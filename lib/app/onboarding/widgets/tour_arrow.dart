import 'package:fact_app/app/onboarding/widgets/tour_arrow_geometry.dart';
import 'package:fact_app/app/onboarding/widgets/tour_palette.dart';
import 'package:flutter/material.dart';

/// Der gebogene Pfeil von der Blase zum Ziel,
/// `02_Frontend/app/screen-tour.jsx:6-64`.
///
/// Erwartet ein `Stack` als Elternteil und legt sich über dessen ganze Fläche,
/// wie das `<svg>` der Quelle mit `position: absolute; top: 0; left: 0` und
/// Rahmengröße. Gerechnet wird deshalb in absoluten Koordinaten der
/// Bezugsfläche, und der Painter braucht keine Verschiebung.
///
/// ## Was hier fehlt: die beiden Strich-Animationen
///
/// Die Quelle zeichnet Bogen und Spitze über `stroke-dashoffset` ein
/// (`screen-tour.jsx:53` und `:60`, Keyframes in `index.html:49` und `:51`).
/// Bewusst nicht nachgebaut, mit Begründung statt Bauchgefühl:
///
/// Der Bogen benutzt `stroke-dasharray: 1600` bei einer tatsächlichen
/// Pfadlänge von rund 100 bis 300 Pixeln. Sichtbar ist dabei
/// `clamp(1600 - offset, 0, Pfadlänge)`, und weil `offset` mit `ease-out` von
/// 1600 auf 0 läuft, ist der Pfad nach etwa einem Fünftel der angegebenen
/// halben Sekunde vollständig da. Die "0.5s"-Animation dauert real rund 70 ms
/// und sieht nicht aus wie ein Zeichnen, sondern wie ein Erscheinen.
///
/// Sichtbar bleibt allein, dass die **Spitze** rund eine halbe Sekunde später
/// auftaucht als der Bogen (`0.45s` Verzögerung). Das ist der offene Rest, und
/// er kostet einen Controller, wenn ihn jemand haben will.
class TourArrow extends StatelessWidget {
  /// Erzeugt den Pfeil zu [geometry].
  const TourArrow({required this.geometry, super.key});

  /// Strichstärke, `screen-tour.jsx:37`.
  static const double strokeWidth = 3;

  /// `drop-shadow(0 2px 5px ...)`, `screen-tour.jsx:47`.
  static const Offset shadowOffset = Offset(0, 2);

  /// Der Radius aus derselben Zeile. Flutter rechnet ihn über
  /// `Shadow.convertRadiusToSigma` in ein Sigma um, CSS tut dasselbe mit einer
  /// anderen Konstante. Ohne Referenzscreenshot ist jede Feinjustierung
  /// geraten, deshalb der direkte Wert, wie beim Schatten der Tab-Leiste.
  static const double shadowBlurRadius = 5;

  /// Anfang, Ende, Kontrollpunkte und Spitze.
  final TourArrowGeometry geometry;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // `pointerEvents: 'none'`, `screen-tour.jsx:45`: ein Tipp auf den Pfeil
      // schaltet weiter wie jeder andere Tipp.
      child: IgnorePointer(
        child: CustomPaint(painter: _TourArrowPainter(geometry)),
      ),
    );
  }
}

class _TourArrowPainter extends CustomPainter {
  const _TourArrowPainter(this.geometry);

  final TourArrowGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final curve = Path()
      ..moveTo(geometry.from.dx, geometry.from.dy)
      ..cubicTo(
        geometry.control1.dx,
        geometry.control1.dy,
        geometry.control2.dx,
        geometry.control2.dy,
        geometry.to.dx,
        geometry.to.dy,
      );
    final tip = Path()
      ..moveTo(geometry.tipLeft.dx, geometry.tipLeft.dy)
      ..lineTo(geometry.to.dx, geometry.to.dy)
      ..lineTo(geometry.tipRight.dx, geometry.tipRight.dy);

    // Der Schatten liegt in der Quelle als `filter` auf dem ganzen `<svg>`,
    // trifft also beide Pfade gemeinsam. Deshalb zuerst beide verwaschen und
    // versetzt, dann beide scharf darüber.
    final shadow = _stroke()
      ..color = TourPalette.arrowShadow
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        Shadow.convertRadiusToSigma(TourArrow.shadowBlurRadius),
      );
    canvas
      ..save()
      ..translate(TourArrow.shadowOffset.dx, TourArrow.shadowOffset.dy)
      ..drawPath(curve, shadow)
      ..drawPath(tip, shadow)
      ..restore();

    final line = _stroke()..color = TourPalette.accent;
    canvas
      ..drawPath(curve, line)
      ..drawPath(tip, line);
  }

  Paint _stroke() => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = TourArrow.strokeWidth
    // `strokeLinecap="round" strokeLinejoin="round"`, `screen-tour.jsx:50`.
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_TourArrowPainter oldDelegate) =>
      oldDelegate.geometry != geometry;
}
