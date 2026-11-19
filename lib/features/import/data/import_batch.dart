/// Importação registrada no servidor (`import_batches`), sem o arquivo.
enum ImportBatchStatus {
  processing('processing', 'Não terminou'),
  completed('completed', 'Concluída'),
  interrupted('interrupted', 'Interrompida'),
  undoing('undoing', 'Desfazendo'),
  undone('undone', 'Desfeita'),
  partiallyUndone('partially_undone', 'Desfeita em parte');

  const ImportBatchStatus(this.db, this.label);
  final String db;
  final String label;

  static ImportBatchStatus fromDb(String value) =>
      ImportBatchStatus.values.firstWhere((s) => s.db == value);

  /// Em andamento: impede outra importação (RN054).
  bool get isOpen =>
      this == processing || this == interrupted || this == undoing;

  /// Pode ser desfeita (RN055).
  bool get canUndo =>
      this == completed ||
      this == processing ||
      this == interrupted ||
      this == undoing;
}

class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.status,
    required this.fileName,
    required this.fileSha256,
    required this.fileSizeBytes,
    required this.fileRows,
    required this.planHash,
    required this.totalChunks,
    required this.itemCount,
    required this.createdAt,
    this.plan,
    this.summary = const {},
    this.result,
    this.lastError,
    this.undoSummary,
    this.completedAt,
    this.undoneAt,
  });

  final String id;
  final ImportBatchStatus status;
  final String fileName;
  final String fileSha256;
  final int fileSizeBytes;
  final int fileRows;
  final String planHash;
  final int totalChunks;
  final int itemCount;
  final DateTime createdAt;

  /// Decisões do usuário (só quando lido com o plano, para retomar).
  final Map<String, dynamic>? plan;

  /// Contagens do cliente (rejeitadas, canceladas, ignoradas…).
  final Map<String, dynamic> summary;

  /// Contagens do servidor ao concluir.
  final Map<String, dynamic>? result;

  /// Último erro de bloco: linha e mensagem.
  final Map<String, dynamic>? lastError;
  final Map<String, dynamic>? undoSummary;
  final DateTime? completedAt;
  final DateTime? undoneAt;

  int? get errorRow => (lastError?['row'] as num?)?.toInt();
  String? get errorMessage => lastError?['message'] as String?;

  factory ImportBatch.fromRow(Map<String, dynamic> r) {
    Map<String, dynamic>? map(Object? v) =>
        v == null ? null : Map<String, dynamic>.from(v as Map);
    DateTime? time(Object? v) => v == null ? null : DateTime.parse('$v');
    return ImportBatch(
      id: r['id'] as String,
      status: ImportBatchStatus.fromDb(r['status'] as String),
      fileName: r['file_name'] as String,
      fileSha256: r['file_sha256'] as String,
      fileSizeBytes: (r['file_size_bytes'] as num).toInt(),
      fileRows: (r['file_rows'] as num).toInt(),
      planHash: r['plan_hash'] as String,
      totalChunks: (r['total_chunks'] as num).toInt(),
      itemCount: (r['item_count'] as num).toInt(),
      createdAt: DateTime.parse('${r['created_at']}'),
      plan: map(r['plan']),
      summary: map(r['summary']) ?? const {},
      result: map(r['result']),
      lastError: map(r['last_error']),
      undoSummary: map(r['undo_summary']),
      completedAt: time(r['completed_at']),
      undoneAt: time(r['undone_at']),
    );
  }
}

/// Resultado do começo de uma importação.
enum BeginOutcome { started, inProgress, fileAlreadyImported }

class ChunkOutcome {
  const ChunkOutcome({required this.applied, this.row, this.message});
  final bool applied;
  final int? row;
  final String? message;
}

/// Prévia ou resultado do desfazer (RN055).
class UndoReport {
  const UndoReport({
    required this.remaining,
    required this.counts,
    required this.preserved,
    this.status,
  });

  final bool remaining;

  /// `cancelled`, `deactivated`, `preserved_changed`, `preserved_in_use` e
  /// as mesmas chaves com `:papel`.
  final Map<String, int> counts;
  final List<PreservedItem> preserved;
  final ImportBatchStatus? status;

  int count(String outcome) => counts[outcome] ?? 0;

  int get preservedTotal =>
      count('preserved_changed') + count('preserved_in_use');

  factory UndoReport.fromJson(Map<String, dynamic> json) => UndoReport(
    remaining: json['remaining'] == true,
    counts: {
      for (final e in ((json['counts'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    preserved: [
      for (final p in (json['preserved'] as List?) ?? const [])
        PreservedItem.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
    status:
        json['status'] is String &&
            ImportBatchStatus.values.any((s) => s.db == json['status'])
        ? ImportBatchStatus.fromDb(json['status'] as String)
        : null,
  );
}

class PreservedItem {
  const PreservedItem({
    required this.entityType,
    required this.role,
    required this.outcome,
    this.row,
    this.reason,
  });

  final String entityType;
  final String role;
  final String outcome;
  final int? row;
  final String? reason;

  factory PreservedItem.fromJson(Map<String, dynamic> json) => PreservedItem(
    entityType: json['entity_type'] as String,
    role: json['role'] as String,
    outcome: json['outcome'] as String,
    row: (json['row'] as num?)?.toInt(),
    reason: json['reason'] as String?,
  );
}
