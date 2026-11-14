import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/tool_catalog.dart';
import '../models/tool_definition.dart';
import '../registry/tool_registry.dart';
import '../tool_launcher.dart';
import '../tools_providers.dart';
import '../widgets/tool_cards.dart';
import '../widgets/tool_explanation.dart';

/// Aba Ferramentas: catálogo personalizável (busca, destaque, "Suas
/// ferramentas" e "Outras ferramentas"). Tudo vem do registro
/// (`tool_registry.dart`); a tela não conhece ferramenta nenhuma pelo nome.
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _categoryId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _categoryId = null;
    });
  }

  bool _matches(ToolDefinition t) =>
      toolMatches(t, query: _query, categoryId: _categoryId);

  void _open(ToolDefinition t) => openTool(context, ref, t);

  void _info(ToolDefinition t) => showToolInfoSheet(
    context,
    t,
    onOpen: () => openTool(context, ref, t, skipIntro: true),
  );

  Future<void> _add(ToolDefinition t) async {
    final error = await ref.read(toolPreferencesProvider.notifier).add(t.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(error ?? '${t.name} está em Suas ferramentas.')),
      );
  }

  void _customize() => context.push('/ferramentas/personalizar');

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(toolPreferencesProvider);
    final registry = ref.watch(toolRegistryProvider);
    final catalog = ref.watch(toolCatalogProvider);
    final filtering = _query.trim().isNotEmpty || _categoryId != null;

    final featured = catalog.featured.where(_matches).toList();
    final selected = catalog.selected.where(_matches).toList();
    final available = catalog.available.where(_matches).toList();
    final categories = registry.categories;
    final nothingFound =
        filtering && featured.isEmpty && selected.isEmpty && available.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: prefs.isLoading && !prefs.hasValue
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const Key('ferramentas-lista'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _Header(onCustomize: _customize),
                  const SizedBox(height: 16),
                  _SearchField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    onClear: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
                  if (categories.length > 1) ...[
                    const SizedBox(height: 12),
                    _CategoryFilter(
                      categories: categories,
                      selectedId: _categoryId,
                      onSelected: (id) => setState(() => _categoryId = id),
                    ),
                  ],
                  if (nothingFound)
                    _EmptyState(
                      key: const Key('ferramentas-sem-resultado'),
                      icon: Icons.search_off,
                      title: 'Nenhuma ferramenta encontrada',
                      message: _query.trim().isEmpty
                          ? 'Não há ferramentas nesta categoria.'
                          : 'Nada corresponde a “${_query.trim()}”.',
                      actionLabel: 'Limpar busca',
                      onAction: _clearFilters,
                    )
                  else ...[
                    for (final t in featured) ...[
                      const SizedBox(height: 20),
                      FeaturedToolCard(
                        tool: t,
                        onOpen: () => _open(t),
                        onInfo: () => _info(t),
                      ),
                    ],
                    _SectionTitle(
                      title: 'Suas ferramentas',
                      subtitle: catalog.selected.isEmpty
                          ? null
                          : 'Toque para abrir. Segure para personalizar.',
                    ),
                    if (catalog.selected.isEmpty)
                      _EmptyState(
                        key: const Key('ferramentas-nenhuma-escolhida'),
                        icon: Icons.home_repair_service_outlined,
                        title: 'Nenhuma ferramenta escolhida',
                        message:
                            'Adicione ferramentas abaixo, em Outras '
                            'ferramentas, ou restaure o padrão em Personalizar.',
                        actionLabel: 'Personalizar',
                        onAction: _customize,
                      )
                    else if (selected.isEmpty)
                      const _Hint(
                        'Nenhuma das suas ferramentas corresponde à busca.',
                      )
                    else
                      _ToolGrid(
                        tools: selected,
                        onOpen: _open,
                        onInfo: _info,
                        onLongPress: _customize,
                      ),
                    if (catalog.available.isNotEmpty || filtering) ...[
                      const _SectionTitle(
                        title: 'Outras ferramentas',
                        subtitle:
                            'Toque em + para levar para Suas ferramentas.',
                      ),
                      if (available.isEmpty)
                        _Hint(
                          catalog.available.isEmpty
                              ? 'Todas as ferramentas já estão em Suas ferramentas.'
                              : 'Nenhuma outra ferramenta corresponde à busca.',
                        )
                      else
                        _AvailableList(
                          tools: available,
                          grouped:
                              {for (final t in available) t.category}.length >
                              1,
                          onOpen: _open,
                          onInfo: _info,
                          onAdd: _add,
                        ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCustomize});

  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ferramentas',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Simulações e análises para decisões financeiras melhores.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          key: const Key('ferramentas-personalizar'),
          onPressed: onCustomize,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Personalizar'),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return TextField(
      key: const Key('ferramentas-busca'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar ferramenta',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
        ),
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Filtro por categoria (só aparece com mais de uma categoria no catálogo).
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ToolCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('ferramentas-categoria-todas'),
            label: const Text('Todas'),
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: Key('ferramentas-categoria-${c.id}'),
              label: Text(c.label),
              selected: selectedId == c.id,
              onSelected: (on) => onSelected(on ? c.id : null),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

/// Cartões compactos em colunas: duas no celular, mais em telas largas; uma
/// só em telas muito estreitas.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({
    required this.tools,
    required this.onOpen,
    required this.onInfo,
    required this.onLongPress,
  });

  final List<ToolDefinition> tools;
  final ValueChanged<ToolDefinition> onOpen;
  final ValueChanged<ToolDefinition> onInfo;
  final VoidCallback onLongPress;

  static const _gap = 10.0;
  static const _minWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _gap) ~/ (_minWidth + _gap))
            .clamp(1, 4);
        final rows = <Widget>[];
        for (var i = 0; i < tools.length; i += columns) {
          final slice = tools.skip(i).take(columns).toList();
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : _gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) const SizedBox(width: _gap),
                      Expanded(
                        child: c < slice.length
                            ? ToolCard(
                                tool: slice[c],
                                onOpen: () => onOpen(slice[c]),
                                onInfo: () => onInfo(slice[c]),
                                onLongPress: onLongPress,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

/// "Outras ferramentas": linhas com botão de adicionar; agrupadas por
/// categoria quando há mais de uma.
class _AvailableList extends StatelessWidget {
  const _AvailableList({
    required this.tools,
    required this.grouped,
    required this.onOpen,
    required this.onInfo,
    required this.onAdd,
  });

  final List<ToolDefinition> tools;
  final bool grouped;
  final ValueChanged<ToolDefinition> onOpen;
  final ValueChanged<ToolDefinition> onInfo;
  final ValueChanged<ToolDefinition> onAdd;

  Widget _row(ToolDefinition t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ToolRow(
      tool: t,
      onOpen: () => onOpen(t),
      onInfo: () => onInfo(t),
      trailing: IconButton.filledTonal(
        key: Key('ferramenta-adicionar-${t.id}'),
        tooltip: 'Adicionar a Suas ferramentas',
        icon: const Icon(Icons.add),
        onPressed: () => onAdd(t),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!grouped) return Column(children: [for (final t in tools) _row(t)]);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (category, items) in groupByCategory(tools)) ...[
          Padding(
            key: Key('ferramentas-grupo-${category.id}'),
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              category.label.toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (final t in items) _row(t),
        ],
      ],
    );
  }
}
