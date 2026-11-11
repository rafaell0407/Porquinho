@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/recurrence_schedule.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/entries/entry_models.dart';
import 'package:porquinho/features/entries/entry_service.dart';
import 'package:porquinho/features/entries/local_entry_repository.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/recurrence/local_recurrence_repository.dart';
import 'package:porquinho/features/recurrence/recurrence_models.dart';
import 'package:porquinho/features/recurrence/recurrence_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/totals/totals_repository.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);
BigInt c(int v) => BigInt.from(v);

class RecordingGateway implements SyncRemoteGateway {
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add(rpc);
    return {'status': 'applied'};
  }
}

/// Um "aparelho": banco local, serviços e relógio fixos.
class Device {
  Device(String prefix) {
    db = PorquinhoDatabase(NativeDatabase.memory());
    DateTime clock() => DateTime.utc(2026, 11, 10);
    final recorder = LocalChangeRecorder(
      db,
      clock: clock,
      newId: () => '$prefix-a${++_ids}',
    );
    periods = PeriodService(
      LocalPeriodRepository(db, 'u1', recorder, clock: clock),
      newId: () => '$prefix-p${++_ids}',
    );
    final catRepo = LocalCategoryRepository(db, 'u1', recorder, clock: clock);
    recurrenceRepo = LocalRecurrenceRepository(
      db,
      'u1',
      recorder,
      clock: clock,
    );
    entries = LocalEntryRepository(db, 'u1', recorder, clock: clock);
    service = EntryService(
      entries,
      catRepo,
      periods,
      recurrences: recurrenceRepo,
      newId: () => '$prefix-e${++_ids}',
    );
    recurrences = RecurrenceService(recurrenceRepo, catRepo);
    totals = LocalTotalsRepository(db, 'u1');
  }

  var _ids = 0;
  late final PorquinhoDatabase db;
  late final PeriodService periods;
  late final LocalRecurrenceRepository recurrenceRepo;
  late final LocalEntryRepository entries;
  late final EntryService service;
  late final RecurrenceService recurrences;
  late final LocalTotalsRepository totals;

  Future<void> setUp() =>
      periods.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));

  Future<BigInt> surplus(CalendarDate date) async =>
      (await totals.totalsFor((await periods.periodFor(date))!.id)).surplus;

  Future<List<Map<String, Object?>>> rows(
    String table, {
    String? where,
    String order = 'scheduled_for_date',
  }) async {
    final r = await db
        .customSelect(
          'SELECT * FROM $table ${where == null ? '' : 'WHERE $where'} '
          'ORDER BY $order',
        )
        .get();
    return r.map((e) => e.data).toList();
  }

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');
}

EntryDraft expense(int? cents, CalendarDate date, {CalendarDate? dueOn}) =>
    EntryDraft(
      kind: EntryKind.expense,
      amount: cents == null ? null : c(cents),
      date: date,
      description: 'Academia',
      dueOn: dueOn,
    );

EntryDraft income(int? cents, CalendarDate date) => EntryDraft(
  kind: EntryKind.income,
  amount: cents == null ? null : c(cents),
  date: date,
  description: 'Salário',
);

const monthly = RepeatChoice(frequency: RecurrenceFrequency.monthly);
const byPeriod = RepeatChoice(frequency: RecurrenceFrequency.byPeriod);
const monthlyVariable = RepeatChoice(
  frequency: RecurrenceFrequency.monthly,
  variableValue: true,
);

void main() {
  late Device dev;
  final today = d(2026, 11, 10);

  setUp(() async {
    dev = Device('x');
    await dev.setUp();
  });
  tearDown(() => dev.db.close());

  group('Entrega 45 — Repetir no formulário', () {
    test(
      'o lançamento vira a primeira ocorrência e o modelo é criado',
      () async {
        final id = await dev.service.create(
          expense(9000, d(2026, 11, 5)),
          repeat: monthly,
        );
        final entry = (await dev.entries.entry(EntryKind.expense, id))!;
        expect(entry.isRecurring, isTrue);
        expect(entry.status, 'pending');
        expect(entry.scheduledFor, d(2026, 11, 5));
        expect(entry.dueOn, d(2026, 11, 5)); // D3
        final templates = await dev.recurrences.templates();
        expect(templates, hasLength(1));
        expect(templates.single.scheduleLabel, 'Todo dia 5');
        expect(templates.single.defaultAmount, c(9000));
        // identificador determinístico (D1)
        expect(
          id,
          RecurrenceCalendar.occurrenceId(templates.single.id, d(2026, 11, 5)),
        );
        final ops = await _queue(dev);
        expect(ops, hasLength(1));
        expect(ops.single.rpc, 'create_recurrence_from_entry');
        expect(ops.single.createdIds, contains(templates.single.id));
      },
    );

    test('despesa fixa entra na sobra; variável sem valor ainda não', () async {
      await dev.service.create(expense(9000, d(2026, 11, 5)), repeat: monthly);
      expect(await dev.surplus(today), c(-9000));
      await dev.service.create(
        expense(null, d(2026, 11, 6)),
        repeat: monthlyVariable,
      );
      expect(await dev.surplus(today), c(-9000));
    });

    test('valor fixo exige valor', () async {
      await expectLater(
        dev.service.create(expense(null, d(2026, 11, 5)), repeat: monthly),
        throwsA(isA<ChangeRejectedException>()),
      );
    });

    test('data passada gera também as atrasadas até hoje (RN038)', () async {
      await dev.periods.createCovering(d(2026, 9, 5));
      await dev.service.create(expense(9000, d(2026, 9, 5)), repeat: monthly);
      expect(await dev.recurrenceRepo.generateDue(today), 2);
      final rows = await dev.rows('expense_entries');
      expect(rows.map((r) => r['scheduled_for_date']), [
        '2026-09-05',
        '2026-10-05',
        '2026-11-05',
      ]);
      // repetir não duplica
      expect(await dev.recurrenceRepo.generateDue(today), 0);
      expect(await dev.count('expense_entries'), 3);
    });

    test('todo período: a ocorrência fica no início do período', () async {
      await dev.service.create(
        expense(5000, d(2026, 11, 20)),
        repeat: byPeriod,
      );
      final row = (await dev.rows('expense_entries')).single;
      expect(row['scheduled_for_date'], '2026-11-01');
      expect(row['competence_on'], '2026-11-01');
      expect(row['scheduled_period_id'], isNotNull);
    });

    test(
      'receita recorrente nasce pendente, fora da sobra, e aparece no período',
      () async {
        final id = await dev.service.create(
          income(300000, d(2026, 11, 5)),
          repeat: monthly,
        );
        final entry = (await dev.entries.entry(EntryKind.income, id))!;
        expect(entry.status, 'pending');
        expect(entry.isPendingIncome, isTrue);
        expect(await dev.surplus(today), BigInt.zero);
        final period = (await dev.periods.periodFor(today))!;
        final listed = await dev.entries.entriesInPeriod(period.id);
        expect(listed.map((e) => e.id), [id]);
      },
    );

    test('"já recebi" confirma o recebimento junto com o cadastro', () async {
      await dev.service.create(
        income(300000, d(2026, 11, 5)),
        repeat: monthly,
        alreadyReceived: true,
        receivedOn: d(2026, 11, 7),
      );
      expect(await dev.surplus(today), c(300000));
      final row = (await dev.rows('income_entries')).single;
      expect(row['status'], 'received');
      expect(row['received_on'], '2026-11-07');
      final ops = await _queue(dev);
      expect(ops.map((o) => o.rpc), [
        'create_recurrence_from_entry',
        'apply_income_recurrence_occurrence_change',
      ]);
    });

    test('despesa "já paga" usa a RPC de ocorrência', () async {
      await dev.service.create(
        expense(9000, d(2026, 11, 5)),
        repeat: monthly,
        alreadyPaid: true,
        paidOn: d(2026, 11, 6),
      );
      expect(await dev.surplus(today), c(-9000)); // pagar não deduz de novo
      final ops = await _queue(dev);
      expect(ops.last.rpc, 'apply_expense_recurrence_occurrence_change');
      expect(ops.last.params['p_action'], 'pay');
    });

    test('lançamento avulso existente vira a primeira ocorrência', () async {
      final id = await dev.service.create(expense(9000, d(2026, 11, 5)));
      final current = (await dev.entries.entry(EntryKind.expense, id))!;
      await dev.service.update(
        current,
        expense(9500, d(2026, 11, 5)),
        repeat: monthly,
      );
      final entry = (await dev.entries.entry(EntryKind.expense, id))!;
      expect(entry.isRecurring, isTrue);
      expect(entry.amount, c(9500));
      expect(entry.version, 3); // criar, editar, converter
      // a geração não cria uma segunda ocorrência no mesmo mês
      await dev.recurrenceRepo.generateDue(today);
      expect(await dev.count('expense_entries'), 1);
    });

    test('categoria desativada não é aceita em nova recorrência', () async {
      final catRepo = LocalCategoryRepository(
        dev.db,
        'u1',
        LocalChangeRecorder(
          dev.db,
          newId: () => 'z${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      final id = 'cat-1';
      await dev.db.customStatement(
        "INSERT INTO categories (id, owner_id, version, created_at, updated_at, kind, name, is_active) "
        "VALUES ('$id', 'u1', 1, 'n', 'n', 'expense', 'Velha', 0)",
      );
      expect((await catRepo.categories()).single.isActive, isFalse);
      await expectLater(
        dev.service.create(
          EntryDraft(
            kind: EntryKind.expense,
            amount: c(100),
            date: d(2026, 11, 5),
            categoryId: id,
          ),
          repeat: monthly,
        ),
        throwsA(isA<ChangeRejectedException>()),
      );
    });

    test(
      'início antes do primeiro período pede para criar os períodos (D4)',
      () async {
        await expectLater(
          dev.service.create(expense(9000, d(2026, 6, 5)), repeat: monthly),
          throwsA(isA<PeriodMissingException>()),
        );
        expect(await dev.count('expense_recurrence_templates'), 0);
      },
    );
  });

  group('Entrega 47 — receitas recorrentes', () {
    late String id;
    setUp(() async {
      id = await dev.service.create(
        income(300000, d(2026, 11, 5)),
        repeat: monthly,
      );
    });

    test(
      'confirmar entra na sobra uma única vez, no período do recebimento',
      () async {
        var e = (await dev.entries.entry(EntryKind.income, id))!;
        await dev.service.receive(e, d(2026, 11, 8));
        expect(await dev.surplus(today), c(300000));
        e = (await dev.entries.entry(EntryKind.income, id))!;
        expect(e.status, 'received');
        await expectLater(
          dev.service.receive(e, d(2026, 11, 9)),
          throwsA(isA<ChangeRejectedException>()),
        );
        expect(await dev.surplus(today), c(300000));
      },
    );

    test('mudar a data de uma recebida move para o outro período', () async {
      await dev.periods.createCovering(d(2026, 12, 3));
      var e = (await dev.entries.entry(EntryKind.income, id))!;
      await dev.service.receive(e, d(2026, 11, 8));
      e = (await dev.entries.entry(EntryKind.income, id))!;
      await dev.service.update(e, income(300000, d(2026, 12, 3)));
      expect(await dev.surplus(d(2026, 11, 8)), BigInt.zero);
      expect(await dev.surplus(d(2026, 12, 3)), c(300000));
    });

    test(
      'variável exige valor para confirmar; valor pode ser dado ao confirmar',
      () async {
        final v = await dev.service.create(
          income(null, d(2026, 11, 6)),
          repeat: monthlyVariable,
        );
        final e = (await dev.entries.entry(EntryKind.income, v))!;
        await expectLater(
          dev.service.receive(e, d(2026, 11, 8)),
          throwsA(isA<ChangeRejectedException>()),
        );
        await dev.service.receive(e, d(2026, 11, 8), amount: c(1234));
        expect(await dev.surplus(today), c(1234));
      },
    );

    test(
      'editar o valor da ocorrência não muda o modelo nem as outras',
      () async {
        var e = (await dev.entries.entry(EntryKind.income, id))!;
        await dev.service.update(e, income(350000, d(2026, 11, 5)));
        e = (await dev.entries.entry(EntryKind.income, id))!;
        expect(e.amount, c(350000));
        expect(e.status, 'pending');
        final template = (await dev.recurrences.templates()).single;
        expect(template.defaultAmount, c(300000));
        final op = (await _queue(dev)).last;
        expect(op.rpc, 'apply_income_recurrence_occurrence_change');
        expect(
          (op.params['p_payload'] as Map).containsKey('received_on'),
          isFalse,
        );
      },
    );

    test('cancelar tira do período e não renasce na geração', () async {
      final e = (await dev.entries.entry(EntryKind.income, id))!;
      await dev.service.cancel(e);
      await dev.recurrenceRepo.generateDue(today);
      expect(await dev.count('income_entries'), 1);
      expect(
        (await dev.entries.entry(EntryKind.income, id))!.isCancelled,
        isTrue,
      );
      expect(await dev.surplus(today), BigInt.zero);
    });
  });

  group('Entrega 48 — despesas recorrentes', () {
    test(
      'variável: informar o valor faz entrar na sobra; pagar não deduz de novo',
      () async {
        final id = await dev.service.create(
          expense(null, d(2026, 11, 5)),
          repeat: monthlyVariable,
        );
        var e = (await dev.entries.entry(EntryKind.expense, id))!;
        expect(e.amount, isNull);
        await expectLater(
          dev.service.pay(e, d(2026, 11, 6)),
          throwsA(isA<ChangeRejectedException>()),
        );
        await dev.service.update(
          e,
          expense(25000, d(2026, 11, 5), dueOn: e.dueOn),
        );
        expect(await dev.surplus(today), c(-25000));
        e = (await dev.entries.entry(EntryKind.expense, id))!;
        await dev.service.pay(e, d(2026, 11, 8));
        expect(await dev.surplus(today), c(-25000));
        expect(
          (await dev.entries.entry(EntryKind.expense, id))!.isPaid,
          isTrue,
        );
      },
    );

    test(
      'vencimento = data da ocorrência e pode ser alterado sem mudar o período',
      () async {
        final id = await dev.service.create(
          expense(9000, d(2026, 11, 5)),
          repeat: monthly,
        );
        var e = (await dev.entries.entry(EntryKind.expense, id))!;
        expect(e.dueOn, d(2026, 11, 5));
        await dev.periods.createCovering(d(2026, 12, 3));
        await dev.service.update(
          e,
          expense(9000, d(2026, 11, 5), dueOn: d(2026, 12, 3)),
        );
        e = (await dev.entries.entry(EntryKind.expense, id))!;
        expect(e.dueOn, d(2026, 12, 3));
        expect(await dev.surplus(today), c(-9000));
        expect(await dev.surplus(d(2026, 12, 3)), BigInt.zero);
      },
    );

    test(
      'valor variável pode ficar sem valor ao editar só a descrição',
      () async {
        final id = await dev.service.create(
          expense(null, d(2026, 11, 5)),
          repeat: monthlyVariable,
        );
        final e = (await dev.entries.entry(EntryKind.expense, id))!;
        await dev.service.update(
          e,
          expense(null, d(2026, 11, 5), dueOn: e.dueOn),
        );
        expect(
          (await dev.entries.entry(EntryKind.expense, id))!.amount,
          isNull,
        );
      },
    );

    test('despesa fixa não aceita ficar sem valor', () async {
      final id = await dev.service.create(
        expense(9000, d(2026, 11, 5)),
        repeat: monthly,
      );
      final e = (await dev.entries.entry(EntryKind.expense, id))!;
      await expectLater(
        dev.service.update(e, expense(null, d(2026, 11, 5), dueOn: e.dueOn)),
        throwsA(isA<ChangeRejectedException>()),
      );
    });

    test('pendente permanece no período original', () async {
      await dev.periods.createCovering(d(2026, 12, 3));
      await dev.service.create(expense(9000, d(2026, 11, 5)), repeat: monthly);
      expect(await dev.surplus(d(2026, 11, 5)), c(-9000));
      expect(await dev.surplus(d(2026, 12, 3)), BigInt.zero);
    });
  });

  group('Entrega 46 — geração', () {
    test('modelo desativado não gera; as já geradas ficam (D7)', () async {
      await dev.service.create(expense(9000, d(2026, 11, 5)), repeat: monthly);
      final t = (await dev.recurrences.templates()).single;
      await dev.recurrences.stop(t);
      await dev.periods.createCovering(d(2026, 12, 20));
      await dev.recurrenceRepo.generateDue(d(2026, 12, 20));
      expect(await dev.count('expense_entries'), 1);
      expect((await dev.recurrences.templates()).single.isActive, isFalse);
    });

    test('dois aparelhos offline geram a mesma ocorrência (mesmo id)', () async {
      await dev.periods.createCovering(d(2026, 9, 5));
      await dev.service.create(expense(9000, d(2026, 9, 5)), repeat: monthly);
      await dev.recurrenceRepo.generateDue(today);

      // segundo aparelho recebe só o modelo (download) e gera sozinho
      final other = Device('y');
      await other.setUp();
      await other.periods.createCovering(d(2026, 9, 5));
      final template = (await dev.rows(
        'expense_recurrence_templates',
        order: 'id',
      )).single;
      await other.db.customStatement(
        'INSERT INTO expense_recurrence_templates (id, owner_id, version, '
        'created_at, updated_at, description, frequency, starts_on, '
        'monthly_reference_day, value_mode, default_amount_centavos, is_active) '
        "VALUES (?, 'u1', 1, 'n', 'n', ?, 'monthly', ?, 5, 'fixed', '9000', 1)",
        [template['id'], template['description'], '2026-09-05'],
      );
      await other.recurrenceRepo.generateDue(today);
      final a = (await dev.rows('expense_entries')).map((r) => r['id']).toSet();
      final b = (await other.rows(
        'expense_entries',
      )).map((r) => r['id']).toSet();
      // as ocorrências de 05/10 e 05/11 têm o mesmo id nos dois aparelhos
      expect(b.difference(a), isEmpty);
      expect(b, hasLength(3));
      await other.db.close();
    });

    test('abrir N vezes não duplica', () async {
      await dev.service.create(income(1000, d(2026, 11, 5)), repeat: monthly);
      for (var i = 0; i < 5; i++) {
        await dev.recurrenceRepo.generateDue(today);
      }
      expect(await dev.count('income_entries'), 1);
    });

    test('virada do dia: 23h59 e 00h00 em São Paulo', () async {
      await dev.service.create(expense(1000, d(2026, 11, 9)), repeat: monthly);
      // dia 10 ainda não chegou (dia 9 + um mês = 9/12): nada novo
      expect(await dev.recurrenceRepo.generateDue(d(2026, 12, 8)), 0);
      await dev.periods.createCovering(d(2026, 12, 9));
      expect(await dev.recurrenceRepo.generateDue(d(2026, 12, 9)), 1);
    });

    test(
      'na sincronização: servidor gera depois dos modelos e antes das ocorrências',
      () async {
        final id = await dev.service.create(
          expense(9000, d(2026, 11, 5)),
          repeat: monthly,
        );
        final e = (await dev.entries.entry(EntryKind.expense, id))!;
        await dev.service.pay(e.copyWith(), d(2026, 11, 6));
        final gateway = RecordingGateway();
        await SyncService(dev.db, gateway).syncOnce('u1');
        expect(
          gateway.calls.where((c) => c != 'create_accounting_period').toList(),
          [
            'create_recurrence_from_entry',
            'generate_due_recurrence_occurrences',
            'apply_expense_recurrence_occurrence_change',
          ],
        );
      },
    );
  });

  group('Mudança de agenda e edição da recorrência (D2)', () {
    test(
      'dia 5 gerada em 05/11 → muda para dia 20 → próxima em 20/12',
      () async {
        await dev.service.create(
          expense(9000, d(2026, 11, 5)),
          repeat: monthly,
        );
        final t = (await dev.recurrences.templates()).single;
        await dev.recurrences.edit(
          t,
          TemplateEdit(
            frequency: RecurrenceFrequency.monthly,
            monthlyReferenceDay: 20,
            variableValue: false,
            defaultAmount: c(9500),
          ),
          today: today,
        );
        final after = (await dev.recurrences.templates()).single;
        expect(after.startsOn, d(2026, 12, 1));
        expect(after.defaultAmount, c(9500));
        await dev.periods.createCovering(d(2026, 12, 31));
        await dev.recurrenceRepo.generateDue(d(2026, 11, 30));
        expect(await dev.count('expense_entries'), 1); // nada em novembro
        await dev.recurrenceRepo.generateDue(d(2026, 12, 31));
        final rows = await dev.rows('expense_entries');
        expect(rows.map((r) => r['scheduled_for_date']), [
          '2026-11-05',
          '2026-12-20',
        ]);
        // a ocorrência já gerada não mudou
        expect(rows.first['amount_centavos'], '9000');
        expect(rows.last['amount_centavos'], '9500');
      },
    );

    test('valor, descrição e categoria valem só para as próximas', () async {
      await dev.service.create(expense(9000, d(2026, 11, 5)), repeat: monthly);
      final t = (await dev.recurrences.templates()).single;
      await dev.recurrences.edit(
        t,
        TemplateEdit(
          description: 'Academia nova',
          frequency: RecurrenceFrequency.monthly,
          monthlyReferenceDay: 5,
          variableValue: false,
          defaultAmount: c(10000),
        ),
        today: today,
      );
      expect(await dev.surplus(today), c(-9000));
      final after = (await dev.recurrences.templates()).single;
      expect(after.description, 'Academia nova');
      expect(after.startsOn, d(2026, 11, 5)); // agenda não mudou
    });

    test('recorrência parada não pode ser alterada', () async {
      await dev.service.create(expense(9000, d(2026, 11, 5)), repeat: monthly);
      final t = (await dev.recurrences.templates()).single;
      await dev.recurrences.stop(t);
      final stopped = (await dev.recurrences.templates()).single;
      await expectLater(
        dev.recurrences.edit(
          stopped,
          TemplateEdit(
            frequency: RecurrenceFrequency.monthly,
            monthlyReferenceDay: 5,
            variableValue: false,
            defaultAmount: c(1),
          ),
          today: today,
        ),
        throwsA(isA<ChangeRejectedException>()),
      );
    });
  });
}

/// Fila de envio sem as operações de criação de período do `setUp`.
Future<List<OutboxOperation>> _queue(Device dev) async => (await SyncService(
  dev.db,
  RecordingGateway(),
).operations('u1')).where((o) => o.rpc != 'create_accounting_period').toList();
