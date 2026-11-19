import 'dart:typed_data';

/// Arquivo escolhido pelo usuário: lido só no navegador, nunca enviado.
class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
