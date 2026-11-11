import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'sync_providers.dart';
import 'sync_scheduler.dart';

/// Agendador de sincronização (entrada na conta, intervalo e retorno ao
/// primeiro plano). Na Web só acompanha a conexão (sem fila local).
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(
    ref.watch(sessionControllerProvider),
    (ownerId) => ref.read(syncStatusProvider.notifier).run(ownerId),
  )..start();
  final observer = _ResumeSync(scheduler.onResume);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    scheduler.dispose();
  });
  return scheduler;
});

class _ResumeSync with WidgetsBindingObserver {
  _ResumeSync(this._onResume);
  final VoidCallback _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}
