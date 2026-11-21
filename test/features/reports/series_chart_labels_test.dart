import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/reports/series_chart.dart';

void main() {
  group('A8: rótulos do eixo nos gráficos de evolução', () {
    test('com espaço sobrando, mostra todos', () {
      expect(axisLabelStep(count: 12, width: 900, labelWidth: 28), 1);
      expect(axisLabelStep(count: 6, width: 330, labelWidth: 28), 1);
    });

    test('12 períodos no celular: um sim, outro não', () {
      // ~330 px de gráfico, rótulo "01/11" ~28 px + folga 8 => 36 > 27,5.
      expect(axisLabelStep(count: 12, width: 330, labelWidth: 28), 2);
    });

    test('tela muito estreita pula mais', () {
      expect(axisLabelStep(count: 12, width: 200, labelWidth: 28), 3);
    });

    test('casos-limite não quebram', () {
      expect(axisLabelStep(count: 0, width: 330, labelWidth: 28), 1);
      expect(axisLabelStep(count: 1, width: 10, labelWidth: 28), 1);
      expect(axisLabelStep(count: 12, width: 0, labelWidth: 28), 1);
      expect(
        axisLabelStep(count: 12, width: double.infinity, labelWidth: 28),
        1,
      );
    });

    test('o período mais recente sempre tem rótulo', () {
      final shown = [
        for (var i = 0; i < 12; i++)
          if (showAxisLabel(i, 12, 2)) i,
      ];
      expect(shown, [1, 3, 5, 7, 9, 11]);
      expect(showAxisLabel(10, 11, 3), isTrue);
      expect(showAxisLabel(0, 1, 1), isTrue);
    });
  });
}
