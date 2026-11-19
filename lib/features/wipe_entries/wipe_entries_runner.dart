import '../sync/sync_models.dart';
import 'wipe_entries_gateway.dart';

/// Resultado de uma execução completa.
sealed class WipeOutcome {
  const WipeOutcome();
}

/// Tudo até o corte foi apagado.
class WipeDone extends WipeOutcome {
  const WipeDone({
    required this.income,
    required this.expense,
    required this.investment,
    required this.templates,
  });

  final int income;
  final int expense;
  final int investment;
  final int templates;

  int get entries => income + expense + investment;
}

/// O servidor recusou: há conflito de sincronização aberto.
class WipeBlocked extends WipeOutcome {
  const WipeBlocked(this.openConflicts);

  final int openConflicts;
}

/// Executa no servidor em partes até terminar (RN056). Repetir com a mesma
/// operação é seguro: o que já foi apagado não é tocado de novo.
class WipeEntriesRunner {
  WipeEntriesRunner(this._gateway, {this.limit = 200, this.maxSteps = 10000});

  final WipeEntriesGateway _gateway;
  final int limit;

  /// Proteção contra um servidor que nunca conclua.
  final int maxSteps;

  Future<WipeOutcome> run({
    required String operationId,
    required String asOf,
    void Function(int done)? onProgress,
  }) async {
    var income = 0;
    var expense = 0;
    var investment = 0;
    var templates = 0;
    for (var i = 0; i < maxSteps; i++) {
      final step = await _gateway.run(
        operationId: operationId,
        asOf: asOf,
        limit: limit,
      );
      if (step.status == 'blocked') return WipeBlocked(step.openConflicts);
      income += step.income;
      expense += step.expense;
      investment += step.investment;
      templates += step.templates;
      onProgress?.call(income + expense + investment);
      if (step.status == 'done') {
        return WipeDone(
          income: income,
          expense: expense,
          investment: investment,
          templates: templates,
        );
      }
      if (step.status != 'running') {
        throw SyncTransientError('Resposta inesperada: ${step.status}');
      }
    }
    throw const SyncTransientError('A exclusão não terminou.');
  }
}
