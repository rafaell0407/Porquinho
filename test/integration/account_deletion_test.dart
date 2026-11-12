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
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// Entrega 73: exclusão definitiva da conta no Supabase LOCAL.
const _tables = [
  'accounting_periods',
  'applied_sync_operations',
  'audit_events',
  'categories',
  'expense_entries',
  'income_entries',
  'investment_allocations',
  'period_configurations',
  'user_preferences',
];

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;

  /// Conta com período, categorias, receita, despesa e investimento enviados.
  Future<SupabaseClient> populate(TestAccount account) async {
    final client = await account.device();
    final db = memoryDb();
    addTearDown(db.close);
    final recorder = LocalChangeRecorder(db);
    final periods = PeriodService(
      LocalPeriodRepository(db, account.id, recorder),
    );
    final catRepo = LocalCategoryRepository(db, account.id, recorder);
    final categories = CategoryService(catRepo);
    final entries = EntryService(
      LocalEntryRepository(db, account.id, recorder),
      catRepo,
      periods,
    );
    final investments = InvestmentService(
      LocalInvestmentRepository(db, account.id, recorder),
      periods,
    );
    final day = CalendarDate(2026, 11, 5);
    await periods.setup(PeriodConfig.calendarMonth(), day);
    await categories.addSuggestions(income: ['Salário'], expense: ['Mercado']);
    final cats = (await categories.load()).categories;
    await entries.create(
      EntryDraft(
        kind: EntryKind.income,
        amount: BigInt.from(500000),
        date: day,
        categoryId: cats.firstWhere((c) => c.kind == CategoryKind.income).id,
      ),
    );
    await entries.create(
      EntryDraft(
        kind: EntryKind.expense,
        amount: BigInt.from(12000),
        date: day,
        categoryId: cats.firstWhere((c) => c.kind == CategoryKind.expense).id,
      ),
    );
    await investments.create(
      InvestmentDraft(amount: BigInt.from(30000), date: day),
    );
    final sync = SyncService(db, SupabaseSyncGateway(client));
    for (var i = 0; i < 5; i++) {
      await sync.syncOnce(account.id);
    }
    expect(await sync.operations(account.id), isEmpty);
    return client;
  }

  test(
    'apaga tudo da conta, preserva a outra e impede novo login',
    () async {
      final a = await newTestAccount(r);
      final b = await newTestAccount(r);
      final clientA = await populate(a);
      final clientB = await populate(b);
      final admin = SupabaseClient(supabaseUrl, supabaseSecret);

      // Sem a confirmação explícita, nada acontece.
      await expectLater(
        clientA.rpc('delete_my_account', params: {'p_confirmation': 'sim'}),
        throwsA(isA<PostgrestException>()),
      );
      expect(await clientA.from('categories').select(), isNotEmpty);

      final bBefore = <String, int>{};
      for (final t in _tables) {
        bBefore[t] = (await clientB.from(t).select()).length;
      }
      expect(bBefore['income_entries'], greaterThan(0));

      final result = await clientA.rpc(
        'delete_my_account',
        params: {'p_confirmation': 'DELETE_MY_ACCOUNT'},
      );
      expect((result as Map)['status'], 'deleted');

      // Nenhuma linha de A em nenhuma tabela (consulta com chave de serviço).
      for (final t in _tables) {
        final rows = await admin.from(t).select().eq('owner_id', a.id);
        expect(rows, isEmpty, reason: t);
      }
      final marker = await admin
          .from('deleted_accounts')
          .select()
          .eq('owner_id', a.id);
      expect(marker, hasLength(1));

      // B continua igual.
      for (final t in _tables) {
        expect((await clientB.from(t).select()).length, bBefore[t], reason: t);
      }

      // A não consegue mais entrar.
      final again = SupabaseClient(supabaseUrl, supabasePublishable);
      await expectLater(
        again.auth.signInWithPassword(email: a.email, password: a.password),
        throwsA(isA<AuthException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: skip,
  );
}
