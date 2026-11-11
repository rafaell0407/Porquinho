import 'package:drift/drift.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/local_database/app_database.dart';
import '../sync/local_change_recorder.dart';
import 'investment_models.dart';
import 'investment_repository.dart';

/// Celular: registro, auditoria e fila de envio na mesma transação; só depois
/// a tela informa "salvo".
class LocalInvestmentRepository implements InvestmentRepository {
  LocalInvestmentRepository(
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
  Future<List<InvestmentRecord>> investmentsInPeriod(String periodId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM investment_allocations '
          'WHERE owner_id = ? AND accounting_period_id = ? '
          'ORDER BY allocated_on DESC, created_at DESC',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(periodId),
          ],
        )
        .get();
    return rows.map((r) => _fromRow(r.data)).toList();
  }

  @override
  Future<InvestmentRecord?> investment(String id) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM investment_allocations WHERE owner_id = ? AND id = ?',
          variables: [Variable.withString(_ownerId), Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _fromRow(row.data);
  }

  InvestmentRecord _fromRow(Map<String, Object?> d) => InvestmentRecord(
    id: d['id']! as String,
    amount: BigInt.parse(d['amount_centavos']! as String),
    date: CalendarDate.parse(d['allocated_on']! as String),
    version: d['version']! as int,
    periodId: d['accounting_period_id'] as String?,
    cancelled: d['cancelled_at'] != null,
    templateId: d['recurrence_template_id'] as String?,
    scheduledFor: d['scheduled_for_date'] == null
        ? null
        : CalendarDate.parse(d['scheduled_for_date']! as String),
  );

  @override
  Future<void> apply(List<InvestmentChange> changes) =>
      _db.transaction(() async {
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

  Future<void> _applyOne(InvestmentChange change) async {
    final call = investmentRpcCallFor(change);
    final now = _clock().toUtc().toIso8601String();
    final next = call.expectedVersion + 1;

    final InvestmentRecord? current = switch (change) {
      CreateInvestment() => null,
      UpdateInvestment(:final current) => current,
      CancelInvestment(:final current) => current,
      CreateInvestmentRecurrence(:final existing) => existing,
    };
    final periodId = switch (change) {
      CreateInvestment(:final draft) => await _periodIdFor(draft.date),
      UpdateInvestment(:final draft) => await _periodIdFor(draft.date),
      CancelInvestment() => current!.periodId,
      CreateInvestmentRecurrence(:final periodId) => periodId,
    };

    final Map<String, dynamic> newSnapshot = switch (change) {
      CreateInvestment(:final id, :final draft) => {
        'id': id,
        'amount_centavos': draft.amount.toString(),
        'allocated_on': draft.date.toIso(),
        'accounting_period_id': periodId,
        'cancelled': false,
        'version': next,
      },
      UpdateInvestment(:final draft) => {
        ...current!.toSnapshot(),
        'amount_centavos': draft.amount.toString(),
        'allocated_on': draft.date.toIso(),
        'accounting_period_id': periodId,
        'version': next,
      },
      CancelInvestment() => {
        ...current!.toSnapshot(),
        'cancelled': true,
        'version': next,
      },
      final CreateInvestmentRecurrence c => {
        if (current != null) ...current.toSnapshot(),
        'id': c.entryId,
        'amount_centavos': c.draft.amount.toString(),
        'allocated_on': c.scheduledFor.toIso(),
        'accounting_period_id': periodId,
        'cancelled': false,
        'recurrence_template_id': c.templateId,
        'scheduled_for_date': c.scheduledFor.toIso(),
        'version': next,
      },
    };

    await _recorder.record(
      ownerId: _ownerId,
      entityType: InvestmentRpcCall.entityType,
      entityId: call.entityId,
      operation: call.action,
      expectedVersion: call.expectedVersion,
      rpc: call.rpc,
      params: call.params,
      dependsOn: [
        ?periodId,
        ?current?.templateId,
        if (change is CreateInvestmentRecurrence) ?change.scheduledPeriodId,
      ],
      extraAudits: [
        if (change is CreateInvestmentRecurrence)
          ExtraAudit(
            entityType: 'investment_recurrence_template',
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
        CreateInvestment(:final draft) => _db.customStatement(
          'INSERT INTO investment_allocations (id, owner_id, version, '
          'created_at, updated_at, amount_centavos, allocated_on, '
          'accounting_period_id) VALUES (?, ?, 1, ?, ?, ?, ?, ?)',
          [
            call.entityId,
            _ownerId,
            now,
            now,
            draft.amount.toString(),
            draft.date.toIso(),
            periodId,
          ],
        ),
        UpdateInvestment(:final draft) => _db.customStatement(
          'UPDATE investment_allocations SET amount_centavos = ?, '
          'allocated_on = ?, accounting_period_id = ?, version = ?, '
          'updated_at = ? WHERE owner_id = ? AND id = ?',
          [
            draft.amount.toString(),
            draft.date.toIso(),
            periodId,
            next,
            now,
            _ownerId,
            call.entityId,
          ],
        ),
        CancelInvestment() => _db.customStatement(
          'UPDATE investment_allocations SET '
          'cancelled_at = COALESCE(cancelled_at, ?), version = ?, '
          'updated_at = ? WHERE owner_id = ? AND id = ?',
          [now, next, now, _ownerId, call.entityId],
        ),
        final CreateInvestmentRecurrence c => _createRecurrence(c, next, now),
      },
    );
  }

  /// Modelo + primeira ocorrência na mesma transação (D7). O investimento novo
  /// nasce já na data programada; o avulso existente mantém o valor e passa a
  /// apontar para o modelo.
  Future<void> _createRecurrence(
    CreateInvestmentRecurrence c,
    int next,
    String now,
  ) async {
    final template = c.templatePayload();
    await _db.customStatement(
      'INSERT INTO investment_recurrence_templates (id, owner_id, version, '
      'created_at, updated_at, frequency, starts_on, monthly_reference_day, '
      'default_amount_centavos, is_active) VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, 1)',
      [
        c.templateId,
        _ownerId,
        now,
        now,
        template['frequency'],
        template['starts_on'],
        template['monthly_reference_day'],
        template['default_amount_centavos'],
      ],
    );
    final scheduled = c.scheduledFor.toIso();
    if (c.existing != null) {
      await _db.customStatement(
        'UPDATE investment_allocations SET recurrence_template_id = ?, '
        'scheduled_for_date = ?, scheduled_period_id = ?, allocated_on = ?, '
        'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
        [
          c.templateId,
          scheduled,
          c.scheduledPeriodId,
          scheduled,
          next,
          now,
          _ownerId,
          c.entryId,
        ],
      );
      return;
    }
    await _db.customStatement(
      'INSERT INTO investment_allocations (id, owner_id, version, created_at, '
      'updated_at, amount_centavos, allocated_on, accounting_period_id, '
      'recurrence_template_id, scheduled_for_date, scheduled_period_id) '
      'VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        c.entryId,
        _ownerId,
        now,
        now,
        c.draft.amount.toString(),
        scheduled,
        c.periodId,
        c.templateId,
        scheduled,
        c.scheduledPeriodId,
      ],
    );
  }
}
