import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/norte_theme.dart';
import '../application/import_providers.dart';
import '../data/file_picker.dart' as picker;
import '../data/import_batch.dart';
import '../data/picked_file.dart';
import '../import_texts.dart';
import 'import_guide_screen.dart';

/// A importação existe neste ambiente (só Web, RN046). Testes sobrescrevem.
final importAvailableProvider = Provider<bool>((_) => picker.canPickFiles);

/// Escolha de um arquivo CSV no navegador. Testes sobrescrevem.
final csvFilePickerProvider = Provider<Future<PickedFile?> Function()>(
  (_) => picker.pickCsvFile,
);

/// Dados para retomar uma importação interrompida com o mesmo arquivo.
class ImportResumeRequest {
  const ImportResumeRequest(this.batch, this.file);
  final ImportBatch batch;
  final PickedFile file;
}

/// Mais → Importar dados (CSV): histórico e nova importação (etapa 1).
class ImportHomeScreen extends ConsumerWidget {
  const ImportHomeScreen({super.key});

  static const route = '/importar';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(importAvailableProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(ImportTexts.title)),
      body: !available
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(ImportTexts.webOnly, key: Key('importar-so-web')),
            )
          : _History(),
    );
  }
}

class _History extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(importBatchesProvider);
    return batches.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar as importações.'),
            TextButton(
              onPressed: () => ref.invalidate(importBatchesProvider),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
      data: (list) {
        final open = list.where((b) => b.status.isOpen).firstOrNull;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(ImportTexts.intro),
                const SizedBox(height: 16),
                const _GuideCard(),
                const SizedBox(height: 16),
                if (open != null) _OpenBatchCard(batch: open),
                FilledButton.icon(
                  key: const Key('importar-nova'),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Nova importação'),
                  onPressed: open != null
                      ? null
                      : () async {
                          await context.push('${ImportHomeScreen.route}/nova');
                          ref.invalidate(importBatchesProvider);
                        },
                ),
                if (open != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Termine ou desfaça a importação em andamento antes de '
                      'começar outra.',
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Importações anteriores',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  const Text('Nenhuma importação ainda.')
                else
                  for (final b in list) _BatchTile(batch: b),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Modelo para baixar e acesso ao passo a passo.
class _GuideCard extends ConsumerWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: const Key('importar-ajuda'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Primeira vez?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Baixe o modelo, preencha com seus lançamentos e carregue aqui. '
              'O passo a passo explica cada coluna.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('importar-baixar-modelo'),
                  icon: const Icon(Icons.download),
                  label: const Text('Baixar modelo'),
                  onPressed: () => downloadImportTemplate(context, ref),
                ),
                TextButton.icon(
                  key: const Key('importar-tutorial'),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Como importar'),
                  onPressed: () => context.push(ImportGuideScreen.route),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenBatchCard extends ConsumerWidget {
  const _OpenBatchCard({required this.batch});
  final ImportBatch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NorteColors.of(context);
    return Card(
      key: const Key('importar-interrompida'),
      color: colors.pendingBackground,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              batch.status == ImportBatchStatus.undoing
                  ? 'O desfazer de "${batch.fileName}" não terminou.'
                  : 'A importação de "${batch.fileName}" não terminou.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (batch.errorRow != null || batch.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Parou na linha ${batch.errorRow ?? '?'}: '
                  '${batch.errorMessage ?? ''}',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (batch.status != ImportBatchStatus.undoing)
                  FilledButton.tonal(
                    key: const Key('importar-retomar'),
                    onPressed: () => _resume(context, ref),
                    child: const Text('Retomar (escolher o mesmo arquivo)'),
                  ),
                OutlinedButton(
                  key: const Key('importar-desfazer-interrompida'),
                  onPressed: () async {
                    await context.push('${ImportHomeScreen.route}/${batch.id}');
                    ref.invalidate(importBatchesProvider);
                  },
                  child: Text(
                    batch.status == ImportBatchStatus.undoing
                        ? 'Continuar o desfazer'
                        : 'Desfazer o que entrou',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final file = await ref.read(csvFilePickerProvider)();
    if (file == null || !context.mounted) return;
    await context.push(
      '${ImportHomeScreen.route}/nova',
      extra: ImportResumeRequest(batch, file),
    );
    ref.invalidate(importBatchesProvider);
  }
}

class _BatchTile extends ConsumerWidget {
  const _BatchTile({required this.batch});
  final ImportBatch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = batch.result;
    final entries = result == null
        ? null
        : ['incomes', 'expenses', 'investments']
              .map((k) => (result[k] as num?)?.toInt() ?? 0)
              .fold<int>(0, (a, b) => a + b);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('importacao-${batch.id}'),
        leading: const Icon(Icons.description_outlined),
        title: Text(batch.fileName),
        subtitle: Text(
          '${ImportTexts.date(batch.createdAt)} · ${batch.status.label}'
          '${entries == null ? '' : ' · $entries lançamento(s)'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await context.push('${ImportHomeScreen.route}/${batch.id}');
          ref.invalidate(importBatchesProvider);
        },
      ),
    );
  }
}
