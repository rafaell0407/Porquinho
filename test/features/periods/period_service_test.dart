@TestOn('vm')
library;

import 'dart:convert';

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

/// Configuração única de período e períodos calculados (reestruturação P6;
/// RN001, RN002, RN004, RN036).
CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
PeriodRange r(CalendarDate a, CalendarDate b) => PeriodRange(a, b);

class FakeGateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];
  String status = 'applied';
  Map<String, dynamic> span = {'oldest': null, 'newest': null};

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc, params));
    if (rpc == 'get_entry_date_span') return span;
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
  late LocalPeriodRepository repo;
  late PeriodService service;
  var ids = 0;
  var refreshed = 0;
  Future<void> Function()? onRefresh;
  final today = d(2026, 11, 10);

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
    service = PeriodService(repo);
  });
  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> rows(String sql) async =>
      (await db.customSelect(sql).get()).map((r) => r.data).toList();

  group('primeiro acesso', () {
    test('conta nova pergunta; depois grava só a configuração', () async {
      expect(await service.needsSetup(), isTrue);
      expect(refreshed, 1, reason: 'antes de perguntar, busca no servidor');
      await service.setup(PeriodConfig.customCycle(20));
      expect(await service.needsSetup(), isFalse);
      expect(await service.currentConfig(), PeriodConfig.customCycle(20));
      // Nenhum período é gravado: só a configuração (versão 1, id = dono).
      final settings = await rows('SELECT * FROM period_settings');
      expect(settings.single['id'], 'u1');
      expect(settings.single['version'], 1);
    });

    test('vai para a fila com auditoria, na mesma gravação', () async {
      await service.setup(PeriodConfig.calendarMonth());
      final outbox = await rows('SELECT * FROM sync_outbox');
      expect(outbox.single['entity_type'], 'period_settings');
      expect(outbox.single['entity_id'], 'u1');
      expect(outbox.single['expected_version'], 0);
      final payload = jsonDecode(outbox.single['payload_json']! as String);
      expect(payload['rpc'], 'set_period_settings');
      expect(payload['params'], {
        'p_expected_version': 0,
        'p_mode': 'calendar_month',
        'p_custom_start_day': null,
      });
      final audit = await rows('SELECT * FROM audit_events');
      expect(audit.single['entity_type'], 'period_settings');
      expect(audit.single['operation'], 'create');
    });

    test('segundo aparelho: a configuração baixada evita a pergunta', () async {
      onRefresh = () => db.customStatement(
        "INSERT INTO period_settings (id, owner_id, version, created_at, "
        "updated_at, mode, custom_start_day) VALUES "
        "('u1', 'u1', 3, 'x', 'x', 'custom_cycle', 5)",
      );
      expect(await service.needsSetup(), isFalse);
      expect(await service.currentConfig(), PeriodConfig.customCycle(5));
    });

    test('configurar duas vezes no mesmo aparelho é recusado', () async {
      await service.setup(PeriodConfig.calendarMonth());
      await expectLater(
        service.setup(PeriodConfig.customCycle(5)),
        throwsA(isA<PeriodSettingsException>()),
      );
    });
  });

  group('troca a qualquer momento (RN002)', () {
    test('vale na hora para todos os períodos, passados e futuros', () async {
      await service.setup(PeriodConfig.calendarMonth());
      expect(
        await service.periodFor(d(2025, 3, 15)),
        r(d(2025, 3, 1), d(2025, 4, 1)),
      );
      await service.change(PeriodConfig.customCycle(20));
      expect(await service.currentConfig(), PeriodConfig.customCycle(20));
      // Mesmo um período de anos atrás passa a usar a nova configuração.
      expect(
        await service.periodFor(d(2025, 3, 15)),
        r(d(2025, 2, 20), d(2025, 3, 20)),
      );
      expect(
        await service.periodFor(d(2030, 1, 25)),
        r(d(2030, 1, 20), d(2030, 2, 20)),
      );
    });

    test('versão: cada troca espera a anterior (fila na ordem)', () async {
      await service.setup(PeriodConfig.calendarMonth());
      await service.change(PeriodConfig.customCycle(20));
      await service.change(PeriodConfig.customCycle(31));
      final outbox = await rows(
        'SELECT expected_version FROM sync_outbox ORDER BY rowid',
      );
      expect(outbox.map((o) => o['expected_version']), [0, 1, 2]);
      final settings = await rows('SELECT * FROM period_settings');
      expect(settings.single['version'], 3);
      expect(settings.single['custom_start_day'], 31);
      final audit = await rows(
        "SELECT operation FROM audit_events WHERE entity_type = "
        "'period_settings' ORDER BY rowid",
      );
      expect(audit.map((a) => a['operation']), ['create', 'update', 'update']);
    });

    test('escolher a configuração atual não grava nada', () async {
      await service.setup(PeriodConfig.customCycle(10));
      await service.change(PeriodConfig.customCycle(10));
      expect(await rows('SELECT * FROM sync_outbox'), hasLength(1));
    });

    test('trocar antes do primeiro acesso é recusado', () async {
      await expectLater(
        service.change(PeriodConfig.calendarMonth()),
        throwsA(isA<PeriodSettingsException>()),
      );
    });
  });

  group('navegação (RN002)', () {
    Future<void> insertDates(List<String> incomeDates) async {
      var i = 0;
      for (final date in incomeDates) {
        await db.customStatement(
          "INSERT INTO income_entries (id, owner_id, version, created_at, "
          "updated_at, amount_centavos, status, received_on) VALUES "
          "(?, 'u1', 1, 'x', 'x', '1', 'received', ?)",
          ['i${i++}', date],
        );
      }
    }

    test('sem lançamentos: só o período atual', () async {
      await service.setup(PeriodConfig.calendarMonth());
      final b = await service.bounds(today);
      expect(b.first, r(d(2026, 11, 1), d(2026, 12, 1)));
      expect(b.last, b.first);
    });

    test(
      'do lançamento mais antigo ao mais distante, sem criar nada',
      () async {
        await service.setup(PeriodConfig.calendarMonth());
        await insertDates(['2024-07-31', '2026-11-05']);
        await db.customStatement(
          "INSERT INTO expense_entries (id, owner_id, version, created_at, "
          "updated_at, amount_centavos, status, competence_on) VALUES "
          "('e1', 'u1', 1, 'x', 'x', '1', 'pending', '2027-03-01')",
        );
        final b = await service.bounds(today);
        expect(b.first, r(d(2024, 7, 1), d(2024, 8, 1)));
        expect(b.last, r(d(2027, 3, 1), d(2027, 4, 1)));
      },
    );

    test('receita pendente conta pela data programada', () async {
      await service.setup(PeriodConfig.calendarMonth());
      await db.customStatement(
        "INSERT INTO income_recurrence_templates (id, owner_id, version, "
        "created_at, updated_at, frequency, starts_on, monthly_reference_day, "
        "value_mode) VALUES ('t1', 'u1', 1, 'x', 'x', 'monthly', "
        "'2026-01-05', 5, 'variable')",
      );
      await db.customStatement(
        "INSERT INTO income_entries (id, owner_id, version, created_at, "
        "updated_at, status, recurrence_template_id, scheduled_for_date) "
        "VALUES ('i1', 'u1', 1, 'x', 'x', 'pending', 't1', '2026-01-05')",
      );
      final b = await service.bounds(today);
      expect(b.first, r(d(2026, 1, 1), d(2026, 2, 1)));
    });

    test('isolado por usuário', () async {
      await service.setup(PeriodConfig.calendarMonth());
      await db.customStatement(
        "INSERT INTO income_entries (id, owner_id, version, created_at, "
        "updated_at, amount_centavos, status, received_on) VALUES "
        "('x', 'outro', 1, 'x', 'x', '1', 'received', '2000-01-01')",
      );
      final b = await service.bounds(today);
      expect(b.first, r(d(2026, 11, 1), d(2026, 12, 1)));
    });
  });

  group('Web (repositório remoto)', () {
    test('grava e lê direto no servidor', () async {
      final reader = FakeReader();
      final gateway = FakeGateway();
      final web = PeriodService(
        RemotePeriodRepository(reader, gateway, newId: () => 'op'),
      );
      expect(await web.needsSetup(), isTrue);
      await web.setup(PeriodConfig.customCycle(31));
      expect(gateway.calls.single.$1, 'set_period_settings');
      expect(gateway.calls.single.$2, {
        'p_operation_id': 'op',
        'p_expected_version': 0,
        'p_mode': 'custom_cycle',
        'p_custom_start_day': 31,
      });

      reader.tables['period_settings'] = [
        {
          'id': 'u1',
          'mode': 'custom_cycle',
          'custom_start_day': 31,
          'version': 4,
        },
      ];
      expect(await web.needsSetup(), isFalse);
      expect(await web.currentConfig(), PeriodConfig.customCycle(31));
      await web.change(PeriodConfig.calendarMonth());
      expect(gateway.calls.last.$2['p_expected_version'], 4);

      gateway.span = {'oldest': '2025-01-31', 'newest': '2027-02-28'};
      final b = await web.bounds(today);
      expect(b.first, r(d(2025, 1, 31), d(2025, 2, 28)));
      expect(b.last, r(d(2027, 2, 28), d(2027, 3, 31)));
    });

    test('conflito do servidor vira mensagem', () async {
      final gateway = FakeGateway()..status = 'conflict';
      final web = PeriodService(RemotePeriodRepository(FakeReader(), gateway));
      await expectLater(
        web.setup(PeriodConfig.calendarMonth()),
        throwsA(isA<PeriodSettingsException>()),
      );
    });
  });
}
