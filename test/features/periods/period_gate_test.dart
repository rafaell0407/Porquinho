import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/features/periods/period_gate.dart';
import 'package:porquinho/features/periods/period_providers.dart';

class _NeedsSetup extends PeriodGateNotifier {
  static PeriodConfig? saved;

  @override
  Future<bool> build() async => true;

  @override
  Future<void> setup(PeriodConfig config) async {
    saved = config;
    state = const AsyncData(false);
  }
}

void main() {
  Widget app(PeriodGateNotifier Function() gate) => ProviderScope(
    overrides: [
      periodGateProvider.overrideWith(gate),
      // 10/11/2026 em São Paulo.
      userClockProvider.overrideWithValue(
        UserClock(now: () => DateTime.utc(2026, 11, 10, 15)),
      ),
    ],
    child: const MaterialApp(
      home: PeriodGate(child: Scaffold(body: Text('App principal'))),
    ),
  );

  testWidgets('primeiro acesso mostra a escolha e a prévia do período', (
    tester,
  ) async {
    _NeedsSetup.saved = null;
    await tester.pumpWidget(app(_NeedsSetup.new));
    await tester.pumpAndSettle();

    expect(find.text('Seu período'), findsOneWidget);
    expect(
      find.text('Seu período atual: 01/11/2026 a 30/11/2026'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ciclo personalizado'));
    await tester.pumpAndSettle();
    expect(
      find.text('Seu período atual: 01/11/2026 a 30/11/2026'),
      findsOneWidget,
      reason: 'dia 1 equivale ao mês-calendário',
    );

    await tester.tap(find.byKey(const Key('dia-inicial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dia 5').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Seu período atual: 05/11/2026 a 04/12/2026'),
      findsOneWidget,
    );

    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    expect(_NeedsSetup.saved, PeriodConfig.customCycle(5));
    expect(find.text('App principal'), findsOneWidget);
  });

  testWidgets('conta já configurada vai direto ao app', (tester) async {
    await tester.pumpWidget(app(_Ready.new));
    await tester.pumpAndSettle();
    expect(find.text('App principal'), findsOneWidget);
    expect(find.text('Seu período'), findsNothing);
  });

  test('CalendarDate formata para o usuário', () {
    expect(CalendarDate(2026, 11, 1).toBr(), '01/11/2026');
  });
}

class _Ready extends PeriodGateNotifier {
  @override
  Future<bool> build() async => false;
}
