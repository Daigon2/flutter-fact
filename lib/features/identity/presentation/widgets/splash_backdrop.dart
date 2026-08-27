import 'package:fact_app/features/identity/presentation/widgets/css_gradient_geometry.dart';
import 'package:flutter/widgets.dart';

/// Der vierschichtige Hintergrund des Startbildschirms,
/// `02_Frontend/app/screen-auth.jsx:274-282`.
///
/// Alle vier Schichten füllen die Fläche, die `SplashPage` vorgibt. Das ist die
/// Fläche **innerhalb** der Safe Area: in der Quelle ist das Inset ein `padding`
/// des `body` und verschiebt den Verlauf mit. Die Streifen darüber und darunter
/// zeigen `SplashPage.surface`, nicht diesen Verlauf.
///
/// Reihenfolge von unten nach oben:
///
/// 1. der Grundverlauf über 170 Grad;
/// 2. das 40er-Gitter;
/// 3. der rote Lichtkegel als Ellipse;
/// 4. der violette Schleier über die unteren 520 Pixel.
class SplashBackdrop extends StatelessWidget {
  /// Erzeugt den Hintergrund.
  const SplashBackdrop({super.key});

  /// Kantenlänge einer Gitterzelle, `backgroundSize: '40px 40px'`.
  static const double gridSpacing = 40;

  /// Höhe des unteren Schleiers, `height: 520`.
  static const double veilHeight = 520;

  /// `gridColor = 'rgba(232,56,13,0.05)'`, screen-auth.jsx:267.
  static const Color gridColor = Color.fromRGBO(232, 56, 13, 0.05);

  /// Mittelpunkt des Lichtkegels, `ellipse at 50% 38%`, in Alignment-Einheiten.
  static const Alignment glowCenter = Alignment(0, 2 * 0.38 - 1);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Der Winkel und die Ellipse hängen vom Seitenverhältnis ab, deshalb
        // wird hier gemessen statt geraten.
        final box = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(decoration: _baseDecoration(box)),
            const CustomPaint(painter: _GridPainter()),
            DecoratedBox(decoration: _glowDecoration(box)),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: veilHeight,
              child: SplashBottomVeil(),
            ),
          ],
        );
      },
    );
  }

  /// `linear-gradient(170deg,#2A0A04 0%,#0A1428 45%,#1F1A2E 100%)`.
  BoxDecoration _baseDecoration(Size box) {
    final ends = cssLinearGradientEnds(angleDegrees: 170, box: box);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: ends.begin,
        end: ends.end,
        colors: const <Color>[
          Color(0xFF2A0A04),
          Color(0xFF0A1428),
          Color(0xFF1F1A2E),
        ],
        stops: const <double>[0, 0.45, 1],
      ),
    );
  }

  /// `radial-gradient(ellipse at 50% 38%, rgba(232,56,13,0.28) 0%, transparent 60%)`.
  BoxDecoration _glowDecoration(Size box) {
    final radii = cssFarthestCornerEllipseRadii(center: glowCenter, box: box);
    return BoxDecoration(
      gradient: RadialGradient(
        center: glowCenter,
        // `RadialGradient.radius` zählt in Anteilen der kürzeren Seite.
        radius: radii.x / box.shortestSide,
        transform: EllipticalGradientScale(
          center: glowCenter,
          scaleY: radii.y / radii.x,
        ),
        colors: const <Color>[
          Color.fromRGBO(232, 56, 13, 0.28),
          // CSS `transparent` ist rgba(0,0,0,0), CSS interpoliert Verläufe aber
          // mit vormultiplizierter Deckkraft. Flutter interpoliert
          // unvormultipliziert: gegen ein durchsichtiges Schwarz entstünde ein
          // sichtbar grauer Ring. Dieselbe Farbe mit Deckkraft 0 ist das, was
          // CSS tatsächlich zeichnet.
          Color.fromRGBO(232, 56, 13, 0),
        ],
        stops: const <double>[0, 0.6],
      ),
    );
  }

  /// Die y-Koordinaten der waagerechten Gitterlinien über [extent].
  ///
  /// Gleichzeitig, um 90 Grad gedreht, die x-Koordinaten der senkrechten. Steht
  /// als eigene Funktion da, damit die Kachelung prüfbar ist, ohne die
  /// Zeichnung abzufangen: eine Linie bei jedem Vielfachen von [gridSpacing],
  /// beginnend bei 0.
  static List<double> gridLines(double extent) {
    final lines = <double>[];
    for (var position = 0.0; position < extent; position += gridSpacing) {
      lines.add(position);
    }
    return lines;
  }
}

/// Der violette Schleier über den unteren [SplashBackdrop.veilHeight] Pixeln,
/// `screen-auth.jsx:281`.
///
/// Eigenes Widget und nicht bloß eine `BoxDecoration`, damit ein Test seine
/// Höhe messen kann. Eine Zahl, die nur in einer Dekoration steht, ist von
/// außen nicht prüfbar.
class SplashBottomVeil extends StatelessWidget {
  /// Erzeugt den Schleier. Die Höhe gibt der Aufrufer vor.
  const SplashBottomVeil({super.key});

  /// `linear-gradient(180deg, transparent 0%, rgba(50,38,62,0.35) 45%, rgba(58,46,72,0.55) 100%)`.
  ///
  /// `180deg` ergibt nach der Formel in [cssLinearGradientEnds] genau
  /// `topCenter → bottomCenter`, deshalb hier konstant statt gerechnet.
  static const BoxDecoration decoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        // `transparent`, aber in der Farbe des nächsten Stops: CSS interpoliert
        // Verläufe vormultipliziert, Flutter nicht.
        Color.fromRGBO(50, 38, 62, 0),
        Color.fromRGBO(50, 38, 62, 0.35),
        Color.fromRGBO(58, 46, 72, 0.55),
      ],
      stops: <double>[0, 0.45, 1],
    ),
  );

  @override
  Widget build(BuildContext context) =>
      const DecoratedBox(decoration: decoration);
}

/// Das Gitter aus zwei sich kreuzenden CSS-Verläufen.
///
/// Die Quelle baut es als Hintergrundbild:
/// `linear-gradient(c 1px, transparent 1px)` waagerecht und dieselbe Form mit
/// `90deg` senkrecht, gekachelt mit `40px 40px`. Effektiv sind das 1 Pixel
/// breite Linien bei jedem Vielfachen von 40, beginnend bei 0.
///
/// Gezeichnet als Rechtecke und nicht als Striche: ein Strich mit
/// `strokeWidth: 1` liegt mittig auf der Koordinate und deckte damit −0,5 bis
/// 0,5 ab. CSS deckt 0 bis 1 ab.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = SplashBackdrop.gridColor;
    for (final y in SplashBackdrop.gridLines(size.height)) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
    for (final x in SplashBackdrop.gridLines(size.width)) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
