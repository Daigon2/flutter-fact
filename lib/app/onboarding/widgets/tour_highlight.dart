import 'dart:async';

import 'package:fact_app/app/onboarding/widgets/tour_palette.dart';
import 'package:flutter/material.dart';

/// Der pulsierende Leuchtring um das Ziel eines Schritts,
/// `02_Frontend/app/screen-tour.jsx:69-90`.
///
/// Erwartet ein `Stack` als Elternteil: das Widget liefert ein [Positioned]
/// und legt sich damit selbst an die richtige Stelle. Der Grund ist der
/// Innenabstand: Ring und Rechteck sind nicht deckungsgleich, und wer die
/// Verschiebung außerhalb rechnet, rechnet sie irgendwann anders als der
/// Radius, der von derselben Zahl abhängt.
///
/// ## Die Pulsation, `index.html:52`
///
/// ```css
/// @keyframes tour-ring-pulse {
///   0%, 100% { box-shadow: 0 0 0 4px rgba(184,58,46,0.18), 0 4px 16px rgba(184,58,46,0.35); }
///   50%      { box-shadow: 0 0 0 7px rgba(184,58,46,0.30), 0 6px 22px rgba(184,58,46,0.55); }
/// }
/// ```
///
/// Der Ring **selbst** bewegt sich nicht, nur seine beiden Schatten. Die
/// Zeitfunktion `ease-in-out` gilt zwischen den Keyframes, `0% → 50%` ist also
/// eine halbe Periode. Deshalb läuft der Controller über 800 ms und wird mit
/// `reverse: true` wiederholt, genau wie in `SplashPinField`.
///
/// Der inline gesetzte `boxShadow` der Quelle (`screen-tour.jsx:85`, mit 3px
/// und 14px) ist **nie sichtbar**: die Animation läuft ohne Verzögerung und
/// überschreibt ihn ab dem ersten Frame. Der Ruhewert hier ist deshalb der
/// `0%`-Keyframe und nicht der Inline-Wert.
///
/// Bei "Bewegung reduzieren" (`MediaQuery.disableAnimations`) steht der Ring
/// still. Das ist erstens richtig und zweitens die Bedingung dafür, dass
/// `pumpAndSettle` in Widget-Tests zurückkommt.
class TourHighlight extends StatefulWidget {
  /// [rect] ist das Rechteck des Ziels, relativ zur Bezugsfläche des
  /// `AnchorScope`, also unverändert das Ergebnis von `AnchorRegistry.rectOf`.
  const TourHighlight({required this.rect, super.key});

  /// Luft zwischen Ziel und Ring, `screen-tour.jsx:71`.
  static const double pad = 5;

  /// Stärke des Rings, `screen-tour.jsx:83`.
  ///
  /// `styles.css:109` setzt `box-sizing: border-box`, der Rahmen liegt also
  /// **innerhalb** der 2 x [pad] großen Fläche. Flutter zeichnet den Rahmen
  /// eines `BoxDecoration` genauso nach innen, hier ist nichts umzurechnen.
  static const double strokeWidth = 2.5;

  /// Volle Periode der Pulsation, `screen-tour.jsx:88`.
  static const Duration pulsePeriod = Duration(milliseconds: 1600);

  /// Der Ruhezustand, also der `0%`-Keyframe aus `index.html:52`.
  static const List<BoxShadow> restShadows = <BoxShadow>[
    BoxShadow(color: Color.fromRGBO(184, 58, 46, 0.18), spreadRadius: 4),
    BoxShadow(
      color: Color.fromRGBO(184, 58, 46, 0.35),
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// Der Umkehrpunkt, also der `50%`-Keyframe aus `index.html:52`.
  static const List<BoxShadow> peakShadows = <BoxShadow>[
    BoxShadow(color: Color.fromRGBO(184, 58, 46, 0.30), spreadRadius: 7),
    BoxShadow(
      color: Color.fromRGBO(184, 58, 46, 0.55),
      offset: Offset(0, 6),
      blurRadius: 22,
    ),
  ];

  /// Das Rechteck des Ziels.
  final Rect rect;

  /// Die Fläche, die der Ring einnimmt, inklusive [pad].
  ///
  /// Öffentlich, weil ein Test sonst die Zahl 5 ein zweites Mal aufschreiben
  /// müsste und damit nichts mehr prüft.
  static Rect ringRect(Rect target) => target.inflate(pad);

  /// Der Eckradius, `screen-tour.jsx:78`.
  ///
  /// `min(w, h) / 2 + 2` ergibt für ein breites Ziel eine Pillenform und für
  /// ein quadratisches einen Kreis. Das `+ 2` steht so in der Quelle.
  static double ringRadius(Rect target) {
    final ring = ringRect(target);
    return ring.shortestSide / 2 + 2;
  }

  @override
  State<TourHighlight> createState() => _TourHighlightState();
}

class _TourHighlightState extends State<TourHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    // Halbe Periode: 0% bis 50% der CSS-Animation, der Rest ist `reverse`.
    duration: TourHighlight.pulsePeriod ~/ 2,
    vsync: this,
  );
  bool? _animationsDisabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nicht in `initState`: `MediaQuery` darf erst hier gelesen werden, und die
    // Einstellung kann sich zur Laufzeit ändern.
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled == _animationsDisabled) {
      return;
    }
    _animationsDisabled = disabled;
    if (disabled) {
      _pulse
        ..stop()
        ..value = 0;
      return;
    }
    // `repeat()` liefert ein `TickerFuture`, das bei endloser Wiederholung nie
    // erfüllt wird.
    unawaited(_pulse.repeat(reverse: true));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = TourHighlight.ringRadius(widget.rect);

    return Positioned.fromRect(
      rect: TourHighlight.ringRect(widget.rect),
      // Der Ring ist Verzierung. Ein Tipp darauf muss den Schritt weiterschalten
      // wie jeder andere Tipp, `screen-tour.jsx:86` setzt dafür
      // `pointerEvents: 'none'`.
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(radius)),
                border: Border.all(
                  color: TourPalette.accent,
                  width: TourHighlight.strokeWidth,
                ),
                boxShadow: <BoxShadow>[
                  for (var i = 0; i < TourHighlight.restShadows.length; i++)
                    BoxShadow.lerp(
                      TourHighlight.restShadows[i],
                      TourHighlight.peakShadows[i],
                      t,
                    )!,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
