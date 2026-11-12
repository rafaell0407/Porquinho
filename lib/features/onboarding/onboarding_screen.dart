import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../categories/category_suggestions_screen.dart';
import '../preferences/preferences_providers.dart';
import 'onboarding_providers.dart';

/// Assistente inicial com etapas opcionais (RF024). Mostra só as etapas ainda
/// sem resposta; "Pular" e "Concluir depois" estão sempre disponíveis.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({required this.onExit, super.key});

  /// Chamado ao terminar as etapas ou ao escolher "Concluir depois".
  final VoidCallback onExit;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  List<OnboardingStep>? _steps;
  int _index = 0;
  bool _busy = false;
  bool _categoriesSkipped = false;

  Future<void> _answer(OnboardingStep step, {required bool skipped}) async {
    setState(() => _busy = true);
    final error = await ref
        .read(onboardingProvider.notifier)
        .mark(step, skipped: skipped);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_index + 1 >= _steps!.length) {
      widget.onExit();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(onboardingProvider);
    if (progress.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _steps ??= ref.read(onboardingProvider.notifier).pending();
    final steps = _steps!;
    if (steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuração inicial')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tudo configurado. Você não tem etapas pendentes.',
                  key: Key('onboarding-vazio'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onExit,
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final step = steps[_index];
    if (step == OnboardingStep.categories) {
      // A tela de categorias tem os próprios botões; "Agora não" = pular.
      return CategorySuggestionsScreen(
        key: const Key('onboarding-categorias'),
        manageFlag: false,
        onSkipped: () {
          _categoriesSkipped = true;
          _answer(step, skipped: true);
        },
        onFinished: () {
          if (!_categoriesSkipped) _answer(step, skipped: false);
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(step.title), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Etapa ${_index + 1} de ${steps.length} (opcional)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _body(step),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('onboarding-avancar'),
            onPressed: _busy ? null : () => _answer(step, skipped: false),
            child: Text(_index + 1 >= steps.length ? 'Concluir' : 'Avançar'),
          ),
          TextButton(
            key: const Key('onboarding-pular'),
            onPressed: _busy ? null : () => _answer(step, skipped: true),
            child: const Text('Pular'),
          ),
          TextButton(
            key: const Key('onboarding-depois'),
            onPressed: _busy ? null : widget.onExit,
            child: const Text('Concluir depois'),
          ),
        ],
      ),
    );
  }

  Widget _body(OnboardingStep step) => switch (step) {
    OnboardingStep.intro => const Text(
      'O Norte mostra o seu dinheiro livre do período: o que você '
      'recebeu, menos o que gastou, menos o que destinou a investimentos. '
      'Ele não é um saldo bancário e não considera sobras de períodos '
      'anteriores.',
    ),
    OnboardingStep.theme => const _ThemeChoice(),
    OnboardingStep.security => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Você pode proteger o aplicativo com PIN ou biometria neste '
          'celular.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('onboarding-seguranca'),
          onPressed: () => context.push('/seguranca'),
          child: const Text('Configurar agora'),
        ),
      ],
    ),
    OnboardingStep.recurrences => const Text(
      'Salário, aluguel e a fatura do cartão se repetem todo mês? Cadastre-os '
      'como recorrências em Mais → Recorrências. O Norte cria os '
      'lançamentos de cada período para você; receitas só contam depois de '
      'confirmadas.',
    ),
    OnboardingStep.categories => const SizedBox.shrink(),
  };
}

class _ThemeChoice extends ConsumerWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return RadioGroup<ThemeMode>(
      groupValue: current,
      onChanged: (mode) async {
        if (mode == null) return;
        final messenger = ScaffoldMessenger.of(context);
        final error = await ref.read(themeModeProvider.notifier).choose(mode);
        if (error != null) {
          messenger.showSnackBar(SnackBar(content: Text(error)));
        }
      },
      child: const Column(
        children: [
          RadioListTile<ThemeMode>(
            key: Key('onb-tema-claro'),
            value: ThemeMode.light,
            title: Text('Claro'),
          ),
          RadioListTile<ThemeMode>(
            key: Key('onb-tema-escuro'),
            value: ThemeMode.dark,
            title: Text('Escuro'),
          ),
          RadioListTile<ThemeMode>(
            key: Key('onb-tema-aparelho'),
            value: ThemeMode.system,
            title: Text('Seguir o aparelho'),
          ),
        ],
      ),
    );
  }
}
