import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Die Kopfzeile von Anmeldung und Registrierung,
/// `02_Frontend/app/screen-auth.jsx:159-177` (`AuthHeader`).
///
/// Links der Zurück-Knopf, rechts die kleine Wortmarke, dazwischen optional ein
/// Titel. Die Anmeldung setzt **keinen** Titel (`screen-auth.jsx:485`), die
/// Registrierung tut es; deshalb ist [title] optional und nicht weggelassen.
///
/// Geteilter Baustein: Schritt 10 benutzt dasselbe Widget, statt es zu
/// verdoppeln.
class AuthHeader extends StatelessWidget {
  /// Erzeugt die Kopfzeile.
  const AuthHeader({required this.onBack, this.title, super.key});

  /// `padding: '8px 20px 0'`.
  static const EdgeInsets padding = EdgeInsets.only(
    left: 20,
    right: 20,
    top: 8,
  );

  /// Kantenlänge des Zurück-Knopfes, `width/height: 38`.
  static const double backButtonSize = 38;

  /// `borderRadius: 12` am Zurück-Knopf.
  static const double backButtonRadius = 12;

  /// Kantenlänge der Chevron-Grafik, `width/height: 16`.
  static const double chevronSize = 16;

  /// Was der Zurück-Knopf auslöst.
  ///
  /// Die Quelle ruft `onNav('onboarding')`, springt also auf den
  /// Startbildschirm. Was hier passiert, entscheidet der Bildschirm: er weiß, ob
  /// er über `push` erreicht wurde.
  final VoidCallback onBack;

  /// Optionaler Titel in der Mitte.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _backButton(colors),
          if (title case final String text) _title(text, colors),
          const AuthWordmarkSmall(),
        ],
      ),
    );
  }

  Widget _backButton(FactColors colors) {
    // Ohne Ansagetext, und das ist eine bekannte Lücke statt einer
    // Entscheidung: der Knopf ist in der Quelle ein `<button>` mit einem SVG
    // darin und ohne `aria-label`, für einen Screenreader also namenlos. Einen
    // Text zu erfinden bräuchte einen i18n-Schlüssel, und dieser Schritt legt
    // keinen neuen an. `SplashPressable` gibt ihm wenigstens die Knopf-Rolle,
    // die `<button>` mitbringt.
    return SplashPressable(
      onPressed: onBack,
      child: Container(
        width: backButtonSize,
        height: backButtonSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: const BorderRadius.all(
            Radius.circular(backButtonRadius),
          ),
          border: Border.fromBorderSide(BorderSide(color: colors.border)),
        ),
        // Der Pfad kommt unverändert aus der Quelle. Warum SVG und kein
        // `CustomPainter`: die Pfaddaten **sind** die Verhaltensquelle, wer sie
        // abtippt, kann sie falsch abtippen, und im Diff sieht das niemand.
        // Dieselbe Begründung wie in `app/shell/shell_tab_icon.dart`.
        child: SvgPicture.string(
          '<svg width="16" height="16" viewBox="0 0 16 16" fill="none">'
          '<path d="M10 3L5 8l5 5" stroke="currentColor" stroke-width="2" '
          'stroke-linecap="round" stroke-linejoin="round"/></svg>',
          width: chevronSize,
          height: chevronSize,
          theme: SvgTheme(currentColor: colors.ink),
        ),
      ),
    );
  }

  Widget _title(String text, FactColors colors) {
    return Text(
      text.toUpperCase(),
      style: FactTypography.mono.copyWith(
        fontSize: 10,
        color: colors.ink3,
        letterSpacing: 0.25,
      ),
    );
  }
}

/// Die kleine Wortmarke der Kopfzeile, `screen-auth.jsx:172-176`.
///
/// **Nicht** die `sm`-Variante von `FactWordmark` aus `screen-auth.jsx:26-55`:
/// die hat 44 Pixel, einen Untertitel und andere Schatten. Die Kopfzeile baut
/// sich ihre eigene, kleinere Marke inline, und das ist die hier.
///
/// Folgt der Systemschriftgröße nicht, aus demselben Grund wie `FactWordmark`:
/// die Kachel hat eine feste Kantenlänge, ein daneben mitwachsender Schriftzug
/// ergäbe ein halb skaliertes Logo. CSS-`px` skaliert in der Quelle ebenfalls
/// nicht.
class AuthWordmarkSmall extends StatelessWidget {
  /// Erzeugt die kleine Wortmarke.
  const AuthWordmarkSmall({super.key});

  /// Kantenlänge der Kachel, `width/height: 26`.
  static const double tileSize = 26;

  /// `borderRadius: 8`.
  static const double tileRadius = 8;

  /// Abstand zwischen Kachel und Schriftzug, `gap: 6`.
  static const double gap = 6;

  /// `fontSize: 18` von "FACT".
  static const double letteringFontSize = 18;

  /// `fontSize: 14` des Ausrufezeichens.
  static const double glyphFontSize = 14;

  /// `linear-gradient(145deg,#FF6B3D,#E8380D)`, einmal gerechnet.
  static final ({Alignment begin, Alignment end}) _tileGradient =
      cssLinearGradientEnds(
        angleDegrees: 145,
        box: const Size.square(tileSize),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    return MediaQuery.withNoTextScaling(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _tile(colors),
          const SizedBox(width: gap),
          Text(
            'FACT',
            style: FactTypography.displayTitle.copyWith(
              fontSize: letteringFontSize,
              color: colors.ink,
              height: 1,
              // `letterSpacing: '-0.01em'`, also die Hälfte von `.display`.
              letterSpacing: letteringFontSize * -0.01,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(FactColors colors) {
    return Container(
      width: tileSize,
      height: tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: _tileGradient.begin,
          end: _tileGradient.end,
          // Die beiden Verlaufsfarben sind `--red-lt` und `--red`, hier über
          // die Tokens statt als Literal: anders als beim Startbildschirm
          // zeichnet diese Kopfzeile im Theme der App.
          colors: <Color>[colors.redLight, colors.red],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(tileRadius)),
        // `boxShadow: '0 2px 0 #A82508'`, also `--red-dk`.
        boxShadow: <BoxShadow>[
          BoxShadow(color: colors.redDark, offset: const Offset(0, 2)),
        ],
      ),
      // `marginBottom: 1` am Glyphen.
      child: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Text(
          '!',
          style: FactTypography.emphasis.copyWith(
            fontSize: glyphFontSize,
            color: const Color(0xFFFFFFFF),
            height: 1,
          ),
        ),
      ),
    );
  }
}
