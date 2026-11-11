import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'category_models.dart';
import 'category_providers.dart';

/// Sugestões do primeiro acesso (RN024): todas marcadas e desmarcáveis; as
/// escolhidas viram categorias comuns, sem tratamento especial.
class CategorySuggestionsScreen extends ConsumerStatefulWidget {
  const CategorySuggestionsScreen({this.onFinished, super.key});

  /// Chamado ao concluir ou pular; por padrão encerra o primeiro acesso.
  final VoidCallback? onFinished;

  @override
  ConsumerState<CategorySuggestionsScreen> createState() =>
      _CategorySuggestionsScreenState();
}

class _CategorySuggestionsScreenState
    extends ConsumerState<CategorySuggestionsScreen> {
  final _income = {...suggestedIncomeCategories};
  final _expense = {...suggestedExpenseCategories};
  bool _saving = false;
  String? _error;

  void _finish() {
    ref.read(pendingSuggestionsProvider.notifier).done();
    widget.onFinished?.call();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = await ref.read(categoryServiceProvider.future);
      await service.addSuggestions(income: _income, expense: _expense);
      ref.invalidate(categoryDataProvider);
      if (mounted) _finish();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar: $e';
        });
      }
    }
  }

  Widget _group(String title, List<String> all, Set<String> chosen) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      for (final name in all)
        CheckboxListTile(
          key: Key('sugestao-$name'),
          value: chosen.contains(name),
          title: Text(name),
          onChanged: (v) => setState(() {
            v == true ? chosen.add(name) : chosen.remove(name);
          }),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final total = _income.length + _expense.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias sugeridas')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Marque as categorias que quer começar usando. Você pode '
              'criar, renomear e desativar categorias depois, em Mais.',
            ),
          ),
          _group('Receitas', suggestedIncomeCategories, _income),
          _group('Despesas', suggestedExpenseCategories, _expense),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FilledButton(
                  onPressed: _saving || total == 0 ? null : _save,
                  child: Text(
                    _saving ? 'Salvando…' : 'Adicionar $total categorias',
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _finish,
                  child: const Text('Agora não'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
