import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_position_rect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('enclosingOrNull', () {
    test('leere Eingabe ergibt null, statt zu raten', () {
      expect(MapPositionRect.enclosingOrNull(const <MapPosition>[]), isNull);
    });

    test('ein einzelner Punkt ergibt ein Rechteck der Fläche null', () {
      final MapPosition point = MapPosition(
        latitude: 48.1351,
        longitude: 11.582,
      );

      final MapPositionRect? rect = MapPositionRect.enclosingOrNull(
        <MapPosition>[point],
      );

      expect(rect, isNotNull);
      expect(rect!.southWest, point);
      expect(rect.northEast, point);
      expect(rect.latitudeSpanInDegrees, 0);
      expect(rect.longitudeSpanInDegrees, 0);
    });

    test('mehrere Punkte ergeben Ecken aus dem jeweiligen Extrem pro Achse, '
        'unabhängig gerechnet: Süd-West aus Rom (Breite) und München (Länge), '
        'Nord-Ost umgekehrt', () {
      final MapPosition munich = MapPosition(
        latitude: 48.1351,
        longitude: 11.582,
      );
      final MapPosition rome = MapPosition(
        latitude: 41.896,
        longitude: 12.4822,
      );

      final MapPositionRect? rect = MapPositionRect.enclosingOrNull(
        <MapPosition>[munich, rome],
      );

      expect(rect, isNotNull);
      // Von Hand: minLat=41.896 (Rom), minLng=11.582 (München).
      expect(rect!.southWest.latitude, closeTo(41.896, 1e-9));
      expect(rect.southWest.longitude, closeTo(11.582, 1e-9));
      // Von Hand: maxLat=48.1351 (München), maxLng=12.4822 (Rom).
      expect(rect.northEast.latitude, closeTo(48.1351, 1e-9));
      expect(rect.northEast.longitude, closeTo(12.4822, 1e-9));
    });

    test('die Reihenfolge der Eingabe ändert das Ergebnis nicht', () {
      final MapPosition a = MapPosition(latitude: 10, longitude: 100);
      final MapPosition b = MapPosition(latitude: -5, longitude: 20);
      final MapPosition c = MapPosition(latitude: 30, longitude: 50);

      final MapPositionRect? forward = MapPositionRect.enclosingOrNull(
        <MapPosition>[a, b, c],
      );
      final MapPositionRect? shuffled = MapPositionRect.enclosingOrNull(
        <MapPosition>[c, a, b],
      );

      expect(forward, isNotNull);
      expect(shuffled, isNotNull);
      expect(shuffled!.southWest, forward!.southWest);
      expect(shuffled.northEast, forward.northEast);
    });
  });

  group('center', () {
    test('ist das arithmetische Mittel der beiden Ecken', () {
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: 41.896, longitude: 11.582),
        northEast: MapPosition(latitude: 48.1351, longitude: 12.4822),
      );

      // Von Hand: (41.896+48.1351)/2 = 45.01555, (11.582+12.4822)/2 = 12.0321.
      expect(rect.center.latitude, closeTo(45.01555, 1e-9));
      expect(rect.center.longitude, closeTo(12.0321, 1e-9));
    });
  });

  group('Spannweiten', () {
    test('Breiten- und Längenspanne sind Differenz der Ecken', () {
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: 41.896, longitude: 11.582),
        northEast: MapPosition(latitude: 48.1351, longitude: 12.4822),
      );

      expect(rect.latitudeSpanInDegrees, closeTo(6.2391, 1e-9));
      expect(rect.longitudeSpanInDegrees, closeTo(0.9002, 1e-9));
    });

    test('eine Spanne von null in genau einer Richtung ist gültig', () {
      final MapPositionRect flatByLatitude = MapPositionRect(
        southWest: MapPosition(latitude: 48, longitude: 11),
        northEast: MapPosition(latitude: 48, longitude: 12),
      );

      expect(flatByLatitude.latitudeSpanInDegrees, 0);
      expect(flatByLatitude.longitudeSpanInDegrees, closeTo(1, 1e-9));
    });
  });

  group('Der 180. Längengrad: dokumentiertes, nicht behobenes Verhalten', () {
    test('Punkte auf beiden Seiten der Datumsgrenze ergeben eine riesige, '
        'falsche Längenspanne statt der gemeinten kleinen', () {
      // Zwei Punkte, die in Wirklichkeit nur 2° auseinanderliegen (über
      // die Datumsgrenze hinweg): -179° und +179°. enclosingOrNull kennt
      // die Datumsgrenze nicht und bildet naiv Minimum und Maximum.
      final MapPositionRect? rect =
          MapPositionRect.enclosingOrNull(<MapPosition>[
            MapPosition(latitude: 0, longitude: -179),
            MapPosition(latitude: 0, longitude: 179),
          ]);

      expect(rect, isNotNull);
      // Von Hand: 179 - (-179) = 358, nicht die gemeinten 2°.
      expect(rect!.longitudeSpanInDegrees, closeTo(358, 1e-9));
      // Der Mittelpunkt landet nahe 0° Länge, der gegenüberliegenden
      // Seite der Erde von der gemeinten Mitte nahe ±180°.
      expect(rect.center.longitude, closeTo(0, 1e-9));
    });
  });

  group('Wertgleichheit', () {
    test(
      'zwei zur Laufzeit gebaute Rechtecke mit gleichen Ecken sind gleich',
      () {
        // Zur Laufzeit gebaut und mit `identical` gegengeprüft, nach dem
        // Muster aus `map_position_test.dart`: zwei gleich geschriebene
        // `const`-Werte wären in Dart dasselbe Objekt, ein Gleichheitstest
        // darauf prüfte nichts.
        MapPositionRect build() => MapPositionRect(
          southWest: MapPosition(
            latitude: double.parse('48.0'),
            longitude: double.parse('11.0'),
          ),
          northEast: MapPosition(
            latitude: double.parse('49.0'),
            longitude: double.parse('12.0'),
          ),
        );

        final MapPositionRect left = build();
        final MapPositionRect right = build();

        expect(identical(left, right), isFalse);
        expect(left, right);
        expect(left.hashCode, right.hashCode);
      },
    );

    test('südwestliche Ecke zählt für die Gleichheit', () {
      final MapPositionRect base = MapPositionRect(
        southWest: MapPosition(latitude: 48, longitude: 11),
        northEast: MapPosition(latitude: 49, longitude: 12),
      );
      final MapPositionRect differentSouthWest = MapPositionRect(
        southWest: MapPosition(latitude: 48.1, longitude: 11),
        northEast: MapPosition(latitude: 49, longitude: 12),
      );

      expect(base, isNot(differentSouthWest));
    });

    test('nordöstliche Ecke zählt für die Gleichheit', () {
      final MapPositionRect base = MapPositionRect(
        southWest: MapPosition(latitude: 48, longitude: 11),
        northEast: MapPosition(latitude: 49, longitude: 12),
      );
      final MapPositionRect differentNorthEast = MapPositionRect(
        southWest: MapPosition(latitude: 48, longitude: 11),
        northEast: MapPosition(latitude: 49, longitude: 12.1),
      );

      expect(base, isNot(differentNorthEast));
    });
  });

  group('hashCode', () {
    test('ungleiche Rechtecke streuen verschieden', () {
      // **Warum das eine eigene Zusicherung braucht.** Ein konstanter
      // `hashCode`, etwa `int get hashCode => 0`, ist nach dem Dart-Vertrag
      // erlaubt, weil Kollisionen erlaubt sind, und lief deshalb am
      // 31.08.2026 durch alle Gleichheitsproben dieser Datei; gefunden von
      // der unabhängigen Review. Erlaubt heißt aber nicht folgenlos: sobald
      // Rechtecke in einer Menge oder als Schlüssel liegen, macht ein
      // konstanter Streuwert aus jedem Zugriff eine lineare Suche, ohne dass
      // irgendetwas bricht oder meldet.
      //
      // Zugesichert wird bewusst nur, was für **diese** beiden Beispiele
      // gelten muss. Die Zusage „nie eine Kollision" wäre unhaltbar und
      // stünde außerdem im Widerspruch zum Vertrag von `Object.hashCode`.
      final MapPositionRect one = MapPositionRect(
        southWest: MapPosition(latitude: 48, longitude: 11),
        northEast: MapPosition(latitude: 49, longitude: 12),
      );
      final MapPositionRect other = MapPositionRect(
        southWest: MapPosition(latitude: 48, longitude: 11),
        northEast: MapPosition(latitude: 49, longitude: 12.5),
      );

      expect(one == other, isFalse);
      expect(one.hashCode, isNot(other.hashCode));
    });
  });

  group('toString verrät keine Koordinaten', () {
    test('weder Breite noch Länge tauchen im Text auf', () {
      // Folgt transitiv aus MapPosition.toString(), aber eigens geprüft:
      // eine künftige Änderung an MapPositionRect.toString() könnte die
      // Ecken direkt interpolieren, statt ihre eigene toString-Methode zu
      // benutzen, und das soll ein Test hier auffangen, nicht erst der Test
      // von MapPosition.
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: 48.1351, longitude: 11.582),
        northEast: MapPosition(latitude: 48.2, longitude: 11.7),
      );

      expect(rect.toString(), isNot(contains('48')));
      expect(rect.toString(), isNot(contains('11')));
      expect(rect.toString(), contains('MapPositionRect'));
    });
  });
}
