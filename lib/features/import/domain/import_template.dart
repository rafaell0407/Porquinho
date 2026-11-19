/// Arquivo modelo da importação (RF030): um CSV misto que o assistente lê
/// sem ajustes de leitura. Cabeçalhos com os nomes que `suggestColumns`
/// reconhece, separador `;` e UTF-8 com BOM (abre certo no Excel em
/// português), valor em reais com vírgula e data DD/MM/AAAA (há dia > 12,
/// então o formato não fica ambíguo). As linhas são só exemplos.
abstract final class ImportTemplate {
  static const fileName = 'modelo_importacao_norte.csv';

  static const header = [
    'tipo',
    'data',
    'descricao',
    'valor',
    'categoria',
    'subcategoria',
    'situacao',
    'vencimento',
    'data_pagamento',
  ];

  static const rows = [
    [
      'Receita',
      '05/10/2026',
      'Salário',
      '4.500,00',
      'Salário',
      '',
      'Recebida',
      '',
      '',
    ],
    [
      'Despesa',
      '10/10/2026',
      'Aluguel',
      '1.800,00',
      'Moradia',
      '',
      'Paga',
      '10/10/2026',
      '10/10/2026',
    ],
    [
      'Despesa',
      '14/10/2026',
      'Supermercado',
      '612,35',
      'Alimentação',
      'Mercado',
      'Paga',
      '',
      '14/10/2026',
    ],
    [
      'Despesa',
      '20/10/2026',
      'Conta de luz',
      '189,90',
      'Moradia',
      'Energia',
      'Pendente',
      '25/10/2026',
      '',
    ],
    ['Investimento', '15/10/2026', '', '500,00', '', '', '', '', ''],
  ];

  static const _bom = '\u{FEFF}';

  /// Conteúdo do arquivo (com BOM, `\r\n`).
  static String content() {
    final out = StringBuffer(_bom)..write('${header.join(';')}\r\n');
    for (final r in rows) {
      out.write('${r.join(';')}\r\n');
    }
    return out.toString();
  }
}
