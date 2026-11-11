import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_access.dart';
import '../auth/auth_providers.dart';
import '../periods/period_providers.dart';
import 'category_repository.dart';
import 'category_service.dart';
import 'local_category_repository.dart';
import 'remote_category_repository.dart';

final categoryRepositoryProvider = FutureProvider<CategoryRepository>((
  ref,
) async {
  final mode = ref.watch(dataAccessModeProvider);
  if (mode == DataAccessMode.remoteOnly || kIsWeb) {
    return RemoteCategoryRepository(
      ref.watch(remoteTableReaderProvider),
      ref.watch(remoteGatewayProvider),
    );
  }
  final db = (await ref.watch(localDatabaseProvider.future))!;
  final recorder = (await ref.watch(localRecorderProvider.future))!;
  return LocalCategoryRepository(db, ref.watch(ownerIdProvider), recorder);
});

final categoryServiceProvider = FutureProvider<CategoryService>(
  (ref) async =>
      CategoryService(await ref.watch(categoryRepositoryProvider.future)),
);

/// Categorias e subcategorias para a tela; recarregue com `ref.invalidate`
/// depois de gravar.
final categoryDataProvider = FutureProvider<CategoryData>((ref) async {
  final service = await ref.watch(categoryServiceProvider.future);
  return service.load();
});

/// `true` logo após escolher o período no primeiro acesso: mostra a tela de
/// sugestões de categorias uma única vez (RN024).
final pendingSuggestionsProvider = NotifierProvider<PendingSuggestions, bool>(
  PendingSuggestions.new,
);

class PendingSuggestions extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void done() => state = false;
}
