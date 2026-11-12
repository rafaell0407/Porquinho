import 'dart:math';

import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/sync/local_change_recorder.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Apoio dos testes de integração com o Supabase LOCAL (nunca o gerenciado).
/// Valores vêm de `--dart-define` (de `supabase status`); nada fica no
/// repositório.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const supabaseSecret = String.fromEnvironment('SUPABASE_SECRET_KEY');
const supabaseEnabled =
    supabaseUrl != '' && supabasePublishable != '' && supabaseSecret != '';
const supabaseSkipReason = 'defina SUPABASE_URL/PUBLISHABLE_KEY/SECRET_KEY';

String testUuid(Random r) {
  String h(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-a${h(3)}-${h(12)}';
}

class TestAccount {
  TestAccount(this.email, this.password, this.id);
  final String email;
  final String password;
  final String id;

  /// Novo "aparelho": cliente próprio autenticado como esta conta.
  Future<SupabaseClient> device() async {
    final client = SupabaseClient(supabaseUrl, supabasePublishable);
    await client.auth.signInWithPassword(email: email, password: password);
    return client;
  }
}

Future<TestAccount> newTestAccount(Random r) async {
  final admin = SupabaseClient(supabaseUrl, supabaseSecret);
  final email = 'it-${r.nextInt(1 << 30)}@teste.local';
  final created = await admin.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: 'Senha-123456',
      emailConfirm: true,
    ),
  );
  return TestAccount(email, 'Senha-123456', created.user!.id);
}

PorquinhoDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return PorquinhoDatabase(NativeDatabase.memory());
}

/// Gateway que executa a chamada de verdade e depois pode "perder a resposta"
/// (a RPC foi aplicada no servidor, mas o app recebe erro de rede).
class FlakyGateway implements SyncRemoteGateway {
  FlakyGateway(this._inner);
  final SyncRemoteGateway _inner;

  /// Quantas próximas respostas serão perdidas depois de executar a chamada.
  int loseNextResponses = 0;

  /// Quantas próximas chamadas falham antes de chegar ao servidor.
  int failNextCalls = 0;
  final calls = <({String rpc, String? operationId})>[];

  @override
  Future<Map<String, dynamic>> call(
    String rpc,
    Map<String, dynamic> params,
  ) async {
    calls.add((rpc: rpc, operationId: params['p_operation_id'] as String?));
    if (failNextCalls > 0) {
      failNextCalls--;
      throw const SyncTransientError('sem rede (simulado)');
    }
    final result = await _inner.call(rpc, params);
    if (loseNextResponses > 0) {
      loseNextResponses--;
      throw const SyncTransientError('resposta perdida (simulado)');
    }
    return result;
  }
}

/// Cria uma categoria de despesa no aparelho (registro + auditoria + fila).
Future<String> localCreateCategory(
  PorquinhoDatabase db,
  String ownerId,
  String id,
  String name,
) => LocalChangeRecorder(db).record(
  ownerId: ownerId,
  entityType: 'category',
  entityId: id,
  operation: 'create',
  expectedVersion: 0,
  rpc: 'apply_category_change',
  params: {
    'p_action': 'create',
    'p_category_id': id,
    'p_expected_version': 0,
    'p_kind': 'expense',
    'p_name': name,
  },
  apply: () => db.customStatement(
    'INSERT INTO categories (id, owner_id, version, created_at, updated_at, '
    "kind, name, is_active) VALUES (?, ?, 1, datetime('now'), "
    "datetime('now'), 'expense', ?, 1)",
    [id, ownerId, name],
  ),
);

/// Renomeia uma categoria no aparelho; [before] é a versão local atual.
Future<String> localRenameCategory(
  PorquinhoDatabase db,
  String ownerId,
  String id,
  String name,
  int before,
) => LocalChangeRecorder(db).record(
  ownerId: ownerId,
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

/// Cria a categoria diretamente no servidor (como se viesse de outro aparelho).
Future<void> remoteCreateCategory(
  SupabaseClient client,
  Random r,
  String id,
  String name,
) => client.rpc(
  'apply_category_change',
  params: {
    'p_operation_id': testUuid(r),
    'p_action': 'create',
    'p_category_id': id,
    'p_expected_version': 0,
    'p_kind': 'expense',
    'p_name': name,
  },
);

Future<List<Map<String, Object?>>> localRows(
  PorquinhoDatabase db,
  String sql, [
  List<Object?> args = const [],
]) async {
  final rows = await db
      .customSelect(sql, variables: [for (final a in args) Variable(a)])
      .get();
  return rows.map((r) => r.data).toList();
}
