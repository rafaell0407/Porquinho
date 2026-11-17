import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'year_month.dart';

/// Identificadores determinísticos da ferramenta (spec §7 e §12): dois
/// aparelhos geram o mesmo id para a mesma fatura, parcela ou cobrança, e a
/// gravação nunca duplica. Formato UUID (versão 5, SHA-1, RFC 4122) para caber
/// nas colunas `uuid` do servidor.
abstract final class CardBillIds {
  /// Espaço de nomes próprio da ferramenta (UUID fixo).
  static const _namespace = '8a3f2c1e-5b7d-4e9a-9c61-2f4d8b0e7a15';

  static String invoice(String cardId, YearMonth month) =>
      _uuid5('invoice:$cardId:${month.toKey()}');

  static String installment(String purchaseId, int number) =>
      _uuid5('installment:$purchaseId:$number');

  static String charge(String subscriptionId, YearMonth month) =>
      _uuid5('charge:$subscriptionId:${month.toKey()}');

  /// Saída da reserva por um pagamento.
  static String paymentEvent(String paymentId) =>
      _uuid5('reserve-payment:$paymentId');

  /// Volta à reserva ao desfazer um pagamento.
  static String undoEvent(String paymentId) =>
      _uuid5('reserve-undo:$paymentId');

  static String _uuid5(String name) {
    final ns = _namespace.replaceAll('-', '');
    final nsBytes = [
      for (var i = 0; i < 32; i += 2)
        int.parse(ns.substring(i, i + 2), radix: 16),
    ];
    final digest = sha1.convert([...nsBytes, ...utf8.encode(name)]).bytes;
    final bytes = digest.sublist(0, 16);
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
