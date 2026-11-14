@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/preferences/preferences_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/remote_table_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:porquinho/features/tools/models/tool_preferences.dart';

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

  LocalPreferencesRepository open(String owner) => LocalPreferencesRepository(
    db,
    owner,
    LocalChangeRecorder(db, newId: () => 'k${++ids}'),
    clock: () => DateTime.utc(2026, 11, 13),
  );

  setUp(() {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    repo = open('u1');
  });
  tearDown(() => db.close());

  group('celular (banco local, offline primeiro)', () {
    test('sem escolha = padrão; grava e persiste ao reabrir', () async {
      expect(await repo.tools(), ToolPreferences.empty);
      await repo.setToolSelection(['reports', 'outra']);
      await repo.dismissToolIntro('outra');
      final reopened = open('u1');
      expect(
        await reopened.tools(),
        const ToolPreferences(
          selected: ['reports', 'outra'],
          dismissedIntros: {'outra'},
        ),
      );
    });

    test('restaurar padrão tira só a lista; o tema não é afetado', () async {
      await repo.setTheme('dark');
      await repo.setToolSelection(['reports']);
      await repo.dismissToolIntro('reports');
      await repo.setToolSelection(null);
      final prefs = await repo.tools();
      expect(prefs.isDefault, isTrue);
      expect(prefs.dismissedIntros, {'reports'});
      expect(await repo.theme(), 'dark');
    });

    test('preferências são do usuário: outro dono não vê', () async {
      await repo.setToolSelection([]);
      expect((await open('u2').tools()).isDefault, isTrue);
    });

    test('fila: sobe pelas RPCs certas, sem duplicar, com auditoria', () async {
      await repo.setToolSelection(['reports']);
      await repo.dismissToolIntro('reports');
      await repo.setToolSelection(null);
      final gateway = _Gateway();
      final sync = SyncService(db, gateway);
      expect(await sync.syncOnce('u1'), 3);
      expect(gateway.calls.map((c) => c.$1), [
        'set_tool_selection',
        'dismiss_tool_intro',
        'set_tool_selection',
      ]);
      expect(gateway.calls[0].$2['p_tool_ids'], ['reports']);
      expect(gateway.calls[1].$2['p_tool_id'], 'reports');
      expect(gateway.calls[2].$2['p_tool_ids'], isNull);
      expect(await sync.syncOnce('u1'), 0);
      expect(gateway.calls.length, 3);
      final audits = await db
          .customSelect(
            "SELECT operation FROM audit_events WHERE entity_type = "
            "'user_preferences' ORDER BY rowid",
          )
          .get();
      expect(audits.map((r) => r.read<String>('operation')), [
        'create',
        'update',
        'update',
      ]);
    });

    test('outro aparelho recebe as escolhas no download', () async {
      final reader = _DownloadReader()
        ..preferences = {
          'theme': null,
          'time_zone_id': 'America/Sao_Paulo',
          'onboarding': {},
          'tools': {
            'selected': ['b', 'a'],
            'dismissed_intros': ['b'],
          },
          'version': 4,
          'updated_at': '2026-11-13T10:00:00Z',
        };
      await DownloadService(db, reader).downloadAll('u1');
      expect(
        await repo.tools(),
        const ToolPreferences(selected: ['b', 'a'], dismissedIntros: {'b'}),
      );
    });

    test('servidor ainda sem a coluna: fica o padrão', () async {
      final reader = _DownloadReader()
        ..preferences = {
          'theme': 'dark',
          'time_zone_id': 'America/Sao_Paulo',
          'version': 2,
          'updated_at': '2026-11-13T10:00:00Z',
        };
      await DownloadService(db, reader).downloadAll('u1');
      expect((await repo.tools()).isDefault, isTrue);
      expect(await repo.theme(), 'dark');
    });

    test(
      'alteração local não enviada não é sobrescrita por versão antiga',
      () async {
        await repo.setToolSelection(['a']); // versão local 1, na fila
        final reader = _DownloadReader()
          ..preferences = {
            'tools': {
              'selected': ['b'],
            },
            'time_zone_id': 'America/Sao_Paulo',
            'version': 1,
            'updated_at': '2026-11-13T10:00:00Z',
          };
        await DownloadService(db, reader).downloadAll('u1');
        expect((await repo.tools()).selected, ['a']);
      },
    );
  });

  group('Web (somente online, servidor)', () {
    test('lê e grava direto nas RPCs', () async {
      final reader = _Reader();
      final gateway = _Gateway();
      final web = RemotePreferencesRepository(
        reader,
        gateway,
        newId: () => 'op',
      );
      expect((await web.tools()).isDefault, isTrue);
      await web.setToolSelection(['reports']);
      await web.dismissToolIntro('reports');
      expect(gateway.calls.map((c) => c.$1), [
        'set_tool_selection',
        'dismiss_tool_intro',
      ]);
      expect(gateway.calls[0].$2, {
        'p_operation_id': 'op',
        'p_tool_ids': ['reports'],
      });
      expect(gateway.calls[1].$2, {
        'p_operation_id': 'op',
        'p_tool_id': 'reports',
      });
      reader.rows = [
        {
          'tools': {
            'selected': <String>[],
            'dismissed_intros': ['reports'],
          },
        },
      ];
      expect(
        await web.tools(),
        const ToolPreferences(selected: [], dismissedIntros: {'reports'}),
      );
    });
  });
}
