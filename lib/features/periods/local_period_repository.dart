import 'package:drift/drift.dart';

import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../../core/local_database/app_database.dart';
import '../sync/local_change_recorder.dart';
import 'period_models.dart';
import 'period_repository.dart';

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
  Future<PeriodSettingsRecord?> settings() async {
    final row = await _db
        .customSelect(
          'SELECT * FROM period_settings WHERE owner_id = ?',
          variables: [Variable.withString(_ownerId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return PeriodSettingsRecord(
      config: configFromRow(row.data),
      version: row.data['version']! as int,
    );
  }

  @override
  Future<void> saveSettings(
    PeriodConfig config, {
    required int expectedVersion,
  }) async {
    final now = _clock().toUtc().toIso8601String();
    final current = await settings();
    if (expectedVersion == 0 && current != null) {
      throw const PeriodSettingsException(
        'A configuração de período já existe neste aparelho.',
      );
    }
    if (expectedVersion > 0 && current?.version != expectedVersion) {
      throw const PeriodSettingsException(
        'A configuração mudou. Abra a tela de novo e tente outra vez.',
      );
    }
    Map<String, dynamic> snapshot(PeriodConfig c, int version) => {
      'id': _ownerId,
      'mode': c.mode.dbValue,
      'custom_start_day': c.customStartDay,
      'version': version,
    };
    await _recorder.record(
      ownerId: _ownerId,
      entityType: 'period_settings',
      entityId: _ownerId,
      operation: expectedVersion == 0 ? 'create' : 'update',
      expectedVersion: expectedVersion,
      rpc: periodSettingsRpc,
      params: periodSettingsParams(config, expectedVersion),
      oldSnapshot: current == null
          ? null
          : snapshot(current.config, current.version),
      newSnapshot: snapshot(config, expectedVersion + 1),
      apply: () async {
        if (current == null) {
          await _db.customStatement(
            'INSERT INTO period_settings (id, owner_id, version, created_at, '
            'updated_at, mode, custom_start_day) VALUES (?, ?, 1, ?, ?, ?, ?)',
            [
              _ownerId,
              _ownerId,
              now,
              now,
              config.mode.dbValue,
              config.customStartDay,
            ],
          );
        } else {
          await _db.customStatement(
            'UPDATE period_settings SET mode = ?, custom_start_day = ?, '
            'version = ?, updated_at = ? WHERE owner_id = ?',
            [
              config.mode.dbValue,
              config.customStartDay,
              expectedVersion + 1,
              now,
              _ownerId,
            ],
          );
        }
      },
    );
  }

  @override
  Future<EntryDateSpan> entryDateSpan() async {
    final row = await _db
        .customSelect(
          'SELECT MIN(d) AS oldest, MAX(d) AS newest FROM ('
          'SELECT COALESCE(received_on, scheduled_for_date) AS d '
          'FROM income_entries WHERE owner_id = ? '
          'UNION ALL SELECT competence_on FROM expense_entries '
          'WHERE owner_id = ? '
          'UNION ALL SELECT allocated_on FROM investment_allocations '
          'WHERE owner_id = ?)',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(_ownerId),
            Variable.withString(_ownerId),
          ],
        )
        .getSingle();
    CalendarDate? parse(Object? v) =>
        v == null ? null : CalendarDate.parse(v as String);
    return EntryDateSpan(
      oldest: parse(row.data['oldest']),
      newest: parse(row.data['newest']),
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
