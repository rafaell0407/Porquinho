import 'package:flutter/material.dart';

import '../models/tool_definition.dart';
import 'tool_cards.dart' show ToolIconBadge;

/// Conteúdo da explicação de uma ferramenta: para que serve, como funciona,
/// premissas/limitações e, separado, o aviso. Usado no ícone de informação
/// (bottom sheet) e na explicação antes do primeiro uso.
class ToolExplanationView extends StatelessWidget {
  const ToolExplanationView({required this.tool, super.key});

  final ToolDefinition tool;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final e = tool.explanation;
    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
    final body = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section('Para que serve', Text(e.purpose, style: body)),
        section('Como funciona', Text(e.howItWorks, style: body)),
        if (e.assumptions.isNotEmpty)
          section(
            'Premissas e limitações',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in e.assumptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: body),
                        Expanded(child: Text(a, style: body)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (e.disclaimer != null)
          Container(
            key: Key('ferramenta-aviso-${tool.id}'),
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(e.disclaimer!, style: text.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Cabeçalho com ícone e nome, comum ao sheet e à tela de explicação.
class _ToolTitle extends StatelessWidget {
  const _ToolTitle(this.tool);

  final ToolDefinition tool;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ToolIconBadge(icon: tool.icon, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tool.name,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                tool.category.label,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ícone de informação: explicação completa (inclusive o aviso) a qualquer
/// momento, mesmo depois de "Não mostrar novamente". [onOpen], se informado,
/// mostra o botão "Abrir".
Future<void> showToolInfoSheet(
  BuildContext context,
  ToolDefinition tool, {
  VoidCallback? onOpen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
      ),
      child: SingleChildScrollView(
        key: Key('ferramenta-info-sheet-${tool.id}'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ToolTitle(tool),
            ToolExplanationView(tool: tool),
            const SizedBox(height: 20),
            if (onOpen != null)
              FilledButton(
                key: Key('ferramenta-info-abrir-${tool.id}'),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onOpen();
                },
                child: Text('Abrir ${tool.name}'),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Fechar'),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Resultado da explicação antes do primeiro uso.
class ToolIntroResult {
  const ToolIntroResult({required this.dontShowAgain});
  final bool dontShowAgain;
}

/// Modalidade B: explicação antes de abrir a ferramenta, com "Continuar" e
/// "Não mostrar novamente". Fechar sem continuar não abre a ferramenta.
class ToolIntroScreen extends StatefulWidget {
  const ToolIntroScreen({required this.tool, super.key});

  final ToolDefinition tool;

  @override
  State<ToolIntroScreen> createState() => _ToolIntroScreenState();
}

class _ToolIntroScreenState extends State<ToolIntroScreen> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return Scaffold(
      key: Key('ferramenta-intro-${tool.id}'),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ToolTitle(tool),
                    const SizedBox(height: 8),
                    Text(
                      tool.shortDescription,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    ToolExplanationView(tool: tool),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    key: const Key('ferramenta-intro-nao-mostrar'),
                    value: _dontShowAgain,
                    onChanged: (v) => setState(() => _dontShowAgain = v!),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Não mostrar novamente'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilledButton(
                      key: const Key('ferramenta-intro-continuar'),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ToolIntroResult(dontShowAgain: _dontShowAgain)),
                      child: const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
