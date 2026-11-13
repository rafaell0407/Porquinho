import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_models.dart';
import 'auth_providers.dart';

/// Tela de login (RF001–RF002): e-mail e senha, Google, cadastro e
/// recuperação de senha.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;
  String? _info;

  int get _blockedCount {
    final state = ref.watch(sessionStateProvider).value;
    return state is SessionSignedOut ? state.blockedPendingCount : 0;
  }

  bool _googleOpen = false;
  Timer? _returnTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Voltando do navegador sem concluir o login com Google, libera os botões
  /// para nova tentativa. A pequena espera dá tempo de o retorno do login
  /// chegar, se o usuário tiver concluído.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_googleOpen) return;
    if (state == AppLifecycleState.resumed) {
      _returnTimer?.cancel();
      _returnTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted || !_googleOpen) return;
        setState(() {
          _googleOpen = false;
          _busy = false;
          _error = authFailureMessage(AuthFailureCode.cancelled);
        });
      });
    } else if (state == AppLifecycleState.paused) {
      _returnTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _returnTimer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Tempo máximo de espera por e-mail/senha: sem resposta, o usuário volta a
  /// poder tentar em vez de ficar preso no indicador de carregamento.
  static const _timeout = Duration(seconds: 15);

  Future<void> _run(
    Future<void> Function() action, {
    bool withTimeout = true,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await (withTimeout ? action().timeout(_timeout) : action());
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = authFailureMessage(e.code));
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = authFailureMessage(AuthFailureCode.network));
      }
    } on Object {
      if (mounted) {
        setState(() => _error = authFailureMessage(AuthFailureCode.unknown));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authRepositoryProvider);
    final session = ref.read(sessionControllerProvider);
    await _run(() async {
      if (_creating) {
        final user = await auth.signUpWithEmail(_email.text, _password.text);
        if (user == null && mounted) {
          setState(() {
            _creating = false;
            _info =
                'Enviamos um e-mail de confirmação para ${_email.text.trim()}. '
                'Confirme e depois entre.';
          });
        }
      } else {
        await session.signInWithEmail(_email.text, _password.text);
      }
    });
  }

  Future<void> _google() async {
    _googleOpen = true;
    await _run(
      () => ref.read(sessionControllerProvider).signInWithGoogle(),
      withTimeout: false,
    );
    _googleOpen = false;
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _error = 'Informe seu e-mail para recuperar a senha.';
        _info = null;
      });
      return;
    }
    final auth = ref.read(authRepositoryProvider);
    await _run(() async {
      await auth.sendPasswordReset(email);
      if (mounted) {
        setState(
          () => _info =
              'Se o e-mail estiver cadastrado, enviamos o link de recuperação.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Norte',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _creating ? 'Criar conta' : 'Entrar',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || !v.trim().contains('@'))
                          ? 'Informe um e-mail válido.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      autofillHints: [
                        _creating
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Informe a senha.' : null,
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    const SizedBox(height: 16),
                    if (_blockedCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Este aparelho ainda tem $_blockedCount '
                          'operação(ões) de outra conta que não foram '
                          'enviadas. Entre com a conta anterior, conecte-se '
                          'à internet e aguarde a sincronização; depois será '
                          'possível trocar de conta.',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (_info != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_info!),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_creating ? 'Criar conta' : 'Entrar'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _google,
                      child: const Text('Entrar com Google'),
                    ),
                    const SizedBox(height: 12),
                    if (!_creating)
                      TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text('Esqueci minha senha'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _creating = !_creating;
                              _error = null;
                              _info = null;
                            }),
                      child: Text(
                        _creating
                            ? 'Já tenho conta. Entrar'
                            : 'Não tenho conta. Criar conta',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
