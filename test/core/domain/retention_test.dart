import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/retention.dart';

void main() {
  group('Retention (D15)', () {
    test('limite = 12 meses antes, no mesmo instante (UTC)', () {
      expect(
        Retention.cutoff(DateTime.utc(2026, 11, 18, 3, 17, 5, 123)),
        DateTime.utc(2025, 11, 18, 3, 17, 5, 123),
      );
    });

    test('dia inexistente usa o último dia do mês, como o PostgreSQL', () {
      // SELECT '2028-02-29'::timestamptz - interval '12 months' = 2027-02-28
      expect(
        Retention.monthsBefore(DateTime.utc(2028, 2, 29, 10), 12),
        DateTime.utc(2027, 2, 28, 10),
      );
      // 31/03 − 1 mês = 28/02 (ou 29 em ano bissexto).
      expect(
        Retention.monthsBefore(DateTime.utc(2027, 3, 31), 1),
        DateTime.utc(2027, 2, 28),
      );
      expect(
        Retention.monthsBefore(DateTime.utc(2028, 3, 31), 1),
        DateTime.utc(2028, 2, 29),
      );
      // Virada de ano.
      expect(
        Retention.monthsBefore(DateTime.utc(2026, 1, 15), 11),
        DateTime.utc(2025, 2, 15),
      );
    });

    test('horário local é convertido para UTC antes da conta', () {
      final local = DateTime.utc(2026, 11, 18, 2).toLocal();
      expect(Retention.cutoff(local), DateTime.utc(2025, 11, 18, 2));
    });

    test('download completo: nunca feito ou há 11 meses ou mais', () {
      final now = DateTime.utc(2026, 11, 18, 12);
      expect(Retention.needsFullDownload(null, now), isTrue);
      expect(
        Retention.needsFullDownload(DateTime.utc(2025, 12, 18, 12), now),
        isTrue,
        reason: 'exatamente 11 meses',
      );
      expect(
        Retention.needsFullDownload(DateTime.utc(2025, 12, 18, 13), now),
        isFalse,
      );
      expect(
        Retention.needsFullDownload(DateTime.utc(2026, 11, 17), now),
        isFalse,
      );
    });

    test('a margem do download completo é menor que a retenção', () {
      expect(Retention.fullDownloadAfterMonths, lessThan(Retention.months));
    });
  });
}
