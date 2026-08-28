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
      // Materials Laufweite (E-38) und Materials Zeilenhöhe raus, Begründung
      // bei [_withoutTrackingAndLineHeight]. Beides muss über `typography`
      // laufen und wäre in [_textTheme] wirkungslos.
      typography: _withoutTrackingAndLineHeight(base.typography),
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
  /// Hier steht **weder** Laufweite **noch** Zeilenhöhe, und ein
  /// `letterSpacing: null` oder `height: null` hätte hier auch keine Wirkung:
  /// `base` kommt aus dem `ThemeData`-Konstruktor und trägt weder
  /// Schriftgröße noch Laufweite noch Zeilenhöhe. Alle drei kommen erst aus
  /// der Geometrie, siehe [_withoutTrackingAndLineHeight].
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

  /// Nimmt Materials Laufweite (E-38) und Materials Zeilenhöhe aus den drei
  /// Geometrie-Themes.
  ///
  /// ## Warum die Zeilenhöhe genauso raus muss wie die Laufweite
  ///
  /// **Die PWA hat keine globale Zeilenhöhe.** `styles.css` enthält das Wort
  /// `line-height` kein einziges Mal, und der einzige Treffer in `index.html`
  /// gehört zum toten Splash-Block. Gesetzt wird sie ausschließlich am
  /// einzelnen Element: 20 Mal in `screen-map.jsx`, 14 Mal in
  /// `screen-auth.jsx`, 4 Mal in `screen-tour.jsx`, 2 Mal in `chrome.jsx`.
  /// Überall sonst rechnet der Browser mit `line-height: normal`, also mit den
  /// Metriken der Schrift, und das heißt in Flutter `height: null`.
  ///
  /// Material 2021 legt dagegen auf jeden Slot eine Zeilenhöhe, `bodyMedium`
  /// etwa 1.43. Die kommt über `Material` als `DefaultTextStyle` bei jedem
  /// Text an, der keine eigene setzt, und ein `Scaffold` bringt ein `Material`
  /// mit. Gemessen am 29.08.2026 über die ganze `FactApp`: **46 verschiedene
  /// Absätze** auf Startbildschirm, Anmeldung, Registrierung, Karten-Chrome
  /// und den Platzhalter-Tabs trugen 1.43, dazu sieben Eingabefelder die 1.5
  /// aus `bodyLarge`. Für **keinen** davon gibt die Quelle eine `line-height`
  /// an. Die Höhe einer Pille ist Innenabstand plus Zeilenkasten: ein falscher
  /// Zeilenkasten macht jede gegen die Quelle belegte Maßangabe falsch.
  ///
  /// Vor dieser Stelle war das dreimal örtlich geflickt worden, in
  /// `OnboardingHost`, `AudioActivationDialog` und `StartupFailureApp`, jeweils
  /// mit einem ausdrücklichen `textStyle` am `Material`. Für
  /// `StartupFailureApp` bleibt das richtig, die installiert bewusst kein
  /// FACT-Theme. Für die beiden anderen war es die Wiederholung derselben
  /// Behebung. Eine app-weite Ursache gehört app-weit behoben, sonst kommt sie
  /// beim nächsten neuen Bildschirm zurück.
  ///
  /// ## Warum hier und nicht in [_textTheme]
  ///
  /// Weder Laufweite noch Zeilenhöhe stehen in dem `textTheme`, das der
  /// `ThemeData`-Konstruktor baut. Beide kommen aus
  /// `Typography.englishLike2021` und werden erst vom `Theme`-Widget
  /// eingemischt, über
  /// `ThemeData.localize(theme, theme.typography.geometryThemeFor(category))`.
  /// Dieses `localize` setzt `textTheme: localTextGeometry.merge(textTheme)`.
  /// Die Geometrie ist dabei die **Basis**, das eigene `textTheme` überschreibt
  /// nur deren nicht-leere Felder. Ein `letterSpacing: null` oder
  /// `height: null` in [_textTheme] wäre deshalb wirkungslos: es ließe genau
  /// den Wert durch, den es entfernen soll. An einer Wegwerf-Probe gemessen,
  /// nicht vermutet.
  ///
  /// Derselbe Aufruf speist auch `primaryTextTheme`. FACT liest den heute
  /// nirgends, es gibt weder eine `AppBar` noch eine Fundstelle in `lib/`, aber
  /// er ist über `Theme.of(context).primaryTextTheme` erreichbar und wird auf
  /// diesem Weg gratis mit erledigt.
  ///
  /// ## Was ausdrücklich bleibt: `fontSize` und `leadingDistribution`
  ///
  /// `fontSize` bleibt, weil ein Slot ohne Größe kein brauchbarer Basisstil
  /// mehr wäre; FACT setzt seine echten Größen ohnehin je Element aus dem JSX.
  ///
  /// `leadingDistribution` bleibt auf `even`, und das ist kein Übersehen. Der
  /// Wert kommt zwar aus derselben Material-Geometrie, ist aber kein
  /// Material-Geschmack, sondern das Umbruchmodell der Quelle: CSS verteilt den
  /// Durchschuss aus `line-height` je zur Hälfte über und unter den Text
  /// (Half-Leading, `css-inline-3`), und `even` ist laut Flutters eigener
  /// Dokumentation genau diese Strategie. Flutters Standard `proportional`
  /// setzt die Grundlinie woanders hin als der Browser. Dieselbe Abwägung
  /// steht bei `OnboardingHost.overlayTextStyle`.
  ///
  /// ## Warum null und nicht 0 beziehungsweise 1.0
  ///
  /// Bei der Laufweite wird beides gleich gezeichnet: `null` heißt „kein
  /// Zuschlag angegeben", `0.0` heißt „Zuschlag ist null". Der Unterschied
  /// zeigt sich beim Mischen, ein Stil mit `0.0` überschreibt eine Laufweite,
  /// die von außen käme.
  ///
  /// Bei der Zeilenhöhe ist der Unterschied sogar sichtbar: `height: 1.0`
  /// staucht den Zeilenkasten auf die Schriftgröße, `height: null` überlässt
  /// ihn den Metriken der Schrift. Nunito trägt 1011 Einheiten Oberlänge und
  /// 353 Unterlänge auf 1000 pro Geviert, also rund 1.364 statt 1.0. `null`
  /// ist die Entsprechung von `line-height: normal`, `1.0` wäre
  /// `line-height: 1`.
  ///
  /// Die Stellen, an denen die PWA eine Laufweite oder eine Zeilenhöhe angibt,
  /// setzen sie weiterhin selbst und gewinnen in beiden Varianten.
  ///
  /// ## Warum die Stile von Hand kopiert werden
  ///
  /// `TextStyle.copyWith` kann kein Feld auf `null` zurücksetzen, und
  /// `TextStyle.apply(letterSpacingFactor: 0)` ergibt `0.0`, nicht `null`. Also
  /// wird der Stil neu gebaut. Die Geometrie trägt `fontSize`, `height`,
  /// `textBaseline` und `leadingDistribution`, und von denen darf nur `height`
  /// verlorengehen. `test/app/theme/fact_theme_tracking_test.dart` nagelt das
  /// mit einem Rundlauf gegen `Typography.englishLike2021` fest.
  static Typography _withoutTrackingAndLineHeight(Typography typography) {
    return typography.copyWith(
      englishLike: _textThemeWithoutTrackingAndLineHeight(
        typography.englishLike,
      ),
      dense: _textThemeWithoutTrackingAndLineHeight(typography.dense),
      tall: _textThemeWithoutTrackingAndLineHeight(typography.tall),
    );
  }

  static TextTheme _textThemeWithoutTrackingAndLineHeight(TextTheme theme) {
    return TextTheme(
      displayLarge: _styleWithoutTrackingAndLineHeight(theme.displayLarge),
      displayMedium: _styleWithoutTrackingAndLineHeight(theme.displayMedium),
      displaySmall: _styleWithoutTrackingAndLineHeight(theme.displaySmall),
      headlineLarge: _styleWithoutTrackingAndLineHeight(theme.headlineLarge),
      headlineMedium: _styleWithoutTrackingAndLineHeight(theme.headlineMedium),
      headlineSmall: _styleWithoutTrackingAndLineHeight(theme.headlineSmall),
      titleLarge: _styleWithoutTrackingAndLineHeight(theme.titleLarge),
      titleMedium: _styleWithoutTrackingAndLineHeight(theme.titleMedium),
      titleSmall: _styleWithoutTrackingAndLineHeight(theme.titleSmall),
      bodyLarge: _styleWithoutTrackingAndLineHeight(theme.bodyLarge),
      bodyMedium: _styleWithoutTrackingAndLineHeight(theme.bodyMedium),
      bodySmall: _styleWithoutTrackingAndLineHeight(theme.bodySmall),
      labelLarge: _styleWithoutTrackingAndLineHeight(theme.labelLarge),
      labelMedium: _styleWithoutTrackingAndLineHeight(theme.labelMedium),
      labelSmall: _styleWithoutTrackingAndLineHeight(theme.labelSmall),
    );
  }

  /// Baut den Stil ohne `letterSpacing` und ohne `height` neu und übernimmt
  /// jedes andere Feld.
  ///
  /// `fontFamily` und `fontFamilyFallback` werden ohne `package` gesetzt: die
  /// Getter liefern den bereits aufgelösten Namen, ein zweites `package` würde
  /// das Präfix doppeln.
  static TextStyle? _styleWithoutTrackingAndLineHeight(TextStyle? style) {
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
      // `height` fehlt hier absichtlich und ist die halbe Aufgabe dieser
      // Methode: weggelassen heißt `null`, und `null` heißt „die Metriken der
      // Schrift", also `line-height: normal`.
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
