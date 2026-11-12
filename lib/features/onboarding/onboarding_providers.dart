import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../preferences/preferences_providers.dart';
import '../sync/sync_providers.dart';

/// Etapas do assistente inicial (RF024; D6). O período é obrigatório e não é
/// uma etapa: vem antes, no primeiro acesso.
enum OnboardingStep {
  intro('intro', 'Como o Norte funciona'),
  categories('categories', 'Categorias sugeridas'),
  theme('theme', 'Tema'),
  security('security', 'Bloqueio do aplicativo'),
  recurrences('recurrences', 'Lançamentos que se repetem');

  const OnboardingStep(this.id, this.title);
  final String id;
  final String title;

  /// PIN e biometria só existem no celular.
  bool get availableHere => this != security || !kIsWeb;
}

/// Progresso salvo na conta (D7): etapa → `done` | `skipped`.
class OnboardingController extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    ref.watch(syncStatusProvider.select((s) => s.lastSyncAt));
    try {
      final repo = await ref.watch(preferencesRepositoryProvider.future);
      return await repo.onboarding();
    } on Object {
      return {};
    }
  }

  /// Etapas ainda sem resposta, na ordem do assistente.
  List<OnboardingStep> pending() {
    final progress = state.value ?? const {};
    return [
      for (final s in OnboardingStep.values)
        if (s.availableHere && !progress.containsKey(s.id)) s,
    ];
  }

  /// Grava a etapa. Devolve o aviso de erro, ou `null` se salvou.
  Future<String?> mark(OnboardingStep step, {required bool skipped}) async {
    final blocked = await ref.read(writeGateProvider).blockedReason();
    if (blocked != null) return blocked;
    final status = skipped ? 'skipped' : 'done';
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      await repo.setOnboardingStep(step.id, status);
      state = AsyncData({...?state.value, step.id: status});
      return null;
    } on Object catch (e) {
      return 'Não foi possível salvar a etapa: $e';
    }
  }
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingController, Map<String, String>>(
      OnboardingController.new,
    );
