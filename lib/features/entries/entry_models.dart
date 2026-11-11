import '../../core/domain/calendar_date.dart';
import '../periods/period_service.dart';

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
  String get dateColumn => this == income ? 'received_on' : 'competence_on';
}

/// Receita ou despesa avulsa como o usuário a vê.
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
    this.periodId,
    this.isRecurring = false,
  });

  final String id;
  final EntryKind kind;
  final BigInt? amount;

  /// `received`/`pending`/`paid`/`cancelled`.
  final String status;

  /// Data de recebimento (receita) ou de cadastro/competência (despesa).
  final CalendarDate date;
  final int version;
  final String? description;
  final String? categoryId;
  final String? subcategoryId;
  final CalendarDate? dueOn;
  final CalendarDate? paidOn;
  final String? periodId;
  final bool isRecurring;

  bool get isCancelled => status == 'cancelled';
  bool get isPaid => status == 'paid';
  bool get isPendingExpense => kind == EntryKind.expense && status == 'pending';

  Map<String, dynamic> toSnapshot() => {
    'id': id,
    'status': status,
    'amount_centavos': amount?.toString(),
    kind.dateColumn: date.toIso(),
    'description': description,
    'category_id': categoryId,
    'subcategory_id': subcategoryId,
    'due_on': dueOn?.toIso(),
    'paid_on': paidOn?.toIso(),
    'accounting_period_id': periodId,
    'version': version,
  };
}

/// Dados que o usuário preenche ao criar ou editar.
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
  final BigInt amount;
  final CalendarDate date;
  final String? description;
  final String? categoryId;
  final String? subcategoryId;
  final CalendarDate? dueOn;

  Map<String, dynamic> toPayload() => {
    'amount_centavos': amount.toString(),
    kind.dateColumn: date.toIso(),
    'description': description,
    'category_id': categoryId,
    'subcategory_id': subcategoryId,
    if (kind == EntryKind.expense) 'due_on': dueOn?.toIso(),
  };
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

class CancelEntry extends EntryChange {
  const CancelEntry(this.current);
  final EntryRecord current;
}

/// Chamada ao servidor equivalente a uma [EntryChange].
class EntryRpcCall {
  const EntryRpcCall({
    required this.kind,
    required this.entityId,
    required this.action,
    required this.expectedVersion,
    required this.payload,
  });

  final EntryKind kind;
  final String entityId;

  /// `create`, `update`, `pay` ou `cancel`.
  final String action;
  final int expectedVersion;
  final Map<String, dynamic>? payload;

  String get rpc => kind.rpc;

  Map<String, dynamic> get params => {
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
    payload: draft.toPayload(),
  ),
  PayExpense(:final current, :final paidOn) => EntryRpcCall(
    kind: EntryKind.expense,
    entityId: current.id,
    action: 'pay',
    expectedVersion: current.version,
    payload: {'paid_on': paidOn.toIso()},
  ),
  CancelEntry(:final current) => EntryRpcCall(
    kind: current.kind,
    entityId: current.id,
    action: 'cancel',
    expectedVersion: current.version,
    payload: null,
  ),
};

/// Falta o período da data do lançamento: o usuário precisa confirmar a
/// criação dos períodos antes de salvar (RN002).
class PeriodMissingException implements Exception {
  const PeriodMissingException(this.date, this.plan);
  final CalendarDate date;
  final PeriodPlan plan;
  @override
  String toString() => 'Não existe período para ${date.toBr()}.';
}
