import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../auth/auth_providers.dart';
import '../periods/period_providers.dart';
import '../sync/sync_providers.dart';
import 'preferences_repository.dart';

final preferencesRepositoryProvider = FutureProvider<PreferencesRepository>((
  ref,
) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemotePreferencesRepository(
      ref.watch(remoteTableReaderProvider),
      ref.watch(remoteGatewayProvider),
    );
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  final recorder = (await ref.watch(localRecorderProvider.future))!;
  return LocalPreferencesRepository(db, ref.watch(ownerIdProvider), recorder);
});

ThemeMode themeModeFrom(String? theme) => switch (theme) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String? themeToDb(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => null,
};

/// Tema do app. Sem sessão (login) ou sem escolha, segue o aparelho (D4). Lê
/// de novo depois de cada sincronização: um tema escolhido em outro aparelho
/// chega pelo download.
class ThemeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    ref.watch(syncStatusProvider.select((s) => s.lastSyncAt));
    try {
      final repo = await ref.watch(preferencesRepositoryProvider.future);
      return themeModeFrom(await repo.theme());
    } on Object {
      return ThemeMode.system;
    }
  }

  /// Aplica na hora e grava. Devolve o aviso de erro, ou `null` se salvou.
  /// Na Web, sem conexão, não grava e o tema anterior volta (porta de
  /// gravação).
  Future<String?> choose(ThemeMode mode) async {
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) return blocked;
    final previous = state.value ?? ThemeMode.system;
    state = AsyncData(mode);
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      await repo.setTheme(themeToDb(mode));
      return null;
    } on Object catch (e) {
      state = AsyncData(previous);
      return 'Não foi possível salvar o tema: $e';
    }
  }
}

final themeModeProvider = AsyncNotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
