import '../../core/domain/calendar_date.dart';
import '../sync/sync_models.dart';
import 'attention_models.dart';

/// Itens que exigem decisão. Celular: conflitos e recusas guardados no
/// aparelho. Web: conflitos abertos no servidor (decisão D11).
abstract interface class AttentionRepository {
  Future<List<AttentionItem>> items();

  /// Resolve um conflito. [editedRequest] só vale com [ConflictResolution.edit].
  Future<void> resolve(
    AttentionItem item,
    ConflictResolution resolution, {
    Map<String, dynamic>? editedRequest,
  });

  /// Descarta uma alteração recusada, por decisão do usuário (só celular).
  Future<void> discard(AttentionItem item);

  /// Recoloca uma alteração recusada na fila para nova tentativa (só celular).
  Future<void> retry(AttentionItem item);
}

/// Monta o pedido editado a partir da alteração original. Só [name] (categorias)
/// e [description]/[amountCentavos] (lançamentos) podem ser trocados; em
/// investimento, [amountCentavos] e [allocatedOn] (valor e data).
Map<String, dynamic> buildEditedRequest(
  AttentionItem item, {
  String? name,
  String? description,
  BigInt? amountCentavos,
  CalendarDate? allocatedOn,
}) {
  final base = Map<String, dynamic>.from(item.request)
    ..remove('expected_version');
  if (item.entityType == 'category' || item.entityType == 'subcategory') {
    return {'action': item.action, 'name': name ?? base['name']};
  }
  if (item.isInvestment) {
    return {
      'action': item.action,
      'amount_centavos': (amountCentavos ?? base['amount_centavos'])
          ?.toString(),
      'allocated_on': allocatedOn?.toIso() ?? base['allocated_on'],
    };
  }
  final payload = Map<String, dynamic>.from((base['payload'] as Map?) ?? {});
  if (description != null) payload['description'] = description;
  if (amountCentavos != null) {
    payload['amount_centavos'] = amountCentavos.toString();
  }
  return {'action': item.action, 'payload': payload};
}
