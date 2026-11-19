import 'package:flutter/material.dart';

import '../../../app/theme/norte_theme.dart';
import '../../../core/domain/money.dart';
import '../application/import_controller.dart';
import '../domain/duplicate_detection.dart';
import '../domain/import_models.dart';
import '../domain/series_detection.dart';
import '../import_texts.dart';
import 'setup_steps.dart';

/// Etapas 6–9 do assistente: duplicidades, recorrências, prévia/confirmação.

String _rowLine(ImportRow r) => [
  r.date.toBr(),
  ImportTexts.money(r.amount),
  r.kind.label,
  if (r.description != null) r.description!,
  if (r.categoryName != null) r.categoryName!,
].join(' · ');

List<Widget> duplicatesStep(BuildContext context, ImportWizardController c) {
  final groups = c.duplicateGroups;
  if (groups.isEmpty) {
    return const [Text('Nenhuma possível duplicidade encontrada.')];
  }
  final rows = {for (final r in c.validation!.rows) r.sourceRow: r};
  return [
    Text(
      '${groups.length} grupo(s) de possíveis duplicidades. Decida cada um: '
      'nada é ignorado sem a sua escolha. Faltam ${c.undecided}.',
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          key: const Key('importar-dup-todos-importar'),
          onPressed: () => c.decideAll(null, DuplicateDecision.importAnyway),
          child: const Text('Importar todos mesmo assim'),
        ),
        OutlinedButton(
          key: const Key('importar-dup-todos-ignorar'),
          onPressed: () => c.decideAll(null, DuplicateDecision.ignore),
          child: const Text('Ignorar todos'),
        ),
      ],
    ),
    for (final g in groups)
      Card(
        key: Key('importar-dup-${g.id}'),
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                g.kind.label + (g.strong ? ' (mesmo identificador)' : ''),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (g.kind == DuplicateKind.fileAlreadyImported)
                Text(
                  'O arquivo inteiro já entrou numa importação não desfeita '
                  '(${g.rows.length} linha(s)). "Ignorar" deixa todas de fora.',
                )
              else ...[
                for (final row in g.rows.take(5))
                  Text(
                    'Linha $row: ${rows[row] == null ? '' : _rowLine(rows[row]!)}',
                  ),
                if (g.rows.length > 5) Text('… e mais ${g.rows.length - 5}.'),
                if (g.kind == DuplicateKind.withinFile)
                  Text(
                    '"Ignorar" mantém só a primeira linha.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final m in g.matches.take(3))
                  Text(
                    'Já existe: ${m.date.toBr()} · ${ImportTexts.money(m.amount)}'
                    '${m.description == null ? '' : ' · ${m.description}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
              const SizedBox(height: 8),
              SegmentedButton<DuplicateDecision>(
                emptySelectionAllowed: true,
                segments: const [
                  ButtonSegment(
                    value: DuplicateDecision.importAnyway,
                    label: Text('Importar mesmo assim'),
                  ),
                  ButtonSegment(
                    value: DuplicateDecision.ignore,
                    label: Text('Ignorar'),
                  ),
                ],
                selected: {?c.duplicateDecisions[g.id]},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) c.decide(g.id, s.first);
                },
              ),
            ],
          ),
        ),
      ),
  ];
}

List<Widget> seriesStep(BuildContext context, ImportWizardController c) {
  if (c.series.isEmpty) {
    return const [
      Text(
        'Nenhuma recorrência mensal encontrada no arquivo. Os lançamentos '
        'entram como avulsos.',
      ),
    ];
  }
  return [
    const Text(
      'Encontramos lançamentos que se repetem todo mês. Marque só os que '
      'devem virar recorrência: o mais recente vira o início e os anteriores '
      'ficam avulsos. Nenhuma vem marcada.',
    ),
    for (final s in c.series) _SeriesCard(series: s, controller: c),
  ];
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, required this.controller});
  final SeriesCandidate series;
  final ImportWizardController controller;

  @override
  Widget build(BuildContext context) {
    final s = series;
    final c = controller;
    final selectable = s.status == SeriesStatus.suggested;
    final confirmed = c.confirmedSeries.contains(s.id);
    final backfill = selectable ? c.backfillOf(s) : const [];
    final name = s.kind == RowKind.investment
        ? 'Investimento de ${ImportTexts.money(s.anchor.amount)}'
        : '${s.kind.label} · ${s.description}';
    final colors = NorteColors.of(context);
    return Card(
      key: Key('importar-serie-${s.anchor.sourceRow}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: selectable
                  ? (v) => c.toggleSeries(s.id, v ?? false)
                  : null,
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${s.rows.length} meses seguidos · '
                '${s.fixed ? 'valor fixo ${ImportTexts.money(s.defaultAmount)}' : 'valor variável'}'
                ' · início ${s.anchor.date.toBr()} (linha ${s.anchor.sourceRow})',
              ),
            ),
            if (s.status == SeriesStatus.ended)
              const Text(
                'Parece encerrada (o último mês não é o atual nem o anterior): '
                'entra só como lançamentos avulsos.',
              ),
            if (s.status == SeriesStatus.future)
              const Text(
                'O último lançamento é de um mês futuro: entra só como avulsos.',
              ),
            if (s.status == SeriesStatus.collision)
              Text(
                s.collisionReason ?? '',
                style: TextStyle(color: colors.pending),
              ),
            if (selectable && s.dayDiffers)
              Text(
                'O dia de repetição será ${s.referenceDay} (dia do lançamento '
                'mais recente); nos outros meses foi dia ${s.habitualDay}.',
                style: TextStyle(color: colors.pending),
              ),
            if (selectable && confirmed) ...[
              const SizedBox(height: 4),
              if (backfill.isEmpty)
                const Text('Nenhuma ocorrência atrasada será gerada.')
              else ...[
                Text(
                  'Ao concluir, o Norte gera ${backfill.length} ocorrência(s) '
                  'até hoje:',
                ),
                for (final b in backfill)
                  Text(
                    '• ${b.date.toBr()} · ${ImportTexts.money(b.amount)}'
                    '${s.kind == RowKind.income
                        ? ' (fica a receber; só conta ao confirmar)'
                        : b.amount == null
                        ? ' (sem valor até você informar)'
                        : ' (conta no dinheiro livre)'}',
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

List<Widget> previewStep(BuildContext context, ImportWizardController c) {
  final a = c.assembled!;
  final v = a.validation;
  BigInt sum(RowKind k) => a.rows
      .where((r) => r.kind == k && r.amount != null)
      .fold(BigInt.zero, (t, r) => t + r.amount!);
  int count(RowKind k) => a.rows.where((r) => r.kind == k).length;
  final counts = c.pendingCounts;
  final rejected = a.rejected;
  final warned = v.rows.where((r) => r.warnings.isNotEmpty).toList();
  return [
    if (c.isLargeFile)
      noticeBox(
        context,
        'Arquivo grande: ${c.dataRows} linhas em ${a.chunks.length} bloco(s). '
        'Deve levar cerca de ${(c.estimatedDuration.inSeconds / 60).ceil()} '
        'minuto(s). Nada é cortado.',
        key: const Key('importar-arquivo-grande'),
      ),
    sectionTitle(context, 'O que vai entrar'),
    for (final k in [RowKind.income, RowKind.expense, RowKind.investment])
      if (count(k) > 0)
        Text('${count(k)} ${ImportTexts.kindPlural(k)} · ${formatBrl(sum(k))}'),
    if (a.newCategories + a.newSubcategories > 0)
      Text(
        '${a.newCategories} categoria(s) e ${a.newSubcategories} '
        'subcategoria(s) novas',
      ),
    if (a.series.isNotEmpty)
      Text(
        '${a.series.length} recorrência(s) e ${a.backfill.length} '
        'ocorrência(s) atrasada(s) geradas ao concluir',
      ),
    if (counts != null &&
        (counts.overdueExpenses +
                counts.pendingIncomes +
                counts.unpricedExpenses) >
            0) ...[
      if (counts.overdueExpenses > 0)
        Text(
          '${counts.overdueExpenses} despesa(s) vão nascer pendentes e '
          'vencidas (com alerta diário até você pagar).',
        ),
      if (counts.pendingIncomes > 0)
        Text(
          '${counts.pendingIncomes} receita(s) ficam a receber (só contam '
          'quando você confirmar).',
        ),
      if (counts.unpricedExpenses > 0)
        Text(
          '${counts.unpricedExpenses} despesa(s) variáveis sem valor (contam '
          'quando você informar).',
        ),
    ],
    sectionTitle(context, 'O que fica de fora'),
    Text('${rejected.length} linha(s) rejeitada(s)'),
    Text('${v.cancelled} cancelada(s) no arquivo (não importadas)'),
    Text('${a.ignoredByDuplicates} ignorada(s) por duplicidade'),
    if (v.ignoredByKind > 0) Text('${v.ignoredByKind} ignorada(s) pelo tipo'),
    if (rejected.isNotEmpty)
      ExpansionTile(
        key: const Key('importar-rejeitadas'),
        tilePadding: EdgeInsets.zero,
        title: const Text('Ver linhas rejeitadas'),
        children: [
          for (final r in rejected.take(200))
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Linha ${r.sourceRow}: ${r.reason}'),
            ),
          if (rejected.length > 200) Text('… e mais ${rejected.length - 200}.'),
        ],
      ),
    if (warned.isNotEmpty)
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('${warned.length} linha(s) com aviso'),
        children: [
          for (final r in warned.take(200))
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Linha ${r.sourceRow}: ${r.warnings.join(' ')}'),
            ),
        ],
      ),
    if (c.periods.isNotEmpty) ...[
      sectionTitle(context, 'Efeito no dinheiro livre por período'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('importar-periodos'),
          columns: const [
            DataColumn(label: Text('Período')),
            DataColumn(label: Text('Lançamentos'), numeric: true),
            DataColumn(label: Text('Efeito'), numeric: true),
            DataColumn(label: Text('Livre antes'), numeric: true),
            DataColumn(label: Text('Livre depois'), numeric: true),
          ],
          rows: [
            for (final p in c.periods)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      '${p.effect.range.start.toBr()} a '
                      '${p.effect.range.end.addDays(-1).toBr()}',
                    ),
                  ),
                  DataCell(Text('${p.effect.entries}')),
                  DataCell(Text(formatBrl(p.effect.delta))),
                  DataCell(
                    Text(p.freeBefore == null ? '—' : formatBrl(p.freeBefore!)),
                  ),
                  DataCell(
                    Text(p.freeAfter == null ? '—' : formatBrl(p.freeAfter!)),
                  ),
                ],
              ),
          ],
        ),
      ),
    ],
  ];
}

/// Texto do botão de confirmação (etapa 9).
String confirmLabel(ImportWizardController c) {
  final a = c.assembled;
  if (a == null) return 'Importar';
  return 'Importar ${a.entryCount} lançamento(s), criar '
      '${a.newCategories + a.newSubcategories} categoria(s) e '
      '${a.series.length} recorrência(s)';
}
