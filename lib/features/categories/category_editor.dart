import 'package:flutter/material.dart';

import 'category_appearance.dart';
import 'category_service.dart';

/// Nome, ícone e cor escolhidos para uma categoria.
class CategoryDraft {
  const CategoryDraft(this.name, this.iconKey, this.colorKey);

  final String name;
  final String iconKey;
  final String colorKey;
}

/// Folha para criar ou editar uma categoria: nome, ícone e cor, com prévia.
/// Valida o nome como o servidor (não vazio, até 60 caracteres).
Future<CategoryDraft?> showCategoryEditor(
  BuildContext context, {
  required String title,
  String initialName = '',
  String initialIcon = defaultCategoryIconKey,
  String initialColor = defaultCategoryColorKey,
}) {
  return showModalBottomSheet<CategoryDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryEditor(
      title: title,
      initialName: initialName,
      initialIcon: initialIcon,
      initialColor: initialColor,
    ),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    required this.title,
    required this.initialName,
    required this.initialIcon,
    required this.initialColor,
  });

  final String title;
  final String initialName;
  final String initialIcon;
  final String initialColor;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late String _icon = categoryIcons.containsKey(widget.initialIcon)
      ? widget.initialIcon
      : defaultCategoryIconKey;
  late String _color = categoryColorKeys.contains(widget.initialColor)
      ? widget.initialColor
      : defaultCategoryColorKey;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = CategoryService.validateName(_name.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.pop(context, CategoryDraft(_name.text.trim(), _icon, _color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Center(
              child: CategoryBadge(
                key: const Key('previa-categoria'),
                iconKey: _icon,
                colorKey: _color,
                size: 64,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('campo-nome'),
              controller: _name,
              autofocus: true,
              maxLength: CategoryService.maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Nome', errorText: _error),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Text('Ícone', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in categoryIcons.entries)
                  _IconChoice(
                    key: Key('icone-${entry.key}'),
                    icon: entry.value,
                    selected: entry.key == _icon,
                    onTap: () => setState(() => _icon = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Cor', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final key in categoryColorKeys)
                  _ColorChoice(
                    key: Key('cor-$key'),
                    label: categoryColorNames[key]!,
                    color: categoryColorFor(key, theme.brightness),
                    selected: key == _color,
                    onTap: () => setState(() => _color = key),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('salvar-categoria'),
                    onPressed: _submit,
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surfaceContainerHighest,
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(icon, size: 22, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
