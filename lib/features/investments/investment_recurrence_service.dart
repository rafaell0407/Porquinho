import '../../core/domain/calendar_date.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_models.dart';
import 'investment_models.dart';
import 'investment_recurrence_repository.dart';

/// Edição e parada do investimento recorrente (D7–D9). Mesmas validações da
/// RPC; valor sempre obrigatório (D8).
class InvestmentRecurrenceService {
  InvestmentRecurrenceService(this._repo);

  final InvestmentRecurrenceRepository _repo;

  Future<List<InvestmentTemplate>> templates() => _repo.templates();

  Future<InvestmentTemplate?> template(String id) => _repo.template(id);

  /// Altera o modelo. Vale só para as próximas ocorrências: as já geradas não
  /// mudam e a nova agenda nunca repete o mês/período já gerado nem cria
  /// ocorrências passadas.
  Future<void> edit(
    InvestmentTemplate current,
    InvestmentTemplateEdit edit, {
    required CalendarDate today,
  }) async {
    if (!current.isActive) {
      throw const ChangeRejectedException(
        'Esta recorrência foi interrompida e não pode mais ser alterada.',
      );
    }
    final day = edit.monthlyReferenceDay;
    if (edit.frequency == RecurrenceFrequency.monthly &&
        (day == null || day < 1 || day > 31)) {
      throw const ChangeRejectedException('Informe um dia entre 1 e 31.');
    }
    if (edit.defaultAmount.isNegative) {
      throw const ChangeRejectedException('O valor não pode ser negativo.');
    }
    var startsOn = current.startsOn;
    final scheduleChanged =
        edit.frequency != current.frequency ||
        (edit.frequency == RecurrenceFrequency.monthly &&
            day != current.monthlyReferenceDay);
    if (scheduleChanged) {
      final facts = await _repo.scheduleFacts(current.id);
      final floor = facts.lastScheduled == null
          ? null
          : RecurrenceCalendar.scheduleChangeFloor(facts.lastScheduled!);
      startsOn = RecurrenceCalendar.effectiveStart(
        current.startsOn,
        today,
        floor: floor,
      );
    }
    await _repo.updateTemplate(current, edit, startsOn);
  }

  Future<void> stop(InvestmentTemplate current) async {
    if (!current.isActive) {
      throw const ChangeRejectedException('Esta recorrência já foi parada.');
    }
    await _repo.stop(current);
  }
}
