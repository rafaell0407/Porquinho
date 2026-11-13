import 'package:drift/drift.dart';

import '../../core/local_database/app_database.dart';
import '../sync/local_change_recorder.dart';
import 'category_appearance.dart';
import 'category_models.dart';
import 'category_repository.dart';

/// Celular: cada alteração grava registro, auditoria e fila na mesma transação.
class LocalCategoryRepository implements CategoryRepository {
  LocalCategoryRepository(
    this._db,
    this._ownerId,
    this._recorder, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PorquinhoDatabase _db;
  final String _ownerId;
  final LocalChangeRecorder _recorder;
  final DateTime Function() _clock;

  @override
  Future<List<CategoryRecord>> categories() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM categories WHERE owner_id = ? ORDER BY name COLLATE NOCASE',
          variables: [Variable.withString(_ownerId)],
        )
        .get();
    return rows.map((r) {
      final d = r.data;
      return CategoryRecord(
        id: d['id']! as String,
        kind: CategoryKind.fromDb(d['kind']! as String),
        name: d['name']! as String,
        isActive: d['is_active'] == 1,
        version: d['version']! as int,
        iconKey: d['icon_key'] as String? ?? defaultCategoryIconKey,
        colorKey: d['color_key'] as String? ?? defaultCategoryColorKey,
      );
    }).toList();
  }

  @override
  Future<List<SubcategoryRecord>> subcategories() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM subcategories WHERE owner_id = ? ORDER BY name COLLATE NOCASE',
          variables: [Variable.withString(_ownerId)],
        )
        .get();
    return rows.map((r) {
      final d = r.data;
      return SubcategoryRecord(
        id: d['id']! as String,
        categoryId: d['category_id']! as String,
        name: d['name']! as String,
        isActive: d['is_active'] == 1,
        version: d['version']! as int,
      );
    }).toList();
  }

  @override
  Future<void> apply(List<CategoryChange> changes) => _db.transaction(() async {
    for (final change in changes) {
      await _applyOne(change);
    }
  });

  Future<void> _applyOne(CategoryChange change) {
    final call = rpcCallFor(change);
    final now = _clock().toUtc().toIso8601String();
    final next = call.expectedVersion + 1;
    final (oldSnapshot, newSnapshot) = _snapshots(change, next);
    return _recorder.record(
      ownerId: _ownerId,
      entityType: call.entityType,
      entityId: call.entityId,
      operation: call.operation,
      expectedVersion: call.expectedVersion,
      rpc: call.rpc,
      params: call.params,
      dependsOn: call.dependsOn,
      oldSnapshot: oldSnapshot,
      newSnapshot: newSnapshot,
      apply: () => switch (change) {
        CreateCategory(
          :final id,
          :final kind,
          :final name,
          :final iconKey,
          :final colorKey,
        ) =>
          _db.customStatement(
            'INSERT INTO categories (id, owner_id, version, created_at, '
            'updated_at, kind, name, is_active, icon_key, color_key) '
            'VALUES (?, ?, 1, ?, ?, ?, ?, 1, ?, ?)',
            [
              id,
              _ownerId,
              now,
              now,
              kind.dbValue,
              name,
              iconKey ?? defaultCategoryIconKey,
              colorKey ?? defaultCategoryColorKey,
            ],
          ),
        EditCategory(
          :final category,
          :final name,
          :final iconKey,
          :final colorKey,
        ) =>
          _update(
            'categories',
            category.id,
            [
              if (name != null) 'name = ?',
              if (iconKey != null) 'icon_key = ?',
              if (colorKey != null) 'color_key = ?',
            ].join(', '),
            [?name, ?iconKey, ?colorKey],
            next,
            now,
          ),
        RenameCategory(:final category, :final name) => _update(
          'categories',
          category.id,
          'name = ?',
          [name],
          next,
          now,
        ),
        DeactivateCategory(:final category) => _update(
          'categories',
          category.id,
          'is_active = 0',
          [],
          next,
          now,
        ),
        CreateSubcategory(:final id, :final categoryId, :final name) =>
          _db.customStatement(
            'INSERT INTO subcategories (id, owner_id, version, created_at, '
            'updated_at, category_id, name, is_active) '
            'VALUES (?, ?, 1, ?, ?, ?, ?, 1)',
            [id, _ownerId, now, now, categoryId, name],
          ),
        RenameSubcategory(:final subcategory, :final name) => _update(
          'subcategories',
          subcategory.id,
          'name = ?',
          [name],
          next,
          now,
        ),
        DeactivateSubcategory(:final subcategory) => _update(
          'subcategories',
          subcategory.id,
          'is_active = 0',
          [],
          next,
          now,
        ),
      },
    );
  }

  Future<void> _update(
    String table,
    String id,
    String set,
    List<Object?> args,
    int version,
    String now,
  ) => _db.customStatement(
    'UPDATE $table SET $set, version = ?, updated_at = ? '
    'WHERE owner_id = ? AND id = ?',
    [...args, version, now, _ownerId, id],
  );

  (Map<String, dynamic>?, Map<String, dynamic>) _snapshots(
    CategoryChange change,
    int next,
  ) => switch (change) {
    CreateCategory(
      :final id,
      :final kind,
      :final name,
      :final iconKey,
      :final colorKey,
    ) =>
      (
        null,
        {
          'id': id,
          'kind': kind.dbValue,
          'name': name,
          'is_active': true,
          'icon_key': iconKey ?? defaultCategoryIconKey,
          'color_key': colorKey ?? defaultCategoryColorKey,
          'version': 1,
        },
      ),
    EditCategory(
      :final category,
      :final name,
      :final iconKey,
      :final colorKey,
    ) =>
      (
        category.toSnapshot(),
        {
          ...category.toSnapshot(),
          'name': ?name,
          'icon_key': ?iconKey,
          'color_key': ?colorKey,
          'version': next,
        },
      ),
    RenameCategory(:final category, :final name) => (
      category.toSnapshot(),
      {...category.toSnapshot(), 'name': name, 'version': next},
    ),
    DeactivateCategory(:final category) => (
      category.toSnapshot(),
      {...category.toSnapshot(), 'is_active': false, 'version': next},
    ),
    CreateSubcategory(:final id, :final categoryId, :final name) => (
      null,
      {
        'id': id,
        'category_id': categoryId,
        'name': name,
        'is_active': true,
        'version': 1,
      },
    ),
    RenameSubcategory(:final subcategory, :final name) => (
      subcategory.toSnapshot(),
      {...subcategory.toSnapshot(), 'name': name, 'version': next},
    ),
    DeactivateSubcategory(:final subcategory) => (
      subcategory.toSnapshot(),
      {...subcategory.toSnapshot(), 'is_active': false, 'version': next},
    ),
  };
}
