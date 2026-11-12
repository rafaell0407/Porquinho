import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/logout_flow.dart';
import 'app_lock_providers.dart';

/// Tela exibida ao abrir o app quando o bloqueio está ativado (RF003).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _canUseBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometric());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    final lock = ref.read(appLockControllerProvider);
    final available =
        await lock.service.biometricEnabled() &&
        await lock.biometric.isAvailable();
    if (!mounted) return;
    setState(() => _canUseBiometric = available);
    if (available) await _biometric();
  }

  Future<void> _biometric() async {
    await ref.read(appLockControllerProvider).unlockWithBiometric();
  }

  Future<void> _submit(String value) async {
    if (value.length != 6 || _busy) return;
    setState(() => _busy = true);
    final check = await ref
        .read(appLockControllerProvider)
        .unlockWithPin(value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = pinCheckMessage(check);
      _pin.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Norte',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Digite seu PIN para continuar.'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pin,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onChanged: _submit,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => forgotPin(context, ref),
                    child: const Text('Esqueci o PIN'),
                  ),
                  if (_canUseBiometric) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _biometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Usar biometria'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
