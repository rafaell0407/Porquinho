import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/features/sync/sync_indicator.dart';
import 'package:porquinho/features/sync/sync_providers.dart';
import 'package:porquinho/features/sync/sync_status.dart';

class _Probe implements ConnectivityProbe {
  bool online = true;
  @override
  Future<bool> isOnline() async => online;
}

void main() {
  late _Probe probe;
  late SyncCounts counts;
  late int sends;
  late bool downloadComplete;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        connectivityProbeProvider.overrideWithValue(probe),
        fullSyncProvider.overrideWithValue((_) async {
          sends++;
          return downloadComplete;
        }),
        syncCountsProvider.overrideWithValue((_) async => counts),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    probe = _Probe();
    counts = const SyncCounts(pending: 0, failed: 0, attention: 0);
    sends = 0;
    downloadComplete = true;
  });

  test('modo avião: sem conexão; ao voltar, sincronizado', () async {
    final container = makeContainer();
    final notifier = container.read(syncStatusProvider.notifier);

    probe.online = false;
    counts = const SyncCounts(pending: 2, failed: 0, attention: 0);
    await notifier.run('u1');
    var status = container.read(syncStatusProvider);
    expect(status.phase, SyncPhase.offline);
    expect(status.pendingCount, 2);
    expect(sends, 0); // sem conexão não tenta enviar

    probe.online = true;
    counts = const SyncCounts(pending: 0, failed: 0, attention: 0);
    await notifier.run('u1');
    status = container.read(syncStatusProvider);
    expect(status.phase, SyncPhase.synced);
    expect(status.pendingCount, 0);
    expect(status.lastSyncAt, isNotNull);
    expect(sends, 1);
  });

  test('envio com falha transitória também aparece como sem conexão', () async {
    final container = makeContainer();
    counts = const SyncCounts(pending: 1, failed: 1, attention: 0);
    await container.read(syncStatusProvider.notifier).run('u1');
    expect(container.read(syncStatusProvider).phase, SyncPhase.offline);
  });

  test('download incompleto não aparece como sincronizado (L1)', () async {
    final container = makeContainer();
    downloadComplete = false;
    await container.read(syncStatusProvider.notifier).run('u1');
    final status = container.read(syncStatusProvider);
    expect(status.phase, SyncPhase.offline);
    expect(status.lastSyncAt, isNull);
  });

  test('conflitos e recusas contam como itens de atenção', () async {
    final container = makeContainer();
    counts = const SyncCounts(pending: 0, failed: 0, attention: 3);
    await container.read(syncStatusProvider.notifier).run('u1');
    final status = container.read(syncStatusProvider);
    expect(status.phase, SyncPhase.synced);
    expect(status.attentionCount, 3);
  });

  testWidgets('faixa mostra sem conexão e itens de atenção', (tester) async {
    final container = makeContainer();
    probe.online = false;
    counts = const SyncCounts(pending: 2, failed: 0, attention: 1);
    await container.read(syncStatusProvider.notifier).run('u1');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SyncIndicator())),
      ),
    );

    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(find.textContaining('1 item(ns) precisam'), findsOneWidget);
  });

  testWidgets('aviso de banco recuperado aparece (D9)', (tester) async {
    final container = ProviderContainer(
      overrides: [recoveryNoticeProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SyncIndicator())),
      ),
    );
    expect(find.byKey(const Key('faixa-recuperacao')), findsOneWidget);
    expect(find.textContaining('baixados de novo'), findsOneWidget);
  });

  testWidgets('sincronizado e sem pendências: nenhuma faixa', (tester) async {
    final container = makeContainer();
    await container.read(syncStatusProvider.notifier).run('u1');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SyncIndicator())),
      ),
    );

    expect(find.byType(Icon), findsNothing);
    expect(find.textContaining('Sem conexão'), findsNothing);
  });

  test('texto do estado em Mais', () {
    expect(syncStatusLabel(const SyncStatus()), contains('Aguardando'));
    expect(
      syncStatusLabel(const SyncStatus(phase: SyncPhase.offline)),
      contains('Sem conexão'),
    );
    expect(
      syncStatusLabel(
        SyncStatus(
          phase: SyncPhase.synced,
          lastSyncAt: DateTime(2026, 11, 10, 9, 5),
        ),
      ),
      'Sincronizado às 09:05.',
    );
  });
}
