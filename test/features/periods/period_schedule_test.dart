@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_models.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/periods/remote_period_repository.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);

class _Gateway implements SyncRemoteGateway {
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
      'configuration': {'id': params['p_configuration_id'], 'version': 1},
    };
  }
}

class _Reader implements RemoteTableReader {
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
  late PeriodService service;
  late LocalPeriodRepository repo;
  var ids = 0;

  setUp(() {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    repo = LocalPeriodRepository(
      db,
      'u1',
      LocalChangeRecorder(
        db,
        clock: () => DateTime.utc(2026, 11, 10),
        newId: () => 'a${++ids}',
      ),
      clock: () => DateTime.utc(2026, 11, 10),
    );
    service = PeriodService(repo, newId: () => 'i${++ids}');
  });
  tearDown(() => db.close());

  Future<List<String>> ranges() async => [
    for (final p in await repo.periods()) p.range.toString(),
  ];

  Future<int> configCount() async => (await repo.configurations()).length;

  group('mudança de configuração (RN002, D2, D3)', () {
    test(
      'mês-calendário → ciclo dia 20: vale a partir do próximo período',
      () async {
        await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
        final starts = await service.scheduleChange(
          PeriodConfig.customCycle(20),
          d(2026, 11, 10),
        );
        expect(starts, d(2026, 12, 1));
        // Nenhum período novo nem alterado.
        expect(await ranges(), ['[2026-11-01, 2026-12-01)']);
        final change = await service.scheduledChange();
        expect(change!.config, PeriodConfig.customCycle(20));
        expect(change.startsOn, d(2026, 12, 1));
        expect(
          await service.currentConfig(d(2026, 11, 10)),
          PeriodConfig.calendarMonth(),
        );

        await service.ensureUpTo(d(2027, 1, 25));
        expect(await ranges(), [
          '[2026-11-01, 2026-12-01)',
          '[2026-12-01, 2026-12-20)', // transição
          '[2026-12-20, 2027-01-20)',
          '[2027-01-20, 2027-02-20)',
        ]);
        // Depois de usada, não aparece mais como agendada.
        expect(await service.scheduledChange(), isNull);
      },
    );

    test('ciclo dia 20 → mês-calendário', () async {
      await service.setup(PeriodConfig.customCycle(20), d(2026, 11, 10));
      final starts = await service.scheduleChange(
        PeriodConfig.calendarMonth(),
        d(2026, 11, 10),
      );
      expect(starts, d(2026, 11, 20));
      await service.ensureUpTo(d(2027, 1, 5));
      expect(await ranges(), [
        '[2026-10-20, 2026-11-20)',
        '[2026-11-20, 2026-12-01)', // transição
        '[2026-12-01, 2027-01-01)',
        '[2027-01-01, 2027-02-01)',
      ]);
    });

    test('ciclo dia 31 entrando em fevereiro comum', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2027, 1, 15));
      await service.scheduleChange(
        PeriodConfig.customCycle(31),
        d(2027, 1, 15),
      );
      await service.ensureUpTo(d(2027, 4, 5));
      expect(await ranges(), [
        '[2027-01-01, 2027-02-01)',
        '[2027-02-01, 2027-02-28)',
        '[2027-02-28, 2027-03-31)',
        '[2027-03-31, 2027-04-30)',
      ]);
    });

    test('ciclo dia 31 entrando em fevereiro bissexto', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2028, 1, 15));
      await service.scheduleChange(
        PeriodConfig.customCycle(31),
        d(2028, 1, 15),
      );
      await service.ensureUpTo(d(2028, 3, 5));
      expect(await ranges(), [
        '[2028-01-01, 2028-02-01)',
        '[2028-02-01, 2028-02-29)',
        '[2028-02-29, 2028-03-31)',
      ]);
    });

    test('dias 29 e 30 em fevereiro usam o último dia disponível', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2027, 1, 15));
      await service.scheduleChange(
        PeriodConfig.customCycle(30),
        d(2027, 1, 15),
      );
      await service.ensureUpTo(d(2027, 3, 10));
      expect(await ranges(), [
        '[2027-01-01, 2027-02-01)',
        '[2027-02-01, 2027-02-28)',
        '[2027-02-28, 2027-03-30)',
      ]);
    });

    test(
      'mudança feita no último dia do período vale a partir do seguinte',
      () async {
        await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
        final starts = await service.scheduleChange(
          PeriodConfig.customCycle(15),
          d(2026, 11, 30),
        );
        expect(starts, d(2026, 12, 1));
        expect(await ranges(), ['[2026-11-01, 2026-12-01)']);
      },
    );

    test(
      'abrir o app depois de dias parados: cria os períodos até hoje antes de agendar',
      () async {
        await service.setup(PeriodConfig.calendarMonth(), d(2026, 9, 10));
        // Hoje já está em novembro: setembro, outubro e novembro precisam existir.
        final starts = await service.scheduleChange(
          PeriodConfig.customCycle(20),
          d(2026, 11, 10),
        );
        expect(starts, d(2026, 12, 1));
        expect(await ranges(), [
          '[2026-09-01, 2026-10-01)',
          '[2026-10-01, 2026-11-01)',
          '[2026-11-01, 2026-12-01)',
        ]);
      },
    );

    test('reagendar troca a anterior sem criar outra configuração', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
      await service.scheduleChange(
        PeriodConfig.customCycle(20),
        d(2026, 11, 10),
      );
      await service.scheduleChange(
        PeriodConfig.customCycle(25),
        d(2026, 11, 10),
      );
      expect(await configCount(), 2);
      expect(
        (await service.scheduledChange())!.config,
        PeriodConfig.customCycle(25),
      );
      final rows = await db
          .customSelect(
            "SELECT payload_json, expected_version FROM sync_outbox "
            "WHERE entity_type = 'period_configuration' "
            'ORDER BY rowid',
          )
          .get();
      // Agendamento (cria) e troca (altera, esperando a versão 1).
      expect(rows.length, 2);
      expect(rows[0].read<int>('expected_version'), 0);
      expect(rows[1].read<int>('expected_version'), 1);
      await service.ensureUpTo(d(2026, 12, 30));
      expect(await ranges(), [
        '[2026-11-01, 2026-12-01)',
        '[2026-12-01, 2026-12-25)',
        '[2026-12-25, 2027-01-25)',
      ]);
    });

    test('escolher a configuração atual cancela a mudança', () async {
      await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
      await service.scheduleChange(
        PeriodConfig.customCycle(20),
        d(2026, 11, 10),
      );
      final starts = await service.scheduleChange(
        PeriodConfig.calendarMonth(),
        d(2026, 11, 10),
      );
      expect(starts, isNull);
      expect(await service.scheduledChange(), isNull);
      await service.ensureUpTo(d(2027, 1, 5));
      // Os períodos seguintes continuam mês-calendário.
      expect(await ranges(), [
        '[2026-11-01, 2026-12-01)',
        '[2026-12-01, 2027-01-01)',
        '[2027-01-01, 2027-02-01)',
      ]);
    });

    test('cancelar sem mudança agendada não grava nada', () async {
      await service.setup(PeriodConfig.customCycle(20), d(2026, 11, 10));
      final before = await db
          .customSelect('SELECT COUNT(*) AS n FROM sync_outbox')
          .getSingle();
      final starts = await service.scheduleChange(
        PeriodConfig.customCycle(20),
        d(2026, 11, 10),
      );
      expect(starts, isNull);
      final after = await db
          .customSelect('SELECT COUNT(*) AS n FROM sync_outbox')
          .getSingle();
      expect(after.read<int>('n'), before.read<int>('n'));
      expect(await configCount(), 1);
    });

    test(
      'envio: período, agendamento e novo período seguem a ordem e não duplicam',
      () async {
        await service.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
        await service.scheduleChange(
          PeriodConfig.customCycle(20),
          d(2026, 11, 10),
        );
        await service.ensureUpTo(d(2026, 12, 5));
        final gateway = _Gateway();
        expect(await SyncService(db, gateway).syncOnce('u1'), 3);
        expect(gateway.calls.map((c) => c.$1), [
          'create_accounting_period',
          'schedule_period_configuration',
          'create_accounting_period',
        ]);
        final schedule = gateway.calls[1].$2;
        expect(schedule['p_action'], 'create');
        expect(schedule['p_effective_from'], '2026-12-01');
        expect(schedule['p_mode'], 'custom_cycle');
        expect(schedule['p_custom_start_day'], 20);
        expect(schedule['p_expected_version'], 0);
        // Segunda rodada: fila vazia, nada é reenviado.
        expect(await SyncService(db, gateway).syncOnce('u1'), 0);
        expect(gateway.calls.length, 3);
      },
    );
  });

  group('Web (repositório remoto)', () {
    test('agenda direto no servidor com a data certa', () async {
      final reader = _Reader()
        ..tables['period_configurations'] = [
          {
            'id': 'c1',
            'mode': 'calendar_month',
            'custom_start_day': null,
            'effective_from': '2026-11-01',
            'version': 1,
          },
        ]
        ..tables['accounting_periods'] = [
          {
            'id': 'p1',
            'configuration_id': 'c1',
            'start_date': '2026-11-01',
            'end_date': '2026-12-01',
            'version': 1,
          },
        ];
      final gateway = _Gateway();
      final web = PeriodService(
        RemotePeriodRepository(reader, gateway, newId: () => 'op'),
        newId: () => 'novo',
      );
      final starts = await web.scheduleChange(
        PeriodConfig.customCycle(20),
        d(2026, 11, 10),
      );
      expect(starts, d(2026, 12, 1));
      expect(gateway.calls.single.$1, 'schedule_period_configuration');
      expect(gateway.calls.single.$2['p_effective_from'], '2026-12-01');
      expect(gateway.calls.single.$2['p_configuration_id'], 'novo');
    });

    test('conflito do servidor vira mensagem', () async {
      final reader = _Reader()
        ..tables['period_configurations'] = [
          {
            'id': 'c1',
            'mode': 'calendar_month',
            'custom_start_day': null,
            'effective_from': '2026-11-01',
            'version': 1,
          },
        ]
        ..tables['accounting_periods'] = [
          {
            'id': 'p1',
            'configuration_id': 'c1',
            'start_date': '2026-11-01',
            'end_date': '2026-12-01',
            'version': 1,
          },
        ];
      final gateway = _Gateway()..status = 'conflict';
      final web = PeriodService(RemotePeriodRepository(reader, gateway));
      await expectLater(
        web.scheduleChange(PeriodConfig.customCycle(20), d(2026, 11, 10)),
        throwsA(isA<PeriodCreationException>()),
      );
    });
  });
}
