@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porquinho/core/infra_providers.dart';
import 'package:porquinho/core/local_database/local_database_manager.dart';
import 'package:porquinho/core/local_database/stored_database_key_provider.dart';
import 'package:porquinho/features/periods/period_providers.dart';

void main() {
  // T15: sair da conta fecha e apaga o banco; entrar de novo no mesmo processo
  // não pode reaproveitar a conexão antiga, já fechada.
  test(
    'depois de closeAndWipe o provedor entrega uma conexão nova e aberta',
    () async {
      final dir = await Directory.systemTemp.createTemp('porquinho_reopen');
      addTearDown(() => dir.delete(recursive: true));
      final manager = LocalDatabaseManager(
        store: InMemorySecureValueStore(),
        path: '${dir.path}/porquinho.db',
      );
      final container = ProviderContainer(
        overrides: [localDatabaseManagerProvider.overrideWithValue(manager)],
      );
      addTearDown(container.dispose);

      final before = await container.read(localDatabaseProvider.future);
      await before!.customSelect('SELECT 1').get();

      await manager.closeAndWipe();

      final after = await container.read(localDatabaseProvider.future);
      expect(identical(after, before), isFalse);
      // Com a conexão antiga isto lançaria "Can't re-open a database after
      // closing it".
      await after!.customSelect('SELECT 1').get();

      await manager.closeAndWipe();
    },
  );
}
