import 'dart:ui' show ImageFilter;

import 'package:fact_app/app/onboarding/widgets/tour_palette.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';

/// Die Glasblase mit Schrittanzeige, Überschrift und Text,
/// `02_Frontend/app/screen-tour.jsx:455-501`.
///
/// Erwartet ein `Stack` als Elternteil: sie liefert ein [Positioned] und setzt
/// sich selbst auf `top` aus dem Schritt, mittig und höchstens [maxWidth] breit.
///
/// Sie wird **immer** gezeichnet, auch wenn der Anker fehlt. Nur Pfeil und
/// Leuchtring hängen am Rechteck (`screen-tour.jsx:447` und `:450`), die Blase
/// nicht.
class TourBubble extends StatelessWidget {
  /// Erzeugt die Blase eines regulären Schritts.
  const TourBubble({
    required this.top,
    required this.counter,
    required this.title,
    required this.body,
    super.key,
  });

  /// `maxWidth: 260`, `screen-tour.jsx:468`.
  static const double maxWidth = 260;

  /// `borderRadius: 18`, `screen-tour.jsx:472`.
  static const double borderRadius = 18;

  /// `padding: '14px 18px'`, `screen-tour.jsx:473`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 14,
  );

  /// `backdropFilter: blur(14px) saturate(1.4)`, `screen-tour.jsx:470`.
  ///
  /// Der Parameter von CSS `blur()` ist laut Filter Effects Level 1 die
  /// Standardabweichung der Gaußfunktion, also derselbe Wert, den
  /// `ImageFilter.blur` als Sigma erwartet. Keine Umrechnung nötig, dieselbe
  /// Begründung wie beim Weichzeichner der Tab-Leiste.
  static const double blurSigma = 14;

  /// Der zweite Teil desselben Filters.
  static const double saturation = 1.4;

  /// Abstand der Blasenoberkante von der Oberkante der Bezugsfläche.
  final double top;

  /// Die Schrittanzeige, fertig formatiert, etwa `SCHRITT 5 VON 9`.
  final String counter;

  /// Die Überschrift. Ein Zeilenumbruch darin bricht wirklich um, die Quelle
  /// rendert jede Zeile als eigenes `div` (`screen-tour.jsx:490-492`).
  final String title;

  /// Der Fließtext.
  final String body;

  /// Die Matrix zu `saturate(amount)` aus Filter Effects Level 1.
  ///
  /// Öffentlich, damit sie prüfbar ist: bei `1.0` muss die Einheitsmatrix
  /// herauskommen und bei `0.0` eine Graustufenmatrix. Ohne diesen Test wäre
  /// ein vertauschter Koeffizient eine Farbverschiebung, die ohne Referenzbild
  /// niemand bemerkt.
  ///
  /// Die Leuchtdichte-Gewichte 0.213 / 0.715 / 0.072 stehen so in der
  /// Spezifikation und sind nicht frei gewählt.
  static List<double> saturationMatrix(double amount) {
    const lumaR = 0.213;
    const lumaG = 0.715;
    const lumaB = 0.072;
    return <double>[
      lumaR + (1 - lumaR) * amount,
      lumaG * (1 - amount),
      lumaB * (1 - amount),
      0,
      0,
      lumaR * (1 - amount),
      lumaG + (1 - lumaG) * amount,
      lumaB * (1 - amount),
      0,
      0,
      lumaR * (1 - amount),
      lumaG * (1 - amount),
      lumaB + (1 - lumaB) * amount,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      // `left: '50%'` plus `translateX(-50%)` heißt mittig, und `maxWidth`
      // heißt, dass eine kurze Blase schmaler bleibt. Deshalb `Center` über
      // einem `ConstrainedBox` und keine feste Breite.
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            // Der Schlagschatten liegt außerhalb des Clips, sonst schneidet
            // ihn das `ClipRRect` für den Weichzeichner weg.
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
              boxShadow: <BoxShadow>[
                // `0 8px 32px rgba(0,0,0,0.15)`, `screen-tour.jsx:474`.
                BoxShadow(
                  color: TourPalette.bubbleShadow,
                  offset: Offset(0, 8),
                  blurRadius: 32,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(borderRadius),
              ),
              child: BackdropFilter(
                // CSS wendet die Filterliste von links nach rechts an, erst
                // `blur`, dann `saturate`. `ImageFilter.compose` rechnet
                // andersherum, `inner` zuerst.
                filter: ImageFilter.compose(
                  outer: ColorFilter.matrix(saturationMatrix(saturation)),
                  inner: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: TourPalette.bubbleBackground,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(borderRadius),
                    ),
                    // `inset 0 0 0 0.5px rgba(255,255,255,0.6)`: ein
                    // Inset-Schatten ohne Weichzeichner und ohne Versatz ist
                    // eine Innenkante. `BoxShadow` kann kein `inset`, ein
                    // `Border` trifft es genau.
                    border: Border.all(
                      color: TourPalette.bubbleEdge,
                      width: 0.5,
                    ),
                  ),
                  // `DecoratedBox` plus `Padding` und nicht `Container`: nur
                  // `Container` schlägt die Rahmenstärke als zusätzlichen
                  // Innenabstand auf. Ein Inset-Schatten in CSS verschiebt den
                  // Inhalt aber nicht.
                  child: Padding(
                    padding: padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          counter,
                          // Nunito 800, 10, `letterSpacing: '0.18em'`,
                          // `screen-tour.jsx:478-482`. CSS rechnet `em` gegen
                          // die Schriftgröße, Flutter erwartet Pixel.
                          style: FactTypography.heading.copyWith(
                            fontSize: 10,
                            letterSpacing: 10 * 0.18,
                            color: TourPalette.accent,
                          ),
                        ),
                        // `marginBottom: 5`, `screen-tour.jsx:481`.
                        const SizedBox(height: 5),
                        Text(
                          title,
                          // Nunito 900, 17, `letterSpacing: '-0.01em'`,
                          // `lineHeight: 1.15`, `screen-tour.jsx:485-489`.
                          style: FactTypography.emphasis.copyWith(
                            fontSize: 17,
                            height: 1.15,
                            letterSpacing: 17 * -0.01,
                            color: TourPalette.bubbleTitle,
                          ),
                        ),
                        // `marginBottom: 5`, `screen-tour.jsx:488`.
                        const SizedBox(height: 5),
                        Text(
                          body,
                          // DM Sans 500, 13, `lineHeight: 1.45`,
                          // `screen-tour.jsx:496-498`.
                          style: FactTypography.bodyEmphasis.copyWith(
                            fontSize: 13,
                            height: 1.45,
                            color: TourPalette.bubbleBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
