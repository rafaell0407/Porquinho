import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../preferences/preferences_providers.dart';
import '../sync/sync_providers.dart';
import 'domain/report_catalog.dart';
import 'models/report_preferences.dart';
import 'registry/report_registry.dart';

/// Escolhas do usuário na central de Relatórios, salvas na conta pelo mesmo
/// mecanismo das demais preferências (celular: banco local + fila; Web:
/// servidor). Lê de novo depois de cada sincronização.
class ReportPreferencesController extends AsyncNotifier<ReportPreferences> {
  @override
  Future<ReportPreferences> build() async {
    ref.watch(syncStatusProvider.select((s) => s.lastSyncAt));
    try {
      final repo = await ref.watch(preferencesRepositoryProvider.future);
      return await repo.reports();
    } on Object {
      // Sem leitura (ex.: Web sem conexão): mostra a lista sugerida em vez de
      // pedir a configuração guiada, que não conseguiria ser gravada.
      return const ReportPreferences(setup: ReportSetupStatus.skipped);
    }
  }

  ReportPreferences get _current => state.value ?? ReportPreferences.empty;

  ReportCatalog get _catalog =>
      ReportCatalog(ref.read(reportRegistryProvider), _current);

  /// Acrescenta ao fim de "Meus relatórios". Devolve o aviso de erro, ou
  /// `null` se salvou.
  Future<String?> add(String id) => _saveSelection(_catalog.add(id));

  /// Tira de "Meus relatórios" (o relatório continua no catálogo).
  Future<String?> remove(String id) => _saveSelection(_catalog.remove(id));

  /// Muda a ordem: [newIndex] é a posição final (como em `onReorderItem`).
  Future<String?> move(int oldIndex, int newIndex) =>
      _saveSelection(_catalog.move(oldIndex, newIndex));

  /// Volta à lista sugerida, sem reabrir a configuração guiada.
  Future<String?> restoreSuggested() => _saveSelection(null);

  /// Configuração guiada: "Concluir" grava os escolhidos ([chosen], ao menos
  /// um); "Pular" mantém a lista sugerida.
  Future<String?> completeSetup(
    ReportSetupStatus status, {
    Set<String> chosen = const {},
  }) async {
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) return blocked;
    final previous = _current;
    final selection = status == ReportSetupStatus.done
        ? _catalog.fromSetup(chosen)
        : previous.selected;
    final changesList = !listEquals(selection, previous.selected);
    state = AsyncData(previous.withSelected(selection).withSetup(status));
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      if (changesList) await repo.setReportSelection(selection);
      await repo.completeReportSetup(status);
      return null;
    } on Object catch (e) {
      state = AsyncData(previous);
      return 'Não foi possível salvar a configuração: $e';
    }
  }

  /// Aplica na hora e grava; se falhar, a lista anterior volta.
  Future<String?> _saveSelection(List<String>? ids) async {
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) return blocked;
    final previous = _current;
    state = AsyncData(previous.withSelected(ids));
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      await repo.setReportSelection(ids);
      return null;
    } on Object catch (e) {
      state = AsyncData(previous);
      return 'Não foi possível salvar os relatórios: $e';
    }
  }
}

final reportPreferencesProvider =
    AsyncNotifierProvider<ReportPreferencesController, ReportPreferences>(
      ReportPreferencesController.new,
    );

/// Central pronta para a tela (registro + escolhas do usuário).
final reportCatalogProvider = Provider<ReportCatalog>(
  (ref) => ReportCatalog(
    ref.watch(reportRegistryProvider),
    ref.watch(reportPreferencesProvider).value ?? ReportPreferences.empty,
  ),
);
