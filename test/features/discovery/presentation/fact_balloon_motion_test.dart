import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_motion.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drehung und Auf-und-ab, ohne Widget und ohne Warten.
///
/// **Der Winkelzähler ist der einzige Zustand dieses Schrittes mit
/// Gedächtnis**, und keine seiner drei Zusicherungen ist an einem gezeichneten
/// Bild zu erkennen: dass er aufsummiert, dass er einen Neuaufbau des Widgets
/// überlebt, und dass er beim Verlassen der Reichweite gelöscht wird.
void main() {
  FactProximityPoint pointAt(String id, double emphasis) => FactProximityPoint(
    id: id,
    position: const MapPosition(latitude: 48.1351, longitude: 11.582),
    style: factCategoryStylesByKey['hist']!,
    // Betonung ist `1 - dist / 150`, die Entfernung also `150 * (1 - t)`.
    distanceInMeters: factProximityRadiusInMeters * (1 - emphasis),
  );

  group('Drehtempo', () {
    test('die Kurve steht an ihren Enden und in der Mitte', () {
      // `screen-map.jsx:2275`, umgerechnet von Grad je Bild auf Grad je
      // Sekunde bei 60 Hz.
      expect(factSpinSpeedAt(0), closeTo(7.2, 1e-9));
      expect(factSpinSpeedAt(1), closeTo(1080, 1e-9));
      // 7,2 + 1072,8 * 0,5^2,2, unabhängig nachgerechnet.
      expect(factSpinSpeedAt(0.5), closeTo(240.6817, 1e-3));
    });

    test('„Grad je Bild" ist bewusst nicht übernommen', () {
      // **Das ist eine Wahl und keine Fundstelle.** Die Quelle addiert einmal
      // je `requestAnimationFrame` (`:2277`); auf einem 120-Hz-Gerät dreht
      // derselbe Ballon dort doppelt so schnell. Hier steht das Tempo in Grad
      // je Sekunde, geeicht auf 60 Bilder.
      expect(factSpinReferenceFramesPerSecond, 60);
      expect(factSpinMinDegreesPerSecond, closeTo(0.12 * 60, 1e-9));
      expect(factSpinMaxDegreesPerSecond, closeTo(18 * 60, 1e-9));
      expect(factSpinExponent, 2.2);
    });

    test('das Tempo wächst streng mit der Nähe', () {
      double previous = -1;
      for (int step = 0; step <= 10; step++) {
        final double speed = factSpinSpeedAt(step / 10);
        expect(speed, greaterThan(previous));
        previous = speed;
      }
    });
  });

  group('Winkelzähler', () {
    test('er summiert auf', () {
      final FactBalloonSpin spin = FactBalloonSpin();
      final List<FactProximityPoint> points = <FactProximityPoint>[
        pointAt('7', 1),
      ];

      spin.advance(points, const Duration(milliseconds: 100));
      final double afterFirst = spin.angleOf('7');
      spin.advance(points, const Duration(milliseconds: 100));

      expect(afterFirst, closeTo(108, 1e-6), reason: '1080 Grad je Sekunde');
      // **Aufsummiert und nicht neu gesetzt.** Ein Zähler, der bei jedem Bild
      // von vorn begänne, stünde still, und das sähe im Bild aus wie ein
      // Ballon, der sich nicht dreht, also wie ein fehlender Aufruf.
      expect(spin.angleOf('7'), closeTo(216, 1e-6));
    });

    test('er dreht schneller, je näher der Fakt ist', () {
      final FactBalloonSpin spin = FactBalloonSpin();
      spin.advance(<FactProximityPoint>[
        pointAt('nah', 1),
        pointAt('fern', 0),
      ], const Duration(seconds: 1));

      expect(spin.angleOf('nah'), greaterThan(spin.angleOf('fern')));
      expect(spin.angleOf('fern'), closeTo(7.2, 1e-6));
    });

    test('er überlebt einen Neuaufbau des Widgets', () {
      // Der Controller lebt am `State` und nicht im `build`. Diese Prüfung ist
      // die Übersetzung davon in eine Aussage: derselbe Controller, zwei
      // Durchläufe, und dazwischen wird die Liste **neu gebaut**, wie es ein
      // Neuaufbau tut.
      final FactBalloonSpin spin = FactBalloonSpin();
      spin.advance(<FactProximityPoint>[
        pointAt('7', 1),
      ], const Duration(milliseconds: 100));
      spin.advance(<FactProximityPoint>[
        pointAt('7', 1),
      ], const Duration(milliseconds: 100));

      expect(spin.angleOf('7'), closeTo(216, 1e-6));
    });

    test('er wird beim Verlassen der Reichweite gelöscht', () {
      // `screen-map.jsx:2312`: `coinAngles.delete(id)`. Beim erneuten Betreten
      // beginnt die Drehung wieder bei 0; ohne das Löschen stünde ein Ballon
      // nach einem Spaziergang um den Block schief da.
      final FactBalloonSpin spin = FactBalloonSpin();
      spin.advance(<FactProximityPoint>[
        pointAt('7', 1),
      ], const Duration(milliseconds: 100));
      expect(spin.trackedIds, <String>{'7'});

      spin.advance(const <FactProximityPoint>[], const Duration(seconds: 1));

      expect(spin.trackedIds, isEmpty);
      expect(spin.angleOf('7'), 0);
    });

    test('das Löschen trifft nur den, der wirklich weg ist', () {
      final FactBalloonSpin spin = FactBalloonSpin();
      spin.advance(<FactProximityPoint>[
        pointAt('bleibt', 1),
        pointAt('geht', 1),
      ], const Duration(milliseconds: 100));

      spin.advance(<FactProximityPoint>[
        pointAt('bleibt', 1),
      ], const Duration(milliseconds: 100));

      expect(spin.trackedIds, <String>{'bleibt'});
      expect(spin.angleOf('bleibt'), closeTo(216, 1e-6));
    });

    test('der Winkel hängt an der Zeit und nicht an der Anzahl der Bilder', () {
      // Zwei Controller, dieselbe Gesamtzeit, verschieden viele Aufrufe. Wäre
      // das Tempo „je Bild", stünden sie am Ende verschieden.
      final FactBalloonSpin sixty = FactBalloonSpin();
      final FactBalloonSpin hundredTwenty = FactBalloonSpin();
      final List<FactProximityPoint> points = <FactProximityPoint>[
        pointAt('7', 1),
      ];

      for (int i = 0; i < 60; i++) {
        sixty.advance(points, const Duration(microseconds: 16666));
      }
      for (int i = 0; i < 120; i++) {
        hundredTwenty.advance(points, const Duration(microseconds: 8333));
      }

      expect(sixty.angleOf('7'), closeTo(hundredTwenty.angleOf('7'), 0.1));
      expect(sixty.angleOf('7'), closeTo(1080, 1));
    });
  });

  group('Auf-und-ab', () {
    /// Wie weit der Kopf zu diesem Zeitpunkt angehoben ist, negativ nach oben.
    ///
    /// Der Fortschritt ist dimensionslos, die Aussagen der Quelle stehen in
    /// Pixeln. Die Umrechnung steht hier einmal und nicht zehnmal.
    double offsetAt(int milliseconds) =>
        -factBalloonFloatRise *
        factBalloonFloatProgress(Duration(milliseconds: milliseconds));

    test('es beginnt unten, steht nach der Hälfte oben und kehrt zurück', () {
      // `styles.css:300-303`: 0 Prozent und 100 Prozent auf 0,
      // 50 Prozent auf -9 Pixel, Periode 2,2 Sekunden.
      expect(factBalloonFloatPeriod, const Duration(milliseconds: 2200));
      expect(factBalloonFloatRise, 9);

      expect(factBalloonFloatProgress(Duration.zero), 0);
      expect(offsetAt(0), 0);
      expect(offsetAt(1100), closeTo(-9, 1e-6));
      expect(offsetAt(2200), closeTo(0, 1e-6));
    });

    test('der Fortschritt ist ein Anteil und keine Pixelzahl', () {
      // **Daran hängen zwei Wirkungen**, der steigende Kopf und der
      // schrumpfende Bodenschatten (`screen-map.jsx:2300-2303`). Wäre das hier
      // schon in Pixeln gerechnet, bräuchte der Bodenschatten eine eigene
      // Umrechnung, und die wäre die Stelle, an der beide auseinanderlaufen.
      for (int ms = 0; ms <= 2200; ms += 41) {
        final double progress = factBalloonFloatProgress(
          Duration(milliseconds: ms),
        );
        expect(progress, greaterThanOrEqualTo(0), reason: 'bei $ms ms');
        expect(progress, lessThanOrEqualTo(1), reason: 'bei $ms ms');
      }
      expect(factBalloonFloatProgress(const Duration(milliseconds: 1100)), 1);
    });

    test('die Kurve ist ease-in-out und nicht linear', () {
      // **Die Mitte allein trägt diese Aussage nicht:** `ease-in-out` ist
      // symmetrisch, bei der Hälfte steht es genau wie eine Gerade auf der
      // Hälfte. Eine Mutation auf einen linearen Verlauf hat genau deshalb die
      // Suite überlebt. Gemessen wird deshalb ein Viertel der Halbwelle, dort
      // ist der Unterschied groß: die Bewegung setzt langsam ein.
      //
      // Bei 275 ms steht der Kopf auf einem Achtel der Periode, also einem
      // Viertel des Aufstiegs. Eine Gerade stünde dort bei -2,25.
      expect(offsetAt(275), closeTo(-1.158, 0.02));
      // Und dieselbe Aussage von der anderen Seite: kurz vor dem Scheitel
      // läuft die Bewegung aus, eine Gerade stünde bei -6,75.
      expect(offsetAt(825), closeTo(-7.842, 0.02));
    });

    test('es steht in der Mitte jeder Hälfte auf halber Höhe', () {
      // `ease-in-out` ist `cubic-bezier(0.42, 0, 0.58, 1)` und symmetrisch,
      // in der Mitte also genau die Hälfte. Der Verlauf gilt **je Abschnitt**;
      // wer ihn über die ganze Periode legte, bekäme hier andere Zahlen.
      expect(offsetAt(550), closeTo(-4.5, 0.05));
      expect(offsetAt(1650), closeTo(-4.5, 0.05));
    });

    test('es bleibt zwischen 0 und minus 9 und wiederholt sich', () {
      for (int ms = 0; ms <= 4400; ms += 37) {
        final double offset = offsetAt(ms);
        expect(offset, lessThanOrEqualTo(0));
        expect(offset, greaterThanOrEqualTo(-9));
        expect(
          offset,
          closeTo(offsetAt(ms + 2200), 1e-9),
          reason: 'die Periode wiederholt sich bei $ms ms',
        );
      }
    });
  });
}
