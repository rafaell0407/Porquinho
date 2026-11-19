import '../../sync/sync_models.dart';
import '../data/import_batch.dart';
import '../data/import_repository.dart';
import '../domain/import_plan.dart';

/// Resultado do envio.
sealed class RunResult {
  const RunResult();
}

class RunCompleted extends RunResult {
  const RunCompleted(this.batch);
  final ImportBatch batch;
}

/// Um bloco falhou: voltou inteiro e a importação ficou interrompida (RN054).
class RunFailed extends RunResult {
  const RunFailed({this.row, this.message});
  final int? row;
  final String? message;
}

/// Sem conexão no meio: o que entrou fica; dá para retomar com o arquivo.
class RunDisconnected extends RunResult {
  const RunDisconnected(this.message);
  final String message;
}

class RunBlocked extends RunResult {
  const RunBlocked(this.outcome);
  final BeginOutcome outcome;
}

/// Envia a importação em blocos (§12): começa (ou retoma), aplica os blocos
/// que faltam na ordem, e conclui. Ids e operações são determinísticos, então
/// repetir nunca duplica.
class ImportRunner {
  ImportRunner(this._repo, {this.retries = 2});

  final ImportRepository _repo;
  final int retries;

  Future<T> _retry<T>(Future<T> Function() call) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await call();
      } on SyncTransientError {
        if (attempt >= retries) rethrow;
      }
    }
  }

  Future<RunResult> run({
    required ImportPlan plan,
    required ImportFileInfo file,
    required AssembledImport assembled,
    required Map<String, Object?> summary,
    bool resume = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final chunks = assembled.chunks;
    final batchId = plan.batchId;
    try {
      if (!resume) {
        final begin = await _retry(
          () => _repo.begin(
            operationId: importUuid('$batchId|begin'),
            batchId: batchId,
            file: file.toJson(),
            plan: plan.toJson(),
            planHash: plan.hash,
            totalChunks: chunks.length,
            itemCount: assembled.items.length,
            summary: summary,
          ),
        );
        if (begin != BeginOutcome.started) return RunBlocked(begin);
      }
      final applied = await _retry(() => _repo.appliedChunks(batchId));
      var done = applied.length;
      onProgress?.call(done, chunks.length);
      for (var i = 0; i < chunks.length; i++) {
        if (applied.contains(i)) continue;
        final outcome = await _retry(
          () => _repo.applyChunk(batchId, i, chunks[i]),
        );
        if (!outcome.applied) {
          return RunFailed(row: outcome.row, message: outcome.message);
        }
        done++;
        onProgress?.call(done, chunks.length);
      }
      final batch = await _retry(
        () => _repo.finish(importUuid('$batchId|finish'), batchId),
      );
      return RunCompleted(batch);
    } on SyncTransientError catch (e) {
      return RunDisconnected(e.message);
    }
  }
}
