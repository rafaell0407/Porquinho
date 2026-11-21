/// Valores em centavos lidos direto das tabelas do servidor chegam exatos
/// (RN045; T8).
///
/// O PostgREST devolve `BIGINT` como número JSON. No celular o Dart lê inteiro
/// de 64 bits, exato; na Web o navegador converte para ponto flutuante antes
/// de o Dart ver o valor, e acima de 2^53 (≈ R$ 90 trilhões) o número muda.
/// Por isso as colunas de dinheiro sem teto abaixo de 2^53 são pedidas também
/// como texto (`::text`, com apelido) e o texto substitui o número na linha.
/// Tabelas com teto menor (faturas, importação) não precisam.
library;

/// Tabela → colunas `BIGINT` de dinheiro que aceitam até 2^63 − 1.
const exactMoneyColumns = <String, List<String>>{
  'income_entries': ['amount_centavos'],
  'expense_entries': ['amount_centavos'],
  'investment_allocations': ['amount_centavos'],
  'income_recurrence_templates': ['default_amount_centavos'],
  'expense_recurrence_templates': ['default_amount_centavos'],
  'investment_recurrence_templates': ['default_amount_centavos'],
};

/// Campos de dinheiro dentro do retrato do servidor de um conflito
/// (`sync_conflicts.remote_snapshot`, gravado com `to_jsonb`).
const _snapshotMoneyFields = ['amount_centavos', 'default_amount_centavos'];

const _prefix = 'exact_text__';
const _snapshotPrefix = 'exact_snapshot__';

/// Texto do `select` que traz todas as colunas mais as de dinheiro em texto.
String exactSelect(String table) {
  final columns = exactMoneyColumns[table];
  if (table == 'sync_conflicts') {
    return [
      '*',
      for (final f in _snapshotMoneyFields)
        '$_snapshotPrefix$f:remote_snapshot->>$f',
    ].join(',');
  }
  if (columns == null) return '*';
  return ['*', for (final c in columns) '$_prefix$c:$c::text'].join(',');
}

/// Troca o número pelo texto exato e remove os apelidos da linha.
Map<String, dynamic> applyExactMoney(String table, Map<String, dynamic> row) {
  final result = Map<String, dynamic>.from(row);
  if (table == 'sync_conflicts') {
    final snapshot = result['remote_snapshot'];
    final exact = Map<String, dynamic>.from(snapshot is Map ? snapshot : {});
    for (final f in _snapshotMoneyFields) {
      final text = result.remove('$_snapshotPrefix$f');
      if (text != null && exact.containsKey(f)) exact[f] = text;
    }
    if (snapshot is Map) result['remote_snapshot'] = exact;
    return result;
  }
  for (final c in exactMoneyColumns[table] ?? const <String>[]) {
    final key = '$_prefix$c';
    if (result.containsKey(key)) result[c] = result.remove(key);
  }
  return result;
}
