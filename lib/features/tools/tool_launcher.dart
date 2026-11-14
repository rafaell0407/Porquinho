import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/tool_definition.dart';
import 'models/tool_preferences.dart';
import 'tools_providers.dart';
import 'widgets/tool_explanation.dart';

/// Abre uma ferramenta respeitando a modalidade de explicação dela. Toda
/// abertura passa por aqui; nenhuma tela decide pela ferramenta.
Future<void> openTool(
  BuildContext context,
  WidgetRef ref,
  ToolDefinition tool, {
  bool skipIntro = false,
}) async {
  if (!skipIntro && tool.introMode == ToolIntroMode.beforeFirstUse) {
    final prefs =
        ref.read(toolPreferencesProvider).value ?? ToolPreferences.empty;
    if (!prefs.dismissedIntros.contains(tool.id)) {
      final result = await Navigator.of(context, rootNavigator: true)
          .push<ToolIntroResult>(
            MaterialPageRoute(builder: (_) => ToolIntroScreen(tool: tool)),
          );
      if (result == null || !context.mounted) return;
      if (result.dontShowAgain) {
        final error = await ref
            .read(toolPreferencesProvider.notifier)
            .dismissIntro(tool.id);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      }
      if (!context.mounted) return;
    }
  }
  await context.push(tool.route);
}
