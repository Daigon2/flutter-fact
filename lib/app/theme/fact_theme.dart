import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';

/// Setzt die FACT-Tokens in `ThemeData` um.
///
/// Material-Komponenten spielen in FACT eine kleine Rolle, die Oberfläche ist
/// weitgehend selbst gezeichnet. Deshalb bleibt hier bewusst wenig konfiguriert:
/// Hintergrund, Grundtext, Auswahlfarbe. Alles Weitere holen Widgets über
/// `context.factColors` und `FactTypography`, damit die Werte dort stehen, wo
/// sie im JSX auch stehen.
abstract final class FactTheme {
  /// `ColorScheme.fromSeed` rechnet eine HCT-Palette aus und ist in der
  /// Flutter-Doku ausdrücklich als teuer markiert. Beide Varianten hängen nur
  /// an Seed-Farbe und Brightness, und beides ist hier konstant. Also wird das
  /// Ergebnis je Variante genau einmal berechnet und gehalten, statt bei jedem
  /// `build` der App erneut. `static final` initialisiert lazy, es entsteht
  /// also keine Startlast für eine Variante, die nie gebraucht wird.
  ///
  /// Bewusst wird nur das `ColorScheme` gehalten und nicht das ganze
  /// `ThemeData`: dessen `platform` folgt `defaultTargetPlatform`, und ein
  /// zwischengespeichertes `ThemeData` würde einen Test mit
  /// `debugDefaultTargetPlatformOverride` still auf der zuerst aufgelösten
  /// Plattform festhalten.
  static final ColorScheme _darkScheme = _scheme(
    FactColors.dark,
    Brightness.dark,
  );

  static final ColorScheme _lightScheme = _scheme(
    FactColors.light,
    Brightness.light,
  );

  static ThemeData dark() =>
      _build(FactColors.dark, Brightness.dark, _darkScheme);

  static ThemeData light() =>
      _build(FactColors.light, Brightness.light, _lightScheme);

  static ColorScheme _scheme(FactColors tokens, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: tokens.red,
      brightness: brightness,
    ).copyWith(
      surface: tokens.surface,
      onSurface: tokens.ink,
      primary: tokens.red,
      // `coin` und nicht `gold`: für Material-Slots gibt es keine
      // PWA-Vorlage, und `--coin` ist der Gold-Ton, den die Quelle im hellen
      // Theme absenkt. Auf der cremefarbenen Fläche ist das der lesbare Wert.
      secondary: tokens.coin,
    );
  }

  static ThemeData _build(
    FactColors tokens,
    Brightness brightness,
    ColorScheme scheme,
  ) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[tokens],
      scaffoldBackgroundColor: tokens.bg,
      canvasColor: tokens.bg,
      colorScheme: scheme,
      textTheme: _textTheme(base.textTheme, tokens),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.coin,
        selectionColor: tokens.coinSoft,
        selectionHandleColor: tokens.coin,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: const Color(0x00000000),
    );
  }

  /// Bildet die PWA-Rollen auf die Material-Slots ab, die Flutter-Widgets ohne
  /// eigenen Stil verwenden. Größen bleiben bei Materials Vorgaben, weil FACT
  /// seine echten Größen pro Screen aus dem JSX setzt.
  static TextTheme _textTheme(TextTheme base, FactColors tokens) {
    final display = FactTypography.displayTitle.copyWith(color: tokens.ink);
    final heading = FactTypography.heading.copyWith(color: tokens.ink);
    final body = FactTypography.bodyText.copyWith(color: tokens.ink);
    final label = FactTypography.emphasis.copyWith(color: tokens.ink);

    return base.copyWith(
      displayLarge: base.displayLarge?.merge(display),
      displayMedium: base.displayMedium?.merge(display),
      displaySmall: base.displaySmall?.merge(display),
      headlineLarge: base.headlineLarge?.merge(heading),
      headlineMedium: base.headlineMedium?.merge(heading),
      headlineSmall: base.headlineSmall?.merge(heading),
      titleLarge: base.titleLarge?.merge(heading),
      titleMedium: base.titleMedium?.merge(heading),
      titleSmall: base.titleSmall?.merge(heading),
      bodyLarge: base.bodyLarge?.merge(body),
      bodyMedium: base.bodyMedium?.merge(body),
      bodySmall: base.bodySmall?.merge(body),
      labelLarge: base.labelLarge?.merge(label),
      labelMedium: base.labelMedium?.merge(label),
      labelSmall: base.labelSmall?.merge(label),
    );
  }
}
