@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/attention/attention_models.dart';
import 'package:porquinho/features/attention/local_attention_repository.dart';
import 'package:porquinho/features/categories/category_models.dart';
import 'package:porquinho/features/categories/category_service.dart';
import 'package:porquinho/features/categories/local_category_repository.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// Renovação visual V2: ícone e cor das categorias percorrem o caminho
/// completo (aparelho → fila → RPC → servidor → download em outro aparelho),
/// inclusive na resolução de conflito.
class _Device {
  _Device(this.account, this.client) {
    db = memoryDb();
    download = DownloadService(db, SupabaseSyncReader(client));
    sync = SyncService(db, SupabaseSyncGateway(client));
    attention = LocalAttentionRepository(db, account.id, sync, download);
    repo = LocalCategoryRepository(db, account.id, LocalChangeRecorder(db));
    service = CategoryService(repo);
  }

  final TestAccount account;
  final SupabaseClient client;
  late final PorquinhoDatabase db;
  late final DownloadService download;
  late final SyncService sync;
  late final LocalAttentionRepository attention;
  late final LocalCategoryRepository repo;
  late final CategoryService service;

  Future<void> pull() async {
    final result = await download.downloadAll(account.id);
    expect(result.completed, isTrue);
  }

  Future<void> push() async {
    for (var i = 0; i < 4; i++) {
      await sync.syncOnce(account.id);
    }
  }

  Future<CategoryRecord> category(String id) async =>
      (await repo.categories()).singleWhere((c) => c.id == id);

  Future<Map<String, dynamic>> serverRow(String id) =>
      client.from('categories').select().eq('id', id).single();
}

void main() {
  final r = Random();
  const skip = supabaseEnabled ? false : supabaseSkipReason;

  test(
    'ícone e cor criados e editados chegam ao servidor e ao outro aparelho',
    () async {
      final account = await newTestAccount(r);
      final a = _Device(account, await account.device());
      final b = _Device(account, await account.device());
      addTearDown(a.db.close);
      addTearDown(b.db.close);

      final id = await a.service.createCategory(
        CategoryKind.expense,
        'Mercado',
        iconKey: 'shopping_cart',
        colorKey: 'orange',
      );
      await a.push();
      final server = await a.serverRow(id);
      expect(server['icon_key'], 'shopping_cart');
      expect(server['color_key'], 'orange');

      await b.pull();
      final onB = await b.category(id);
      expect(onB.iconKey, 'shopping_cart');
      expect(onB.colorKey, 'orange');

      // Só o visual muda ("restyle"): nome e versão seguem a regra de sempre.
      await a.service.editCategory(
        await a.category(id),
        name: 'Mercado',
        iconKey: 'car',
        colorKey: 'orange',
      );
      await a.push();
      await b.pull();
      final after = await b.category(id);
      expect(after.iconKey, 'car');
      expect(after.colorKey, 'orange');
      expect(after.name, 'Mercado');
      expect(after.version, 2);
      expect((await a.serverRow(id))['version'], 2);
      expect(await a.sync.operations(account.id), isEmpty);
    },
    skip: skip,
  );

  test(
    'conflito visual × renomear: "manter a minha" aplica ícone e cor no servidor',
    () async {
      final account = await newTestAccount(r);
      final a = _Device(account, await account.device());
      final b = _Device(account, await account.device());
      addTearDown(a.db.close);
      addTearDown(b.db.close);

      final id = await a.service.createCategory(CategoryKind.expense, 'Base');
      await a.push();
      await b.pull();

      // Offline nos dois, a partir da versão 1.
      await a.service.editCategory(
        await a.category(id),
        name: 'Base',
        iconKey: 'home',
        colorKey: 'blue',
      );
      await b.service.renameCategory(await b.category(id), 'Do B');
      await b.push(); // B chega primeiro
      await a.push(); // A recebe o conflito

      final items = await a.attention.items();
      expect(items, hasLength(1));
      expect(items.single.kind, AttentionKind.conflict);
      expect(items.single.action, 'restyle');
      expect(items.single.mineSummary, 'Mudar ícone e cor');
      expect(items.single.canKeepLocal, isTrue);

      await a.attention.resolve(items.single, ConflictResolution.keepLocal);
      await a.push();
      await a.pull();
      await b.pull();

      final server = await a.serverRow(id);
      expect(server['name'], 'Do B');
      expect(server['icon_key'], 'home');
      expect(server['color_key'], 'blue');
      for (final d in [a, b]) {
        final c = await d.category(id);
        expect(c.name, 'Do B');
        expect(c.iconKey, 'home');
        expect(c.colorKey, 'blue');
      }
      expect(await a.sync.operations(account.id), isEmpty);
      expect(await b.sync.operations(account.id), isEmpty);
    },
    skip: skip,
  );
}
