import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/data_access.dart';
import 'package:porquinho/core/infra_providers.dart';
import 'package:porquinho/features/sync/sync_providers.dart';
import 'package:porquinho/features/sync/sync_status.dart';

class _Probe implements ConnectivityProbe {
  _Probe(this.online);
  bool online;
  @override
  Future<bool> isOnline() async => online;
}

void main() {
  test('celular grava localmente mesmo sem conexão', () async {
    final gate = WriteGate(DataAccessMode.local, _Probe(false));
    expect(await gate.blockedReason(), isNull);
  });

  test('Web (somente online): sem conexão bloqueia a gravação', () async {
    final probe = _Probe(false);
    final gate = WriteGate(DataAccessMode.remoteOnly, probe);
    expect(await gate.blockedReason(), WriteGate.offlineMessage);

    probe.online = true;
    expect(await gate.blockedReason(), isNull);
  });

  test('Web: sem caminho de banco nada é gravado no navegador', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(localDatabaseManagerProvider), isNull);
    expect(container.read(syncNowProvider), isNull);
  });

  test('Web: o acompanhamento só mede a conexão, sem fila', () async {
    final probe = _Probe(false);
    final container = ProviderContainer(
      overrides: [connectivityProbeProvider.overrideWithValue(probe)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(syncStatusProvider.notifier);

    await notifier.run('u1');
    expect(container.read(syncStatusProvider).phase, SyncPhase.offline);

    probe.online = true;
    await notifier.run('u1');
    expect(container.read(syncStatusProvider).phase, SyncPhase.synced);
  });
}
