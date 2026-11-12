import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/infra_providers.dart';
import 'csv_export.dart';
import 'file_download.dart';

/// Lê todas as linhas de uma tabela do usuário, em páginas (sem o limite de
/// 1.000 linhas das listas comuns). A política de leitura isola por usuário.
abstract interface class ExportSource {
  Future<ExportData> load();
}

class SupabaseExportSource implements ExportSource {
  SupabaseExportSource(this._client);

  final SupabaseClient _client;
  static const pageSize = 1000;

  Future<List<Map<String, dynamic>>> _all(String table) async {
    final rows = <Map<String, dynamic>>[];
    for (var from = 0; ; from += pageSize) {
      final page = await _client
          .from(table)
          .select()
          .order('id', ascending: true)
          .range(from, from + pageSize - 1);
      rows.addAll(page.map((r) => Map<String, dynamic>.from(r)));
      if (page.length < pageSize) return rows;
    }
  }

  @override
  Future<ExportData> load() async => ExportData(
    incomes: await _all('income_entries'),
    expenses: await _all('expense_entries'),
    investments: await _all('investment_allocations'),
    categories: await _all('categories'),
    subcategories: await _all('subcategories'),
  );
}

final exportSourceProvider = Provider<ExportSource>(
  (ref) => SupabaseExportSource(ref.watch(supabaseClientProvider)),
);

/// Entrega 74 (D4): exportação CSV só na Web. No celular a tela orienta a usar
/// a versão Web.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  CsvKind? _running;
  String? _message;

  Future<void> _export(CsvKind kind) async {
    setState(() {
      _running = kind;
      _message = null;
    });
    try {
      final data = await ref.read(exportSourceProvider).load();
      downloadTextFile('norte_${kind.fileBase}.csv', buildCsv(kind, data));
      if (mounted) setState(() => _message = '${kind.label}: arquivo gerado.');
    } on Object {
      if (mounted) {
        setState(
          () => _message =
              'Não foi possível exportar agora. Verifique a conexão e tente '
              'de novo.',
        );
      }
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar dados (CSV)')),
      body: !canDownloadFiles
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'A exportação em CSV está disponível na versão Web do '
                'Norte. Entre pelo navegador com a mesma conta para '
                'baixar seus dados.',
                key: Key('exportar-so-web'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Cada arquivo traz os valores em centavos (coluna '
                  'valor_centavos) e inclui os lançamentos cancelados, com o '
                  'status.',
                ),
                const SizedBox(height: 16),
                for (final kind in CsvKind.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.tonal(
                      key: Key('exportar-${kind.fileBase}'),
                      onPressed: _running == null ? () => _export(kind) : null,
                      child: Text(
                        _running == kind
                            ? 'Gerando…'
                            : 'Baixar ${kind.label} (.csv)',
                      ),
                    ),
                  ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(_message!),
                ],
              ],
            ),
    );
  }
}
