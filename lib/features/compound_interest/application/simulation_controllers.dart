import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/compound_interest.dart';
import '../domain/simulation_math.dart';
import '../domain/withdrawal_simulation.dart';

/// Estado de uma simulação em memória: último resultado ou a mensagem de
/// erro do cálculo. Nada é gravado (nem banco, nem preferências).
@immutable
class SimulationOutcome<T> {
  const SimulationOutcome({this.result, this.error});

  final T? result;
  final String? error;

  bool get isEmpty => result == null && error == null;
}

/// Simulação principal. Descartada ao sair da ferramenta.
class CompoundInterestController
    extends Notifier<SimulationOutcome<CompoundInterestResult>> {
  @override
  SimulationOutcome<CompoundInterestResult> build() =>
      const SimulationOutcome();

  void calculate(CompoundInterestInput input) {
    try {
      state = SimulationOutcome(result: simulateCompoundInterest(input));
    } on SimulationException catch (e) {
      state = SimulationOutcome(error: e.message);
    }
  }

  void clear() => state = const SimulationOutcome();
}

final compoundInterestProvider =
    NotifierProvider.autoDispose<
      CompoundInterestController,
      SimulationOutcome<CompoundInterestResult>
    >(CompoundInterestController.new);

/// Simulação de retiradas, separada da principal (parâmetros próprios).
class WithdrawalController
    extends Notifier<SimulationOutcome<WithdrawalResult>> {
  @override
  SimulationOutcome<WithdrawalResult> build() => const SimulationOutcome();

  void calculate(WithdrawalInput input) {
    try {
      state = SimulationOutcome(result: simulateWithdrawals(input));
    } on SimulationException catch (e) {
      state = SimulationOutcome(error: e.message);
    }
  }

  void clear() => state = const SimulationOutcome();
}

final withdrawalProvider =
    NotifierProvider.autoDispose<
      WithdrawalController,
      SimulationOutcome<WithdrawalResult>
    >(WithdrawalController.new);
