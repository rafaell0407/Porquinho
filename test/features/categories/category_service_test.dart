@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/categories/remote_category_repository.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

class FakeGateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];
  String status = 'applied';
  Object? failWith;

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc, params));
    if (failWith != null) throw failWith!;
    return {'status': status};
  }
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
  late PorquinhoDatabase db;
  late LocalCategoryRepository repo;
  late CategoryService service;
  var ids = 0;

  setUp(() {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    repo = LocalCategoryRepository(
      db,
      'u1',
      LocalChangeRecorder(
        db,
        clock: () => DateTime.utc(2026, 11, 10),
        newId: () => 'a${++ids}',
      ),
      clock: () => DateTime.utc(2026, 11, 10),
    );
    service = CategoryService(repo, newId: () => 'i${++ids}');
  });
  tearDown(() => db.close());

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  group('validação do nome (igual à da RPC: obrigatório)', () {
    test('vazio e só espaços são recusados', () {
      expect(CategoryService.validateName(''), isNotNull);
      expect(CategoryService.validateName('   '), isNotNull);
      expect(CategoryService.validateName('Mercado'), isNull);
      expect(CategoryService.validateName('x' * 61), isNotNull);
    });

    test('nome inválido não grava nada', () async {
      await expectLater(
        service.createCategory(CategoryKind.expense, '  '),
        throwsA(isA<ChangeRejectedException>()),
      );
      expect(await count('categories'), 0);
      expect(await count('sync_outbox'), 0);
    });
  });

  test('criar grava registro, auditoria e fila; nome é aparado', () async {
    await service.createCategory(CategoryKind.expense, '  Mercado ');
    final cats = await repo.categories();
    expect(cats.single.name, 'Mercado');
    expect(cats.single.kind, CategoryKind.expense);
    expect(cats.single.isActive, isTrue);
    expect(cats.single.version, 1);
    expect(await count('audit_events'), 1);
    final op = (await SyncService(db, FakeGateway()).operations('u1')).single;
    expect(op.params['p_action'], 'create');
    expect(op.params['p_kind'], 'expense');
    expect(op.expectedVersion, 0);
  });

  test('criar devolve o id da categoria e da subcategoria', () async {
    final id = await service.createCategory(CategoryKind.expense, 'Mercado');
    final cat = (await repo.categories()).single;
    expect(cat.id, id);
    final subId = await service.createSubcategory(cat, 'Feira');
    expect((await repo.subcategories()).single.id, subId);
  });

  test('renomear mantém o vínculo (mesmo id) e sobe a versão', () async {
    await service.createCategory(CategoryKind.income, 'Salario');
    final before = (await repo.categories()).single;
    await service.renameCategory(before, 'Salário');
    final after = (await repo.categories()).single;
    expect(after.id, before.id);
    expect(after.name, 'Salário');
    expect(after.version, 2);
    expect(after.kind, CategoryKind.income, reason: 'tipo é imutável');
    final ops = await SyncService(db, FakeGateway()).operations('u1');
    expect(ops.map((o) => o.expectedVersion), [0, 1]);
    expect(await count('audit_events'), 2);
  });

  test('desativar não apaga; categoria inativa sai da lista ativa', () async {
    await service.createCategory(CategoryKind.expense, 'Lazer');
    final c = (await repo.categories()).single;
    await service.deactivateCategory(c);
    final data = await service.load();
    expect(data.ofKind(CategoryKind.expense, active: true), isEmpty);
    expect(
      data.ofKind(CategoryKind.expense, active: false).single.name,
      'Lazer',
    );
    await expectLater(
      service.deactivateCategory(data.categories.single),
      throwsA(isA<ChangeRejectedException>()),
    );
  });

  group('subcategorias (Entrega 37)', () {
    test('exigem categoria ativa', () async {
      await service.createCategory(CategoryKind.expense, 'Mercado');
      final c = (await repo.categories()).single;
      await service.createSubcategory(c, 'Feira');
      expect((await repo.subcategories()).single.categoryId, c.id);

      await service.deactivateCategory(c);
      final inactive = (await repo.categories()).single;
      await expectLater(
        service.createSubcategory(inactive, 'Padaria'),
        throwsA(isA<ChangeRejectedException>()),
      );
    });

    test('renomear e desativar; fila leva dependência da categoria', () async {
      await service.createCategory(CategoryKind.expense, 'Mercado');
      final c = (await repo.categories()).single;
      await service.createSubcategory(c, 'Feira');
      final s = (await repo.subcategories()).single;
      await service.renameSubcategory(s, 'Feira livre');
      await service.deactivateSubcategory((await repo.subcategories()).single);

      final subs = await repo.subcategories();
      expect(subs.single.name, 'Feira livre');
      expect(subs.single.isActive, isFalse);
      expect(subs.single.version, 3);

      final ops = await SyncService(db, FakeGateway()).operations('u1');
      final subOps = ops.where((o) => o.entityType == 'subcategory').toList();
      expect(subOps.first.dependsOn, [c.id]);
      // Atualizações não levam category_id (a RPC recusa).
      expect(subOps[1].params['p_category_id'], isNull);
    });
  });

  test(
    'sugestões viram categorias comuns, todas ou só as escolhidas',
    () async {
      await service.addSuggestions(
        income: suggestedIncomeCategories,
        expense: ['Mercado', 'Lazer'],
      );
      final cats = await repo.categories();
      expect(cats.length, 5);
      expect(cats.where((c) => c.kind == CategoryKind.income).length, 3);
      expect(await count('sync_outbox'), 5);
      expect(suggestedExpenseCategories.length, 10);
      expect(suggestedIncomeCategories, [
        'Salário',
        'Renda extra',
        'Rendimentos',
      ]);
      expect(suggestedExpenseCategories, isNot(contains('Saldo inicial')));
    },
  );

  test(
    'offline: tudo fica na fila; sobe em ordem quando a rede volta',
    () async {
      await service.createCategory(CategoryKind.expense, 'Mercado');
      final c = (await repo.categories()).single;
      await service.createSubcategory(c, 'Feira');
      await service.renameCategory(c, 'Supermercado');

      final gateway = FakeGateway();
      expect(await SyncService(db, gateway).syncOnce('u1'), 3);
      expect(gateway.calls.map((x) => x.$2['p_action']), [
        'create',
        'create',
        'rename',
      ]);
    },
  );

  group('Web (repositório remoto)', () {
    test('lê categorias e subcategorias do servidor', () async {
      final reader = FakeReader()
        ..tables['categories'] = [
          {
            'id': 'c1',
            'kind': 'income',
            'name': 'Salário',
            'is_active': true,
            'version': 2,
          },
        ]
        ..tables['subcategories'] = [
          {
            'id': 's1',
            'category_id': 'c1',
            'name': 'Extra',
            'is_active': false,
            'version': 1,
          },
        ];
      final web = CategoryService(
        RemoteCategoryRepository(reader, FakeGateway()),
      );
      final data = await web.load();
      expect(data.categories.single.kind, CategoryKind.income);
      expect(data.subcategories.single.isActive, isFalse);
    });

    test('grava direto no servidor, com a versão lida', () async {
      final gateway = FakeGateway();
      final web = CategoryService(
        RemoteCategoryRepository(FakeReader(), gateway, newId: () => 'op'),
      );
      const cat = CategoryRecord(
        id: 'c1',
        kind: CategoryKind.expense,
        name: 'A',
        isActive: true,
        version: 4,
      );
      await web.renameCategory(cat, 'B');
      expect(gateway.calls.single.$1, 'apply_category_change');
      expect(gateway.calls.single.$2['p_expected_version'], 4);
      expect(gateway.calls.single.$2['p_operation_id'], 'op');
    });

    test('conflito e recusa viram mensagens', () async {
      final gateway = FakeGateway()..status = 'conflict';
      final web = CategoryService(
        RemoteCategoryRepository(FakeReader(), gateway),
      );
      await expectLater(
        web.createCategory(CategoryKind.expense, 'X'),
        throwsA(isA<ChangeConflictException>()),
      );
      gateway.failWith = const SyncRejectedError('nome inválido');
      await expectLater(
        web.createCategory(CategoryKind.expense, 'X'),
        throwsA(isA<ChangeRejectedException>()),
      );
    });
  });
}
