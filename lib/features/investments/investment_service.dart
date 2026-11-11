import '../../core/domain/calendar_date.dart';
import '../../core/domain/money.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_models.dart';
import '../entries/entry_models.dart' show PeriodMissingException;
import '../periods/period_models.dart';
import '../periods/period_service.dart';
import '../sync/sync_models.dart';
import 'investment_models.dart';
import 'investment_repository.dart';

/// Regras de investimento (RN004, RN021–RN023, RN027–RN029, D1, D2): só valor
/// e data; a data pode ser passada ou futura; o valor sai da sobra do período
/// da data. As mesmas validações da RPC, para que o salvo no aparelho não seja
/// recusado depois.
class InvestmentService {
  InvestmentService(this._repo, this._periods, {String Function()? newId})
    : _newId = newId ?? newUuid;

  final InvestmentRepository _repo;
  final PeriodService _periods;
  final String Function() _newId;

  Future<List<InvestmentRecord>> investmentsInPeriod(String periodId) =>
      _repo.investmentsInPeriod(periodId);

  /// Registra um investimento e devolve seu id. Com [repeat] (D7) cria
  /// também a recorrência: o investimento é a primeira ocorrência, no valor
  /// informado (valor sempre fixo, D8).
  Future<String> create(
    InvestmentDraft draft, {
    RecurrenceFrequency? repeat,
  }) async {
    final clean = _validated(draft);
    final period = await _requirePeriod(clean.date);
    if (repeat == null) {
      final id = _newId();
      await _repo.apply([CreateInvestment(id, clean)]);
      return id;
    }
    final recurrence = _recurrenceFor(clean, repeat, period, null);
    await _repo.apply([recurrence]);
    return recurrence.entryId;
  }

  /// Edita valor e/ou data. Mudar a data move o valor para o período da nova
  /// data. Em ocorrência recorrente altera só esta ocorrência (o modelo e as
  /// demais não mudam). Em investimento avulso, [repeat] o transforma na
  /// primeira ocorrência de uma recorrência. Cancelado não pode ser alterado.
  Future<void> update(
    InvestmentRecord current,
    InvestmentDraft draft, {
    RecurrenceFrequency? repeat,
  }) async {
    _requireEditable(current);
    if (repeat != null && current.isRecurring) {
      throw const ChangeRejectedException('Este investimento já se repete.');
    }
    final clean = _validated(draft);
    PeriodRecord? period;
    if (repeat != null || clean.date != current.date) {
      period = await _requirePeriod(clean.date);
    }
    final changes = <InvestmentChange>[UpdateInvestment(current, clean)];
    if (repeat != null) {
      changes.add(
        _recurrenceFor(
          clean,
          repeat,
          period!,
          current.copyWith(version: current.version + 1),
        ),
      );
    }
    await _repo.apply(changes);
  }

  CreateInvestmentRecurrence _recurrenceFor(
    InvestmentDraft clean,
    RecurrenceFrequency frequency,
    PeriodRecord period,
    InvestmentRecord? existing,
  ) {
    final templateId = _newId();
    final scheduled = RecurrenceCalendar.firstOccurrenceDate(
      frequency,
      clean.date,
      period.range,
    );
    return CreateInvestmentRecurrence(
      templateId: templateId,
      entryId:
          existing?.id ??
          RecurrenceCalendar.occurrenceId(templateId, scheduled),
      draft: clean,
      frequency: frequency,
      scheduledFor: scheduled,
      periodId: period.id,
      scheduledPeriodId: frequency == RecurrenceFrequency.byPeriod
          ? period.id
          : null,
      existing: existing,
    );
  }

  /// Cancela: sai da sobra do período original e continua no histórico.
  Future<void> cancel(InvestmentRecord current) async {
    _requireEditable(current);
    await _repo.apply([CancelInvestment(current)]);
  }

  /// Cria os períodos faltantes depois da confirmação do usuário (RN002).
  Future<void> createMissingPeriods(CalendarDate date) =>
      _periods.createCovering(date);

  void _requireEditable(InvestmentRecord current) {
    if (current.cancelled) {
      throw const ChangeRejectedException(
        'Este investimento está cancelado e não pode mais ser alterado.',
      );
    }
  }

  Future<PeriodRecord> _requirePeriod(CalendarDate date) async {
    final plan = await _periods.planFor(date);
    if (plan != null) throw PeriodMissingException(date, plan);
    final period = await _periods.periodFor(date);
    if (period == null) {
      throw const ChangeRejectedException('Nenhum período cobre esta data.');
    }
    return period;
  }

  InvestmentDraft _validated(InvestmentDraft d) {
    final amount = d.amount;
    if (amount == null) {
      throw const ChangeRejectedException('Informe o valor.');
    }
    if (amount.isNegative) {
      throw const ChangeRejectedException('O valor não pode ser negativo.');
    }
    if (amount > maxCentavos) {
      throw const ChangeRejectedException('Valor acima do limite permitido.');
    }
    return d;
  }
}
