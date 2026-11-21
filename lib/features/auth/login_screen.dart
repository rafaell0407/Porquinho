import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/norte_theme.dart';

import 'auth_models.dart';
import 'auth_providers.dart';
import 'widgets/google_g_icon.dart';
import 'widgets/login_hero.dart';
import 'widgets/login_panel.dart';

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
  final _confirmPassword = TextEditingController();
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
    _confirmPassword.dispose();
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: LayoutBuilder(
        builder: (context, c) {
          // Em telas largas (Web), a tela vira um cartão centralizado no
          // formato de celular.
          final wide = c.maxWidth > 600;
          final media = MediaQuery.of(context);
          final width = wide ? 460.0 : c.maxWidth;
          final height = wide ? math.max(0.0, c.maxHeight - 48) : c.maxHeight;
          final topInset = wide ? 0.0 : media.padding.top;
          final bottomInset = wide ? 0.0 : media.padding.bottom;
          final layout = LoginHeroLayout.compute(
            height: height,
            topInset: topInset,
          );
          final page = SingleChildScrollView(
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LoginHero(
                    layout: layout,
                    topInset: topInset,
                    overlap: LoginPanel.radius,
                  ),
                ),
                Column(
                  children: [
                    SizedBox(height: layout.height),
                    LoginPanel(
                      minHeight: math.max(0, height - layout.height),
                      bottomInset: bottomInset,
                      child: _form(context),
                    ),
                  ],
                ),
              ],
            ),
          );
          if (!wide) return page;
          return Center(
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: page,
            ),
          );
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: color, width: width),
        );
    final line = scheme.outline.withValues(alpha: 0.45);
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(icon, color: scheme.onSurfaceVariant, size: 22),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(line),
      enabledBorder: border(line),
      focusedBorder: border(scheme.primary, 1.5),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.5),
    );
  }

  Widget _message(BuildContext context, String text, {required bool error}) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.info_outline,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: error ? scheme.error : scheme.onSurface,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const link = TextStyle(
      fontFamily: NorteTheme.fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 15,
    );
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _creating ? 'Crie sua conta' : 'Bem-vindo ao Norte',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _creating
                ? 'Informe seu e-mail e escolha uma senha.'
                : 'Entre na sua conta para continuar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: TextStyle(fontSize: 16, color: scheme.onSurface),
            decoration: _fieldDecoration(
              context,
              label: 'E-mail',
              icon: Icons.mail_outline_rounded,
            ),
            validator: (v) => (v == null || !v.trim().contains('@'))
                ? 'Informe um e-mail válido.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _hidePassword,
            textInputAction: _creating
                ? TextInputAction.next
                : TextInputAction.done,
            autofillHints: [
              _creating ? AutofillHints.newPassword : AutofillHints.password,
            ],
            style: TextStyle(fontSize: 16, color: scheme.onSurface),
            decoration: _fieldDecoration(
              context,
              label: 'Senha',
              icon: Icons.lock_outline_rounded,
              suffix: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
                  color: scheme.onSurfaceVariant,
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Informe a senha.' : null,
            onFieldSubmitted: (_) => _creating || _busy ? null : _submit(),
          ),
          if (_creating) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassword,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              style: TextStyle(fontSize: 16, color: scheme.onSurface),
              decoration: _fieldDecoration(
                context,
                label: 'Repita a senha',
                icon: Icons.lock_outline_rounded,
              ),
              validator: (v) =>
                  v != _password.text ? 'As senhas não são iguais.' : null,
              onFieldSubmitted: (_) => _busy ? null : _submit(),
            ),
          ],
          const SizedBox(height: 16),
          if (_blockedCount > 0)
            _message(
              context,
              'Este aparelho ainda tem $_blockedCount '
              'operação(ões) de outra conta que não foram '
              'enviadas. Entre com a conta anterior, conecte-se '
              'à internet e aguarde a sincronização; depois será '
              'possível trocar de conta.',
              error: true,
            ),
          if (_error != null) _message(context, _error!, error: true),
          if (_info != null) _message(context, _info!, error: false),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: const StadiumBorder(),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              disabledBackgroundColor: scheme.primary.withValues(alpha: 0.55),
              disabledForegroundColor: scheme.onPrimary,
              textStyle: const TextStyle(
                fontFamily: NorteTheme.fontFamily,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: _busy
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: scheme.onPrimary,
                    ),
                  )
                : Text(_creating ? 'Criar conta' : 'Entrar'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _google,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: const StadiumBorder(),
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.outline, width: 1.2),
              textStyle: const TextStyle(
                fontFamily: NorteTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GoogleGIcon(size: 22),
                SizedBox(width: 12),
                Flexible(child: Text('Entrar com Google')),
              ],
            ),
          ),
          if (!_creating) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: scheme.primary,
                  textStyle: link,
                ),
                child: const Text('Esqueci minha senha'),
              ),
            ),
          ] else
            const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                Expanded(child: Divider(color: scheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'ou',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: scheme.outlineVariant)),
              ],
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _creating ? 'Já tem conta?' : 'Ainda não tem conta?',
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _creating = !_creating;
                        _confirmPassword.clear();
                        _error = null;
                        _info = null;
                      }),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: scheme.primary,
                  textStyle: link,
                ),
                child: Text(_creating ? 'Entrar' : 'Criar conta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
