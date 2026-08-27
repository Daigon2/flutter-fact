import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Kategorien, die der Startbildschirm als Pin zeigt.
///
/// Werte aus `02_Frontend/app/screen-map.jsx:199-205` (`CAT`). Die PWA kennt
/// dort zehn Kategorien, der Startbildschirm nutzt fünf
/// (`screen-auth.jsx:285-291`). Hier stehen nur diese fünf: eine Aufzählung mit
/// fünf ungenutzten Werten würde vortäuschen, die Kategorienliste wäre hier
/// vollständig. Der vollständige Satz gehört zu `features/facts`.
///
/// Die Farben stehen als Literale, weil die Quelle sie auf diesem Bildschirm
/// als Literale schreibt und ihn themenunabhängig zeichnet. `FactColors.catHist`
/// bis `catArch` tragen dieselben Werte, in beiden Themes identisch; ein Test
/// nagelt diese Gleichheit fest, damit die Dopplung nicht auseinanderlaufen
/// kann.
enum BubblePinCategory {
  /// `hist`, Historisch.
  hist('🏛', Color(0xFFE8380D), Color(0xFFA82508)),

  /// `myth`, Mythos.
  myth('⚡', Color(0xFFA855F7), Color(0xFF7C3AC0)),

  /// `fun`, Fun-Fact.
  fun('😄', Color(0xFFF5C518), Color(0xFFC49A0A)),

  /// `geo`, Geografie.
  geo('🗺', Color(0xFF00C2A8), Color(0xFF007A6B)),

  /// `arch`, Architektur.
  arch('🗼', Color(0xFF3B82F6), Color(0xFF1D4ED8));

  const BubblePinCategory(this.emoji, this.color, this.dark);

  /// Das Zeichen in der Blase, `CAT[x].emoji`.
  final String emoji;

  /// Grundfarbe der Blase, `CAT[x].color`.
  final Color color;

  /// Tiefere Variante für Kante und Stiel, `CAT[x].dk`.
  final Color dark;
}

/// Der Blasen-Pin aus `02_Frontend/app/screen-map.jsx:265-289`.
///
/// **Diese Dopplung ist Absicht.** Der echte Karten-Marker gehört zu
/// `features/discovery` (`lib/features/README.md`) und entsteht in Phase 2 mit
/// Treffer-Fläche, Cluster-Verhalten und Kartenprojektion. Dieses Widget hier
/// ist rein dekorativ: es hat keine Interaktion, keinen Fakt-Bezug und keine
/// Position auf einer Karte. Ein gemeinsames Widget jetzt würde die
/// Eigentümerschaft über eine Feature-Grenze verschieben, bevor überhaupt
/// bekannt ist, was der Marker auf der Karte braucht.
///
/// Die `bounce`-Variante der Quelle fehlt: der Startbildschirm setzt
/// `bounce={false}` (`screen-auth.jsx:296`), die Animationen `factBounce` und
/// `factShadow` entfallen damit vollständig. Sie gehören zum Karten-Marker.
class BubblePin extends StatelessWidget {
  /// [size] ist der Außendurchmesser der Blase, nicht die Höhe des ganzen Pins.
  const BubblePin({required this.category, required this.size, super.key});

  /// Höhe des Stiels unter der Blase, `height: 7`.
  static const double stemHeight = 7;

  /// Höhe der Bodenschatten-Ellipse, `height: 4`.
  static const double groundShadowHeight = 4;

  /// Die Kategorie, aus der Farbe und Zeichen kommen.
  final BubblePinCategory category;

  /// Außendurchmesser der Blase in logischen Pixeln.
  final double size;

  /// Gesamthöhe: Blase, Stiel, Bodenschatten.
  double get totalHeight => size + stemHeight + groundShadowHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _bubble(),
        // `width: 3, height: 7, background: c.dk`, ohne Radius.
        SizedBox(
          width: 3,
          height: stemHeight,
          child: ColoredBox(color: category.dark),
        ),
        _groundShadow(),
      ],
    );
  }

  Widget _bubble() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // `radial-gradient(circle at 35% 30%, ${c.color}ee, ${c.color})`.
        //
        // Mittelpunkt in Alignment-Koordinaten: (2*0.35-1, 2*0.30-1).
        // Ausdehnung: CSS-Standard `farthest-corner`, für einen Kreis also der
        // Abstand zur entferntesten Ecke, hier (1, 1):
        // sqrt(0.65² + 0.70²) = 0.9553, gemessen in Anteilen der kürzeren
        // Seite, was `RadialGradient.radius` genau erwartet.
        gradient: RadialGradient(
          center: const Alignment(-0.30, -0.40),
          radius: 0.9553,
          colors: <Color>[category.color.withAlpha(0xEE), category.color],
        ),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFFFFFFF), width: 3),
        ),
        // `boxShadow: '0 4px 0 ${c.dk}, 0 6px 16px rgba(0,0,0,0.3)'`, hier in
        // umgekehrter Reihenfolge: CSS zeichnet den **ersten** Schatten vorne,
        // Flutter zeichnet die Liste von vorne nach hinten und legt damit den
        // letzten obenauf.
        //
        // Die Radien gehen unverändert als `blurRadius` mit: Flutter und CSS
        // rechnen sie mit unterschiedlichen Konstanten in ein Sigma um, und
        // ohne Referenzbild wäre jede Feinjustierung geraten.
        boxShadow: <BoxShadow>[
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
          BoxShadow(color: category.dark, offset: const Offset(0, 4)),
        ],
      ),
      child: Text(
        category.emoji,
        style: TextStyle(fontSize: size * 0.46, height: 1),
      ),
    );
  }

  Widget _groundShadow() {
    // `filter: blur(2px)`: der CSS-Parameter ist laut Filter Effects Level 1
    // die Standardabweichung der Gaußfunktion, also derselbe Wert, den
    // `ImageFilter.blur` als Sigma erwartet. Keine Umrechnung.
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: Container(
        width: size * 0.45,
        height: groundShadowHeight,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.3),
          // `borderRadius: '50%'` auf einem 4px hohen Rechteck ergibt eine
          // Ellipse, keinen Kreis: die Radien sind die halben Kantenlängen.
          borderRadius: BorderRadius.all(
            Radius.elliptical(size * 0.45 / 2, groundShadowHeight / 2),
          ),
        ),
      ),
    );
  }
}
