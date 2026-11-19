import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/import/domain/category_resolution.dart';
import 'package:porquinho/features/import/domain/duplicate_detection.dart';
import 'package:porquinho/features/import/domain/existing_data.dart';
import 'package:porquinho/features/import/domain/import_models.dart';

ImportRow _row(
  int line, {
  RowKind kind = RowKind.expense,
  int amount = 1000,
  CalendarDate? date,
  String? desc,
  String? cat,
  String? sub,
  String? id,
}) => ImportRow(
  sourceRow: line,
  kind: kind,
  amount: BigInt.from(amount),
  date: date ?? CalendarDate(2026, 1, 5),
  state: kind == RowKind.income
      ? EntryState.received
      : kind == RowKind.investment
      ? EntryState.active
      : EntryState.pending,
  description: desc,
  categoryName: cat,
  subcategoryName: sub,
  norteId: id,
);

void main() {
  group('categorias', () {
    final existing = ExistingData(
      categories: const [
        ExistingCategory(
          id: 'c-casa',
          kind: CategoryKind.expense,
          name: 'Casa',
          active: true,
        ),
        ExistingCategory(
          id: 'c-velha',
          kind: CategoryKind.expense,
          name: 'Lazer',
          active: false,
        ),
        ExistingCategory(
          id: 'c-casa-receita',
          kind: CategoryKind.income,
          name: 'Casa',
          active: true,
        ),
      ],
      subcategories: const [
        ExistingSubcategory(
          id: 's-luz',
          categoryId: 'c-casa',
          name: 'Luz',
          active: true,
        ),
      ],
    );

    test('nomes por tipo, com subcategorias e linhas de categoria', () {
      final needs = collectCategoryNeeds(
        [
          _row(2, cat: 'casa', sub: 'luz'),
          _row(3, cat: 'Casa', sub: 'Água'),
          _row(4, kind: RowKind.income, cat: 'Casa'),
          _row(5, kind: RowKind.investment),
        ],
        const [
          CategoryRow(sourceRow: 6, kind: CategoryKind.expense, name: 'Lazer'),
          CategoryRow(
            sourceRow: 7,
            kind: CategoryKind.expense,
            name: 'Gás',
            parentName: 'Casa',
          ),
        ],
      );
      expect(needs.map((n) => n.key), [
        'expense|lazer',
        'expense|casa',
        'income|casa',
      ]);
      final casa = needs[1];
      expect(casa.rows, 2);
      expect(casa.subs.keys, [
        'expense|casa|gas',
        'expense|casa|luz',
        'expense|casa|agua',
      ]);
    });

    test('sugestão: existente ativa do mesmo tipo; inativa vira nova', () {
      final needs = collectCategoryNeeds([
        _row(2, cat: 'CASA', sub: 'luz'),
        _row(3, cat: 'Lazer'),
        _row(4, cat: 'Casa', sub: 'Gás'),
      ], const []);
      final choices = suggestCategoryChoices(needs, existing);
      expect(choices['expense|casa'], const CategoryChoice.existing('c-casa'));
      expect(
        choices['expense|casa|luz'],
        const CategoryChoice.existing('s-luz'),
      );
      expect(choices['expense|casa|gas'], const CategoryChoice.create());
      // Inativa nunca é reativada: sugere criar uma nova com o mesmo nome.
      expect(choices['expense|lazer'], const CategoryChoice.create());
      expect(categoryProblems(needs, choices, existing), isEmpty);
    });

    test('problemas: inativa, outro tipo, sub de outra categoria', () {
      final needs = collectCategoryNeeds([
        _row(2, cat: 'Lazer'),
        _row(3, cat: 'Casa', sub: 'Luz'),
      ], const []);
      final p = categoryProblems(needs, {
        'expense|lazer': const CategoryChoice.existing('c-velha'),
        'expense|casa': const CategoryChoice.existing('c-casa-receita'),
        'expense|casa|luz': const CategoryChoice.existing('s-luz'),
      }, existing);
      expect(p, hasLength(3));
    });

    test('sem categoria força sem subcategoria', () {
      final needs = collectCategoryNeeds([
        _row(3, cat: 'Casa', sub: 'Luz'),
      ], const []);
      final p = categoryProblems(needs, {
        'expense|casa': const CategoryChoice.none(),
        'expense|casa|luz': const CategoryChoice.create(),
      }, existing);
      expect(p.single, contains('sem subcategoria'));
    });

    test('resolução por linha', () {
      final choices = {
        'expense|casa': const CategoryChoice.existing('c-casa'),
        'expense|casa|gas': const CategoryChoice.create(),
        'expense|novo': const CategoryChoice.create(),
        'expense|nada': const CategoryChoice.none(),
      };
      final a = resolveCategory(_row(2, cat: 'Casa', sub: 'Gás'), choices);
      expect(a.categoryId, 'c-casa');
      expect(a.newSubKey, 'expense|casa|gas');
      final b = resolveCategory(_row(3, cat: 'Novo'), choices);
      expect(b.newCategoryKey, 'expense|novo');
      expect(resolveCategory(_row(4, cat: 'Nada'), choices).isNone, isTrue);
      expect(resolveCategory(_row(5), choices).isNone, isTrue);
    });
  });

  group('duplicidades', () {
    test('dentro do arquivo: valores iguais e id do Norte repetido', () {
      final rows = [
        _row(2, desc: 'Luz', cat: 'Casa'),
        _row(3, desc: 'luz ', cat: 'casa'),
        _row(4, desc: 'Água', id: 'x'),
        _row(5, desc: 'Gás', id: 'x'),
      ];
      final g = detectDuplicates(rows, const ExistingData(), fileSha256: 'h');
      expect(g, hasLength(2));
      final byId = g.firstWhere((x) => x.strong);
      expect(byId.rows, [4, 5]);
      expect(byId.rowsIgnoredOnIgnore, [5]);
      final byValues = g.firstWhere((x) => !x.strong);
      expect(byValues.rows, [2, 3]);
      expect(byValues.rowsIgnoredOnIgnore, [3]);
    });

    test('contra o banco: tipo, data e valor; id do Norte é sinal forte', () {
      final existing = ExistingData(
        entries: [
          ExistingEntry(
            id: 'e1',
            kind: RowKind.expense,
            date: CalendarDate(2026, 1, 5),
            amount: BigInt.from(1000),
            cancelled: false,
            description: 'Luz',
          ),
          ExistingEntry(
            id: 'e2',
            kind: RowKind.expense,
            date: CalendarDate(2026, 1, 6),
            amount: BigInt.from(1000),
            cancelled: true,
          ),
          ExistingEntry(
            id: 'norte-1',
            kind: RowKind.income,
            date: CalendarDate(2025, 1, 1),
            amount: BigInt.from(1),
            cancelled: false,
          ),
        ],
      );
      final g = detectDuplicates(
        [
          _row(2, desc: 'LUZ'),
          _row(3, date: CalendarDate(2026, 1, 6)),
          _row(4, kind: RowKind.income, id: 'norte-1', amount: 999),
          _row(5, kind: RowKind.income),
        ],
        existing,
        fileSha256: 'h',
      );
      expect(g.map((x) => x.id), ['db:2', 'db:4']);
      expect(g[0].sameDescription, isTrue);
      expect(g[0].strong, isFalse);
      expect(g[1].strong, isTrue);
      expect(g[1].matches.single.id, 'norte-1');
    });

    test('arquivo já importado e decisões', () {
      final rows = [_row(2), _row(3, amount: 5)];
      final existing = ExistingData(
        imports: [
          PreviousImport(
            batchId: 'b',
            fileName: 'x.csv',
            fileSha256: 'h',
            createdAt: DateTime.utc(2026),
          ),
        ],
      );
      final g = detectDuplicates(rows, existing, fileSha256: 'h');
      expect(g.single.kind, DuplicateKind.fileAlreadyImported);
      expect(undecidedGroups(g, const {}), 1);
      expect(ignoredRows(g, {'file': DuplicateDecision.ignore}), {2, 3});
      expect(ignoredRows(g, {'file': DuplicateDecision.importAnyway}), isEmpty);
      expect(detectDuplicates(rows, existing, fileSha256: 'outro'), isEmpty);
    });
  });
}
