import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/infra_providers.dart';
import '../data/reference_rates.dart';
import '../domain/cash_or_installments_engine.dart';

/// Cache da taxa. Web: só em memória (dura enquanto o app está aberto);
/// celular: armazenamento seguro do aparelho (spec §10).
final cashOrInstallmentsRateCacheProvider = Provider<RateCache>((ref) {
  if (kIsWeb) return MemoryRateCache();
  return SecureRateCache(ref.watch(secureValueStoreProvider));
});

final cashOrInstallmentsRateRepositoryProvider =
    Provider<ReferenceRateRepository>(
      (ref) => ReferenceRateRepository(
        client: BcbRateClient(),
        cache: ref.watch(cashOrInstallmentsRateCacheProvider),
      ),
    );

/// Taxa de referência buscada ao abrir a ferramenta (uma vez por abertura).
final referenceRateProvider = FutureProvider.autoDispose
    .family<RateLookup, RateIndex>(
      (ref, index) =>
          ref.watch(cashOrInstallmentsRateRepositoryProvider).load(index),
    );

/// Resultado da última simulação; descartado ao sair da ferramenta.
class CashOrInstallmentsController extends Notifier<SimulationResult?> {
  @override
  SimulationResult? build() => null;

  void calculate(SimulationInput input) =>
      state = simulateCashOrInstallments(input);

  void clear() => state = null;
}

final cashOrInstallmentsProvider =
    NotifierProvider.autoDispose<
      CashOrInstallmentsController,
      SimulationResult?
    >(CashOrInstallmentsController.new);
