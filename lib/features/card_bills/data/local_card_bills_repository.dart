import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/local_database/app_database.dart';
import '../../sync/sync_models.dart';
import '../domain/card_bill_models.dart';
import '../domain/change_set.dart';
import 'card_bills_repository.dart';
import 'card_bills_rows.dart';

/// Celular: grava primeiro no banco local e põe a operação na fila de envio,
/// na mesma transação (spec §12; "salvo" só depois de gravar). Sem
/// auditoria do app (decisão de 16/11/2026). A semântica de cada gravação é
/// a mesma da RPC no servidor, para os dois lados ficarem iguais.
class LocalCardBillsRepository implements CardBillsRepository {
  LocalCardBillsRepository(
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

  String _now() => _clock().toUtc().toIso8601String();

  @override
  Future<CardBillsData> load() async {
    final rows = <String, List<Map<String, Object?>>>{};
    for (final table in CardBillTables.ordered) {
      final result = await _db
          .customSelect(
            'SELECT * FROM $table WHERE owner_id = ?',
            variables: [Variable.withString(_ownerId)],
          )
          .get();
      rows[table] = [for (final r in result) r.data];
    }
    return dataFromRows(rows);
  }

  @override
  Future<void> apply(CardBillsChange change) async {
    if (change.isEmpty) return;
    await _db.transaction(() async {
      await applyChangeLocally(_db, _ownerId, change, _now());
      await _enqueue(
        CardBillsEntity.cadastros,
        _ownerId,
        CardBillsRpc.apply,
        applyParams(change),
      );
    });
  }

  @override
  Future<void> pay(PayInvoiceCommand command) => _db.transaction(() async {
    await applyPaymentLocally(_db, _ownerId, command, _now());
    await _enqueue(
      CardBillsEntity.invoice,
      command.invoice.id,
      CardBillsRpc.pay,
      payParams(command),
    );
  });

  @override
  Future<void> undo(UndoPaymentCommand command) => _db.transaction(() async {
    await applyUndoLocally(_db, _ownerId, command, _now());
    await _enqueue(
      CardBillsEntity.invoice,
      command.invoiceId,
      CardBillsRpc.undo,
      undoParams(command),
    );
  });

  Future<void> _enqueue(
    String entityType,
    String entityId,
    String rpc,
    Map<String, dynamic> params,
  ) => _db.customStatement(
    'INSERT INTO sync_outbox (owner_id, idempotency_key, entity_type, '
    'entity_id, expected_version, payload_json, state, attempts) '
    "VALUES (?, ?, ?, ?, 0, ?, 'pending', 0)",
    [
      _ownerId,
      _newId(),
      entityType,
      entityId,
      jsonEncode({'rpc': rpc, 'params': params}),
    ],
  );
}

/// Aplica a alteração no banco local com a mesma regra da RPC
/// `card_bills_apply`: gravações na ordem das tabelas, depois exclusões na
/// ordem inversa; fatura paga não muda nem é apagada.
Future<void> applyChangeLocally(
  PorquinhoDatabase db,
  String ownerId,
  CardBillsChange change,
  String now,
) async {
  for (final w in change.orderedWrites) {
    await _write(db, ownerId, w, now);
  }
  for (final d in change.orderedDeletes) {
    final frozen = d.table == CardBillTables.invoices
        ? " AND status = 'pending'"
        : '';
    await db.customStatement(
      'DELETE FROM ${d.table} WHERE owner_id = ? AND id = ?$frozen',
      [ownerId, d.id],
    );
  }
}

Future<void> _write(
  PorquinhoDatabase db,
  String ownerId,
  RowWrite w,
  String now,
) async {
  final isInvoice = w.table == CardBillTables.invoices;
  var row = Map<String, Object?>.from(w.row);
  var allowed = CardBillTables.columns[w.table]!;
  if (isInvoice) {
    row['status'] = 'pending';
    allowed = [
      for (final c in allowed)
        if (!CardBillTables.paymentColumns.contains(c)) c,
    ];
  }
  final columns = row.keys.toList();
  final updates = w.table == CardBillTables.reserveEvents
      ? const <String>[]
      : (w.updateColumns ??
            [
              for (final c in allowed)
                if (c != 'id') c,
            ]);
  final names = ['owner_id', 'created_at', 'updated_at', ...columns];
  final values = [
    ownerId,
    now,
    now,
    for (final c in columns) toSqlValue(c, row[c]),
  ];
  final conflict = updates.isEmpty
      ? 'DO NOTHING'
      : 'DO UPDATE SET ${[for (final c in updates) '$c = excluded.$c', 'updated_at = excluded.updated_at'].join(', ')}'
            '${isInvoice ? " WHERE ${w.table}.status = 'pending'" : ''}';
  await db.customStatement(
    'INSERT INTO ${w.table} (${names.join(', ')}) '
    'VALUES (${List.filled(names.length, '?').join(', ')}) '
    'ON CONFLICT (owner_id, id) $conflict',
    values,
  );
}

Future<void> _insertEvent(
  PorquinhoDatabase db,
  String ownerId,
  ReserveEvent? event,
  String now,
) async {
  if (event == null) return;
  await _write(
    db,
    ownerId,
    RowWrite.insertIfAbsent(CardBillTables.reserveEvents, event.toRow()),
    now,
  );
}

/// Pagamento no banco local (mesma regra da RPC `card_bills_pay_invoice`).
Future<void> applyPaymentLocally(
  PorquinhoDatabase db,
  String ownerId,
  PayInvoiceCommand command,
  String now,
) async {
  final row = command.invoice.toRow();
  final existing = await db
      .customSelect(
        'SELECT * FROM card_bill_invoices '
        'WHERE owner_id = ? AND id = ?',
        variables: [
          Variable.withString(ownerId),
          Variable.withString(command.invoice.id),
        ],
      )
      .getSingleOrNull();
  if (existing != null && existing.data['status'] == 'paid') {
    final current = existing.data['payment_id'];
    if (current == command.payment.paymentId) return;
    if (current != command.replacePaymentId) {
      throw DuplicatePaymentException(InvoiceRecord.fromRow(existing.data));
    }
  }
  if (command.replacePaymentId != null) {
    await _insertEvent(db, ownerId, command.replaceUndoEvent, now);
  }
  final names = ['owner_id', 'created_at', 'updated_at', ...row.keys];
  final values = [
    ownerId,
    now,
    now,
    for (final e in row.entries) toSqlValue(e.key, e.value),
  ];
  final updates = [
    for (final c in CardBillTables.paymentColumns) '$c = excluded.$c',
    'updated_at = excluded.updated_at',
  ].join(', ');
  await db.customStatement(
    'INSERT INTO card_bill_invoices (${names.join(', ')}) '
    'VALUES (${List.filled(names.length, '?').join(', ')}) '
    'ON CONFLICT (owner_id, id) DO UPDATE SET $updates',
    values,
  );
  await _insertEvent(db, ownerId, command.reserveEvent, now);
}

/// Desfazer no banco local (mesma regra da RPC `card_bills_undo_payment`).
Future<void> applyUndoLocally(
  PorquinhoDatabase db,
  String ownerId,
  UndoPaymentCommand command,
  String now,
) async {
  final existing = await db
      .customSelect(
        'SELECT payment_id FROM card_bill_invoices '
        "WHERE owner_id = ? AND id = ? AND status = 'paid'",
        variables: [
          Variable.withString(ownerId),
          Variable.withString(command.invoiceId),
        ],
      )
      .getSingleOrNull();
  if (existing?.data['payment_id'] != command.paymentId) return;
  await _insertEvent(db, ownerId, command.reserveEvent, now);
  await db.customStatement(
    "UPDATE card_bill_invoices SET status = 'pending', payment_id = NULL, "
    'paid_amount_centavos = NULL, paid_on = NULL, payment_source = NULL, '
    'reserve_used_centavos = NULL, expected_amount_centavos = NULL, '
    'card_name = NULL, items_snapshot = NULL, updated_at = ? '
    'WHERE owner_id = ? AND id = ?',
    [now, ownerId, command.invoiceId],
  );
}
