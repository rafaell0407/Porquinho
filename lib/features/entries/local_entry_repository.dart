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
      // Receita recorrente pendente ainda não tem período: aparece no período
      // que contém a data programada (RN011).
      final scheduled = kind == EntryKind.income
          ? 'OR (accounting_period_id IS NULL AND scheduled_for_date >= '
                '(SELECT start_date FROM accounting_periods '
                'WHERE owner_id = ? AND id = ?) '
                'AND scheduled_for_date < '
                '(SELECT end_date FROM accounting_periods '
                'WHERE owner_id = ? AND id = ?)) '
          : '';
      final order = kind == EntryKind.income
          ? 'COALESCE(received_on, scheduled_for_date)'
          : kind.dateColumn;
      final rows = await _db
          .customSelect(
            'SELECT * FROM ${kind.table} '
            'WHERE owner_id = ? AND (accounting_period_id = ? $scheduled) '
            'ORDER BY $order DESC, created_at DESC',
            variables: [
              Variable.withString(_ownerId),
              Variable.withString(periodId),
              if (kind == EntryKind.income) ...[
                Variable.withString(_ownerId),
                Variable.withString(periodId),
                Variable.withString(_ownerId),
                Variable.withString(periodId),
              ],
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
      periodId: d['accounting_period_id'] as String?,
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
        // Receita recorrente pendente não tem data de recebimento nem período.
        if (!c.isPendingIncome) periodId = await _periodIdFor(d.date);
      case PayExpense(current: final c):
        current = c;
      case ReceiveIncome(current: final c, :final receivedOn):
        current = c;
        periodId = await _periodIdFor(receivedOn);
      case CancelEntry(current: final c):
        current = c;
      case CreateRecurrence(
        draft: final d,
        existing: final e,
        periodId: final p,
      ):
        draft = d;
        current = e;
        periodId = p;
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
        ?(current?.templateId),
        if (change is CreateRecurrence) ?change.scheduledPeriodId,
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
        CreateEntry() => _insert(kind, call.entityId, draft!, periodId!, now),
        UpdateEntry() => _update(
          kind,
          call.entityId,
          draft!,
          periodId,
          next,
          now,
        ),
        PayExpense(:final paidOn) => _db.customStatement(
          "UPDATE expense_entries SET status = 'paid', paid_on = ?, "
          'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
          [paidOn.toIso(), next, now, _ownerId, call.entityId],
        ),
        ReceiveIncome(:final receivedOn, :final amount) => _db.customStatement(
          "UPDATE income_entries SET status = 'received', received_on = ?, "
          'accounting_period_id = ?, '
          'amount_centavos = COALESCE(?, amount_centavos), '
          'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
          [
            receivedOn.toIso(),
            periodId,
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
    if (change is ReceiveIncome) {
      return {
        ...current!.toSnapshot(),
        'status': 'received',
        'received_on': change.receivedOn.toIso(),
        if (change.amount != null) 'amount_centavos': change.amount.toString(),
        'accounting_period_id': periodId,
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
        'accounting_period_id': change.kind == EntryKind.expense
            ? periodId
            : current?.periodId,
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
      if (!pendingIncome) 'accounting_period_id': periodId,
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
        d.amount!.toString(),
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
    String? periodId,
    int version,
    String now,
  ) {
    final income = kind == EntryKind.income;
    if (periodId == null) {
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
      '${income ? '' : 'due_on = ?, '}accounting_period_id = ?, '
      'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
      [
        d.description,
        d.amount?.toString(),
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
        'scheduled_for_date = ?, scheduled_period_id = ?, '
        '${income ? '' : 'competence_on = ?, due_on = COALESCE(due_on, ?), '}'
        'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
        [
          c.templateId,
          scheduled,
          c.scheduledPeriodId,
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
      'subcategory_id, recurrence_template_id, scheduled_for_date, '
      "scheduled_period_id${income ? '' : ', competence_on, due_on, '
                'accounting_period_id'}) "
      "VALUES (?, ?, 1, ?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?"
      "${income ? '' : ', ?, ?, ?'})",
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
        c.scheduledPeriodId,
        if (!income) ...[
          scheduled,
          (c.draft.dueOn ?? c.scheduledFor).toIso(),
          c.periodId,
        ],
      ],
    );
  }
}
