import 'package:flutter/material.dart';

import '../../../app/theme/norte_theme.dart';
import '../application/import_controller.dart';
import '../data/picked_file.dart';
import '../domain/category_resolution.dart';
import '../domain/column_mapping.dart';
import '../domain/csv_reader.dart';
import '../domain/date_parsing.dart';
import '../domain/import_models.dart';
import '../domain/text_decoding.dart';
import '../domain/value_parsing.dart';

/// Etapas 2–5 do assistente: arquivo, colunas, classificação e categorias.

Widget sectionTitle(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 8),
  child: Text(text, style: Theme.of(context).textTheme.titleMedium),
);

Widget noticeBox(BuildContext context, String text, {Key? key}) {
  final colors = NorteColors.of(context);
  return Container(
    key: key,
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.pendingBackground,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
}

String _kb(int bytes) => bytes < 1024
    ? '$bytes bytes'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

List<Widget> fileStep(
  BuildContext context,
  ImportWizardController c,
  Future<PickedFile?> Function() pick,
) {
  final t = c.table;
  return [
    FilledButton.icon(
      key: const Key('importar-escolher-arquivo'),
      icon: const Icon(Icons.folder_open),
      label: Text(
        c.file == null ? 'Escolher arquivo CSV' : 'Escolher outro arquivo',
      ),
      onPressed: c.busy
          ? null
          : () async {
              final f = await pick();
              if (f != null) await c.loadFile(f);
            },
    ),
    if (c.file != null) ...[
      sectionTitle(context, c.file!.name),
      Text(
        'Tamanho: ${_kb(c.file!.bytes.length)} · codificação: ${c.encoding.label}',
      ),
      if (c.decodeFailure != null) ...[
        noticeBox(
          context,
          c.decodeFailure!,
          key: const Key('importar-erro-utf8'),
        ),
        if (c.encoding == ImportEncoding.utf8)
          OutlinedButton(
            key: const Key('importar-usar-1252'),
            onPressed: () => c.useEncoding(ImportEncoding.windows1252),
            child: const Text('Ler como Windows-1252'),
          ),
      ],
      if (t != null) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Separador: '),
            DropdownButton<CsvSeparator>(
              key: const Key('importar-separador'),
              value: c.separator,
              items: [
                for (final s in CsvSeparator.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (s) => s == null ? null : c.setSeparator(s),
            ),
          ],
        ),
        Text(
          '${t.records.length} linha(s) de dados, ${t.header.length} '
          'coluna(s)${t.emptyLines > 0 ? ', ${t.emptyLines} linha(s) vazia(s) ignorada(s)' : ''}.',
        ),
        if (c.norteKind != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              key: const Key('importar-arquivo-norte'),
              avatar: const Icon(Icons.verified_outlined, size: 18),
              label: Text('Arquivo do Norte: ${c.norteKind!.label}'),
            ),
          ),
        if (c.previousImport != null)
          noticeBox(
            context,
            'Este mesmo arquivo já foi importado (${c.previousImport!.fileName}) '
            'e não foi desfeito. Você decide na etapa Duplicidades.',
            key: const Key('importar-ja-importado'),
          ),
        if (t.header.isNotEmpty) ...[
          sectionTitle(context, 'Primeiras linhas'),
          _SampleTable(table: t),
        ],
      ],
    ],
  ];
}

class _SampleTable extends StatelessWidget {
  const _SampleTable({required this.table});
  final CsvTable table;

  @override
  Widget build(BuildContext context) {
    final rows = table.records.take(3).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        columns: [for (final h in table.header) DataColumn(label: Text(h))],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                for (var i = 0; i < table.header.length; i++)
                  DataCell(Text(i < r.fields.length ? r.fields[i] : '')),
              ],
            ),
        ],
      ),
    );
  }
}

List<Widget> columnsStep(BuildContext context, ImportWizardController c) {
  final t = c.table!;
  final byColumn = {for (final e in c.mapping.columns.entries) e.value: e.key};
  final norte = c.norteKind != null;
  final unused = [
    for (var i = 0; i < t.header.length; i++)
      if (!byColumn.containsKey(i)) t.header[i],
  ];
  return [
    Text(
      norte
          ? 'Arquivo do Norte: as colunas já vêm associadas. Confira e '
                'continue.'
          : 'Diga o que é cada coluna do arquivo. O que não for usado fica '
                'de fora.',
    ),
    sectionTitle(context, 'Colunas'),
    for (var i = 0; i < t.header.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.header[i].isEmpty ? '(sem nome)' : t.header[i],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    t.records.isNotEmpty && i < t.records.first.fields.length
                        ? 'Ex.: ${t.records.first.fields[i]}'
                        : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: DropdownButton<ImportField?>(
                key: Key('importar-coluna-$i'),
                isExpanded: true,
                value: byColumn[i],
                items: [
                  const DropdownMenuItem(value: null, child: Text('Não usar')),
                  for (final f in ImportField.values)
                    DropdownMenuItem(
                      value: f,
                      child: Text(f.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (f) {
                  final old = byColumn[i];
                  if (old != null) c.setColumn(old, null);
                  if (f != null) c.setColumn(f, i);
                },
              ),
            ),
          ],
        ),
      ),
    if (unused.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Colunas sem uso (ignoradas): ${unused.join(', ')}.'),
      ),
    if (c.mapping.column(ImportField.amount) != null) ...[
      sectionTitle(context, 'Formato do valor'),
      DropdownButton<ValueFormat?>(
        key: const Key('importar-formato-valor'),
        value: c.mapping.valueFormat,
        hint: const Text('Escolha (não deu para saber pelo arquivo)'),
        items: [
          for (final f in ValueFormat.values)
            DropdownMenuItem(
              value: f,
              child: Text('${f.label} (${f.example})'),
            ),
        ],
        onChanged: norte ? null : c.setValueFormat,
      ),
    ],
    if (ImportField.dateFields.any(c.mapping.columns.containsKey)) ...[
      sectionTitle(context, 'Formato da data'),
      DropdownButton<DateFormatKind?>(
        key: const Key('importar-formato-data'),
        value: c.mapping.dateFormat,
        hint: const Text('Escolha (dia e mês podem estar trocados)'),
        items: [
          for (final f in DateFormatKind.values)
            DropdownMenuItem(
              value: f,
              child: Text('${f.label} (${f.example})'),
            ),
        ],
        onChanged: norte ? null : c.setDateFormat,
      ),
    ],
  ];
}

const _ignoreKey = 'ignore';

List<Widget> classificationStep(
  BuildContext context,
  ImportWizardController c,
) {
  final m = c.mapping;
  final kindValues = c.distinctValues(ImportField.kind);
  final statusValues = c.distinctValues(ImportField.status);
  final hasExpenses =
      (m.typeSource == TypeSource.fixed && m.fixedKind == RowKind.expense) ||
      m.typeSource == TypeSource.sign ||
      (m.typeSource == TypeSource.column &&
          m.kindValues.values.contains(RowKind.expense));
  return [
    sectionTitle(context, 'Tipo das linhas'),
    RadioGroup<TypeSource>(
      groupValue: m.typeSource,
      onChanged: (v) => v == null ? null : c.setTypeSource(v),
      child: Column(
        children: [
          const RadioListTile(
            key: Key('importar-tipo-fixo'),
            value: TypeSource.fixed,
            title: Text('O arquivo inteiro é de um tipo'),
          ),
          if (m.typeSource == TypeSource.fixed)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<RowKind?>(
                  key: const Key('importar-tipo-arquivo'),
                  value: m.fixedKind,
                  hint: const Text('Escolha o tipo'),
                  items: [
                    for (final k in RowKind.values)
                      DropdownMenuItem(value: k, child: Text(k.label)),
                  ],
                  onChanged: c.norteKind != null ? null : c.setFixedKind,
                ),
              ),
            ),
          RadioListTile(
            key: const Key('importar-tipo-coluna'),
            value: TypeSource.column,
            enabled: m.column(ImportField.kind) != null,
            title: const Text('Uma coluna diz o tipo de cada linha'),
            subtitle: m.column(ImportField.kind) == null
                ? const Text(
                    'Associe a coluna "Tipo da linha" na etapa anterior.',
                  )
                : null,
          ),
          if (m.typeSource == TypeSource.column)
            for (final v in kindValues)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Row(
                  children: [
                    Expanded(child: Text(v.isEmpty ? '(vazio)' : '"$v"')),
                    DropdownButton<String>(
                      key: Key('importar-valor-tipo-$v'),
                      value: !m.kindValues.containsKey(v)
                          ? null
                          : (m.kindValues[v]?.key ?? _ignoreKey),
                      hint: const Text('Escolha'),
                      items: [
                        for (final k in RowKind.values)
                          DropdownMenuItem(value: k.key, child: Text(k.label)),
                        const DropdownMenuItem(
                          value: _ignoreKey,
                          child: Text('Ignorar a linha'),
                        ),
                      ],
                      onChanged: (k) => k == null
                          ? null
                          : c.setKindValue(
                              v,
                              k == _ignoreKey ? null : RowKind.fromKey(k),
                            ),
                    ),
                  ],
                ),
              ),
          const RadioListTile(
            key: Key('importar-tipo-sinal'),
            value: TypeSource.sign,
            title: Text('Pelo sinal do valor (extrato de banco)'),
            subtitle: Text(
              'Negativo vira despesa (valor sem o sinal) e positivo vira '
              'receita. Valor zero é rejeitado.',
            ),
          ),
        ],
      ),
    ),
    if (statusValues.isNotEmpty) ...[
      sectionTitle(context, 'Situação'),
      const Text(
        'Diga o que significa cada situação do arquivo. Canceladas não são '
        'importadas; pagamento parcial é rejeitado.',
      ),
      for (final v in statusValues)
        Row(
          children: [
            Expanded(child: Text(v.isEmpty ? '(vazio)' : '"$v"')),
            Flexible(
              child: DropdownButton<StatusMeaning>(
                key: Key('importar-situacao-$v'),
                isExpanded: true,
                value: m.statusValues[v],
                hint: const Text('Escolha'),
                items: [
                  for (final s in StatusMeaning.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(s.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (s) => s == null ? null : c.setStatusValue(v, s),
              ),
            ),
          ],
        ),
    ],
    if (hasExpenses && c.norteKind == null) ...[
      sectionTitle(context, 'Despesas'),
      SwitchListTile(
        key: const Key('importar-marcar-pagas'),
        contentPadding: EdgeInsets.zero,
        value: m.markExpensesPaid,
        onChanged: c.setMarkExpensesPaid,
        title: const Text('Marcar as despesas como pagas'),
        subtitle: const Text(
          'Sem isso, elas entram pendentes (contam no dinheiro livre do mesmo '
          'jeito). Despesas com situação "pendente" continuam pendentes.',
        ),
      ),
      if (m.markExpensesPaid)
        RadioGroup<PaidDateSource>(
          groupValue: m.paidDateSource,
          onChanged: (v) => v == null ? null : c.setPaidDateSource(v),
          child: const Column(
            children: [
              RadioListTile(
                value: PaidDateSource.entryDate,
                title: Text('Data do pagamento = data da despesa'),
              ),
              RadioListTile(
                value: PaidDateSource.column,
                title: Text('Data do pagamento vem da coluna associada'),
              ),
            ],
          ),
        ),
    ],
  ];
}

const _createKey = '__criar__';
const _noneKey = '__nenhuma__';

String _choiceKey(CategoryChoice? c) => switch (c?.type) {
  CategoryChoiceType.existing => c!.existingId!,
  CategoryChoiceType.create => _createKey,
  CategoryChoiceType.none => _noneKey,
  null => _noneKey,
};

CategoryChoice _fromKey(String key) => switch (key) {
  _createKey => const CategoryChoice.create(),
  _noneKey => const CategoryChoice.none(),
  _ => CategoryChoice.existing(key),
};

List<Widget> categoriesStep(BuildContext context, ImportWizardController c) {
  final v = c.validation!;
  if (c.needs.isEmpty) {
    return [
      const Text(
        'O arquivo não traz categorias. Os lançamentos entram sem '
        'categoria.',
      ),
      if (v.inactiveCategories > 0)
        Text(
          '${v.inactiveCategories} categoria(s) inativa(s) do arquivo '
          'ignorada(s).',
        ),
    ];
  }
  final existing = c.existing;
  return [
    const Text(
      'Para cada nome do arquivo, use uma categoria que você já tem, crie uma '
      'nova ou deixe sem categoria. Categoria desativada não é reativada. '
      'Investimentos não têm categoria.',
    ),
    if (v.inactiveCategories > 0)
      noticeBox(
        context,
        '${v.inactiveCategories} categoria(s) marcada(s) como inativa(s) no '
        'arquivo foram ignoradas.',
      ),
    for (final need in c.needs)
      Card(
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${need.kind.label} · ${need.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('${need.rows} lançamento(s)'),
              DropdownButton<String>(
                key: Key('importar-categoria-${need.key}'),
                isExpanded: true,
                value: _choiceKey(c.categoryChoices[need.key]),
                items: [
                  DropdownMenuItem(
                    value: _createKey,
                    child: Text('Criar "${need.name}"'),
                  ),
                  const DropdownMenuItem(
                    value: _noneKey,
                    child: Text('Sem categoria'),
                  ),
                  for (final e in existing.categories)
                    if (e.active && e.kind == need.kind)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text('Usar "${e.name}"'),
                      ),
                ],
                onChanged: (k) => k == null
                    ? null
                    : c.setCategoryChoice(need.key, _fromKey(k)),
              ),
              if (existing.categories.any(
                (e) =>
                    !e.active &&
                    e.kind == need.kind &&
                    normalizeKey(e.name) == normalizeKey(need.name),
              ))
                Text(
                  'Existe uma categoria desativada com este nome; ela não é '
                  'reativada.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              for (final sub in need.subs.values)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('Subcategoria · ${sub.name}')),
                      Flexible(
                        child: DropdownButton<String>(
                          key: Key('importar-subcategoria-${sub.key}'),
                          isExpanded: true,
                          value: _choiceKey(c.categoryChoices[sub.key]),
                          items: [
                            if (c.categoryChoices[need.key]?.type !=
                                CategoryChoiceType.none)
                              DropdownMenuItem(
                                value: _createKey,
                                child: Text('Criar "${sub.name}"'),
                              ),
                            const DropdownMenuItem(
                              value: _noneKey,
                              child: Text('Sem subcategoria'),
                            ),
                            for (final s in existing.subcategories)
                              if (s.active &&
                                  s.categoryId ==
                                      c.categoryChoices[need.key]?.existingId)
                                DropdownMenuItem(
                                  value: s.id,
                                  child: Text('Usar "${s.name}"'),
                                ),
                          ],
                          onChanged: (k) => k == null
                              ? null
                              : c.setCategoryChoice(sub.key, _fromKey(k)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
  ];
}
