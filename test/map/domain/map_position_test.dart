import 'dart:math' as math;

import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Meter je Grad Breite, von Hand hergeleitet.
///
/// Zwei Punkte auf demselben Längengrad liegen auf einem Großkreis, dem
/// Meridian. Die Großkreisstrecke ist dort schlicht die Bogenlänge `r * phi`
/// mit `phi` im Bogenmaß, für ein Grad also `r * pi / 180`. Mit dem Radius der
/// Quelle sind das 111194,92664455873 Meter.
///
/// Diese Zahl stammt **nicht** aus `distanceInMetersTo`, sondern aus der
/// Bogenformel. Genau deshalb taugt sie als Prüfwert: eine
/// Haversine-Implementierung gegen sich selbst zu prüfen belegt nichts. Der
/// Radius wird weiter unten separat gegen `screen-map.jsx:297` festgenagelt,
/// er ist hier also keine unbelegte Eingangsgröße.
final double metersPerDegreeLatitude =
    MapPosition.earthRadiusInMeters * math.pi / 180;

void main() {
  group('Haversine gegen eine unabhängig hergeleitete Strecke', () {
    test('die Herleitung selbst ergibt 111194,9266 Meter je Grad', () {
      expect(metersPerDegreeLatitude, closeTo(111194.92664455873, 1e-8));
    });

    test('ein Grad Breite auf demselben Längengrad ist die Bogenlänge', () {
      const MapPosition south = MapPosition(latitude: 48, longitude: 11.582);
      const MapPosition north = MapPosition(latitude: 49, longitude: 11.582);

      expect(
        south.distanceInMetersTo(north),
        closeTo(metersPerDegreeLatitude, 1e-6),
      );
    });

    test('ein Grad Länge auf dem Äquator ist dieselbe Bogenlänge', () {
      // Der Äquator ist ebenfalls ein Großkreis, also gilt dieselbe
      // Herleitung. Das prüft zugleich den `cos`-Anteil der Formel: mit
      // `cos(0) = 1` muss dasselbe herauskommen wie am Meridian.
      const MapPosition west = MapPosition(latitude: 0, longitude: 0);
      const MapPosition east = MapPosition(latitude: 0, longitude: 1);

      expect(
        west.distanceInMetersTo(east),
        closeTo(metersPerDegreeLatitude, 1e-6),
      );
    });

    test('ein Grad Länge auf 60° Breite ist knapp halb so weit', () {
      // Der Breitenkreis bei 60° hat den Radius `r * cos(60°) = r / 2`, ein
      // Grad darauf misst also `metersPerDegreeLatitude / 2` = 55597,46 Meter.
      // Der Breitenkreis ist aber **kein** Großkreis: die kürzeste Verbindung
      // weicht polwärts aus und ist deshalb ein Stück **kürzer**, hier um 0,53
      // Meter. Der Test behauptet genau diese zwei Dinge und nicht mehr:
      // kleiner als die halbe Bogenlänge, und um weniger als 0,02 Prozent.
      //
      // Die Richtung war beim ersten Anlauf falsch geraten und der Test fiel.
      // Das ist der Beleg dafür, dass hier wirklich gegen eine unabhängige
      // Herleitung geprüft wird und nicht gegen die Implementierung.
      const MapPosition west = MapPosition(latitude: 60, longitude: 0);
      const MapPosition east = MapPosition(latitude: 60, longitude: 1);
      final double half = metersPerDegreeLatitude / 2;

      expect(west.distanceInMetersTo(east), lessThan(half));
      expect(west.distanceInMetersTo(east), closeTo(half, half * 0.0002));
    });

    test('zehntausendstel Grad Breite sind gut elf Meter', () {
      // Der Maßstab, in dem die Totzone von 12 Metern arbeitet:
      // 0,0001 * 111194,92664455873 = 11,1194926644.
      const MapPosition from = MapPosition(
        latitude: 48.1351,
        longitude: 11.582,
      );
      const MapPosition to = MapPosition(latitude: 48.1352, longitude: 11.582);

      expect(
        from.distanceInMetersTo(to),
        closeTo(metersPerDegreeLatitude / 10000, 1e-6),
      );
    });

    test('der Abstand zu sich selbst ist null', () {
      const MapPosition here = MapPosition(
        latitude: 48.1351,
        longitude: 11.582,
      );

      expect(here.distanceInMetersTo(here), 0);
    });

    test('der Abstand ist symmetrisch', () {
      const MapPosition munich = MapPosition(
        latitude: 48.1351,
        longitude: 11.582,
      );
      const MapPosition rome = MapPosition(
        latitude: 41.896,
        longitude: 12.4822,
      );

      expect(
        munich.distanceInMetersTo(rome),
        closeTo(rome.distanceInMetersTo(munich), 1e-9),
      );
    });
  });

  group('Der Erdradius kommt aus der Quelle', () {
    test('6371000 Meter, wie screen-map.jsx:297', () {
      // Festgenagelt, weil die Totzone von 12 Metern gegen diese Rechnung
      // geeicht ist. Wer den Radius ändert, verschiebt die Schwelle.
      expect(MapPosition.earthRadiusInMeters, 6371000);
    });
  });

  group('Peilung, gegen die vier Himmelsrichtungen geprüft', () {
    // Die Himmelsrichtungen sind hier die unabhängige Herleitung: eine
    // Verschiebung nach Norden muss 0 ergeben, nach Osten 90, und das gilt
    // ohne jede Kenntnis der Formel. Ein Test, der nur nachrechnet, was der
    // Code rechnet, prüft nichts.
    const MapPosition muenchen = MapPosition(
      latitude: 48.1372,
      longitude: 11.5755,
    );

    test('genau nördlich ergibt 0 Grad', () {
      expect(
        muenchen.bearingInDegreesTo(
          const MapPosition(latitude: 48.2372, longitude: 11.5755),
        ),
        closeTo(0, 0.001),
      );
    });

    test('genau östlich ergibt 90 Grad', () {
      expect(
        muenchen.bearingInDegreesTo(
          const MapPosition(latitude: 48.1372, longitude: 11.7755),
        ),
        closeTo(90, 0.1),
      );
    });

    test('genau südlich ergibt 180 Grad', () {
      expect(
        muenchen.bearingInDegreesTo(
          const MapPosition(latitude: 48.0372, longitude: 11.5755),
        ),
        closeTo(180, 0.001),
      );
    });

    test('genau westlich ergibt 270 Grad', () {
      // **Der Fall, der ohne das abschließende `+ 360) % 360` falsch wäre.**
      // `atan2` liefert hier einen negativen Wert, und ohne die Faltung stünde
      // dort −90 statt 270. Die Quelle hat dieselbe Zeile, aus demselben
      // Grund (`screen-map.jsx:652`).
      expect(
        muenchen.bearingInDegreesTo(
          const MapPosition(latitude: 48.1372, longitude: 11.3755),
        ),
        closeTo(270, 0.1),
      );
    });

    test('das Ergebnis liegt immer in [0, 360)', () {
      // Über acht Richtungen geprüft, damit keine einzelne Himmelsrichtung
      // zufällig durchkommt.
      for (final MapPosition ziel in <MapPosition>[
        const MapPosition(latitude: 48.2372, longitude: 11.6755),
        const MapPosition(latitude: 48.0372, longitude: 11.6755),
        const MapPosition(latitude: 48.0372, longitude: 11.4755),
        const MapPosition(latitude: 48.2372, longitude: 11.4755),
        const MapPosition(latitude: -33.8688, longitude: 151.2093),
        const MapPosition(latitude: 64.1466, longitude: -21.9426),
        const MapPosition(latitude: 0, longitude: 0),
        const MapPosition(latitude: 48.1372, longitude: 11.5756),
      ]) {
        final double peilung = muenchen.bearingInDegreesTo(ziel);
        expect(peilung, greaterThanOrEqualTo(0));
        expect(peilung, lessThan(360));
      }
    });

    test('auf demselben Punkt ist die Peilung 0 und wirft nicht', () {
      // Keine Aussage über eine Richtung, sondern die einzige, die eine
      // Peilung ohne Strecke haben kann. Wichtig ist, dass nichts wirft und
      // kein `NaN` herauskommt: der Pfeil bekäme sonst einen Index, den
      // `huntArrowIndexFor` nicht bilden kann.
      final double peilung = muenchen.bearingInDegreesTo(muenchen);

      expect(peilung, 0);
      expect(peilung.isNaN, isFalse);
    });

    test('die Peilung ist nicht symmetrisch', () {
      // Die Gegenprobe zur Verwechslung mit der Entfernung: hin und zurück
      // sind bei einer Strecke gleich, bei einer Peilung nicht. Ohne sie käme
      // eine Umsetzung durch, die Start und Ziel vertauscht.
      const MapPosition ziel = MapPosition(
        latitude: 48.2372,
        longitude: 11.6755,
      );

      expect(
        muenchen.bearingInDegreesTo(ziel),
        isNot(closeTo(ziel.bearingInDegreesTo(muenchen), 1)),
      );
    });
  });

  group('Wertgleichheit', () {
    test(
      'zwei zur Laufzeit gebaute Punkte mit gleichen Feldern sind gleich',
      () {
        // Zur Laufzeit gebaut und mit `identical` gegengeprüft, nach dem
        // Muster aus `auth_city_test.dart:59`: zwei gleich geschriebene
        // `const`-Werte sind in Dart **dasselbe Objekt**, ein Gleichheitstest
        // darauf prüfte nichts. Diese Falle hat im Projekt schon zweimal eine
        // Mutation von `==` auf `identical` überleben lassen.
        final MapPosition left = MapPosition(
          latitude: double.parse('48.1351'),
          longitude: double.parse('11.582'),
        );
        final MapPosition right = MapPosition(
          latitude: double.parse('48.13510'),
          longitude: double.parse('11.58200'),
        );

        expect(identical(left, right), isFalse);
        expect(left, right);
        expect(left.hashCode, right.hashCode);
      },
    );

    test('jedes Feld zählt für die Gleichheit', () {
      const MapPosition base = MapPosition(
        latitude: 48.1351,
        longitude: 11.582,
      );

      expect(
        base,
        isNot(const MapPosition(latitude: 48.1352, longitude: 11.582)),
      );
      expect(
        base,
        isNot(const MapPosition(latitude: 48.1351, longitude: 11.583)),
      );
    });

    test('Breite und Länge sind nicht vertauschbar', () {
      // Ein Dreher wäre sonst unsichtbar, und er ist der häufigste Fehler bei
      // Geokoordinaten überhaupt.
      final MapPosition swapped = MapPosition(
        latitude: double.parse('11.582'),
        longitude: double.parse('48.1351'),
      );

      expect(
        swapped,
        isNot(const MapPosition(latitude: 48.1351, longitude: 11.582)),
      );
    });
  });

  group('toString verrät keine Koordinaten', () {
    test('weder Breite noch Länge tauchen im Text auf', () {
      // `security.md` §6 verbietet das Loggen genauer Koordinaten, und eine
      // MapPosition ist regelmäßig die Nutzerposition.
      const MapPosition here = MapPosition(
        latitude: 48.1351,
        longitude: 11.582,
      );

      expect(here.toString(), 'MapPosition(gesetzt)');
      expect(here.toString(), isNot(contains('48')));
      expect(here.toString(), isNot(contains('11')));
    });
  });
}
