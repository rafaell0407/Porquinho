import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/app/theme/norte_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = {'claro': NorteTheme.light(), 'escuro': NorteTheme.dark()};

  for (final entry in themes.entries) {
    group('tema ${entry.key}', () {
      final theme = entry.value;
      final scheme = theme.colorScheme;
      final norte = theme.extension<NorteColors>()!;

      test('usa a fonte Inter', () {
        expect(theme.textTheme.bodyMedium?.fontFamily, NorteTheme.fontFamily);
      });

      test('texto principal e secundário são legíveis (mín. 4,5:1)', () {
        expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThan(4.5),
        );
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surfaceContainer),
          greaterThan(4.5),
        );
      });

      test('botão de destaque é legível', () {
        expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
        expect(_contrast(scheme.onError, scheme.error), greaterThan(4.5));
      });

      test(
        'cores de receita, despesa, investimento e pendente são legíveis',
        () {
          for (final c in [
            norte.income,
            norte.expense,
            norte.investment,
            norte.pending,
          ]) {
            expect(_contrast(c, scheme.surface), greaterThan(4.5));
            expect(_contrast(c, scheme.surfaceContainer), greaterThan(4.5));
          }
        },
      );

      test('receita, despesa e investimento são cores diferentes', () {
        expect({norte.income, norte.expense, norte.investment}.length, 3);
      });
    });
  }

  testWidgets('tema escuro e claro renderizam botões e campos', (tester) async {
    for (final theme in themes.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(onPressed: () {}, child: const Text('Salvar')),
                const TextField(decoration: InputDecoration(labelText: 'Nome')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Salvar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
