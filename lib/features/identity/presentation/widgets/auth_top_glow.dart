import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:flutter/widgets.dart';

/// Der rote Lichtkegel am oberen Rand von Anmeldung und Registrierung,
/// `02_Frontend/app/screen-auth.jsx:483`.
///
/// `radial-gradient(ellipse at 50% 0%, rgba(232,56,13,0.22) 0%, transparent 65%)`
/// in einem Streifen von [height] Pixeln über die ganze Breite, ohne
/// Zeigerereignisse.
///
/// Die Farbe steht als Literal und nicht als Token: die Quelle schreibt sie
/// inline und themenunabhängig hin, sie kommt nicht aus `useAuthTokens`. Der
/// Wert liegt zwischen `FactColors.redSoft` (0,12) und `redGlow` (0,38), es gibt
/// also auch kein passendes Token.
class AuthTopGlow extends StatelessWidget {
  /// Erzeugt den Lichtkegel.
  const AuthTopGlow({super.key});

  /// `height: 220`.
  static const double height = 220;

  /// Mittelpunkt, `ellipse at 50% 0%`, in Alignment-Einheiten.
  static const Alignment center = Alignment(0, -1);

  /// `rgba(232,56,13,0.22)`.
  static const Color glowColor = Color.fromRGBO(232, 56, 13, 0.22);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Die Ellipse hängt am Seitenverhältnis, deshalb gemessen statt
            // geraten. Dieselbe Rechnung wie im Lichtkegel des
            // Startbildschirms, siehe `SplashBackdrop`.
            final box = constraints.biggest;
            final radii = cssFarthestCornerEllipseRadii(
              center: center,
              box: box,
            );
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: center,
                  // `RadialGradient.radius` zählt in Anteilen der kürzeren
                  // Seite.
                  radius: radii.x / box.shortestSide,
                  transform: EllipticalGradientScale(
                    center: center,
                    scaleY: radii.y / radii.x,
                  ),
                  colors: const <Color>[
                    glowColor,
                    // CSS `transparent` ist rgba(0,0,0,0), CSS interpoliert
                    // Verläufe aber vormultipliziert und Flutter nicht: gegen
                    // durchsichtiges Schwarz entstünde ein grauer Ring.
                    Color.fromRGBO(232, 56, 13, 0),
                  ],
                  stops: const <double>[0, 0.65],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
