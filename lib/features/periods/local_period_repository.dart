import 'package:drift/drift.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../../core/local_database/app_database.dart';
import '../sync/local_change_recorder.dart';
import 'period_models.dart';
import 'period_repository.dart';
import 'remote_period_repository.dart'
    show configFromRow, periodParams, periodRpc, scheduleParams, scheduleRpc;

/// Celular: grava primeiro no banco local cifrado (registro, auditoria e fila
/// na mesma transação) e sincroniza depois.
class LocalPeriodRepository implements PeriodRepository {
  LocalPeriodRepository(
    this._db,
    this._ownerId,
    this._recorder, {
    Future<void> Function()? refresh,
    DateTime Function()? clock,
  }) : _refresh = refresh,
       _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final String _ownerId;
  final LocalChangeRecorder _recorder;
  final Future<void> Function()? _refresh;
  final DateTime Function() _clock;

  @override
  Future<List<PeriodConfigRecord>> configurations() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM period_configurations WHERE owner_id = ? '
          'ORDER BY effective_from',
          variables: [Variable.withString(_ownerId)],
        )
        .get();
    return rows.map((r) {
      final d = r.data;
      return PeriodConfigRecord(
        id: d['id']! as String,
        config: configFromRow(d),
        effectiveFrom: CalendarDate.parse(d['effective_from']! as String),
        version: d['version']! as int,
      );
    }).toList();
  }

  @override
  Future<List<PeriodRecord>> periods() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM accounting_periods WHERE owner_id = ? '
          'ORDER BY start_date',
          variables: [Variable.withString(_ownerId)],
        )
        .get();
    return rows.map((r) {
      final d = r.data;
      return PeriodRecord(
        id: d['id']! as String,
        configurationId: d['configuration_id']! as String,
        range: PeriodRange(
          CalendarDate.parse(d['start_date']! as String),
          CalendarDate.parse(d['end_date']! as String),
        ),
        version: d['version']! as int,
      );
    }).toList();
  }

  @override
  Future<void> createPeriod(PeriodDraft draft) async {
    final now = _clock().toUtc().toIso8601String();
    final configSnapshot = {
      'id': draft.configurationId,
      'mode': draft.config.mode.dbValue,
      'custom_start_day': draft.config.customStartDay,
      'effective_from': draft.range.start.toIso(),
      'version': 1,
    };
    final periodSnapshot = {
      'id': draft.id,
      'configuration_id': draft.configurationId,
      'start_date': draft.range.start.toIso(),
      'end_date': draft.range.end.toIso(),
      'version': 1,
    };
    await _recorder.record(
      ownerId: _ownerId,
      entityType: 'accounting_period',
      entityId: draft.id,
      operation: 'create',
      expectedVersion: 0,
      rpc: periodRpc(draft),
      params: periodParams(draft),
      dependsOn: [
        if (draft.dependsOnPeriodId != null) draft.dependsOnPeriodId!,
        // Configuração agendada que ainda pode estar na fila (Entrega 59).
        if (draft.dependsOnConfigurationId != null)
          draft.dependsOnConfigurationId!,
      ],
      newSnapshot: periodSnapshot,
      extraAudits: [
        if (draft.newConfiguration)
          ExtraAudit(
            entityType: 'period_configuration',
            entityId: draft.configurationId,
            operation: 'create',
            newSnapshot: configSnapshot,
          ),
      ],
      apply: () async {
        if (draft.newConfiguration) {
          await _db.customStatement(
            'INSERT INTO period_configurations (id, owner_id, version, '
            'created_at, updated_at, mode, custom_start_day, effective_from) '
            'VALUES (?, ?, 1, ?, ?, ?, ?, ?)',
            [
              draft.configurationId,
              _ownerId,
              now,
              now,
              draft.config.mode.dbValue,
              draft.config.customStartDay,
              draft.range.start.toIso(),
            ],
          );
        }
        await _db.customStatement(
          'INSERT INTO accounting_periods (id, owner_id, version, created_at, '
          'updated_at, configuration_id, start_date, end_date) '
          'VALUES (?, ?, 1, ?, ?, ?, ?, ?)',
          [
            draft.id,
            _ownerId,
            now,
            now,
            draft.configurationId,
            draft.range.start.toIso(),
            draft.range.end.toIso(),
          ],
        );
      },
    );
  }

  @override
  Future<void> scheduleConfiguration(ScheduleDraft draft) async {
    final now = _clock().toUtc().toIso8601String();
    final rows = await _db
        .customSelect(
          'SELECT * FROM period_configurations WHERE owner_id = ? AND id = ?',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(draft.configurationId),
          ],
        )
        .get();
    final old = rows.isEmpty ? null : rows.single.data;
    await _recorder.record(
      ownerId: _ownerId,
      entityType: 'period_configuration',
      entityId: draft.configurationId,
      operation: draft.isCreate ? 'create' : 'update',
      expectedVersion: draft.expectedVersion,
      rpc: scheduleRpc,
      params: scheduleParams(draft),
      dependsOn: [draft.lastPeriodId],
      oldSnapshot: old == null
          ? null
          : {
              'id': old['id'],
              'mode': old['mode'],
              'custom_start_day': old['custom_start_day'],
              'effective_from': old['effective_from'],
              'version': old['version'],
            },
      newSnapshot: {
        'id': draft.configurationId,
        'mode': draft.config.mode.dbValue,
        'custom_start_day': draft.config.customStartDay,
        'effective_from': draft.effectiveFrom.toIso(),
        'version': draft.expectedVersion + 1,
      },
      apply: () async {
        if (draft.isCreate) {
          await _db.customStatement(
            'INSERT INTO period_configurations (id, owner_id, version, '
            'created_at, updated_at, mode, custom_start_day, effective_from) '
            'VALUES (?, ?, 1, ?, ?, ?, ?, ?)',
            [
              draft.configurationId,
              _ownerId,
              now,
              now,
              draft.config.mode.dbValue,
              draft.config.customStartDay,
              draft.effectiveFrom.toIso(),
            ],
          );
        } else {
          await _db.customStatement(
            'UPDATE period_configurations SET mode = ?, custom_start_day = ?, '
            'version = ?, updated_at = ? WHERE owner_id = ? AND id = ?',
            [
              draft.config.mode.dbValue,
              draft.config.customStartDay,
              draft.expectedVersion + 1,
              now,
              _ownerId,
              draft.configurationId,
            ],
          );
        }
      },
    );
  }

  @override
  Future<void> refreshFromServer() async {
    final refresh = _refresh;
    if (refresh == null) return;
    try {
      await refresh().timeout(const Duration(seconds: 8));
    } on Object {
      // Sem conexão: segue com o que existe no aparelho.
    }
  }
}
