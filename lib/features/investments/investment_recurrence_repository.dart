import '../../core/domain/calendar_date.dart';
import '../recurrence/recurrence_models.dart';
import 'investment_models.dart';

/// Modelos de investimento recorrente. Celular: banco local + fila de envio.
/// Web: servidor, somente online. A geração das ocorrências fica em
/// `RecurrenceRepository.generateDue` (junto com receitas e despesas).
abstract interface class InvestmentRecurrenceRepository {
  Future<List<InvestmentTemplate>> templates();

  Future<InvestmentTemplate?> template(String id);

  Future<ScheduleFacts> scheduleFacts(String templateId);

  /// Grava a alteração do modelo. [startsOn] é o início já ajustado (D2).
  Future<void> updateTemplate(
    InvestmentTemplate current,
    InvestmentTemplateEdit edit,
    CalendarDate startsOn,
  );

  /// "Parar de repetir": desativa o modelo; as ocorrências já geradas ficam
  /// como estão.
  Future<void> stop(InvestmentTemplate current);
}
