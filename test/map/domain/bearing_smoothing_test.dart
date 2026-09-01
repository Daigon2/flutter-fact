import 'package:fact_app/map/domain/bearing_smoothing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Kompass-Glättung und der Wachhund für einen toten Kompass.
void main() {
  group('SmoothedBearing.towards', () {
    test('von 0 nach 100 ergibt 25', () {
      // 0 + 100 * 0.25, der einfachste Fall ohne Nullgrenze und ohne
      // Vorzeichenwechsel.
      final result = const SmoothedBearing(0).towards(100);

      expect(result.degrees, 25);
    });

    test('der Fixpunkt: bei degrees == heading ändert sich nichts', () {
      final result = const SmoothedBearing(123.5).towards(123.5);

      expect(result.degrees, 123.5);
    });

    test('der Sprung über die Nullgrenze, von 350 nach 10', () {
      // Der kürzere Weg von 350 nach 10 ist +20 (über die 360-Grenze), nicht
      // -340 (rückwärts durch den ganzen Kreis). Ein Viertel davon sind 5
      // Grad, also 350 + 5 = 355.
      final result = const SmoothedBearing(350).towards(10);

      expect(result.degrees, 355);
      expect(result.degrees, inInclusiveRange(0, 360));
    });

    test('der Sprung über die Nullgrenze, von 10 nach 350', () {
      // Die Gegenrichtung: der kürzere Weg von 10 nach 350 ist -20 (rückwärts
      // über die 0-Grenze), nicht +340. Ein Viertel davon sind -5 Grad, also
      // 10 - 5 = 5, gefaltet auf [0, 360) durch das abschließende `% 360`.
      final result = const SmoothedBearing(10).towards(350);

      expect(result.degrees, 5);
      expect(result.degrees, inInclusiveRange(0, 360));
    });

    test('das Ergebnis liegt immer in [0, 360)', () {
      for (final double start in <double>[0, 90, 180, 270, 359.9]) {
        for (final double target in <double>[0, 90, 180, 270, 359.9]) {
          final result = SmoothedBearing(start).towards(target);

          expect(
            result.degrees,
            inInclusiveRange(0, 360),
            reason: 'start: $start, target: $target',
          );
          expect(
            result.degrees,
            lessThan(360),
            reason: 'start: $start, target: $target',
          );
        }
      }
    });

    test(
      'mehrere Schritte nähern sich dem Ziel monoton, ohne Überschießen',
      () {
        // Von 0 auf ein Ziel von 40 Grad: jeder Schritt verringert den Abstand
        // zum Ziel, und keiner überschreitet es. Nach zwanzig Schritten ist die
        // Annäherung praktisch abgeschlossen.
        SmoothedBearing bearing = const SmoothedBearing(0);
        double? previousDistance;

        for (int step = 0; step < 20; step++) {
          bearing = bearing.towards(40);
          final double distance = (40 - bearing.degrees).abs();

          if (previousDistance != null) {
            expect(
              distance,
              lessThanOrEqualTo(previousDistance),
              reason: 'Schritt $step',
            );
          }
          expect(
            bearing.degrees,
            lessThanOrEqualTo(40),
            reason: 'kein Überschießen in Schritt $step',
          );
          previousDistance = distance;
        }

        // Nach zwanzig Schritten mit Faktor 0.25 bleibt (1 - 0.25)^20, also
        // rund 0,32 Prozent der ursprünglichen 40 Grad Abstand, das sind
        // knapp 0,13 Grad. Die Toleranz trägt das, ohne beliebig lose zu sein.
        expect(bearing.degrees, closeTo(40, 0.2));
      },
    );
  });

  group('isCompassStale', () {
    test('knapp unter 5 Sekunden gilt der Kompass noch als lebendig', () {
      expect(
        isCompassStale(
          sinceLastHeading: compassStaleAfter - const Duration(milliseconds: 1),
        ),
        isFalse,
      );
    });

    test('genau 5 Sekunden gelten noch als lebendig', () {
      // Echt größer, wie `Date.now() - last > 5000` in der Quelle: die
      // Grenze selbst zählt noch nicht als tot.
      expect(isCompassStale(sinceLastHeading: compassStaleAfter), isFalse);
    });

    test('knapp über 5 Sekunden gilt der Kompass als tot', () {
      expect(
        isCompassStale(
          sinceLastHeading: compassStaleAfter + const Duration(milliseconds: 1),
        ),
        isTrue,
      );
    });
  });
}
