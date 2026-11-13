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
    );
    await periods.setup(PeriodConfig.calendarMonth());
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

  testWidgets('mostra a configuração atual e o período atual', (tester) async {
    await pump(tester);
    expect(find.text('Mês-calendário'), findsWidgets);
    expect(
      find.text(
        'Com esta configuração, o período atual vai de 01/11/2026 a '
        '30/11/2026. A mudança vale na hora para todos os períodos, passados '
        'e futuros.',
      ),
      findsOneWidget,
    );
    // Sem alteração, não há o que salvar; não existe mais histórico nem
    // mudança agendada.
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('salvar-mudanca')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('Histórico'), findsNothing);
  });

  testWidgets('troca na hora, depois de avisar que os totais podem mudar', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Ciclo personalizado'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dia-inicial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dia 20').last);
    await tester.pumpAndSettle();
    // Prévia já com a configuração escolhida.
    expect(find.textContaining('de 20/10/2026 a 19/11/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('salvar-mudanca')));
    await tester.pumpAndSettle();
    expect(find.text('Mudar a configuração?'), findsOneWidget);
    expect(
      find.textContaining('todos os períodos, inclusive os passados'),
      findsOneWidget,
    );
    expect(
      find.textContaining('totais de períodos antigos podem mudar'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirmar-mudanca')));
    await tester.pumpAndSettle();

    expect(await periods.currentConfig(), PeriodConfig.customCycle(20));
    expect(
      find.descendant(
        of: find.byKey(const Key('config-atual')),
        matching: find.text('Ciclo personalizado (dia 20)'),
      ),
      findsOneWidget,
    );
    expect(find.text('Configuração de período alterada.'), findsOneWidget);
    // Um período antigo já usa a nova configuração.
    expect(
      await periods.periodFor(d(2025, 3, 25)),
      PeriodRange(d(2025, 3, 20), d(2025, 4, 20)),
    );
  });

  testWidgets('voltar na confirmação não muda nada', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Ciclo personalizado'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar-mudanca')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(await periods.currentConfig(), PeriodConfig.calendarMonth());
  });
}
