import 'package:flutter/material.dart';

/// Tema central do Norte (Menta + Inter), claro e escuro.
///
/// Telas não devem ter cor própria: usam `Theme.of(context).colorScheme` e
/// `NorteColors` (cores com significado fixo).
abstract final class NorteTheme {
  static const fontFamily = 'Inter';

  static ThemeData light() => _build(_lightScheme, NorteColors.light);
  static ThemeData dark() => _build(_darkScheme, NorteColors.dark);

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF5FD4B0),
    onPrimary: Color(0xFF03241B),
    primaryContainer: Color(0xFF12382E),
    onPrimaryContainer: Color(0xFFBDF2E1),
    secondary: Color(0xFF8E9997),
    onSecondary: Color(0xFF040505),
    secondaryContainer: Color(0xFF1A1F1D),
    onSecondaryContainer: Color(0xFFF2F5F4),
    error: Color(0xFFF27C7C),
    onError: Color(0xFF2B0808),
    errorContainer: Color(0xFF4A1D1D),
    onErrorContainer: Color(0xFFFFD9D9),
    surface: Color(0xFF040505),
    onSurface: Color(0xFFF2F5F4),
    onSurfaceVariant: Color(0xFF8E9997),
    surfaceContainerLowest: Color(0xFF000000),
    surfaceContainerLow: Color(0xFF090B0A),
    surfaceContainer: Color(0xFF0E1110),
    surfaceContainerHigh: Color(0xFF141816),
    surfaceContainerHighest: Color(0xFF1A1F1D),
    outline: Color(0xFF3A4240),
    outlineVariant: Color(0xFF1F2523),
    inverseSurface: Color(0xFFF2F5F4),
    onInverseSurface: Color(0xFF111615),
    inversePrimary: Color(0xFF0E7C62),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0E7C62),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCDEBE1),
    onPrimaryContainer: Color(0xFF06382B),
    secondary: Color(0xFF5D6967),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8EDEB),
    onSecondaryContainer: Color(0xFF111615),
    error: Color(0xFFC23B3B),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFBE0E0),
    onErrorContainer: Color(0xFF5A1414),
    surface: Color(0xFFF4F6F5),
    onSurface: Color(0xFF111615),
    onSurfaceVariant: Color(0xFF5D6967),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAFBFA),
    surfaceContainer: Color(0xFFFFFFFF),
    surfaceContainerHigh: Color(0xFFEFF2F1),
    surfaceContainerHighest: Color(0xFFE8EDEB),
    outline: Color(0xFFB4BDBB),
    outlineVariant: Color(0xFFDCE2E0),
    inverseSurface: Color(0xFF111615),
    onInverseSurface: Color(0xFFF2F5F4),
    inversePrimary: Color(0xFF5FD4B0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData _build(ColorScheme scheme, NorteColors semantic) {
    const pill = StadiumBorder();
    final line = BorderSide(color: scheme.outlineVariant);
    final base = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [semantic],
    );
    final text = base.textTheme;

    return base.copyWith(
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: scheme.brightness == Brightness.light ? line : BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: line,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: line,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: pill,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: pill,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: pill,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: pill,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: line,
        backgroundColor: Colors.transparent,
        selectedColor: scheme.onSurface,
        secondarySelectedColor: scheme.onSurface,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: scheme.surface,
        ),
        checkmarkColor: scheme.surface,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: pill,
          side: line,
          selectedBackgroundColor: scheme.surfaceContainerHighest,
          selectedForegroundColor: scheme.onSurface,
          foregroundColor: scheme.onSurfaceVariant,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.surfaceContainerHighest,
        indicatorShape: pill,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}

/// Cores com significado fixo, iguais em todo o app (acessar com
/// `Theme.of(context).extension<NorteColors>()!`).
@immutable
class NorteColors extends ThemeExtension<NorteColors> {
  const NorteColors({
    required this.income,
    required this.expense,
    required this.investment,
    required this.pending,
    required this.pendingBackground,
  });

  final Color income;
  final Color expense;
  final Color investment;
  final Color pending;
  final Color pendingBackground;

  static const dark = NorteColors(
    income: Color(0xFF6FD3A0),
    expense: Color(0xFFF27C7C),
    investment: Color(0xFFB39DFA),
    pending: Color(0xFFF0B954),
    pendingBackground: Color(0x24F0B954),
  );

  static const light = NorteColors(
    income: Color(0xFF12784B),
    expense: Color(0xFFC23B3B),
    investment: Color(0xFF6A4BD3),
    pending: Color(0xFF9A5F00),
    pendingBackground: Color(0x1FB06E00),
  );

  /// Cores do tema atual; se o tema não for o do Norte (por exemplo, em testes
  /// com `MaterialApp` simples), usa as padrão do brilho correspondente.
  static NorteColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<NorteColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  NorteColors copyWith({
    Color? income,
    Color? expense,
    Color? investment,
    Color? pending,
    Color? pendingBackground,
  }) {
    return NorteColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      investment: investment ?? this.investment,
      pending: pending ?? this.pending,
      pendingBackground: pendingBackground ?? this.pendingBackground,
    );
  }

  @override
  NorteColors lerp(ThemeExtension<NorteColors>? other, double t) {
    if (other is! NorteColors) return this;
    return NorteColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      investment: Color.lerp(investment, other.investment, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      pendingBackground: Color.lerp(
        pendingBackground,
        other.pendingBackground,
        t,
      )!,
    );
  }
}
