import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/local_database/app_database.dart';
import '../../sync/sync_models.dart';
import '../domain/card_bill_models.dart';
import '../domain/change_set.dart';
import '../domain/reserve.dart';
import 'card_bills_repository.dart';
import 'local_card_bills_repository.dart';

/// Pagamento duplicado (spec §12, GF3.7): a mesma fatura paga em dois
/// aparelhos sem conexão. O segundo não é aplicado no servidor e aparece em
/// "Precisam de atenção". O usuário escolhe qual manter:
/// - o do servidor: o deste aparelho é descartado (a reserva não muda aqui);
/// - o deste aparelho: o do servidor é desfeito (a reserva recebe de volta só
///   o que saiu dela) e este é aplicado — a reserva é descontada uma vez só.
class CardBillsConflictResolver {
  CardBillsConflictResolver(
    this._db,
    this._ownerId, {
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? newUuid;

  final PorquinhoDatabase _db;
  final String _ownerId;
  final DateTime Function() _clock;
  final String Function() _newId;

  static bool handles(String entityType) =>
      entityType == CardBillsEntity.invoice;

  Future<void> resolve(String conflictId, ConflictResolution resolution) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM sync_conflicts WHERE owner_id = ? AND id = ?',
          variables: [
            Variable.withString(_ownerId),
            Variable.withString(conflictId),
          ],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Conflito não encontrado.');
    final conflict = LocalConflict.fromRow(row.data);
    if (conflict.state != ConflictState.open) {
      throw StateError('Conflito já resolvido.');
    }
    final now = _clock().toUtc();
    final nowIso = now.toIso8601String();
    await _db.transaction(() async {
      await _db.customStatement(
        "UPDATE sync_conflicts SET state = 'resolved', resolution_json = ?, "
        'version = version + 1, updated_at = ? WHERE owner_id = ? AND id = ?',
        [
          jsonEncode({'resolution': resolution.wireName}),
          nowIso,
          _ownerId,
          conflictId,
        ],
      );
      await _db.customStatement(
        "DELETE FROM sync_outbox WHERE owner_id = ? AND state = 'conflict' "
        'AND entity_type = ? AND entity_id = ?',
        [_ownerId, conflict.entityType, conflict.entityId],
      );
      if (resolution != ConflictResolution.keepLocal) return;

      final local = conflict.localSnapshot;
      final invoice = InvoiceRecord.fromRow(
        Map<String, Object?>.from(local['p_invoice'] as Map),
      );
      final eventRow = local['p_reserve_event'];
      final remote = InvoiceRecord.fromRow(
        Map<String, Object?>.from(conflict.remoteSnapshot),
      );
      final remotePayment = remote.payment!;
      final label = invoiceLabel(remotePayment.cardName, remote.dueOn);
      final command = PayInvoiceCommand(
        invoice: invoice,
        reserveEvent: eventRow == null
            ? null
            : ReserveEvent.fromRow(Map<String, Object?>.from(eventRow as Map)),
        replacePaymentId: remotePayment.paymentId,
        replaceUndoEvent: undoEvent(
          payment: remotePayment,
          invoiceId: remote.id,
          label:
              'ao manter o outro pagamento da fatura '
              '${remotePayment.cardName}',
          now: now,
        ),
      );
      // Saída da reserva do pagamento do servidor, se este aparelho ainda
      // não a baixou (o mesmo id que o servidor guardou).
      final remoteOut = paymentEvent(
        paymentId: remotePayment.paymentId,
        invoiceId: remote.id,
        reserveUsed: remotePayment.reserveUsed,
        label: label,
        now: now,
      );
      if (remoteOut != null) {
        await applyChangeLocally(
          _db,
          _ownerId,
          CardBillsChange(
            writes: [
              RowWrite.insertIfAbsent(
                CardBillTables.reserveEvents,
                remoteOut.toRow(),
              ),
            ],
            summary: '',
          ),
          nowIso,
        );
      }
      await _db.customStatement(
        "UPDATE card_bill_invoices SET status = 'pending', payment_id = NULL, "
        'paid_amount_centavos = NULL, paid_on = NULL, payment_source = NULL, '
        'reserve_used_centavos = NULL, expected_amount_centavos = NULL, '
        'items_snapshot = NULL WHERE owner_id = ? AND id = ?',
        [_ownerId, invoice.id],
      );
      // A fatura local passa a mostrar este pagamento (com a devolução do
      // pagamento do servidor), igual ao que o servidor fará ao receber.
      await applyPaymentLocally(_db, _ownerId, command, nowIso);
      await _db.customStatement(
        'INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, '
        'entity_id, expected_version, payload_json, state, attempts) '
        "VALUES (?, ?, ?, ?, 0, ?, 'pending', 0)",
        [
          _ownerId,
          _newId(),
          CardBillsEntity.invoice,
          invoice.id,
          jsonEncode({'rpc': CardBillsRpc.pay, 'params': payParams(command)}),
        ],
      );
    });
  }
}
