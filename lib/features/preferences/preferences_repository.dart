import 'package:drift/drift.dart';

import '../../core/local_database/app_database.dart';
import '../sync/local_change_recorder.dart';
import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';

/// Preferências da conta (`user_preferences`): por enquanto, o tema (RF026).
/// Celular: banco local + fila de envio. Web: servidor.
abstract interface class PreferencesRepository {
  /// `'light'`, `'dark'` ou `null` (sem escolha: segue o aparelho, D4).
  Future<String?> theme();

  /// Grava o tema; `null` volta a seguir o aparelho. Decisão D5: vale a
  /// última gravação enviada, sem tela de conflito.
  Future<void> setTheme(String? theme);
}

const setThemeRpc = 'set_user_theme';

/// Celular: grava primeiro no banco local (registro, auditoria e fila na mesma
/// transação), funcionando sem conexão.
class LocalPreferencesRepository implements PreferencesRepository {
  LocalPreferencesRepository(
    this._db,
    this._ownerId,
    this._recorder, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final String _ownerId;
  final LocalChangeRecorder _recorder;
  final DateTime Function() _clock;

  Future<Map<String, dynamic>?> _row() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM user_preferences WHERE owner_id = ?',
          variables: [Variable.withString(_ownerId)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.data;
  }

  @override
  Future<String?> theme() async => (await _row())?['theme'] as String?;

  @override
  Future<void> setTheme(String? theme) async {
    final old = await _row();
    final previousVersion = (old?['version'] as int?) ?? 0;
    final now = _clock().toUtc().toIso8601String();
    await _recorder.record(
      ownerId: _ownerId,
      entityType: 'user_preferences',
      entityId: _ownerId,
      operation: old == null ? 'create' : 'update',
      expectedVersion: previousVersion,
      rpc: setThemeRpc,
      params: {'p_theme': theme},
      oldSnapshot: old == null
          ? null
          : {
              'owner_id': _ownerId,
              'theme': old['theme'],
              'version': previousVersion,
            },
      newSnapshot: {
        'owner_id': _ownerId,
        'theme': theme,
        'version': previousVersion + 1,
      },
      apply: () async {
        await _db.customStatement(
          'INSERT INTO user_preferences (owner_id, theme, version, '
          'updated_at) VALUES (?, ?, ?, ?) '
          'ON CONFLICT (owner_id) DO UPDATE SET theme = excluded.theme, '
          'version = excluded.version, updated_at = excluded.updated_at',
          [_ownerId, theme, previousVersion + 1, now],
        );
      },
    );
  }
}

/// Web: lê e grava direto no servidor (somente online).
class RemotePreferencesRepository implements PreferencesRepository {
  RemotePreferencesRepository(
    this._reader,
    this._gateway, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final RemoteTableReader _reader;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  @override
  Future<String?> theme() async {
    final rows = await _reader.select('user_preferences');
    return rows.isEmpty ? null : rows.first['theme'] as String?;
  }

  @override
  Future<void> setTheme(String? theme) async {
    final response = await _gateway.call(setThemeRpc, {
      'p_operation_id': _newId(),
      'p_theme': theme,
    });
    if (response['status'] != 'applied') {
      throw const SyncRejectedError('Não foi possível salvar o tema.');
    }
  }
}
