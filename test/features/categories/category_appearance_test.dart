import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/app/theme/norte_theme.dart';
import 'package:porquinho/features/categories/category_appearance.dart';
import 'package:porquinho/features/categories/category_models.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('o ícone e a cor padrão existem no conjunto', () {
    expect(categoryIcons.containsKey(defaultCategoryIconKey), isTrue);
    expect(categoryColorKeys.contains(defaultCategoryColorKey), isTrue);
    expect(categoryColorKeys.length, 8, reason: 'igual ao CHECK do servidor');
    expect(categoryColorNames.keys.toSet(), categoryColorKeys.toSet());
  });

  test('chave desconhecida cai no padrão em vez de quebrar', () {
    expect(categoryIconFor('inexistente'), categoryIcons['category']);
    expect(
      categoryColorFor('inexistente', Brightness.dark),
      categoryColorFor('gray', Brightness.dark),
    );
  });

  test('as sugestões do primeiro acesso usam ícones e cores válidos', () {
    for (final name in [
      ...suggestedIncomeCategories,
      ...suggestedExpenseCategories,
    ]) {
      final look = suggestedCategoryAppearance[name];
      expect(look, isNotNull, reason: 'sem visual para "$name"');
      expect(categoryIcons.containsKey(look!.$1), isTrue, reason: name);
      expect(categoryColorKeys.contains(look.$2), isTrue, reason: name);
    }
  });

  for (final brightness in Brightness.values) {
    test('cores das categorias são visíveis no tema ${brightness.name}', () {
      final scheme = brightness == Brightness.dark
          ? NorteTheme.dark().colorScheme
          : NorteTheme.light().colorScheme;
      for (final key in categoryColorKeys) {
        final c = categoryColorFor(key, brightness);
        // 3:1 é o mínimo para elementos gráficos (ícones) sobre o fundo.
        expect(_contrast(c, scheme.surface), greaterThan(3), reason: key);
        expect(
          _contrast(c, scheme.surfaceContainerHighest),
          greaterThan(3),
          reason: key,
        );
      }
    });
  }

  test('a cor das categorias não repete as de receita e despesa', () {
    for (final brightness in Brightness.values) {
      final semantic = brightness == Brightness.dark
          ? NorteColors.dark
          : NorteColors.light;
      for (final key in categoryColorKeys) {
        final c = categoryColorFor(key, brightness);
        expect(c, isNot(semantic.income));
        expect(c, isNot(semantic.expense));
      }
    }
  });
}
