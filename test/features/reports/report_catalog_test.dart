import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/reports/domain/free_money_change.dart';
import 'package:porquinho/features/reports/domain/report_catalog.dart';
import 'package:porquinho/features/reports/models/report_definition.dart';
import 'package:porquinho/features/reports/models/report_preferences.dart';
import 'package:porquinho/features/reports/registry/report_registry.dart';

const _suggested = [
  'income_by_category',
  'expense_by_category',
  'investments_total',
  'free_money_evolution',
  'period_comparison',
];

ReportCatalog _catalog([ReportPreferences p = ReportPreferences.empty]) =>
    ReportCatalog(norteReportRegistry, p);

ReportDefinition _def(String id, {int? position}) => ReportDefinition(
  id: id,
  name: id,
  benefit: 'b',
  icon: Icons.abc,
  category: ReportCategory.overview,
  visualization: ReportVisualization.barsByPeriod,
  dataNeed: ReportDataNeed.series,
  suggestedPosition: position,
  build: (_) => const SizedBox(),
);

void main() {
  group('registro', () {
    test('os cinco do RF025, na ordem, todos na lista sugerida', () {
      expect(norteReportRegistry.reports.map((r) => r.id), _suggested);
      expect(norteReportRegistry.suggestedSelection, _suggested);
    });

    test('recusa ID repetido ou fora do formato', () {
      expect(() => ReportRegistry([_def('a'), _def('a')]), throwsArgumentError);
      expect(() => ReportRegistry([_def('Relatório')]), throwsArgumentError);
    });

    test('relatório novo fica fora da lista sugerida', () {
      final registry = ReportRegistry([_def('a', position: 0), _def('novo')]);
      expect(registry.suggestedSelection, ['a']);
      final catalog = ReportCatalog(registry, ReportPreferences.empty);
      expect(catalog.available.map((r) => r.id), ['novo']);
    });

    test('grupos em ordem fixa: Visão geral, Receitas e despesas, '
        'Investimentos', () {
      final groups = _catalog().groups;
      expect(groups.map((g) => g.$1), ReportCategory.values);
      expect(groups[0].$2.map((r) => r.id), [
        'free_money_evolution',
        'period_comparison',
      ]);
      expect(groups[1].$2.map((r) => r.id), [
        'income_by_category',
        'expense_by_category',
      ]);
      expect(groups[2].$2.map((r) => r.id), ['investments_total']);
    });
  });

  group('catálogo puro', () {
    test('sem escolha = lista sugerida; nada disponível', () {
      expect(_catalog().selected.map((r) => r.id), _suggested);
      expect(_catalog().available, isEmpty);
    });

    test('remover, adicionar no fim e mover', () {
      final removed = _catalog().remove('investments_total');
      expect(removed, isNot(contains('investments_total')));
      final c = _catalog(ReportPreferences(selected: removed));
      expect(c.available.map((r) => r.id), ['investments_total']);
      expect(c.add('investments_total').last, 'investments_total');
      expect(c.add('income_by_category'), removed); // já escolhido
      expect(c.add('nao_existe'), removed);
      expect(c.move(0, 3), [
        'expense_by_category',
        'free_money_evolution',
        'period_comparison',
        'income_by_category',
      ]);
      expect(c.move(9, 0), removed);
    });

    test('IDs desconhecidos ficam no fim e não aparecem', () {
      final c = _catalog(
        const ReportPreferences(
          selected: ['futuro', 'period_comparison', 'income_by_category'],
        ),
      );
      expect(c.selected.map((r) => r.id), [
        'period_comparison',
        'income_by_category',
      ]);
      expect(c.remove('period_comparison'), ['income_by_category', 'futuro']);
      expect(c.move(1, 0), [
        'income_by_category',
        'period_comparison',
        'futuro',
      ]);
      expect(c.add('investments_total'), [
        'period_comparison',
        'income_by_category',
        'investments_total',
        'futuro',
      ]);
    });

    test('lista vazia é escolha válida', () {
      final c = _catalog(const ReportPreferences(selected: []));
      expect(c.selected, isEmpty);
      expect(c.available.length, 5);
    });

    test('configuração guiada: ordem do RF025; os cinco = sugerida', () {
      expect(_catalog().fromSetup(_suggested.toSet()), isNull);
      expect(
        _catalog().fromSetup({'period_comparison', 'income_by_category'}),
        ['income_by_category', 'period_comparison'],
      );
      expect(
        _catalog(
          const ReportPreferences(selected: ['futuro']),
        ).fromSetup({'investments_total'}),
        ['investments_total', 'futuro'],
      );
    });
  });

  group('relatório 4: diferença para o período anterior', () {
    BigInt c(int v) => BigInt.from(v);

    test('selecionado − anterior, exato em centavos', () {
      expect(freeMoneyChangeFromPrevious([c(100), c(250), c(400)]), c(150));
      expect(freeMoneyChangeFromPrevious([c(400), c(250)]), c(-150));
      expect(freeMoneyChangeFromPrevious([c(-500), c(-200)]), c(300));
      expect(freeMoneyChangeFromPrevious([c(10), c(10)]), BigInt.zero);
      expect(
        freeMoneyChangeFromPrevious([
          BigInt.parse('9223372036854775807'),
          BigInt.parse('-9223372036854775807'),
        ]),
        BigInt.parse('-18446744073709551614'),
      );
    });

    test('sem período anterior: sem texto', () {
      expect(freeMoneyChangeFromPrevious([c(100)]), isNull);
      expect(freeMoneyChangeFromPrevious(const []), isNull);
    });
  });
}
