import 'dart:async';

import 'package:fact_app/features/identity/presentation/widgets/bubble_pin.dart';
import 'package:flutter/widgets.dart';

/// Ein schwebender Pin des Startbildschirms, wie ihn
/// `02_Frontend/app/screen-auth.jsx:285-291` beschreibt.
///
/// [left] ist ein Anteil der Breite (CSS `left: '12%'`), [top] ein Pixelwert von
/// oben. Bezugsfläche ist der Bildschirm innerhalb der Safe Area, siehe
/// [SplashPinField]. Beide beziehen sich auf die **linke obere Ecke der Blase**,
/// nicht auf ihren Mittelpunkt: CSS positioniert die Kanten.
@immutable
class SplashPinSpec {
  /// Erzeugt eine Pin-Beschreibung.
  const SplashPinSpec({
    required this.left,
    required this.top,
    required this.category,
    required this.size,
    required this.duration,
    required this.delay,
  });

  /// Abstand von links als Anteil der Breite, CSS `left`.
  final double left;

  /// Abstand von oben in logischen Pixeln, CSS `top`.
  final double top;

  /// Kategorie und damit Farbe und Zeichen.
  final BubblePinCategory category;

  /// Außendurchmesser der Blase.
  final double size;

  /// Volle Periode der `authFloat`-Animation, CSS `animation-duration`.
  final Duration duration;

  /// Versatz des Starts, CSS `animation-delay`.
  final Duration delay;
}

/// Die fünf Pins des Startbildschirms in der Reihenfolge der Quelle.
///
/// Diese Tabelle ist der einzige Ort, an dem die Zahlen stehen, und sie ist per
/// Test gegen die Quelle festgenagelt: fünf Zeilen mal sechs Werte sind der
/// größte Block abgetippter Zahlen auf diesem Bildschirm, und ein Zahlendreher
/// darin fällt beim Ansehen niemandem auf.
const List<SplashPinSpec> splashPins = <SplashPinSpec>[
  SplashPinSpec(
    left: 0.12,
    top: 110,
    category: BubblePinCategory.hist,
    size: 36,
    duration: Duration(milliseconds: 1600),
    delay: Duration.zero,
  ),
  SplashPinSpec(
    left: 0.74,
    top: 90,
    category: BubblePinCategory.myth,
    size: 32,
    duration: Duration(milliseconds: 1850),
    delay: Duration(milliseconds: 300),
  ),
  SplashPinSpec(
    left: 0.40,
    top: 70,
    category: BubblePinCategory.fun,
    size: 28,
    duration: Duration(milliseconds: 2100),
    delay: Duration(milliseconds: 600),
  ),
  SplashPinSpec(
    left: 0.82,
    top: 170,
    category: BubblePinCategory.geo,
    size: 26,
    duration: Duration(milliseconds: 1950),
    delay: Duration(milliseconds: 900),
  ),
  SplashPinSpec(
    left: 0.20,
    top: 185,
    category: BubblePinCategory.arch,
    size: 24,
    duration: Duration(milliseconds: 2200),
    delay: Duration(milliseconds: 1200),
  ),
];

/// Die fünf dekorativen Pins über dem Hintergrund des Startbildschirms.
///
/// [SplashPinSpec.top] zählt von der Oberkante der Fläche, die `SplashPage`
/// vorgibt, also von der Safe Area. Genauso rechnet die Quelle: das Inset ist
/// dort ein `padding` des `body`, in dem `ScreenFrame` und mit ihm die absolut
/// positionierten Pins liegen.
///
/// ## Die Animation
///
/// `@keyframes authFloat { 0%, 100% { translateY(0) } 50% { translateY(-10px) } }`
/// mit `ease-in-out` (`index.html:35`, `screen-auth.jsx:294`).
///
/// CSS wendet die Zeitfunktion **zwischen** den Keyframes an, `0% → 50%` ist
/// also eine halbe Periode mit `ease-in-out`. Deshalb läuft je Pin ein
/// Controller über die halbe Dauer und wird mit `reverse: true` wiederholt; das
/// bildet die zweite Hälfte ab. Fünf Ticker, deshalb
/// `TickerProviderStateMixin` und nicht die Single-Variante.
///
/// Die Verzögerungen von 0 bis 1,2 Sekunden werden als **Phasenversatz**
/// umgesetzt, nicht mit `Timer` oder `Future.delayed`. Bewusster Unterschied:
/// CSS hält den Pin während der Verzögerung im Ausgangszustand fest, ein
/// Phasenversatz lässt ihn sofort mitlaufen, nur an einer anderen Stelle der
/// Welle. Sichtbar ist das ausschließlich in der ersten Sekunde. Dafür gibt es
/// keinen Timer, der einen vorzeitig entsorgten Zustand überleben kann.
///
/// Bei eingeschalteter Systemeinstellung "Bewegung reduzieren"
/// (`MediaQuery.disableAnimations`) läuft nichts: alle Pins stehen im
/// Ausgangszustand. Das ist erstens das richtige Verhalten und zweitens die
/// Bedingung dafür, dass `pumpAndSettle` in Widget-Tests überhaupt
/// zurückkommt.
class SplashPinField extends StatefulWidget {
  /// Erzeugt das Pin-Feld.
  const SplashPinField({super.key});

  /// Amplitude der `authFloat`-Animation: `translateY(-10px)` in der Mitte.
  static const double floatAmplitude = -10;

  @override
  State<SplashPinField> createState() => _SplashPinFieldState();
}

class _SplashPinFieldState extends State<SplashPinField>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controllers = splashPins
        .map(
          (pin) => AnimationController(
            // Halbe Periode: 0% → 50% der CSS-Animation.
            duration: pin.duration ~/ 2,
            vsync: this,
          ),
        )
        .toList(growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nicht in `initState`: `MediaQuery` darf erst hier gelesen werden, und die
    // Einstellung kann sich während der Laufzeit ändern.
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled == _animationsDisabled) {
      return;
    }
    _animationsDisabled = disabled;
    for (var i = 0; i < _controllers.length; i++) {
      final controller = _controllers[i];
      if (disabled) {
        controller
          ..stop()
          ..value = 0;
        continue;
      }
      controller.value = _phase(splashPins[i]);
      // `repeat()` liefert ein `TickerFuture`, das bei einer endlosen
      // Wiederholung nie erfüllt wird.
      unawaited(controller.repeat(reverse: true));
    }
  }

  /// Der Startwert des Controllers, der die CSS-Verzögerung nachbildet.
  ///
  /// Die Verzögerung in halben Perioden gemessen ergibt eine Position im
  /// Dreieck 0 → 1 → 0. `AnimationController.repeat` übernimmt den aktuellen
  /// Wert als Phase, deshalb genügt es, ihn vorher zu setzen.
  double _phase(SplashPinSpec pin) {
    final halfPeriods =
        pin.delay.inMicroseconds / (pin.duration.inMicroseconds / 2);
    final position = halfPeriods % 2;
    return position <= 1 ? position : 2 - position;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: <Widget>[
            for (var i = 0; i < splashPins.length; i++)
              Positioned(
                left: constraints.maxWidth * splashPins[i].left,
                top: splashPins[i].top,
                child: _FloatingPin(
                  progress: _controllers[i],
                  spec: splashPins[i],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FloatingPin extends StatelessWidget {
  const _FloatingPin({required this.progress, required this.spec});

  final Animation<double> progress;
  final SplashPinSpec spec;

  @override
  Widget build(BuildContext context) {
    final pin = BubblePin(category: spec.category, size: spec.size);
    return AnimatedBuilder(
      animation: progress,
      // Der Pin selbst hängt nicht am Fortschritt und wird deshalb einmal
      // gebaut statt in jedem Frame.
      child: pin,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          Curves.easeInOut.transform(progress.value) *
              SplashPinField.floatAmplitude,
        ),
        child: child,
      ),
    );
  }
}
