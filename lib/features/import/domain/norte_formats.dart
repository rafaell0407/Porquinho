/// Arquivos exportados pelo próprio Norte (`csv_export.dart`): reconhecidos
/// pelo cabeçalho exato. Com eles, colunas, formato de valor (centavos) e de
/// data (ISO) vêm associados; o usuário só confirma.
enum NorteFileKind {
  incomes('Receitas do Norte', [
    'id',
    'descricao',
    'valor_centavos',
    'status',
    'data_recebimento',
    'categoria',
    'subcategoria',
    'recorrente',
    'data_prevista',
    'criado_em',
    'atualizado_em',
  ]),
  expenses('Despesas do Norte', [
    'id',
    'descricao',
    'valor_centavos',
    'status',
    'data_competencia',
    'vencimento',
    'data_pagamento',
    'categoria',
    'subcategoria',
    'recorrente',
    'data_prevista',
    'criado_em',
    'atualizado_em',
  ]),
  investments('Investimentos do Norte', [
    'id',
    'valor_centavos',
    'data',
    'status',
    'recorrente',
    'data_prevista',
    'criado_em',
    'atualizado_em',
  ]),
  categories('Categorias do Norte', [
    'id',
    'tipo',
    'nome',
    'ativa',
    'categoria_pai_id',
    'categoria_pai',
  ]);

  const NorteFileKind(this.label, this.header);
  final String label;
  final List<String> header;
}

/// Tipo do arquivo do Norte pelo cabeçalho exato; `null` = outra origem.
NorteFileKind? recognizeNorteFile(List<String> header) {
  for (final kind in NorteFileKind.values) {
    if (header.length != kind.header.length) continue;
    var same = true;
    for (var i = 0; i < header.length; i++) {
      if (header[i] != kind.header[i]) {
        same = false;
        break;
      }
    }
    if (same) return kind;
  }
  return null;
}

/// A exportação do Norte prefixa apóstrofo em textos que começam com
/// `= + - @`, tab ou CR (proteção contra fórmula de planilha). Na importação
/// de arquivo do Norte, o apóstrofo é removido só nesse caso; em arquivo de
/// outra origem, nada é removido.
String unguardNorteText(String value) {
  if (value.length >= 2 &&
      value.startsWith("'") &&
      '=+-@\t\r'.contains(value[1])) {
    return value.substring(1);
  }
  return value;
}
