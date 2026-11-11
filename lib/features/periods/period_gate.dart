import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../categories/category_providers.dart';
import '../categories/category_suggestions_screen.dart';
import 'period_providers.dart';
import 'period_setup_screen.dart';

/// Mostra o primeiro acesso (escolha do período) antes do app principal e
/// garante os períodos até hoje ao abrir.
class PeriodGate extends ConsumerWidget {
  const PeriodGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(periodGateProvider);
    return gate.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar seus períodos.'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(periodGateProvider),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
      data: (needsSetup) {
        if (needsSetup) return const PeriodSetupScreen();
        if (ref.watch(pendingSuggestionsProvider)) {
          return const CategorySuggestionsScreen();
        }
        return child;
      },
    );
  }
}
