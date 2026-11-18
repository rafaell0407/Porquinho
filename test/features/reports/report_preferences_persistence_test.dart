@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/preferences/preferences_repository.dart';
import 'package:porquinho/features/reports/models/report_preferences.dart';
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
  group('formato salvo', () {
    test('vazio = configuração pendente e lista sugerida', () {
      final p = ReportPreferences.decode('{}');
      expect(p.setupPending, isTrue);
      expect(p.isSuggested, isTrue);
      expect(p.toJson(), isEmpty);
    });

    test('lê, ignora inválidos e repetidos, preserva options', () {
      final p = ReportPreferences.decode({
        'setup': 'skipped',
        'selected': ['b', 'Inválido', 'a', 'b', 3, 'futuro_relatorio'],
        'options': {
          'b': {'periods': 6},
        },
      });
      expect(p.setup, ReportSetupStatus.skipped);
      expect(p.selected, ['b', 'a', 'futuro_relatorio']);
      expect(p.toJson(), {
        'setup': 'skipped',
        'selected': ['b', 'a', 'futuro_relatorio'],
        'options': {
          'b': {'periods': 6},
        },
      });
    });

    test('JSON quebrado ou status desconhecido viram padrão', () {
      expect(ReportPreferences.decode('{x'), ReportPreferences.empty);
      expect(ReportPreferences.decode({'setup': 'talvez'}).setupPending, true);
    });

    test('configuração feita não volta e não troca de status', () {
      final done = ReportPreferences.empty.withSetup(ReportSetupStatus.done);
      expect(
        done.withSetup(ReportSetupStatus.skipped).setup,
        ReportSetupStatus.done,
      );
      expect(done.withSelected(['a']).setup, ReportSetupStatus.done);
      expect(done.withSelected(['a']).withSelected(null).isSuggested, isTrue);
    });
  });

  late PorquinhoDatabase db;
  late LocalPreferencesRepository repo;
  var ids = 0;

  LocalPreferencesRepository open(String owner) => LocalPreferencesRepository(
    db,
    owner,
    LocalChangeRecorder(db, newId: () => 'k${++ids}'),
    clock: () => DateTime.utc(2026, 11, 17),
  );

  setUp(() {
    ids = 0;
    db = PorquinhoDatabase(NativeDatabase.memory());
    repo = open('u1');
  });
  tearDown(() => db.close());

  group('celular (banco local, offline primeiro)', () {
    test('grava e persiste ao reabrir', () async {
      expect(await repo.reports(), ReportPreferences.empty);
      await repo.completeReportSetup(ReportSetupStatus.done);
      await repo.setReportSelection([
        'period_comparison',
        'income_by_category',
      ]);
      expect(
        await open('u1').reports(),
        const ReportPreferences(
          setup: ReportSetupStatus.done,
          selected: ['period_comparison', 'income_by_category'],
        ),
      );
    });

    test('relatórios, ferramentas e tema não se apagam entre si', () async {
      await repo.setTheme('dark');
      await repo.setToolSelection(['reports']);
      await repo.setReportSelection(['investments_total']);
      await repo.setToolSelection(['reports', 'outra']);
      expect((await repo.reports()).selected, ['investments_total']);
      expect(
        await repo.tools(),
        const ToolPreferences(selected: ['reports', 'outra']),
      );
      expect(await repo.theme(), 'dark');
    });

    test('restaurar tira só a lista; a configuração fica', () async {
      await repo.completeReportSetup(ReportSetupStatus.skipped);
      await repo.setReportSelection([]);
      await repo.setReportSelection(null);
      final p = await repo.reports();
      expect(p.isSuggested, isTrue);
      expect(p.setup, ReportSetupStatus.skipped);
    });

    test('preferências são do usuário: outro dono não vê', () async {
      await repo.completeReportSetup(ReportSetupStatus.done);
      expect((await open('u2').reports()).setupPending, isTrue);
    });

    test('fila: sobe pelas RPCs certas, sem duplicar, com auditoria', () async {
      await repo.completeReportSetup(ReportSetupStatus.done);
      await repo.setReportSelection(['income_by_category']);
      await repo.setReportSelection(null);
      final gateway = _Gateway();
      final sync = SyncService(db, gateway);
      expect(await sync.syncOnce('u1'), 3);
      expect(gateway.calls.map((c) => c.$1), [
        'complete_report_setup',
        'set_report_selection',
        'set_report_selection',
      ]);
      expect(gateway.calls[0].$2['p_status'], 'done');
      expect(gateway.calls[1].$2['p_report_ids'], ['income_by_category']);
      expect(gateway.calls[2].$2['p_report_ids'], isNull);
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
          'tools': {},
          'reports': {
            'setup': 'done',
            'selected': ['b', 'a'],
            'options': {'z': 1},
          },
          'version': 4,
          'updated_at': '2026-11-17T10:00:00Z',
        };
      await DownloadService(db, reader).downloadAll('u1');
      expect(
        await repo.reports(),
        const ReportPreferences(
          setup: ReportSetupStatus.done,
          selected: ['b', 'a'],
          options: {'z': 1},
        ),
      );
    });

    test('servidor ainda sem a coluna: fica o padrão', () async {
      final reader = _DownloadReader()
        ..preferences = {
          'theme': 'dark',
          'time_zone_id': 'America/Sao_Paulo',
          'version': 2,
          'updated_at': '2026-11-17T10:00:00Z',
        };
      await DownloadService(db, reader).downloadAll('u1');
      expect(await repo.reports(), ReportPreferences.empty);
      expect(await repo.theme(), 'dark');
    });

    test('alteração local não enviada não é sobrescrita', () async {
      await repo.setReportSelection(['a']); // versão local 1, na fila
      final reader = _DownloadReader()
        ..preferences = {
          'reports': {
            'selected': ['b'],
          },
          'time_zone_id': 'America/Sao_Paulo',
          'version': 1,
          'updated_at': '2026-11-17T10:00:00Z',
        };
      await DownloadService(db, reader).downloadAll('u1');
      expect((await repo.reports()).selected, ['a']);
    });
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
      expect(await web.reports(), ReportPreferences.empty);
      await web.completeReportSetup(ReportSetupStatus.skipped);
      await web.setReportSelection(['investments_total']);
      expect(gateway.calls.map((c) => c.$1), [
        'complete_report_setup',
        'set_report_selection',
      ]);
      expect(gateway.calls[0].$2, {
        'p_operation_id': 'op',
        'p_status': 'skipped',
      });
      expect(gateway.calls[1].$2, {
        'p_operation_id': 'op',
        'p_report_ids': ['investments_total'],
      });
      reader.rows = [
        {
          'reports': {'setup': 'skipped', 'selected': <String>[]},
        },
      ];
      expect(
        await web.reports(),
        const ReportPreferences(setup: ReportSetupStatus.skipped, selected: []),
      );
    });
  });
}
