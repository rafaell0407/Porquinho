import '../../core/domain/calendar_date.dart';
import '../../core/domain/recurrence_schedule.dart';

/// Investimento (destinação) como o usuário o vê: só valor e data (D1, D2).
class InvestmentRecord {
  const InvestmentRecord({
    required this.id,
    required this.amount,
    required this.date,
    required this.version,
    this.periodId,
    this.cancelled = false,
    this.templateId,
    this.scheduledFor,
  });

  final String id;
  final BigInt amount;
  final CalendarDate date;
  final int version;
  final String? periodId;
  final bool cancelled;

  /// Modelo recorrente de que esta ocorrência vem (`null` = avulso).
  final String? templateId;
  final CalendarDate? scheduledFor;

  bool get isRecurring => templateId != null;

  InvestmentRecord copyWith({int? version}) => InvestmentRecord(
    id: id,
    amount: amount,
    date: date,
    version: version ?? this.version,
    periodId: periodId,
    cancelled: cancelled,
    templateId: templateId,
    scheduledFor: scheduledFor,
  );

  Map<String, dynamic> toSnapshot() => {
    'id': id,
    'amount_centavos': amount.toString(),
    'allocated_on': date.toIso(),
    'accounting_period_id': periodId,
    'cancelled': cancelled,
    'recurrence_template_id': templateId,
    'scheduled_for_date': scheduledFor?.toIso(),
    'version': version,
  };
}

/// Dados que o usuário preenche ao criar ou editar.
class InvestmentDraft {
  const InvestmentDraft({required this.amount, required this.date});
  final BigInt? amount;
  final CalendarDate date;
}

/// Modelo de investimento recorrente (D7, D8): agenda e valor fixo; sem
/// descrição, categoria nem valor variável.
class InvestmentTemplate {
  const InvestmentTemplate({
    required this.id,
    required this.frequency,
    required this.startsOn,
    required this.defaultAmount,
    required this.isActive,
    required this.version,
    this.monthlyReferenceDay,
  });

  final String id;
  final RecurrenceFrequency frequency;
  final CalendarDate startsOn;
  final int? monthlyReferenceDay;
  final BigInt defaultAmount;
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
    'frequency': frequency.dbValue,
    'starts_on': startsOn.toIso(),
    'monthly_reference_day': monthlyReferenceDay,
    'default_amount_centavos': defaultAmount.toString(),
    'is_active': isActive,
    'version': version,
  };
}

/// Alterações do usuário em "a recorrência" (valem só para as próximas).
class InvestmentTemplateEdit {
  const InvestmentTemplateEdit({
    required this.frequency,
    required this.defaultAmount,
    this.monthlyReferenceDay,
  });

  final RecurrenceFrequency frequency;
  final int? monthlyReferenceDay;
  final BigInt defaultAmount;
}

sealed class InvestmentChange {
  const InvestmentChange();
}

class CreateInvestment extends InvestmentChange {
  const CreateInvestment(this.id, this.draft);
  final String id;
  final InvestmentDraft draft;
}

class UpdateInvestment extends InvestmentChange {
  const UpdateInvestment(this.current, this.draft);
  final InvestmentRecord current;
  final InvestmentDraft draft;
}

class CancelInvestment extends InvestmentChange {
  const CancelInvestment(this.current);
  final InvestmentRecord current;
}

/// Cria o modelo recorrente e faz o investimento ser a primeira ocorrência
/// (D7). [existing] é o investimento avulso que está sendo convertido.
class CreateInvestmentRecurrence extends InvestmentChange {
  const CreateInvestmentRecurrence({
    required this.templateId,
    required this.entryId,
    required this.draft,
    required this.frequency,
    required this.scheduledFor,
    required this.periodId,
    this.scheduledPeriodId,
    this.existing,
  });

  final String templateId;
  final String entryId;
  final InvestmentDraft draft;
  final RecurrenceFrequency frequency;

  /// Data programada da primeira ocorrência (mensal: a data do investimento;
  /// por período: início do período).
  final CalendarDate scheduledFor;

  /// Período que contém a data programada.
  final String periodId;

  /// Período programado (só "todo período").
  final String? scheduledPeriodId;
  final InvestmentRecord? existing;

  bool get isMonthly => frequency == RecurrenceFrequency.monthly;

  Map<String, dynamic> templatePayload() => {
    'frequency': frequency.dbValue,
    'starts_on': draft.date.toIso(),
    'monthly_reference_day': isMonthly ? draft.date.day : null,
    'default_amount_centavos': draft.amount.toString(),
  };
}

/// Chamada à RPC do servidor equivalente a uma [InvestmentChange]. Por padrão
/// `apply_investment_allocation_change` (parâmetros na ordem da assinatura).
class InvestmentRpcCall {
  const InvestmentRpcCall({
    required this.entityId,
    required this.action,
    required this.expectedVersion,
    this.amount,
    this.date,
    this.rpcName,
    this.extraParams,
  });

  static const defaultRpc = 'apply_investment_allocation_change';
  static const entityType = 'investment_allocation';

  final String entityId;

  /// `create`, `update` ou `cancel`.
  final String action;
  final int expectedVersion;
  final BigInt? amount;
  final CalendarDate? date;

  /// RPC de criação da recorrência (em vez da de investimento avulso).
  final String? rpcName;
  final Map<String, dynamic>? extraParams;

  String get rpc => rpcName ?? defaultRpc;

  Map<String, dynamic> get params =>
      extraParams ??
      {
        'p_action': action,
        'p_allocation_id': entityId,
        'p_expected_version': expectedVersion,
        'p_amount_centavos': amount?.toString(),
        'p_allocated_on': date?.toIso(),
      };
}

InvestmentRpcCall investmentRpcCallFor(InvestmentChange change) =>
    switch (change) {
      CreateInvestment(:final id, :final draft) => InvestmentRpcCall(
        entityId: id,
        action: 'create',
        expectedVersion: 0,
        amount: draft.amount,
        date: draft.date,
      ),
      UpdateInvestment(:final current, :final draft) => InvestmentRpcCall(
        entityId: current.id,
        action: 'update',
        expectedVersion: current.version,
        amount: draft.amount,
        date: draft.date,
      ),
      CancelInvestment(:final current) => InvestmentRpcCall(
        entityId: current.id,
        action: 'cancel',
        expectedVersion: current.version,
      ),
      final CreateInvestmentRecurrence c => InvestmentRpcCall(
        entityId: c.entryId,
        action: c.existing == null ? 'create' : 'update',
        expectedVersion: c.existing?.version ?? 0,
        rpcName: 'create_investment_recurrence_from_entry',
        extraParams: {
          'p_template_id': c.templateId,
          'p_entry_id': c.entryId,
          'p_expected_entry_version': c.existing?.version ?? 0,
          'p_template': c.templatePayload(),
          'p_entry': c.existing != null
              ? null
              : {
                  'date': c.draft.date.toIso(),
                  'amount_centavos': c.draft.amount.toString(),
                },
        },
      ),
    };
