import '../../core/domain/calendar_date.dart';
import '../../core/domain/recurrence_schedule.dart';

enum EntryKind {
  income('income_entry', 'Receita'),
  expense('expense_entry', 'Despesa');

  const EntryKind(this.entityType, this.label);
  final String entityType;
  final String label;

  String get table => this == income ? 'income_entries' : 'expense_entries';
  String get categoryKind => this == income ? 'income' : 'expense';
  String get rpc => this == income
      ? 'apply_income_entry_change'
      : 'apply_expense_entry_change';
  String get occurrenceRpc => this == income
      ? 'apply_income_recurrence_occurrence_change'
      : 'apply_expense_recurrence_occurrence_change';
  String get templateTable => this == income
      ? 'income_recurrence_templates'
      : 'expense_recurrence_templates';
  String get templateEntityType => this == income
      ? 'income_recurrence_template'
      : 'expense_recurrence_template';
  String get templateRpc => this == income
      ? 'apply_income_recurrence_template_change'
      : 'apply_expense_recurrence_template_change';
  String get dateColumn => this == income ? 'received_on' : 'competence_on';
  String get wireKind => this == income ? 'income' : 'expense';
}

/// Receita ou despesa como o usuário a vê (avulsa ou ocorrência recorrente).
class EntryRecord {
  const EntryRecord({
    required this.id,
    required this.kind,
    required this.amount,
    required this.status,
    required this.date,
    required this.version,
    this.description,
    this.categoryId,
    this.subcategoryId,
    this.dueOn,
    this.paidOn,
    this.templateId,
    this.scheduledFor,
  });

  final String id;
  final EntryKind kind;
  final BigInt? amount;

  /// `received`/`pending`/`paid`/`cancelled`.
  final String status;

  /// Data de recebimento (receita) ou de cadastro/competência (despesa). Na
  /// receita recorrente ainda pendente é a data programada.
  final CalendarDate date;
  final int version;
  final String? description;
  final String? categoryId;
  final String? subcategoryId;
  final CalendarDate? dueOn;
  final CalendarDate? paidOn;

  /// Modelo recorrente de que esta ocorrência vem (`null` = lançamento avulso).
  final String? templateId;
  final CalendarDate? scheduledFor;

  bool get isRecurring => templateId != null;
  bool get isCancelled => status == 'cancelled';
  bool get isPaid => status == 'paid';
  bool get isPendingExpense => kind == EntryKind.expense && status == 'pending';
  bool get isPendingIncome => kind == EntryKind.income && status == 'pending';

  EntryRecord copyWith({int? version}) => EntryRecord(
    id: id,
    kind: kind,
    amount: amount,
    status: status,
    date: date,
    version: version ?? this.version,
    description: description,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    dueOn: dueOn,
    paidOn: paidOn,
    templateId: templateId,
    scheduledFor: scheduledFor,
  );

  Map<String, dynamic> toSnapshot() => {
    'id': id,
    'status': status,
    'amount_centavos': amount?.toString(),
    if (!isPendingIncome) kind.dateColumn: date.toIso(),
    'description': description,
    'category_id': categoryId,
    'subcategory_id': subcategoryId,
    'due_on': dueOn?.toIso(),
    'paid_on': paidOn?.toIso(),
    'recurrence_template_id': templateId,
    'scheduled_for_date': scheduledFor?.toIso(),
    'version': version,
  };
}

/// Dados que o usuário preenche ao criar ou editar. O valor só pode faltar
/// em ocorrência de valor variável (informado depois).
class EntryDraft {
  const EntryDraft({
    required this.kind,
    required this.amount,
    required this.date,
    this.description,
    this.categoryId,
    this.subcategoryId,
    this.dueOn,
  });

  final EntryKind kind;
  final BigInt? amount;
  final CalendarDate date;
  final String? description;
  final String? categoryId;
  final String? subcategoryId;
  final CalendarDate? dueOn;

  Map<String, dynamic> toPayload({bool includeDate = true}) => {
    'amount_centavos': amount?.toString(),
    if (includeDate) kind.dateColumn: date.toIso(),
    'description': description,
    'category_id': categoryId,
    'subcategory_id': subcategoryId,
    if (kind == EntryKind.expense) 'due_on': dueOn?.toIso(),
  };
}

/// O que o usuário escolheu em "Repetir" (D8).
class RepeatChoice {
  const RepeatChoice({required this.frequency, this.variableValue = false});

  final RecurrenceFrequency frequency;

  /// Valor muda a cada ocorrência (fatura do cartão, conta de luz…).
  final bool variableValue;
}

sealed class EntryChange {
  const EntryChange();
}

class CreateEntry extends EntryChange {
  const CreateEntry(this.id, this.draft);
  final String id;
  final EntryDraft draft;
}

class UpdateEntry extends EntryChange {
  const UpdateEntry(this.current, this.draft);
  final EntryRecord current;
  final EntryDraft draft;
}

class PayExpense extends EntryChange {
  const PayExpense(this.current, this.paidOn);
  final EntryRecord current;
  final CalendarDate paidOn;
}

/// Confirma o recebimento de uma receita recorrente (RN011–RN012).
class ReceiveIncome extends EntryChange {
  const ReceiveIncome(this.current, this.receivedOn, {this.amount});
  final EntryRecord current;
  final CalendarDate receivedOn;

  /// Valor informado na confirmação (receita variável); `null` mantém o atual.
  final BigInt? amount;
}

class CancelEntry extends EntryChange {
  const CancelEntry(this.current);
  final EntryRecord current;
}

/// Cria o modelo recorrente e faz o lançamento ser a primeira ocorrência (D8).
/// [existing] é o lançamento avulso que está sendo convertido (`null` = novo).
class CreateRecurrence extends EntryChange {
  const CreateRecurrence({
    required this.templateId,
    required this.entryId,
    required this.draft,
    required this.choice,
    required this.scheduledFor,
    this.existing,
  });

  final String templateId;
  final String entryId;
  final EntryDraft draft;
  final RepeatChoice choice;

  /// Data programada da primeira ocorrência: a data do lançamento (D8).
  final CalendarDate scheduledFor;
  final EntryRecord? existing;

  EntryKind get kind => draft.kind;
  RecurrenceFrequency get frequency => choice.frequency;
  bool get isMonthly => frequency == RecurrenceFrequency.monthly;

  /// Valor padrão do modelo: o do lançamento, se fixo.
  BigInt? get defaultAmount => choice.variableValue ? null : draft.amount;

  Map<String, dynamic> templatePayload() => {
    'description': draft.description,
    'frequency': frequency.dbValue,
    'starts_on': draft.date.toIso(),
    'monthly_reference_day': isMonthly ? draft.date.day : null,
    'value_mode': choice.variableValue ? 'variable' : 'fixed',
    'default_amount_centavos': defaultAmount?.toString(),
    'category_id': draft.categoryId,
    'subcategory_id': draft.subcategoryId,
  };
}

/// Chamada ao servidor equivalente a uma [EntryChange].
class EntryRpcCall {
  const EntryRpcCall({
    required this.kind,
    required this.entityId,
    required this.action,
    required this.expectedVersion,
    required this.payload,
    this.rpcName,
    this.extraParams,
  });

  final EntryKind kind;
  final String entityId;

  /// `create`, `update`, `pay`, `receive` ou `cancel`.
  final String action;
  final int expectedVersion;
  final Map<String, dynamic>? payload;

  /// RPC diferente das de lançamento/ocorrência (criação da recorrência).
  final String? rpcName;
  final Map<String, dynamic>? extraParams;

  String get rpc => rpcName ?? kind.rpc;

  Map<String, dynamic> get params =>
      extraParams ??
      {
        'p_action': action,
        'p_entry_id': entityId,
        'p_expected_version': expectedVersion,
        'p_payload': payload,
      };
}

EntryRpcCall entryRpcCallFor(EntryChange change) => switch (change) {
  CreateEntry(:final id, :final draft) => EntryRpcCall(
    kind: draft.kind,
    entityId: id,
    action: 'create',
    expectedVersion: 0,
    payload: draft.toPayload(),
  ),
  UpdateEntry(:final current, :final draft) => EntryRpcCall(
    kind: current.kind,
    entityId: current.id,
    action: 'update',
    expectedVersion: current.version,
    payload: draft.toPayload(includeDate: !current.isPendingIncome),
    rpcName: current.isRecurring ? current.kind.occurrenceRpc : null,
  ),
  PayExpense(:final current, :final paidOn) => EntryRpcCall(
    kind: EntryKind.expense,
    entityId: current.id,
    action: 'pay',
    expectedVersion: current.version,
    payload: {'paid_on': paidOn.toIso()},
    rpcName: current.isRecurring ? current.kind.occurrenceRpc : null,
  ),
  ReceiveIncome(:final current, :final receivedOn, :final amount) =>
    EntryRpcCall(
      kind: EntryKind.income,
      entityId: current.id,
      action: 'receive',
      expectedVersion: current.version,
      payload: {
        'received_on': receivedOn.toIso(),
        if (amount != null) 'amount_centavos': amount.toString(),
      },
      rpcName: current.kind.occurrenceRpc,
    ),
  CancelEntry(:final current) => EntryRpcCall(
    kind: current.kind,
    entityId: current.id,
    action: 'cancel',
    expectedVersion: current.version,
    payload: null,
    rpcName: current.isRecurring ? current.kind.occurrenceRpc : null,
  ),
  final CreateRecurrence c => EntryRpcCall(
    kind: c.kind,
    entityId: c.entryId,
    action: c.existing == null ? 'create' : 'update',
    expectedVersion: c.existing?.version ?? 0,
    payload: null,
    rpcName: 'create_recurrence_from_entry',
    extraParams: {
      'p_kind': c.kind.wireKind,
      'p_template_id': c.templateId,
      'p_entry_id': c.entryId,
      'p_expected_entry_version': c.existing?.version ?? 0,
      'p_template': c.templatePayload(),
      'p_entry': c.existing != null
          ? null
          : {
              'date': c.draft.date.toIso(),
              'amount_centavos': c.draft.amount?.toString(),
              'description': c.draft.description,
              'category_id': c.draft.categoryId,
              'subcategory_id': c.draft.subcategoryId,
              if (c.kind == EntryKind.expense) 'due_on': c.draft.dueOn?.toIso(),
            },
    },
  ),
};
