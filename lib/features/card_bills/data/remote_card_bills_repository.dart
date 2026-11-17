import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sync/supabase_sync_gateway.dart';
import '../../sync/sync_models.dart';
import '../domain/card_bill_models.dart';
import '../domain/change_set.dart';
import 'card_bills_repository.dart';
import 'card_bills_rows.dart';

/// Leitura das tabelas da ferramenta no servidor (política de leitura própria).
abstract interface class CardBillsRemoteSource {
  /// Todas as linhas do usuário na [table]. Falhas: [SyncTransientError].
  Future<List<Map<String, dynamic>>> fetchAll(String table);
}

class SupabaseCardBillsSource implements CardBillsRemoteSource {
  SupabaseCardBillsSource(this._client, {this.pageSize = 1000});

  final SupabaseClient _client;
  final int pageSize;

  @override
  Future<List<Map<String, dynamic>>> fetchAll(String table) async {
    final all = <Map<String, dynamic>>[];
    try {
      for (var from = 0; ; from += pageSize) {
        final page = await _client
            .from(table)
            .select()
            .order('id', ascending: true)
            .range(from, from + pageSize - 1);
        all.addAll(page.map((r) => Map<String, dynamic>.from(r)));
        if (page.length < pageSize) break;
      }
    } on PostgrestException catch (e) {
      throw SyncTransientError(e.message);
    } catch (e) {
      throw SyncTransientError(e.toString());
    }
    return all;
  }
}

/// Lê tudo do servidor e monta os dados.
Future<CardBillsData> loadRemote(CardBillsRemoteSource source) async {
  final rows = <String, List<Map<String, Object?>>>{};
  for (final table in CardBillTables.ordered) {
    rows[table] = [
      for (final r in await source.fetchAll(table)) knownColumns(table, r),
    ];
  }
  return dataFromRows(rows);
}

/// Web: lê e grava direto no servidor (somente online).
class RemoteCardBillsRepository implements CardBillsRepository {
  RemoteCardBillsRepository(
    this._source,
    this._gateway, {
    String Function()? newId,
  }) : _newId = newId ?? newUuid;

  final CardBillsRemoteSource _source;
  final SyncRemoteGateway _gateway;
  final String Function() _newId;

  @override
  Future<CardBillsData> load() => loadRemote(_source);

  Future<Map<String, dynamic>> _call(String rpc, Map<String, dynamic> params) =>
      _gateway.call(rpc, {'p_operation_id': _newId(), ...params});

  @override
  Future<void> apply(CardBillsChange change) async {
    if (change.isEmpty) return;
    final r = await _call(CardBillsRpc.apply, applyParams(change));
    if (r['status'] != 'applied') {
      throw const SyncRejectedError('Não foi possível salvar.');
    }
  }

  @override
  Future<void> pay(PayInvoiceCommand command) async {
    final r = await _call(CardBillsRpc.pay, payParams(command));
    if (r['status'] == 'conflict') {
      throw DuplicatePaymentException(
        InvoiceRecord.fromRow(
          Map<String, Object?>.from(r['remote_invoice'] as Map),
        ),
      );
    }
    if (r['status'] != 'applied') {
      throw const SyncRejectedError('Não foi possível registrar o pagamento.');
    }
  }

  @override
  Future<void> undo(UndoPaymentCommand command) async {
    final r = await _call(CardBillsRpc.undo, undoParams(command));
    if (r['status'] != 'applied') {
      throw const SyncRejectedError('Não foi possível desfazer o pagamento.');
    }
  }
}

/// Atalho para montar o repositório da Web com o cliente do Supabase.
RemoteCardBillsRepository supabaseCardBillsRepository(SupabaseClient client) =>
    RemoteCardBillsRepository(
      SupabaseCardBillsSource(client),
      SupabaseSyncGateway(client),
    );
