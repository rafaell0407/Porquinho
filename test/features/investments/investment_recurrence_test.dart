@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/recurrence_schedule.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/investments/investment_models.dart';
import 'package:porquinho/features/investments/investment_recurrence_service.dart';
import 'package:porquinho/features/investments/investment_service.dart';
import 'package:porquinho/features/investments/local_investment_recurrence_repository.dart';
import 'package:porquinho/features/investments/local_investment_repository.dart';
import 'package:porquinho/features/investments/remote_investment_recurrence_repository.dart';
import 'package:porquinho/features/investments/remote_investment_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/recurrence/local_recurrence_repository.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

final today = d(2026, 11, 10);

class Device {
  Device(String prefix) : db = PorquinhoDatabase(NativeDatabase.memory()) {
    DateTime clock() => DateTime.utc(2026, 11, 10);
    recorder = LocalChangeRecorder(
      db,
      clock: clock,
      newId: () => '$prefix-a${++ids}',
    );
    periods = PeriodService(
      LocalPeriodRepository(db, 'u1', recorder, clock: clock),
    );
    investments = LocalInvestmentRepository(db, 'u1', recorder, clock: clock);
    service = InvestmentService(investments, newId: () => 'tpl-${++templates}');
    templatesRepo = LocalInvestmentRecurrenceRepository(
      db,
      'u1',
      recorder,
      clock: clock,
    );
    recurrence = InvestmentRecurrenceService(templatesRepo);
    generator = LocalRecurrenceRepository(db, 'u1', null, clock: clock);
    totals = LocalTotalsRepository(db, 'u1');
  }

  final PorquinhoDatabase db;
  var ids = 0;
  var templates = 0;
  late final LocalChangeRecorder recorder;
  late final PeriodService periods;
  late final LocalInvestmentRepository investments;
  late final InvestmentService service;
  late final LocalInvestmentRecurrenceRepository templatesRepo;
  late final InvestmentRecurrenceService recurrence;
  late final LocalRecurrenceRepository generator;
  late final LocalTotalsRepository totals;

  Future<void> setUp() async {
    await periods.setup(PeriodConfig.calendarMonth());
  }

  Future<BigInt> surplus(CalendarDate date) async =>
      (await totals.totalsFor((await periods.periodFor(date)))).surplus;

  Future<List<InvestmentRecord>> all() async {
    final result = <InvestmentRecord>[];
    for (var m = 8; m <= 11; m++) {
      final p = await periods.periodFor(d(2026, m, 5));
      result.addAll(await investments.investmentsInPeriod(p));
    }
    return result..sort((a, b) => a.date.compareTo(b.date));
  }
}

void main() {
  late Device a;

  setUp(() async {
    a = Device('a');
    await a.setUp();
  });
  tearDown(() => a.db.close());

  InvestmentDraft draft(int cents, CalendarDate date) =>
      InvestmentDraft(amount: c(cents), date: date);

  group('mensal (D7)', () {
    test(
      'o lançamento é a primeira ocorrência e as atrasadas são geradas',
      () async {
        final id = await a.service.create(
          draft(5000, d(2026, 8, 5)),
          repeat: RecurrenceFrequency.monthly,
        );
        final first = (await a.investments.investment(id))!;
        expect(first.templateId, 'tpl-1');
        expect(first.scheduledFor, d(2026, 8, 5));
        expect(id, RecurrenceCalendar.occurrenceId('tpl-1', d(2026, 8, 5)));

        final created = await a.generator.generateDue(today);
        expect(created, 3, reason: 'set, out e nov (ago já existe)');
        final list = await a.all();
        expect(list.map((i) => i.date), [
          d(2026, 8, 5),
          d(2026, 9, 5),
          d(2026, 10, 5),
          d(2026, 11, 5),
        ]);
        for (final i in list) {
          expect(i.amount, c(5000));
          expect(
            i.id,
            RecurrenceCalendar.occurrenceId('tpl-1', i.scheduledFor!),
          );
        }
        // Entra na sobra do período da data programada, sem confirmação (D9).
        expect(await a.surplus(d(2026, 9, 5)), c(-5000));
        expect(await a.surplus(d(2026, 11, 5)), c(-5000));
      },
    );

    test('gerar de novo não duplica; cancelada não renasce', () async {
      await a.service.create(
        draft(5000, d(2026, 8, 5)),
        repeat: RecurrenceFrequency.monthly,
      );
      await a.generator.generateDue(today);
      expect(await a.generator.generateDue(today), 0);
      final victim = (await a.all())[1];
      await a.service.cancel(victim);
      expect(await a.generator.generateDue(today), 0);
      expect((await a.all()).length, 4);
      expect(await a.surplus(victim.date), BigInt.zero);
    });

    test('dia 31 em mês curto usa o último dia', () async {
      await a.service.create(
        draft(100, d(2026, 8, 31)),
        repeat: RecurrenceFrequency.monthly,
      );
      await a.generator.generateDue(today);
      final dates = (await a.all()).map((i) => i.date).toList();
      expect(dates, contains(d(2026, 9, 30)));
      expect(dates, contains(d(2026, 10, 31)));
    });

    test('dois aparelhos offline geram as mesmas ocorrências (mesmo id)', () async {
      final b = Device('b');
      await b.setUp();
      addTearDown(b.db.close);
      // Mesmo modelo nos dois (como após o download).
      for (final dev in [a, b]) {
        await dev.db.customStatement(
          'INSERT INTO investment_recurrence_templates (id, owner_id, version, '
          "created_at, updated_at, frequency, starts_on, monthly_reference_day, "
          "default_amount_centavos, is_active) VALUES ('t9', 'u1', 1, 'x', 'x', "
          "'monthly', '2026-09-03', 3, '2500', 1)",
        );
        await dev.generator.generateDue(today);
      }
      final idsA = (await a.all()).map((i) => i.id).toSet();
      final idsB = (await b.all()).map((i) => i.id).toSet();
      expect(idsA, isNotEmpty);
      expect(idsA, idsB);
      expect(
        idsA,
        contains(RecurrenceCalendar.occurrenceId('t9', d(2026, 10, 3))),
      );
    });
  });

  group('só "Todo mês" (13/11/2026)', () {
    test('"Todo período" é recusado e nada é gravado', () async {
      await expectLater(
        a.service.create(
          draft(7000, d(2026, 9, 17)),
          repeat: RecurrenceFrequency.byPeriod,
        ),
        throwsA(isA<ChangeRejectedException>()),
      );
      expect(await a.all(), isEmpty);
    });

    test('dia 31: em mês curto, último dia útil; uma por mês', () async {
      await a.service.create(
        draft(7000, d(2026, 8, 31)),
        repeat: RecurrenceFrequency.monthly,
      );
      await a.generator.generateDue(today);
      // 31/08 (seg), 30/09 (qua), 31/10 (sáb, existe: mantém).
      expect((await a.all()).map((i) => i.date).toList()..sort(), [
        d(2026, 8, 31),
        d(2026, 9, 30),
        d(2026, 10, 31),
      ]);
      expect(await a.generator.generateDue(today), 0);
    });
  });

  group('valor por ocorrência e do modelo (D8)', () {
    test(
      'mudar o valor de um mês não altera outros meses nem o modelo',
      () async {
        await a.service.create(
          draft(5000, d(2026, 9, 5)),
          repeat: RecurrenceFrequency.monthly,
        );
        await a.generator.generateDue(today);
        final list = await a.all();
        final target = list[1];
        await a.service.update(target, draft(8000, target.date));
        final after = await a.all();
        expect(after.map((i) => i.amount), [c(5000), c(8000), c(5000)]);
        expect(
          (await a.templatesRepo.template('tpl-1'))!.defaultAmount,
          c(5000),
        );
        // Gerar de novo não desfaz a edição.
        await a.generator.generateDue(today);
        expect((await a.all())[1].amount, c(8000));
        expect(await a.surplus(target.date), c(-8000));
      },
    );

    test('mudar o valor das próximas não reescreve as já geradas', () async {
      await a.service.create(
        draft(5000, d(2026, 9, 5)),
        repeat: RecurrenceFrequency.monthly,
      );
      await a.generator.generateDue(today);
      final template = (await a.templatesRepo.template('tpl-1'))!;
      await a.recurrence.edit(
        template,
        InvestmentTemplateEdit(
          frequency: RecurrenceFrequency.monthly,
          monthlyReferenceDay: 5,
          defaultAmount: BigInt.zero,
        ),
        today: today,
      );
      // zero é aceito (RN045); as geradas continuam com o valor antigo.
      expect((await a.all()).map((i) => i.amount).toSet(), {c(5000)});
      final updated = (await a.templatesRepo.template('tpl-1'))!;
      expect(updated.defaultAmount, BigInt.zero);
      expect(updated.version, 2);
      final ops = (await SyncService(
        a.db,
        _Gateway(),
      ).operations('u1')).where((o) => o.entityId == 'tpl-1').toList();
      expect(ops.single.rpc, 'apply_investment_recurrence_template_change');
      expect(ops.single.params['p_payload']['default_amount_centavos'], '0');
    });

    test(
      'mudar o dia vale só para as próximas e nunca repete o mês gerado',
      () async {
        await a.service.create(
          draft(5000, d(2026, 9, 5)),
          repeat: RecurrenceFrequency.monthly,
        );
        await a.generator.generateDue(today);
        final template = (await a.templatesRepo.template('tpl-1'))!;
        await a.recurrence.edit(
          template,
          InvestmentTemplateEdit(
            frequency: RecurrenceFrequency.monthly,
            monthlyReferenceDay: 20,
            defaultAmount: c(5000),
          ),
          today: today,
        );
        final updated = (await a.templatesRepo.template('tpl-1'))!;
        expect(updated.startsOn, d(2026, 12, 1));
        expect(await a.generator.generateDue(today), 0);
        expect((await a.all()).length, 3);
      },
    );

    test('valor negativo e modelo parado são recusados', () async {
      await a.service.create(
        draft(5000, d(2026, 9, 5)),
        repeat: RecurrenceFrequency.monthly,
      );
      final template = (await a.templatesRepo.template('tpl-1'))!;
      await expectLater(
        a.recurrence.edit(
          template,
          InvestmentTemplateEdit(
            frequency: RecurrenceFrequency.monthly,
            monthlyReferenceDay: 5,
            defaultAmount: c(-1),
          ),
          today: today,
        ),
        throwsA(isA<ChangeRejectedException>()),
      );
      await a.recurrence.stop(template);
      await expectLater(
        a.recurrence.stop((await a.templatesRepo.template('tpl-1'))!),
        throwsA(isA<ChangeRejectedException>()),
      );
    });
  });

  group('parar e converter', () {
    test('parar de repetir mantém as geradas e não gera mais', () async {
      await a.service.create(
        draft(5000, d(2026, 9, 5)),
        repeat: RecurrenceFrequency.monthly,
      );
      await a.generator.generateDue(today);
      await a.recurrence.stop((await a.templatesRepo.template('tpl-1'))!);
      expect((await a.templatesRepo.template('tpl-1'))!.isActive, isFalse);
      expect((await a.all()).length, 3);
      expect(await a.generator.generateDue(d(2026, 12, 20)), 0);
      expect((await a.all()).length, 3);
    });

    test('investimento avulso vira a primeira ocorrência', () async {
      final id = await a.service.create(draft(4000, d(2026, 9, 12)));
      final current = (await a.investments.investment(id))!;
      await a.service.update(
        current,
        draft(4500, d(2026, 9, 12)),
        repeat: RecurrenceFrequency.monthly,
      );
      final converted = (await a.investments.investment(id))!;
      expect(converted.templateId, 'tpl-2');
      expect(converted.amount, c(4500));
      expect(converted.version, 3, reason: 'edição + conversão');
      expect((await a.templatesRepo.template('tpl-2'))!.defaultAmount, c(4500));
      await a.generator.generateDue(today);
      expect(
        (await a.all()).length,
        2,
        reason: '12/set e 12/out (12/nov ainda não)',
      );
      await expectLater(
        a.service.update(
          converted,
          draft(1, d(2026, 9, 12)),
          repeat: RecurrenceFrequency.monthly,
        ),
        throwsA(isA<ChangeRejectedException>()),
      );
    });

    test('fila: parâmetros da criação da recorrência e dependências', () async {
      final id = await a.service.create(
        draft(5000, d(2026, 9, 5)),
        repeat: RecurrenceFrequency.monthly,
      );
      final ops = await SyncService(a.db, _Gateway()).operations('u1');
      final op = ops.singleWhere((o) => o.entityId == id);
      expect(op.rpc, 'create_investment_recurrence_from_entry');
      expect(op.isCreate, isTrue);
      expect(op.createdIds, [id, 'tpl-1']);
      expect(op.params['p_template_id'], 'tpl-1');
      expect(op.params['p_expected_entry_version'], 0);
      expect(op.params['p_template'], {
        'frequency': 'monthly',
        'starts_on': '2026-09-05',
        'monthly_reference_day': 5,
        'default_amount_centavos': '5000',
      });
      expect(op.params['p_entry'], {
        'date': '2026-09-05',
        'amount_centavos': '5000',
      });
      final audits = await a.db
          .customSelect(
            "SELECT entity_type FROM audit_events WHERE entity_id IN ('$id', 'tpl-1')",
          )
          .get();
      expect(audits.map((r) => r.read<String>('entity_type')).toSet(), {
        'investment_allocation',
        'investment_recurrence_template',
      });
    });

    test('qualquer data é aceita (RN002): recorrência criada direto', () async {
      await a.service.create(
        draft(100, d(2026, 5, 5)),
        repeat: RecurrenceFrequency.monthly,
      );
      expect((await a.templatesRepo.templates()), hasLength(1));
      await a.generator.generateDue(today);
      // 05/05 (a própria) até 05/11: sete meses, uma por mês.
      expect(
        (await a.db.customSelect('SELECT * FROM investment_allocations').get())
            .length,
        7,
      );
    });
  });

  group('Web (servidor)', () {
    test(
      'criação da recorrência e edição enviam as RPCs do servidor',
      () async {
        final gateway = _Gateway();
        final repo = RemoteInvestmentRepository(
          _Reader(const []),
          gateway,
          newId: () => 'op',
        );
        await repo.apply([
          CreateInvestmentRecurrence(
            templateId: 't1',
            entryId: 'e1',
            draft: draft(5000, d(2026, 9, 5)),
            frequency: RecurrenceFrequency.byPeriod,
            scheduledFor: d(2026, 9, 1),
          ),
        ]);
        final (rpc, params) = gateway.calls.single;
        expect(rpc, 'create_investment_recurrence_from_entry');
        expect(params['p_operation_id'], 'op');
        expect(params['p_expected_entry_version'], 0);
        expect((params['p_template'] as Map)['monthly_reference_day'], isNull);

        final templates = RemoteInvestmentRecurrenceRepository(
          _Reader([
            {
              'id': 't1',
              'frequency': 'by_period',
              'starts_on': '2026-09-01',
              'monthly_reference_day': null,
              'default_amount_centavos': 5000,
              'is_active': true,
              'version': 1,
            },
          ]),
          gateway,
          newId: () => 'op2',
        );
        final t = (await templates.template('t1'))!;
        expect(t.defaultAmount, c(5000));
        expect(t.scheduleLabel, 'Todo período');
        await templates.stop(t);
        expect(
          gateway.calls.last.$1,
          'apply_investment_recurrence_template_change',
        );
        expect(gateway.calls.last.$2['p_action'], 'deactivate');
      },
    );
  });
}

class _Gateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc, params));
    return {'status': 'applied'};
  }
}

class _Reader implements RemoteTableReader {
  _Reader(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    List<RemoteFilter> filters = const [],
    String? orderBy,
  }) async => rows;
}
