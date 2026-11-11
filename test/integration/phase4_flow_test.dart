@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/categories/remote_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/entries/remote_entry_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/periods/remote_period_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/reports/reports_repository.dart';
import 'package:porquinho/features/totals/totals_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fase 4 contra o Supabase LOCAL (nunca o gerenciado): celular offline →
/// sincronização → totais iguais no servidor e em um aparelho novo, Web e
/// isolamento entre usuários. Mesmos parâmetros dos demais testes de integração.
const _url = String.fromEnvironment('SUPABASE_URL');
const _publishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _secret = String.fromEnvironment('SUPABASE_SECRET_KEY');
final _enabled =
    _url.isNotEmpty && _publishable.isNotEmpty && _secret.isNotEmpty;

class _Account {
  _Account(this.client, this.id);
  final SupabaseClient client;
  final String id;
}

Future<_Account> _newAccount(Random r) async {
  final admin = SupabaseClient(_url, _secret);
  final email = 'f4-${r.nextInt(1 << 30)}@teste.local';
  final created = await admin.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: 'Senha-123456',
      emailConfirm: true,
    ),
  );
  final client = SupabaseClient(_url, _publishable);
  await client.auth.signInWithPassword(email: email, password: 'Senha-123456');
  return _Account(client, created.user!.id);
}

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

void main() {
  final r = Random();
  const skip = 'defina SUPABASE_URL/PUBLISHABLE_KEY/SECRET_KEY';

  test(
    'celular offline → servidor: totais iguais, aparelho novo igual, isolamento',
    () async {
      final a = await _newAccount(r);
      final b = await _newAccount(r);
      final db = PorquinhoDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final recorder = LocalChangeRecorder(db);
      final periodRepo = LocalPeriodRepository(db, a.id, recorder);
      final periods = PeriodService(periodRepo);
      final catRepo = LocalCategoryRepository(db, a.id, recorder);
      final categories = CategoryService(catRepo);
      final entryRepo = LocalEntryRepository(db, a.id, recorder);
      final entries = EntryService(entryRepo, catRepo, periods);

      // Tudo offline: ciclo dia 20, categorias, lançamentos e períodos para trás.
      await periods.setup(PeriodConfig.customCycle(20), d(2026, 11, 10));
      await categories.addSuggestions(
        income: ['Salário'],
        expense: ['Mercado'],
      );
      final cats = (await categories.load()).categories;
      final salary = cats.firstWhere((x) => x.kind == CategoryKind.income);
      final market = cats.firstWhere((x) => x.kind == CategoryKind.expense);
      await categories.createSubcategory(market, 'Feira');
      final fair = (await categories.load()).subcategories.single;

      Future<String> add(
        EntryKind k,
        int cents,
        CalendarDate date, {
        String? cat,
        String? sub,
        bool paid = false,
      }) => entries.create(
        EntryDraft(
          kind: k,
          amount: c(cents),
          date: date,
          categoryId: cat,
          subcategoryId: sub,
        ),
        alreadyPaid: paid,
        paidOn: date,
      );

      await add(EntryKind.income, 500000, d(2026, 11, 5), cat: salary.id);
      await add(
        EntryKind.expense,
        120000,
        d(2026, 11, 6),
        cat: market.id,
        sub: fair.id,
      );
      await add(EntryKind.expense, 30000, d(2026, 11, 7), paid: true);
      final toCancel = await add(EntryKind.expense, 99999, d(2026, 11, 8));
      await entries.cancel(
        (await entryRepo.entry(EntryKind.expense, toCancel))!,
      );
      // Data passada (cria períodos para trás) e futura.
      await entries.createMissingPeriods(d(2026, 8, 25));
      final moved = await add(EntryKind.income, 70000, d(2026, 8, 25));
      await entries.createMissingPeriods(d(2027, 1, 30));
      await add(EntryKind.income, 1000, d(2027, 1, 30));
      // Muda a data: o valor muda de período.
      await entries.update(
        (await entryRepo.entry(EntryKind.income, moved))!,
        EntryDraft(
          kind: EntryKind.income,
          amount: c(70000),
          date: d(2026, 9, 25),
        ),
      );

      // Sincroniza até esvaziar a fila: nada pode ser recusado nem conflitar.
      final sync = SyncService(db, SupabaseSyncGateway(a.client));
      for (var i = 0; i < 5 && (await sync.operations(a.id)).isNotEmpty; i++) {
        await sync.syncOnce(a.id);
      }
      final left = await sync.operations(a.id);
      expect(
        left,
        isEmpty,
        reason: left
            .map((o) => '${o.rpc}:${o.state}:${o.lastError}')
            .join('; '),
      );
      expect(await sync.openConflicts(a.id), isEmpty);

      // Servidor × celular: mesmo conjunto de períodos e mesmas sobras.
      final remoteTotals = RemoteTotalsRepository(
        RemoteReportsRepository(SupabaseReportSource(a.client)),
      );
      final localTotals = LocalTotalsRepository(db, a.id);
      final localPeriods = await periodRepo.periods();
      final serverPeriods = await RemotePeriodRepository(
        SupabaseTableReader(a.client),
        SupabaseSyncGateway(a.client),
      ).periods();
      expect(
        serverPeriods.map((p) => p.range.toString()).toList(),
        localPeriods.map((p) => p.range.toString()).toList(),
      );
      for (var i = 1; i < serverPeriods.length; i++) {
        expect(serverPeriods[i].range.start, serverPeriods[i - 1].range.end);
      }
      for (final p in localPeriods) {
        expect(
          await remoteTotals.totalsFor(p.id),
          await localTotals.totalsFor(p.id),
          reason: p.range.toString(),
        );
      }
      final nov = (await periods.periodFor(d(2026, 11, 5)))!;
      expect((await localTotals.totalsFor(nov.id)).surplus, c(350000));

      // Aparelho novo: baixa tudo e chega nos mesmos números.
      final db2 = PorquinhoDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      final result = await DownloadService(
        db2,
        SupabaseSyncReader(a.client),
      ).downloadAll(a.id);
      expect(result.completed, isTrue);
      final totals2 = LocalTotalsRepository(db2, a.id);
      for (final p in localPeriods) {
        expect(
          await totals2.totalsFor(p.id),
          await localTotals.totalsFor(p.id),
          reason: 'aparelho novo ${p.range}',
        );
      }

      // Usuário B não enxerga nada de A.
      final readerB = SupabaseTableReader(b.client);
      for (final t in [
        'categories',
        'subcategories',
        'accounting_periods',
        'period_configurations',
        'income_entries',
        'expense_entries',
      ]) {
        expect(await readerB.select(t), isEmpty, reason: t);
      }
    },
    skip: _enabled ? false : skip,
  );

  test(
    'Web (repositórios remotos): período, categoria, lançamento, pagar e cancelar',
    () async {
      final a = await _newAccount(r);
      final reader = SupabaseTableReader(a.client);
      final gateway = SupabaseSyncGateway(a.client);
      final periods = PeriodService(RemotePeriodRepository(reader, gateway));
      final catRepo = RemoteCategoryRepository(reader, gateway);
      final categories = CategoryService(catRepo);
      final entryRepo = RemoteEntryRepository(reader, gateway);
      final entries = EntryService(entryRepo, catRepo, periods);

      expect(await periods.needsSetup(), isTrue);
      await periods.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
      expect(await periods.needsSetup(), isFalse);

      await categories.createCategory(CategoryKind.expense, 'Mercado');
      final market = (await categories.load()).categories.single;
      await categories.renameCategory(market, 'Supermercado');
      expect((await categories.load()).categories.single.name, 'Supermercado');

      final income = await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: c(100000),
          date: d(2026, 11, 3),
        ),
      );
      final expense = await entries.create(
        EntryDraft(
          kind: EntryKind.expense,
          amount: c(40000),
          date: d(2026, 11, 4),
          categoryId: market.id,
        ),
      );
      final period = (await periods.periodFor(d(2026, 11, 4)))!;
      final totals = RemoteTotalsRepository(
        RemoteReportsRepository(SupabaseReportSource(a.client)),
      );
      expect((await totals.totalsFor(period.id)).surplus, c(60000));

      await entries.pay(
        (await entryRepo.entry(EntryKind.expense, expense))!,
        d(2026, 11, 9),
      );
      expect(
        (await totals.totalsFor(period.id)).surplus,
        c(60000),
        reason: 'pagar não muda',
      );
      await entries.cancel((await entryRepo.entry(EntryKind.income, income))!);
      expect((await totals.totalsFor(period.id)).surplus, c(-40000));

      // Período inexistente: pergunta; períodos para trás pela RPC nova.
      await expectLater(
        entries.create(
          EntryDraft(kind: EntryKind.income, amount: c(1), date: d(2026, 8, 2)),
        ),
        throwsA(isA<PeriodMissingException>()),
      );
      await entries.createMissingPeriods(d(2026, 8, 2));
      await entries.create(
        EntryDraft(
          kind: EntryKind.income,
          amount: c(5000),
          date: d(2026, 8, 2),
        ),
      );
      final august = (await periods.periodFor(d(2026, 8, 2)))!;
      expect((await totals.totalsFor(august.id)).surplus, c(5000));

      // Servidor recusa o que a validação local deixaria passar: vira mensagem.
      final other = await _newAccount(r);
      await expectLater(
        EntryService(
          RemoteEntryRepository(
            SupabaseTableReader(other.client),
            SupabaseSyncGateway(other.client),
          ),
          RemoteCategoryRepository(
            SupabaseTableReader(other.client),
            SupabaseSyncGateway(other.client),
          ),
          PeriodService(
            RemotePeriodRepository(
              SupabaseTableReader(other.client),
              SupabaseSyncGateway(other.client),
            ),
          ),
        ).create(
          EntryDraft(
            kind: EntryKind.income,
            amount: c(1),
            date: d(2026, 11, 3),
            categoryId: market.id,
          ),
        ),
        throwsA(isA<ChangeRejectedException>()),
        reason: 'categoria de outro usuário nunca é aceita',
      );
    },
    skip: _enabled ? false : skip,
  );

  test(
    'download em várias páginas traz tudo, na ordem certa e sem repetir',
    () async {
      final a = await _newAccount(r);
      final reader = SupabaseTableReader(a.client);
      final gateway = SupabaseSyncGateway(a.client);
      final categories = CategoryService(
        RemoteCategoryRepository(reader, gateway),
      );
      for (var i = 0; i < 7; i++) {
        await categories.createCategory(CategoryKind.expense, 'Categoria $i');
      }
      final db = PorquinhoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final result = await DownloadService(
        db,
        SupabaseSyncReader(a.client),
        pageSize: 3,
      ).downloadAll(a.id);
      expect(result.completed, isTrue);
      final n = await db
          .customSelect('SELECT COUNT(*) AS n FROM categories')
          .getSingle();
      expect(n.read<int>('n'), 7);
    },
    skip: _enabled ? false : skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
