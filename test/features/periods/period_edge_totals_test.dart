@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

/// T7 — casos de borda de período conferidos de ponta a ponta no banco local:
/// lançamento → período calculado → total (RN001–RN004, RN036–RN037).
CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

void main() {
  late PorquinhoDatabase db;
  late LocalEntryRepository repo;
  late EntryService service;
  late PeriodService periods;
  late LocalTotalsRepository totals;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    final clock = DateTime.utc(2026, 11, 10);
    final recorder = LocalChangeRecorder(
      db,
      clock: () => clock,
      newId: () => 'a${++ids}',
    );
    periods = PeriodService(
      LocalPeriodRepository(db, 'u1', recorder, clock: () => clock),
    );
    final catRepo = LocalCategoryRepository(
      db,
      'u1',
      recorder,
      clock: () => clock,
    );
    repo = LocalEntryRepository(db, 'u1', recorder, clock: () => clock);
    service = EntryService(repo, catRepo, newId: () => 'e${++ids}');
    totals = LocalTotalsRepository(db, 'u1');
    await periods.setup(PeriodConfig.calendarMonth());
  });
  tearDown(() => db.close());

  Future<BigInt> surplus(CalendarDate date) async =>
      (await totals.totalsFor(await periods.periodFor(date))).surplus;

  Future<void> income(int cents, CalendarDate date) => service.create(
    EntryDraft(kind: EntryKind.income, amount: c(cents), date: date),
  );

  /// Um lançamento por data, com valor próprio (potências de 2: a soma de
  /// qualquer subconjunto é única, então um valor fora do lugar aparece).
  Future<Map<CalendarDate, int>> seed(List<CalendarDate> dates) async {
    final values = <CalendarDate, int>{};
    for (var i = 0; i < dates.length; i++) {
      values[dates[i]] = 100 * (1 << i);
      await income(values[dates[i]]!, dates[i]);
    }
    return values;
  }

  group('ciclo com dia 29, 30 e 31 (RN037)', () {
    test('dia 31 em ano bissexto: 29/02 abre o período, sem lacuna', () async {
      await periods.change(PeriodConfig.customCycle(31));
      final dates = [
        d(2028, 1, 30),
        d(2028, 1, 31),
        d(2028, 2, 28),
        d(2028, 2, 29),
        d(2028, 3, 30),
        d(2028, 3, 31),
        d(2028, 4, 29),
        d(2028, 4, 30),
      ];
      final v = await seed(dates);
      // [31/12, 31/01) · [31/01, 29/02) · [29/02, 31/03) · [31/03, 30/04) ·
      // [30/04, 31/05)
      expect(await surplus(d(2028, 1, 30)), c(v[d(2028, 1, 30)]!));
      expect(
        await surplus(d(2028, 1, 31)),
        c(v[d(2028, 1, 31)]! + v[d(2028, 2, 28)]!),
      );
      expect(
        await surplus(d(2028, 2, 29)),
        c(v[d(2028, 2, 29)]! + v[d(2028, 3, 30)]!),
      );
      expect(
        await surplus(d(2028, 3, 31)),
        c(v[d(2028, 3, 31)]! + v[d(2028, 4, 29)]!),
      );
      expect(await surplus(d(2028, 4, 30)), c(v[d(2028, 4, 30)]!));
    });

    test('dia 31 em ano comum: 28/02 abre o período', () async {
      await periods.change(PeriodConfig.customCycle(31));
      final dates = [d(2027, 2, 27), d(2027, 2, 28), d(2027, 3, 31)];
      final v = await seed(dates);
      expect(
        await periods.periodFor(d(2027, 2, 27)),
        PeriodRange(d(2027, 1, 31), d(2027, 2, 28)),
      );
      expect(await surplus(d(2027, 2, 27)), c(v[d(2027, 2, 27)]!));
      expect(await surplus(d(2027, 2, 28)), c(v[d(2027, 2, 28)]!));
      expect(await surplus(d(2027, 3, 31)), c(v[d(2027, 3, 31)]!));
    });

    for (final day in [29, 30]) {
      test('dia $day: fevereiro comum usa 28/02, bissexto usa 29/02', () async {
        await periods.change(PeriodConfig.customCycle(day));
        // Comum
        final common = await periods.periodFor(d(2027, 2, 28));
        expect(common.start, d(2027, 2, 28));
        expect(common.end, d(2027, 3, day));
        // Bissexto: dia 29 existe; dia 30 cai em 29/02.
        final leap = await periods.periodFor(d(2028, 2, 29));
        expect(leap.start, d(2028, 2, 29));
        expect(leap.end, d(2028, 3, day));
      });
    }

    for (final day in [29, 30, 31]) {
      test('dia $day: 5 anos seguidos, cada data em exatamente um período, '
          'soma dos períodos = soma dos lançamentos', () async {
        await periods.change(PeriodConfig.customCycle(day));
        var expected = BigInt.zero;
        for (
          var date = d(2027, 12, 1);
          date.isBefore(d(2029, 3, 5));
          date = date.addDays(1)
        ) {
          await income(100, date);
          expected += c(100);
        }
        // Percorre os períodos do primeiro ao último e soma tudo.
        final first = await periods.periodFor(d(2027, 12, 1));
        var cursor = first;
        var sum = BigInt.zero;
        var previousEnd = cursor.start;
        while (cursor.start.isBefore(d(2029, 3, 5))) {
          expect(cursor.start, previousEnd, reason: 'sem lacuna/sobreposição');
          sum += (await totals.totalsFor(cursor)).surplus;
          previousEnd = cursor.end;
          cursor = await periods.periodFor(cursor.end);
        }
        expect(sum, expected);
      });
    }
  });

  group('troca de configuração recalcula pelas datas (RN002)', () {
    test(
      'mesmos lançamentos, totais novos; voltar restaura os antigos',
      () async {
        await income(1000, d(2026, 11, 5));
        await income(2000, d(2026, 11, 25));
        await income(4000, d(2026, 12, 10));

        expect(await surplus(d(2026, 11, 10)), c(3000)); // novembro inteiro
        await periods.change(PeriodConfig.customCycle(20));
        // [20/10, 20/11) e [20/11, 20/12)
        expect(await surplus(d(2026, 11, 10)), c(1000));
        expect(await surplus(d(2026, 11, 25)), c(6000));
        await periods.change(PeriodConfig.calendarMonth());
        expect(await surplus(d(2026, 11, 10)), c(3000));
        expect(await surplus(d(2026, 12, 10)), c(4000));
      },
    );

    test('nada é contado duas vezes nem some na troca', () async {
      final dates = [for (var i = 0; i < 90; i++) d(2026, 9, 1).addDays(i)];
      for (final date in dates) {
        await income(100, date);
      }
      Future<BigInt> sumAll() async {
        var cursor = await periods.periodFor(dates.first);
        var sum = BigInt.zero;
        while (cursor.start.isBefore(dates.last.addDays(1))) {
          sum += (await totals.totalsFor(cursor)).surplus;
          cursor = await periods.periodFor(cursor.end);
        }
        return sum;
      }

      final expected = c(100 * dates.length);
      expect(await sumAll(), expected);
      await periods.change(PeriodConfig.customCycle(15));
      expect(await sumAll(), expected);
      await periods.change(PeriodConfig.customCycle(31));
      expect(await sumAll(), expected);
      await periods.change(PeriodConfig.calendarMonth());
      expect(await sumAll(), expected);
    });
  });

  group('despesa não paga depois do fim do período (RN017)', () {
    test('fica no período original; pagar noutro período não a move', () async {
      final id = await service.create(
        EntryDraft(
          kind: EntryKind.expense,
          amount: c(30000),
          date: d(2026, 10, 20),
          dueOn: d(2026, 10, 28),
        ),
      );
      expect(await surplus(d(2026, 10, 20)), c(-30000));
      // Passa o fim de outubro: segue em outubro, novembro não a vê.
      expect(await surplus(d(2026, 11, 10)), BigInt.zero);
      await service.pay(
        (await repo.entry(EntryKind.expense, id))!,
        d(2026, 11, 8),
      );
      expect(await surplus(d(2026, 10, 20)), c(-30000));
      expect(await surplus(d(2026, 11, 10)), BigInt.zero);
    });
  });
}
