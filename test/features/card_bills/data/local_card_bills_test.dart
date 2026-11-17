import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/local_database/app_database.dart';
import 'package:porquinho/features/attention/local_attention_repository.dart';
import 'package:porquinho/features/card_bills/data/card_bills_downloader.dart';
import 'package:porquinho/features/card_bills/data/card_bills_repository.dart';
import 'package:porquinho/features/card_bills/data/local_card_bills_repository.dart';
import 'package:porquinho/features/card_bills/data/remote_card_bills_repository.dart';
import 'package:porquinho/features/card_bills/domain/card_bill_models.dart';
import 'package:porquinho/features/card_bills/domain/cards_and_invoices.dart';
import 'package:porquinho/features/card_bills/domain/change_set.dart';
import 'package:porquinho/features/card_bills/domain/invoice_board.dart';
import 'package:porquinho/features/card_bills/domain/purchases.dart';
import 'package:porquinho/features/card_bills/domain/reserve.dart';
import 'package:porquinho/features/card_bills/domain/subscriptions.dart';
import 'package:porquinho/features/sync/download_service.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';

import '../domain/card_bills_fixtures.dart';

const owner = 'owner-1';

PorquinhoDatabase _memory() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return PorquinhoDatabase(NativeDatabase.memory());
}

/// Servidor simulado: outro banco com a MESMA regra das RPCs (os testes SQL
/// e de integração conferem o servidor de verdade).
class _FakeServer implements SyncRemoteGateway, CardBillsRemoteSource {
  final db = _memory();
  int calls = 0;
  bool offline = false;

  @override
  Future<Map<String, dynamic>> call(String rpc, Map<String, dynamic> p) async {
    calls++;
    if (offline) throw const SyncTransientError('sem rede');
    final now = DateTime.now().toUtc().toIso8601String();
    switch (rpc) {
      case CardBillsRpc.apply:
        await db.transaction(
          () => applyChangeLocally(
            db,
            owner,
            CardBillsChange.fromJson(
              Map<String, dynamic>.from(p['p_changes'] as Map),
              '',
            ),
            now,
          ),
        );
        return {'status': 'applied'};
      case CardBillsRpc.pay:
        final cmd = PayInvoiceCommand(
          invoice: InvoiceRecord.fromRow(
            Map<String, Object?>.from(p['p_invoice'] as Map),
          ),
          reserveEvent: p['p_reserve_event'] == null
              ? null
              : ReserveEvent.fromRow(
                  Map<String, Object?>.from(p['p_reserve_event'] as Map),
                ),
          replacePaymentId: p['p_replace_payment_id'] as String?,
          replaceUndoEvent: p['p_replace_undo_event'] == null
              ? null
              : ReserveEvent.fromRow(
                  Map<String, Object?>.from(p['p_replace_undo_event'] as Map),
                ),
        );
        try {
          await db.transaction(() => applyPaymentLocally(db, owner, cmd, now));
        } on DuplicatePaymentException catch (e) {
          return {
            'status': 'conflict',
            'conflict_id': 'conflict-${p['p_operation_id']}',
            'remote_invoice': {...e.remote.toRow(), 'version': 1},
          };
        }
        return {'status': 'applied'};
      case CardBillsRpc.undo:
        await db.transaction(
          () => applyUndoLocally(
            db,
            owner,
            UndoPaymentCommand(
              invoiceId: p['p_invoice_id'] as String,
              paymentId: p['p_payment_id'] as String,
              reserveEvent: p['p_reserve_event'] == null
                  ? null
                  : ReserveEvent.fromRow(
                      Map<String, Object?>.from(p['p_reserve_event'] as Map),
                    ),
            ),
            now,
          ),
        );
        return {'status': 'applied'};
    }
    throw SyncRejectedError('RPC desconhecida: $rpc');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll(String table) async {
    if (offline) throw const SyncTransientError('sem rede');
    final rows = await db
        .customSelect(
          'SELECT * FROM $table WHERE owner_id = ? ORDER BY id',
          variables: [Variable.withString(owner)],
        )
        .get();
    return [for (final r in rows) Map<String, dynamic>.from(r.data)];
  }

  Future<CardBillsData> data() => LocalCardBillsRepository(db, owner).load();
}

class _Device {
  _Device(this.server) {
    repo = LocalCardBillsRepository(db, owner);
    sync = SyncService(db, server);
  }

  final _FakeServer server;
  final db = _memory();
  late final LocalCardBillsRepository repo;
  late final SyncService sync;

  Future<void> syncAll() async {
    await sync.syncOnce(owner);
    await CardBillsDownloader(db, server).replaceAll(owner);
  }

  Future<List<OutboxOperation>> outbox() => sync.operations(owner);
}

void main() {
  final today = d('2026-11-18');
  final now = DateTime.utc(2026, 11, 16, 15);

  Future<void> seed(LocalCardBillsRepository repo) async {
    await repo.apply(createCard(nubank));
    final data = await repo.load();
    await repo.apply(
      planNewPurchase(
        id: 'purchase-1',
        draft: PurchaseDraft(
          cardId: nubank.id,
          description: 'TV',
          purchasedOn: today,
          installmentCount: 3,
          amountMode: AmountMode.total,
          amount: c(300000),
        ),
        data: data,
        today: today,
      ).change,
    );
    final withPurchase = await repo.load();
    await repo.apply(
      CardBillsChange(
        writes: [
          RowWrite(
            CardBillTables.reserveEvents,
            adjustmentTo(
              c(150000),
              withPurchase.reserveEvents,
              id: 'adj-1',
              now: now,
            )!.toRow(),
          ),
        ],
        summary: 'Reserva',
      ),
    );
  }

  test('grava no aparelho e põe na fila, sem auditoria do app', () async {
    final device = _Device(_FakeServer());
    await seed(device.repo);
    final data = await device.repo.load();
    expect(data.cards.single.name, 'Nubank');
    expect(data.installments.length, 3);
    expect(reserveShown(data.reserveEvents), c(150000));
    final ops = await device.outbox();
    expect(ops.length, 3);
    expect(ops.map((o) => o.entityType).toSet(), {CardBillsEntity.cadastros});
    expect(ops.first.rpc, CardBillsRpc.apply);
    final audit = await device.db
        .customSelect('SELECT * FROM audit_events')
        .get();
    expect(audit, isEmpty);
  });

  test(
    'envio leva ao servidor o mesmo conteúdo (paridade aparelho × servidor)',
    () async {
      final server = _FakeServer();
      final device = _Device(server);
      await seed(device.repo);
      await device.syncAll();
      expect(await device.outbox(), isEmpty);
      final local = await device.repo.load();
      final remote = await server.data();
      expect(
        CardBillsBoard.build(remote, today).committed,
        CardBillsBoard.build(local, today).committed,
      );
      expect(remote.installments.map((i) => i.toRow()).toSet().length, 3);
      expect(
        {for (final i in remote.installments) i.id: i.amount},
        {for (final i in local.installments) i.id: i.amount},
      );
      // Reenviar a fila (resposta perdida) não duplica nada.
      expect(reserveShown(remote.reserveEvents), c(150000));
    },
  );

  test(
    'cobranças geradas em dois aparelhos não duplicam; removida não volta',
    () async {
      final server = _FakeServer();
      final a = _Device(server);
      final b = _Device(server);
      await a.repo.apply(createCard(nubank));
      await a.repo.apply(
        createSubscription(
          Subscription(
            id: 'sub-1',
            cardId: nubank.id,
            description: 'Streaming',
            monthlyAmount: c(3990),
            startMonth: ym('2026-12'),
          ),
        ),
      );
      await a.syncAll();
      await b.syncAll();
      // Os dois geram a cobrança sem conexão entre si.
      await a.repo.apply(generateCharges(await a.repo.load(), today));
      await b.repo.apply(generateCharges(await b.repo.load(), today));
      // A remove a cobrança e envia; B envia a geração depois.
      final generated = (await a.repo.load()).charges.single;
      await a.repo.apply(removeCharge(generated));
      await a.syncAll();
      await b.syncAll();
      await a.syncAll();
      for (final device in [a, b]) {
        final charges = (await device.repo.load()).charges;
        expect(charges.length, 1);
        expect(charges.single.removed, isTrue);
      }
    },
  );

  test(
    'exclusão em um aparelho some no outro (comparação com o servidor)',
    () async {
      final server = _FakeServer();
      final a = _Device(server);
      final b = _Device(server);
      await seed(a.repo);
      await a.syncAll();
      await b.syncAll();
      expect((await b.repo.load()).purchases.length, 1);
      final data = await a.repo.load();
      await a.repo.apply(deletePurchase(data.purchases.single, data));
      await a.syncAll();
      await b.syncAll();
      final after = await b.repo.load();
      expect(after.purchases, isEmpty);
      expect(after.installments, isEmpty);
      expect(after.cards.single.name, 'Nubank');
    },
  );

  test('envio pendente não é sobrescrito pelo download', () async {
    final server = _FakeServer();
    final device = _Device(server);
    await seed(device.repo);
    await device.syncAll();
    server.offline = true;
    await device.repo.apply(
      createCard(
        const CreditCard(id: 'card-2', name: 'Inter', closingDay: 1, dueDay: 8),
      ),
    );
    await device.sync.syncOnce(owner); // falha: fica para depois
    server.offline = false;
    expect(
      await CardBillsDownloader(device.db, server).replaceAll(owner),
      isFalse,
    );
    expect((await device.repo.load()).cards.length, 2);
    // Depois de enviar, o download confirma.
    await device.sync.syncOnce(owner);
  });

  test('pagar e desfazer: fatura, reserva e fila', () async {
    final server = _FakeServer();
    final device = _Device(server);
    await seed(device.repo);
    var data = await device.repo.load();
    final view = CardBillsBoard.build(data, today).pending.first;
    final plan = planPayment(
      expectedAmount: view.value,
      paidAmount: view.value,
      source: PaymentSource.reserve,
      events: data.reserveEvents,
    );
    await device.repo.pay(
      buildPayment(
        view: view,
        plan: plan,
        paidOn: today,
        paymentId: 'pay-a',
        now: now,
        data: data,
      ),
    );
    data = await device.repo.load();
    var board = CardBillsBoard.build(data, today);
    expect(board.paid.single.value, c(100000));
    expect(board.reserve, c(50000));
    final ops = await device.outbox();
    expect(ops.last.entityType, CardBillsEntity.invoice);
    expect(ops.last.rpc, CardBillsRpc.pay);

    await device.repo.undo(buildUndo(data.invoiceById(view.id)!, now));
    board = CardBillsBoard.build(await device.repo.load(), today);
    expect(board.paid, isEmpty);
    expect(board.reserve, c(150000));
    await device.syncAll();
    final remote = CardBillsBoard.build(await server.data(), today);
    expect(remote.reserve, c(150000));
    expect(remote.paid, isEmpty);
  });

  group('pagamento duplicado (dois aparelhos sem conexão)', () {
    late _FakeServer server;
    late _Device a;
    late _Device b;
    late LocalAttentionRepository attentionB;

    Future<void> payOn(
      _Device device,
      String paymentId,
      int amount,
      PaymentSource source,
    ) async {
      final data = await device.repo.load();
      final view = CardBillsBoard.build(data, today).pending.first;
      final plan = planPayment(
        expectedAmount: view.value,
        paidAmount: c(amount),
        source: source,
        events: data.reserveEvents,
      );
      await device.repo.pay(
        buildPayment(
          view: view,
          plan: plan,
          paidOn: today,
          paymentId: paymentId,
          now: now,
          data: data,
        ),
      );
    }

    setUp(() async {
      server = _FakeServer();
      a = _Device(server);
      b = _Device(server);
      await seed(a.repo);
      await a.syncAll();
      await b.syncAll();
      await payOn(a, 'pay-a', 100000, PaymentSource.reserve);
      await payOn(b, 'pay-b', 100000, PaymentSource.other);
      await a.syncAll();
      await b.syncAll();
      attentionB = LocalAttentionRepository(
        b.db,
        owner,
        b.sync,
        DownloadService(b.db, _NoReader()),
      );
    });

    test('o segundo não é aplicado e aparece em atenção', () async {
      final remote = CardBillsBoard.build(await server.data(), today);
      expect(remote.paid.single.payment!.paymentId, 'pay-a');
      expect(remote.reserve, c(50000));
      final items = await attentionB.items();
      expect(items.single.entityType, CardBillsEntity.invoice);
      expect(items.single.isCardBillPayment, isTrue);
      expect(items.single.canKeepLocal, isTrue);
      expect(items.single.mineSummary, contains('R\$ 1.000,00'));
      // B passa a mostrar o que está no servidor.
      final local = CardBillsBoard.build(await b.repo.load(), today);
      expect(local.paid.single.payment!.paymentId, 'pay-a');
    });

    test(
      'manter o do servidor: nada muda, reserva descontada uma vez',
      () async {
        final item = (await attentionB.items()).single;
        await attentionB.resolve(item, ConflictResolution.keepRemote);
        expect(await attentionB.items(), isEmpty);
        await b.syncAll();
        final remote = CardBillsBoard.build(await server.data(), today);
        expect(remote.paid.single.payment!.paymentId, 'pay-a');
        expect(remote.reserve, c(50000));
      },
    );

    test(
      'manter o deste aparelho: o outro é desfeito e a reserva volta',
      () async {
        final item = (await attentionB.items()).single;
        await attentionB.resolve(item, ConflictResolution.keepLocal);
        final localNow = CardBillsBoard.build(await b.repo.load(), today);
        expect(localNow.paid.single.payment!.paymentId, 'pay-b');
        expect(localNow.reserve, c(150000));
        await b.syncAll();
        await a.syncAll();
        for (final data in [
          await server.data(),
          await a.repo.load(),
          await b.repo.load(),
        ]) {
          final board = CardBillsBoard.build(data, today);
          expect(board.paid.single.payment!.paymentId, 'pay-b');
          expect(board.reserve, c(150000), reason: 'pago com outras fontes');
        }
        expect(await attentionB.items(), isEmpty);
      },
    );
  });
}

class _NoReader implements SyncRemoteReader {
  @override
  Future<Map<String, dynamic>?> fetchPreferences(String ownerId) async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required String ownerId,
    required String orderColumn,
    String? afterOrder,
    String? afterId,
    required int limit,
  }) async => const [];
}
