import '../../core/domain/calendar_date.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../entries/entry_models.dart';

/// Modelo de receita ou despesa recorrente (RN010, RN014).
class RecurringTemplate {
  const RecurringTemplate({
    required this.id,
    required this.kind,
    required this.frequency,
    required this.startsOn,
    required this.variableValue,
    required this.isActive,
    required this.version,
    this.description,
    this.monthlyReferenceDay,
    this.defaultAmount,
    this.categoryId,
    this.subcategoryId,
  });

  final String id;
  final EntryKind kind;
  final String? description;
  final RecurrenceFrequency frequency;
  final CalendarDate startsOn;
  final int? monthlyReferenceDay;

  /// Valor muda a cada ocorrência (`value_mode = 'variable'`).
  final bool variableValue;
  final BigInt? defaultAmount;
  final String? categoryId;
  final String? subcategoryId;
  final bool isActive;
  final int version;

  RecurrenceSchedule get schedule => frequency == RecurrenceFrequency.monthly
      ? RecurrenceSchedule.monthly(
          startsOn: startsOn,
          day: monthlyReferenceDay!,
        )
      : RecurrenceSchedule.byPeriod(startsOn: startsOn);

  /// "Todo dia 5" ou "Todo período".
  String get scheduleLabel => frequency == RecurrenceFrequency.monthly
      ? 'Todo dia $monthlyReferenceDay'
      : 'Todo período';

  Map<String, dynamic> toSnapshot() => {
    'id': id,
    'description': description,
    'frequency': frequency.dbValue,
    'starts_on': startsOn.toIso(),
    'monthly_reference_day': monthlyReferenceDay,
    'value_mode': variableValue ? 'variable' : 'fixed',
    'default_amount_centavos': defaultAmount?.toString(),
    'category_id': categoryId,
    'subcategory_id': subcategoryId,
    'is_active': isActive,
    'version': version,
  };
}

/// Alterações do usuário em "a recorrência" (valem só para as próximas
/// ocorrências, D2).
class TemplateEdit {
  const TemplateEdit({
    required this.frequency,
    required this.variableValue,
    this.description,
    this.monthlyReferenceDay,
    this.defaultAmount,
    this.categoryId,
    this.subcategoryId,
  });

  final String? description;
  final RecurrenceFrequency frequency;
  final int? monthlyReferenceDay;
  final bool variableValue;
  final BigInt? defaultAmount;
  final String? categoryId;
  final String? subcategoryId;
}

/// Última ocorrência já gerada de um modelo, usada para a agenda alterada
/// nunca repetir o mês (D2).
class ScheduleFacts {
  const ScheduleFacts({this.lastScheduled});

  final CalendarDate? lastScheduled;
}
