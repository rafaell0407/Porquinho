import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/import_providers.dart';
import '../data/import_batch.dart';
import '../import_texts.dart';
import '../widgets/setup_steps.dart';

final _batchProvider = FutureProvider.autoDispose.family<ImportBatch?, String>(
  (ref, id) => ref.watch(importRepositoryProvider).batch(id),
);

/// Detalhe de uma importação, com "Desfazer…" condicional (RN055, etapa 12).
class ImportBatchScreen extends ConsumerStatefulWidget {
  const ImportBatchScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<ImportBatchScreen> createState() => _ImportBatchScreenState();
}

class _ImportBatchScreenState extends ConsumerState<ImportBatchScreen> {
  bool _working = false;
  UndoReport? _report;
  String? _error;
  int _calls = 0;

  Future<void> _undo(ImportBatch batch) async {
    final repo = ref.read(importRepositoryProvider);
    setState(() {
      _working = true;
      _error = null;
    });
    UndoReport? preview;
    try {
      preview = await repo.undoPreview(batch.id);
    } on Object {
      setState(() {
        _working = false;
        _error = 'Não foi possível calcular o desfazer. Tente de novo.';
      });
      return;
    }
    setState(() => _working = false);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desfazer a importação?'),
        content: SingleChildScrollView(
          child: _ReportText(report: preview!, preview: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('importar-confirmar-desfazer'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desfazer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _working = true;
      _calls = 0;
    });
    try {
      UndoReport r;
      do {
        r = await repo.undo(batch.id);
        if (mounted) setState(() => _calls++);
      } while (r.remaining);
      if (!mounted) return;
      setState(() => _report = r);
      ref.invalidate(_batchProvider(widget.batchId));
      ref.invalidate(importBatchesProvider);
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'A conexão caiu durante o desfazer. O que já foi desfeito fica; '
              'toque em "Desfazer…" de novo para continuar.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_batchProvider(widget.batchId));
    return Scaffold(
      appBar: AppBar(title: const Text('Importação')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(_batchProvider(widget.batchId)),
            child: const Text('Não foi possível carregar. Tentar de novo'),
          ),
        ),
        data: (batch) => batch == null
            ? const Center(child: Text('Importação não encontrada.'))
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _details(context, batch),
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _details(BuildContext context, ImportBatch b) {
    int n(Map? m, String k) => (m?[k] as num?)?.toInt() ?? 0;
    final res = b.result;
    final undoReport =
        _report ??
        (b.undoSummary == null
            ? null
            : UndoReport.fromJson({...b.undoSummary!, 'remaining': false}));
    return [
      Text(b.fileName, style: Theme.of(context).textTheme.titleLarge),
      Text(
        '${ImportTexts.date(b.createdAt)} · ${b.status.label}',
        key: const Key('importacao-status'),
      ),
      Text('${b.fileRows} linha(s) no arquivo'),
      if (res != null) ...[
        sectionTitle(context, 'O que entrou'),
        Text(
          '${n(res, 'incomes')} receita(s), ${n(res, 'expenses')} despesa(s), '
          '${n(res, 'investments')} investimento(s)',
        ),
        if (n(res, 'categories') + n(res, 'subcategories') > 0)
          Text(
            '${n(res, 'categories')} categoria(s), '
            '${n(res, 'subcategories')} subcategoria(s)',
          ),
        if (n(res, 'recurrences') > 0)
          Text(
            '${n(res, 'recurrences')} recorrência(s), '
            '${n(res, 'occurrences')} ocorrência(s) gerada(s)',
          ),
      ],
      if (b.summary.isNotEmpty) ...[
        sectionTitle(context, 'O que ficou de fora'),
        Text(
          '${n(b.summary, 'rejected')} rejeitada(s), '
          '${n(b.summary, 'cancelled')} cancelada(s) no arquivo, '
          '${n(b.summary, 'ignored_duplicates')} ignorada(s) por '
          'duplicidade',
        ),
      ],
      if (b.errorMessage != null && b.status.isOpen)
        noticeBox(
          context,
          'Parou na linha ${b.errorRow ?? '?'}: ${b.errorMessage}',
        ),
      if (undoReport != null) ...[
        sectionTitle(context, 'Desfazer'),
        _ReportText(report: undoReport, preview: false),
      ],
      if (_error != null) noticeBox(context, _error!),
      if (_working)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              const LinearProgressIndicator(),
              if (_calls > 0) Text('Desfazendo… ($_calls parte(s))'),
            ],
          ),
        ),
      if (b.status.canUndo && _report == null) ...[
        const SizedBox(height: 24),
        FilledButton.tonal(
          key: const Key('importar-desfazer'),
          onPressed: _working ? null : () => _undo(b),
          child: const Text('Desfazer…'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Cancela só o que não foi mexido depois da importação. '
            'Pagamentos, recebimentos e edições ficam. Nada é apagado e o '
            'desfazer não pode ser desfeito.',
          ),
        ),
      ],
    ];
  }
}

class _ReportText extends StatelessWidget {
  const _ReportText({required this.report, required this.preview});
  final UndoReport report;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final cancelled = r.count('cancelled');
    final deactivated = r.count('deactivated');
    return Column(
      key: Key(
        preview ? 'importar-previa-desfazer' : 'importar-resultado-desfazer',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          preview
              ? '$cancelled lançamento(s) serão cancelados e $deactivated '
                    'recorrência(s) ou categoria(s) desativadas.'
              : '$cancelled lançamento(s) cancelados e $deactivated '
                    'recorrência(s) ou categoria(s) desativadas.',
        ),
        if (r.preservedTotal > 0) ...[
          const SizedBox(height: 8),
          Text(
            preview
                ? '${r.preservedTotal} item(ns) serão preservados:'
                : '${r.preservedTotal} item(ns) preservados:',
          ),
          for (final p in r.preserved.take(50))
            Text(
              '• ${ImportTexts.entityLabel(p.entityType, p.role)}'
              '${p.row == null ? '' : ' (linha ${p.row})'}: ${p.reason ?? ''}',
            ),
          if (r.preserved.length > 50)
            Text('… e mais ${r.preserved.length - 50}.'),
        ],
      ],
    );
  }
}
