import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/local_database/app_database.dart';
import '../tools/models/tool_preferences.dart';
import '../sync/local_change_recorder.dart';
import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';

/// Preferências da conta (`user_preferences`): tema (RF026), progresso do
/// assistente inicial e escolhas da aba Ferramentas.
/// Celular: banco local + fila de envio. Web: servidor.
abstract interface class PreferencesRepository {
  /// `'light'`, `'dark'` ou `null` (sem escolha: segue o aparelho, D4).
  Future<String?> theme();

  /// Grava o tema; `null` volta a seguir o aparelho. Decisão D5: vale a
  /// última gravação enviada, sem tela de conflito.
  Future<void> setTheme(String? theme);

  /// Progresso do assistente inicial (RF024, D7): etapa → `done` | `skipped`.
  Future<Map<String, String>> onboarding();

  /// Marca a etapa como concluída ou pulada. Etapas de aparelhos diferentes se
  /// somam no servidor.
  Future<void> setOnboardingStep(String step, String status);

  /// Escolhas da aba Ferramentas.
  Future<ToolPreferences> tools();

  /// Grava a lista ordenada de "Suas ferramentas"; `null` = padrão do app.
  /// Decisão de 13/11/2026: vale a última lista enviada (como o tema).
  Future<void> setToolSelection(List<String>? toolIds);

  /// "Não mostrar novamente" da explicação inicial. Aparelhos se somam.
  Future<void> dismissToolIntro(String toolId);
}

Map<String, String> decodeOnboarding(Object? raw) {
  Object? value = raw;
  if (value is String) {
    try {
      value = jsonDecode(value);
    } on FormatException {
      return {};
    }
  }
  if (value is! Map) return {};
  return {for (final e in value.entries) '${e.key}': '${e.value}'};
}

const setThemeRpc = 'set_user_theme';
const setOnboardingStepRpc = 'set_onboarding_step';
const setToolSelectionRpc = 'set_tool_selection';
const dismissToolIntroRpc = 'dismiss_tool_intro';

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

  @override
  Future<Map<String, String>> onboarding() async =>
      decodeOnboarding((await _row())?['onboarding']);

  @override
  Future<void> setOnboardingStep(String step, String status) async {
    final old = await _row();
    final previousVersion = (old?['version'] as int?) ?? 0;
    final merged = {...decodeOnboarding(old?['onboarding']), step: status};
    final encoded = jsonEncode(merged);
    final now = _clock().toUtc().toIso8601String();
    await _recorder.record(
      ownerId: _ownerId,
      entityType: 'user_preferences',
      entityId: _ownerId,
      operation: old == null ? 'create' : 'update',
      expectedVersion: previousVersion,
      rpc: setOnboardingStepRpc,
      params: {'p_step': step, 'p_status': status},
      oldSnapshot: old == null
          ? null
          : {
              'owner_id': _ownerId,
              'onboarding': decodeOnboarding(old['onboarding']),
              'version': previousVersion,
            },
      newSnapshot: {
        'owner_id': _ownerId,
        'onboarding': merged,
        'version': previousVersion + 1,
      },
      apply: () async {
        await _db.customStatement(
          'INSERT INTO user_preferences (owner_id, onboarding, version, '
          'updated_at) VALUES (?, ?, ?, ?) '
          'ON CONFLICT (owner_id) DO UPDATE SET '
          'onboarding = excluded.onboarding, '
          'version = excluded.version, updated_at = excluded.updated_at',
          [_ownerId, encoded, previousVersion + 1, now],
        );
      },
    );
  }

  @override
  Future<ToolPreferences> tools() async =>
      ToolPreferences.decode((await _row())?['tools']);

  @override
  Future<void> setToolSelection(List<String>? toolIds) async {
    final old = await _row();
    final next = ToolPreferences.decode(old?['tools']).withSelected(toolIds);
    await _recordTools(
      old,
      next,
      rpc: setToolSelectionRpc,
      params: {'p_tool_ids': toolIds},
    );
  }

  @override
  Future<void> dismissToolIntro(String toolId) async {
    final old = await _row();
    final next = ToolPreferences.decode(old?['tools']).withDismissed(toolId);
    await _recordTools(
      old,
      next,
      rpc: dismissToolIntroRpc,
      params: {'p_tool_id': toolId},
    );
  }

  Future<void> _recordTools(
    Map<String, dynamic>? old,
    ToolPreferences next, {
    required String rpc,
    required Map<String, dynamic> params,
  }) async {
    final previousVersion = (old?['version'] as int?) ?? 0;
    final now = _clock().toUtc().toIso8601String();
    await _recorder.record(
      ownerId: _ownerId,
      entityType: 'user_preferences',
      entityId: _ownerId,
      operation: old == null ? 'create' : 'update',
      expectedVersion: previousVersion,
      rpc: rpc,
      params: params,
      oldSnapshot: old == null
          ? null
          : {
              'owner_id': _ownerId,
              'tools': ToolPreferences.decode(old['tools']).toJson(),
              'version': previousVersion,
            },
      newSnapshot: {
        'owner_id': _ownerId,
        'tools': next.toJson(),
        'version': previousVersion + 1,
      },
      apply: () async {
        await _db.customStatement(
          'INSERT INTO user_preferences (owner_id, tools, version, '
          'updated_at) VALUES (?, ?, ?, ?) '
          'ON CONFLICT (owner_id) DO UPDATE SET tools = excluded.tools, '
          'version = excluded.version, updated_at = excluded.updated_at',
          [_ownerId, next.encode(), previousVersion + 1, now],
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

  @override
  Future<Map<String, String>> onboarding() async {
    final rows = await _reader.select('user_preferences');
    return rows.isEmpty ? {} : decodeOnboarding(rows.first['onboarding']);
  }

  @override
  Future<void> setOnboardingStep(String step, String status) async {
    final response = await _gateway.call(setOnboardingStepRpc, {
      'p_operation_id': _newId(),
      'p_step': step,
      'p_status': status,
    });
    if (response['status'] != 'applied') {
      throw const SyncRejectedError('Não foi possível salvar a etapa.');
    }
  }

  @override
  Future<ToolPreferences> tools() async {
    final rows = await _reader.select('user_preferences');
    return rows.isEmpty
        ? ToolPreferences.empty
        : ToolPreferences.decode(rows.first['tools']);
  }

  @override
  Future<void> setToolSelection(List<String>? toolIds) async {
    final response = await _gateway.call(setToolSelectionRpc, {
      'p_operation_id': _newId(),
      'p_tool_ids': toolIds,
    });
    if (response['status'] != 'applied') {
      throw const SyncRejectedError('Não foi possível salvar as ferramentas.');
    }
  }

  @override
  Future<void> dismissToolIntro(String toolId) async {
    final response = await _gateway.call(dismissToolIntroRpc, {
      'p_operation_id': _newId(),
      'p_tool_id': toolId,
    });
    if (response['status'] != 'applied') {
      throw const SyncRejectedError('Não foi possível salvar a preferência.');
    }
  }
}
