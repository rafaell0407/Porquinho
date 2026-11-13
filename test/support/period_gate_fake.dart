import 'package:flutter_riverpod/misc.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/surplus.dart';
import 'package:porquinho/features/entries/entry_providers.dart';
import 'package:porquinho/features/investments/investment_providers.dart';
import 'package:porquinho/features/periods/period_navigation.dart';
import 'package:porquinho/features/periods/period_providers.dart';

/// Gate de períodos já resolvido, para testes que não tratam do primeiro acesso.
class ReadyPeriodGate extends PeriodGateNotifier {
  @override
  Future<bool> build() async => false;
}

/// Primeiro acesso resolvido e um período com sobra zero, para testes do app
/// inteiro (login, bloqueio, navegação) que não tratam de finanças.
List<Override> readyFinanceOverrides() {
  final november = PeriodRange(
    CalendarDate(2026, 11, 1),
    CalendarDate(2026, 12, 1),
  );
  return [
    periodGateProvider.overrideWith(ReadyPeriodGate.new),
    selectedPeriodProvider.overrideWith(
      (ref) async => PeriodView(
        range: november,
        bounds: PeriodBounds(november, november),
        config: PeriodConfig.calendarMonth(),
      ),
    ),
    periodTotalsProvider.overrideWith((ref) async => PeriodTotals.zero),
    periodEntriesProvider.overrideWith((ref) async => const []),
    periodInvestmentsProvider.overrideWith((ref) async => const []),
  ];
}
