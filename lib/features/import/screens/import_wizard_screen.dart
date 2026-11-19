import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/import_controller.dart';
import '../application/import_providers.dart';
import '../application/import_runner.dart';
import '../data/import_batch.dart';
import '../import_texts.dart';
import '../widgets/review_steps.dart';
import '../widgets/setup_steps.dart';
import 'import_home_screen.dart';

/// Assistente de nova importação (etapas 2–11) ou retomada (D26).
class ImportWizardScreen extends ConsumerStatefulWidget {
  const ImportWizardScreen({super.key, this.resume});

  final ImportResumeRequest? resume;

  @override
  ConsumerState<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends ConsumerState<ImportWizardScreen> {
  late final ImportWizardController _c;
  String? _resumeError;

  @override
  void initState() {
    super.initState();
    _c = newImportController(ref);
    final resume = widget.resume;
    if (resume != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final problem = await _c.resumeWith(resume.batch, resume.file);
        if (mounted && problem != null) setState(() => _resumeError = problem);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(importAvailableProvider);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final step = _c.step;
        final inWizard = ImportStep.wizard.contains(step);
        return PopScope(
          canPop: step != ImportStep.processing,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: step != ImportStep.processing,
              title: Text(
                widget.resume != null
                    ? 'Retomar importação'
                    : 'Nova importação',
              ),
            ),
            body: !available
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(ImportTexts.webOnly),
                  )
                : _resumeError != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resumeError!,
                          key: const Key('importar-retomar-erro'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.pushReplacement(
                            '${ImportHomeScreen.route}/${widget.resume!.batch.id}',
                          ),
                          child: const Text('Desfazer o que entrou'),
                        ),
                      ],
                    ),
                  )
                : _body(context, step),
            bottomNavigationBar: inWizard && available && _resumeError == null
                ? _NavBar(controller: _c)
                : null,
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ImportStep step) {
    final pick = ref.read(csvFilePickerProvider);
    final List<Widget> children = switch (step) {
      ImportStep.file => fileStep(context, _c, pick),
      ImportStep.columns => columnsStep(context, _c),
      ImportStep.classification => classificationStep(context, _c),
      ImportStep.categories => categoriesStep(context, _c),
      ImportStep.duplicates => duplicatesStep(context, _c),
      ImportStep.series => seriesStep(context, _c),
      ImportStep.preview => previewStep(context, _c),
      ImportStep.processing => _processing(context),
      ImportStep.result => _result(context),
    };
    final index = ImportStep.wizard.indexOf(step);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.builder(
          key: Key('importar-etapa-${step.name}'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: children.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index >= 0)
                      Text(
                        'Etapa ${index + 1} de ${ImportStep.wizard.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      step.label,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (index >= 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (index + 1) / ImportStep.wizard.length,
                      ),
                    ],
                    if (_c.error != null) noticeBox(context, _c.error!),
                  ],
                ),
              );
            }
            return children[i - 1];
          },
        ),
      ),
    );
  }

  List<Widget> _processing(BuildContext context) {
    final total = _c.progressTotal;
    final done = _c.progressDone;
    return [
      LinearProgressIndicator(
        key: const Key('importar-progresso'),
        value: total == 0 ? null : done / total,
      ),
      const SizedBox(height: 8),
      Text('Bloco $done de $total gravado(s).'),
      const SizedBox(height: 16),
      const Text(ImportTexts.processingHint),
    ];
  }

  List<Widget> _result(BuildContext context) {
    final r = _c.runResult;
    final batchId = _c.plan?.batchId;
    Widget openBatch() => OutlinedButton(
      key: const Key('importar-ver-importacao'),
      onPressed: batchId == null
          ? null
          : () => context.pushReplacement('${ImportHomeScreen.route}/$batchId'),
      child: const Text('Ver a importação (desfazer)'),
    );
    switch (r) {
      case RunCompleted(:final batch):
        final res = batch.result ?? const {};
        final sum = batch.summary;
        int n(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;
        return [
          Text(
            'Importação concluída.',
            key: const Key('importar-concluida'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${n(res, 'incomes')} receita(s), ${n(res, 'expenses')} '
            'despesa(s) e ${n(res, 'investments')} investimento(s) criados.',
          ),
          if (n(res, 'categories') + n(res, 'subcategories') > 0)
            Text(
              '${n(res, 'categories')} categoria(s) e '
              '${n(res, 'subcategories')} subcategoria(s) criadas.',
            ),
          if (n(res, 'recurrences') > 0)
            Text(
              '${n(res, 'recurrences')} recorrência(s) criadas e '
              '${n(res, 'occurrences')} ocorrência(s) geradas.',
            ),
          Text(
            '${n(sum, 'ignored_duplicates')} ignorada(s) por duplicidade, '
            '${n(sum, 'rejected')} rejeitada(s) e ${n(sum, 'cancelled')} '
            'cancelada(s) não importadas.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('importar-ir-lancamentos'),
                onPressed: () => context.go('/lancamentos'),
                child: const Text('Ver lançamentos'),
              ),
              if (n(res, 'recurrences') > 0)
                OutlinedButton(
                  onPressed: () => context.push('/recorrencias'),
                  child: const Text('Ver recorrências'),
                ),
              openBatch(),
            ],
          ),
        ];
      case RunFailed(:final row, :final message):
        return [
          Text(
            'A importação parou${row == null ? '' : ' na linha $row'}.',
            key: const Key('importar-falhou'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (message != null) Text(message),
          const SizedBox(height: 8),
          const Text(
            'Nada desse bloco foi gravado; os blocos anteriores ficaram. Você '
            'pode desfazer o que entrou ou, depois de corrigir a causa, '
            'retomar com o mesmo arquivo.',
          ),
          const SizedBox(height: 16),
          openBatch(),
        ];
      case RunDisconnected():
        return [
          Text(
            'A conexão caiu durante a importação.',
            key: const Key('importar-sem-conexao'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'O que já entrou está salvo e nada se repete: em Importar dados, '
            'use "Retomar" e escolha o mesmo arquivo.',
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Voltar'),
          ),
        ];
      case RunBlocked(:final outcome):
        return [
          Text(
            outcome == BeginOutcome.fileAlreadyImported
                ? 'Este arquivo já foi importado e a duplicidade não foi '
                      'confirmada.'
                : 'Já existe uma importação em andamento. Termine ou desfaça '
                      'antes de começar outra.',
            key: const Key('importar-bloqueada'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Voltar'),
          ),
        ];
      case null:
        return const [Center(child: CircularProgressIndicator())];
    }
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.controller});
  final ImportWizardController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final blockers = c.blockers;
    final first = ImportStep.wizard.indexOf(c.step) == 0;
    final last = c.step == ImportStep.preview;
    return SafeArea(
      child: Material(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blockers.isNotEmpty && c.file != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    blockers.first,
                    key: const Key('importar-bloqueio'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Row(
                children: [
                  if (!first)
                    TextButton(
                      key: const Key('importar-voltar'),
                      onPressed: c.busy ? null : c.back,
                      child: const Text('Voltar'),
                    ),
                  const Spacer(),
                  if (c.busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Flexible(
                    child: FilledButton(
                      key: Key(
                        last ? 'importar-confirmar' : 'importar-continuar',
                      ),
                      onPressed: c.canContinue ? c.next : null,
                      child: Text(
                        last ? confirmLabel(c) : 'Continuar',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
