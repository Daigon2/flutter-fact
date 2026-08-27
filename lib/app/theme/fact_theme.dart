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
      // Materials Laufweite raus (E-38), Begründung bei [_withoutTracking].
      // Das muss über `typography` laufen und wäre in [_textTheme] wirkungslos.
      typography: _withoutTracking(base.typography),
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
  ///
  /// Hier steht **keine** Laufweite, und ein `letterSpacing: null` hätte hier
  /// auch keine Wirkung: `base` kommt aus dem `ThemeData`-Konstruktor und trägt
  /// weder Schriftgröße noch Laufweite. Beides kommt erst aus der Geometrie,
  /// siehe [_withoutTracking].
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

  /// Nimmt Materials Laufweite aus den drei Geometrie-Themes (E-38).
  ///
  /// ## Warum hier und nicht in [_textTheme]
  ///
  /// Die Laufweite steht nicht in dem `textTheme`, das der
  /// `ThemeData`-Konstruktor baut. Sie kommt aus `Typography.englishLike2021`
  /// und wird erst vom `Theme`-Widget eingemischt, über
  /// `ThemeData.localize(theme, theme.typography.geometryThemeFor(category))`.
  /// Dieses `localize` setzt `textTheme: localTextGeometry.merge(textTheme)`.
  /// Die Geometrie ist dabei die **Basis**, das eigene `textTheme` überschreibt
  /// nur deren nicht-leere Felder. Ein `letterSpacing: null` in [_textTheme]
  /// wäre deshalb wirkungslos: es ließe genau den Wert durch, den es entfernen
  /// soll. An einer Wegwerf-Probe gemessen, nicht vermutet.
  ///
  /// Derselbe Aufruf speist auch `primaryTextTheme`. FACT liest den heute
  /// nirgends, es gibt weder eine `AppBar` noch eine Fundstelle in `lib/`, aber
  /// er ist über `Theme.of(context).primaryTextTheme` erreichbar und wird auf
  /// diesem Weg gratis mit erledigt.
  ///
  /// ## Warum null und nicht 0
  ///
  /// Gezeichnet wird beides gleich. `null` heißt „kein Zuschlag angegeben",
  /// `0.0` heißt „Zuschlag ist null". Der Unterschied zeigt sich beim Mischen:
  /// ein Stil mit `0.0` überschreibt eine Laufweite, die von außen käme, ein
  /// Stil mit `null` lässt sie durch. E-38 sagt „auf null setzen, wo die Quelle
  /// keine angibt", und das ist „nicht angegeben" und nicht „ausdrücklich
  /// null". Die Stellen, an denen die PWA eine Laufweite angibt, setzen sie
  /// weiterhin selbst und gewinnen in beiden Varianten.
  ///
  /// ## Warum die Stile von Hand kopiert werden
  ///
  /// `TextStyle.copyWith` kann kein Feld auf `null` zurücksetzen, und
  /// `TextStyle.apply(letterSpacingFactor: 0)` ergibt `0.0`, nicht `null`. Also
  /// wird der Stil neu gebaut. Die Geometrie trägt `fontSize`, `height`,
  /// `textBaseline` und `leadingDistribution`, die dürfen dabei nicht
  /// verlorengehen. `test/app/theme/fact_theme_tracking_test.dart` nagelt das
  /// mit einem Rundlauf gegen `Typography.englishLike2021` fest.
  static Typography _withoutTracking(Typography typography) {
    return typography.copyWith(
      englishLike: _textThemeWithoutTracking(typography.englishLike),
      dense: _textThemeWithoutTracking(typography.dense),
      tall: _textThemeWithoutTracking(typography.tall),
    );
  }

  static TextTheme _textThemeWithoutTracking(TextTheme theme) {
    return TextTheme(
      displayLarge: _styleWithoutTracking(theme.displayLarge),
      displayMedium: _styleWithoutTracking(theme.displayMedium),
      displaySmall: _styleWithoutTracking(theme.displaySmall),
      headlineLarge: _styleWithoutTracking(theme.headlineLarge),
      headlineMedium: _styleWithoutTracking(theme.headlineMedium),
      headlineSmall: _styleWithoutTracking(theme.headlineSmall),
      titleLarge: _styleWithoutTracking(theme.titleLarge),
      titleMedium: _styleWithoutTracking(theme.titleMedium),
      titleSmall: _styleWithoutTracking(theme.titleSmall),
      bodyLarge: _styleWithoutTracking(theme.bodyLarge),
      bodyMedium: _styleWithoutTracking(theme.bodyMedium),
      bodySmall: _styleWithoutTracking(theme.bodySmall),
      labelLarge: _styleWithoutTracking(theme.labelLarge),
      labelMedium: _styleWithoutTracking(theme.labelMedium),
      labelSmall: _styleWithoutTracking(theme.labelSmall),
    );
  }

  /// Baut den Stil ohne `letterSpacing` neu und übernimmt jedes andere Feld.
  ///
  /// `fontFamily` und `fontFamilyFallback` werden ohne `package` gesetzt: die
  /// Getter liefern den bereits aufgelösten Namen, ein zweites `package` würde
  /// das Präfix doppeln.
  static TextStyle? _styleWithoutTracking(TextStyle? style) {
    if (style == null) {
      return null;
    }
    return TextStyle(
      inherit: style.inherit,
      color: style.color,
      backgroundColor: style.backgroundColor,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      wordSpacing: style.wordSpacing,
      textBaseline: style.textBaseline,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      foreground: style.foreground,
      background: style.background,
      shadows: style.shadows,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      decoration: style.decoration,
      decorationColor: style.decorationColor,
      decorationStyle: style.decorationStyle,
      decorationThickness: style.decorationThickness,
      debugLabel: style.debugLabel,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      overflow: style.overflow,
    );
  }
}
