import '../../core/domain/calendar_date.dart';
import '../entries/entry_models.dart';
import 'recurrence_models.dart';

/// Modelos recorrentes e geração das ocorrências. Celular: banco local +
/// fila de envio. Web: servidor, somente online.
abstract interface class RecurrenceRepository {
  Future<List<RecurringTemplate>> templates();

  Future<RecurringTemplate?> template(EntryKind kind, String id);

  Future<ScheduleFacts> scheduleFacts(EntryKind kind, String templateId);

  /// Grava a alteração do modelo. [startsOn] é o início já ajustado (D2).
  Future<void> updateTemplate(
    RecurringTemplate current,
    TemplateEdit edit,
    CalendarDate startsOn,
  );

  /// "Parar de repetir": desativa o modelo; as ocorrências já geradas ficam
  /// como estão (D7).
  Future<void> stop(RecurringTemplate current);

  /// Gera as ocorrências devidas até [today] (RN038). Idempotente. Devolve
  /// quantas foram criadas (no servidor, as criadas agora).
  Future<int> generateDue(CalendarDate today);
}
