@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/money.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
import 'package:porquinho/features/investments/remote_investment_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

class FakeGateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic> response = {'status': 'applied'};
  SyncRejectedError? reject;

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc, params));
    if (reject != null) throw reject!;
    return response;
  }
}

class FakeReader implements RemoteTableReader {
  FakeReader(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    List<RemoteFilter> filters = const [],
    String? orderBy,
  }) async => rows;
}

void main() {
  late PorquinhoDatabase db;
  late LocalInvestmentRepository repo;
  late InvestmentService service;
  late PeriodService periods;
  late LocalTotalsRepository totals;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    DateTime clock() => DateTime.utc(2026, 11, 10);
    final recorder = LocalChangeRecorder(
      db,
      clock: clock,
      newId: () => 'a${++ids}',
    );
    periods = PeriodService(
      LocalPeriodRepository(db, 'u1', recorder, clock: clock),
      newId: () => 'p${++ids}',
    );
    repo = LocalInvestmentRepository(db, 'u1', recorder, clock: clock);
    service = InvestmentService(repo, periods, newId: () => 'i${++ids}');
    totals = LocalTotalsRepository(db, 'u1');
    await periods.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
  });
  tearDown(() => db.close());

  Future<BigInt> surplus(CalendarDate date) async =>
      (await totals.totalsFor((await periods.periodFor(date))!.id)).surplus;

  InvestmentDraft draft(int cents, CalendarDate date) =>
      InvestmentDraft(amount: c(cents), date: date);

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  group('validação (mesmas regras da RPC)', () {
    test('valor é obrigatório', () async {
      await expectLater(
        service.create(InvestmentDraft(amount: null, date: d(2026, 11, 5))),
        throwsA(isA<ChangeRejectedException>()),
      );
      expect(await count('investment_allocations'), 0);
    });

    test('negativo e acima do limite são recusados; zero é aceito', () async {
      await expectLater(
        service.create(draft(-1, d(2026, 11, 5))),
        throwsA(isA<ChangeRejectedException>()),
      );
      await expectLater(
        service.create(
          InvestmentDraft(
            amount: maxCentavos + BigInt.one,
            date: d(2026, 11, 5),
          ),
        ),
        throwsA(isA<ChangeRejectedException>()),
      );
      await service.create(draft(0, d(2026, 11, 5)));
      expect(await count('investment_allocations'), 1);
    });

    test('mais de duas casas decimais são recusadas no valor digitado', () {
      expect(
        () => parseBrlToCentavos('10,005'),
        throwsA(isA<MoneyFormatException>()),
      );
      expect(
        () => parseBrlToCentavos('-1'),
        throwsA(isA<MoneyFormatException>()),
      );
      expect(parseBrlToCentavos('0'), BigInt.zero);
    });

    test('período inexistente: pergunta antes; nada é gravado', () async {
      await expectLater(
        service.create(draft(1000, d(2026, 8, 20))),
        throwsA(isA<PeriodMissingException>()),
      );
      expect(await count('investment_allocations'), 0);
      await service.createMissingPeriods(d(2026, 8, 20));
      await service.create(draft(1000, d(2026, 8, 20)));
      expect(await surplus(d(2026, 8, 20)), c(-1000));
    });
  });

  group('sobra (RN005, RN022, RN029)', () {
    test(
      'investimento salvo offline reduz a sobra do período da data',
      () async {
        final id = await service.create(draft(30000, d(2026, 11, 5)));
        final saved = (await repo.investment(id))!;
        expect(saved.version, 1);
        expect(saved.amount, c(30000));
        expect(await surplus(d(2026, 11, 5)), c(-30000));
      },
    );

    test('data futura e passada são aceitas (D1)', () async {
      await periods.createCovering(d(2026, 12, 15));
      await service.create(draft(1000, d(2026, 11, 30)));
      await service.create(draft(2000, d(2026, 12, 15)));
      expect(await surplus(d(2026, 11, 30)), c(-1000));
      expect(await surplus(d(2026, 12, 15)), c(-2000));
    });

    test('editar a data move o valor de período', () async {
      await periods.createCovering(d(2026, 10, 1));
      final id = await service.create(draft(70000, d(2026, 11, 5)));
      await service.update(
        (await repo.investment(id))!,
        draft(70000, d(2026, 10, 20)),
      );
      expect(await surplus(d(2026, 11, 5)), BigInt.zero);
      expect(await surplus(d(2026, 10, 20)), c(-70000));
      expect((await repo.investment(id))!.version, 2);
    });

    test('editar o valor recalcula sem contar duas vezes', () async {
      final id = await service.create(draft(100000, d(2026, 11, 5)));
      await service.update(
        (await repo.investment(id))!,
        draft(150000, d(2026, 11, 5)),
      );
      expect(await surplus(d(2026, 11, 5)), c(-150000));
    });

    test('cancelar tira da sobra, mantém o registro e trava edição', () async {
      final id = await service.create(draft(100000, d(2026, 11, 5)));
      await service.cancel((await repo.investment(id))!);
      expect(await surplus(d(2026, 11, 5)), BigInt.zero);
      final cancelled = (await repo.investment(id))!;
      expect(cancelled.cancelled, isTrue);
      expect(cancelled.amount, c(100000));
      expect(await count('investment_allocations'), 1);
      await expectLater(
        service.update(cancelled, draft(1, d(2026, 11, 5))),
        throwsA(isA<ChangeRejectedException>()),
      );
      await expectLater(
        service.cancel(cancelled),
        throwsA(isA<ChangeRejectedException>()),
      );
    });

    test(
      'cancelar um investimento antigo devolve ao período original (D5)',
      () async {
        await periods.createCovering(d(2026, 10, 1));
        final id = await service.create(draft(5000, d(2026, 10, 10)));
        await service.cancel((await repo.investment(id))!);
        expect(await surplus(d(2026, 10, 10)), BigInt.zero);
        expect(await surplus(d(2026, 11, 10)), BigInt.zero);
      },
    );
  });

  group('auditoria e fila', () {
    test(
      'registro, auditoria e fila entram juntos; params iguais à RPC',
      () async {
        final id = await service.create(draft(100000, d(2026, 11, 5)));
        await service.update(
          (await repo.investment(id))!,
          draft(120000, d(2026, 11, 6)),
        );
        await service.cancel((await repo.investment(id))!);

        final audits = await db
            .customSelect(
              "SELECT operation, old_snapshot_json, new_snapshot_json "
              "FROM audit_events WHERE entity_id = '$id' ORDER BY rowid",
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
        expect(ops.map((o) => o.rpc).toSet(), {
          'apply_investment_allocation_change',
        });
        expect(ops.map((o) => o.expectedVersion), [0, 1, 2]);
        expect(ops[0].params, {
          'p_action': 'create',
          'p_allocation_id': id,
          'p_expected_version': 0,
          'p_amount_centavos': '100000',
          'p_allocated_on': '2026-11-05',
        });
        expect(ops[1].params['p_allocated_on'], '2026-11-06');
        expect(ops[2].params['p_amount_centavos'], isNull);
        expect(ops[2].params['p_allocated_on'], isNull);
        expect(ops[0].dependsOn, isNotEmpty, reason: 'depende do período');
      },
    );

    test('envio repetido da fila não duplica', () async {
      final id = await service.create(draft(100000, d(2026, 11, 5)));
      final gateway = FakeGateway();
      final sync = SyncService(db, gateway);
      await sync.syncOnce('u1');
      await sync.syncOnce('u1');
      final sent = gateway.calls.where((x) => x.$2['p_allocation_id'] == id);
      expect(sent.length, 1, reason: 'aplicada sai da fila');
      expect(sent.first.$2['p_operation_id'], isNotNull);
    });
  });

  group('repositório remoto (Web)', () {
    test(
      'envia os mesmos parâmetros da RPC com chave idempotente nova',
      () async {
        final gateway = FakeGateway();
        final remote = RemoteInvestmentRepository(
          FakeReader(const []),
          gateway,
          newId: () => 'op1',
        );
        await remote.apply([
          CreateInvestment('x1', draft(2500, d(2026, 11, 5))),
        ]);
        final (rpc, params) = gateway.calls.single;
        expect(rpc, 'apply_investment_allocation_change');
        expect(params, {
          'p_operation_id': 'op1',
          'p_action': 'create',
          'p_allocation_id': 'x1',
          'p_expected_version': 0,
          'p_amount_centavos': '2500',
          'p_allocated_on': '2026-11-05',
        });
      },
    );

    test(
      'recusa vira ChangeRejectedException; conflito vira ChangeConflictException',
      () async {
        final gateway = FakeGateway()
          ..reject = const SyncRejectedError('sem período');
        final remote = RemoteInvestmentRepository(
          FakeReader(const []),
          gateway,
        );
        await expectLater(
          remote.apply([CreateInvestment('x1', draft(1, d(2026, 11, 5)))]),
          throwsA(isA<ChangeRejectedException>()),
        );
        gateway
          ..reject = null
          ..response = {'status': 'conflict'};
        await expectLater(
          remote.apply([CreateInvestment('x1', draft(1, d(2026, 11, 5)))]),
          throwsA(isA<ChangeConflictException>()),
        );
      },
    );

    test('lê linhas do servidor, inclusive cancelada', () async {
      final remote = RemoteInvestmentRepository(
        FakeReader([
          {
            'id': 'a',
            'amount_centavos': 1000,
            'allocated_on': '2026-11-05',
            'version': 2,
            'accounting_period_id': 'p1',
            'cancelled_at': '2026-11-06T00:00:00Z',
          },
          {
            'id': 'b',
            'amount_centavos': '2000',
            'allocated_on': '2026-11-09',
            'version': 1,
            'accounting_period_id': 'p1',
            'cancelled_at': null,
          },
        ]),
        FakeGateway(),
      );
      final list = await remote.investmentsInPeriod('p1');
      expect(list.map((r) => r.id), ['b', 'a']);
      expect(list.last.cancelled, isTrue);
      expect(list.first.amount, c(2000));
    });
  });
}
