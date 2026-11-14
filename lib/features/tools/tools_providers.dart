import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../preferences/preferences_providers.dart';
import '../sync/sync_providers.dart';
import 'domain/tool_catalog.dart';
import 'models/tool_preferences.dart';
import 'registry/tool_registry.dart';

/// Escolhas do usuário na aba Ferramentas, salvas na conta pelo mesmo
/// mecanismo das demais preferências (celular: banco local + fila; Web:
/// servidor). Lê de novo depois de cada sincronização.
class ToolPreferencesController extends AsyncNotifier<ToolPreferences> {
  @override
  Future<ToolPreferences> build() async {
    ref.watch(syncStatusProvider.select((s) => s.lastSyncAt));
    try {
      final repo = await ref.watch(preferencesRepositoryProvider.future);
      return await repo.tools();
    } on Object {
      return ToolPreferences.empty;
    }
  }

  ToolCatalog get _catalog => ToolCatalog(
    ref.read(toolRegistryProvider),
    state.value ?? ToolPreferences.empty,
  );

  /// Acrescenta ao fim de "Suas ferramentas". Devolve o aviso de erro, ou
  /// `null` se salvou.
  Future<String?> add(String id) => _saveSelection(_catalog.add(id));

  /// Tira de "Suas ferramentas" (a ferramenta continua no catálogo).
  Future<String?> remove(String id) => _saveSelection(_catalog.remove(id));

  /// Muda a ordem: [newIndex] é a posição final (como em
  /// `onReorderItem`).
  Future<String?> move(int oldIndex, int newIndex) =>
      _saveSelection(_catalog.move(oldIndex, newIndex));

  /// Volta à configuração padrão do app (as dispensas de explicação ficam).
  Future<String?> restoreDefault() => _saveSelection(null);

  /// "Não mostrar novamente" da explicação inicial de [id].
  Future<String?> dismissIntro(String id) async {
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) return blocked;
    final previous = state.value ?? ToolPreferences.empty;
    state = AsyncData(previous.withDismissed(id));
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      await repo.dismissToolIntro(id);
      return null;
    } on Object catch (e) {
      state = AsyncData(previous);
      return 'Não foi possível salvar a preferência: $e';
    }
  }

  /// Aplica na hora e grava; se falhar, a lista anterior volta.
  Future<String?> _saveSelection(List<String>? ids) async {
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) return blocked;
    final previous = state.value ?? ToolPreferences.empty;
    state = AsyncData(previous.withSelected(ids));
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      await repo.setToolSelection(ids);
      return null;
    } on Object catch (e) {
      state = AsyncData(previous);
      return 'Não foi possível salvar as ferramentas: $e';
    }
  }
}

final toolPreferencesProvider =
    AsyncNotifierProvider<ToolPreferencesController, ToolPreferences>(
      ToolPreferencesController.new,
    );

/// Catálogo pronto para a tela (registro + escolhas do usuário).
final toolCatalogProvider = Provider<ToolCatalog>(
  (ref) => ToolCatalog(
    ref.watch(toolRegistryProvider),
    ref.watch(toolPreferencesProvider).value ?? ToolPreferences.empty,
  ),
);
