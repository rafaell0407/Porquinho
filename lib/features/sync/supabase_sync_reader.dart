import 'package:supabase_flutter/supabase_flutter.dart';

import 'download_service.dart';
import 'supabase_sync_gateway.dart';
import 'sync_models.dart';

/// Lê as linhas do usuário pela política de leitura própria (RLS) do Supabase.
/// Todo erro de leitura é tratado como transitório: a rodada é interrompida e
/// repetida depois (a gravação local é idempotente).
class SupabaseSyncReader implements SyncRemoteReader {
  SupabaseSyncReader(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> fetchPreferences(String ownerId) async {
    try {
      final row = await _client
          .from('user_preferences')
          .select()
          .eq('owner_id', ownerId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } on PostgrestException catch (e) {
      throw _classify(e);
    } catch (e) {
      throw SyncTransientError(e.toString());
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required String ownerId,
    required String orderColumn,
    String? afterOrder,
    String? afterId,
    required int limit,
  }) async {
    try {
      var query = _client.from(table).select().eq('owner_id', ownerId);
      if (afterOrder != null) {
        final value = _filterValue(afterOrder);
        query = afterId == null
            ? query.gte(orderColumn, value)
            : query.or(
                '$orderColumn.gt.$value,'
                'and($orderColumn.eq.$value,id.gt.$afterId)',
              );
      }
      final rows = await query
          .order(orderColumn, ascending: true)
          .order('id', ascending: true)
          .limit(limit);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } on PostgrestException catch (e) {
      throw _classify(e);
    } catch (e) {
      throw SyncTransientError(e.toString());
    }
  }

  SyncTransientError _classify(PostgrestException e) =>
      SupabaseSyncGateway.isDefinitiveRejection(e.code)
      ? SyncTransientError('Leitura recusada: ${e.message}')
      : SyncTransientError(e.message);

  /// Formato UTC com `Z` (o `+` de `+00:00` precisaria de codificação na URL).
  static String _filterValue(String timestamp) => timestamp.endsWith('+00:00')
      ? '${timestamp.substring(0, timestamp.length - 6)}Z'
      : DateTime.parse(timestamp).toUtc().toIso8601String();
}
