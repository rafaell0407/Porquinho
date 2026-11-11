import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_models.dart';

/// Chama as RPCs do Supabase e classifica as falhas.
///
/// Recusa definitiva: violação de dados/regras (SQLSTATE 22xxx, 23xxx,
/// `P0002`/no_data_found). Todo o resto (rede, sessão, servidor, 40001) é
/// transitório e será reenviado.
class SupabaseSyncGateway implements SyncRemoteGateway {
  SupabaseSyncGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await _client.rpc(rpc, params: params);
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      if (isDefinitiveRejection(e.code)) {
        throw SyncRejectedError(e.message);
      }
      throw SyncTransientError(e.message);
    } catch (e) {
      throw SyncTransientError(e.toString());
    }
  }

  static bool isDefinitiveRejection(String? sqlState) =>
      sqlState != null &&
      (sqlState.startsWith('22') ||
          sqlState.startsWith('23') ||
          sqlState == 'P0002');
}
