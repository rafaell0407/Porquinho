import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_providers.dart';

/// Mais → Tema: claro, escuro ou seguir o aparelho (RF026; D4).
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'O tema escolhido vale para toda a sua conta, no celular e no '
            'navegador.',
          ),
          const SizedBox(height: 8),
          RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (mode) async {
              if (mode == null) return;
              final messenger = ScaffoldMessenger.of(context);
              final error = await ref
                  .read(themeModeProvider.notifier)
                  .choose(mode);
              if (error != null) {
                messenger.showSnackBar(SnackBar(content: Text(error)));
              }
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  key: Key('tema-claro'),
                  value: ThemeMode.light,
                  title: Text('Claro'),
                ),
                RadioListTile<ThemeMode>(
                  key: Key('tema-escuro'),
                  value: ThemeMode.dark,
                  title: Text('Escuro'),
                ),
                RadioListTile<ThemeMode>(
                  key: Key('tema-aparelho'),
                  value: ThemeMode.system,
                  title: Text('Seguir o aparelho'),
                  subtitle: Text('Usa o tema do celular ou do navegador'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
