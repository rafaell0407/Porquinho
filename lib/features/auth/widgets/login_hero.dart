import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'norte_mark.dart';

/// Como a parte de cima do login se adapta à altura disponível.
enum LoginHeroMode {
  /// Cena completa com marca, slogan e frase.
  full,

  /// Cena com a marca em linha (sem slogan), para telas baixas.
  medium,

  /// Só a marca em linha, sem cena (teclado aberto ou tela muito baixa).
  compact,
}

/// Altura e modo da área superior, calculados a partir da altura da tela.
class LoginHeroLayout {
  const LoginHeroLayout(this.mode, this.height);

  final LoginHeroMode mode;

  /// Altura total da área superior, incluindo a barra de status.
  final double height;

  /// Espaço reservado para o painel de acesso, para os campos e o botão
  /// "Entrar" ficarem sempre visíveis.
  static const panelReserve = 528.0;
  static const compactBody = 76.0;
  static const _maxBody = 430.0;

  static LoginHeroLayout compute({
    required double height,
    required double topInset,
  }) {
    final spare = height - topInset - panelReserve;
    if (spare >= 250) {
      final body = math.min(math.min(spare, height * 0.5), _maxBody);
      return LoginHeroLayout(LoginHeroMode.full, topInset + body);
    }
    if (spare >= 130) {
      return LoginHeroLayout(LoginHeroMode.medium, topInset + spare);
    }
    return LoginHeroLayout(LoginHeroMode.compact, topInset + compactBody);
  }
}

/// Parte superior do login: cena (aurora, montanha e arco da bússola) e a
/// marca do Norte. A cena é uma imagem por tema; os textos são widgets reais.
class LoginHero extends StatelessWidget {
  const LoginHero({
    super.key,
    required this.layout,
    required this.topInset,
    this.overlap = 0,
  });

  final LoginHeroLayout layout;
  final double topInset;

  /// Quanto o painel de baixo sobrepõe a cena (cantos arredondados).
  final double overlap;

  static const darkScene = 'assets/login/login_scene_dark.webp';
  static const lightScene = 'assets/login/login_scene_light.webp';

  // Dimensões e posições da imagem de origem (pixels).
  static const _imgW = 1024.0;
  static const _imgH = 632.0;

  /// Fração da altura da imagem acima do "N" do arco.
  static const _arcTop = 0.665;

  /// Tom do pé da montanha em cada cena (vem das próprias imagens).
  static Color _ground(bool dark) =>
      dark ? const Color(0xFF030807) : const Color(0xFF1A5245);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final height = layout.height + overlap;

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        if (layout.mode == LoginHeroMode.compact) {
          return SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.only(top: topInset, bottom: overlap),
              child: const Center(child: _BrandRow()),
            ),
          );
        }

        final body = height - topInset;
        // Proporção próxima da referência: a cena ocupa a largura (com leve
        // ampliação) e o céu acima dela se funde ao fundo.
        final scale = math.max(width * 1.12 / _imgW, body * 0.6 / _imgH);
        final imgW = _imgW * scale;
        final imgH = _imgH * scale;
        // A montanha fica inteira acima do painel, que começa logo abaixo da
        // base (como na referência).
        final imgBottom = overlap + 4;
        // Topo do "N" do arco, medido do topo da área.
        final arcTop = height - imgBottom - imgH * (1 - _arcTop);
        final brandTop =
            topInset + (layout.mode == LoginHeroMode.full ? 22.0 : 14.0);
        // A marca termina com folga acima do "N" (encolhe se faltar espaço).
        final brandSpace = arcTop - brandTop - 16;

        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: (width - imgW) / 2,
                bottom: imgBottom,
                width: imgW,
                height: imgH,
                child: ExcludeSemantics(
                  child: Image.asset(
                    dark ? darkScene : lightScene,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              // Funde o topo da imagem com o fundo quando a área é mais alta
              // que a imagem.
              if (imgH + imgBottom < height)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: height - imgBottom - imgH * 0.55,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scheme.surface,
                          scheme.surface,
                          scheme.surface.withValues(alpha: 0),
                        ],
                        stops: [
                          0,
                          (height - imgBottom - imgH) /
                              (height - imgBottom - imgH * 0.55),
                          1,
                        ],
                      ),
                    ),
                  ),
                ),
              // Chão: a base da montanha se funde num tom contínuo até o
              // painel, sem a linha reta da borda da imagem.
              Positioned(
                left: 0,
                right: 0,
                bottom: imgBottom - 1,
                height: imgH * 0.045,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _ground(dark).withValues(alpha: 0),
                        _ground(dark),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: imgBottom,
                child: ColoredBox(color: _ground(dark)),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: brandTop,
                height: math.max(0, brandSpace),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: layout.mode == LoginHeroMode.full
                        ? const _BrandFull()
                        : const _BrandRow(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandFull extends StatelessWidget {
  const _BrandFull();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slogan = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.3,
      color: scheme.onSurface,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NorteMark(size: 78),
        const SizedBox(height: 2),
        Semantics(
          header: true,
          child: Text(
            'Norte',
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              height: 1.1,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: slogan,
            children: [
              const TextSpan(text: 'Suas finanças,\n'),
              TextSpan(
                text: 'na direção certa.',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Organize. Equilibre. Evolua.',
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NorteMark(size: 50),
        const SizedBox(width: 10),
        Semantics(
          header: true,
          child: Text(
            'Norte',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
