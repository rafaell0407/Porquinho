import '../sync/remote_table_reader.dart';
import '../sync/sync_models.dart';
import 'category_models.dart';
import 'category_repository.dart';

/// Web: lê e grava direto no servidor (somente online).
class RemoteCategoryRepository implements CategoryRepository {
  RemoteCategoryRepository(
    this._reader,
    this._gateway, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final RemoteTableReader _reader;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  @override
  Future<List<CategoryRecord>> categories() async {
    final rows = await _reader.select('categories', orderBy: 'name');
    return rows
        .map(
          (r) => CategoryRecord(
            id: r['id'] as String,
            kind: CategoryKind.fromDb(r['kind'] as String),
            name: r['name'] as String,
            isActive: r['is_active'] == true,
            version: (r['version'] as num).toInt(),
          ),
        )
        .toList();
  }

  @override
  Future<List<SubcategoryRecord>> subcategories() async {
    final rows = await _reader.select('subcategories', orderBy: 'name');
    return rows
        .map(
          (r) => SubcategoryRecord(
            id: r['id'] as String,
            categoryId: r['category_id'] as String,
            name: r['name'] as String,
            isActive: r['is_active'] == true,
            version: (r['version'] as num).toInt(),
          ),
        )
        .toList();
  }

  @override
  Future<void> apply(List<CategoryChange> changes) async {
    for (final change in changes) {
      final call = rpcCallFor(change);
      final Map<String, dynamic> response;
      try {
        response = await _gateway.call(call.rpc, {
          'p_operation_id': _newId(),
          ...call.params,
        });
      } on SyncRejectedError catch (e) {
        throw ChangeRejectedException(e.message);
      }
      if (response['status'] == 'conflict') {
        throw const ChangeConflictException();
      }
    }
  }
}
