import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);
const MapPosition rome = MapPosition(latitude: 41.896, longitude: 12.4822);

void main() {
  group('MapCameraView ist immer vollständig', () {
    test(
      'zwei zur Laufzeit gebaute Zustände mit gleichen Feldern sind gleich',
      () {
        // Ohne `const`, sonst kanonisiert Dart beide zu demselben Objekt und
        // eine Mutation von `==` auf `identical` überlebt den Test.
        final MapCameraView left = MapCameraView(
          center: MapPosition(
            latitude: double.parse('48.1351'),
            longitude: double.parse('11.582'),
          ),
          zoom: double.parse('16.5'),
          bearing: double.parse('0'),
          pitch: double.parse('58'),
        );
        final MapCameraView right = MapCameraView(
          center: MapPosition(
            latitude: double.parse('48.13510'),
            longitude: double.parse('11.58200'),
          ),
          zoom: double.parse('16.50'),
          bearing: double.parse('0.0'),
          pitch: double.parse('58.0'),
        );

        expect(identical(left, right), isFalse);
        expect(left, right);
        expect(left.hashCode, right.hashCode);
      },
    );

    test('jedes der vier Felder zählt für die Gleichheit', () {
      const MapCameraView base = MapCameraView(
        center: munich,
        zoom: 16.5,
        bearing: 0,
        pitch: 58,
      );

      expect(
        base,
        isNot(
          const MapCameraView(center: rome, zoom: 16.5, bearing: 0, pitch: 58),
        ),
      );
      expect(
        base,
        isNot(
          const MapCameraView(center: munich, zoom: 15, bearing: 0, pitch: 58),
        ),
      );
      expect(
        base,
        isNot(
          const MapCameraView(
            center: munich,
            zoom: 16.5,
            bearing: 90,
            pitch: 58,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const MapCameraView(
            center: munich,
            zoom: 16.5,
            bearing: 0,
            pitch: 30,
          ),
        ),
      );
    });

    test('die Textausgabe zeigt keine Koordinaten, aber die Kamerawerte', () {
      const MapCameraView view = MapCameraView(
        center: munich,
        zoom: 16.5,
        bearing: 0,
        pitch: 58,
      );

      expect(view.toString(), contains('MapPosition(gesetzt)'));
      expect(view.toString(), isNot(contains('48.1351')));
      expect(view.toString(), isNot(contains('11.582')));
      expect(view.toString(), contains('16.5'));
      expect(view.toString(), contains('58'));
    });
  });

  group('MapCameraChange: null heißt unverändert', () {
    test('eine leere Änderung fasst kein Feld an', () {
      const MapCameraChange change = MapCameraChange();

      expect(change.center, isNull);
      expect(change.zoom, isNull);
      expect(change.bearing, isNull);
      expect(change.pitch, isNull);
    });

    test('die Auto-Neigung ändert nur die Neigung', () {
      // `screen-map.jsx:1764`: `easeTo({ pitch: target, duration: 300 })`.
      // Mittelpunkt, Zoom und Blickrichtung bleiben stehen.
      const MapCameraChange change = MapCameraChange(pitch: 58);

      expect(change.pitch, 58);
      expect(change.center, isNull);
      expect(change.zoom, isNull);
      expect(change.bearing, isNull);
      expect(change.changesBearing, isFalse);
    });

    test('eine Blickrichtung von 0 ist gesetzt und nicht „unverändert"', () {
      // Der Sky-Fall setzt `bearing: 0` ausdrücklich
      // (`screen-map.jsx:1736`). Wer 0 mit „nicht gesetzt" verwechselt,
      // verliert genau diese Absicht.
      const MapCameraChange change = MapCameraChange(bearing: 0);

      expect(change.bearing, 0);
      expect(change.changesBearing, isTrue);
    });

    test('ein Zoom von 0 ist ebenfalls gesetzt', () {
      const MapCameraChange change = MapCameraChange(zoom: 0);

      expect(change.zoom, 0);
    });

    test(
      'zwei zur Laufzeit gebaute Änderungen mit gleichem Inhalt sind gleich',
      () {
        final MapCameraChange left = MapCameraChange(
          center: MapPosition(
            latitude: double.parse('48.1351'),
            longitude: double.parse('11.582'),
          ),
          zoom: double.parse('15'),
        );
        final MapCameraChange right = MapCameraChange(
          center: MapPosition(
            latitude: double.parse('48.13510'),
            longitude: double.parse('11.58200'),
          ),
          zoom: double.parse('15.0'),
        );

        expect(identical(left, right), isFalse);
        expect(left, right);
        expect(left.hashCode, right.hashCode);
      },
    );

    test('jedes der vier Felder zählt für die Gleichheit', () {
      // Dasselbe Muster wie bei `MapCameraView`, und es gehört hier genauso
      // geprüft: zwei Typen mit demselben `==`, von denen nur einer einen
      // feldweisen Test hat, ist genau die Lücke, durch die ein vergessenes
      // `pitch` oder `center` unbemerkt durchfällt.
      const MapCameraChange base = MapCameraChange(
        center: munich,
        zoom: 16.5,
        bearing: 0,
        pitch: 58,
      );

      expect(
        base,
        isNot(
          const MapCameraChange(
            center: rome,
            zoom: 16.5,
            bearing: 0,
            pitch: 58,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const MapCameraChange(
            center: munich,
            zoom: 15,
            bearing: 0,
            pitch: 58,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const MapCameraChange(
            center: munich,
            zoom: 16.5,
            bearing: 90,
            pitch: 58,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const MapCameraChange(
            center: munich,
            zoom: 16.5,
            bearing: 0,
            pitch: 30,
          ),
        ),
      );
    });

    test('und jedes der vier Felder zählt auch für den hashCode', () {
      const MapCameraChange base = MapCameraChange(
        center: munich,
        zoom: 16.5,
        bearing: 0,
        pitch: 58,
      );

      expect(
        base.hashCode,
        isNot(
          const MapCameraChange(
            center: munich,
            zoom: 16.5,
            bearing: 0,
            pitch: 30,
          ).hashCode,
        ),
      );
      expect(
        base.hashCode,
        isNot(
          const MapCameraChange(
            center: rome,
            zoom: 16.5,
            bearing: 0,
            pitch: 58,
          ).hashCode,
        ),
      );
    });

    test(
      '„nicht gesetzt" und „auf null gesetzt" sind verschiedene Änderungen',
      () {
        expect(
          const MapCameraChange(bearing: 0),
          isNot(const MapCameraChange()),
        );
        expect(const MapCameraChange(zoom: 0), isNot(const MapCameraChange()));
      },
    );

    test('die Textausgabe zeigt keine Koordinaten', () {
      const MapCameraChange change = MapCameraChange(center: munich, zoom: 15);

      expect(change.toString(), contains('MapPosition(gesetzt)'));
      expect(change.toString(), isNot(contains('48.1351')));
    });
  });

  group('MapCameraMotion trennt Animation und Sprung als Typ', () {
    test('eine Animation trägt ihre Dauer', () {
      const MapCameraMotion motion = MapCameraAnimated(
        Duration(milliseconds: 900),
      );

      expect(motion, isA<MapCameraAnimated>());
      expect(
        (motion as MapCameraAnimated).duration,
        const Duration(milliseconds: 900),
      );
    });

    test('ein Sprung ist nicht dasselbe wie eine Animation von null', () {
      // Genau dafür gibt es den eigenen Typ: `Duration.zero` würde den Host
      // raten lassen.
      expect(
        const MapCameraImmediate(),
        isNot(const MapCameraAnimated(Duration.zero)),
      );
    });

    test('zwei zur Laufzeit gebaute Sprünge sind gleich', () {
      final MapCameraMotion left = MapCameraImmediate();
      final MapCameraMotion right = MapCameraImmediate();

      expect(identical(left, right), isFalse);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('zwei Animationen sind nur bei gleicher Dauer gleich', () {
      final MapCameraMotion left = MapCameraAnimated(
        Duration(milliseconds: int.parse('900')),
      );
      final MapCameraMotion right = MapCameraAnimated(
        Duration(milliseconds: int.parse('900')),
      );

      expect(identical(left, right), isFalse);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
      expect(left, isNot(const MapCameraAnimated(Duration(milliseconds: 600))));
    });

    test('die Hierarchie ist versiegelt und hat genau zwei Ausprägungen', () {
      // Ein `switch` über eine versiegelte Klasse ist vollständig, solange es
      // bei zwei bleibt. Kommt eine dritte Bewegungsart dazu, meldet der
      // Compiler jede Auswertungsstelle, und dieser Test erinnert daran, dass
      // das eine Entscheidung ist und kein Versehen.
      const List<MapCameraMotion> all = <MapCameraMotion>[
        MapCameraAnimated(Duration(milliseconds: 300)),
        MapCameraImmediate(),
      ];

      for (final MapCameraMotion motion in all) {
        final String label = switch (motion) {
          MapCameraAnimated() => 'animiert',
          MapCameraImmediate() => 'sofort',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
