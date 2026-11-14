import 'package:flutter/material.dart';

import '../models/tool_definition.dart';

/// Ícone da ferramenta em quadrado arredondado Menta.
class ToolIconBadge extends StatelessWidget {
  const ToolIconBadge({required this.icon, this.size = 40, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: scheme.primary, size: size * 0.52),
    );
  }
}

/// Botão de informação (explicação sob demanda).
class ToolInfoButton extends StatelessWidget {
  const ToolInfoButton({
    required this.tool,
    required this.onPressed,
    super.key,
  });

  final ToolDefinition tool;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: Key('ferramenta-info-${tool.id}'),
      tooltip: 'Sobre ${tool.name}',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      iconSize: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      icon: const Icon(Icons.info_outline),
      onPressed: onPressed,
    );
  }
}

BoxDecoration _cardDecoration(ColorScheme scheme) => BoxDecoration(
  color: scheme.surfaceContainer,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: scheme.outlineVariant),
);

/// Cartão compacto de "Suas ferramentas": ícone, nome com informação e
/// descrição curta. Toque abre; toque longo leva à personalização.
class ToolCard extends StatelessWidget {
  const ToolCard({
    required this.tool,
    required this.onOpen,
    required this.onInfo,
    this.onLongPress,
    super.key,
  });

  final ToolDefinition tool;
  final VoidCallback onOpen;
  final VoidCallback onInfo;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: _cardDecoration(scheme),
        child: InkWell(
          key: Key('ferramenta-${tool.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToolIconBadge(icon: tool.icon),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tool.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ToolInfoButton(tool: tool, onPressed: onInfo),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    tool.shortDescription,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha de "Outras ferramentas" (e da personalização): ícone, nome com
/// informação, descrição e uma ação à direita (adicionar, remover…).
class ToolRow extends StatelessWidget {
  const ToolRow({
    required this.tool,
    required this.onInfo,
    required this.trailing,
    this.onOpen,
    this.leading,
    super.key,
  });

  final ToolDefinition tool;
  final VoidCallback onInfo;
  final Widget trailing;
  final VoidCallback? onOpen;

  /// Elemento antes do ícone (ex.: alça de arrastar).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: _cardDecoration(scheme),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                ?leading,
                ToolIconBadge(icon: tool.icon, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tool.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ToolInfoButton(tool: tool, onPressed: onInfo),
                        ],
                      ),
                      Text(
                        tool.shortDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartão maior da área "Em destaque" (só para ferramentas marcadas como
/// destaque no registro).
class FeaturedToolCard extends StatelessWidget {
  const FeaturedToolCard({
    required this.tool,
    required this.onOpen,
    required this.onInfo,
    super.key,
  });

  final ToolDefinition tool;
  final VoidCallback onOpen;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      key: Key('destaque-${tool.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.surfaceContainer],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Em destaque',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tool.name,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ToolInfoButton(tool: tool, onPressed: onInfo),
                  ],
                ),
                Text(
                  tool.shortDescription,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: Key('destaque-abrir-${tool.id}'),
                  onPressed: onOpen,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  iconAlignment: IconAlignment.end,
                  label: const Text('Abrir'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ToolIconBadge(icon: tool.icon, size: 56),
        ],
      ),
    );
  }
}
