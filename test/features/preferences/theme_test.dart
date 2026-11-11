@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/data_access.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/preferences/preferences_providers.dart';
import 'package:porquinho/features/preferences/preferences_repository.dart';
import 'package:porquinho/features/preferences/theme_screen.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_providers.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/sync/sync_status.dart';

class _Gateway implements SyncRemoteGateway {
  final calls = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc, params));
    return {
      'status': 'applied',
      'preferences': {'owner_id': 'u1', 'version': calls.length},
    };
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

  group('celular (banco local)', () {
    test('sem escolha, o tema é nulo (segue o aparelho)', () async {
      expect(await repo.theme(), isNull);
      expect(themeModeFrom(await repo.theme()), ThemeMode.system);
    });

    test('grava, persiste e troca', () async {
      await repo.setTheme('dark');
      expect(await repo.theme(), 'dark');
      // Outro repositório sobre o mesmo banco = "reabrir o app".
      final reopened = LocalPreferencesRepository(
        db,
        'u1',
        LocalChangeRecorder(db, newId: () => 'b${++ids}'),
      );
      expect(await reopened.theme(), 'dark');
      await reopened.setTheme('light');
      expect(await repo.theme(), 'light');
      await repo.setTheme(null);
      expect(themeModeFrom(await repo.theme()), ThemeMode.system);
    });

    test('offline: fica na fila e sobe depois, sem duplicar', () async {
      await repo.setTheme('dark');
      await repo.setTheme('light');
      final gateway = _Gateway();
      final sync = SyncService(db, gateway);
      expect(await sync.syncOnce('u1'), 2);
      expect(gateway.calls.map((c) => c.$1), [
        'set_user_theme',
        'set_user_theme',
      ]);
      expect(gateway.calls.map((c) => c.$2['p_theme']), ['dark', 'light']);
      // Repetir o envio não reenvia nada.
      expect(await sync.syncOnce('u1'), 0);
      expect(gateway.calls.length, 2);
      // Auditoria da alteração e da criação.
      final audits = await db
          .customSelect(
            "SELECT operation FROM audit_events WHERE entity_type = "
            "'user_preferences' ORDER BY rowid",
          )
          .get();
      expect(audits.map((r) => r.read<String>('operation')), [
        'create',
        'update',
      ]);
    });

    test('segundo aparelho recebe o tema no download', () async {
      final reader = _DownloadReader()
        ..preferences = {
          'theme': 'dark',
          'time_zone_id': 'America/Sao_Paulo',
          'version': 3,
          'updated_at': '2026-11-12T10:00:00Z',
        };
      await DownloadService(db, reader).downloadAll('u1');
      expect(await repo.theme(), 'dark');
    });

    test(
      'alteração local ainda não enviada não é sobrescrita por versão antiga',
      () async {
        await repo.setTheme('light'); // versão local 1, ainda na fila
        final reader = _DownloadReader()
          ..preferences = {
            'theme': 'dark',
            'time_zone_id': 'America/Sao_Paulo',
            'version': 1,
            'updated_at': '2026-11-12T10:00:00Z',
          };
        await DownloadService(db, reader).downloadAll('u1');
        expect(await repo.theme(), 'light');
      },
    );
  });

  group('Web (servidor)', () {
    test('lê e grava direto no servidor', () async {
      final reader = _Reader();
      final gateway = _Gateway();
      final web = RemotePreferencesRepository(
        reader,
        gateway,
        newId: () => 'op',
      );
      expect(await web.theme(), isNull);
      await web.setTheme('dark');
      expect(gateway.calls.single.$1, 'set_user_theme');
      expect(gateway.calls.single.$2, {
        'p_operation_id': 'op',
        'p_theme': 'dark',
      });
      reader.rows = [
        {'theme': 'dark'},
      ];
      expect(await web.theme(), 'dark');
    });
  });

  group('tela e controle do tema', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      PreferencesRepository repository, {
      DataAccessMode mode = DataAccessMode.local,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
            dataAccessModeProvider.overrideWithValue(mode),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              themeMode: ref.watch(themeModeProvider).value,
              theme: ThemeData(brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              home: const ThemeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(ThemeScreen)),
      );
    }

    testWidgets('troca na hora e grava; reabrir mantém', (tester) async {
      await pump(tester, repo);
      Brightness shown() =>
          Theme.of(tester.element(find.byType(ThemeScreen))).brightness;
      await tester.tap(find.byKey(const Key('tema-escuro')));
      await tester.pumpAndSettle();
      expect(shown(), Brightness.dark);
      expect(await repo.theme(), 'dark');

      await tester.tap(find.byKey(const Key('tema-claro')));
      await tester.pumpAndSettle();
      expect(shown(), Brightness.light);
      expect(await repo.theme(), 'light');
    });

    testWidgets('Web sem conexão não grava e avisa', (tester) async {
      final gateway = _Gateway();
      final web = RemotePreferencesRepository(_Reader(), gateway);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWith((ref) async => web),
            dataAccessModeProvider.overrideWithValue(DataAccessMode.remoteOnly),
            connectivityProbeProvider.overrideWithValue(_Probe(false)),
          ],
          child: const MaterialApp(home: ThemeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tema-escuro')));
      await tester.pumpAndSettle();
      expect(gateway.calls, isEmpty);
      expect(find.text(WriteGate.offlineMessage), findsOneWidget);
    });

    testWidgets('Web com conexão grava no servidor', (tester) async {
      final gateway = _Gateway();
      final web = RemotePreferencesRepository(_Reader(), gateway);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWith((ref) async => web),
            dataAccessModeProvider.overrideWithValue(DataAccessMode.remoteOnly),
            connectivityProbeProvider.overrideWithValue(_Probe(true)),
          ],
          child: const MaterialApp(home: ThemeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tema-escuro')));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.$2['p_theme'], 'dark');
    });
  });
}

class _Probe implements ConnectivityProbe {
  _Probe(this.online);
  final bool online;

  @override
  Future<bool> isOnline() async => online;
}
