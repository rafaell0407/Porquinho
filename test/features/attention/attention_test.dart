@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/attention/attention_models.dart';
import 'package:porquinho/features/attention/attention_providers.dart';
import 'package:porquinho/features/attention/attention_repository.dart';
import 'package:porquinho/features/attention/attention_screen.dart';
import 'package:porquinho/features/attention/local_attention_repository.dart';
import 'package:porquinho/features/attention/remote_attention_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

class FakeGateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];
  final handlers =
      <String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)>{};

  @override
  Future<Map<String, dynamic>> call(String rpc, Map<String, dynamic> params) {
    calls.add((rpc, params));
    return handlers[rpc]!(params);
  }
}

class NoReader implements SyncRemoteReader {
  @override
  Future<Map<String, dynamic>?> fetchPreferences(String ownerId) async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required String ownerId,
    required String orderColumn,
    String? afterOrder,
    String? afterId,
    required int limit,
  }) async => [];
}

class FakeReader implements RemoteTableReader {
  final tables = <String, List<Map<String, dynamic>>>{};

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    List<RemoteFilter> filters = const [],
    String? orderBy,
  }) async => tables[table] ?? [];
}

void main() {
  group('modelos', () {
    test('o que pode ser mantido, editado e descrito', () {
      final rename = AttentionItem(
        kind: AttentionKind.conflict,
        id: 'x',
        entityType: 'category',
        entityId: 'c1',
        request: normalizeRequest({'p_action': 'rename', 'p_name': 'Novo'}),
        remote: {'name': 'Outro', 'is_active': true, 'version': 3},
      );
      expect(rename.canKeepLocal, isTrue);
      expect(rename.canEdit, isTrue);
      expect(rename.mineSummary, 'Renomear para "Novo"');
      expect(rename.serverSummary, '"Outro"');

      final create = AttentionItem(
        kind: AttentionKind.conflict,
        id: 'y',
        entityType: 'category',
        entityId: 'c1',
        request: {'action': 'create', 'name': 'A'},
      );
      expect(
        create.canKeepLocal,
        isFalse,
        reason: 'criação só aceita servidor',
      );

      final settings = AttentionItem(
        kind: AttentionKind.conflict,
        id: 'z',
        entityType: 'period_settings',
        entityId: 'u1',
        request: {'expected_version': 0, 'mode': 'calendar_month'},
        remote: {'mode': 'custom_cycle', 'custom_start_day': 20},
      );
      // Criação da configuração (primeiro acesso em dois aparelhos): só a do
      // servidor.
      expect(settings.canKeepLocal, isFalse);
      expect(settings.canEdit, isFalse);
      expect(settings.mineSummary, 'Mudar para Mês-calendário');
      expect(settings.serverSummary, 'Ciclo personalizado (dia 20)');

      final entry = AttentionItem(
        kind: AttentionKind.conflict,
        id: 'w',
        entityType: 'income_entry',
        entityId: 'e1',
        request: {
          'action': 'update',
          'payload': {'amount_centavos': '123456', 'received_on': '2026-11-10'},
        },
        remote: {
          'amount_centavos': 100000,
          'status': 'received',
          'received_on': '2026-11-09',
        },
      );
      expect(entry.canEdit, isTrue);
      expect(entry.mineSummary, 'Alterar: R\$ 1.234,56 · 10/11/2026');
      expect(entry.serverSummary, 'R\$ 1.000,00 · 09/11/2026');

      final edited = buildEditedRequest(
        entry,
        amountCentavos: BigInt.from(5000),
        description: 'Ajuste',
      );
      expect(edited['action'], 'update');
      expect((edited['payload'] as Map)['amount_centavos'], '5000');
      expect((edited['payload'] as Map)['received_on'], '2026-11-10');
      expect(buildEditedRequest(rename, name: 'Final'), {
        'action': 'rename',
        'name': 'Final',
      });
    });
  });

  group('investimento (Entrega 52, D6, V7)', () {
    test('textos com valor e data; editar valor e data', () {
      final item = AttentionItem(
        kind: AttentionKind.conflict,
        id: 'i1',
        entityType: 'investment_allocation',
        entityId: 'a1',
        request: normalizeRequest({
          'p_action': 'update',
          'p_allocation_id': 'a1',
          'p_expected_version': 1,
          'p_amount_centavos': '123456',
          'p_allocated_on': '2026-11-10',
        }),
        remote: {
          'amount_centavos': 100000,
          'allocated_on': '2026-11-09',
          'cancelled_at': null,
          'version': 2,
        },
      );
      expect(item.canKeepLocal, isTrue);
      expect(item.canEdit, isTrue);
      expect(item.mineSummary, 'Alterar: R\$ 1.234,56 · 10/11/2026');
      expect(item.serverSummary, 'R\$ 1.000,00 · 09/11/2026');
      expect(buildEditedRequest(item, amountCentavos: BigInt.from(5000)), {
        'action': 'update',
        'amount_centavos': '5000',
        'allocated_on': '2026-11-10',
      });
      expect(buildEditedRequest(item, allocatedOn: CalendarDate(2026, 12, 1)), {
        'action': 'update',
        'amount_centavos': '123456',
        'allocated_on': '2026-12-01',
      });
    });

    test('cancelamento e servidor cancelado; criação só aceita servidor', () {
      final cancel = AttentionItem(
        kind: AttentionKind.conflict,
        id: 'i2',
        entityType: 'investment_allocation',
        entityId: 'a1',
        request: {'action': 'cancel'},
        remote: {
          'amount_centavos': 2500,
          'allocated_on': '2026-11-09',
          'cancelled_at': '2026-11-10T00:00:00Z',
        },
      );
      expect(cancel.mineSummary, 'Cancelar o investimento');
      expect(cancel.serverSummary, 'R\$ 25,00 · 09/11/2026 (cancelado)');
      expect(cancel.canEdit, isFalse);
      final create = AttentionItem(
        kind: AttentionKind.conflict,
        id: 'i3',
        entityType: 'investment_allocation',
        entityId: 'a1',
        request: {
          'action': 'create',
          'amount_centavos': '100',
          'allocated_on': '2026-11-09',
        },
      );
      expect(create.canKeepLocal, isFalse);
      expect(create.canEdit, isFalse);
      expect(create.mineSummary, 'Criar: R\$ 1,00 · 09/11/2026');
    });
  });

  group('celular (repositório local)', () {
    late PorquinhoDatabase db;
    late FakeGateway gateway;
    late SyncService sync;
    late LocalAttentionRepository repo;

    setUp(() async {
      db = PorquinhoDatabase(NativeDatabase.memory());
      gateway = FakeGateway();
      sync = SyncService(db, gateway, clock: () => DateTime.utc(2026, 11, 10));
      repo = LocalAttentionRepository(
        db,
        'u1',
        sync,
        DownloadService(db, NoReader()),
      );
      await db.customStatement(
        'INSERT INTO categories (id, owner_id, version, created_at, updated_at, '
        "kind, name, is_active) VALUES ('c1', 'u1', 2, 'x', 'x', 'expense', "
        "'Meu nome', 1)",
      );
    });
    tearDown(() => db.close());

    Future<void> conflictOnRename() async {
      await sync.enqueue(
        OutboxOperation(
          ownerId: 'u1',
          idempotencyKey: 'k1',
          entityType: 'category',
          entityId: 'c1',
          expectedVersion: 1,
          rpc: 'apply_category_change',
          params: {
            'p_action': 'rename',
            'p_category_id': 'c1',
            'p_expected_version': 1,
            'p_kind': null,
            'p_name': 'Meu nome',
          },
        ),
      );
      gateway.handlers['apply_category_change'] = (_) async => {
        'status': 'conflict',
        'conflict_id': 'cf1',
        'remote_category': {
          'id': 'c1',
          'kind': 'expense',
          'name': 'Nome do servidor',
          'is_active': true,
          'version': 2,
        },
      };
      await sync.syncOnce('u1');
    }

    Future<String> localName() async =>
        (await db
                .customSelect("SELECT name FROM categories WHERE id = 'c1'")
                .getSingle())
            .read<String>('name');

    test('lista o conflito com as duas versões', () async {
      await conflictOnRename();
      final items = await repo.items();
      expect(items.single.kind, AttentionKind.conflict);
      expect(items.single.mineSummary, 'Renomear para "Meu nome"');
      expect(items.single.serverSummary, '"Nome do servidor"');
    });

    test('manter o servidor: mesmo com versão igual, o registro local '
        'passa a ser o do servidor', () async {
      await conflictOnRename();
      gateway.handlers['resolve_sync_conflict'] = (_) async => {
        'status': 'resolved',
        'conflict_id': 'cf1',
        'record': {
          'id': 'c1',
          'kind': 'expense',
          'name': 'Nome do servidor',
          'is_active': true,
          'version': 2,
          'created_at': 'x',
          'updated_at': 'y',
        },
      };
      final item = (await repo.items()).single;
      await repo.resolve(item, ConflictResolution.keepRemote);

      expect(await localName(), 'Nome do servidor');
      expect(await repo.items(), isEmpty);
      expect(await sync.operations('u1'), isEmpty);
      final call = gateway.calls.last;
      expect(call.$2['p_resolution'], 'keep_remote');
      expect(call.$2['p_conflict_id'], 'cf1');
    });

    test('manter a minha: servidor devolve a versão consolidada', () async {
      await conflictOnRename();
      gateway.handlers['resolve_sync_conflict'] = (_) async => {
        'status': 'resolved',
        'result': {
          'status': 'applied',
          'category': {
            'id': 'c1',
            'kind': 'expense',
            'name': 'Meu nome',
            'is_active': true,
            'version': 3,
            'created_at': 'x',
            'updated_at': 'z',
          },
        },
      };
      await repo.resolve(
        (await repo.items()).single,
        ConflictResolution.keepLocal,
      );
      final row = await db
          .customSelect("SELECT version FROM categories WHERE id = 'c1'")
          .getSingle();
      expect(row.read<int>('version'), 3);
      expect(await localName(), 'Meu nome');
    });

    test('editar envia o pedido editado', () async {
      await conflictOnRename();
      gateway.handlers['resolve_sync_conflict'] = (_) async => {
        'status': 'resolved',
        'result': {
          'category': {
            'id': 'c1',
            'kind': 'expense',
            'name': 'Final',
            'is_active': true,
            'version': 3,
            'created_at': 'x',
            'updated_at': 'z',
          },
        },
      };
      final item = (await repo.items()).single;
      await repo.resolve(
        item,
        ConflictResolution.edit,
        editedRequest: buildEditedRequest(item, name: 'Final'),
      );
      expect(gateway.calls.last.$2['p_request'], {
        'action': 'rename',
        'name': 'Final',
      });
      expect(await localName(), 'Final');
    });

    test(
      'conflito de investimento: editar valor e data gera nova versão',
      () async {
        await db.customStatement('PRAGMA foreign_keys = OFF');
        await db.customStatement(
          'INSERT INTO investment_allocations (id, owner_id, version, created_at, '
          "updated_at, amount_centavos, allocated_on) "
          "VALUES ('a1', 'u1', 2, 'x', 'x', '100000', '2026-11-05')",
        );
        await sync.enqueue(
          OutboxOperation(
            ownerId: 'u1',
            idempotencyKey: 'k9',
            entityType: 'investment_allocation',
            entityId: 'a1',
            expectedVersion: 1,
            rpc: 'apply_investment_allocation_change',
            params: {
              'p_action': 'update',
              'p_allocation_id': 'a1',
              'p_expected_version': 1,
              'p_amount_centavos': '150000',
              'p_allocated_on': '2026-11-06',
            },
          ),
        );
        gateway.handlers['apply_investment_allocation_change'] = (_) async => {
          'status': 'conflict',
          'conflict_id': 'cf9',
          'remote_allocation': {
            'id': 'a1',
            'amount_centavos': 100000,
            'allocated_on': '2026-11-05',
            'cancelled_at': null,
            'version': 2,
          },
        };
        await sync.syncOnce('u1');
        final item = (await repo.items()).single;
        expect(item.mineSummary, 'Alterar: R\$ 1.500,00 · 06/11/2026');
        expect(item.serverSummary, 'R\$ 1.000,00 · 05/11/2026');

        gateway.handlers['resolve_sync_conflict'] = (_) async => {
          'status': 'resolved',
          'result': {
            'status': 'applied',
            'allocation': {
              'id': 'a1',
              'amount_centavos': 120000,
              'allocated_on': '2026-11-07',
              'accounting_period_id': 'p1',
              'cancelled_at': null,
              'version': 3,
              'created_at': 'x',
              'updated_at': 'z',
            },
          },
        };
        await repo.resolve(
          item,
          ConflictResolution.edit,
          editedRequest: buildEditedRequest(
            item,
            amountCentavos: BigInt.from(120000),
            allocatedOn: CalendarDate(2026, 11, 7),
          ),
        );
        expect(gateway.calls.last.$2['p_request'], {
          'action': 'update',
          'amount_centavos': '120000',
          'allocated_on': '2026-11-07',
        });
        final row = await db
            .customSelect(
              "SELECT version, amount_centavos, allocated_on "
              "FROM investment_allocations WHERE id = 'a1'",
            )
            .getSingle();
        expect(row.read<int>('version'), 3);
        expect(row.read<String>('amount_centavos'), '120000');
        expect(row.read<String>('allocated_on'), '2026-11-07');
        expect(await repo.items(), isEmpty);
      },
    );

    test(
      'recusa vira item com motivo; descartar edição restaura o servidor',
      () async {
        await sync.enqueue(
          OutboxOperation(
            ownerId: 'u1',
            idempotencyKey: 'k2',
            entityType: 'category',
            entityId: 'c1',
            expectedVersion: 2,
            rpc: 'apply_category_change',
            params: {
              'p_action': 'rename',
              'p_category_id': 'c1',
              'p_expected_version': 2,
              'p_kind': null,
              'p_name': 'Nome ruim',
            },
          ),
        );
        gateway.handlers['apply_category_change'] = (_) async =>
            throw const SyncRejectedError('nome não aceito');
        await sync.syncOnce('u1');

        final item = (await repo.items()).single;
        expect(item.kind, AttentionKind.rejected);
        expect(item.reason, 'nome não aceito');

        // Tentar de novo volta para a fila.
        await repo.retry(item);
        expect((await sync.operations('u1')).single.state, OutboxState.pending);
        await sync.syncOnce('u1');

        await db.customStatement(
          "INSERT INTO sync_cursors (owner_id, source_table, last_order_value) "
          "VALUES ('u1', 'categories', '2026-01-01T00:00:00Z')",
        );
        await repo.discard((await repo.items()).single);
        expect(await sync.operations('u1'), isEmpty);
        final v = await db
            .customSelect("SELECT version FROM categories WHERE id = 'c1'")
            .getSingle();
        expect(
          v.read<int>('version'),
          0,
          reason: 'o próximo download restaura',
        );
        final cursors = await db
            .customSelect('SELECT COUNT(*) AS n FROM sync_cursors')
            .getSingle();
        expect(cursors.read<int>('n'), 0);
      },
    );

    test('descartar criação recusada remove o registro local', () async {
      await db.customStatement(
        'INSERT INTO categories (id, owner_id, version, created_at, updated_at, '
        "kind, name, is_active) VALUES ('c2', 'u1', 1, 'x', 'x', 'expense', 'Nova', 1)",
      );
      await sync.enqueue(
        OutboxOperation(
          ownerId: 'u1',
          idempotencyKey: 'k3',
          entityType: 'category',
          entityId: 'c2',
          expectedVersion: 0,
          rpc: 'apply_category_change',
          params: {'p_action': 'create', 'p_category_id': 'c2'},
        ),
      );
      gateway.handlers['apply_category_change'] = (_) async =>
          throw const SyncRejectedError('recusada');
      await sync.syncOnce('u1');
      await repo.discard((await repo.items()).single);
      final n = await db
          .customSelect("SELECT COUNT(*) AS n FROM categories WHERE id = 'c2'")
          .getSingle();
      expect(n.read<int>('n'), 0);
      expect(await sync.operations('u1'), isEmpty);
    });

    test(
      'conflito da configuração de período: manter a do aparelho reaplica',
      () async {
        // Este aparelho trocou para ciclo dia 20 (versão 1 → 2); outro
        // aparelho já tinha trocado para dia 5 (servidor na versão 2).
        await db.customStatement(
          'INSERT INTO period_settings (id, owner_id, version, created_at, '
          "updated_at, mode, custom_start_day) VALUES "
          "('u1', 'u1', 2, 'x', 'x', 'custom_cycle', 20)",
        );
        await db.customStatement(
          'INSERT INTO sync_conflicts (id, owner_id, version, created_at, '
          'updated_at, entity_type, entity_id, expected_version, '
          'remote_version, local_snapshot_json, remote_snapshot_json, state) '
          "VALUES ('cfs', 'u1', 1, 'x', 'x', 'period_settings', 'u1', 1, 2, "
          "'{\"p_expected_version\":1,\"p_mode\":\"custom_cycle\","
          "\"p_custom_start_day\":20}', "
          "'{\"id\":\"u1\",\"mode\":\"custom_cycle\","
          "\"custom_start_day\":5,\"version\":2}', 'open')",
        );
        gateway.handlers['resolve_sync_conflict'] = (_) async => {
          'status': 'resolved',
          'result': {
            'status': 'applied',
            'settings': {
              'id': 'u1',
              'mode': 'custom_cycle',
              'custom_start_day': 20,
              'version': 3,
              'created_at': 'x',
              'updated_at': 'z',
            },
          },
        };
        final item = (await repo.items()).single;
        expect(item.title, 'Configuração de período');
        expect(item.mineSummary, 'Mudar para Ciclo personalizado (dia 20)');
        expect(item.serverSummary, 'Ciclo personalizado (dia 5)');
        expect(item.canKeepLocal, isTrue);
        expect(item.canEdit, isFalse);
        await repo.resolve(item, ConflictResolution.keepLocal);
        final row = await db
            .customSelect('SELECT * FROM period_settings')
            .getSingle();
        expect(row.data['custom_start_day'], 20);
        expect(row.data['version'], 3);
      },
    );

    test('conflito da configuração de período: manter a do servidor', () async {
      await db.customStatement(
        'INSERT INTO period_settings (id, owner_id, version, created_at, '
        "updated_at, mode, custom_start_day) VALUES "
        "('u1', 'u1', 2, 'x', 'x', 'custom_cycle', 20)",
      );
      await db.customStatement(
        'INSERT INTO sync_conflicts (id, owner_id, version, created_at, '
        'updated_at, entity_type, entity_id, expected_version, '
        'remote_version, local_snapshot_json, remote_snapshot_json, state) '
        "VALUES ('cfs', 'u1', 1, 'x', 'x', 'period_settings', 'u1', 1, 2, "
        "'{\"p_expected_version\":1,\"p_mode\":\"custom_cycle\","
        "\"p_custom_start_day\":20}', '{}', 'open')",
      );
      gateway.handlers['resolve_sync_conflict'] = (_) async => {
        'status': 'resolved',
        'record': {
          'id': 'u1',
          'mode': 'calendar_month',
          'custom_start_day': null,
          'version': 2,
          'created_at': 'x',
          'updated_at': 'y',
        },
      };
      final item = (await repo.items()).single;
      await repo.resolve(item, ConflictResolution.keepRemote);
      final row = await db
          .customSelect('SELECT * FROM period_settings')
          .getSingle();
      expect(row.data['mode'], 'calendar_month');
      expect(row.data['custom_start_day'], isNull);
    });
  });

  group('Web (repositório remoto)', () {
    test('lê conflitos abertos e resolve pela RPC', () async {
      final reader = FakeReader()
        ..tables['sync_conflicts'] = [
          {
            'id': 'cf9',
            'entity_type': 'category',
            'entity_id': 'c1',
            'local_snapshot': {
              'action': 'rename',
              'name': 'Meu',
              'expected_version': 1,
            },
            'remote_snapshot': {
              'name': 'Dele',
              'is_active': true,
              'version': 2,
            },
          },
        ];
      final gateway = FakeGateway()
        ..handlers['resolve_sync_conflict'] = (_) async => {
          'status': 'resolved',
        };
      final repo = RemoteAttentionRepository(
        reader,
        gateway,
        newId: () => 'op',
      );
      final item = (await repo.items()).single;
      expect(item.mineSummary, 'Renomear para "Meu"');
      expect(await repo.openCount(), 1);

      await repo.resolve(item, ConflictResolution.keepRemote);
      expect(gateway.calls.single.$2['p_conflict_id'], 'cf9');
      expect(gateway.calls.single.$2['p_operation_id'], 'op');
    });
  });

  group('tela', () {
    testWidgets('mostra o conflito, confirma antes de manter o servidor', (
      tester,
    ) async {
      final resolved = <ConflictResolution>[];
      final repo = _FakeAttentionRepository(resolved);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attentionRepositoryProvider.overrideWith((ref) async => repo),
          ],
          child: const MaterialApp(home: AttentionScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Categoria: alterada em dois lugares'), findsOneWidget);
      expect(find.text('Sua alteração: Renomear para "Meu"'), findsOneWidget);
      expect(find.text('No servidor: "Dele"'), findsOneWidget);

      await tester.tap(find.byKey(const Key('manter-servidor-cf1')));
      await tester.pumpAndSettle();
      expect(find.text('Manter a versão do servidor?'), findsOneWidget);
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(resolved, isEmpty, reason: 'nada acontece sem confirmar');
    });
  });
}

class _FakeAttentionRepository implements AttentionRepository {
  _FakeAttentionRepository(this.resolved);
  final List<ConflictResolution> resolved;

  @override
  Future<List<AttentionItem>> items() async => [
    const AttentionItem(
      kind: AttentionKind.conflict,
      id: 'cf1',
      entityType: 'category',
      entityId: 'c1',
      request: {'action': 'rename', 'name': 'Meu'},
      remote: {'name': 'Dele', 'is_active': true, 'version': 2},
    ),
  ];

  @override
  Future<void> resolve(
    AttentionItem item,
    ConflictResolution resolution, {
    Map<String, dynamic>? editedRequest,
  }) async {
    resolved.add(resolution);
  }

  @override
  Future<void> discard(AttentionItem item) async {}

  @override
  Future<void> retry(AttentionItem item) async {}
}
