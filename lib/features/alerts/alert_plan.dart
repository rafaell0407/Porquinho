import '../../core/domain/calendar_date.dart';

/// Despesa pendente com vencimento, como entra no cálculo dos alertas.
class DueExpense {
  const DueExpense({required this.id, required this.dueOn});

  final String id;
  final CalendarDate dueOn;
}

/// Um alerta diário (RN018, RN035, RN041, D9): uma única notificação por dia,
/// resumindo as despesas pendentes, sem valores nem nomes (tela bloqueada).
class PlannedAlert {
  const PlannedAlert({
    required this.date,
    this.dueToday = 0,
    this.inThreeDays = 0,
    this.overdue = 0,
  });

  final CalendarDate date;
  final int dueToday;
  final int inThreeDays;
  final int overdue;

  /// Identificador estável da notificação do dia (`AAAAMMDD`).
  int get id => date.year * 10000 + date.month * 100 + date.day;

  String get body {
    String count(int n, String one, String many) =>
        n == 1 ? '1 $one' : '$n $many';
    return [
      if (overdue > 0)
        count(overdue, 'despesa em atraso', 'despesas em atraso'),
      if (dueToday > 0) count(dueToday, 'vence hoje', 'vencem hoje'),
      if (inThreeDays > 0)
        count(inThreeDays, 'vence em 3 dias', 'vencem em 3 dias'),
    ].join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is PlannedAlert &&
      other.date == date &&
      other.dueToday == dueToday &&
      other.inThreeDays == inThreeDays &&
      other.overdue == overdue;

  @override
  int get hashCode => Object.hash(date, dueToday, inThreeDays, overdue);
}

/// Horário do alerta: 9h na zona do usuário (D9).
const alertHour = 9;

/// Janela de agendamento: 30 dias (D9). Reagendada ao abrir, sincronizar e
/// salvar, então o limite de alarmes do Android nunca é atingido.
const alertWindowDays = 30;

/// Calcula os alertas de [today] até [alertWindowDays] dias à frente.
///
/// Para cada despesa pendente com vencimento: aviso 3 dias antes, no dia e
/// todo dia depois, enquanto continuar pendente, mesmo após o fim do período
/// (RN018, RN041). Vencimento muito antigo gera **um** resumo por dia, não uma
/// rajada. [todayStillAhead] indica que as [alertHour]h de hoje ainda não
/// chegaram; senão o alerta de hoje já passou e não é agendado.
List<PlannedAlert> planAlerts(
  Iterable<DueExpense> pending,
  CalendarDate today, {
  required bool todayStillAhead,
  int windowDays = alertWindowDays,
}) {
  final result = <PlannedAlert>[];
  for (var i = todayStillAhead ? 0 : 1; i < windowDays; i++) {
    final day = today.addDays(i);
    var dueToday = 0;
    var inThree = 0;
    var overdue = 0;
    for (final e in pending) {
      if (e.dueOn == day) {
        dueToday++;
      } else if (e.dueOn.addDays(-3) == day) {
        inThree++;
      } else if (e.dueOn.isBefore(day)) {
        overdue++;
      }
    }
    if (dueToday + inThree + overdue > 0) {
      result.add(
        PlannedAlert(
          date: day,
          dueToday: dueToday,
          inThreeDays: inThree,
          overdue: overdue,
        ),
      );
    }
  }
  return result;
}
