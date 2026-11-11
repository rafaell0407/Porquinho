import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_models.dart';

/// Filtro simples de leitura direta das tabelas do usuário (Web e consultas
/// remotas). A política de leitura própria (RLS) isola os dados por usuário.
class RemoteFilter {
  const RemoteFilter.eq(this.column, this.value) : op = 'eq';
  const RemoteFilter.gte(this.column, this.value) : op = 'gte';
  const RemoteFilter.lt(this.column, this.value) : op = 'lt';

  final String column;
  final Object value;
  final String op;
}

abstract interface class RemoteTableReader {
  Future<List<Map<String, dynamic>>> select(
    String table, {
    List<RemoteFilter> filters = const [],
    String? orderBy,
  });
}

class SupabaseTableReader implements RemoteTableReader {
  SupabaseTableReader(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    List<RemoteFilter> filters = const [],
    String? orderBy,
  }) async {
    try {
      var query = _client.from(table).select();
      for (final f in filters) {
        query = switch (f.op) {
          'gte' => query.gte(f.column, f.value),
          'lt' => query.lt(f.column, f.value),
          _ => query.eq(f.column, f.value),
        };
      }
      final rows = orderBy == null
          ? await query.limit(1000)
          : await query.order(orderBy, ascending: true).limit(1000);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } on PostgrestException catch (e) {
      throw SyncTransientError(e.message);
    } catch (e) {
      throw SyncTransientError(e.toString());
    }
  }
}
