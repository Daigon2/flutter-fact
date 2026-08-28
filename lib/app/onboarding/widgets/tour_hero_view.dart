import 'package:fact_app/app/onboarding/widgets/tour_palette.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';

/// Der Inhalt eines Vollbild-Schritts, `02_Frontend/app/screen-tour.jsx:352-393`.
///
/// Erwartet einen `Stack` als Elternteil und füllt ihn. Der Verdunkler und der
/// Tipp-Bereich liegen nicht hier, sondern im `TourOverlay`: sie sind auf
/// beiden Schrittarten dieselben.
class TourHeroView extends StatelessWidget {
  /// Erzeugt den Inhalt eines Hero-Schritts.
  const TourHeroView({
    required this.title,
    required this.body,
    required this.meta,
    super.key,
  });

  /// `padding: 40`, `screen-tour.jsx:355`.
  static const double padding = 40;

  /// `maxWidth: 320` der Überschrift, `screen-tour.jsx:363`.
  static const double titleMaxWidth = 320;

  /// `maxWidth: 300` des Fließtextes, `screen-tour.jsx:378`.
  static const double bodyMaxWidth = 300;

  /// Die Überschrift. Ein Zeilenumbruch darin bricht wirklich um, die Quelle
  /// rendert jede Zeile als eigenes `div` (`screen-tour.jsx:358-360`).
  final String title;

  /// Der Fließtext.
  final String body;

  /// Die goldene Zeile darunter, etwa die Zuschreibung des Zitats.
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // Bewusste Abweichung: die Quelle kann nicht überlaufen, ein zu hoher
      // Inhalt wächst im Browser einfach aus der Überlagerung heraus. Flutter
      // meldet stattdessen einen Überlauf. Bei doppelter Systemschrift ist eine
      // 38 Pixel große Überschrift plus Fließtext auf einem flachen Gerät
      // wirklich zu hoch. `Center` über einem `SingleChildScrollView` zentriert
      // genau wie die Quelle, solange es passt, und wird erst dann scrollbar.
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: titleMaxWidth),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  // Nunito 900, 38, `lineHeight: 1.05`,
                  // `letterSpacing: '-0.025em'`, `screen-tour.jsx:365-370`.
                  style: FactTypography.emphasis.copyWith(
                    fontSize: 38,
                    height: 1.05,
                    letterSpacing: 38 * -0.025,
                    color: TourPalette.heroTitle,
                  ),
                ),
              ),
              // `marginBottom: 22`, `screen-tour.jsx:371`.
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: bodyMaxWidth),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  // DM Sans 500, 16, `lineHeight: 1.45`,
                  // `screen-tour.jsx:374-376`.
                  style: FactTypography.bodyEmphasis.copyWith(
                    fontSize: 16,
                    height: 1.45,
                    color: TourPalette.heroBody,
                  ),
                ),
              ),
              // `marginTop: 30`, `screen-tour.jsx:383`.
              const SizedBox(height: 30),
              Text(
                meta,
                textAlign: TextAlign.center,
                // Nunito 800, 11, `letterSpacing: '0.22em'`,
                // `screen-tour.jsx:384-387`.
                style: FactTypography.heading.copyWith(
                  fontSize: 11,
                  letterSpacing: 11 * 0.22,
                  color: TourPalette.heroMeta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
