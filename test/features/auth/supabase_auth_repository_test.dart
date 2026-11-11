@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/stored_database_key_provider.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/secure_session_storage.dart';
import 'package:porquinho/features/auth/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// Integração com o Supabase LOCAL (`supabase start`). Pulada se indisponível.
/// Variáveis opcionais: PORQUINHO_SUPABASE_URL, PORQUINHO_SUPABASE_KEY.
final _url =
    Platform.environment['PORQUINHO_SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
final _mailpit =
    Platform.environment['PORQUINHO_MAILPIT_URL'] ?? 'http://127.0.0.1:54324';
final _key =
    Platform.environment['PORQUINHO_SUPABASE_KEY'] ??
    'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

Future<bool> _localAvailable() async {
  try {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final r = await (await c.getUrl(Uri.parse('$_url/auth/v1/health'))).close();
    c.close();
    return r.statusCode < 500;
  } on Object {
    return false;
  }
}

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _data = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _data[key];
  @override
  Future<void> removeItem({required String key}) async => _data.remove(key);
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _data[key] = value;
}

GoTrueClient _client(String url) => GoTrueClient(
  url: url,
  headers: {'apikey': _key},
  asyncStorage: _MemoryAsyncStorage(),
);

SupabaseAuthRepository _repo() =>
    SupabaseAuthRepository(_client('$_url/auth/v1'));

Matcher _failure(AuthFailureCode code) =>
    throwsA(isA<AuthFailure>().having((f) => f.code, 'code', code));

/// Lê o último e-mail do Mailpit local para [to] e abre o link de confirmação
/// (sem seguir o redirecionamento para o site, que não está rodando).
Future<void> _confirmEmail(String to) async {
  final c = HttpClient();
  try {
    Future<String> get(String url, {bool follow = true}) async {
      final req = await c.getUrl(Uri.parse(url));
      req.followRedirects = follow;
      final res = await req.close();
      return res.transform(utf8.decoder).join();
    }

    Map<String, dynamic>? message;
    for (var i = 0; i < 20 && message == null; i++) {
      final list =
          jsonDecode(await get('$_mailpit/api/v1/search?query=to:$to'))
              as Map<String, dynamic>;
      final msgs = list['messages'] as List<dynamic>;
      if (msgs.isNotEmpty) message = msgs.first as Map<String, dynamic>;
      if (message == null) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    expect(message, isNotNull, reason: 'e-mail de confirmação não chegou');
    final full =
        jsonDecode(await get('$_mailpit/api/v1/message/${message!['ID']}'))
            as Map<String, dynamic>;
    final html = full['HTML'] as String;
    final link = RegExp(
      r'href="([^"]*verify[^"]*)"',
    ).firstMatch(html)!.group(1)!;
    await get(link.replaceAll('&amp;', '&'), follow: false);
  } finally {
    c.close();
  }
}

void main() {
  late bool available;
  setUpAll(() async => available = await _localAvailable());

  String email() => 'teste${DateTime.now().microsecondsSinceEpoch}@exemplo.com';
  const senha = 'senha-segura-123';

  test('cadastro exige confirmar o e-mail antes do login', () async {
    if (!available) return markTestSkipped('Supabase local indisponível');
    final e = email();
    final repo = _repo();

    // Sem confirmação não há sessão.
    expect(await repo.signUpWithEmail(e, senha), isNull);
    expect(await repo.restoreSession(), isNull);
    await expectLater(
      repo.signInWithEmail(e, senha),
      _failure(AuthFailureCode.emailNotConfirmed),
    );

    await _confirmEmail(e);

    final user = await repo.signInWithEmail(e, senha);
    expect(user.email, e);
    expect((await repo.restoreSession())?.id, user.id);

    await expectLater(
      repo.signInWithEmail(e, 'errada-errada'),
      _failure(AuthFailureCode.invalidCredentials),
    );

    await repo.signOut();
    expect(await repo.restoreSession(), isNull);
  });

  test('senha fraca é rejeitada', () async {
    if (!available) return markTestSkipped('Supabase local indisponível');
    await expectLater(
      _repo().signUpWithEmail(email(), 'abc'),
      _failure(AuthFailureCode.weakPassword),
    );
  });

  test('recuperação de senha é aceita', () async {
    if (!available) return markTestSkipped('Supabase local indisponível');
    final e = email();
    final repo = _repo();
    await repo.signUpWithEmail(e, senha);
    await repo.signOut();
    await repo.sendPasswordReset(e);
  });

  test('servidor fora do ar vira falha de rede', () async {
    final repo = SupabaseAuthRepository(_client('http://127.0.0.1:1/auth/v1'));
    await expectLater(
      repo.signInWithEmail('a@b.com', 'x'),
      _failure(AuthFailureCode.network),
    );
  });

  test('SecureSessionStorage persiste e remove a sessão', () async {
    final storage = SecureSessionStorage(InMemorySecureValueStore());
    expect(await storage.hasAccessToken(), isFalse);
    await storage.persistSession('{"s":1}');
    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), '{"s":1}');
    await storage.removePersistedSession();
    expect(await storage.hasAccessToken(), isFalse);
  });
}
