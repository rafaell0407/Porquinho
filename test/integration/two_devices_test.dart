@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/attention/attention_models.dart';
import 'package:porquinho/features/attention/attention_repository.dart';
import 'package:porquinho/features/attention/local_attention_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// Entrega 70: dois aparelhos (dois bancos locais) com a mesma conta no
/// Supabase LOCAL convergem para o mesmo estado, inclusive após conflito.
class _Device {
  _Device(this.account, this.client) {
    db = memoryDb();
    reader = SupabaseSyncReader(client);
    download = DownloadService(db, reader);
    sync = SyncService(db, SupabaseSyncGateway(client));
    attention = LocalAttentionRepository(db, account.id, sync, download);
  }

  final TestAccount account;
  final SupabaseClient client;
  late final PorquinhoDatabase db;
  late final SupabaseSyncReader reader;
  late final DownloadService download;
  late final SyncService sync;
  late final LocalAttentionRepository attention;

  Future<void> pull() async {
    final result = await download.downloadAll(account.id);
    expect(result.completed, isTrue);
  }

  Future<void> push() async {
    for (var i = 0; i < 4; i++) {
      await sync.syncOnce(account.id);
    }
  }

  Future<String?> name(String id) async {
    final rows = await localRows(
      db,
      'SELECT name FROM categories WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : rows.single['name'] as String;
  }

  Future<int> activeFlag(String id) async {
    final rows = await localRows(
      db,
      'SELECT is_active FROM categories WHERE id = ?',
      [id],
    );
    return rows.single['is_active'] as int;
  }

  Future<void> deactivate(String id, int before) => LocalChangeRecorder(db)
      .record(
        ownerId: account.id,
        entityType: 'category',
        entityId: id,
        operation: 'deactivate',
        expectedVersion: before,
        rpc: 'apply_category_change',
        params: {
          'p_action': 'deactivate',
          'p_category_id': id,
          'p_expected_version': before,
          'p_kind': null,
          'p_name': null,
        },
        apply: () => db.customStatement(
          'UPDATE categories SET is_active = 0, version = ? WHERE id = ?',
          [before + 1, id],
        ),
      )
      .then((_) {});
}

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;

  /// Dois aparelhos com a categoria [id] já baixada nos dois.
  Future<(TestAccount, _Device, _Device, String)> setup(String base) async {
    final account = await newTestAccount(r);
    final a = _Device(account, await account.device());
    final b = _Device(account, await account.device());
    addTearDown(a.db.close);
    addTearDown(b.db.close);
    final id = testUuid(r);
    await localCreateCategory(a.db, account.id, id, base);
    await a.push();
    await b.pull();
    expect(await b.name(id), base);
    return (account, a, b, id);
  }

  Future<String> serverName(_Device d, String id) async {
    final row = await d.client
        .from('categories')
        .select()
        .eq('id', id)
        .single();
    return row['name'] as String;
  }

  group('Entrega 70 — dois aparelhos', () {
    test('criação em um aparelho chega ao outro sem duplicar', () async {
      final (account, a, b, id) = await setup('Base');
      await a.pull();
      await b.pull();
      expect(await a.name(id), 'Base');
      expect(await b.name(id), 'Base');
      final n = await localRows(b.db, 'SELECT COUNT(*) AS n FROM categories');
      expect(n.single['n'], 1);
      expect(account.id, isNotEmpty);
    }, skip: skip);

    for (final resolution in ConflictResolution.values) {
      test('edição × edição, resolução "${resolution.wireName}": os dois '
          'aparelhos e o servidor convergem', () async {
        final (account, a, b, id) = await setup('Base');

        // Offline nos dois: cada um renomeia a partir da versão 1.
        await localRenameCategory(a.db, account.id, id, 'Do A', 1);
        await localRenameCategory(b.db, account.id, id, 'Do B', 1);
        await a.push(); // A chega primeiro
        await b.push(); // B recebe conflito
        final items = await b.attention.items();
        expect(items, hasLength(1));
        expect(items.single.kind, AttentionKind.conflict);
        expect(await a.sync.openConflicts(account.id), isEmpty);

        await b.attention.resolve(
          items.single,
          resolution,
          editedRequest: resolution == ConflictResolution.edit
              ? buildEditedRequest(items.single, name: 'Combinado')
              : null,
        );
        expect(await b.attention.items(), isEmpty);
        await b.push();
        await a.pull();
        await b.pull();

        final expected = switch (resolution) {
          ConflictResolution.keepLocal => 'Do B',
          ConflictResolution.keepRemote => 'Do A',
          ConflictResolution.edit => 'Combinado',
        };
        expect(await serverName(a, id), expected);
        expect(await a.name(id), expected);
        expect(await b.name(id), expected);
        // Nenhum aparelho fica com pendência nem conflito.
        expect(await a.sync.operations(account.id), isEmpty);
        expect(await b.sync.operations(account.id), isEmpty);
        // Resolver não gera duplicatas.
        final n = await localRows(b.db, 'SELECT COUNT(*) AS n FROM categories');
        expect(n.single['n'], 1);
      }, skip: skip);
    }

    test(
      'desativação × edição vira conflito e a decisão vale nos dois',
      () async {
        final (account, a, b, id) = await setup('Base');
        await a.deactivate(id, 1);
        await localRenameCategory(b.db, account.id, id, 'Renomeada', 1);
        await a.push();
        await b.push();

        final items = await b.attention.items();
        expect(items, hasLength(1));
        await b.attention.resolve(items.single, ConflictResolution.keepRemote);
        await a.pull();
        await b.pull();

        expect(await b.name(id), 'Base');
        expect(await b.activeFlag(id), 0);
        expect(await a.activeFlag(id), 0);
        final row = await a.client.from('categories').select().eq('id', id);
        expect(row.single['is_active'], false);
      },
      skip: skip,
    );

    test('mesma operação enviada pelos dois aparelhos não duplica', () async {
      final (account, a, b, id) = await setup('Base');
      // O mesmo pedido (mesma chave) chega duas vezes, de aparelhos diferentes.
      final params = {
        'p_operation_id': testUuid(r),
        'p_action': 'rename',
        'p_category_id': id,
        'p_expected_version': 1,
        'p_kind': null,
        'p_name': 'Única',
      };
      final first = await SupabaseSyncGateway(
        a.client,
      ).call('apply_category_change', params);
      final second = await SupabaseSyncGateway(
        b.client,
      ).call('apply_category_change', params);
      expect(first['status'], 'applied');
      expect(second['status'], 'applied');
      final row = await a.client
          .from('categories')
          .select()
          .eq('id', id)
          .single();
      expect(row['version'], 2);
      expect(account.id, isNotEmpty);
    }, skip: skip);
  });
}
