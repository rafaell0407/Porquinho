@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/auth/auth_models.dart';
import 'package:porquinho/features/auth/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// Integração com o Supabase LOCAL: sessão, recuperação de senha e
/// autorização (isolamento entre usuários). Pulada se o servidor não responde.
final _url =
    Platform.environment['PORQUINHO_SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
final _mailpit =
    Platform.environment['PORQUINHO_MAILPIT_URL'] ?? 'http://127.0.0.1:54324';
final _key =
    Platform.environment['PORQUINHO_SUPABASE_KEY'] ??
    'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
const _redirect = 'br.com.norte.app://login-callback';
const _senha = 'senha-segura-123';

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

GoTrueClient _client() => GoTrueClient(
  url: '$_url/auth/v1',
  headers: {'apikey': _key},
  asyncStorage: _MemoryAsyncStorage(),
);

Future<bool> _available() async {
  try {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final r = await (await c.getUrl(Uri.parse('$_url/auth/v1/health'))).close();
    c.close();
    return r.statusCode < 500;
  } on Object {
    return false;
  }
}

Future<String> _get(HttpClient c, String url, {bool follow = true}) async {
  final req = await c.getUrl(Uri.parse(url));
  req.followRedirects = follow;
  final res = await req.close();
  if (!follow && res.isRedirect) {
    await res.drain<void>();
    return res.headers.value('location') ?? '';
  }
  return res.transform(utf8.decoder).join();
}

/// Abre o link do último e-mail para [to] cujo assunto contém [subject], sem
/// seguir o redirecionamento; devolve o endereço de destino (`Location`).
Future<String> _openMailLink(String to, String subject) async {
  final c = HttpClient();
  try {
    String? id;
    for (var i = 0; i < 20 && id == null; i++) {
      final res =
          jsonDecode(
                await _get(
                  c,
                  '$_mailpit/api/v1/search?query=${Uri.encodeQueryComponent('to:$to subject:"$subject"')}',
                ),
              )
              as Map<String, dynamic>;
      final msgs = res['messages'] as List<dynamic>;
      if (msgs.isNotEmpty) {
        id = (msgs.first as Map<String, dynamic>)['ID'] as String;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    expect(id, isNotNull, reason: 'e-mail "$subject" não chegou');
    final msg =
        jsonDecode(await _get(c, '$_mailpit/api/v1/message/$id'))
            as Map<String, dynamic>;
    final link = RegExp(
      r'href="([^"]*verify[^"]*)"',
    ).firstMatch(msg['HTML'] as String)!.group(1)!;
    return await _get(c, link.replaceAll('&amp;', '&'), follow: false);
  } finally {
    c.close();
  }
}

String _email() => 'seg${DateTime.now().microsecondsSinceEpoch}@exemplo.com';

/// Cria e confirma um usuário; devolve o repositório já logado.
Future<(SupabaseAuthRepository, GoTrueClient, AuthUser)> _newUser() async {
  final client = _client();
  final repo = SupabaseAuthRepository(client, redirectTo: _redirect);
  final e = _email();
  await repo.signUpWithEmail(e, _senha);
  await _openMailLink(e, 'Confirm');
  final user = await repo.signInWithEmail(e, _senha);
  return (repo, client, user);
}

Future<RestResponse> _rest(
  String token,
  String method,
  String path, [
  Object? body,
]) async {
  final c = HttpClient();
  try {
    final req = await c.openUrl(method, Uri.parse('$_url$path'));
    req.headers
      ..set('apikey', _key)
      ..set('Authorization', 'Bearer $token')
      ..set('Content-Type', 'application/json');
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    return RestResponse(
      res.statusCode,
      await res.transform(utf8.decoder).join(),
    );
  } finally {
    c.close();
  }
}

class RestResponse {
  RestResponse(this.status, this.body);
  final int status;
  final String body;
}

void main() {
  late bool available;
  setUpAll(() async => available = await _available());

  test('renovar o token mantém a mesma conta e muda o token', () async {
    if (!available) return markTestSkipped('Supabase local indisponível');
    final (_, client, user) = await _newUser();
    final antes = client.currentSession!.accessToken;

    final res = await client.refreshSession();

    expect(res.user!.id, user.id);
    expect(res.session!.accessToken, isNot(antes));
  });

  test('sessão guardada é restaurada por outro cliente', () async {
    if (!available) return markTestSkipped('Supabase local indisponível');
    final (_, client, user) = await _newUser();
    final guardada = jsonEncode(client.currentSession!.toJson());

    final outro = _client();
    final res = await outro.recoverSession(guardada);

    expect(res.user!.id, user.id);
    expect(SupabaseAuthRepository(outro).restoreSession(), completes);
  });

  test(
    'recuperação de senha: link do e-mail, nova senha e novo login',
    () async {
      if (!available) return markTestSkipped('Supabase local indisponível');
      final e = _email();
      final client = _client();
      final repo = SupabaseAuthRepository(client, redirectTo: _redirect);
      await repo.signUpWithEmail(e, _senha);
      await _openMailLink(e, 'Confirm');

      await repo.sendPasswordReset(e);
      final destino = await _openMailLink(e, 'Reset');
      final code = Uri.parse(
        destino.replaceFirst('#', '?'),
      ).queryParameters['code'];
      expect(code, isNotNull, reason: 'o link deve trazer o código: $destino');
      await client.exchangeCodeForSession(code!);

      await repo.updatePassword('nova-senha-456');
      await repo.signOut();

      await expectLater(
        repo.signInWithEmail(e, _senha),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.invalidCredentials,
          ),
        ),
      );
      expect((await repo.signInWithEmail(e, 'nova-senha-456')).email, e);
    },
  );

  test('autorização: um usuário não enxerga nem altera dados de outro', () async {
    if (!available) return markTestSkipped('Supabase local indisponível');
    final (_, clientA, userA) = await _newUser();
    final (_, clientB, _) = await _newUser();
    final tokenA = clientA.currentSession!.accessToken;
    final tokenB = clientB.currentSession!.accessToken;

    final catId =
        '00000000-0000-4000-8000-${DateTime.now().microsecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}';
    final op =
        '10000000-0000-4000-8000-${DateTime.now().microsecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}';
    final criar =
        await _rest(tokenA, 'POST', '/rest/v1/rpc/apply_category_change', {
          'p_operation_id': op,
          'p_action': 'create',
          'p_category_id': catId,
          'p_expected_version': 0,
          'p_kind': 'expense',
          'p_name': 'Mercado',
        });
    expect(criar.status, lessThan(300), reason: criar.body);

    final lerA = await _rest(tokenA, 'GET', '/rest/v1/categories?id=eq.$catId');
    expect(jsonDecode(lerA.body) as List<dynamic>, hasLength(1));
    expect(
      (jsonDecode(lerA.body) as List<dynamic>).first['owner_id'],
      userA.id,
    );

    // B não vê a categoria de A.
    final lerB = await _rest(tokenB, 'GET', '/rest/v1/categories?id=eq.$catId');
    expect(jsonDecode(lerB.body), isEmpty);

    // Sem login (só a chave pública) também não.
    final anon = await _rest(_key, 'GET', '/rest/v1/categories?id=eq.$catId');
    expect(anon.status == 200 ? jsonDecode(anon.body) : <dynamic>[], isEmpty);

    // B não consegue gravar direto na tabela (DML bloqueado por grants).
    final direto = await _rest(
      tokenB,
      'PATCH',
      '/rest/v1/categories?id=eq.$catId',
      {'name': 'Invadida'},
    );
    expect(direto.status, greaterThanOrEqualTo(400));

    // A categoria de A continua intacta.
    final depois = await _rest(
      tokenA,
      'GET',
      '/rest/v1/categories?id=eq.$catId',
    );
    expect((jsonDecode(depois.body) as List<dynamic>).first['name'], 'Mercado');
  });
}
