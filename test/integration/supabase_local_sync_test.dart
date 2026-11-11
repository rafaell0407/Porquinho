@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Integração com o Supabase LOCAL (nunca o gerenciado). Só roda com:
/// `flutter test test/integration --dart-define=SUPABASE_URL=http://127.0.0.1:54321
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=... --dart-define=SUPABASE_SECRET_KEY=...`
/// (as chaves vêm de `supabase status`; nada fica no repositório).
const _url = String.fromEnvironment('SUPABASE_URL');
const _publishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _secret = String.fromEnvironment('SUPABASE_SECRET_KEY');
final _enabled =
    _url.isNotEmpty && _publishable.isNotEmpty && _secret.isNotEmpty;

String _uuid(Random r) {
  String h(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-a${h(3)}-${h(12)}';
}

class _Account {
  _Account(this.client, this.id);
  final SupabaseClient client;
  final String id;
}

Future<_Account> _newAccount(Random r) async {
  final admin = SupabaseClient(_url, _secret);
  final email = 'it-${r.nextInt(1 << 30)}@teste.local';
  final created = await admin.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: 'Senha-123456',
      emailConfirm: true,
    ),
  );
  final client = SupabaseClient(_url, _publishable);
  await client.auth.signInWithPassword(email: email, password: 'Senha-123456');
  return _Account(client, created.user!.id);
}

void main() {
  final r = Random();

  Future<Map<String, dynamic>> createCategory(
    _Account a,
    String id,
    String name,
  ) async {
    final res = await a.client.rpc(
      'apply_category_change',
      params: {
        'p_operation_id': _uuid(r),
        'p_action': 'create',
        'p_category_id': id,
        'p_expected_version': 0,
        'p_kind': 'expense',
        'p_name': name,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  group('Supabase local', () {
    test(
      'download: aparelho novo recebe tudo, repetição não duplica, isolamento',
      () async {
        final a = await _newAccount(r);
        final b = await _newAccount(r);
        final c1 = _uuid(r), c2 = _uuid(r), cb = _uuid(r);
        await createCategory(a, c1, 'Mercado');
        await createCategory(a, c2, 'Aluguel');
        await createCategory(b, cb, 'Da outra conta');

        final db = PorquinhoDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final service = DownloadService(db, SupabaseSyncReader(a.client));

        final first = await service.downloadAll(a.id);
        expect(first.completed, isTrue);
        final cats = await db.customSelect('SELECT id FROM categories').get();
        expect(cats.map((x) => x.read<String>('id')).toSet(), {c1, c2});
        final audit = await db
            .customSelect('SELECT COUNT(*) AS n FROM audit_events')
            .getSingle();
        expect(audit.read<int>('n'), 2);

        final second = await service.downloadAll(a.id);
        expect(second.applied, 0);
        final again = await db
            .customSelect('SELECT COUNT(*) AS n FROM categories')
            .getSingle();
        expect(again.read<int>('n'), 2);
      },
      skip: _enabled ? false : 'defina SUPABASE_URL/PUBLISHABLE_KEY/SECRET_KEY',
    );

    test(
      'pendência local × mudança remota vira conflito no envio',
      () async {
        final a = await _newAccount(r);
        final id = _uuid(r);
        await createCategory(a, id, 'Original');

        final db = PorquinhoDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final reader = SupabaseSyncReader(a.client);
        await DownloadService(db, reader).downloadAll(a.id);

        // Edição local offline (versão 1 -> 2) ...
        final recorder = LocalChangeRecorder(db);
        await recorder.record(
          ownerId: a.id,
          entityType: 'category',
          entityId: id,
          operation: 'rename',
          expectedVersion: 1,
          rpc: 'apply_category_change',
          params: {
            'p_action': 'rename',
            'p_category_id': id,
            'p_expected_version': 1,
            'p_kind': null,
            'p_name': 'Local',
          },
          apply: () => db.customStatement(
            "UPDATE categories SET name = 'Local', version = 2 WHERE id = ?",
            [id],
          ),
        );
        // ... e, em outro aparelho, o servidor muda o mesmo registro.
        await a.client.rpc(
          'apply_category_change',
          params: {
            'p_operation_id': _uuid(r),
            'p_action': 'rename',
            'p_category_id': id,
            'p_expected_version': 1,
            'p_kind': null,
            'p_name': 'Remoto',
          },
        );

        final download = await DownloadService(db, reader).downloadAll(a.id);
        expect(download.skippedPending, 1);
        final local = await db
            .customSelect(
              'SELECT name FROM categories WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingle();
        expect(local.read<String>('name'), 'Local');

        final sync = SyncService(db, SupabaseSyncGateway(a.client));
        await sync.syncOnce(a.id);
        expect((await sync.openConflicts(a.id)).length, 1);
      },
      skip: _enabled ? false : 'defina SUPABASE_URL/PUBLISHABLE_KEY/SECRET_KEY',
    );

    test(
      'duas edições seguidas enviam sem conflito falso (Entrega 26)',
      () async {
        final a = await _newAccount(r);
        final id = _uuid(r);
        await createCategory(a, id, 'Base');

        final db = PorquinhoDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await DownloadService(
          db,
          SupabaseSyncReader(a.client),
        ).downloadAll(a.id);
        final recorder = LocalChangeRecorder(db);
        final sync = SyncService(db, SupabaseSyncGateway(a.client));

        Future<void> rename(String name, int before) => recorder.record(
          ownerId: a.id,
          entityType: 'category',
          entityId: id,
          operation: 'rename',
          expectedVersion: before,
          rpc: 'apply_category_change',
          params: {
            'p_action': 'rename',
            'p_category_id': id,
            'p_expected_version': before,
            'p_kind': null,
            'p_name': name,
          },
          apply: () => db.customStatement(
            'UPDATE categories SET name = ?, version = ? WHERE id = ?',
            [name, before + 1, id],
          ),
        );

        await rename('Um', 1);
        await sync.syncOnce(a.id);
        await rename('Dois', 2);
        await sync.syncOnce(a.id);

        expect(await sync.openConflicts(a.id), isEmpty);
        expect(await sync.operations(a.id), isEmpty);
        final row = await db
            .customSelect(
              'SELECT name, version FROM categories WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingle();
        expect(row.read<int>('version'), 3);
        final server = await a.client
            .from('categories')
            .select()
            .eq('id', id)
            .single();
        expect(server['version'], 3);
        expect(server['name'], 'Dois');
      },
      skip: _enabled ? false : 'defina SUPABASE_URL/PUBLISHABLE_KEY/SECRET_KEY',
    );
  });
}
