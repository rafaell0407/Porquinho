@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// Entrega 72: isolamento A×B e acesso anônimo pela API (PostgREST) do
/// Supabase LOCAL, em todas as tabelas e RPCs de `public`.
const _tables = [
  'applied_sync_operations',
  'audit_events',
  'categories',
  'expense_entries',
  'expense_recurrence_templates',
  'income_entries',
  'income_recurrence_templates',
  'investment_allocations',
  'investment_recurrence_templates',
  'period_settings',
  'subcategories',
  'sync_conflicts',
  'user_preferences',
];

const _rpcs = [
  'apply_category_change',
  'apply_expense_entry_change',
  'apply_expense_recurrence_occurrence_change',
  'apply_expense_recurrence_template_change',
  'apply_income_entry_change',
  'apply_income_recurrence_occurrence_change',
  'apply_income_recurrence_template_change',
  'apply_investment_allocation_change',
  'apply_investment_recurrence_template_change',
  'apply_subcategory_change',
  'dismiss_tool_intro',
  'create_investment_recurrence_from_entry',
  'create_recurrence_from_entry',
  'generate_due_recurrence_occurrences',
  'get_entry_date_span',
  'get_range_report',
  'resolve_sync_conflict',
  'set_onboarding_step',
  'set_period_settings',
  'set_tool_selection',
  'set_user_theme',
];

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;

  /// Lê [table] como [client]: erro de permissão conta como "sem acesso".
  Future<List<dynamic>> read(SupabaseClient client, String table) async {
    try {
      return await client.from(table).select();
    } on PostgrestException {
      return const [];
    }
  }

  /// `true` se a escrita direta foi bloqueada (erro) ou não afetou nada.
  Future<bool> writeBlocked(SupabaseClient client, String table) async {
    try {
      final inserted = await client.from(table).insert({}).select();
      if (inserted.isNotEmpty) return false;
    } on PostgrestException {
      // bloqueado
    }
    try {
      final updated = await client
          .from(table)
          .update({'version': 99})
          .not('id', 'is', null)
          .select();
      if (updated.isNotEmpty) return false;
    } on PostgrestException {
      // bloqueado
    }
    try {
      final deleted = await client
          .from(table)
          .delete()
          .not('id', 'is', null)
          .select();
      if (deleted.isNotEmpty) return false;
    } on PostgrestException {
      // bloqueado
    }
    return true;
  }

  late TestAccount accountA;
  late SupabaseClient a;
  late SupabaseClient b;
  late SupabaseClient anon;
  late String categoryId;
  late String conflictId;

  setUpAll(() async {
    if (!supabaseEnabled) return;
    accountA = await newTestAccount(r);
    final accountB = await newTestAccount(r);
    a = await accountA.device();
    b = await accountB.device();
    anon = SupabaseClient(supabaseUrl, supabasePublishable);
    categoryId = testUuid(r);
    await remoteCreateCategory(a, r, categoryId, 'Só da A');
    // A gera um conflito (versão esperada errada).
    final res = await a.rpc(
      'apply_category_change',
      params: {
        'p_operation_id': testUuid(r),
        'p_action': 'rename',
        'p_category_id': categoryId,
        'p_expected_version': 7,
        'p_kind': null,
        'p_name': 'Conflito',
      },
    );
    conflictId = (res as Map)['conflict_id'] as String;
  });

  group('Entrega 72 — isolamento pela API', () {
    test('A enxerga os próprios dados (controle do teste)', () async {
      expect(await read(a, 'categories'), hasLength(1));
      expect(await read(a, 'audit_events'), isNotEmpty);
      expect(await read(a, 'sync_conflicts'), hasLength(1));
    }, skip: skip);

    test('B não lê nenhuma linha de A em nenhuma tabela', () async {
      for (final table in _tables) {
        expect(await read(b, table), isEmpty, reason: table);
      }
    }, skip: skip);

    test('anônimo não lê nenhuma tabela', () async {
      for (final table in _tables) {
        expect(await read(anon, table), isEmpty, reason: table);
      }
    }, skip: skip);

    test('escrita direta é bloqueada para autenticado e anônimo', () async {
      for (final table in _tables) {
        expect(await writeBlocked(a, table), isTrue, reason: 'A em $table');
        expect(await writeBlocked(anon, table), isTrue, reason: 'anon $table');
      }
      expect(await read(a, 'categories'), hasLength(1));
      final row = (await read(a, 'categories')).single as Map;
      expect(row['name'], 'Só da A');
      expect(row['version'], 1);
    }, skip: skip);

    test('anônimo não executa nenhuma RPC', () async {
      for (final rpc in _rpcs) {
        await expectLater(
          anon.rpc(rpc, params: {}),
          throwsA(isA<PostgrestException>()),
          reason: rpc,
        );
      }
    }, skip: skip);

    test('B não altera nem resolve dados de A pelas RPCs', () async {
      // Renomear a categoria de A como B: recusado ou "não encontrado".
      Object? outcome;
      try {
        outcome = await b.rpc(
          'apply_category_change',
          params: {
            'p_operation_id': testUuid(r),
            'p_action': 'rename',
            'p_category_id': categoryId,
            'p_expected_version': 1,
            'p_kind': null,
            'p_name': 'Invadida',
          },
        );
      } on PostgrestException {
        outcome = null;
      }
      if (outcome is Map) {
        expect(outcome['status'], isNot('applied'));
      }

      try {
        await b.rpc(
          'resolve_sync_conflict',
          params: {
            'p_operation_id': testUuid(r),
            'p_conflict_id': conflictId,
            'p_resolution': 'keep_local',
            'p_request': null,
          },
        );
        fail('B não pode resolver o conflito de A');
      } on PostgrestException {
        // esperado
      }

      final row = (await read(a, 'categories')).single as Map;
      expect(row['name'], 'Só da A');
      expect(row['version'], 1);
      expect((await read(a, 'sync_conflicts')).single['status'], 'open');
    }, skip: skip);

    test('relatório por datas de outra conta devolve zeros', () async {
      final report = await b.rpc(
        'get_range_report',
        params: {
          'p_starts': ['2000-01-01'],
          'p_ends': ['2100-01-01'],
        },
      );
      final ranges = (report as Map)['ranges'] as List;
      expect(ranges.single['income'], '0');
      expect(ranges.single['expense'], '0');
      expect(ranges.single['investment'], '0');
      expect(await b.rpc('get_entry_date_span'), {
        'oldest': null,
        'newest': null,
      });
    }, skip: skip);
  });
}
