import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/sync/sync_providers.dart';
import '../features/sync/sync_status.dart';

/// Onde os dados financeiros são gravados (`arquitetura.md` §17.5).
enum DataAccessMode {
  /// Celular: grava primeiro no banco local cifrado e sincroniza depois.
  local,

  /// Web: somente online. Nada é gravado no navegador; leitura e gravação
  /// vão direto ao servidor e exigem conexão.
  remoteOnly,
}

/// Cada funcionalidade (Fase 4 em diante) escolhe o repositório pelo modo: o
/// local no celular e o remoto na Web.
final dataAccessModeProvider = Provider<DataAccessMode>(
  (ref) => kIsWeb ? DataAccessMode.remoteOnly : DataAccessMode.local,
);

/// Porta de gravação: toda tela que grava consulta antes de salvar.
class WriteGate {
  WriteGate(this._mode, this._probe);

  final DataAccessMode _mode;
  final ConnectivityProbe _probe;

  static const offlineMessage =
      'Sem conexão. No navegador não é possível salvar sem internet.';

  /// `null` se pode gravar; senão, o aviso para o usuário.
  Future<String?> blockedReason() async {
    if (_mode == DataAccessMode.local) return null;
    return await _probe.isOnline() ? null : offlineMessage;
  }
}

final writeGateProvider = Provider<WriteGate>(
  (ref) => WriteGate(
    ref.watch(dataAccessModeProvider),
    ref.watch(connectivityProbeProvider),
  ),
);
