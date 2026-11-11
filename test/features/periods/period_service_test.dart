@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/periods/remote_period_repository.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);

class FakeGateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];
  String status = 'applied';

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc, params));
    return {
      'status': status,
      'period': {'id': params['p_period_id'], 'version': 1},
    };
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
  late LocalPeriodRepository repo;
  late PeriodService service;
  var ids = 0;
  var refreshed = 0;
  Future<void> Function()? onRefresh;

  setUp(() {
    ids = 0;
    refreshed = 0;
    onRefresh = null;
    db = PorquinhoDatabase(NativeDatabase.memory());
    repo = LocalPeriodRepository(
      db,
      'u1',
      LocalChangeRecorder(
        db,
        clock: () => DateTime.utc(2026, 11, 10),
        newId: () => 'a${++ids}',
      ),
      refresh: () async {
        refreshed++;
        await onRefresh?.call();
      },
      clock: () => DateTime.utc(2026, 11, 10),
    );
    service = PeriodService(repo, newId: () => 'i${++ids}');
  });
  tearDown(() => db.close());

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  test('conta nova pergunta; primeiro período contém hoje', () async {
    expect(await service.needsSetup(), isTrue);
    expect(refreshed, 1);
    final range = await service.setup(
      PeriodConfig.customCycle(20),
      d(2026, 11, 10),
    );
    expect(range, PeriodRange(d(2026, 10, 20), d(2026, 11, 20)));

    expect(await service.needsSetup(), isFalse);
    expect(await count('period_configurations'), 1);
    expect(await count('accounting_periods'), 1);
    expect(await count('sync_outbox'), 1);
    // Auditoria do período e da configuração, na mesma operação.
    expect(await count('audit_events'), 2);
    final configs = await repo.configurations();
    expect(configs.single.effectiveFrom, d(2026, 10, 20));
  });

  test('conta já configurada (baixada do servidor) não pergunta', () async {
    onRefresh = () => db.customStatement(
      'INSERT INTO period_configurations (id, owner_id, version, created_at, '
      "updated_at, mode, custom_start_day, effective_from) VALUES "
      "('c1', 'u1', 1, 'x', 'x', 'calendar_month', NULL, '2026-11-01')",
    );
    expect(await service.needsSetup(), isFalse);
  });

  test(
    'ensureUpTo cria os períodos faltantes, em ordem e dependentes',
    () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2026, 8, 15));
      final created = await service.ensureUpTo(d(2026, 11, 10));
      expect(created.map((r) => r.start.toIso()), [
        '2026-09-01',
        '2026-10-01',
        '2026-11-01',
      ]);
      expect((await repo.periods()).length, 4);
      // Segunda chamada no mesmo dia não cria nada.
      expect(await service.ensureUpTo(d(2026, 11, 30)), isEmpty);

      final ops = await SyncService(db, FakeGateway()).operations('u1');
      expect(ops.length, 4);
      expect(ops[1].dependsOn, [ops[0].entityId]);
      expect(ops[3].dependsOn, [ops[2].entityId]);
    },
  );

  test('períodos criados no celular sobem pela fila sem recusa', () async {
    await service.setup(PeriodConfig.calendarMonth(), d(2026, 9, 15));
    await service.ensureUpTo(d(2026, 11, 10));
    final gateway = FakeGateway();
    expect(await SyncService(db, gateway).syncOnce('u1'), 3);
    expect(gateway.calls.map((c) => c.$2['p_start_date']), [
      '2026-09-01',
      '2026-10-01',
      '2026-11-01',
    ]);
    expect(gateway.calls.first.$2['p_mode'], 'calendar_month');
    expect(gateway.calls.first.$2['p_custom_start_day'], isNull);
  });

  group('períodos anteriores e futuros sob demanda (Entrega 34B)', () {
    test('data coberta não gera plano', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
      expect(await service.planFor(d(2026, 11, 30)), isNull);
      expect(await service.periodFor(d(2026, 11, 30)), isNotNull);
      expect(await service.periodFor(d(2026, 10, 31)), isNull);
    });

    test(
      'para trás: pergunta, cria do mais próximo ao mais distante',
      () async {
        await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
        final plan = (await service.planFor(d(2026, 7, 15)))!;
        expect(plan.earlier, isTrue);
        expect(plan.count, 4);
        expect(
          plan.question,
          'Criar os 4 períodos de julho de 2026 a outubro de 2026?',
        );
        // Nada foi criado só de perguntar.
        expect((await repo.periods()).length, 1);

        final created = await service.createCovering(d(2026, 7, 15));
        expect(created.map((r) => r.start.toIso()), [
          '2026-10-01',
          '2026-09-01',
          '2026-08-01',
          '2026-07-01',
        ]);
        final periods = await repo.periods();
        expect(periods.length, 5);
        for (var i = 1; i < periods.length; i++) {
          expect(periods[i].range.start, periods[i - 1].range.end);
        }
        // A configuração é a do primeiro período e continua uma só.
        expect(await count('period_configurations'), 1);
        expect(periods.map((p) => p.configurationId).toSet().length, 1);

        final ops = await SyncService(db, FakeGateway()).operations('u1');
        expect(ops.map((o) => o.rpc), [
          'create_accounting_period',
          'create_earlier_accounting_period',
          'create_earlier_accounting_period',
          'create_earlier_accounting_period',
          'create_earlier_accounting_period',
        ]);
        expect(ops[1].dependsOn, [ops[0].entityId]);
        expect(ops[2].dependsOn, [ops[1].entityId]);
        expect(ops[1].params.keys.toSet(), {'p_period_id', 'p_start_date'});
      },
    );

    test('para trás sobe pela fila na ordem certa', () async {
      await service.setup(PeriodConfig.customCycle(31), d(2026, 3, 31));
      await service.createCovering(d(2025, 12, 31));
      final gateway = FakeGateway();
      expect(await SyncService(db, gateway).syncOnce('u1'), 4);
      expect(gateway.calls.map((c) => c.$2['p_start_date']), [
        '2026-03-31',
        '2026-02-28',
        '2026-01-31',
        '2025-12-31',
      ]);
    });

    test('para frente: futuro usa a mesma criação de sempre', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
      final plan = (await service.planFor(d(2027, 1, 20)))!;
      expect(plan.earlier, isFalse);
      expect(
        plan.question,
        'Criar os 2 períodos de dezembro de 2026 a janeiro de 2027?',
      );
      await service.createCovering(d(2027, 1, 20));
      expect(
        (await service.periodFor(d(2027, 1, 20)))!.range.start,
        d(2027, 1, 1),
      );
    });

    test('um período só pergunta com as datas', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
      final plan = (await service.planFor(d(2026, 10, 3)))!;
      expect(plan.question, 'Criar o período de 01/10/2026 a 31/10/2026?');
    });

    test('data muito distante é recusada sem criar nada em massa', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
      await expectLater(
        service.planFor(d(1900, 1, 1)),
        throwsA(isA<PeriodTooFarException>()),
      );
      expect((await repo.periods()).length, 1);
    });
  });

  group('Web (repositório remoto)', () {
    test('cria direto no servidor e lê o que existe', () async {
      final reader = FakeReader();
      final gateway = FakeGateway();
      final remote = RemotePeriodRepository(reader, gateway, newId: () => 'op');
      final web = PeriodService(remote, newId: () => 'i${++ids}');

      expect(await web.needsSetup(), isTrue);
      await web.setup(PeriodConfig.customCycle(31), d(2026, 2, 27));
      expect(gateway.calls.single.$1, 'create_accounting_period');
      expect(gateway.calls.single.$2['p_start_date'], '2026-01-31');
      expect(gateway.calls.single.$2['p_custom_start_day'], 31);

      reader.tables['period_configurations'] = [
        {
          'id': 'c1',
          'mode': 'custom_cycle',
          'custom_start_day': 31,
          'effective_from': '2026-01-31',
          'version': 1,
        },
      ];
      reader.tables['accounting_periods'] = [
        {
          'id': 'p1',
          'configuration_id': 'c1',
          'start_date': '2026-01-31',
          'end_date': '2026-02-28',
          'version': 1,
        },
      ];
      expect(await web.needsSetup(), isFalse);
      final created = await web.ensureUpTo(d(2026, 3, 5));
      expect(created.map((r) => r.toString()), ['[2026-02-28, 2026-03-31)']);
    });

    test('conflito do servidor vira mensagem, sem criar duplicado', () async {
      final gateway = FakeGateway()..status = 'conflict';
      final web = PeriodService(RemotePeriodRepository(FakeReader(), gateway));
      await expectLater(
        web.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10)),
        throwsA(isA<Exception>()),
      );
    });
  });
}
