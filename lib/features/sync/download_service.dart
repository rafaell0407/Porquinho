import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/local_database/app_database.dart';
import 'sync_models.dart';

/// Leitura das linhas do servidor (a implementação real usa a política de
/// leitura própria do Supabase; nenhuma RPC nova).
abstract interface class SyncRemoteReader {
  /// Linha de `user_preferences` do usuário, ou `null`.
  Future<Map<String, dynamic>?> fetchPreferences(String ownerId);

  /// Uma página ordenada por ([orderColumn], `id`).
  ///
  /// - [afterId] nulo: linhas com `orderColumn >= afterOrder` (ou todas, se
  ///   [afterOrder] for nulo);
  /// - [afterId] informado: linhas depois de ([afterOrder], [afterId]).
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required String ownerId,
    required String orderColumn,
    String? afterOrder,
    String? afterId,
    required int limit,
  });
}

enum _Kind { text, integer, boolean, amount }

class _Col {
  const _Col(this.name, [this.kind = _Kind.text]);
  final String name;
  final _Kind kind;
}

class _TableSpec {
  const _TableSpec(this.table, this.entityType, this.columns);

  final String table;

  /// Tipo da entidade na fila de envio (para não sobrescrever pendências).
  final String entityType;
  final List<_Col> columns;
}

const _common = [
  _Col('version', _Kind.integer),
  _Col('created_at'),
  _Col('updated_at'),
];

const _templateColumns = [
  _Col('description'),
  _Col('frequency'),
  _Col('starts_on'),
  _Col('monthly_reference_day', _Kind.integer),
  _Col('value_mode'),
  _Col('default_amount_centavos', _Kind.amount),
  _Col('category_id'),
  _Col('subcategory_id'),
  _Col('is_active', _Kind.boolean),
];

/// Ordem de dependência: cada tabela só referencia as anteriores.
const _specs = [
  _TableSpec('period_configurations', 'period_configuration', [
    _Col('mode'),
    _Col('custom_start_day', _Kind.integer),
    _Col('effective_from'),
    ..._common,
  ]),
  _TableSpec('accounting_periods', 'accounting_period', [
    _Col('configuration_id'),
    _Col('start_date'),
    _Col('end_date'),
    ..._common,
  ]),
  _TableSpec('categories', 'category', [
    _Col('kind'),
    _Col('name'),
    _Col('is_active', _Kind.boolean),
    ..._common,
  ]),
  _TableSpec('subcategories', 'subcategory', [
    _Col('category_id'),
    _Col('name'),
    _Col('is_active', _Kind.boolean),
    ..._common,
  ]),
  _TableSpec('income_recurrence_templates', 'income_recurrence_template', [
    ..._templateColumns,
    ..._common,
  ]),
  _TableSpec('expense_recurrence_templates', 'expense_recurrence_template', [
    ..._templateColumns,
    ..._common,
  ]),
  _TableSpec('income_entries', 'income_entry', [
    _Col('description'),
    _Col('amount_centavos', _Kind.amount),
    _Col('status'),
    _Col('received_on'),
    _Col('category_id'),
    _Col('subcategory_id'),
    _Col('accounting_period_id'),
    _Col('recurrence_template_id'),
    _Col('scheduled_for_date'),
    _Col('scheduled_period_id'),
    ..._common,
  ]),
  _TableSpec('expense_entries', 'expense_entry', [
    _Col('description'),
    _Col('amount_centavos', _Kind.amount),
    _Col('status'),
    _Col('competence_on'),
    _Col('due_on'),
    _Col('paid_on'),
    _Col('category_id'),
    _Col('subcategory_id'),
    _Col('accounting_period_id'),
    _Col('recurrence_template_id'),
    _Col('scheduled_for_date'),
    _Col('scheduled_period_id'),
    ..._common,
  ]),
  _TableSpec('investment_allocations', 'investment_allocation', [
    _Col('amount_centavos', _Kind.amount),
    _Col('allocated_on'),
    _Col('accounting_period_id'),
    _Col('cancelled_at'),
    ..._common,
  ]),
];

const _auditTable = 'audit_events';

/// Resultado de uma rodada de download.
class DownloadResult {
  const DownloadResult({
    this.applied = 0,
    this.skippedPending = 0,
    this.completed = true,
  });

  /// Linhas novas ou atualizadas gravadas no aparelho.
  final int applied;

  /// Linhas ignoradas porque há operação local pendente para o mesmo registro.
  final int skippedPending;

  /// `false` se a rodada parou no meio (falha de rede ou de gravação).
  final bool completed;
}

/// Download dos dados da conta para o aparelho (Entrega 27B; proposta 27A).
///
/// - Leitura incremental por tabela, na ordem de dependência, em páginas, a
///   partir do cursor guardado em `sync_cursors`.
/// - Gravação idempotente: só grava se a versão do servidor for maior que a
///   local. Repetir o download não duplica nem altera nada.
/// - Registro com operação pendente na fila local nunca é sobrescrito; quando
///   a operação for enviada, o servidor detecta a divergência e gera o
///   conflito pelo fluxo normal.
/// - O cursor recua [overlap] a cada rodada para não perder linhas gravadas
///   no servidor por transações que terminaram depois de outras.
/// - O histórico de auditoria é baixado sem duplicar eventos já criados neste
///   aparelho (mesma operação, registro e tipo).
class DownloadService {
  DownloadService(
    this._db,
    this._reader, {
    this.pageSize = 500,
    this.overlap = const Duration(minutes: 2),
  });

  final PorquinhoDatabase _db;
  final SyncRemoteReader _reader;
  final int pageSize;
  final Duration overlap;

  /// Baixa tudo o que mudou. Falhas de rede interrompem a rodada sem erro
  /// (volta a tentar na próxima); o cursor só avança em páginas já gravadas.
  Future<DownloadResult> downloadAll(String ownerId) async {
    var applied = 0;
    var skipped = 0;
    try {
      final prefs = await _reader.fetchPreferences(ownerId);
      if (prefs != null) applied += await _applyPreferences(ownerId, prefs);
      for (final spec in _specs) {
        final r = await _downloadTable(ownerId, spec);
        applied += r.$1;
        skipped += r.$2;
      }
      applied += await _downloadAudit(ownerId);
    } on SyncTransientError {
      return DownloadResult(
        applied: applied,
        skippedPending: skipped,
        completed: false,
      );
    }
    return DownloadResult(applied: applied, skippedPending: skipped);
  }

  // --- cursor ---------------------------------------------------------

  Future<({String order, String? id})?> _cursor(
    String ownerId,
    String table,
  ) async {
    final row = await _db
        .customSelect(
          'SELECT last_order_value, last_id FROM sync_cursors '
          'WHERE owner_id = ? AND source_table = ?',
          variables: [Variable.withString(ownerId), Variable.withString(table)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (
      order: row.read<String>('last_order_value'),
      id: row.read<String?>('last_id'),
    );
  }

  Future<void> _saveCursor(
    String ownerId,
    String table,
    String order,
    String? id,
  ) => _db.customStatement(
    'INSERT INTO sync_cursors (owner_id, source_table, last_order_value, '
    'last_id) VALUES (?, ?, ?, ?) '
    'ON CONFLICT (owner_id, source_table) DO UPDATE SET '
    'last_order_value = excluded.last_order_value, last_id = excluded.last_id',
    [ownerId, table, order, id],
  );

  /// Instante inicial da leitura: cursor recuado pela margem de segurança.
  String? _startFor(({String order, String? id})? cursor) {
    if (cursor == null) return null;
    return DateTime.parse(
      cursor.order,
    ).toUtc().subtract(overlap).toIso8601String();
  }

  /// `true` se ([order], [id]) vem depois do cursor guardado.
  bool _isAfter(({String order, String? id})? cursor, String order, String id) {
    if (cursor == null) return true;
    final a = DateTime.parse(order).toUtc();
    final b = DateTime.parse(cursor.order).toUtc();
    if (a != b) return a.isAfter(b);
    return cursor.id == null || id.compareTo(cursor.id!) > 0;
  }

  /// Grava o registro devolvido pelo servidor ao resolver um conflito, mesmo
  /// que a versão local seja igual: a versão do aparelho que não foi escolhida
  /// fica preservada no histórico do conflito, e o registro passa a refletir
  /// a decisão do usuário.
  Future<void> adoptResolvedRecord(
    String ownerId,
    String entityType,
    String localEntityId,
    Map<String, dynamic> row,
  ) async {
    final spec = _specs.firstWhere(
      (s) => s.entityType == entityType,
      orElse: () => throw ArgumentError('Tipo sem tabela: $entityType'),
    );
    await _db.transaction(() async {
      final remoteId = row['id'] as String;
      if (remoteId != localEntityId) {
        // Conflito de criação (ex.: mesmo período criado em dois aparelhos):
        // o registro do servidor substitui o local e quem o referenciava passa
        // a apontar para ele.
        await _remapReferences(ownerId, spec.table, localEntityId, remoteId);
        await _db.customStatement(
          'DELETE FROM ${spec.table} WHERE owner_id = ? AND id = ?',
          [ownerId, localEntityId],
        );
      }
      await _upsert(ownerId, spec, row, force: true);
    });
  }

  Future<void> _remapReferences(
    String ownerId,
    String table,
    String fromId,
    String toId,
  ) async {
    const references = {
      'accounting_periods': [
        ('income_entries', 'accounting_period_id'),
        ('income_entries', 'scheduled_period_id'),
        ('expense_entries', 'accounting_period_id'),
        ('expense_entries', 'scheduled_period_id'),
        ('investment_allocations', 'accounting_period_id'),
      ],
      'period_configurations': [('accounting_periods', 'configuration_id')],
    };
    for (final (refTable, column) in references[table] ?? const []) {
      await _db.customStatement(
        'UPDATE $refTable SET $column = ? WHERE owner_id = ? AND $column = ?',
        [toId, ownerId, fromId],
      );
    }
  }

  // --- tabelas comuns ---------------------------------------------------

  Future<(int, int)> _downloadTable(String ownerId, _TableSpec spec) async {
    var cursor = await _cursor(ownerId, spec.table);
    var afterOrder = _startFor(cursor);
    String? afterId;
    var applied = 0;
    var skipped = 0;
    while (true) {
      final page = await _reader.fetchPage(
        spec.table,
        ownerId: ownerId,
        orderColumn: 'updated_at',
        afterOrder: afterOrder,
        afterId: afterId,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      final last = page.last;
      final lastOrder = last['updated_at'] as String;
      final lastId = last['id'] as String;
      final result = await _db.transaction(() async {
        final pending = await _pendingIds(ownerId, spec.entityType);
        var a = 0;
        var s = 0;
        for (final row in page) {
          if (pending.contains(row['id'])) {
            s++;
            continue;
          }
          if (await _upsert(ownerId, spec, row)) a++;
        }
        if (_isAfter(cursor, lastOrder, lastId)) {
          await _saveCursor(ownerId, spec.table, lastOrder, lastId);
          cursor = (order: lastOrder, id: lastId);
        }
        return (a, s);
      });
      applied += result.$1;
      skipped += result.$2;
      if (page.length < pageSize) break;
      afterOrder = lastOrder;
      afterId = lastId;
    }
    return (applied, skipped);
  }

  Future<Set<String>> _pendingIds(String ownerId, String entityType) async {
    final rows = await _db
        .customSelect(
          'SELECT entity_id FROM sync_outbox '
          'WHERE owner_id = ? AND entity_type = ?',
          variables: [
            Variable.withString(ownerId),
            Variable.withString(entityType),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('entity_id')).toSet();
  }

  Object? _convert(_Col col, Object? value) {
    if (value == null) return null;
    switch (col.kind) {
      case _Kind.text:
        return value.toString();
      case _Kind.integer:
        return value is int ? value : int.parse(value.toString());
      case _Kind.boolean:
        return value == true || value == 1 ? 1 : 0;
      case _Kind.amount:
        return value.toString();
    }
  }

  /// Grava a linha se for nova ou de versão maior. Devolve se gravou.
  Future<bool> _upsert(
    String ownerId,
    _TableSpec spec,
    Map<String, dynamic> row, {
    bool force = false,
  }) async {
    final names = ['id', 'owner_id', ...spec.columns.map((c) => c.name)];
    final values = <Object?>[
      row['id'],
      ownerId,
      for (final c in spec.columns) _convert(c, row[c.name]),
    ];
    final updates = names
        .where((n) => n != 'id' && n != 'owner_id')
        .map((n) => '$n = excluded.$n')
        .join(', ');
    final before = await _changes();
    await _db.customStatement(
      'INSERT INTO ${spec.table} (${names.join(', ')}) '
      'VALUES (${List.filled(names.length, '?').join(', ')}) '
      'ON CONFLICT (owner_id, id) DO UPDATE SET $updates '
      '${force ? '' : 'WHERE excluded.version > ${spec.table}.version'}',
      values,
    );
    return await _changes() != before;
  }

  /// Contador acumulado de linhas alteradas na conexão (para saber se o upsert
  /// gravou ou foi ignorado pela guarda de versão).
  Future<int> _changes() async =>
      (await _db.customSelect('SELECT total_changes() AS n').getSingle())
          .read<int>('n');

  // --- preferências -----------------------------------------------------

  Future<int> _applyPreferences(
    String ownerId,
    Map<String, dynamic> row,
  ) async {
    final before = await _changes();
    await _db.customStatement(
      'INSERT INTO user_preferences (owner_id, theme, time_zone_id, version, '
      'updated_at) VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT (owner_id) DO UPDATE SET theme = excluded.theme, '
      'time_zone_id = excluded.time_zone_id, version = excluded.version, '
      'updated_at = excluded.updated_at '
      'WHERE excluded.version > user_preferences.version',
      [
        ownerId,
        row['theme'],
        row['time_zone_id'] ?? 'America/Sao_Paulo',
        row['version'],
        row['updated_at'],
      ],
    );
    return await _changes() != before ? 1 : 0;
  }

  // --- auditoria ----------------------------------------------------------

  Future<int> _downloadAudit(String ownerId) async {
    var cursor = await _cursor(ownerId, _auditTable);
    var afterOrder = _startFor(cursor);
    String? afterId;
    var applied = 0;
    while (true) {
      final page = await _reader.fetchPage(
        _auditTable,
        ownerId: ownerId,
        orderColumn: 'occurred_at',
        afterOrder: afterOrder,
        afterId: afterId,
        limit: pageSize,
      );
      if (page.isEmpty) break;
      final last = page.last;
      final lastOrder = last['occurred_at'] as String;
      final lastId = last['id'] as String;
      applied += await _db.transaction(() async {
        var a = 0;
        for (final row in page) {
          if (await _insertAudit(ownerId, row)) a++;
        }
        if (_isAfter(cursor, lastOrder, lastId)) {
          await _saveCursor(ownerId, _auditTable, lastOrder, lastId);
          cursor = (order: lastOrder, id: lastId);
        }
        return a;
      });
      if (page.length < pageSize) break;
      afterOrder = lastOrder;
      afterId = lastId;
    }
    return applied;
  }

  String? _json(Object? value) => value == null ? null : jsonEncode(value);

  /// Insere o evento se ainda não existir (mesmo `id`, ou mesma operação,
  /// registro e tipo já gravados localmente pelo próprio aparelho).
  Future<bool> _insertAudit(String ownerId, Map<String, dynamic> row) async {
    final before = await _changes();
    final occurred = row['occurred_at'];
    await _db.customStatement(
      'INSERT OR IGNORE INTO audit_events (id, owner_id, version, created_at, '
      'updated_at, entity_type, entity_id, operation, actor_id, occurred_at, '
      'old_snapshot_json, new_snapshot_json, operation_id) '
      'SELECT ?1, ?2, 1, ?3, ?3, ?4, ?5, ?6, ?7, ?3, ?8, ?9, ?10 '
      'WHERE NOT EXISTS (SELECT 1 FROM audit_events WHERE owner_id = ?2 '
      'AND operation_id = ?10 AND entity_id = ?5 AND operation = ?6)',
      [
        row['id'],
        ownerId,
        occurred,
        row['entity_type'],
        row['entity_id'],
        row['operation'],
        row['actor_id'],
        _json(row['previous_values']),
        _json(row['new_values']),
        row['operation_id'] ?? row['id'],
      ],
    );
    return await _changes() != before;
  }
}
