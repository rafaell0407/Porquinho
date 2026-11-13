import 'package:drift/drift.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
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
  Future<List<EntryRecord>> entriesInPeriod(PeriodRange range) async {
    final result = <EntryRecord>[];
    final start = Variable.withString(range.start.toIso());
    final end = Variable.withString(range.end.toIso());
    for (final kind in EntryKind.values) {
      final date = kind.dateColumn;
      // Receita recorrente pendente ainda não tem data de recebimento:
      // aparece no período que contém a data programada (RN011).
      final scheduled = kind == EntryKind.income
          ? 'OR ($date IS NULL AND scheduled_for_date >= ? '
                'AND scheduled_for_date < ?) '
          : '';
      final order = kind == EntryKind.income
          ? 'COALESCE(received_on, scheduled_for_date)'
          : date;
      final rows = await _db
          .customSelect(
            'SELECT * FROM ${kind.table} WHERE owner_id = ? '
            'AND (($date >= ? AND $date < ?) $scheduled) '
            'ORDER BY $order DESC, created_at DESC',
            variables: [
              Variable.withString(_ownerId),
              start,
              end,
              if (kind == EntryKind.income) ...[start, end],
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
    final scheduled = d['scheduled_for_date'] as String?;
    final dateText = (d[kind.dateColumn] as String?) ?? scheduled;
    return EntryRecord(
      id: d['id']! as String,
      kind: kind,
      amount: amount == null ? null : BigInt.parse(amount as String),
      status: d['status']! as String,
      date: CalendarDate.parse(dateText!),
      version: d['version']! as int,
      description: d['description'] as String?,
      categoryId: d['category_id'] as String?,
      subcategoryId: d['subcategory_id'] as String?,
      dueOn: due == null ? null : CalendarDate.parse(due),
      paidOn: paid == null ? null : CalendarDate.parse(paid),
      templateId: d['recurrence_template_id'] as String?,
      scheduledFor: scheduled == null ? null : CalendarDate.parse(scheduled),
    );
  }

  @override
  Future<void> apply(List<EntryChange> changes) => _db.transaction(() async {
    for (final change in changes) {
      await _applyOne(change);
    }
  });

  Future<void> _applyOne(EntryChange change) async {
    final call = entryRpcCallFor(change);
    final kind = call.kind;
    final now = _clock().toUtc().toIso8601String();
    final next = call.expectedVersion + 1;

    EntryDraft? draft;
    EntryRecord? current;
    switch (change) {
      case CreateEntry(draft: final d):
        draft = d;
      case UpdateEntry(current: final c, draft: final d):
        draft = d;
        current = c;
      case PayExpense(current: final c):
        current = c;
      case ReceiveIncome(current: final c):
        current = c;
      case CancelEntry(current: final c):
        current = c;
      case CreateRecurrence(draft: final d, existing: final e):
        draft = d;
        current = e;
    }

    final newSnapshot = _newSnapshot(change, draft, current, next);
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
        ?(current?.templateId),
      ],
      extraAudits: [
        if (change is CreateRecurrence)
          ExtraAudit(
            entityType: kind.templateEntityType,
            entityId: change.templateId,
            operation: 'create',
            newSnapshot: {
              'id': change.templateId,
              ...change.templatePayload(),
              'is_active': true,
              'version': 1,
            },
          ),
      ],
      oldSnapshot: current?.toSnapshot(),
      newSnapshot: newSnapshot,
      apply: () => switch (change) {
        CreateEntry() => _insert(kind, call.entityId, draft!, now),
        UpdateEntry(:final current) => _update(
          kind,
          call.entityId,
          draft!,
          next,
          now,
          pendingIncome: current.isPendingIncome,
        ),
        PayExpense(:final paidOn) => _db.customStatement(
          "UPDATE expense_entries SET status = 'paid', paid_on = ?, "
          'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
          [paidOn.toIso(), next, now, _ownerId, call.entityId],
        ),
        ReceiveIncome(:final receivedOn, :final amount) => _db.customStatement(
          "UPDATE income_entries SET status = 'received', received_on = ?, "
          'amount_centavos = COALESCE(?, amount_centavos), '
          'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
          [
            receivedOn.toIso(),
            amount?.toString(),
            next,
            now,
            _ownerId,
            call.entityId,
          ],
        ),
        CancelEntry() => _db.customStatement(
          "UPDATE ${kind.table} SET status = 'cancelled', version = ?, "
          'updated_at = ? WHERE owner_id = ? AND id = ?',
          [next, now, _ownerId, call.entityId],
        ),
        final CreateRecurrence c => _createRecurrence(c, next, now),
      },
    );
  }

  Map<String, dynamic> _newSnapshot(
    EntryChange change,
    EntryDraft? draft,
    EntryRecord? current,
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
    if (change is ReceiveIncome) {
      return {
        ...current!.toSnapshot(),
        'status': 'received',
        'received_on': change.receivedOn.toIso(),
        if (change.amount != null) 'amount_centavos': change.amount.toString(),
        'version': next,
      };
    }
    if (change is CancelEntry) {
      return {...current!.toSnapshot(), 'status': 'cancelled', 'version': next};
    }
    if (change is CreateRecurrence) {
      return {
        if (current != null) ...current.toSnapshot(),
        'id': change.entryId,
        'status': 'pending',
        'recurrence_template_id': change.templateId,
        'scheduled_for_date': change.scheduledFor.toIso(),
        'version': next,
      };
    }
    final isCreate = change is CreateEntry;
    final pendingIncome = current?.isPendingIncome ?? false;
    return {
      if (!isCreate) ...current!.toSnapshot(),
      if (isCreate) 'id': (change).id,
      'status': isCreate
          ? (draft!.kind == EntryKind.income ? 'received' : 'pending')
          : current!.status,
      ...draft!.toPayload(includeDate: !pendingIncome),
      'version': next,
    };
  }

  Future<void> _insert(EntryKind kind, String id, EntryDraft d, String now) {
    final income = kind == EntryKind.income;
    return _db.customStatement(
      'INSERT INTO ${kind.table} (id, owner_id, version, created_at, '
      'updated_at, description, amount_centavos, status, category_id, '
      'subcategory_id, ${kind.dateColumn}${income ? '' : ', due_on'}) '
      "VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?${income ? '' : ', ?'})",
      [
        id,
        _ownerId,
        now,
        now,
        d.description,
        d.amount!.toString(),
        income ? 'received' : 'pending',
        d.categoryId,
        d.subcategoryId,
        d.date.toIso(),
        if (!income) d.dueOn?.toIso(),
      ],
    );
  }

  Future<void> _update(
    EntryKind kind,
    String id,
    EntryDraft d,
    int version,
    String now, {
    required bool pendingIncome,
  }) {
    final income = kind == EntryKind.income;
    if (pendingIncome) {
      // Receita recorrente pendente: só descrição, valor e categoria.
      return _db.customStatement(
        'UPDATE income_entries SET description = ?, amount_centavos = ?, '
        'category_id = ?, subcategory_id = ?, version = ?, updated_at = ? '
        'WHERE owner_id = ? AND id = ?',
        [
          d.description,
          d.amount?.toString(),
          d.categoryId,
          d.subcategoryId,
          version,
          now,
          _ownerId,
          id,
        ],
      );
    }
    return _db.customStatement(
      'UPDATE ${kind.table} SET description = ?, amount_centavos = ?, '
      'category_id = ?, subcategory_id = ?, ${kind.dateColumn} = ?, '
      '${income ? '' : 'due_on = ?, '}'
      'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
      [
        d.description,
        d.amount?.toString(),
        d.categoryId,
        d.subcategoryId,
        d.date.toIso(),
        if (!income) d.dueOn?.toIso(),
        version,
        now,
        _ownerId,
        id,
      ],
    );
  }

  /// Modelo + primeira ocorrência na mesma transação (D8). O lançamento novo
  /// nasce pendente; o avulso existente mantém seus dados e passa a apontar
  /// para o modelo, na data programada.
  Future<void> _createRecurrence(
    CreateRecurrence c,
    int next,
    String now,
  ) async {
    final kind = c.kind;
    final template = c.templatePayload();
    await _db.customStatement(
      'INSERT INTO ${kind.templateTable} (id, owner_id, version, created_at, '
      'updated_at, description, frequency, starts_on, monthly_reference_day, '
      'value_mode, default_amount_centavos, category_id, subcategory_id, '
      'is_active) VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
      [
        c.templateId,
        _ownerId,
        now,
        now,
        template['description'],
        template['frequency'],
        template['starts_on'],
        template['monthly_reference_day'],
        template['value_mode'],
        template['default_amount_centavos'],
        template['category_id'],
        template['subcategory_id'],
      ],
    );
    final income = kind == EntryKind.income;
    final scheduled = c.scheduledFor.toIso();
    if (c.existing != null) {
      await _db.customStatement(
        'UPDATE ${kind.table} SET recurrence_template_id = ?, '
        'scheduled_for_date = ?, '
        '${income ? '' : 'competence_on = ?, due_on = COALESCE(due_on, ?), '}'
        'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
        [
          c.templateId,
          scheduled,
          if (!income) ...[scheduled, scheduled],
          next,
          now,
          _ownerId,
          c.entryId,
        ],
      );
      return;
    }
    final amount = c.choice.variableValue ? c.draft.amount : c.defaultAmount;
    await _db.customStatement(
      'INSERT INTO ${kind.table} (id, owner_id, version, created_at, '
      'updated_at, description, amount_centavos, status, category_id, '
      'subcategory_id, recurrence_template_id, scheduled_for_date'
      "${income ? '' : ', competence_on, due_on'}) "
      "VALUES (?, ?, 1, ?, ?, ?, ?, 'pending', ?, ?, ?, ?"
      "${income ? '' : ', ?, ?'})",
      [
        c.entryId,
        _ownerId,
        now,
        now,
        c.draft.description,
        amount?.toString(),
        c.draft.categoryId,
        c.draft.subcategoryId,
        c.templateId,
        scheduled,
        if (!income) ...[scheduled, (c.draft.dueOn ?? c.scheduledFor).toIso()],
      ],
    );
  }
}
