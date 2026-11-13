import '../../core/domain/calendar_date.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_models.dart';
import '../categories/category_repository.dart';
import 'recurrence_models.dart';
import 'recurrence_repository.dart';

/// Regras de edição, parada e geração das recorrências (RN010–RN014, RN038,
/// decisões D2, D7 e D8 da Fase 5). As mesmas validações da RPC.
class RecurrenceService {
  RecurrenceService(this._repo, this._categories);

  final RecurrenceRepository _repo;
  final CategoryRepository _categories;

  static const maxDescriptionLength = 120;

  Future<List<RecurringTemplate>> templates() => _repo.templates();

  /// Altera o modelo. Vale só para as próximas ocorrências: as já geradas não
  /// mudam e a nova agenda nunca repete o mês/período já gerado nem cria
  /// ocorrências passadas (D2).
  Future<void> edit(
    RecurringTemplate current,
    TemplateEdit edit, {
    required CalendarDate today,
  }) async {
    if (!current.isActive) {
      throw const ChangeRejectedException(
        'Esta recorrência foi interrompida e não pode mais ser alterada.',
      );
    }
    final description = edit.description?.trim();
    if (description != null && description.length > maxDescriptionLength) {
      throw const ChangeRejectedException(
        'A descrição aceita até $maxDescriptionLength caracteres.',
      );
    }
    final day = edit.monthlyReferenceDay;
    if (edit.frequency == RecurrenceFrequency.monthly &&
        (day == null || day < 1 || day > 31)) {
      throw const ChangeRejectedException('Informe um dia entre 1 e 31.');
    }
    if (!edit.variableValue &&
        (edit.defaultAmount == null || edit.defaultAmount!.isNegative)) {
      throw const ChangeRejectedException(
        'Informe o valor da recorrência ou marque que o valor muda todo mês.',
      );
    }
    await _checkCategory(current, edit);

    var startsOn = current.startsOn;
    final scheduleChanged =
        edit.frequency != current.frequency ||
        (edit.frequency == RecurrenceFrequency.monthly &&
            day != current.monthlyReferenceDay);
    if (scheduleChanged) {
      final facts = await _repo.scheduleFacts(current.kind, current.id);
      final floor = facts.lastScheduled == null
          ? null
          : RecurrenceCalendar.scheduleChangeFloor(facts.lastScheduled!);
      startsOn = RecurrenceCalendar.effectiveStart(
        current.startsOn,
        today,
        floor: floor,
      );
    }
    await _repo.updateTemplate(
      current,
      TemplateEdit(
        description: (description == null || description.isEmpty)
            ? null
            : description,
        frequency: edit.frequency,
        monthlyReferenceDay: edit.monthlyReferenceDay,
        variableValue: edit.variableValue,
        defaultAmount: edit.defaultAmount,
        categoryId: edit.categoryId,
        subcategoryId: edit.subcategoryId,
      ),
      startsOn,
    );
  }

  Future<void> stop(RecurringTemplate current) {
    if (!current.isActive) {
      throw const ChangeRejectedException('Esta recorrência já foi parada.');
    }
    return _repo.stop(current);
  }

  Future<int> generateDue(CalendarDate today) => _repo.generateDue(today);

  Future<void> _checkCategory(RecurringTemplate current, TemplateEdit e) async {
    if (e.subcategoryId != null && e.categoryId == null) {
      throw const ChangeRejectedException(
        'Escolha a categoria da subcategoria.',
      );
    }
    final categories = await _categories.categories();
    final subs = await _categories.subcategories();
    if (e.categoryId != null) {
      final cat = categories.where((c) => c.id == e.categoryId).firstOrNull;
      if (cat == null) {
        throw const ChangeRejectedException('Categoria não encontrada.');
      }
      if (cat.kind.dbValue != current.kind.categoryKind) {
        throw const ChangeRejectedException(
          'A categoria precisa ser do mesmo tipo do lançamento.',
        );
      }
      if (e.categoryId != current.categoryId && !cat.isActive) {
        throw const ChangeRejectedException('A categoria está desativada.');
      }
    }
    if (e.subcategoryId != null) {
      final sub = subs.where((s) => s.id == e.subcategoryId).firstOrNull;
      if (sub == null || sub.categoryId != e.categoryId) {
        throw const ChangeRejectedException(
          'A subcategoria não pertence à categoria escolhida.',
        );
      }
      final changed =
          e.categoryId != current.categoryId ||
          e.subcategoryId != current.subcategoryId;
      if (changed && !sub.isActive) {
        throw const ChangeRejectedException('A subcategoria está desativada.');
      }
    }
  }
}
