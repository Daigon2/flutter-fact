import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:flutter/widgets.dart';

/// Die Wortmarke aus `02_Frontend/app/screen-auth.jsx:26-55`, Größe `lg`.
///
/// Nur die große Variante. Die Quelle kennt eine zweite mit
/// `{logo: 44, font: 44, gap: 10, sub: 9}`, die die Kopfzeilen von Anmeldung und
/// Registrierung nutzen. Sie kommt mit Schritt 9 und 10 dazu, wenn es einen
/// Aufrufer dafür gibt.
///
/// Das Ausrufezeichen ist **Text**, kein Bild: die Quelle setzt ein
/// `<span>!</span>` in Nunito 900. Es gibt kein Logo-Asset.
///
/// ## Die Wortmarke folgt der Systemschriftgröße nicht
///
/// Sie ist als einziges Element dieses Bildschirms von der Textskalierung
/// ausgenommen, und das ist **keine vergessene Barrierefreiheit**, sondern eine
/// Entscheidung mit zwei Gründen:
///
/// 1. **Die Quelle skaliert hier auch nicht.** Die 64 Pixel sind CSS-`px`
///    (`screen-auth.jsx:20`, `dims.lg`), und `px` folgt der Textgrößen-Einstellung
///    des Betriebssystems nicht. Wer hier skaliert, weicht von der Quelle ab.
/// 2. **Es wäre sichtbar kaputt.** Die Kachel hat mit [tileSize] eine feste
///    Kantenlänge, weil sie ein Quadrat mit Verlauf, Rand und zwei Schatten ist.
///    Ein daneben mitwachsender Schriftzug ergäbe ein Logo, dessen zwei Hälften
///    verschieden groß sind. Gemessen: bei Skalierung 2.0 auf 390 Pixel Breite
///    lief die Zeile um **65 Pixel** nach rechts über, bei 320 Pixeln um 135.
///
/// Das gilt ausschließlich für dieses Logo, Kachel, Ausrufezeichen und
/// Untertitel eingeschlossen. Alles andere auf dem Startbildschirm skaliert
/// weiter: Zitat, Kennzahlen, Sprachzeile und die drei Knöpfe.
///
/// Der Untertitel steht in der Quelle in gemischter Schreibung und wird per
/// `text-transform: uppercase` großgeschrieben. Hier steht deshalb die
/// Umwandlung im Code und kein großgeschriebenes Literal. (Die Parity-Spec
/// behauptet ein großgeschriebenes Literal, das ist gegen die Quelle geprüft und
/// falsch.) Der Text ist eines der drei belegten i18n-Löcher dieses
/// Bildschirms: die PWA hat dafür keinen Schlüssel.
class FactWordmark extends StatelessWidget {
  /// Erzeugt die Wortmarke.
  const FactWordmark({super.key});

  /// Kantenlänge der Kachel, `dims.logo`.
  static const double tileSize = 64;

  /// Schriftgröße von "FACT", `dims.font`.
  static const double fontSize = 64;

  /// Abstand zwischen Kachel und Schriftzug, `dims.gap`.
  static const double gap = 14;

  /// Schriftgröße des Untertitels, `dims.sub`.
  static const double subtitleFontSize = 10;

  /// Der Untertitel, wie er in der Quelle steht. Großschreibung macht [build].
  static const String subtitle = 'Stadtführer · Urban Explorer';

  /// `linear-gradient(145deg,#FF6B3D,#E8380D)`.
  ///
  /// Einmal gerechnet und nicht je Aufbau: die Umrechnung hängt nur vom
  /// Seitenverhältnis ab, und die Kachel ist in beiden Größen der Quelle
  /// quadratisch.
  static final ({Alignment begin, Alignment end}) _tileGradient =
      cssLinearGradientEnds(
        angleDegrees: 145,
        box: const Size.square(tileSize),
      );

  @override
  Widget build(BuildContext context) {
    // Ein Punkt für den ganzen Baum statt `textScaler` an jedem der drei Texte:
    // so kann kein späterer Text hier hineinrutschen, der die Ausnahme nicht
    // kennt. Siehe Klassenkommentar für die Begründung.
    return MediaQuery.withNoTextScaling(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _tile(),
              const SizedBox(width: gap),
              _lettering(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle.toUpperCase(),
            textAlign: TextAlign.center,
            style: FactTypography.mono.copyWith(
              fontSize: subtitleFontSize,
              color: const Color.fromRGBO(255, 255, 255, 0.4),
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile() {
    return Container(
      width: tileSize,
      height: tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: _tileGradient.begin,
          end: _tileGradient.end,
          colors: const <Color>[Color(0xFFFF6B3D), Color(0xFFE8380D)],
        ),
        // `borderRadius: dims.logo * 0.3`.
        borderRadius: const BorderRadius.all(Radius.circular(tileSize * 0.3)),
        border: const Border.fromBorderSide(
          BorderSide(color: Color.fromRGBO(255, 255, 255, 0.2), width: 2),
        ),
        // `boxShadow: '0 5px 0 #A82508, 0 10px 24px rgba(232,56,13,0.55)'`,
        // hier in umgekehrter Reihenfolge: CSS zeichnet den **ersten** Schatten
        // vorne, Flutter zeichnet die Liste von vorne nach hinten und legt
        // damit den letzten obenauf. Die Radien gehen unverändert als
        // `blurRadius` mit, siehe `floating_tab_bar.dart`.
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(232, 56, 13, 0.55),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
          BoxShadow(color: Color(0xFFA82508), offset: Offset(0, 5)),
        ],
      ),
      // `marginBottom: 2` am Glyphen: die Kachel zentriert das Kästchen samt
      // Rand, das Ausrufezeichen sitzt dadurch einen Pixel höher als die Mitte.
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          '!',
          style: FactTypography.emphasis.copyWith(
            fontSize: tileSize * 0.5,
            color: const Color(0xFFFFFFFF),
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _lettering() {
    return Text(
      'FACT',
      style: FactTypography.emphasis.copyWith(
        fontSize: fontSize,
        color: const Color(0xFFFFFFFF),
        height: 1,
        // `textShadow: '0 5px 0 #A82508, 0 10px 28px rgba(232,56,13,0.6)'`,
        // umgekehrt wie oben.
        shadows: const <Shadow>[
          Shadow(
            color: Color.fromRGBO(232, 56, 13, 0.6),
            offset: Offset(0, 10),
            blurRadius: 28,
          ),
          Shadow(color: Color(0xFFA82508), offset: Offset(0, 5)),
        ],
      ),
    );
  }
}
