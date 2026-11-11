import 'package:drift/drift.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/local_database/app_database.dart';
import '../sync/local_change_recorder.dart';
import 'entry_models.dart';
import 'entry_repository.dart';

/// Celular: cada alteração grava registro, auditoria e fila de envio na mesma
/// transação; só depois a tela informa "salvo".
class LocalEntryRepository implements EntryRepository {
  LocalEntryRepository(
    this._db,
    this._ownerId,
    this._recorder, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final String _ownerId;
  final LocalChangeRecorder _recorder;
  final DateTime Function() _clock;

  @override
  Future<List<EntryRecord>> entriesInPeriod(String periodId) async {
    final result = <EntryRecord>[];
    for (final kind in EntryKind.values) {
      final rows = await _db
          .customSelect(
            'SELECT * FROM ${kind.table} '
            'WHERE owner_id = ? AND accounting_period_id = ? '
            'ORDER BY ${kind.dateColumn} DESC, created_at DESC',
            variables: [
              Variable.withString(_ownerId),
              Variable.withString(periodId),
            ],
          )
          .get();
      result.addAll(rows.map((r) => _fromRow(kind, r.data)));
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<EntryRecord?> entry(EntryKind kind, String id) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM ${kind.table} WHERE owner_id = ? AND id = ?',
          variables: [Variable.withString(_ownerId), Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _fromRow(kind, row.data);
  }

  EntryRecord _fromRow(EntryKind kind, Map<String, Object?> d) {
    final amount = d['amount_centavos'];
    final due = d['due_on'] as String?;
    final paid = d['paid_on'] as String?;
    return EntryRecord(
      id: d['id']! as String,
      kind: kind,
      amount: amount == null ? null : BigInt.parse(amount as String),
      status: d['status']! as String,
      date: CalendarDate.parse(d[kind.dateColumn]! as String),
      version: d['version']! as int,
      description: d['description'] as String?,
      categoryId: d['category_id'] as String?,
      subcategoryId: d['subcategory_id'] as String?,
      dueOn: due == null ? null : CalendarDate.parse(due),
      paidOn: paid == null ? null : CalendarDate.parse(paid),
      periodId: d['accounting_period_id'] as String?,
      isRecurring: d['recurrence_template_id'] != null,
    );
  }

  @override
  Future<void> apply(List<EntryChange> changes) => _db.transaction(() async {
    for (final change in changes) {
      await _applyOne(change);
    }
  });

  Future<String> _periodIdFor(CalendarDate date) async {
    final row = await _db
        .customSelect(
          'SELECT id FROM accounting_periods WHERE owner_id = ? '
          'AND start_date <= ? AND ? < end_date',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(date.toIso()),
            Variable.withString(date.toIso()),
          ],
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Nenhum período cobre ${date.toIso()}.');
    }
    return row.read<String>('id');
  }

  Future<void> _applyOne(EntryChange change) async {
    final call = entryRpcCallFor(change);
    final kind = call.kind;
    final now = _clock().toUtc().toIso8601String();
    final next = call.expectedVersion + 1;

    String? periodId;
    EntryDraft? draft;
    EntryRecord? current;
    switch (change) {
      case CreateEntry(draft: final d):
        draft = d;
        periodId = await _periodIdFor(d.date);
      case UpdateEntry(current: final c, draft: final d):
        draft = d;
        current = c;
        periodId = await _periodIdFor(d.date);
      case PayExpense(current: final c):
        current = c;
      case CancelEntry(current: final c):
        current = c;
    }

    final newSnapshot = _newSnapshot(change, draft, current, periodId, next);
    await _recorder.record(
      ownerId: _ownerId,
      entityType: kind.entityType,
      entityId: call.entityId,
      operation: call.action,
      expectedVersion: call.expectedVersion,
      rpc: call.rpc,
      params: call.params,
      dependsOn: [
        if (draft?.categoryId != null) draft!.categoryId!,
        if (draft?.subcategoryId != null) draft!.subcategoryId!,
        ?periodId,
      ],
      oldSnapshot: current?.toSnapshot(),
      newSnapshot: newSnapshot,
      apply: () => switch (change) {
        CreateEntry() => _insert(kind, call.entityId, draft!, periodId!, now),
        UpdateEntry() => _update(
          kind,
          call.entityId,
          draft!,
          periodId!,
          next,
          now,
        ),
        PayExpense(:final paidOn) => _db.customStatement(
          "UPDATE expense_entries SET status = 'paid', paid_on = ?, "
          'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
          [paidOn.toIso(), next, now, _ownerId, call.entityId],
        ),
        CancelEntry() => _db.customStatement(
          "UPDATE ${kind.table} SET status = 'cancelled', version = ?, "
          'updated_at = ? WHERE owner_id = ? AND id = ?',
          [next, now, _ownerId, call.entityId],
        ),
      },
    );
  }

  Map<String, dynamic> _newSnapshot(
    EntryChange change,
    EntryDraft? draft,
    EntryRecord? current,
    String? periodId,
    int next,
  ) {
    if (change is PayExpense) {
      return {
        ...current!.toSnapshot(),
        'status': 'paid',
        'paid_on': change.paidOn.toIso(),
        'version': next,
      };
    }
    if (change is CancelEntry) {
      return {...current!.toSnapshot(), 'status': 'cancelled', 'version': next};
    }
    final isCreate = change is CreateEntry;
    return {
      if (!isCreate) ...current!.toSnapshot(),
      if (isCreate) 'id': (change).id,
      'status': isCreate
          ? (draft!.kind == EntryKind.income ? 'received' : 'pending')
          : current!.status,
      ...draft!.toPayload(),
      'accounting_period_id': periodId,
      'version': next,
    };
  }

  Future<void> _insert(
    EntryKind kind,
    String id,
    EntryDraft d,
    String periodId,
    String now,
  ) {
    final income = kind == EntryKind.income;
    return _db.customStatement(
      'INSERT INTO ${kind.table} (id, owner_id, version, created_at, '
      'updated_at, description, amount_centavos, status, category_id, '
      'subcategory_id, ${kind.dateColumn}, ${income ? '' : 'due_on, '}'
      'accounting_period_id) '
      "VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ${income ? '' : '?, '}?)",
      [
        id,
        _ownerId,
        now,
        now,
        d.description,
        d.amount.toString(),
        income ? 'received' : 'pending',
        d.categoryId,
        d.subcategoryId,
        d.date.toIso(),
        if (!income) d.dueOn?.toIso(),
        periodId,
      ],
    );
  }

  Future<void> _update(
    EntryKind kind,
    String id,
    EntryDraft d,
    String periodId,
    int version,
    String now,
  ) {
    final income = kind == EntryKind.income;
    return _db.customStatement(
      'UPDATE ${kind.table} SET description = ?, amount_centavos = ?, '
      'category_id = ?, subcategory_id = ?, ${kind.dateColumn} = ?, '
      '${income ? '' : 'due_on = ?, '}accounting_period_id = ?, '
      'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
      [
        d.description,
        d.amount.toString(),
        d.categoryId,
        d.subcategoryId,
        d.date.toIso(),
        if (!income) d.dueOn?.toIso(),
        periodId,
        version,
        now,
        _ownerId,
        id,
      ],
    );
  }
}
