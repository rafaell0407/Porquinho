@TestOn('browser')
@Tags(['supabase_local'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/recurrence_schedule.dart';
import 'package:porquinho/features/attention/remote_attention_repository.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/remote_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/remote_entry_repository.dart';
import 'package:porquinho/features/export/export_screen.dart';
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/remote_investment_recurrence_repository.dart';
import 'package:porquinho/features/investments/remote_investment_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/periods/remote_period_repository.dart';
import 'package:porquinho/features/recurrence/remote_recurrence_repository.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/totals/totals_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// T8: paridade de BRL e datas na Web × PostgreSQL (o Drift × PostgreSQL já é
/// coberto por `test/integration/parity_test.dart`, com o mesmo tipo de valor).
///
/// Roda NO NAVEGADOR contra o Supabase LOCAL, pelos mesmos repositórios que a
/// Web usa. A conta é criada antes, fora do navegador (o Supabase recusa a
/// chave secreta vinda do navegador): `tooling/test_web_parity.ps1`.
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _email = String.fromEnvironment('WEB_TEST_EMAIL');
const _password = String.fromEnvironment('WEB_TEST_PASSWORD');
const _enabled = _url != '' && _key != '' && _email != '' && _password != '';

final max64 = BigInt.parse('9223372036854775807'); // 2^63 − 1 (RN045)
final above53 = BigInt.parse('9007199254740993'); // 2^53 + 1
final huge = BigInt.parse('9000000000000000123');

void main() {
  test(
    'valores acima de 2^53 e datas chegam exatos na Web',
    () async {
      final client = SupabaseClient(_url, _key);
      await client.auth.signInWithPassword(email: _email, password: _password);
      final reader = SupabaseTableReader(client);
      final gateway = SupabaseSyncGateway(client);

      final periods = PeriodService(RemotePeriodRepository(reader, gateway));
      await periods.setup(PeriodConfig.calendarMonth());
      final catRepo = RemoteCategoryRepository(reader, gateway);
      final categories = CategoryService(catRepo);
      await categories.addSuggestions(income: ['Salário'], expense: ['Casa']);
      final cats = (await categories.load()).categories;
      final salary = cats.firstWhere((c) => c.kind == CategoryKind.income);
      final home = cats.firstWhere((c) => c.kind == CategoryKind.expense);

      final entryRepo = RemoteEntryRepository(reader, gateway);
      final recurrences = RemoteRecurrenceRepository(reader, gateway);
      final entries = EntryService(
        entryRepo,
        catRepo,
        recurrences: recurrences,
      );
      final investmentRepo = RemoteInvestmentRepository(reader, gateway);
      final investments = InvestmentService(investmentRepo);

      // Datas de borda: último dia do mês e 1º do mês seguinte.
      final d1 = CalendarDate(2026, 10, 31);
      final next = CalendarDate(2026, 11, 1);
      final incomeId = await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: max64,
          date: d1,
          categoryId: salary.id,
        ),
      );
      final expenseId = await entries.create(
        EntryDraft(
          kind: EntryKind.expense,
          amount: above53,
          date: d1,
          categoryId: home.id,
        ),
      );
      final investmentId = await investments.create(
        InvestmentDraft(amount: huge, date: d1),
      );
      // Recorrência (receita: a ocorrência fica pendente e não entra no
      // período) e investimento recorrente, ambos no mês seguinte.
      final recurringId = await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: above53,
          date: next,
          categoryId: salary.id,
        ),
        repeat: const RepeatChoice(frequency: RecurrenceFrequency.monthly),
      );
      final recurringInvestmentId = await investments.create(
        InvestmentDraft(amount: max64, date: next),
        repeat: RecurrenceFrequency.monthly,
      );

      // Prova do defeito: a leitura sem texto perde exatidão no navegador.
      final raw = await client
          .from('income_entries')
          .select('amount_centavos')
          .eq('id', incomeId)
          .single();
      expect('${raw['amount_centavos']}', isNot(max64.toString()));

      // Lançamento a lançamento, pelos repositórios da Web.
      final income = (await entryRepo.entry(EntryKind.income, incomeId))!;
      expect(income.amount, max64);
      expect(income.date, d1);
      final expense = (await entryRepo.entry(EntryKind.expense, expenseId))!;
      expect(expense.amount, above53);
      expect(expense.date, d1);
      final investment = (await investmentRepo.investment(investmentId))!;
      expect(investment.amount, huge);
      expect(investment.date, d1);

      final occurrence = (await entryRepo.entry(
        EntryKind.income,
        recurringId,
      ))!;
      final template = (await recurrences.template(
        EntryKind.income,
        occurrence.templateId!,
      ))!;
      expect(template.defaultAmount, above53);
      final investmentOccurrence = (await investmentRepo.investment(
        recurringInvestmentId,
      ))!;
      final investmentTemplate = (await RemoteInvestmentRecurrenceRepository(
        reader,
        gateway,
      ).template(investmentOccurrence.templateId!))!;
      expect(investmentTemplate.defaultAmount, max64);

      // Lista do período (mês de outubro: [01/10, 01/11)).
      final october = PeriodCalendar.containing(
        PeriodConfig.calendarMonth(),
        d1,
      );
      expect(october.end, next);
      final listed = await entryRepo.entriesInPeriod(october);
      expect(
        {for (final e in listed) e.id: e.amount},
        {incomeId: max64, expenseId: above53},
      );

      // Totais e dinheiro livre do período (somas do servidor em texto).
      final totals = await RemoteTotalsRepository(
        RemoteReportsRepository(SupabaseReportSource(client)),
      ).totalsFor(october);
      expect(totals.income, max64);
      expect(totals.expense, above53);
      expect(totals.investment, huge);
      expect(totals.surplus, max64 - above53 - huge);

      // Exportação CSV (Web): os valores saem exatos.
      final export = await SupabaseExportSource(client).load();
      String amountOf(List<Map<String, dynamic>> rows, String id) =>
          '${rows.firstWhere((r) => r['id'] == id)['amount_centavos']}';
      expect(amountOf(export.incomes, incomeId), max64.toString());
      expect(amountOf(export.expenses, expenseId), above53.toString());
      expect(amountOf(export.investments, investmentId), huge.toString());

      // Conflito: outra edição salva antes (versão sobe); a edição feita com
      // a versão antiga vira conflito. O retrato do servidor mostra o valor
      // exato em Itens de atenção.
      final sameIncome = EntryDraft(
        kind: EntryKind.income,
        amount: max64,
        date: d1,
        categoryId: salary.id,
        description: 'editada em outro aparelho',
      );
      await entryRepo.apply([UpdateEntry(income, sameIncome)]);
      expect(
        (await entryRepo.entry(EntryKind.income, incomeId))!.amount,
        max64,
      );
      await expectLater(
        entryRepo.apply([
          UpdateEntry(
            income,
            EntryDraft(
              kind: EntryKind.income,
              amount: BigInt.one,
              date: d1,
              categoryId: salary.id,
            ),
          ),
        ]),
        throwsA(isA<ChangeConflictException>()),
      );
      final items = await RemoteAttentionRepository(reader, gateway).items();
      final conflict = items.singleWhere((i) => i.entityId == incomeId);
      expect('${conflict.remote['amount_centavos']}', max64.toString());
    },
    skip: _enabled ? false : 'rode por tooling/test_web_parity.ps1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
