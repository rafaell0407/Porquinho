@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

class FakeGateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];
  final failRpcs = <String>{};

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc, params));
    if (failRpcs.contains(rpc)) throw const SyncTransientError('sem rede');
    return {'status': 'applied'};
  }
}

void main() {
  late PorquinhoDatabase db;
  late LocalEntryRepository repo;
  late EntryService service;
  late CategoryService categories;
  late PeriodService periods;
  late LocalTotalsRepository totals;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    final recorder = LocalChangeRecorder(
      db,
      clock: () => DateTime.utc(2026, 11, 10),
      newId: () => 'a${++ids}',
    );
    final periodRepo = LocalPeriodRepository(
      db,
      'u1',
      recorder,
      clock: () => DateTime.utc(2026, 11, 10),
    );
    periods = PeriodService(periodRepo, newId: () => 'p${++ids}');
    final catRepo = LocalCategoryRepository(
      db,
      'u1',
      recorder,
      clock: () => DateTime.utc(2026, 11, 10),
    );
    categories = CategoryService(catRepo, newId: () => 'c${++ids}');
    repo = LocalEntryRepository(
      db,
      'u1',
      recorder,
      clock: () => DateTime.utc(2026, 11, 10),
    );
    service = EntryService(repo, catRepo, periods, newId: () => 'e${++ids}');
    totals = LocalTotalsRepository(db, 'u1');
    await periods.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
  });
  tearDown(() => db.close());

  Future<String> periodOf(CalendarDate date) async =>
      (await periods.periodFor(date))!.id;

  Future<BigInt> surplus(CalendarDate date) async =>
      (await totals.totalsFor(await periodOf(date))).surplus;

  EntryDraft income(
    int cents,
    CalendarDate date, {
    String? description,
    String? categoryId,
    String? subcategoryId,
  }) => EntryDraft(
    kind: EntryKind.income,
    amount: c(cents),
    date: date,
    description: description,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
  );

  EntryDraft expense(int cents, CalendarDate date, {CalendarDate? dueOn}) =>
      EntryDraft(
        kind: EntryKind.expense,
        amount: c(cents),
        date: date,
        dueOn: dueOn,
      );

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  group('receita avulsa (Entrega 39)', () {
    test(
      'cadastra, entra na sobra do período da data de recebimento',
      () async {
        final id = await service.create(
          income(500000, d(2026, 11, 5), description: ' Salário '),
        );
        final saved = (await repo.entry(EntryKind.income, id))!;
        expect(saved.status, 'received');
        expect(saved.description, 'Salário');
        expect(saved.version, 1);
        expect(await surplus(d(2026, 11, 5)), c(500000));
      },
    );

    test('data futura e passada são aceitas (RN004/RN008)', () async {
      await service.create(income(1000, d(2026, 11, 30)));
      await periods.createCovering(d(2026, 12, 15));
      await service.create(income(2000, d(2026, 12, 15)));
      expect(await surplus(d(2026, 11, 30)), c(1000));
      expect(await surplus(d(2026, 12, 15)), c(2000));
    });

    test(
      'período inexistente: pergunta antes; nada é gravado até confirmar',
      () async {
        await expectLater(
          service.create(income(1000, d(2026, 8, 20))),
          throwsA(
            isA<PeriodMissingException>().having(
              (e) => e.plan.question,
              'pergunta',
              'Criar os 3 períodos de agosto de 2026 a outubro de 2026?',
            ),
          ),
        );
        expect(await count('income_entries'), 0);
        expect((await periods.planFor(d(2026, 8, 20)))!.count, 3);

        await service.createMissingPeriods(d(2026, 8, 20));
        await service.create(income(1000, d(2026, 8, 20)));
        expect(await surplus(d(2026, 8, 20)), c(1000));
      },
    );

    test('editar a data move o valor para o período certo', () async {
      await periods.createCovering(d(2026, 10, 1));
      final id = await service.create(income(70000, d(2026, 11, 5)));
      final current = (await repo.entry(EntryKind.income, id))!;
      await service.update(current, income(70000, d(2026, 10, 20)));
      expect(await surplus(d(2026, 11, 5)), BigInt.zero);
      expect(await surplus(d(2026, 10, 20)), c(70000));
      final moved = (await repo.entry(EntryKind.income, id))!;
      expect(moved.version, 2);
      expect(moved.periodId, await periodOf(d(2026, 10, 20)));
    });

    test('editar o valor recalcula sem contar duas vezes', () async {
      final id = await service.create(income(100000, d(2026, 11, 5)));
      await service.update(
        (await repo.entry(EntryKind.income, id))!,
        income(150000, d(2026, 11, 5)),
      );
      expect(await surplus(d(2026, 11, 5)), c(150000));
    });

    test(
      'cancelar tira da sobra, mantém no histórico e trava edição',
      () async {
        final id = await service.create(income(100000, d(2026, 11, 5)));
        final current = (await repo.entry(EntryKind.income, id))!;
        await service.cancel(current);
        expect(await surplus(d(2026, 11, 5)), BigInt.zero);
        final cancelled = (await repo.entry(EntryKind.income, id))!;
        expect(cancelled.isCancelled, isTrue);
        expect(cancelled.amount, c(100000), reason: 'não apaga fisicamente');
        expect(await count('income_entries'), 1);
        await expectLater(
          service.update(cancelled, income(1, d(2026, 11, 5))),
          throwsA(isA<ChangeRejectedException>()),
        );
        await expectLater(
          service.cancel(cancelled),
          throwsA(isA<ChangeRejectedException>()),
        );
      },
    );

    test('registro, auditoria e fila entram juntos em cada ação', () async {
      final id = await service.create(income(100000, d(2026, 11, 5)));
      final cur = (await repo.entry(EntryKind.income, id))!;
      await service.update(cur, income(120000, d(2026, 11, 5)));
      await service.cancel((await repo.entry(EntryKind.income, id))!);

      final audits = await db
          .customSelect(
            "SELECT operation, old_snapshot_json, new_snapshot_json FROM audit_events "
            "WHERE entity_id = '$id' ORDER BY rowid",
          )
          .get();
      expect(audits.map((r) => r.read<String>('operation')), [
        'create',
        'update',
        'cancel',
      ]);
      expect(audits[1].read<String>('old_snapshot_json'), contains('100000'));
      expect(audits[1].read<String>('new_snapshot_json'), contains('120000'));
      final ops = (await SyncService(
        db,
        FakeGateway(),
      ).operations('u1')).where((o) => o.entityId == id).toList();
      expect(ops.map((o) => o.params['p_action']), [
        'create',
        'update',
        'cancel',
      ]);
      expect(ops.map((o) => o.expectedVersion), [0, 1, 2]);
    });

    test('valor zero é aceito; valor acima de 2^53 é exato', () async {
      await service.create(income(0, d(2026, 11, 5)));
      final big = BigInt.parse('9007199254740993');
      final id = await service.create(
        EntryDraft(kind: EntryKind.income, amount: big, date: d(2026, 11, 6)),
      );
      expect((await repo.entry(EntryKind.income, id))!.amount, big);
      expect(await surplus(d(2026, 11, 6)), big);
    });

    test('salvar localmente leva até 500 ms (RN043)', () async {
      final sw = Stopwatch()..start();
      await service.create(income(1000, d(2026, 11, 5)));
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });

  group('despesa avulsa (Entrega 40)', () {
    test('nasce pendente e já entra na sobra', () async {
      await service.create(income(300000, d(2026, 11, 1)));
      final id = await service.create(expense(120000, d(2026, 11, 5)));
      final e = (await repo.entry(EntryKind.expense, id))!;
      expect(e.status, 'pending');
      expect(e.paidOn, isNull);
      expect(await surplus(d(2026, 11, 5)), c(180000));
    });

    test('pagar registra a data e não altera a sobra', () async {
      final id = await service.create(expense(120000, d(2026, 11, 5)));
      final before = await surplus(d(2026, 11, 5));
      await service.pay(
        (await repo.entry(EntryKind.expense, id))!,
        d(2026, 11, 8),
      );
      final paid = (await repo.entry(EntryKind.expense, id))!;
      expect(paid.status, 'paid');
      expect(paid.paidOn, d(2026, 11, 8));
      expect(await surplus(d(2026, 11, 5)), before);
    });

    test('pagar em outro mês não move a despesa de período', () async {
      final id = await service.create(expense(50000, d(2026, 11, 5)));
      await periods.createCovering(d(2026, 12, 10));
      await service.pay(
        (await repo.entry(EntryKind.expense, id))!,
        d(2026, 12, 3),
      );
      expect(await surplus(d(2026, 11, 5)), c(-50000));
      expect(await surplus(d(2026, 12, 10)), BigInt.zero);
    });

    test('vencimento em outro mês não muda o período', () async {
      await periods.createCovering(d(2026, 12, 10));
      final id = await service.create(
        expense(50000, d(2026, 11, 5), dueOn: d(2026, 12, 5)),
      );
      expect((await repo.entry(EntryKind.expense, id))!.dueOn, d(2026, 12, 5));
      expect(await surplus(d(2026, 11, 5)), c(-50000));
      expect(await surplus(d(2026, 12, 5)), BigInt.zero);
    });

    test('pendente permanece no período original', () async {
      await service.create(expense(40000, d(2026, 11, 5)));
      await periods.createCovering(d(2027, 1, 10));
      expect(await surplus(d(2026, 11, 5)), c(-40000));
      expect(await surplus(d(2027, 1, 10)), BigInt.zero);
    });

    test(
      'já paga: cadastro e pagamento juntos, dois eventos de auditoria',
      () async {
        final id = await service.create(
          expense(25000, d(2026, 11, 5)),
          alreadyPaid: true,
          paidOn: d(2026, 11, 5),
        );
        final e = (await repo.entry(EntryKind.expense, id))!;
        expect(e.status, 'paid');
        expect(e.version, 2);
        final audits = await db
            .customSelect(
              "SELECT operation FROM audit_events WHERE entity_id = '$id' ORDER BY rowid",
            )
            .get();
        expect(audits.map((r) => r.read<String>('operation')), [
          'create',
          'pay',
        ]);
        expect(
          await surplus(d(2026, 11, 5)),
          c(-25000),
          reason: 'conta uma vez',
        );
        final ops = (await SyncService(
          db,
          FakeGateway(),
        ).operations('u1')).where((o) => o.entityId == id).toList();
        expect(ops.map((o) => o.params['p_action']), ['create', 'pay']);
        expect(ops.map((o) => o.expectedVersion), [0, 1]);
      },
    );

    test('pagar de novo corrige a data do pagamento', () async {
      final id = await service.create(expense(25000, d(2026, 11, 5)));
      await service.pay(
        (await repo.entry(EntryKind.expense, id))!,
        d(2026, 11, 6),
      );
      await service.pay(
        (await repo.entry(EntryKind.expense, id))!,
        d(2026, 11, 7),
      );
      final e = (await repo.entry(EntryKind.expense, id))!;
      expect(e.paidOn, d(2026, 11, 7));
      expect(e.version, 3);
      expect(await surplus(d(2026, 11, 5)), c(-25000));
    });

    test('cancelar despesa paga remove da sobra e trava pagamento', () async {
      final id = await service.create(
        expense(25000, d(2026, 11, 5)),
        alreadyPaid: true,
        paidOn: d(2026, 11, 5),
      );
      await service.cancel((await repo.entry(EntryKind.expense, id))!);
      expect(await surplus(d(2026, 11, 5)), BigInt.zero);
      await expectLater(
        service.pay((await repo.entry(EntryKind.expense, id))!, d(2026, 11, 9)),
        throwsA(isA<ChangeRejectedException>()),
      );
    });

    test('editar despesa paga é permitido e recalcula', () async {
      final id = await service.create(
        expense(25000, d(2026, 11, 5)),
        alreadyPaid: true,
        paidOn: d(2026, 11, 5),
      );
      await service.update(
        (await repo.entry(EntryKind.expense, id))!,
        expense(30000, d(2026, 11, 5)),
      );
      final e = (await repo.entry(EntryKind.expense, id))!;
      expect(e.status, 'paid', reason: 'editar não desfaz o pagamento');
      expect(await surplus(d(2026, 11, 5)), c(-30000));
    });

    test('receita não aceita vencimento nem pagamento', () async {
      await expectLater(
        service.create(
          EntryDraft(
            kind: EntryKind.income,
            amount: c(1),
            date: d(2026, 11, 5),
            dueOn: d(2026, 11, 9),
          ),
        ),
        throwsA(isA<ChangeRejectedException>()),
      );
      final id = await service.create(income(100, d(2026, 11, 5)));
      await expectLater(
        service.pay((await repo.entry(EntryKind.income, id))!, d(2026, 11, 6)),
        throwsA(isA<ChangeRejectedException>()),
      );
    });
  });

  group('validações iguais às da RPC', () {
    test(
      'categoria do outro tipo, inativa ou inexistente é recusada',
      () async {
        await categories.createCategory(CategoryKind.expense, 'Mercado');
        await categories.createCategory(CategoryKind.income, 'Salário');
        final data = await categories.load();
        final expenseCat = data.categories.firstWhere(
          (x) => x.kind == CategoryKind.expense,
        );
        final incomeCat = data.categories.firstWhere(
          (x) => x.kind == CategoryKind.income,
        );

        await expectLater(
          service.create(income(1, d(2026, 11, 5), categoryId: expenseCat.id)),
          throwsA(isA<ChangeRejectedException>()),
        );
        await expectLater(
          service.create(income(1, d(2026, 11, 5), categoryId: 'nao-existe')),
          throwsA(isA<ChangeRejectedException>()),
        );
        await categories.deactivateCategory(incomeCat);
        await expectLater(
          service.create(income(1, d(2026, 11, 5), categoryId: incomeCat.id)),
          throwsA(isA<ChangeRejectedException>()),
        );
        expect(await count('income_entries'), 0);
      },
    );

    test(
      'lançamento antigo mantém categoria desativada depois; nova escolha não',
      () async {
        await categories.createCategory(CategoryKind.income, 'Salário');
        final cat = (await categories.load()).categories.single;
        final id = await service.create(
          income(100, d(2026, 11, 5), categoryId: cat.id),
        );
        await categories.deactivateCategory(cat);
        final current = (await repo.entry(EntryKind.income, id))!;
        await service.update(
          current,
          income(200, d(2026, 11, 5), categoryId: cat.id),
        );
        expect((await repo.entry(EntryKind.income, id))!.amount, c(200));
      },
    );

    test('subcategoria exige categoria e pertencer a ela', () async {
      await categories.createCategory(CategoryKind.income, 'A');
      await categories.createCategory(CategoryKind.income, 'B');
      final cats = (await categories.load()).categories;
      await categories.createSubcategory(cats.first, 'Sub');
      final sub = (await categories.load()).subcategories.single;
      await expectLater(
        service.create(income(1, d(2026, 11, 5), subcategoryId: sub.id)),
        throwsA(isA<ChangeRejectedException>()),
      );
      await expectLater(
        service.create(
          income(
            1,
            d(2026, 11, 5),
            categoryId: cats.last.id,
            subcategoryId: sub.id,
          ),
        ),
        throwsA(isA<ChangeRejectedException>()),
      );
      await service.create(
        income(
          1,
          d(2026, 11, 5),
          categoryId: cats.first.id,
          subcategoryId: sub.id,
        ),
      );
    });

    test('descrição muito longa é recusada', () async {
      await expectLater(
        service.create(income(1, d(2026, 11, 5), description: 'x' * 121)),
        throwsA(isA<ChangeRejectedException>()),
      );
    });
  });

  group('fila e dependências', () {
    test(
      'lançamento espera a categoria e o período criados no aparelho',
      () async {
        await categories.createCategory(CategoryKind.income, 'Salário');
        final cat = (await categories.load()).categories.single;
        await service.createMissingPeriods(d(2026, 10, 5));
        await service.create(income(100, d(2026, 10, 5), categoryId: cat.id));

        final ops = await SyncService(db, FakeGateway()).operations('u1');
        final entryOp = ops.firstWhere((o) => o.entityType == 'income_entry');
        expect(
          entryOp.dependsOn,
          containsAll([cat.id, await periodOf(d(2026, 10, 5))]),
        );

        // Categoria sem rede: o lançamento fica esperando, sem tentativa nem recusa.
        final gateway = FakeGateway()..failRpcs.add('apply_category_change');
        final sync = SyncService(
          db,
          gateway,
          clock: () => DateTime.utc(2026, 11, 10),
        );
        await sync.syncOnce('u1');
        expect(
          gateway.calls.where((c) => c.$1 == 'apply_income_entry_change'),
          isEmpty,
        );
        expect(
          (await sync.operations(
            'u1',
          )).where((o) => o.state == OutboxState.rejected),
          isEmpty,
        );
      },
    );

    test(
      'com rede, tudo sobe na ordem: período, categoria, lançamento',
      () async {
        await categories.createCategory(CategoryKind.income, 'Salário');
        final cat = (await categories.load()).categories.single;
        await service.createMissingPeriods(d(2026, 10, 5));
        await service.create(income(100, d(2026, 10, 5), categoryId: cat.id));
        final gateway = FakeGateway();
        await SyncService(db, gateway).syncOnce('u1');
        final order = gateway.calls.map((c) => c.$1).toList();
        expect(order.last, 'apply_income_entry_change');
        expect(
          order.indexOf('create_earlier_accounting_period') <
              order.indexOf('apply_income_entry_change'),
          isTrue,
        );
        expect(
          order.indexOf('apply_category_change') <
              order.indexOf('apply_income_entry_change'),
          isTrue,
        );
        expect(await SyncService(db, gateway).operations('u1'), isEmpty);
      },
    );
  });
}
