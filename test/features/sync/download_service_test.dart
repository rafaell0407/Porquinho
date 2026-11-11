@TestOn('vm')
library;

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/sync_models.dart';

class _FakeReader implements SyncRemoteReader {
  final tables = <String, List<Map<String, dynamic>>>{};
  Map<String, dynamic>? preferences;
  int failAfterPages = -1; // -1 = nunca falha
  int pagesServed = 0;
  final requests = <String?>[];

  @override
  Future<Map<String, dynamic>?> fetchPreferences(String ownerId) async =>
      preferences;

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required String ownerId,
    required String orderColumn,
    String? afterOrder,
    String? afterId,
    required int limit,
  }) async {
    if (failAfterPages >= 0 && pagesServed >= failAfterPages) {
      throw const SyncTransientError('sem rede');
    }
    pagesServed++;
    requests.add('$table|$afterOrder|$afterId');
    final rows = (tables[table] ?? [])
        .where((r) => r['owner_id'] == ownerId)
        .toList();
    int cmp(Map<String, dynamic> r) => DateTime.parse(
      r[orderColumn] as String,
    ).compareTo(DateTime.parse(afterOrder!));
    final filtered =
        rows.where((r) {
          if (afterOrder == null) return true;
          if (afterId == null) return cmp(r) >= 0;
          final c = cmp(r);
          return c > 0 ||
              (c == 0 && (r['id'] as String).compareTo(afterId) > 0);
        }).toList()..sort((a, b) {
          final c = DateTime.parse(
            a[orderColumn] as String,
          ).compareTo(DateTime.parse(b[orderColumn] as String));
          return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
        });
    return filtered.take(limit).toList();
  }
}

String _t(int minute, [int second = 0]) =>
    '2026-11-10T10:${minute.toString().padLeft(2, '0')}:'
    '${second.toString().padLeft(2, '0')}.000000+00:00';

Map<String, dynamic> _base(String id, String at, {int version = 1}) => {
  'owner_id': 'u1',
  'id': id,
  'version': version,
  'created_at': at,
  'updated_at': at,
};

void main() {
  late PorquinhoDatabase db;
  late _FakeReader reader;
  late DownloadService service;

  setUp(() {
    db = PorquinhoDatabase(NativeDatabase.memory());
    reader = _FakeReader();
    service = DownloadService(db, reader, pageSize: 2);
  });
  tearDown(() => db.close());

  Future<int> count(String table, {String owner = 'u1'}) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM $table WHERE owner_id = ?1',
                variables: [Variable.withString(owner)],
              )
              .getSingle())
          .read<int>('n');

  void seedServer() {
    reader.preferences = {
      'owner_id': 'u1',
      'theme': 'dark',
      'time_zone_id': 'America/Sao_Paulo',
      'version': 3,
      'updated_at': _t(5),
    };
    reader.tables['period_configurations'] = [
      {
        ..._base('cfg1', _t(1)),
        'mode': 'calendar_month',
        'custom_start_day': null,
        'effective_from': '2026-01-01',
      },
    ];
    reader.tables['accounting_periods'] = [
      for (var i = 0; i < 3; i++)
        {
          ..._base('per$i', _t(2, i)),
          'configuration_id': 'cfg1',
          'start_date': '2026-0${i + 1}-01',
          'end_date': '2026-0${i + 2}-01',
        },
    ];
    reader.tables['categories'] = [
      {
        ..._base('cat1', _t(3)),
        'kind': 'expense',
        'name': 'Mercado',
        'is_active': true,
      },
      {
        ..._base('cat2', _t(3)), // mesmo instante: desempate pelo id
        'kind': 'income',
        'name': 'Salário',
        'is_active': false,
      },
    ];
    reader.tables['subcategories'] = [
      {
        ..._base('sub1', _t(4)),
        'category_id': 'cat1',
        'name': 'Feira',
        'is_active': true,
      },
    ];
    reader.tables['expense_recurrence_templates'] = [
      {
        ..._base('tpl1', _t(5)),
        'description': null,
        'frequency': 'by_period',
        'starts_on': '2026-01-01',
        'monthly_reference_day': null,
        'value_mode': 'variable',
        'default_amount_centavos': null,
        'category_id': 'cat1',
        'subcategory_id': null,
        'is_active': true,
      },
    ];
    reader.tables['income_entries'] = [
      {
        ..._base('inc1', _t(6)),
        'description': null,
        'amount_centavos': 9223372036854775807,
        'status': 'received',
        'received_on': '2026-01-05',
        'category_id': 'cat2',
        'subcategory_id': null,
        'accounting_period_id': 'per0',
        'recurrence_template_id': null,
        'scheduled_for_date': null,
        'scheduled_period_id': null,
      },
    ];
    reader.tables['expense_entries'] = [
      {
        ..._base('exp1', _t(7)),
        'description': 'Feira',
        'amount_centavos': 1500,
        'status': 'paid',
        'competence_on': '2026-01-10',
        'due_on': null,
        'paid_on': '2026-01-12',
        'category_id': 'cat1',
        'subcategory_id': 'sub1',
        'accounting_period_id': 'per0',
        'recurrence_template_id': null,
        'scheduled_for_date': null,
        'scheduled_period_id': null,
      },
    ];
    reader.tables['investment_recurrence_templates'] = [
      {
        ..._base('itpl1', _t(6)),
        'frequency': 'monthly',
        'starts_on': '2026-01-20',
        'monthly_reference_day': 20,
        'default_amount_centavos': 20000,
        'is_active': true,
      },
    ];
    reader.tables['investment_allocations'] = [
      {
        ..._base('inv1', _t(8)),
        'amount_centavos': 20000,
        'allocated_on': '2026-01-20',
        'accounting_period_id': 'per0',
        'cancelled_at': null,
        'recurrence_template_id': 'itpl1',
        'scheduled_for_date': '2026-01-20',
        'scheduled_period_id': null,
      },
    ];
    reader.tables['audit_events'] = [
      {
        'owner_id': 'u1',
        'id': 'aud1',
        'entity_type': 'category',
        'entity_id': 'cat1',
        'operation': 'create',
        'actor_id': 'u1',
        'occurred_at': _t(3),
        'previous_values': null,
        'new_values': {'name': 'Mercado'},
        'operation_id': 'op1',
      },
    ];
  }

  test('aparelho novo baixa tudo, na ordem de dependência', () async {
    seedServer();
    final result = await service.downloadAll('u1');

    expect(result.completed, isTrue);
    expect(await count('period_configurations'), 1);
    expect(await count('accounting_periods'), 3);
    expect(await count('categories'), 2);
    expect(await count('subcategories'), 1);
    expect(await count('expense_recurrence_templates'), 1);
    expect(await count('income_entries'), 1);
    expect(await count('expense_entries'), 1);
    expect(await count('investment_allocations'), 1);
    expect(await count('investment_recurrence_templates'), 1);
    expect(await count('audit_events'), 1);
    expect(await count('user_preferences'), 1);

    final occurrence = await db
        .customSelect('SELECT * FROM investment_allocations')
        .getSingle();
    expect(occurrence.read<String>('recurrence_template_id'), 'itpl1');
    expect(occurrence.read<String>('scheduled_for_date'), '2026-01-20');
    final itpl = await db
        .customSelect('SELECT * FROM investment_recurrence_templates')
        .getSingle();
    expect(itpl.read<String>('default_amount_centavos'), '20000');
    expect(itpl.read<int>('monthly_reference_day'), 20);

    final inc = await db
        .customSelect('SELECT * FROM income_entries')
        .getSingle();
    expect(inc.read<String>('amount_centavos'), '9223372036854775807');
    expect(inc.data['description'], isNull);
    final cat = await db
        .customSelect("SELECT is_active FROM categories WHERE id = 'cat2'")
        .getSingle();
    expect(cat.read<int>('is_active'), 0);
    final tpl = await db
        .customSelect('SELECT frequency FROM expense_recurrence_templates')
        .getSingle();
    expect(tpl.read<String>('frequency'), 'by_period');
    final aud = await db.customSelect('SELECT * FROM audit_events').getSingle();
    expect(aud.read<String>('new_snapshot_json'), '{"name":"Mercado"}');
  });

  test('repetir o download não duplica nem altera nada', () async {
    seedServer();
    await service.downloadAll('u1');
    final second = await service.downloadAll('u1');

    expect(second.applied, 0);
    expect(await count('accounting_periods'), 3);
    expect(await count('categories'), 2);
    expect(await count('audit_events'), 1);
  });

  test('só grava versão maior; versão menor ou igual é ignorada', () async {
    seedServer();
    await service.downloadAll('u1');
    await db.customStatement(
      "UPDATE categories SET name = 'Local', version = 5 WHERE id = 'cat1'",
    );
    // Servidor com versão 2 (< 5 local): não pode sobrescrever.
    reader.tables['categories']![0]
      ..['version'] = 2
      ..['name'] = 'Servidor v2'
      ..['updated_at'] = _t(9);
    await service.downloadAll('u1');
    var row = await db
        .customSelect("SELECT name FROM categories WHERE id = 'cat1'")
        .getSingle();
    expect(row.read<String>('name'), 'Local');

    // Servidor com versão 6: atualiza.
    reader.tables['categories']![0]
      ..['version'] = 6
      ..['name'] = 'Servidor v6'
      ..['updated_at'] = _t(10);
    await service.downloadAll('u1');
    row = await db
        .customSelect("SELECT name FROM categories WHERE id = 'cat1'")
        .getSingle();
    expect(row.read<String>('name'), 'Servidor v6');
  });

  test('pendência local não é sobrescrita por mudança remota', () async {
    seedServer();
    await service.downloadAll('u1');
    await db.customStatement(
      "UPDATE categories SET name = 'Edição local', version = 2 "
      "WHERE id = 'cat1'",
    );
    await db.customStatement(
      'INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, '
      'entity_id, expected_version, payload_json, state) '
      "VALUES ('u1', 'k1', 'category', 'cat1', 1, '{}', 'pending')",
    );
    reader.tables['categories']![0]
      ..['version'] = 3
      ..['name'] = 'Outro aparelho'
      ..['updated_at'] = _t(11);

    final result = await service.downloadAll('u1');

    expect(result.skippedPending, 1);
    final row = await db
        .customSelect("SELECT name, version FROM categories WHERE id = 'cat1'")
        .getSingle();
    expect(row.read<String>('name'), 'Edição local');
    expect(row.read<int>('version'), 2);
  });

  test('isolamento: linhas de outra conta nunca entram', () async {
    seedServer();
    reader.tables['categories']!.add({
      ..._base('catX', _t(3)),
      'owner_id': 'u2',
      'kind': 'expense',
      'name': 'Da outra conta',
      'is_active': true,
    });
    await service.downloadAll('u1');

    expect(await count('categories'), 2);
    expect(await count('categories', owner: 'u2'), 0);
  });

  test('falha de rede no meio retoma sem perder nem duplicar', () async {
    seedServer();
    reader.failAfterPages = 3;
    final first = await service.downloadAll('u1');
    expect(first.completed, isFalse);
    expect(await count('income_entries'), 0);

    reader.failAfterPages = -1;
    final second = await service.downloadAll('u1');
    expect(second.completed, isTrue);
    expect(await count('accounting_periods'), 3);
    expect(await count('categories'), 2);
    expect(await count('income_entries'), 1);
    expect(await count('audit_events'), 1);
  });

  test('linha gravada no servidor "no passado" é pega pela margem', () async {
    seedServer();
    await service.downloadAll('u1');
    // Transação lenta: confirmada agora, mas com updated_at 1 minuto antes do
    // último que já baixamos.
    reader.tables['categories']!.add({
      ..._base('cat3', _t(2, 30)),
      'kind': 'expense',
      'name': 'Atrasada',
      'is_active': true,
    });
    await service.downloadAll('u1');

    expect(await count('categories'), 3);
  });

  test('evento de auditoria criado neste aparelho não é duplicado', () async {
    seedServer();
    await db.customStatement(
      'INSERT INTO audit_events (id, owner_id, version, created_at, '
      'updated_at, entity_type, entity_id, operation, actor_id, occurred_at, '
      "operation_id) VALUES ('local-1', 'u1', 1, 'x', 'x', 'category', "
      "'cat1', 'create', 'u1', 'x', 'op1')",
    );
    await service.downloadAll('u1');

    expect(await count('audit_events'), 1);
  });

  test('conta sem dados no servidor: nada é gravado', () async {
    final result = await service.downloadAll('u1');
    expect(result.applied, 0);
    expect(result.completed, isTrue);
    expect(await count('categories'), 0);
  });
}
