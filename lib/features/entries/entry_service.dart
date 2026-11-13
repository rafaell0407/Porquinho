import '../../core/domain/calendar_date.dart';
import '../../core/domain/period_calendar.dart';
import '../../core/domain/recurrence_schedule.dart';
import '../categories/category_models.dart';
import '../categories/category_repository.dart';
import '../recurrence/recurrence_repository.dart';
import '../sync/sync_models.dart';
import 'entry_models.dart';
import 'entry_repository.dart';

/// Regras de receitas e despesas, avulsas e recorrentes (RN004–RN008, RN011,
/// RN015, `CLAUDE.md` §4.4–4.5). As mesmas validações da RPC, para que o que
/// for salvo no aparelho não seja recusado depois.
class EntryService {
  EntryService(
    this._entries,
    this._categories, {
    RecurrenceRepository? recurrences,
    String Function()? newId,
  }) : _recurrences = recurrences,
       _newId = newId ?? newUuid;

  final EntryRepository _entries;
  final CategoryRepository _categories;
  final RecurrenceRepository? _recurrences;
  final String Function() _newId;

  static const maxDescriptionLength = 120;

  Future<List<EntryRecord>> entriesInPeriod(PeriodRange range) =>
      _entries.entriesInPeriod(range);

  /// Cadastra uma receita ou despesa.
  ///
  /// - [alreadyPaid] (só despesa, decisão D10) grava o cadastro e o pagamento
  ///   na mesma operação local; o pagamento usa [paidOn] ou a data de hoje.
  /// - [repeat] (D8) cria também a recorrência: o lançamento é a primeira
  ///   ocorrência. A receita recorrente nasce pendente; [alreadyReceived]
  ///   confirma o recebimento na hora, em [receivedOn].
  Future<String> create(
    EntryDraft draft, {
    bool alreadyPaid = false,
    CalendarDate? paidOn,
    CalendarDate? today,
    RepeatChoice? repeat,
    bool alreadyReceived = false,
    CalendarDate? receivedOn,
  }) async {
    final clean = await _validated(
      draft,
      amountOptional: repeat?.variableValue ?? false,
    );
    if (alreadyPaid && clean.kind != EntryKind.expense) {
      throw const ChangeRejectedException(
        'Só despesas podem ser cadastradas como pagas.',
      );
    }
    if (alreadyReceived && (clean.kind != EntryKind.income || repeat == null)) {
      throw const ChangeRejectedException(
        'Só uma receita recorrente pode ser criada já recebida.',
      );
    }
    final changes = <EntryChange>[];
    late final String id;
    if (repeat == null) {
      id = _newId();
      changes.add(CreateEntry(id, clean));
    } else {
      final recurrence = _recurrenceFor(clean, repeat, null);
      id = recurrence.entryId;
      changes.add(recurrence);
    }
    if (alreadyPaid) {
      final when = paidOn ?? today;
      if (when == null) {
        throw const ChangeRejectedException('Informe a data do pagamento.');
      }
      if (repeat == null) {
        changes.add(PayExpense(_pendingRecord(id, clean), when));
      } else {
        if (clean.amount == null) {
          throw const ChangeRejectedException(
            'Informe o valor da despesa antes de pagar.',
          );
        }
        changes.add(
          PayExpense(_firstOccurrence(changes.first as CreateRecurrence), when),
        );
      }
    }
    if (alreadyReceived) {
      final when = receivedOn ?? today;
      if (when == null) {
        throw const ChangeRejectedException('Informe a data do recebimento.');
      }
      if (clean.amount == null) {
        throw const ChangeRejectedException(
          'Informe o valor da receita antes de confirmar o recebimento.',
        );
      }
      changes.add(
        ReceiveIncome(
          _firstOccurrence(changes.first as CreateRecurrence),
          when,
        ),
      );
    }
    await _entries.apply(changes);
    return id;
  }

  EntryRecord _pendingRecord(String id, EntryDraft clean) => EntryRecord(
    id: id,
    kind: EntryKind.expense,
    amount: clean.amount,
    status: 'pending',
    date: clean.date,
    version: 1,
    description: clean.description,
    categoryId: clean.categoryId,
    subcategoryId: clean.subcategoryId,
    dueOn: clean.dueOn,
  );

  /// A primeira ocorrência como ficará após [CreateRecurrence] (versão 1).
  EntryRecord _firstOccurrence(CreateRecurrence c) => EntryRecord(
    id: c.entryId,
    kind: c.kind,
    amount: c.choice.variableValue ? c.draft.amount : c.defaultAmount,
    status: 'pending',
    date: c.scheduledFor,
    version: 1,
    description: c.draft.description,
    categoryId: c.draft.categoryId,
    subcategoryId: c.draft.subcategoryId,
    dueOn: c.kind == EntryKind.expense
        ? (c.draft.dueOn ?? c.scheduledFor)
        : null,
    templateId: c.templateId,
    scheduledFor: c.scheduledFor,
  );

  CreateRecurrence _recurrenceFor(
    EntryDraft clean,
    RepeatChoice repeat,
    EntryRecord? existing,
  ) {
    if (repeat.frequency != RecurrenceFrequency.monthly) {
      throw const ChangeRejectedException('A repetição é só "Todo mês".');
    }
    final templateId = _newId();
    // O próprio lançamento é a primeira ocorrência (D8).
    final scheduled = clean.date;
    return CreateRecurrence(
      templateId: templateId,
      entryId:
          existing?.id ??
          RecurrenceCalendar.occurrenceId(templateId, scheduled),
      draft: clean,
      choice: repeat,
      scheduledFor: scheduled,
      existing: existing,
    );
  }

  /// Edita qualquer lançamento não cancelado, mesmo pago ou recebido. Mudar a
  /// data move o valor para o período da nova data. Em ocorrência recorrente,
  /// altera só esta ocorrência (o modelo e as demais não mudam). Em lançamento
  /// avulso, [repeat] o transforma na primeira ocorrência de uma recorrência.
  Future<void> update(
    EntryRecord current,
    EntryDraft draft, {
    RepeatChoice? repeat,
  }) async {
    _requireEditable(current);
    if (draft.kind != current.kind) {
      throw const ChangeRejectedException('O tipo do lançamento não muda.');
    }
    if (repeat != null && current.isRecurring) {
      throw const ChangeRejectedException('Este lançamento já se repete.');
    }
    final optional = await _amountOptionalFor(current, repeat);
    final clean = await _validated(
      draft,
      current: current,
      amountOptional: optional,
    );
    if (current.isPendingIncome) {
      // Receita recorrente pendente: a data programada não muda.
      await _entries.apply([
        UpdateEntry(
          current,
          EntryDraft(
            kind: clean.kind,
            amount: clean.amount,
            date: current.date,
            description: clean.description,
            categoryId: clean.categoryId,
            subcategoryId: clean.subcategoryId,
          ),
        ),
      ]);
      return;
    }
    if (current.isRecurring &&
        current.status != 'pending' &&
        clean.amount == null) {
      throw const ChangeRejectedException('Informe o valor do lançamento.');
    }
    final changes = <EntryChange>[UpdateEntry(current, clean)];
    if (repeat != null) {
      changes.add(
        _recurrenceFor(
          clean,
          repeat,
          current.copyWith(version: current.version + 1),
        ),
      );
    }
    await _entries.apply(changes);
  }

  Future<bool> _amountOptionalFor(
    EntryRecord current,
    RepeatChoice? repeat,
  ) async {
    if (repeat != null) return repeat.variableValue;
    final id = current.templateId;
    if (id == null || _recurrences == null) return false;
    final template = await _recurrences.template(current.kind, id);
    return template?.variableValue ?? false;
  }

  /// Marca a despesa como paga: registra a data e **não** altera a sobra.
  /// Pagar de novo corrige a data do pagamento (decisão de 10/11/2026).
  Future<void> pay(EntryRecord current, CalendarDate paidOn) async {
    if (current.kind != EntryKind.expense) {
      throw const ChangeRejectedException('Só despesas podem ser pagas.');
    }
    _requireEditable(current);
    if (current.amount == null) {
      throw const ChangeRejectedException(
        'Informe o valor da despesa antes de pagar.',
      );
    }
    await _entries.apply([PayExpense(current, paidOn)]);
  }

  /// Confirma o recebimento de uma receita recorrente: ela passa a entrar na
  /// sobra, uma única vez, no período da data de recebimento (RN011–RN012).
  Future<void> receive(
    EntryRecord current,
    CalendarDate receivedOn, {
    BigInt? amount,
  }) async {
    if (current.kind != EntryKind.income || !current.isRecurring) {
      throw const ChangeRejectedException(
        'Só receitas recorrentes têm confirmação de recebimento.',
      );
    }
    _requireEditable(current);
    if (current.status != 'pending') {
      throw const ChangeRejectedException('Esta receita já foi recebida.');
    }
    final value = amount ?? current.amount;
    if (value == null) {
      throw const ChangeRejectedException(
        'Informe o valor recebido para confirmar o recebimento.',
      );
    }
    if (value.isNegative) {
      throw const ChangeRejectedException('O valor não pode ser negativo.');
    }
    await _entries.apply([ReceiveIncome(current, receivedOn, amount: value)]);
  }

  /// Cancela: sai da sobra, mas continua no histórico. Não há desfazer no MVP.
  Future<void> cancel(EntryRecord current) async {
    _requireEditable(current);
    await _entries.apply([CancelEntry(current)]);
  }

  void _requireEditable(EntryRecord current) {
    if (current.isCancelled) {
      throw const ChangeRejectedException(
        'Este lançamento está cancelado e não pode mais ser alterado.',
      );
    }
  }

  Future<EntryDraft> _validated(
    EntryDraft d, {
    EntryRecord? current,
    bool amountOptional = false,
  }) async {
    if (d.amount == null && !amountOptional) {
      throw const ChangeRejectedException('Informe o valor.');
    }
    if (d.amount?.isNegative ?? false) {
      throw const ChangeRejectedException('O valor não pode ser negativo.');
    }
    final description = d.description?.trim();
    if (description != null && description.length > maxDescriptionLength) {
      throw const ChangeRejectedException(
        'A descrição aceita até $maxDescriptionLength caracteres.',
      );
    }
    if (d.kind == EntryKind.income && d.dueOn != null) {
      throw const ChangeRejectedException('Receita não tem vencimento.');
    }
    if (d.subcategoryId != null && d.categoryId == null) {
      throw const ChangeRejectedException(
        'Escolha a categoria da subcategoria.',
      );
    }
    final categories = await _categories.categories();
    final subs = await _categories.subcategories();
    // Como a RPC: só a categoria/subcategoria NOVA precisa estar ativa; um
    // lançamento antigo pode manter a que foi desativada depois.
    if (d.categoryId != null) {
      final cat = categories.where((c) => c.id == d.categoryId).firstOrNull;
      if (cat == null) {
        throw const ChangeRejectedException('Categoria não encontrada.');
      }
      if (cat.kind.dbValue != d.kind.categoryKind) {
        throw const ChangeRejectedException(
          'A categoria precisa ser do mesmo tipo do lançamento.',
        );
      }
      if (d.categoryId != current?.categoryId && !cat.isActive) {
        throw const ChangeRejectedException('A categoria está desativada.');
      }
    }
    if (d.subcategoryId != null) {
      final sub = subs.where((s) => s.id == d.subcategoryId).firstOrNull;
      if (sub == null || sub.categoryId != d.categoryId) {
        throw const ChangeRejectedException(
          'A subcategoria não pertence à categoria escolhida.',
        );
      }
      final changed =
          d.categoryId != current?.categoryId ||
          d.subcategoryId != current?.subcategoryId;
      if (changed && !sub.isActive) {
        throw const ChangeRejectedException('A subcategoria está desativada.');
      }
    }
    return EntryDraft(
      kind: d.kind,
      amount: d.amount,
      date: d.date,
      description: (description == null || description.isEmpty)
          ? null
          : description,
      categoryId: d.categoryId,
      subcategoryId: d.subcategoryId,
      dueOn: d.dueOn,
    );
  }
}
