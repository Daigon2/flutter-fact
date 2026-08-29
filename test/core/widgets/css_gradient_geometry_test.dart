import 'dart:math' as math;

import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Umrechnung der CSS-Gradienten-Geometrie.
///
/// Ein Vorzeichenfehler in `(sin θ, −cos θ)` dreht den Verlauf um und sieht auf
/// dem Bildschirm nach einer Design-Entscheidung aus, nicht nach einem Fehler.
/// Deshalb hier die vier Himmelsrichtungen als Gegenprobe.
void main() {
  const box = Size(390, 844);

  group('linear-gradient', () {
    test('die vier rechten Winkel zeigen in die richtige Richtung', () {
      const square = Size.square(100);

      expect(cssLinearGradientEnds(angleDegrees: 0, box: square), (
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ));
      expect(
        cssLinearGradientEnds(angleDegrees: 90, box: square).end,
        _closeToAlignment(Alignment.centerRight),
      );
      expect(
        cssLinearGradientEnds(angleDegrees: 180, box: square).end,
        _closeToAlignment(Alignment.bottomCenter),
      );
      expect(
        cssLinearGradientEnds(angleDegrees: 270, box: square).end,
        _closeToAlignment(Alignment.centerLeft),
      );
    });

    test('Richtung und Länge der Gradientenlinie stimmen in Pixeln', () {
      // Die eigentliche Zusicherung, und zwar unabhängig von der Rechnung in
      // der Umsetzung: die zurückgegebenen Alignments werden in Pixel
      // zurückverwandelt, und dort müssen zwei Dinge gelten, die die
      // CSS-Definition festlegt.
      //
      // Der vorherige Test an dieser Stelle prüfte `begin == -end`. Das steht
      // wörtlich in der Implementierung und war damit tautologisch: er hätte
      // jede falsche Richtung und jede falsche Länge mitgemacht.
      const rect = Rect.fromLTWH(0, 0, 390, 844);

      for (final angle in <double>[0, 45, 90, 145, 170, 200, 315]) {
        final ends = cssLinearGradientEnds(angleDegrees: angle, box: box);
        final beginPx = ends.begin.withinRect(rect);
        final endPx = ends.end.withinRect(rect);
        final line = endPx - beginPx;
        final radians = angle * math.pi / 180;

        // 1. Richtung: im Uhrzeigersinn von oben, y zeigt nach unten.
        expect(
          line.direction,
          closeTo(
            Offset(math.sin(radians), -math.cos(radians)).direction,
            1e-9,
          ),
          reason: '$angle Grad, Richtung',
        );

        // 2. Länge: `L = |W·sin θ| + |H·cos θ|`. Damit fallen die Stops 0 und
        // 100 Prozent genau auf die Projektionen der beiden Ecken.
        expect(
          line.distance,
          closeTo(
            (rect.width * math.sin(radians)).abs() +
                (rect.height * math.cos(radians)).abs(),
            1e-9,
          ),
          reason: '$angle Grad, Länge',
        );

        // 3. Die Mitte der Linie ist die Mitte der Fläche.
        expect(
          (beginPx + (endPx - beginPx) / 2 - rect.center).distance,
          closeTo(0, 1e-9),
          reason: '$angle Grad, Mitte',
        );
      }
    });

    test('die Ecken der Fläche projizieren genau auf 0 und 100 Prozent', () {
      // Die CSS-Definition selbst, an einem schrägen Winkel nachgerechnet: kein
      // Punkt der Fläche liegt außerhalb der Strecke von `begin` nach `end`,
      // und zwei Ecken liegen genau darauf.
      const rect = Rect.fromLTWH(0, 0, 390, 844);
      final ends = cssLinearGradientEnds(angleDegrees: 170, box: box);
      final beginPx = ends.begin.withinRect(rect);
      final endPx = ends.end.withinRect(rect);
      final line = endPx - beginPx;

      double fractionOf(Offset point) {
        final relative = point - beginPx;
        return (relative.dx * line.dx + relative.dy * line.dy) /
            (line.dx * line.dx + line.dy * line.dy);
      }

      final fractions = <double>[
        fractionOf(rect.topLeft),
        fractionOf(rect.topRight),
        fractionOf(rect.bottomLeft),
        fractionOf(rect.bottomRight),
      ];

      for (final fraction in fractions) {
        expect(fraction, greaterThanOrEqualTo(-1e-9));
        expect(fraction, lessThanOrEqualTo(1 + 1e-9));
      }
      expect(fractions.reduce(math.min), closeTo(0, 1e-9));
      expect(fractions.reduce(math.max), closeTo(1, 1e-9));
    });

    test('170 Grad auf dem Rahmenmaß der PWA', () {
      // Handgerechnet: dx = sin 170° = 0.17365, dy = −cos 170° = 0.98481,
      // L = 390·dx + 844·dy = 899,7. Ende = (L·dx/390, L·dy/844).
      final ends = cssLinearGradientEnds(angleDegrees: 170, box: box);

      expect(ends.end.x, closeTo(0.4003, 0.001));
      expect(ends.end.y, closeTo(1.0489, 0.001));
    });

    test('eine leere Fläche fällt auf senkrecht zurück', () {
      expect(cssLinearGradientEnds(angleDegrees: 170, box: Size.zero), (
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ));
    });
  });

  group('radial-gradient mit farthest-corner', () {
    test('die Radien sind das Wurzel-Zwei-Fache der farthest-side-Radien', () {
      // Mittelpunkt `50% 38%`: farthest side sind 0,5·Breite und 0,62·Höhe.
      final radii = cssFarthestCornerEllipseRadii(
        center: const Alignment(0, 2 * 0.38 - 1),
        box: box,
      );

      expect(radii.x, closeTo(math.sqrt2 * 0.5 * 390, 0.01));
      expect(radii.y, closeTo(math.sqrt2 * 0.62 * 844, 0.01));
    });

    test('die Ellipse geht genau durch die entfernteste Ecke', () {
      const center = Alignment(0, 2 * 0.38 - 1);
      final radii = cssFarthestCornerEllipseRadii(center: center, box: box);
      final centerY = (center.y + 1) / 2 * box.height;

      // Entfernteste Ecke von (195, 320,7) ist (0, 844) beziehungsweise
      // (390, 844). Auf der Ellipse gilt (dx/rx)² + (dy/ry)² = 1.
      final dx = box.width / 2;
      final dy = box.height - centerY;

      expect(
        math.pow(dx / radii.x, 2) + math.pow(dy / radii.y, 2),
        closeTo(1, 1e-9),
      );
    });
  });

  group('EllipticalGradientScale', () {
    test('lässt den Mittelpunkt liegen und streckt darum', () {
      const rect = Rect.fromLTWH(0, 0, 100, 200);
      const center = Alignment(0, -0.24);
      const scale = EllipticalGradientScale(center: center, scaleY: 2);
      final matrix = scale.transform(rect);
      final centerY = center.withinRect(rect).dy;

      double mapY(double y) => matrix.entry(1, 1) * y + matrix.entry(1, 3);

      expect(mapY(centerY), closeTo(centerY, 1e-9));
      expect(mapY(centerY + 10), closeTo(centerY + 20, 1e-9));
      expect(matrix.entry(0, 0), 1);
    });
  });
}

Matcher _closeToAlignment(Alignment expected) => predicate<Alignment>(
  (actual) =>
      (actual.x - expected.x).abs() < 1e-9 &&
      (actual.y - expected.y).abs() < 1e-9,
  'liegt bei $expected',
);
