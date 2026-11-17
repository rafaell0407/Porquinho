@TestOn('vm')
@Tags(['supabase_local'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/domain/user_clock.dart';
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
import 'package:porquinho/features/sync/supabase_sync_gateway.dart';
import 'package:porquinho/features/sync/supabase_sync_reader.dart';
import 'package:porquinho/features/sync/sync_models.dart';
import 'package:porquinho/features/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/supabase_local_support.dart';

/// GF3.8: Gestão de Faturas contra o Supabase LOCAL — dois aparelhos,
/// paridade aparelho × servidor, isolamento e pagamento duplicado.
class _Device {
  _Device(this.account, this.client) {
    repo = LocalCardBillsRepository(db, account.id);
    sync = SyncService(db, SupabaseSyncGateway(client));
    source = SupabaseCardBillsSource(client);
  }

  final TestAccount account;
  final SupabaseClient client;
  final PorquinhoDatabase db = memoryDb();
  late final LocalCardBillsRepository repo;
  late final SyncService sync;
  late final SupabaseCardBillsSource source;

  Future<void> syncAll() async {
    for (var i = 0; i < 3; i++) {
      await sync.syncOnce(account.id);
    }
    await CardBillsDownloader(db, source).replaceAll(account.id);
  }
}

void main() {
  final r = Random();
  final today = const UserClock().today();
  final now = DateTime.now().toUtc();
  String id() => testUuid(r);

  CreditCard card() =>
      CreditCard(id: id(), name: 'Nubank', closingDay: 10, dueDay: 17);

  Future<void> seed(_Device device, CreditCard c) async {
    await device.repo.apply(createCard(c));
    var data = await device.repo.load();
    await device.repo.apply(
      planNewPurchase(
        id: id(),
        draft: PurchaseDraft(
          cardId: c.id,
          description: 'TV',
          purchasedOn: today,
          installmentCount: 3,
          amountMode: AmountMode.total,
          amount: BigInt.from(100000),
        ),
        data: data,
        today: today,
      ).change,
    );
    await device.repo.apply(
      createSubscription(
        Subscription(
          id: id(),
          cardId: c.id,
          description: 'Streaming',
          monthlyAmount: BigInt.from(3990),
          startMonth: CardBillsBoard.build(
            await device.repo.load(),
            today,
          ).pending.first.month,
        ),
      ),
    );
    data = await device.repo.load();
    await device.repo.apply(generateCharges(data, today));
    await device.repo.apply(
      CardBillsChange(
        writes: [
          RowWrite(
            CardBillTables.reserveEvents,
            adjustmentTo(
              BigInt.from(200000),
              data.reserveEvents,
              id: id(),
              now: now,
            )!.toRow(),
          ),
        ],
        summary: 'Reserva',
      ),
    );
  }

  test(
    'dois aparelhos convergem; servidor guarda o mesmo que o aparelho',
    () async {
      final account = await newTestAccount(r);
      final a = _Device(account, await account.device());
      final b = _Device(account, await account.device());
      final c = card();
      await seed(a, c);
      await a.syncAll();
      expect(await a.sync.operations(account.id), isEmpty);
      await b.syncAll();

      final local = await a.repo.load();
      final remote = await loadRemote(a.source);
      final onB = await b.repo.load();
      for (final data in [remote, onB]) {
        expect(data.cards.single.toRow(), local.cards.single.toRow());
        expect(
          {for (final i in data.installments) i.id: i.toRow()},
          {for (final i in local.installments) i.id: i.toRow()},
        );
        expect(data.charges.single.toRow(), local.charges.single.toRow());
        final board = CardBillsBoard.build(data, today);
        final mine = CardBillsBoard.build(local, today);
        expect(board.committed, mine.committed);
        expect(board.reserve, BigInt.from(200000));
        expect(board.uncommitted, mine.uncommitted);
      }

      // Exclusão em B some em A (comparação com o servidor).
      final dataB = await b.repo.load();
      await b.repo.apply(deletePurchase(dataB.purchases.single, dataB));
      await b.syncAll();
      await a.syncAll();
      expect((await a.repo.load()).installments, isEmpty);

      // Web (remoto) lê o mesmo.
      final web = RemoteCardBillsRepository(
        a.source,
        SupabaseSyncGateway(a.client),
      );
      expect((await web.load()).charges.length, 1);
    },
    skip: supabaseEnabled ? false : supabaseSkipReason,
  );

  test(
    'pagamento duplicado: o segundo não é aplicado; manter o do aparelho',
    () async {
      final account = await newTestAccount(r);
      final a = _Device(account, await account.device());
      final b = _Device(account, await account.device());
      await seed(a, card());
      await a.syncAll();
      await b.syncAll();

      Future<void> pay(_Device d, PaymentSource source) async {
        final data = await d.repo.load();
        final view = CardBillsBoard.build(data, today).pending.first;
        final plan = planPayment(
          expectedAmount: view.value,
          paidAmount: view.value,
          source: source,
          events: data.reserveEvents,
        );
        await d.repo.pay(
          buildPayment(
            view: view,
            plan: plan,
            paidOn: today,
            paymentId: id(),
            now: now,
            data: data,
          ),
        );
      }

      await pay(a, PaymentSource.reserve);
      await pay(b, PaymentSource.other);
      await a.syncAll();
      await b.syncAll();
      final afterA = CardBillsBoard.build(await loadRemote(a.source), today);
      final paidByA = afterA.paid.single.payment!;
      expect(paidByA.source, PaymentSource.reserve);
      expect(afterA.reserve, BigInt.from(200000) - paidByA.reserveUsed);

      final attention = LocalAttentionRepository(
        b.db,
        account.id,
        b.sync,
        DownloadService(b.db, SupabaseSyncReader(b.client)),
      );
      final items = await attention.items();
      expect(items.single.isCardBillPayment, isTrue);
      await attention.resolve(items.single, ConflictResolution.keepLocal);
      await b.syncAll();
      await a.syncAll();
      for (final data in [
        await loadRemote(a.source),
        await a.repo.load(),
        await b.repo.load(),
      ]) {
        final board = CardBillsBoard.build(data, today);
        expect(board.paid.single.payment!.source, PaymentSource.other);
        expect(
          board.reserve,
          BigInt.from(200000),
          reason: 'reserva descontada uma vez só',
        );
      }
    },
    skip: supabaseEnabled ? false : supabaseSkipReason,
  );

  test('isolamento: outro usuário não vê nem altera os dados', () async {
    final owner = await newTestAccount(r);
    final other = await newTestAccount(r);
    final a = _Device(owner, await owner.device());
    await seed(a, card());
    await a.syncAll();
    final intruder = _Device(other, await other.device());
    expect((await loadRemote(intruder.source)).cards, isEmpty);
    final victim = await a.repo.load();
    // Apagar o cartão de outro usuário não tem efeito (RLS + dono na RPC).
    await RemoteCardBillsRepository(
      intruder.source,
      SupabaseSyncGateway(intruder.client),
    ).apply(deleteCard(victim.cards.single, victim));
    expect((await loadRemote(a.source)).cards.length, 1);
    // Gravação recusada pelo servidor (limite) vira recusa definitiva.
    await expectLater(
      SupabaseSyncGateway(a.client).call(CardBillsRpc.apply, {
        'p_operation_id': id(),
        'p_changes': {
          'writes': [
            {
              'table': CardBillTables.cards,
              'row': {'id': id(), 'name': 'X', 'closing_day': 40, 'due_day': 1},
            },
          ],
        },
      }),
      throwsA(isA<SyncRejectedError>()),
    );
  }, skip: supabaseEnabled ? false : supabaseSkipReason);
}
