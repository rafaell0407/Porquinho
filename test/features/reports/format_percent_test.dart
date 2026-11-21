import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/reports.dart';
import 'package:porquinho/features/reports/widgets/report_parts.dart';

/// A10 (21/11/2026): o percentual dos relatórios por categoria é arredondado
/// na 1ª casa, com meio para cima, em vez de cortado.
void main() {
  String percentOf(int part, int total) {
    final item = CategoryTotal(categoryId: 'a', amount: BigInt.from(part));
    final breakdown = CategoryBreakdown([item], BigInt.from(total));
    return formatPercent(breakdown.basisPoints(item));
  }

  test('arredonda para cima a partir do meio', () {
    expect(percentOf(503000, 566500), '88,8%'); // 88,79… (caso do T7)
    expect(percentOf(1235, 10000), '12,4%'); // 12,35 exato
    expect(percentOf(2, 3), '66,7%'); // 66,666…
  });

  test('arredonda para baixo abaixo do meio', () {
    expect(percentOf(123499, 1000000), '12,3%'); // 12,3499
    expect(percentOf(511000, 547000), '93,4%'); // 93,418…
    expect(percentOf(1, 3), '33,3%');
  });

  test('valores exatos e extremos', () {
    expect(percentOf(3, 4), '75,0%');
    expect(percentOf(1, 8), '12,5%');
    expect(percentOf(5, 5), '100,0%');
    expect(percentOf(0, 5), '0,0%');
    expect(percentOf(0, 0), '0,0%');
    expect(percentOf(1, 100000), '0,0%'); // 0,001%
    expect(percentOf(5, 10000), '0,1%'); // 0,05% exato
  });
}
