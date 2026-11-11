/// Fornece a chave bruta de 256 bits do banco local, em hexadecimal.
///
/// A origem da chave (Keystore/Keychain no celular, KEK WebCrypto na Web) é
/// pendência de `arquitetura.md` §17.5; este contrato só isola o banco disso.
abstract interface class DatabaseKeyProvider {
  Future<String> loadKeyHex();
}

/// Chave fixa em memória, para testes e provas técnicas.
class StaticDatabaseKeyProvider implements DatabaseKeyProvider {
  const StaticDatabaseKeyProvider(this._keyHex);

  final String _keyHex;

  @override
  Future<String> loadKeyHex() async => _keyHex;
}

final RegExp _rawKeyPattern = RegExp(r'^[0-9a-fA-F]{64}$');

/// Valida a chave e monta o `PRAGMA key`. Rejeita qualquer valor que não seja
/// exatamente 64 dígitos hexadecimais, evitando injeção de SQL pela chave.
String buildKeyPragma(String keyHex) {
  if (!_rawKeyPattern.hasMatch(keyHex)) {
    throw ArgumentError.value(
      '<oculta>',
      'keyHex',
      'A chave deve ter 64 dígitos hexadecimais (256 bits).',
    );
  }
  return "PRAGMA key = \"x'$keyHex'\";";
}
