@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/data_access.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/onboarding/onboarding_screen.dart';
import 'package:porquinho/features/preferences/preferences_providers.dart';
import 'package:porquinho/features/preferences/preferences_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

class _Gateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc, params));
    return {'status': 'applied'};
  }
}

class _Reader implements RemoteTableReader {
  List<Map<String, dynamic>> rows = [];

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    List<RemoteFilter> filters = const [],
    String? orderBy,
  }) async => rows;
}

class _DownloadReader implements SyncRemoteReader {
  Map<String, dynamic>? preferences;

  @override
  Future<Map<String, dynamic>?> fetchPreferences(String ownerId) async =>
      preferences;

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required String ownerId,
    required String orderColumn,
    String? afterOrder,
    String? afterId,
    required int limit,
  }) async => [];
}

void main() {
  late PorquinhoDatabase db;
  late LocalPreferencesRepository repo;
  var ids = 0;

  setUp(() {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    repo = LocalPreferencesRepository(
      db,
      'u1',
      LocalChangeRecorder(db, newId: () => 'a${++ids}'),
      clock: () => DateTime.utc(2026, 11, 12),
    );
  });
  tearDown(() => db.close());

  group('repositório local', () {
    test('começa vazio e acumula etapas sem apagar o tema', () async {
      expect(await repo.onboarding(), isEmpty);
      await repo.setTheme('dark');
      await repo.setOnboardingStep('intro', 'done');
      await repo.setOnboardingStep('theme', 'skipped');
      expect(await repo.onboarding(), {'intro': 'done', 'theme': 'skipped'});
      expect(await repo.theme(), 'dark');
    });

    test('sobe pela fila uma vez e não duplica', () async {
      await repo.setOnboardingStep('intro', 'done');
      final gateway = _Gateway();
      final sync = SyncService(db, gateway);
      expect(await sync.syncOnce('u1'), 1);
      expect(gateway.calls.single.$1, 'set_onboarding_step');
      expect(gateway.calls.single.$2['p_step'], 'intro');
      expect(gateway.calls.single.$2['p_status'], 'done');
      expect(await sync.syncOnce('u1'), 0);
    });

    test('segundo aparelho recebe o progresso no download', () async {
      final reader = _DownloadReader()
        ..preferences = {
          'theme': null,
          'time_zone_id': 'America/Sao_Paulo',
          'onboarding': {'intro': 'done', 'categories': 'skipped'},
          'version': 2,
          'updated_at': '2026-11-12T10:00:00Z',
        };
      await DownloadService(db, reader).downloadAll('u1');
      expect(await repo.onboarding(), {
        'intro': 'done',
        'categories': 'skipped',
      });
    });
  });

  group('Web (servidor)', () {
    test('lê o progresso e grava pela função do servidor', () async {
      final reader = _Reader();
      final gateway = _Gateway();
      final web = RemotePreferencesRepository(
        reader,
        gateway,
        newId: () => 'op',
      );
      expect(await web.onboarding(), isEmpty);
      await web.setOnboardingStep('theme', 'done');
      expect(gateway.calls.single.$1, 'set_onboarding_step');
      expect(gateway.calls.single.$2, {
        'p_operation_id': 'op',
        'p_step': 'theme',
        'p_status': 'done',
      });
      reader.rows = [
        {
          'onboarding': {'theme': 'done'},
        },
      ];
      expect(await web.onboarding(), {'theme': 'done'});
    });
  });

  group('assistente', () {
    var exited = 0;

    Future<void> pump(WidgetTester tester) async {
      exited = 0;
      await tester.pumpWidget(const SizedBox()); // desmonta (reabrir)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWith((ref) async => repo),
            dataAccessModeProvider.overrideWithValue(DataAccessMode.local),
          ],
          child: MaterialApp(home: OnboardingScreen(onExit: () => exited++)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> skipCategories(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Agora não'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Agora não'));
    }

    testWidgets('pular tudo grava cada etapa e não repete depois', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Como o Porquinho funciona'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-pular')));
      await tester.pumpAndSettle();
      // Categorias: "Agora não".
      await skipCategories(tester);
      await tester.pumpAndSettle();
      // Tema, segurança e recorrências.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('onboarding-pular')));
        await tester.pumpAndSettle();
      }
      expect(exited, 1);
      final saved = await repo.onboarding();
      expect(saved.length, 5);
      expect(saved.values.toSet(), {'skipped'});

      // Reabrir (Mais → Configuração inicial): nada pendente.
      await pump(tester);
      expect(find.byKey(const Key('onboarding-vazio')), findsOneWidget);
    });

    testWidgets('concluir depois sai sem gravar e retoma depois', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('onboarding-avancar')));
      await tester.pumpAndSettle();
      await skipCategories(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-depois')));
      await tester.pumpAndSettle();
      expect(exited, 1);
      expect(await repo.onboarding(), {
        'intro': 'done',
        'categories': 'skipped',
      });

      // Retomar: começa pelo tema, as duas primeiras não voltam.
      await pump(tester);
      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Como o Porquinho funciona'), findsNothing);
    });
  });
}
