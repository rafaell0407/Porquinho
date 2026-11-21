import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/domain/calendar_date.dart';
import '../../sync/sync_models.dart';
import '../domain/existing_data.dart';
import '../domain/import_models.dart';
import 'import_batch.dart';

/// Acesso ao servidor da importação (só Web, sempre online).
abstract interface class ImportRepository {
  /// Categorias, lançamentos, modelos e importações anteriores, lidos em
  /// páginas (sem o limite de 1.000 linhas).
  Future<ExistingData> loadExisting();

  Future<List<ImportBatch>> listBatches();

  /// Uma importação com o plano (para retomar).
  Future<ImportBatch?> batch(String id);

  /// Índices dos blocos já aplicados.
  Future<Set<int>> appliedChunks(String batchId);

  Future<BeginOutcome> begin({
    required String operationId,
    required String batchId,
    required Map<String, Object?> file,
    required Map<String, Object?> plan,
    required String planHash,
    required int totalChunks,
    required int itemCount,
    required Map<String, Object?> summary,
  });

  Future<ChunkOutcome> applyChunk(
    String batchId,
    int index,
    List<Map<String, Object?>> items,
  );

  /// Conclui; devolve o lote atualizado.
  Future<ImportBatch> finish(String operationId, String batchId);

  Future<UndoReport> undoPreview(String batchId);

  /// Uma parte do desfazer (até [limit] chamadas).
  Future<UndoReport> undo(String batchId, {int limit});
}

/// Chamadas ao Supabase isoladas para os testes trocarem por um falso.
abstract interface class ImportBackend {
  Future<Object?> rpc(String name, Map<String, Object?> params);

  /// Todas as linhas visíveis da [table] (a política isola por usuário).
  Future<List<Map<String, dynamic>>> selectAll(String table, String columns);

  Future<Map<String, dynamic>?> selectOne(String table, String id);

  Future<List<Map<String, dynamic>>> selectWhere(
    String table,
    String columns,
    String column,
    String value,
  );
}

class SupabaseImportBackend implements ImportBackend {
  SupabaseImportBackend(this._client, {this.pageSize = 1000});

  final SupabaseClient _client;
  final int pageSize;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SyncTransientError(e.message);
    } on SyncTransientError {
      rethrow;
    } catch (e) {
      throw SyncTransientError(e.toString());
    }
  }

  @override
  Future<Object?> rpc(String name, Map<String, Object?> params) =>
      _guard(() => _client.rpc(name, params: params));

  @override
  Future<List<Map<String, dynamic>>> selectAll(String table, String columns) =>
      _guard(() async {
        final all = <Map<String, dynamic>>[];
        for (var from = 0; ; from += pageSize) {
          final page = await _client
              .from(table)
              .select(columns)
              .order('id', ascending: true)
              .range(from, from + pageSize - 1);
          all.addAll(page.map((r) => Map<String, dynamic>.from(r)));
          if (page.length < pageSize) return all;
        }
      });

  @override
  Future<Map<String, dynamic>?> selectOne(String table, String id) => _guard(
    () async {
      final row = await _client.from(table).select().eq('id', id).maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    },
  );

  @override
  Future<List<Map<String, dynamic>>> selectWhere(
    String table,
    String columns,
    String column,
    String value,
  ) => _guard(() async {
    final rows = await _client.from(table).select(columns).eq(column, value);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  });
}

const _batchColumns =
    'id,status,file_name,file_sha256,file_size_bytes,file_rows,plan_hash,'
    'total_chunks,item_count,summary,result,last_error,undo_summary,'
    'created_at,completed_at,undone_at';

BigInt? _big(Object? v) => v == null ? null : BigInt.parse('$v');
CalendarDate? _date(Object? v) => v == null ? null : CalendarDate.parse('$v');

class RemoteImportRepository implements ImportRepository {
  RemoteImportRepository(this._backend);

  final ImportBackend _backend;

  @override
  Future<ExistingData> loadExisting() async {
    final categories = await _backend.selectAll(
      'categories',
      'id,kind,name,is_active',
    );
    final subcategories = await _backend.selectAll(
      'subcategories',
      'id,category_id,name,is_active',
    );
    // Valores em texto: na Web, número JSON acima de 2^53 perde exatidão
    // (RN045; `core/exact_money_columns.dart`).
    final incomes = await _backend.selectAll(
      'income_entries',
      'id,description,amount_centavos::text,status,received_on,scheduled_for_date,'
          'category_id,recurrence_template_id',
    );
    final expenses = await _backend.selectAll(
      'expense_entries',
      'id,description,amount_centavos::text,status,competence_on,category_id,'
          'recurrence_template_id',
    );
    final investments = await _backend.selectAll(
      'investment_allocations',
      'id,amount_centavos::text,allocated_on,cancelled_at,recurrence_template_id',
    );
    final incomeTemplates = await _backend.selectAll(
      'income_recurrence_templates',
      'id,description,category_id,is_active',
    );
    final expenseTemplates = await _backend.selectAll(
      'expense_recurrence_templates',
      'id,description,category_id,is_active',
    );
    final investmentTemplates = await _backend.selectAll(
      'investment_recurrence_templates',
      'id,default_amount_centavos::text,is_active',
    );
    final batches = await _backend.selectAll('import_batches', _batchColumns);

    return ExistingData(
      categories: [
        for (final c in categories)
          ExistingCategory(
            id: c['id'] as String,
            kind: CategoryKind.fromKey(c['kind'] as String),
            name: c['name'] as String,
            active: c['is_active'] == true,
          ),
      ],
      subcategories: [
        for (final s in subcategories)
          ExistingSubcategory(
            id: s['id'] as String,
            categoryId: s['category_id'] as String,
            name: s['name'] as String,
            active: s['is_active'] == true,
          ),
      ],
      entries: [
        for (final e in incomes)
          if (_date(e['received_on'] ?? e['scheduled_for_date']) != null)
            ExistingEntry(
              id: e['id'] as String,
              kind: RowKind.income,
              date: _date(e['received_on'] ?? e['scheduled_for_date'])!,
              amount: _big(e['amount_centavos']),
              cancelled: e['status'] == 'cancelled',
              description: e['description'] as String?,
              categoryId: e['category_id'] as String?,
              templateId: e['recurrence_template_id'] as String?,
            ),
        for (final e in expenses)
          ExistingEntry(
            id: e['id'] as String,
            kind: RowKind.expense,
            date: _date(e['competence_on'])!,
            amount: _big(e['amount_centavos']),
            cancelled: e['status'] == 'cancelled',
            description: e['description'] as String?,
            categoryId: e['category_id'] as String?,
            templateId: e['recurrence_template_id'] as String?,
          ),
        for (final e in investments)
          ExistingEntry(
            id: e['id'] as String,
            kind: RowKind.investment,
            date: _date(e['allocated_on'])!,
            amount: _big(e['amount_centavos']),
            cancelled: e['cancelled_at'] != null,
            templateId: e['recurrence_template_id'] as String?,
          ),
      ],
      templates: [
        for (final t in incomeTemplates)
          ExistingTemplate(
            id: t['id'] as String,
            kind: RowKind.income,
            active: t['is_active'] == true,
            description: t['description'] as String?,
            categoryId: t['category_id'] as String?,
          ),
        for (final t in expenseTemplates)
          ExistingTemplate(
            id: t['id'] as String,
            kind: RowKind.expense,
            active: t['is_active'] == true,
            description: t['description'] as String?,
            categoryId: t['category_id'] as String?,
          ),
        for (final t in investmentTemplates)
          ExistingTemplate(
            id: t['id'] as String,
            kind: RowKind.investment,
            active: t['is_active'] == true,
            amount: _big(t['default_amount_centavos']),
          ),
      ],
      imports: [
        for (final b in batches)
          if (b['status'] != 'undone')
            PreviousImport(
              batchId: b['id'] as String,
              fileName: b['file_name'] as String,
              fileSha256: b['file_sha256'] as String,
              createdAt: DateTime.parse('${b['created_at']}'),
            ),
      ],
    );
  }

  @override
  Future<List<ImportBatch>> listBatches() async {
    final rows = await _backend.selectAll('import_batches', _batchColumns);
    final list = [for (final r in rows) ImportBatch.fromRow(r)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<ImportBatch?> batch(String id) async {
    final row = await _backend.selectOne('import_batches', id);
    return row == null ? null : ImportBatch.fromRow(row);
  }

  @override
  Future<Set<int>> appliedChunks(String batchId) async {
    final rows = await _backend.selectWhere(
      'import_batch_chunks',
      'chunk_index',
      'batch_id',
      batchId,
    );
    return {for (final r in rows) (r['chunk_index'] as num).toInt()};
  }

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
    final r = Map<String, dynamic>.from(
      await _backend.rpc('import_begin_batch', {
            'p_operation_id': operationId,
            'p_batch_id': batchId,
            'p_file': file,
            'p_plan': plan,
            'p_plan_hash': planHash,
            'p_total_chunks': totalChunks,
            'p_item_count': itemCount,
            'p_summary': summary,
          })
          as Map,
    );
    if (r['status'] == 'applied') return BeginOutcome.started;
    return r['reason'] == 'file_already_imported'
        ? BeginOutcome.fileAlreadyImported
        : BeginOutcome.inProgress;
  }

  @override
  Future<ChunkOutcome> applyChunk(
    String batchId,
    int index,
    List<Map<String, Object?>> items,
  ) async {
    final r = Map<String, dynamic>.from(
      await _backend.rpc('import_apply_chunk', {
            'p_batch_id': batchId,
            'p_chunk_index': index,
            'p_items': items,
          })
          as Map,
    );
    return ChunkOutcome(
      applied: r['status'] == 'applied',
      row: (r['row'] as num?)?.toInt(),
      message: r['message'] as String?,
    );
  }

  @override
  Future<ImportBatch> finish(String operationId, String batchId) async {
    final r = Map<String, dynamic>.from(
      await _backend.rpc('import_finish_batch', {
            'p_operation_id': operationId,
            'p_batch_id': batchId,
          })
          as Map,
    );
    if (r['status'] != 'completed') {
      throw SyncTransientError('Importação incompleta: $r');
    }
    return ImportBatch.fromRow(Map<String, dynamic>.from(r['batch'] as Map));
  }

  @override
  Future<UndoReport> undoPreview(String batchId) async => UndoReport.fromJson(
    Map<String, dynamic>.from(
      await _backend.rpc('import_undo_preview', {'p_batch_id': batchId}) as Map,
    ),
  );

  @override
  Future<UndoReport> undo(String batchId, {int limit = 200}) async =>
      UndoReport.fromJson(
        Map<String, dynamic>.from(
          await _backend.rpc('import_undo_batch', {
                'p_batch_id': batchId,
                'p_limit': limit,
              })
              as Map,
        ),
      );
}
