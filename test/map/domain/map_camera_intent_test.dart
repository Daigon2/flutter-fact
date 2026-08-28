import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);

void main() {
  group('Der Rang bildet die Vorrangfolge ab', () {
    test('Befehl vor Einmal vor Dauer', () {
      const MapCameraCommand command = MapCameraCommand(
        change: MapCameraChange(bearing: 0, pitch: 30, zoom: 15),
        motion: MapCameraImmediate(),
        origin: MapCameraIntentOrigin.discovery,
        releasesBearingLock: true,
        clearsFollowAnchor: true,
      );
      const MapCameraOneShot oneShot = MapCameraOneShot(
        change: MapCameraChange(zoom: 16.5, pitch: 58),
        motion: MapCameraAnimated(Duration(milliseconds: 1200)),
        origin: MapCameraIntentOrigin.discovery,
      );
      const MapCameraFollow follow = MapCameraFollow(
        kind: MapCameraFollowKind.userPosition,
        change: MapCameraChange(center: munich),
        motion: MapCameraAnimated(Duration(milliseconds: 900)),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: false,
      );

      expect(command.rank, 1);
      expect(oneShot.rank, 3);
      expect(follow.rank, 4);
      expect(command.rank, lessThan(oneShot.rank));
      expect(oneShot.rank, lessThan(follow.rank));
    });

    test('Rang 2 ist keine Absicht, sondern Zustand am Gate', () {
      // Direkte Manipulation durch den Nutzer hat Rang 2 und taucht hier
      // deshalb nicht auf. `maplibre_gl 0.26.2` meldet für sie keine Ursache,
      // sie ist nur als unerklärte Kamerabewegung erkennbar. Wenn dieser Test
      // fällt, hat jemand eine vierte Absichtssorte eingeführt, und das ist
      // eine Entscheidung und kein Detail.
      const List<int> ranks = <int>[1, 3, 4];

      expect(ranks, isNot(contains(2)));
    });
  });

  group('Der Nutzerbefehl', () {
    test('muss sich zum Einrasten der Blickrichtung erklären', () {
      // Kein Standardwert: beide Befehle der Quelle lösen das Einrasten
      // (`screen-map.jsx:3166` und `:3182`), ein Standard `false` wäre für
      // beide bekannten Fälle falsch.
      const MapCameraCommand releasing = MapCameraCommand(
        change: MapCameraChange(zoom: 15),
        motion: MapCameraImmediate(),
        origin: MapCameraIntentOrigin.discovery,
        releasesBearingLock: true,
        clearsFollowAnchor: false,
      );
      const MapCameraCommand keeping = MapCameraCommand(
        change: MapCameraChange(zoom: 15),
        motion: MapCameraImmediate(),
        origin: MapCameraIntentOrigin.discovery,
        releasesBearingLock: false,
        clearsFollowAnchor: false,
      );

      expect(releasing.releasesBearingLock, isTrue);
      expect(keeping.releasesBearingLock, isFalse);
    });

    test('der harte Reset leert auch den Anker der Strecken-Totzone', () {
      // `screen-map.jsx:3165` setzt `lastCameraPosRef.current = null`, direkt
      // vor `:3166`. Ohne dieses Feld unterdrückt das Gate den nächsten
      // GPS-Fix mit der Totzone, während die Quelle ihn ausführt.
      const MapCameraCommand longPress = MapCameraCommand(
        change: MapCameraChange(
          center: munich,
          bearing: 0,
          pitch: 30,
          zoom: 15,
        ),
        motion: MapCameraImmediate(),
        origin: MapCameraIntentOrigin.discovery,
        releasesBearingLock: true,
        clearsFollowAnchor: true,
      );

      expect(longPress.clearsFollowAnchor, isTrue);
      expect(longPress.releasesBearingLock, isTrue);
    });

    test('der kurze Druck löst nur das Einrasten, nicht den Anker', () {
      // `:3182` setzt allein `manualBearingRef = false` und ruft dann
      // `recenter()` (`:2983-2987`), das `lastCameraPosRef` nicht anfasst.
      // Genau deshalb hat `clearsFollowAnchor` keinen Standardwert: die zwei
      // bekannten Befehle sind sich uneinig.
      const MapCameraCommand shortPress = MapCameraCommand(
        change: MapCameraChange(center: munich, zoom: 15),
        motion: MapCameraAnimated(Duration(milliseconds: 400)),
        origin: MapCameraIntentOrigin.discovery,
        releasesBearingLock: true,
        clearsFollowAnchor: false,
      );

      expect(shortPress.releasesBearingLock, isTrue);
      expect(shortPress.clearsFollowAnchor, isFalse);
    });

    test('der harte Reset trägt alle vier Werte der Quelle', () {
      // `screen-map.jsx:3168`: `jumpTo({ center, bearing: 0, pitch: 30,
      // zoom: 15 })`, und davor `lastCameraPosRef = null`.
      const MapCameraCommand reset = MapCameraCommand(
        change: MapCameraChange(
          center: munich,
          bearing: 0,
          pitch: 30,
          zoom: 15,
        ),
        motion: MapCameraImmediate(),
        origin: MapCameraIntentOrigin.discovery,
        releasesBearingLock: true,
        clearsFollowAnchor: true,
      );

      expect(reset.change.center, munich);
      expect(reset.change.bearing, 0);
      expect(reset.change.pitch, 30);
      expect(reset.change.zoom, 15);
      expect(reset.motion, const MapCameraImmediate());
    });
  });

  group('Die Einmal-Absicht', () {
    test('weicht im Standard keiner Animation', () {
      const MapCameraOneShot skyFall = MapCameraOneShot(
        change: MapCameraChange(zoom: 16.5, pitch: 58, bearing: 0),
        motion: MapCameraAnimated(Duration(milliseconds: 1200)),
        origin: MapCameraIntentOrigin.discovery,
      );

      expect(skyFall.yieldsToRunningAnimation, isFalse);
    });

    test('die Auto-Neigung ist die einzige, die weicht', () {
      // `screen-map.jsx:1761`, und sie gehört dem Host selbst, keinem Feature.
      const MapCameraOneShot autoPitch = MapCameraOneShot(
        change: MapCameraChange(pitch: 58),
        motion: MapCameraAnimated(Duration(milliseconds: 300)),
        origin: MapCameraIntentOrigin.mapHost,
        yieldsToRunningAnimation: true,
      );

      expect(autoPitch.yieldsToRunningAnimation, isTrue);
      expect(autoPitch.origin, MapCameraIntentOrigin.mapHost);
    });
  });

  group('Die Dauerabsicht trägt ihre eigenen Schwellen', () {
    test('ohne Angabe bremst sie sich nicht selbst', () {
      const MapCameraFollow follow = MapCameraFollow(
        kind: MapCameraFollowKind.userPosition,
        change: MapCameraChange(center: munich),
        motion: MapCameraAnimated(Duration(milliseconds: 900)),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: false,
      );

      expect(follow.deadZoneMeters, isNull);
      expect(follow.bearingDeadZoneDegrees, isNull);
      expect(follow.minPause, isNull);
    });

    test('die zwei Dauerabsichten sind sich auch bei der Geste uneinig', () {
      // Das Blickrichtungs-Folgen prüft `!userInteracting`
      // (`screen-map.jsx:2837`), `applyPos` prüft in `:2668` allein
      // `!m.isEasing()`. Ein Standardwert wäre für eine der beiden falsch.
      const MapCameraFollow gps = MapCameraFollow(
        kind: MapCameraFollowKind.userPosition,
        change: MapCameraChange(center: munich),
        motion: MapCameraAnimated(Duration(milliseconds: 900)),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: false,
        deadZoneMeters: 12,
        minPause: Duration(milliseconds: 800),
      );
      const MapCameraFollow bearing = MapCameraFollow(
        kind: MapCameraFollowKind.compassBearing,
        change: MapCameraChange(bearing: 90),
        motion: MapCameraImmediate(),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: true,
        bearingDeadZoneDegrees: 1.5,
      );

      expect(gps.yieldsToUserGesture, isFalse);
      expect(bearing.yieldsToUserGesture, isTrue);
    });

    test('die zwei Dauerabsichten der Quelle haben verschiedene Schwellen', () {
      // Genau deshalb sitzen die Schwellen an der Absicht und nicht am Gate.
      const MapCameraFollow gps = MapCameraFollow(
        kind: MapCameraFollowKind.userPosition,
        change: MapCameraChange(center: munich),
        motion: MapCameraAnimated(Duration(milliseconds: 900)),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: false,
        deadZoneMeters: 12,
        minPause: Duration(milliseconds: 800),
      );
      const MapCameraFollow bearing = MapCameraFollow(
        kind: MapCameraFollowKind.compassBearing,
        change: MapCameraChange(bearing: 90),
        motion: MapCameraImmediate(),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: true,
        bearingDeadZoneDegrees: 1.5,
      );

      expect(gps.deadZoneMeters, 12);
      expect(gps.minPause, const Duration(milliseconds: 800));
      expect(gps.bearingDeadZoneDegrees, isNull);
      expect(bearing.bearingDeadZoneDegrees, 1.5);
      expect(bearing.minPause, isNull);
      expect(bearing.deadZoneMeters, isNull);
    });
  });

  group('Die Identität einer Dauerabsicht', () {
    test('ist nicht die Herkunft', () {
      // **Der Grund, warum es dieses Feld gibt.** Beide Dauerabsichten der
      // Quelle kommen aus `discovery`. Wer den Zustand des Hosts nach der
      // Herkunft schlüsselt, gibt ihnen einen gemeinsamen Platz: die
      // Mindestpause des GPS-Folgens legte dann das Kompass-Folgen still, und
      // dessen Winkel-Totzone bremste den nächsten GPS-Fix.
      const MapCameraFollow gps = MapCameraFollow(
        kind: MapCameraFollowKind.userPosition,
        change: MapCameraChange(center: munich),
        motion: MapCameraAnimated(Duration(milliseconds: 900)),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: false,
      );
      const MapCameraFollow bearing = MapCameraFollow(
        kind: MapCameraFollowKind.compassBearing,
        change: MapCameraChange(bearing: 90),
        motion: MapCameraImmediate(),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: true,
      );

      expect(gps.origin, bearing.origin);
      expect(gps.kind, isNot(bearing.kind));
    });

    test('kennt genau die zwei Dauerabsichten, die es in der Quelle gibt', () {
      // Die Tour-Folgeabsicht der Phase 6 fehlt bewusst. Fällt dieser Test,
      // ist gerade jemand dabei, eine dritte hinzuzunehmen, und dann ist der
      // Zustand des Hosts je Sorte nachzuziehen.
      expect(MapCameraFollowKind.values, <MapCameraFollowKind>[
        MapCameraFollowKind.userPosition,
        MapCameraFollowKind.compassBearing,
      ]);
    });
  });

  group('Die Herkunft', () {
    test('drei Werte, jeder mit einer Kamerabewegung in der Quelle', () {
      // Kein Vorrat: `challenges` und `collection` fehlen, weil
      // `screen-map.jsx` keinen Kameraaufruf enthält, der ihnen gehört. Wer
      // einen Wert ergänzt, soll dabei auf diesen Test stoßen.
      expect(MapCameraIntentOrigin.values, hasLength(3));
      expect(
        MapCameraIntentOrigin.values,
        containsAll(<MapCameraIntentOrigin>[
          MapCameraIntentOrigin.discovery,
          MapCameraIntentOrigin.tours,
          MapCameraIntentOrigin.mapHost,
        ]),
      );
    });
  });

  group('Die Hierarchie ist versiegelt', () {
    test('ein switch über die drei Sorten ist vollständig', () {
      const List<MapCameraIntent> all = <MapCameraIntent>[
        MapCameraCommand(
          change: MapCameraChange(zoom: 15),
          motion: MapCameraImmediate(),
          origin: MapCameraIntentOrigin.discovery,
          releasesBearingLock: true,
          clearsFollowAnchor: true,
        ),
        MapCameraOneShot(
          change: MapCameraChange(zoom: 16.5),
          motion: MapCameraAnimated(Duration(milliseconds: 1200)),
          origin: MapCameraIntentOrigin.tours,
        ),
        MapCameraFollow(
          kind: MapCameraFollowKind.userPosition,
          change: MapCameraChange(center: munich),
          motion: MapCameraAnimated(Duration(milliseconds: 900)),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: false,
        ),
      ];

      final List<int> ranks = <int>[
        for (final MapCameraIntent intent in all)
          switch (intent) {
            MapCameraCommand() => 1,
            MapCameraOneShot() => 3,
            MapCameraFollow() => 4,
          },
      ];

      expect(ranks, <int>[1, 3, 4]);
    });
  });
}
