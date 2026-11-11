import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/features/alerts/alert_plan.dart';
import 'package:porquinho/features/alerts/alert_providers.dart';
import 'package:porquinho/features/alerts/alert_scheduler.dart';

CalendarDate d(String iso) => CalendarDate.parse(iso);
DueExpense due(String iso) => DueExpense(id: iso, dueOn: d(iso));

void main() {
  final today = d('2026-11-10');

  test('3 dias antes, no dia e diariamente depois (RN018/RN041)', () {
    final alerts = planAlerts(
      [due('2026-11-15')],
      today,
      todayStillAhead: true,
      windowDays: 10,
    );
    expect(alerts.map((a) => a.date.toIso()), [
      '2026-11-12', // 3 dias antes
      '2026-11-15', // no dia
      '2026-11-16',
      '2026-11-17',
      '2026-11-18',
      '2026-11-19',
    ]);
    expect(alerts[0].inThreeDays, 1);
    expect(alerts[1].dueToday, 1);
    expect(alerts[2].overdue, 1);
  });

  test('vencimento antigo gera um resumo por dia, não uma rajada', () {
    final alerts = planAlerts(
      [due('2026-01-05'), due('2026-02-10'), due('2026-03-15')],
      today,
      todayStillAhead: true,
      windowDays: 5,
    );
    expect(alerts, hasLength(5));
    expect(alerts.every((a) => a.overdue == 3), isTrue);
    expect(alerts.first.body, '3 despesas em atraso');
  });

  test('o alerta de hoje só entra se as 9h ainda não passaram', () {
    final before = planAlerts(
      [due('2026-11-10')],
      today,
      todayStillAhead: true,
      windowDays: 3,
    );
    final after = planAlerts(
      [due('2026-11-10')],
      today,
      todayStillAhead: false,
      windowDays: 3,
    );
    expect(before.first.date, today);
    expect(after.first.date, d('2026-11-11'));
  });

  test('texto resume sem valores nem nomes', () {
    final alert = planAlerts(
      [
        due('2026-11-10'),
        due('2026-11-10'),
        due('2026-11-13'),
        due('2026-11-01'),
      ],
      today,
      todayStillAhead: true,
      windowDays: 1,
    ).single;
    expect(
      alert.body,
      '1 despesa em atraso · 2 vencem hoje · 1 vence em 3 dias',
    );
  });

  test('sem despesa pendente não há alerta (paga ou cancelada some)', () {
    expect(planAlerts([], today, todayStillAhead: true), isEmpty);
  });

  test('janela de 30 dias', () {
    final alerts = planAlerts(
      [due('2026-01-01')],
      today,
      todayStillAhead: true,
    );
    expect(alerts, hasLength(alertWindowDays));
  });

  test('9h em São Paulo: antes e depois', () {
    // 11h UTC = 8h em São Paulo (UTC-3)
    expect(
      beforeAlertHour(DateTime.utc(2026, 11, 10, 11), 'America/Sao_Paulo'),
      isTrue,
    );
    // 12h UTC = 9h
    expect(
      beforeAlertHour(DateTime.utc(2026, 11, 10, 12), 'America/Sao_Paulo'),
      isFalse,
    );
  });

  test('agendador vazio (Web) não faz nada', () async {
    await const NoopAlertScheduler().replaceAll([]);
    await const NoopAlertScheduler().cancelAll();
  });
}
