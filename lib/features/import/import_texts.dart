import '../../core/domain/money.dart';
import 'data/import_batch.dart';
import 'domain/import_models.dart';

/// Textos da importação (RF030).
abstract final class ImportTexts {
  static const title = 'Importar dados (CSV)';
  static const webOnly =
      'A importação de CSV está disponível na versão Web do Norte. Entre '
      'pelo navegador com a mesma conta para trazer seus lançamentos.';
  static const intro =
      'Traga lançamentos de uma planilha, de um extrato ou de uma exportação '
      'do Norte. Um arquivo CSV por importação. O arquivo é lido só no seu '
      'navegador e nada é gravado antes da sua confirmação.';
  static const processingHint =
      'Não feche esta aba. Se fechar, a importação fica interrompida e pode '
      'ser retomada escolhendo o mesmo arquivo.';

  static String batchStatus(ImportBatchStatus s) => s.label;

  static String kindPlural(RowKind k) => switch (k) {
    RowKind.income => 'receitas',
    RowKind.expense => 'despesas',
    RowKind.investment => 'investimentos',
    RowKind.category => 'categorias',
  };

  static String money(BigInt? v) => v == null ? 'sem valor' : formatBrl(v);

  static String date(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:'
        '${two(l.minute)}';
  }

  static String entityLabel(String entityType, String role) {
    if (role == 'template') return 'Recorrência';
    if (role == 'category') return 'Categoria';
    if (role == 'subcategory') return 'Subcategoria';
    final kind = switch (entityType) {
      'income_entry' => 'Receita',
      'expense_entry' => 'Despesa',
      _ => 'Investimento',
    };
    return switch (role) {
      'anchor' => '$kind (início da recorrência)',
      'occurrence' => '$kind (ocorrência gerada)',
      _ => kind,
    };
  }
}
