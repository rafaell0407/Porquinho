import '../../core/domain/calendar_date.dart';
import '../categories/category_models.dart';
import '../categories/category_repository.dart';
import '../periods/period_service.dart';
import '../sync/sync_models.dart';
import 'entry_models.dart';
import 'entry_repository.dart';

/// Regras de receitas e despesas avulsas (RN004–RN008, RN015, `AGENTS.md`
/// §4.3–4.4). As mesmas validações da RPC, para que o que for salvo no
/// aparelho não seja recusado depois.
class EntryService {
  EntryService(
    this._entries,
    this._categories,
    this._periods, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final EntryRepository _entries;
  final CategoryRepository _categories;
  final PeriodService _periods;
  final String Function() _newId;

  static const maxDescriptionLength = 120;

  Future<List<EntryRecord>> entriesInPeriod(String periodId) =>
      _entries.entriesInPeriod(periodId);

  /// Cadastra uma receita ou despesa. [alreadyPaid] (só despesa, decisão D10)
  /// grava o cadastro e o pagamento na mesma operação local, com dois eventos
  /// de auditoria; o pagamento usa [paidOn] ou, se ausente, a data de hoje.
  Future<String> create(
    EntryDraft draft, {
    bool alreadyPaid = false,
    CalendarDate? paidOn,
    CalendarDate? today,
  }) async {
    final clean = await _validated(draft);
    await _requirePeriod(clean.date);
    final id = _newId();
    final changes = <EntryChange>[CreateEntry(id, clean)];
    if (alreadyPaid) {
      if (clean.kind != EntryKind.expense) {
        throw const ChangeRejectedException(
          'Só despesas podem ser cadastradas como pagas.',
        );
      }
      final when = paidOn ?? today;
      if (when == null) {
        throw const ChangeRejectedException('Informe a data do pagamento.');
      }
      changes.add(
        PayExpense(
          EntryRecord(
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
          ),
          when,
        ),
      );
    }
    await _entries.apply(changes);
    return id;
  }

  /// Edita qualquer lançamento não cancelado, mesmo pago ou recebido. Mudar a
  /// data move o valor para o período da nova data.
  Future<void> update(EntryRecord current, EntryDraft draft) async {
    _requireEditable(current);
    if (draft.kind != current.kind) {
      throw const ChangeRejectedException('O tipo do lançamento não muda.');
    }
    final clean = await _validated(draft, current: current);
    if (clean.date != current.date) await _requirePeriod(clean.date);
    await _entries.apply([UpdateEntry(current, clean)]);
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

  /// Pergunta ao usuário (via exceção) quando o período da data não existe.
  Future<void> _requirePeriod(CalendarDate date) async {
    final plan = await _periods.planFor(date);
    if (plan != null) throw PeriodMissingException(date, plan);
  }

  /// Cria os períodos faltantes depois da confirmação do usuário.
  Future<void> createMissingPeriods(CalendarDate date) =>
      _periods.createCovering(date);

  Future<EntryDraft> _validated(EntryDraft d, {EntryRecord? current}) async {
    if (d.amount.isNegative) {
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
