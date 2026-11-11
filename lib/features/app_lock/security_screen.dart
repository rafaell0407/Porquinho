import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_providers.dart';
import 'app_lock_service.dart';

/// Ativa, altera e desativa o bloqueio por PIN/biometria. Tela provisória: a
/// navegação definitiva ("Mais") será definida na Fase 3.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool? _enabled;
  bool _biometric = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final lock = ref.read(appLockControllerProvider);
    final enabled = await lock.service.isEnabled();
    final bio = await lock.service.biometricEnabled();
    final available = await lock.biometric.isAvailable();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _biometric = bio;
      _biometricAvailable = available;
    });
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _activate() async {
    final pins = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _PinDialog(
        title: 'Criar PIN',
        fields: ['Novo PIN (6 dígitos)', 'Repita o PIN'],
        mustMatch: true,
      ),
    );
    if (pins == null) return;
    final lock = ref.read(appLockControllerProvider);
    await lock.service.enable(pins[0], biometric: false);
    _say('Bloqueio ativado.');
    await _reload();
  }

  Future<void> _change() async {
    final pins = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _PinDialog(
        title: 'Alterar PIN',
        fields: ['PIN atual', 'Novo PIN (6 dígitos)', 'Repita o novo PIN'],
        mustMatch: true,
      ),
    );
    if (pins == null) return;
    final check = await ref
        .read(appLockControllerProvider)
        .service
        .changePin(pins[0], pins[1]);
    _say(check is PinOk ? 'PIN alterado.' : pinCheckMessage(check));
  }

  Future<void> _disable() async {
    final pins = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          const _PinDialog(title: 'Desativar bloqueio', fields: ['PIN atual']),
    );
    if (pins == null) return;
    final check = await ref
        .read(appLockControllerProvider)
        .service
        .disable(pins[0]);
    _say(check is PinOk ? 'Bloqueio desativado.' : pinCheckMessage(check));
    await _reload();
  }

  Future<void> _toggleBiometric(bool value) async {
    final lock = ref.read(appLockControllerProvider);
    if (value && !await lock.biometric.authenticate('Ativar a biometria')) {
      _say('Não foi possível confirmar a biometria.');
      return;
    }
    await lock.service.setBiometric(value);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Segurança')),
      body: enabled == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: const Text('Bloqueio por PIN'),
                  subtitle: Text(
                    enabled
                        ? 'Ativado: o PIN é pedido ao abrir o app.'
                        : 'Desativado.',
                  ),
                ),
                if (!enabled)
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Ativar bloqueio'),
                    onTap: _activate,
                  )
                else ...[
                  if (_biometricAvailable)
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text('Usar biometria'),
                      subtitle: const Text('O PIN continua como alternativa.'),
                      value: _biometric,
                      onChanged: _toggleBiometric,
                    ),
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text('Alterar PIN'),
                    onTap: _change,
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_open),
                    title: const Text('Desativar bloqueio'),
                    onTap: _disable,
                  ),
                ],
              ],
            ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({
    required this.title,
    required this.fields,
    this.mustMatch = false,
  });

  final String title;
  final List<String> fields;

  /// Os dois últimos campos devem ser iguais (novo PIN e confirmação).
  final bool mustMatch;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  late final _controllers = [
    for (final _ in widget.fields) TextEditingController(),
  ];
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() {
    final values = [for (final c in _controllers) c.text];
    if (values.any((v) => !AppLockService.isValidPin(v))) {
      setState(() => _error = 'O PIN deve ter 6 números.');
      return;
    }
    if (widget.mustMatch &&
        values[values.length - 1] != values[values.length - 2]) {
      setState(() => _error = 'Os PINs não são iguais.');
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.fields.length; i++)
            TextField(
              controller: _controllers[i],
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: widget.fields[i],
                counterText: '',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Confirmar')),
      ],
    );
  }
}
