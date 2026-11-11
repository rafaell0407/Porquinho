@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/calendar_date.dart';
import 'package:porquinho/core/domain/period_calendar.dart';
import 'package:porquinho/core/domain/user_clock.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/periods/local_period_repository.dart';
import 'package:porquinho/features/periods/period_providers.dart';
import 'package:porquinho/features/periods/period_service.dart';
import 'package:porquinho/features/periods/period_settings_screen.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);

void main() {
  late PorquinhoDatabase db;
  late PeriodService periods;
  var ids = 0;

  setUp(() async {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    periods = PeriodService(
      LocalPeriodRepository(
        db,
        'u1',
        LocalChangeRecorder(db, newId: () => 'a${++ids}'),
      ),
      newId: () => 'p${++ids}',
    );
    await periods.setup(PeriodConfig.calendarMonth(), d(2026, 11, 10));
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userClockProvider.overrideWithValue(
            UserClock(now: () => DateTime.utc(2026, 11, 10, 15)),
          ),
          periodServiceProvider.overrideWith((ref) async => periods),
        ],
        child: const MaterialApp(home: PeriodSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra a configuração atual, a data de início e o histórico', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Mês-calendário'), findsWidgets);
    expect(
      find.text(
        'A nova configuração começa em 01/12/2026. O período atual não muda.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('historico-2026-11-01')), findsOneWidget);
    expect(find.byKey(const Key('mudanca-agendada')), findsNothing);
    // Sem alteração, não há o que salvar.
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('salvar-mudanca')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('agenda, confirma com a data e mostra a mudança agendada', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Ciclo personalizado'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar-mudanca')));
    await tester.pumpAndSettle();
    expect(find.text('Mudar a configuração?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar-mudanca')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mudanca-agendada')), findsOneWidget);
    expect(find.textContaining('Começa em 01/12/2026'), findsOneWidget);
    // O período atual e o histórico continuam iguais.
    expect(find.byKey(const Key('historico-2026-11-01')), findsOneWidget);
    expect(find.byKey(const Key('config-atual')), findsOneWidget);
    expect(
      (await periods.scheduledChange())!.config.mode,
      PeriodMode.customCycle,
    );
  });

  testWidgets('voltar na confirmação não agenda nada', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Ciclo personalizado'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar-mudanca')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(await periods.scheduledChange(), isNull);
  });

  testWidgets('cancelar a mudança agendada', (tester) async {
    await periods.scheduleChange(PeriodConfig.customCycle(20), d(2026, 11, 10));
    await pump(tester);
    expect(find.byKey(const Key('mudanca-agendada')), findsOneWidget);
    expect(find.textContaining('Ciclo personalizado (dia 20)'), findsWidgets);

    await tester.tap(find.byKey(const Key('cancelar-mudanca')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mudanca-agendada')), findsNothing);
    expect(await periods.scheduledChange(), isNull);
  });

  testWidgets('histórico mostra a configuração de cada período', (
    tester,
  ) async {
    await periods.scheduleChange(PeriodConfig.customCycle(20), d(2026, 11, 10));
    await periods.ensureUpTo(d(2026, 12, 25));
    await pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('historico-2026-12-01')),
        matching: find.text('Ciclo personalizado (dia 20)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('historico-2026-11-01')),
        matching: find.text('Mês-calendário'),
      ),
      findsOneWidget,
    );
  });
}
