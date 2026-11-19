import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/infra_providers.dart';
import '../sync/sync_models.dart';

/// Prévia de "Apagar todos os lançamentos" (RN056), lida no servidor.
class WipePreview {
  const WipePreview({
    required this.income,
    required this.expense,
    required this.investment,
    required this.templates,
    required this.openConflicts,
    required this.asOf,
  });

  factory WipePreview.fromJson(Map<String, dynamic> json) => WipePreview(
    income: _int(json['income']),
    expense: _int(json['expense']),
    investment: _int(json['investment']),
    templates: _int(json['templates']),
    openConflicts: _int(json['open_conflicts']),
    asOf: json['as_of'] as String,
  );

  final int income;
  final int expense;
  final int investment;

  /// Modelos de recorrência ativos (serão desativados).
  final int templates;
  final int openConflicts;

  /// Instante de corte devolvido pelo servidor: só o que existia até ele é
  /// apagado.
  final String asOf;

  int get entries => income + expense + investment;

  bool get isEmpty => entries == 0 && templates == 0;
}

/// Uma parte da execução no servidor.
class WipeStep {
  const WipeStep({
    required this.status,
    this.income = 0,
    this.expense = 0,
    this.investment = 0,
    this.templates = 0,
    this.openConflicts = 0,
  });

  factory WipeStep.fromJson(Map<String, dynamic> json) {
    final cancelled = Map<String, dynamic>.from(
      (json['cancelled'] as Map?) ?? const {},
    );
    return WipeStep(
      status: json['status'] as String,
      income: _int(cancelled['income']),
      expense: _int(cancelled['expense']),
      investment: _int(cancelled['investment']),
      templates: _int(json['deactivated_templates']),
      openConflicts: _int(json['open_conflicts']),
    );
  }

  /// `running` (falta algo), `done` ou `blocked` (conflito aberto).
  final String status;
  final int income;
  final int expense;
  final int investment;
  final int templates;
  final int openConflicts;
}

/// Acesso ao servidor (RPCs `wipe_entries_*`). Trocado por um falso nos testes.
abstract interface class WipeEntriesGateway {
  Future<WipePreview> preview();

  Future<WipeStep> run({
    required String operationId,
    required String asOf,
    required int limit,
  });
}

class SupabaseWipeEntriesGateway implements WipeEntriesGateway {
  SupabaseWipeEntriesGateway(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, Object?>? params,
  ]) async {
    try {
      final result = await _client.rpc(name, params: params);
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw SyncTransientError(e.message);
    } on SyncTransientError {
      rethrow;
    } catch (e) {
      throw SyncTransientError(e.toString());
    }
  }

  @override
  Future<WipePreview> preview() async =>
      WipePreview.fromJson(await _call('wipe_entries_preview'));

  @override
  Future<WipeStep> run({
    required String operationId,
    required String asOf,
    required int limit,
  }) async => WipeStep.fromJson(
    await _call('wipe_entries_run', {
      'p_operation_id': operationId,
      'p_as_of': asOf,
      'p_limit': limit,
    }),
  );
}

final wipeEntriesGatewayProvider = Provider<WipeEntriesGateway>(
  (ref) => SupabaseWipeEntriesGateway(ref.watch(supabaseClientProvider)),
);

int _int(Object? value) => switch (value) {
  null => 0,
  num n => n.toInt(),
  _ => int.parse(value.toString()),
};
