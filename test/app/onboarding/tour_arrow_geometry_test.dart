import 'dart:math' as math;

import 'package:fact_app/app/onboarding/widgets/tour_arrow_geometry.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Pfeilgeometrie gegen `02_Frontend/app/screen-tour.jsx:6-33` und
/// `:398-433`.
///
/// Alle Erwartungen unten sind von Hand nachgerechnet und nicht aus einem Lauf
/// abgeschrieben. Das ist der Punkt: ein vertauschtes Vorzeichen ergibt einen
/// Pfeil, der plausibel aussieht und trotzdem falsch zeigt.
void main() {
  // Bezugsfläche 400 breit, Blase also mittig bei 200.
  const frameWidth = 400.0;
  const bubbleTop = 100.0;
  // 100 + 85 / 2.
  const bubbleCenterY = 142.5;

  TourArrowGeometry? geometryFor(Rect? target, {double curve = 0}) =>
      TourArrowGeometry.forTarget(
        target: target,
        bubbleTop: bubbleTop,
        frameWidth: frameWidth,
        curve: curve,
      );

  group('Ohne Ziel', () {
    test('gibt es keine Geometrie und damit keinen Pfeil', () {
      // Das ist der Degradationsfall. Die Quelle liefert an derselben Stelle
      // `null` für den Endpunkt (`screen-tour.jsx:423`) und zeichnet den Pfeil
      // gar nicht erst (`:450`).
      expect(geometryFor(null), isNull);
    });
  });

  group('Der Austrittspunkt an der Blase', () {
    test('liegt unten, wenn das Ziel unter der Blase liegt', () {
      final geometry = geometryFor(const Rect.fromLTWH(180, 300, 40, 40))!;

      // `bubble.top + 85 + 4`.
      expect(geometry.from, const Offset(200, 189));
    });

    test('liegt oben, wenn das Ziel über der Blase liegt', () {
      final geometry = geometryFor(const Rect.fromLTWH(180, 20, 40, 40))!;

      // `bubble.top - 4`.
      expect(geometry.from, const Offset(200, 96));
    });

    test('liegt rechts, wenn das Ziel seitlich versetzt ist', () {
      // Mitte (390, 150): dx = 190, dy = 7.5, also überwiegt waagerecht.
      final geometry = geometryFor(const Rect.fromLTWH(370, 130, 40, 40))!;

      // `bubbleCx + 260 / 2 + 4`.
      expect(geometry.from, const Offset(334, bubbleCenterY));
    });

    test('liegt links, wenn das Ziel nach links versetzt ist', () {
      final geometry = geometryFor(const Rect.fromLTWH(-10, 130, 40, 40))!;

      expect(geometry.from, const Offset(66, bubbleCenterY));
    });

    test('bei genau 45 Grad gewinnt die senkrechte Richtung', () {
      // Die Quelle schreibt `Math.abs(dy) >= Math.abs(dx)`. Ein `>` statt `>=`
      // wäre an jeder anderen Stelle unsichtbar.
      final geometry = geometryFor(
        Rect.fromCenter(
          center: const Offset(200 + 50, bubbleCenterY + 50),
          width: 40,
          height: 40,
        ),
      )!;

      expect(geometry.from.dx, 200);
    });
  });

  group('Der Endpunkt', () {
    test('bleibt um die halbe längere Kante plus 18 vor der Zielmitte', () {
      final geometry = geometryFor(const Rect.fromLTWH(180, 300, 40, 40))!;

      // Senkrecht darunter: 320 - (40 / 2 + 18).
      expect(geometry.to, const Offset(200, 282));
    });

    test('ein breiteres Ziel schiebt den Endpunkt weiter weg', () {
      // `Math.max(w, h)`, nicht die Kante in Pfeilrichtung. Ein Ziel von
      // 120 x 40 hält den Pfeil also 60 + 18 von der Mitte fern, obwohl er von
      // oben kommt.
      final geometry = geometryFor(const Rect.fromLTWH(140, 300, 120, 40))!;

      expect(geometry.to, const Offset(200, 320 - 78));
    });

    test('liegt auf der Geraden zwischen Austrittspunkt und Zielmitte', () {
      final target = const Rect.fromLTWH(320, 400, 40, 40);
      final geometry = geometryFor(target)!;
      final full = target.center - geometry.from;
      final shortened = geometry.to - geometry.from;

      expect(
        shortened.direction,
        closeTo(full.direction, 1e-9),
        reason: 'gleiche Richtung',
      );
      expect(
        (target.center - geometry.to).distance,
        closeTo(40 / 2 + 18, 1e-9),
      );
    });
  });

  group('Kurve und Spitze', () {
    test('ohne Krümmung liegen die Kontrollpunkte auf der Geraden', () {
      final geometry = geometryFor(const Rect.fromLTWH(180, 300, 40, 40))!;
      // from (200, 189), to (200, 282), Länge 93.
      expect(geometry.control1, const Offset(200, 189 + 93 * 0.25));
      expect(geometry.control2, const Offset(200, 189 + 93 * 0.70));
    });

    test('eine positive Krümmung schlägt zur einen Seite aus, eine negative '
        'zur anderen', () {
      final right = geometryFor(
        const Rect.fromLTWH(180, 300, 40, 40),
        curve: 0.35,
      )!;
      final left = geometryFor(
        const Rect.fromLTWH(180, 300, 40, 40),
        curve: -0.35,
      )!;

      expect(right.control1.dx, lessThan(200));
      expect(left.control1.dx, greaterThan(200));
      // Spiegelbildlich um die Gerade.
      expect(right.control1.dx - 200, closeTo(-(left.control1.dx - 200), 1e-9));
      // Anfang und Ende bleiben, nur der Bauch wandert.
      expect(right.from, left.from);
      expect(right.to, left.to);
    });

    test('die Spitze sitzt symmetrisch um die Tangente, mit 14 Länge', () {
      final geometry = geometryFor(const Rect.fromLTWH(180, 300, 40, 40))!;
      final sinA = math.sin(math.pi / 7);
      final cosA = math.cos(math.pi / 7);

      // Senkrecht nach unten: die Schenkel liegen 14 * sin(pi/7) neben und
      // 14 * cos(pi/7) über dem Endpunkt.
      expect(geometry.tipLeft.dx, closeTo(200 + 14 * sinA, 1e-9));
      expect(geometry.tipRight.dx, closeTo(200 - 14 * sinA, 1e-9));
      expect(geometry.tipLeft.dy, closeTo(282 - 14 * cosA, 1e-9));
      expect(geometry.tipRight.dy, closeTo(282 - 14 * cosA, 1e-9));
      expect((geometry.tipLeft - geometry.to).distance, closeTo(14, 1e-9));
      expect((geometry.tipRight - geometry.to).distance, closeTo(14, 1e-9));
    });

    test('die Spitze folgt der Tangente, nicht der Sehne', () {
      // Bei starker Krümmung zeigen Sehne und Tangente in verschiedene
      // Richtungen. Wer die Sehne nimmt, bekommt eine Spitze, die schief auf
      // dem Bogen sitzt.
      final geometry = geometryFor(
        const Rect.fromLTWH(180, 300, 40, 40),
        curve: 0.35,
      )!;
      final tipDirection =
          (geometry.to - (geometry.tipLeft + geometry.tipRight) / 2).direction;
      final tangent = (geometry.to - geometry.control2).direction;
      final chord = (geometry.to - geometry.from).direction;

      expect(tipDirection, closeTo(tangent, 1e-9));
      expect(tipDirection, isNot(closeTo(chord, 1e-3)));
    });
  });

  group('Gleichheit', () {
    test('zwei getrennt gerechnete Ergebnisse sind gleich', () {
      // Absichtlich zweimal gerechnet und nicht zweimal dasselbe Objekt
      // benutzt: bei `const`-Ausdrücken würde Dart kanonisieren, und der Test
      // bliebe auch dann grün, wenn `==` nur `identical` prüfte.
      final a = geometryFor(const Rect.fromLTWH(180, 300, 40, 40))!;
      final b = geometryFor(const Rect.fromLTWH(180, 300, 40, 40))!;

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('eine andere Krümmung ist ein anderer Wert', () {
      expect(
        geometryFor(const Rect.fromLTWH(180, 300, 40, 40), curve: 0.35),
        isNot(geometryFor(const Rect.fromLTWH(180, 300, 40, 40))),
      );
    });
  });
}
