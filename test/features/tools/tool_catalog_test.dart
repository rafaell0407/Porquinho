import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/tools/domain/tool_catalog.dart';
import 'package:porquinho/features/tools/models/tool_definition.dart';
import 'package:porquinho/features/tools/models/tool_preferences.dart';
import 'package:porquinho/features/tools/registry/tool_registry.dart';

ToolDefinition tool(
  String id, {
  ToolCategory category = ToolCategories.others,
  int? defaultPosition,
  bool featured = false,
  List<String> keywords = const [],
  String? name,
}) => ToolDefinition(
  id: id,
  name: name ?? 'Ferramenta $id',
  shortDescription: 'Descrição de $id',
  icon: Icons.build,
  category: category,
  route: '/$id',
  defaultPosition: defaultPosition,
  featured: featured,
  keywords: keywords,
  explanation: const ToolExplanation(purpose: 'p', howItWorks: 'h'),
);

List<String> ids(List<ToolDefinition> tools) => [for (final t in tools) t.id];

void main() {
  group('registro', () {
    test('o catálogo do app tem IDs únicos e válidos', () {
      final seen = <String>{};
      for (final t in norteToolRegistry.tools) {
        expect(toolIdPattern.hasMatch(t.id), isTrue, reason: t.id);
        expect(seen.add(t.id), isTrue, reason: 'ID repetido: ${t.id}');
      }
    });

    test('recusa ID repetido ou fora do formato', () {
      expect(() => ToolRegistry([tool('a'), tool('a')]), throwsArgumentError);
      expect(() => ToolRegistry([tool('Relatórios')]), throwsArgumentError);
      expect(() => ToolRegistry([tool('1abc')]), throwsArgumentError);
    });

    test('Relatórios é ferramenta real, padrão, em Análises', () {
      final reports = norteToolRegistry.byId('reports')!;
      expect(reports.route, '/relatorios');
      expect(reports.category, ToolCategories.analyses);
      expect(reports.introMode, ToolIntroMode.onDemand);
      expect(reports.explanation.disclaimer, isNotNull);
      expect(norteToolRegistry.defaultSelection, ['reports']);
    });

    test('padrão segue a posição definida, não a ordem de registro', () {
      final r = ToolRegistry([
        tool('a', defaultPosition: 2),
        tool('b'),
        tool('c', defaultPosition: 1),
      ]);
      expect(r.defaultSelection, ['c', 'a']);
    });

    test('categorias: só as usadas, na ordem definida', () {
      final r = ToolRegistry([
        tool('a', category: ToolCategories.others),
        tool('b', category: ToolCategories.investments),
        tool('c', category: ToolCategories.others),
      ]);
      expect(r.categories, [ToolCategories.investments, ToolCategories.others]);
    });
  });

  group('catálogo e personalização', () {
    final registry = ToolRegistry([
      tool('a', defaultPosition: 0),
      tool('b', defaultPosition: 1),
      tool('c'),
      tool('d', featured: true),
    ]);

    test('sem escolha, usa o padrão; o resto fica em Outras', () {
      final c = ToolCatalog(registry, ToolPreferences.empty);
      expect(ids(c.selected), ['a', 'b']);
      expect(ids(c.available), ['c', 'd']);
      expect(ids(c.featured), ['d']);
    });

    test('adicionar vai para o fim e sai de Outras', () {
      final c = ToolCatalog(registry, ToolPreferences.empty);
      final next = c.add('c');
      expect(next, ['a', 'b', 'c']);
      final after = ToolCatalog(registry, ToolPreferences(selected: next));
      expect(ids(after.available), ['d']);
      // Já escolhida ou desconhecida: nada muda (sem duplicar).
      expect(after.add('c'), ['a', 'b', 'c']);
      expect(after.add('zzz'), ['a', 'b', 'c']);
    });

    test('remover volta para Outras; lista vazia é válida', () {
      final c = ToolCatalog(registry, const ToolPreferences(selected: ['a']));
      final next = c.remove('a');
      expect(next, isEmpty);
      final after = ToolCatalog(registry, ToolPreferences(selected: next));
      expect(after.selected, isEmpty);
      expect(ids(after.available), ['a', 'b', 'c', 'd']);
      expect(after.preferences.isDefault, isFalse);
    });

    test('reordenar', () {
      final c = ToolCatalog(
        registry,
        const ToolPreferences(selected: ['a', 'b', 'c']),
      );
      expect(c.move(0, 2), ['b', 'c', 'a']);
      expect(c.move(2, 0), ['c', 'a', 'b']);
      expect(c.move(1, 1), ['a', 'b', 'c']);
      expect(c.move(9, 0), ['a', 'b', 'c']);
    });

    test('nova ferramenta registrada não muda as escolhas nem a ordem', () {
      const prefs = ToolPreferences(selected: ['b', 'a']);
      final before = ToolCatalog(registry, prefs);
      final grown = ToolRegistry([...registry.tools, tool('novo')]);
      final after = ToolCatalog(grown, prefs);
      expect(ids(after.selected), ids(before.selected));
      expect(ids(after.available), ['c', 'd', 'novo']);
      expect(after.add('novo'), ['b', 'a', 'novo']);
    });

    test('ferramenta desconhecida (de outra versão) é preservada', () {
      const prefs = ToolPreferences(selected: ['b', 'futura', 'a']);
      final c = ToolCatalog(registry, prefs);
      expect(ids(c.selected), ['b', 'a']);
      expect(c.isSelected('futura'), isTrue);
      expect(c.move(0, 1), ['a', 'b', 'futura']);
      expect(c.remove('b'), ['a', 'futura']);
      expect(c.add('c'), ['b', 'a', 'c', 'futura']);
    });

    test('dispensa da explicação é por ferramenta', () {
      final c = ToolCatalog(
        registry,
        const ToolPreferences(dismissedIntros: {'a'}),
      );
      expect(c.introDismissed('a'), isTrue);
      expect(c.introDismissed('b'), isFalse);
    });
  });

  group('busca e categorias', () {
    final simulacao = tool(
      'sim',
      name: 'Simulação de crédito',
      category: ToolCategories.purchasesAndCredit,
      keywords: ['empréstimo'],
    );

    test('pelo nome, descrição e termos, sem acento nem maiúsculas', () {
      expect(toolMatches(simulacao, query: 'SIMULACAO'), isTrue);
      expect(toolMatches(simulacao, query: 'credito'), isTrue);
      expect(toolMatches(simulacao, query: 'emprestimo'), isTrue);
      expect(toolMatches(simulacao, query: 'descrição sim'), isTrue);
      expect(toolMatches(simulacao, query: 'carteira'), isFalse);
      expect(toolMatches(simulacao, query: '   '), isTrue);
    });

    test('Relatórios é encontrado pela busca', () {
      expect(toolMatches(reportsTool, query: 'relatorio'), isTrue);
      expect(toolMatches(reportsTool, query: 'despesas'), isTrue);
    });

    test('filtro por categoria', () {
      expect(
        toolMatches(
          simulacao,
          categoryId: ToolCategories.purchasesAndCredit.id,
        ),
        isTrue,
      );
      expect(
        toolMatches(simulacao, categoryId: ToolCategories.analyses.id),
        isFalse,
      );
    });

    test('agrupa na ordem das categorias, mantendo a ordem interna', () {
      final groups = groupByCategory([
        tool('x', category: ToolCategories.others),
        tool('y', category: ToolCategories.investments),
        tool('z', category: ToolCategories.others),
      ]);
      expect(groups.map((g) => g.$1), [
        ToolCategories.investments,
        ToolCategories.others,
      ]);
      expect(ids(groups.last.$2), ['x', 'z']);
    });
  });

  group('formato gravado', () {
    test('sem lista = padrão; lista vazia é escolha', () {
      expect(ToolPreferences.decode('{}').isDefault, isTrue);
      expect(ToolPreferences.decode(null).isDefault, isTrue);
      expect(ToolPreferences.decode('lixo').isDefault, isTrue);
      final empty = ToolPreferences.decode('{"selected": []}');
      expect(empty.isDefault, isFalse);
      expect(empty.selected, isEmpty);
    });

    test('ida e volta, ignorando IDs inválidos e repetidos', () {
      const prefs = ToolPreferences(
        selected: ['b', 'a'],
        dismissedIntros: {'a'},
      );
      expect(ToolPreferences.decode(prefs.encode()), prefs);
      expect(
        ToolPreferences.decode({
          'selected': ['a', 'A!', 3, 'a', 'b'],
          'dismissed_intros': ['x', null],
        }),
        const ToolPreferences(selected: ['a', 'b'], dismissedIntros: {'x'}),
      );
      expect(const ToolPreferences().toJson(), isEmpty);
    });
  });
}
