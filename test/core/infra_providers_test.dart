import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/infra_providers.dart';
import 'package:porquinho/features/auth/auth_providers.dart';
import 'package:porquinho/features/sync/sync_providers.dart';

void main() {
  test('sem caminho de banco (Web) não há banco nem sync', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(localDatabaseManagerProvider), isNull);
    expect(container.read(syncNowProvider), isNull);
  });

  test('sem banco local a contagem de pendências é zero', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(pendingSyncCounterProvider).countPending('u1'),
      0,
    );
  });

  test('com caminho de banco há gerenciador', () {
    final container = ProviderContainer(
      overrides: [databasePathProvider.overrideWithValue('x/porquinho.db')],
    );
    addTearDown(container.dispose);

    expect(container.read(localDatabaseManagerProvider), isNotNull);
  });
}
