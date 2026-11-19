import 'package:porquinho/features/import/data/import_batch.dart';
import 'package:porquinho/features/import/data/import_repository.dart';
import 'package:porquinho/features/import/domain/existing_data.dart';
import 'package:porquinho/features/sync/sync_models.dart';

/// Servidor falso da importação: guarda blocos e simula falhas.
class FakeImportRepository implements ImportRepository {
  FakeImportRepository({this.existing = const ExistingData()});

  ExistingData existing;
  final batches = <String, ImportBatch>{};
  final plans = <String, Map<String, Object?>>{};
  final chunks = <String, Map<int, List<Map<String, Object?>>>>{};
  final calls = <String>[];

  /// Índice do bloco que falha (com a linha) uma vez.
  int? failChunk;
  int failRow = 0;

  /// Próximas chamadas de bloco que perdem a conexão.
  int disconnectChunks = 0;
  BeginOutcome beginOutcome = BeginOutcome.started;
  UndoReport undoResult = const UndoReport(
    remaining: false,
    counts: {'cancelled': 3, 'deactivated': 1},
    preserved: [],
  );
  int undoParts = 1;

  ImportBatch _batch(
    String id,
    ImportBatchStatus status, {
    Map<String, dynamic>? result,
  }) {
    final old = batches[id]!;
    return ImportBatch(
      id: id,
      status: status,
      fileName: old.fileName,
      fileSha256: old.fileSha256,
      fileSizeBytes: old.fileSizeBytes,
      fileRows: old.fileRows,
      planHash: old.planHash,
      totalChunks: old.totalChunks,
      itemCount: old.itemCount,
      createdAt: old.createdAt,
      plan: old.plan,
      summary: old.summary,
      result: result ?? old.result,
    );
  }

  @override
  Future<ExistingData> loadExisting() async => existing;

  @override
  Future<List<ImportBatch>> listBatches() async => batches.values.toList();

  @override
  Future<ImportBatch?> batch(String id) async => batches[id];

  @override
  Future<Set<int>> appliedChunks(String batchId) async =>
      (chunks[batchId] ?? const {}).keys.toSet();

  @override
  Future<BeginOutcome> begin({
    required String operationId,
    required String batchId,
    required Map<String, Object?> file,
    required Map<String, Object?> plan,
    required String planHash,
    required int totalChunks,
    required int itemCount,
    required Map<String, Object?> summary,
  }) async {
    calls.add('begin');
    if (beginOutcome != BeginOutcome.started) return beginOutcome;
    batches[batchId] = ImportBatch(
      id: batchId,
      status: ImportBatchStatus.processing,
      fileName: file['name']! as String,
      fileSha256: file['sha256']! as String,
      fileSizeBytes: file['size_bytes']! as int,
      fileRows: file['rows']! as int,
      planHash: planHash,
      totalChunks: totalChunks,
      itemCount: itemCount,
      createdAt: DateTime.utc(2026, 11, 18),
      plan: Map<String, dynamic>.from(plan),
      summary: Map<String, dynamic>.from(summary),
    );
    plans[batchId] = plan;
    chunks[batchId] = {};
    return BeginOutcome.started;
  }

  @override
  Future<ChunkOutcome> applyChunk(
    String batchId,
    int index,
    List<Map<String, Object?>> items,
  ) async {
    calls.add('chunk:$index');
    if (disconnectChunks > 0) {
      disconnectChunks--;
      throw const SyncTransientError('sem rede (simulado)');
    }
    if (failChunk == index) {
      failChunk = null;
      batches[batchId] = _batch(batchId, ImportBatchStatus.interrupted);
      return ChunkOutcome(applied: false, row: failRow, message: 'falhou');
    }
    chunks[batchId]![index] = items;
    return const ChunkOutcome(applied: true);
  }

  @override
  Future<ImportBatch> finish(String operationId, String batchId) async {
    calls.add('finish');
    final items = chunks[batchId]!.values.expand((c) => c).toList();
    int count(String type) => items.where((i) => i['type'] == type).length;
    batches[batchId] = _batch(
      batchId,
      ImportBatchStatus.completed,
      result: {
        'incomes': count('income'),
        'expenses': count('expense'),
        'investments': count('investment'),
        'categories': count('category'),
        'subcategories': count('subcategory'),
        'recurrences': count('series'),
        'occurrences': 0,
      },
    );
    return batches[batchId]!;
  }

  @override
  Future<UndoReport> undoPreview(String batchId) async => undoResult;

  @override
  Future<UndoReport> undo(String batchId, {int limit = 200}) async {
    calls.add('undo');
    undoParts--;
    if (undoParts > 0) {
      return const UndoReport(remaining: true, counts: {}, preserved: []);
    }
    batches[batchId] = _batch(batchId, ImportBatchStatus.undone);
    return undoResult;
  }

  List<Map<String, Object?>> allItems(String batchId) => [
    for (final i in (chunks[batchId]!.keys.toList()..sort()))
      ...chunks[batchId]![i]!,
  ];
}
