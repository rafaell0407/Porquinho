@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

import '../support/supabase_local_support.dart';

/// Entrega 71 (RF027): o que o aparelho calcula (Drift) é igual ao que o
/// servidor calcula (`get_period_report`) para os mesmos dados, incluindo
/// cenários de referência (arquitetura §12), mais de 1.000 linhas e valores
/// grandes.
BigInt c(int v) => BigInt.from(v);

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;

  test(
    'cenário de referência + volume: totais e categorias iguais no app e no '
    'servidor',
    () async {
      final account = await newTestAccount(r);
      final client = await account.device();
      final db = memoryDb();
      addTearDown(db.close);
      final recorder = LocalChangeRecorder(db);
      final periodRepo = LocalPeriodRepository(db, account.id, recorder);
      final periods = PeriodService(periodRepo);
      final catRepo = LocalCategoryRepository(db, account.id, recorder);
      final categories = CategoryService(catRepo);
      final entryRepo = LocalEntryRepository(db, account.id, recorder);
      final entries = EntryService(entryRepo, catRepo, periods);
      final investments = InvestmentService(
        LocalInvestmentRepository(db, account.id, recorder),
        periods,
      );
      final sync = SyncService(db, SupabaseSyncGateway(client));

      // Ciclo dia 20: o período de 05/11 vai de 20/10 a 19/11.
      final today = CalendarDate(2026, 11, 10);
      await periods.setup(PeriodConfig.customCycle(20), today);
      await categories.addSuggestions(
        income: ['Salário'],
        expense: ['Mercado', 'Moradia'],
      );
      final cats = (await categories.load()).categories;
      final salary = cats.firstWhere((x) => x.kind == CategoryKind.income);
      final market = cats.firstWhere((x) => x.name == 'Mercado');
      final home = cats.firstWhere((x) => x.name == 'Moradia');

      Future<String> add(
        EntryKind k,
        int cents,
        CalendarDate date, {
        String? cat,
        bool paid = false,
      }) => entries.create(
        EntryDraft(kind: k, amount: c(cents), date: date, categoryId: cat),
        alreadyPaid: paid,
        paidOn: date,
      );

      // Referência: recebimento, despesa avulsa, despesa paga (sem segunda
      // dedução), investimento, cancelamento e edição.
      final d1 = CalendarDate(2026, 11, 5);
      await add(EntryKind.income, 500000, d1, cat: salary.id);
      await add(EntryKind.expense, 120000, d1, cat: market.id);
      await add(EntryKind.expense, 30000, d1, cat: home.id, paid: true);
      final cancelled = await add(EntryKind.expense, 99999, d1);
      await entries.cancel(
        (await entryRepo.entry(EntryKind.expense, cancelled))!,
      );
      final edited = await add(EntryKind.expense, 1000, d1, cat: market.id);
      final record = (await entryRepo.entry(EntryKind.expense, edited))!;
      await entries.update(
        record,
        EntryDraft(
          kind: EntryKind.expense,
          amount: c(2500),
          date: d1,
          categoryId: market.id,
        ),
      );
      await investments.create(InvestmentDraft(amount: c(70000), date: d1));

      // Valor muito acima de 2^53 centavos (limite: 19 dígitos): precisa ser exato nos dois lados.
      final huge = BigInt.parse('9000000000000000123');
      await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: huge,
          date: d1,
          categoryId: salary.id,
        ),
      );

      // Volume: mais de 1.000 lançamentos no mesmo período.
      for (var i = 0; i < 1005; i++) {
        await add(
          i.isEven ? EntryKind.expense : EntryKind.income,
          100 + i,
          CalendarDate(2026, 11, 1 + (i % 15)),
          cat: i.isEven ? market.id : salary.id,
        );
      }

      // Envia tudo ao servidor.
      for (var i = 0; i < 6; i++) {
        await sync.syncOnce(account.id);
      }
      expect(await sync.operations(account.id), isEmpty);
      expect(await sync.openConflicts(account.id), isEmpty);

      final remote = RemoteReportsRepository(SupabaseReportSource(client));
      final local = LocalReportsRepository(db, account.id);
      final ids = [for (final p in await periodRepo.periods()) p.id];
      final lr = await local.report(ids);
      final rr = await remote.report(ids);

      for (final id in ids) {
        expect(rr.totalsOf(id), lr.totalsOf(id), reason: 'totais $id');
        expect(
          rr.incomeOf(id).toString(),
          lr.incomeOf(id).toString(),
          reason: 'receitas por categoria $id',
        );
        expect(
          rr.expenseOf(id).toString(),
          lr.expenseOf(id).toString(),
          reason: 'despesas por categoria $id',
        );
      }
      // O período do cenário tem os valores esperados.
      final current = (await periodRepo.periods()).firstWhere(
        (p) => p.range.contains(d1),
      );
      final totals = rr.totalsOf(current.id);
      expect(totals.investment, c(70000));
      expect(totals.income > huge, isTrue);
      expect(
        await RemoteTotalsRepository(remote).totalsFor(current.id),
        await LocalTotalsRepository(db, account.id).totalsFor(current.id),
      );
      // Mais de 1.000 linhas no servidor, sem truncar a soma.
      final count = await client
          .from('income_entries')
          .select('id')
          .eq('accounting_period_id', current.id)
          .count();
      expect(count.count, greaterThan(500));
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: skip,
  );
}
