import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_gate.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Startpunkt aller Ortsrechnungen, `CITIES[0]` aus `screen-map.jsx:310`.
const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);

/// Meter je Grad Breite, unabhängig hergeleitet in `map_position_test.dart`.
const double metersPerDegreeLatitude = 111194.92664455873;

/// Ein Punkt [meters] Meter nördlich von [from].
///
/// Auf demselben Längengrad, damit die Strecke die reine Bogenlänge ist und
/// nicht vom Kosinus der Breite abhängt.
MapPosition northOf(MapPosition from, double meters) => MapPosition(
  latitude: from.latitude + meters / metersPerDegreeLatitude,
  longitude: from.longitude,
);

MapCameraView viewAt({
  MapPosition center = munich,
  double zoom = 15,
  double bearing = 0,
  double pitch = 0,
}) => MapCameraView(center: center, zoom: zoom, bearing: bearing, pitch: pitch);

/// Eine Lage ohne laufende Animation, ohne Einrasten, ohne Vorgeschichte.
MapCameraSituation calm({
  MapCameraView? view,
  Duration now = const Duration(seconds: 10),
  bool userIsGesturing = false,
}) => MapCameraSituation(
  view: view ?? viewAt(),
  now: now,
  userIsGesturing: userIsGesturing,
);

/// Eine Lage, in der eine eigene Animation von 200 bis 800 ms läuft.
MapCameraSituation animating({
  MapCameraView? view,
  Duration now = const Duration(milliseconds: 500),
  bool bearingLocked = false,
  Duration? lastUnexplainedMoveAt,
  Duration? lastFollowAt,
  MapPosition? lastFollowCenter,
}) => MapCameraSituation(
  view: view ?? viewAt(),
  now: now,
  animationStartedAt: const Duration(milliseconds: 200),
  animationEndsAt: const Duration(milliseconds: 800),
  bearingLocked: bearingLocked,
  lastUnexplainedMoveAt: lastUnexplainedMoveAt,
  lastFollowAt: lastFollowAt,
  lastFollowCenter: lastFollowCenter,
);

/// Der harte Reset am Kompass, `screen-map.jsx:3164-3170`.
MapCameraCommand hardReset({MapPosition center = munich}) => MapCameraCommand(
  change: MapCameraChange(center: center, bearing: 0, pitch: 30, zoom: 15),
  motion: const MapCameraImmediate(),
  origin: MapCameraIntentOrigin.discovery,
  releasesBearingLock: true,
  clearsFollowAnchor: true,
);

/// Der kurze Druck am Kompass, `screen-map.jsx:3180-3184`.
///
/// Löst das Einrasten, lässt den Anker der Strecken-Totzone aber stehen:
/// `recenter()` (`:2983-2987`) fasst `lastCameraPosRef` nicht an.
MapCameraCommand shortPress({MapPosition center = munich}) => MapCameraCommand(
  change: MapCameraChange(center: center, zoom: 15),
  motion: const MapCameraAnimated(Duration(milliseconds: 400)),
  origin: MapCameraIntentOrigin.discovery,
  releasesBearingLock: true,
  clearsFollowAnchor: false,
);

/// Die Auto-Neigung nach dem Zoomende, `screen-map.jsx:1755-1764`.
///
/// Die eine Einmal-Absicht der Quelle, die einer laufenden Animation weicht.
MapCameraOneShot autoPitch() => const MapCameraOneShot(
  change: MapCameraChange(pitch: 58),
  motion: MapCameraAnimated(Duration(milliseconds: 300)),
  origin: MapCameraIntentOrigin.mapHost,
  yieldsToRunningAnimation: true,
);

/// Das GPS-Folgen, `screen-map.jsx:2665-2675`.
MapCameraFollow gpsFollow(MapPosition target) => MapCameraFollow(
  kind: MapCameraFollowKind.userPosition,
  change: MapCameraChange(center: target),
  motion: const MapCameraAnimated(Duration(milliseconds: 900)),
  origin: MapCameraIntentOrigin.discovery,
  yieldsToUserGesture: false,
  deadZoneMeters: MapCameraThresholds.followDeadZoneMeters,
  minPause: MapCameraThresholds.followMinPause,
);

/// Das Folgen der Blickrichtung, `screen-map.jsx:2834-2839`.
///
/// Ohne Mindestpause: von den vier Bedingungen in `:2837` ist keine eine
/// Pause. Weicht dagegen einer laufenden Geste, das ist dort `!userInteracting`.
MapCameraFollow bearingFollow(double bearing) => MapCameraFollow(
  kind: MapCameraFollowKind.compassBearing,
  change: MapCameraChange(bearing: bearing),
  motion: const MapCameraImmediate(),
  origin: MapCameraIntentOrigin.discovery,
  yieldsToUserGesture: true,
  bearingDeadZoneDegrees: MapCameraThresholds.bearingDeadZoneDegrees,
);

void main() {
  group('Die Schwellwerte stehen so in der Quelle', () {
    test('12 Meter, 800 Millisekunden, 1,5 Grad', () {
      expect(MapCameraThresholds.followDeadZoneMeters, 12);
      expect(
        MapCameraThresholds.followMinPause,
        const Duration(milliseconds: 800),
      );
      expect(MapCameraThresholds.bearingDeadZoneDegrees, 1.5);
    });

    test('die Karenzzeit ist im Standard aus, das ist Lesart A', () {
      expect(const MapCameraThresholds().manualMoveGrace, Duration.zero);
    });
  });

  group('Vorrangregel 1: ein Nutzerbefehl bricht alles ab', () {
    test('er wird auch mitten in einer Animation ausgeführt', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: hardReset(),
        situation: animating(),
      );

      expect(verdict.isExecuted, isTrue);
      expect(verdict.reason, isNull);
      expect(verdict.interruptsRunningAnimation, isTrue);
    });

    test('ohne laufende Animation bricht er nichts ab', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: hardReset(),
        situation: calm(),
      );

      expect(verdict.isExecuted, isTrue);
      expect(verdict.interruptsRunningAnimation, isFalse);
    });

    test('eingerastete Blickrichtung hält ihn nicht auf', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: hardReset(),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          bearingLocked: true,
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });

    test('auch die Karenzzeit aus Lesart B hält ihn nicht auf', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: hardReset(),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          lastUnexplainedMoveAt: const Duration(seconds: 9),
        ),
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });
  });

  group('Vorrangregel 4: unter Einmal-Absichten gewinnt die letzte', () {
    test('eine Einmal-Absicht überschreibt eine laufende Animation', () {
      // Sechs der sieben Einmal-Absichten der Quelle tun das.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: const MapCameraOneShot(
          change: MapCameraChange(zoom: 16.5, pitch: 58),
          motion: MapCameraAnimated(Duration(milliseconds: 1200)),
          origin: MapCameraIntentOrigin.discovery,
        ),
        situation: animating(),
      );

      expect(verdict.isExecuted, isTrue);
      expect(verdict.interruptsRunningAnimation, isTrue);
    });

    test('zwei Einmal-Absichten hintereinander: beide werden ausgeführt', () {
      // Es gibt keine Warteschlange. Die erste läuft noch, die zweite kommt
      // trotzdem durch und meldet, dass sie die erste überschreibt.
      const MapCameraOneShot first = MapCameraOneShot(
        change: MapCameraChange(zoom: 15, pitch: 60),
        motion: MapCameraAnimated(Duration(milliseconds: 1500)),
        origin: MapCameraIntentOrigin.discovery,
      );
      const MapCameraOneShot second = MapCameraOneShot(
        change: MapCameraChange(zoom: 16.5, pitch: 58),
        motion: MapCameraAnimated(Duration(milliseconds: 1200)),
        origin: MapCameraIntentOrigin.discovery,
      );

      expect(
        decideMapCameraIntent(intent: first, situation: calm()).isExecuted,
        isTrue,
      );
      final MapCameraVerdict later = decideMapCameraIntent(
        intent: second,
        situation: animating(),
      );
      expect(later.isExecuted, isTrue);
      expect(later.interruptsRunningAnimation, isTrue);
    });

    test('die Auto-Neigung ist die eine, die einer Animation weicht', () {
      // `screen-map.jsx:1761`: `if (map.isEasing()) return;`
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: autoPitch(),
        situation: animating(),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.runningAnimation);
    });

    test('ohne laufende Animation läuft die Auto-Neigung durch', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: autoPitch(),
        situation: calm(),
      );

      expect(verdict.isExecuted, isTrue);
      expect(verdict.interruptsRunningAnimation, isFalse);
    });

    test('eine Einmal-Absicht kennt weder Totzone noch Karenzzeit', () {
      // Sie ist einmalig, es gibt nichts zu drosseln. Selbst mit
      // Vorgeschichte und eingerasteter Blickrichtung läuft sie durch.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: MapCameraOneShot(
          change: MapCameraChange(center: munich, bearing: 0),
          motion: const MapCameraAnimated(Duration(milliseconds: 400)),
          origin: MapCameraIntentOrigin.discovery,
        ),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          bearingLocked: true,
          lastUnexplainedMoveAt: const Duration(seconds: 10),
          lastFollowAt: const Duration(seconds: 10),
          lastFollowCenter: munich,
        ),
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });
  });

  group(
    'Vorrangregel 3: eine laufende Animation schlägt jede Dauerabsicht',
    () {
      test('das GPS-Folgen wird unterdrückt, mit Grund', () {
        final MapCameraVerdict verdict = decideMapCameraIntent(
          intent: gpsFollow(northOf(munich, 100)),
          situation: animating(),
        );

        expect(verdict.isExecuted, isFalse);
        expect(verdict.reason, MapCameraSuppressionReason.runningAnimation);
      });

      test('das Ende der Animation zählt schon als vorbei', () {
        // Eine Animation von 200 bis 800 ms ist bei genau 800 ms fertig.
        final MapCameraVerdict verdict = decideMapCameraIntent(
          intent: gpsFollow(northOf(munich, 100)),
          situation: animating(now: const Duration(milliseconds: 800)),
        );

        expect(verdict.isExecuted, isTrue);
      });

      test('eine Dauerabsicht überschreibt nie eine Animation', () {
        final MapCameraVerdict verdict = decideMapCameraIntent(
          intent: gpsFollow(northOf(munich, 100)),
          situation: calm(),
        );

        expect(verdict.interruptsRunningAnimation, isFalse);
      });
    },
  );

  group('Vorrangregel 2: die eingerastete Blickrichtung', () {
    test('hält eine Dauerabsicht auf, die die Blickrichtung ändert', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(90),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          bearingLocked: true,
        ),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.bearingLocked);
    });

    test('hält das GPS-Folgen nicht auf, das nur verschiebt', () {
      // In der Quelle prüft `applyPos` `manualBearingRef` gar nicht
      // (`screen-map.jsx:2668`). Wer die Karte dreht, bleibt trotzdem
      // zentriert.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 100)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          bearingLocked: true,
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });

    test(
      'eine Blickrichtung von 0 Grad zählt als Änderung, nicht als null',
      () {
        // Der Fallstrick von `MapCameraChange`: `0` ist gesetzt, `null` ist
        // „unverändert". Ein `if (bearing != null)` fällt darauf nicht herein,
        // ein `if (bearing != 0)` sehr wohl.
        final MapCameraVerdict verdict = decideMapCameraIntent(
          intent: bearingFollow(0),
          situation: MapCameraSituation(
            view: viewAt(bearing: 180),
            now: const Duration(seconds: 10),
            bearingLocked: true,
          ),
        );

        expect(verdict.reason, MapCameraSuppressionReason.bearingLocked);
      },
    );
  });

  group('Vorrangregel 2: die laufende Geste des Nutzers', () {
    // Der Nachbau von `userInteracting` (`screen-map.jsx:2807`, gesetzt in
    // `:2810-2814`, benutzt in `:2837`). Ein eigener Eingang neben der
    // Karenzzeit, weil beide zwei verschiedene Dinge messen.

    test('das Blickrichtungs-Folgen schweigt, solange die Geste läuft', () {
      // `:2833-2834`: „Without this, 60Hz setBearing interrupts user gestures
      // and blocks pinch-zoom-out."
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(90),
        situation: calm(userIsGesturing: true),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.userGesture);
    });

    test('das GPS-Folgen läuft während derselben Geste weiter', () {
      // `applyPos` prüft in `:2668` allein `!m.isEasing()`. `userInteracting`
      // ist dort gar nicht erreichbar. Genau deshalb hat
      // `yieldsToUserGesture` keinen Standardwert.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 100)),
        situation: calm(userIsGesturing: true),
      );

      expect(verdict.isExecuted, isTrue);
      expect(verdict.reason, isNull);
    });

    test('nach dem Loslassen folgt beides wieder', () {
      expect(
        decideMapCameraIntent(
          intent: bearingFollow(90),
          situation: calm(),
        ).isExecuted,
        isTrue,
      );
      expect(
        decideMapCameraIntent(
          intent: gpsFollow(northOf(munich, 100)),
          situation: calm(),
        ).isExecuted,
        isTrue,
      );
    });

    test('Gestenzustand und Karenzzeit wirken unabhängig voneinander', () {
      // Karenzzeit auf null, also Lesart A, in der die Karenzzeit nie feuert.
      // Die Geste unterdrückt trotzdem, und zwar mit ihrem eigenen Grund. Ein
      // Karenzzeitfenster ist kein Gestenzustand.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(90),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          userIsGesturing: true,
          lastUnexplainedMoveAt: const Duration(seconds: 9),
        ),
        thresholds: const MapCameraThresholds(),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.userGesture);
    });

    test('und umgekehrt: ohne Geste greift allein die Karenzzeit', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 100)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 61),
          lastUnexplainedMoveAt: const Duration(seconds: 60),
        ),
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.manualMoveGrace);
    });

    test('eine Geste hält weder Befehl noch Einmal-Absicht auf', () {
      expect(
        decideMapCameraIntent(
          intent: hardReset(),
          situation: calm(userIsGesturing: true),
        ).isExecuted,
        isTrue,
      );
      expect(
        decideMapCameraIntent(
          intent: autoPitch(),
          situation: calm(userIsGesturing: true),
        ).isExecuted,
        isTrue,
      );
    });

    test('die laufende Animation wird vor der Geste gemeldet', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(90),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(milliseconds: 500),
          animationStartedAt: const Duration(milliseconds: 200),
          animationEndsAt: const Duration(milliseconds: 800),
          userIsGesturing: true,
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.runningAnimation);
    });

    test('die Geste wird vor dem Einrasten gemeldet', () {
      // Dieselbe Reihenfolge wie in `:2837`: erst `!userInteracting`, dann
      // `!manualBearingRef.current`.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(90),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          userIsGesturing: true,
          bearingLocked: true,
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.userGesture);
    });
  });

  group('Das Gate liest die Schwellen der Absicht, nicht die Konstanten', () {
    test('eine Winkel-Totzone von 5 Grad unterdrückt eine Drehung um 3', () {
      // Läse das Gate `MapCameraThresholds.bearingDeadZoneDegrees`, wären 3
      // Grad über der Schwelle und die Absicht liefe durch.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: const MapCameraFollow(
          kind: MapCameraFollowKind.compassBearing,
          change: MapCameraChange(bearing: 3),
          motion: MapCameraImmediate(),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: true,
          bearingDeadZoneDegrees: 5,
        ),
        situation: calm(),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.bearingDeadZone);
    });

    test('eine Mindestpause von 2000 ms unterdrückt nach 1000 ms', () {
      // Mit der Konstanten von 800 ms wäre die Pause längst um.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: MapCameraFollow(
          kind: MapCameraFollowKind.userPosition,
          change: MapCameraChange(center: northOf(munich, 100)),
          motion: const MapCameraAnimated(Duration(milliseconds: 900)),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: false,
          minPause: const Duration(milliseconds: 2000),
        ),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 61),
          lastFollowAt: const Duration(seconds: 60),
        ),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.minPause);
    });

    test('eine Strecken-Totzone von 100 Metern unterdrückt 50 Meter', () {
      // Mit der Konstanten von 12 Metern liefe die Absicht durch.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: MapCameraFollow(
          kind: MapCameraFollowKind.userPosition,
          change: MapCameraChange(center: northOf(munich, 50)),
          motion: const MapCameraAnimated(Duration(milliseconds: 900)),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: false,
          deadZoneMeters: 100,
        ),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          lastFollowCenter: munich,
        ),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.distanceDeadZone);
    });
  });

  group('Eine Dauerabsicht ohne Schwellen bremst sich nicht selbst', () {
    // Die Tour-Folgeabsicht aus Phase 6 ist genau so eine Absicht.
    MapCameraFollow unthrottled(MapPosition target) => MapCameraFollow(
      kind: MapCameraFollowKind.userPosition,
      change: MapCameraChange(center: target),
      motion: const MapCameraAnimated(Duration(milliseconds: 600)),
      origin: MapCameraIntentOrigin.tours,
      yieldsToUserGesture: false,
    );

    test('mit Mittelpunkt, aber ohne Strecken-Totzone: ein Meter reicht', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: unthrottled(northOf(munich, 1)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          lastFollowCenter: munich,
        ),
      );

      expect(verdict.isExecuted, isTrue);
      expect(verdict.reason, isNull);
    });

    test('auch bei identischem Mittelpunkt', () {
      // Strecke null, und trotzdem ausgeführt: ohne Schwelle wird nicht
      // gemessen. Wer hier mit `?? double.infinity` rechnet, unterdrückt
      // stumm.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: unthrottled(munich),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          lastFollowCenter: munich,
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });

    test('ohne Winkel-Totzone und ohne Pause ebenso', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: const MapCameraFollow(
          kind: MapCameraFollowKind.compassBearing,
          change: MapCameraChange(bearing: 0),
          motion: MapCameraImmediate(),
          origin: MapCameraIntentOrigin.tours,
          yieldsToUserGesture: false,
        ),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 60),
          lastFollowAt: const Duration(seconds: 60),
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });
  });

  group('Die Strecken-Totzone des GPS-Folgens', () {
    test('genau 12 Meter werden unterdrückt, die Quelle schreibt „> 12"', () {
      // Ein Versatz von exakt 12,000000 Metern lässt sich in
      // Gleitkommazahlen nicht konstruieren. Geprüft wird deshalb gegen die
      // **gemessene** Strecke: liegt die Schwelle genau darauf, muss
      // unterdrückt werden. Das ist die Frage, um die es geht, `>` oder `>=`.
      final MapPosition target = northOf(munich, 12);
      final double measured = munich.distanceInMetersTo(target);
      expect(measured, closeTo(12, 1e-6));

      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: MapCameraFollow(
          kind: MapCameraFollowKind.userPosition,
          change: MapCameraChange(center: target),
          motion: const MapCameraAnimated(Duration(milliseconds: 900)),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: false,
          deadZoneMeters: measured,
        ),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          lastFollowCenter: munich,
        ),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.distanceDeadZone);
    });

    test('einen Millimeter über der Schwelle wird ausgeführt', () {
      final MapPosition target = northOf(munich, 12);
      final double measured = munich.distanceInMetersTo(target);

      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: MapCameraFollow(
          kind: MapCameraFollowKind.userPosition,
          change: MapCameraChange(center: target),
          motion: const MapCameraAnimated(Duration(milliseconds: 900)),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: false,
          deadZoneMeters: measured - 0.001,
        ),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          lastFollowCenter: munich,
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });

    test('elf Meter bleiben unter der 12-Meter-Schwelle der Quelle', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 11)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          lastFollowCenter: munich,
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.distanceDeadZone);
    });

    test('dreizehn Meter überschreiten sie', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 13)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 10),
          lastFollowCenter: munich,
        ),
      );

      expect(verdict.isExecuted, isTrue);
      // Auch mit gesetztem Anker bricht eine Dauerabsicht nichts ab. Ohne
      // diese Zeile wäre „überschreibt nie eine Animation" nur in der einen
      // Lage geprüft, in der der Anker ohnehin `null` ist.
      expect(verdict.interruptsRunningAnimation, isFalse);
    });

    test('ohne vorherige Ausführung greift die Totzone nicht', () {
      // Die Quelle rechnet dann mit `Infinity` (`screen-map.jsx:2660-2662`).
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 1)),
        situation: calm(),
      );

      expect(verdict.isExecuted, isTrue);
    });

    test(
      'gemessen wird gegen die letzte Ausführung, nicht gegen die Mitte',
      () {
        // Der Nutzer hat die Karte weit weggeschoben, das GPS ist aber kaum
        // gewandert. Die Quelle hält dafür `lastCameraPosRef` und nicht
        // `map.getCenter()`; ohne diese Unterscheidung setzte jedes Verschieben
        // die Totzone zurück.
        final MapCameraVerdict verdict = decideMapCameraIntent(
          intent: gpsFollow(northOf(munich, 1)),
          situation: MapCameraSituation(
            view: viewAt(center: northOf(munich, 5000)),
            now: const Duration(seconds: 10),
            lastFollowCenter: munich,
          ),
        );

        expect(verdict.reason, MapCameraSuppressionReason.distanceDeadZone);
      },
    );
  });

  group('Die Mindestpause des GPS-Folgens', () {
    MapCameraVerdict after(Duration elapsed) => decideMapCameraIntent(
      intent: gpsFollow(northOf(munich, 100)),
      situation: MapCameraSituation(
        view: viewAt(),
        now: const Duration(seconds: 60) + elapsed,
        lastFollowAt: const Duration(seconds: 60),
        lastFollowCenter: munich,
      ),
    );

    test('genau 800 ms werden unterdrückt, die Quelle schreibt „> 800"', () {
      final MapCameraVerdict verdict = after(const Duration(milliseconds: 800));

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.minPause);
    });

    test('eine Mikrosekunde darüber wird ausgeführt', () {
      final MapCameraVerdict verdict = after(
        const Duration(milliseconds: 800, microseconds: 1),
      );

      expect(verdict.isExecuted, isTrue);
    });

    test('799 ms werden unterdrückt', () {
      expect(
        after(const Duration(milliseconds: 799)).reason,
        MapCameraSuppressionReason.minPause,
      );
    });

    test('das Folgen der Blickrichtung hat gar keine Pause', () {
      // `screen-map.jsx:2837` prüft vier Bedingungen: `!isEasing()`,
      // `!userInteracting`, `!manualBearingRef` und die Winkel-Totzone. Keine
      // davon ist eine Mindestpause.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(90),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 60),
          lastFollowAt: const Duration(seconds: 60),
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });
  });

  group('Die Winkel-Totzone rechnet über den kurzen Weg', () {
    MapCameraVerdict turnFrom(double current, double target) =>
        decideMapCameraIntent(
          intent: bearingFollow(target),
          situation: calm(view: viewAt(bearing: current)),
        );

    test('genau 1,5 Grad werden unterdrückt, die Quelle schreibt „> 1.5"', () {
      final MapCameraVerdict verdict = turnFrom(0, 1.5);

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.bearingDeadZone);
    });

    test('1,6 Grad werden ausgeführt', () {
      expect(turnFrom(0, 1.6).isExecuted, isTrue);
    });

    test('von 359 auf 1 Grad sind zwei Grad, nicht 358', () {
      expect(turnFrom(359, 1).isExecuted, isTrue);
    });

    test('von 1 auf 359 Grad sind ebenfalls zwei Grad', () {
      expect(turnFrom(1, 359).isExecuted, isTrue);
    });

    test('von 359 auf 0,5 Grad sind genau 1,5 und damit zu wenig', () {
      expect(
        turnFrom(359, 0.5).reason,
        MapCameraSuppressionReason.bearingDeadZone,
      );
    });

    test('von 0,5 auf 359 Grad ebenso', () {
      expect(
        turnFrom(0.5, 359).reason,
        MapCameraSuppressionReason.bearingDeadZone,
      );
    });
  });

  group('Nach dem harten Reset folgt der Kompass sofort wieder', () {
    test('eine Absicht auf 90 Grad wird ausgeführt, obwohl die Karte gerade '
        'von 90 auf 0 gesprungen ist', () {
      // **Bewusste Abweichung von der Quelle, und dieser Test ist der Beleg,
      // dass sie gewollt ist.**
      //
      // Die Quelle misst die Winkel-Totzone gegen `lastAppliedBearing`
      // (`screen-map.jsx:2836`), einen Wert, der allein im Erfolgszweig des
      // Folgens fortgeschrieben wird (`:2839`). Der lange Kompassdruck setzt
      // `manualBearingRef = false` (`:3166`) und springt mit `jumpTo` auf
      // Norden (`:3168`), ohne ihn anzufassen. Er steht danach noch auf 90,
      // während die Karte auf 0 zeigt: die Quelle unterdrückt die nächste
      // Peilung von ~90 Grad und bleibt auf Nord stehen, obwohl derselbe Druck
      // das Folgen gerade wieder eingeschaltet hat. Ein Defekt, kein Vorbild.
      //
      // Hier wird gegen die echte Kartenausrichtung gemessen, die per
      // Konstruktion nicht veralten kann.

      // 1. Der Kompass hat die Karte zuletzt auf 90 Grad gedreht.
      expect(
        decideMapCameraIntent(
          intent: bearingFollow(90),
          situation: calm(view: viewAt(bearing: 0)),
        ).isExecuted,
        isTrue,
      );

      // 2. Langer Druck: Sprung auf Nord, Einrasten gelöst, Anker geleert.
      final MapCameraCommand reset = hardReset();
      expect(
        decideMapCameraIntent(
          intent: reset,
          situation: calm(view: viewAt(bearing: 90)),
        ).isExecuted,
        isTrue,
      );
      expect(releasesBearingLock(reset), isTrue);
      expect(clearsFollowAnchor(reset), isTrue);

      // 3. Nächstes Kompassereignis, wieder ~90 Grad. Die Karte steht auf 0.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(90),
        situation: calm(view: viewAt(bearing: 0)),
      );

      expect(verdict.isExecuted, isTrue);
      expect(verdict.reason, isNull);
    });

    test('nach dem harten Reset bremst auch die Strecken-Totzone nicht', () {
      // `:3165` setzt `lastCameraPosRef.current = null`. Der Host, der
      // `clearsFollowAnchor` befolgt, gibt danach `lastFollowCenter: null`
      // weiter, und die Quelle rechnet dort mit `Infinity` (`:2660-2662`).
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 1)),
        situation: calm(),
      );

      expect(verdict.isExecuted, isTrue);
    });
  });

  group('Beide Lesarten von Vorrangregel 2', () {
    MapCameraVerdict walkAfterPan(MapCameraThresholds thresholds) =>
        decideMapCameraIntent(
          intent: gpsFollow(northOf(munich, 20)),
          situation: MapCameraSituation(
            view: viewAt(),
            now: const Duration(seconds: 61),
            lastUnexplainedMoveAt: const Duration(seconds: 60),
            lastFollowCenter: munich,
          ),
          thresholds: thresholds,
        );

    test('Lesart A, der Standard: die Karte reißt zurück', () {
      // Quellentreu. `userInteracting` ist in der PWA für `applyPos` nicht
      // erreichbar (`screen-map.jsx:2807`), das GPS-Folgen prüft nur
      // `!isEasing()` (`:2668`).
      expect(walkAfterPan(const MapCameraThresholds()).isExecuted, isTrue);
    });

    test('Lesart B: die Karte lässt den Nutzer in Ruhe', () {
      final MapCameraVerdict verdict = walkAfterPan(
        const MapCameraThresholds(manualMoveGrace: Duration(seconds: 5)),
      );

      expect(verdict.isExecuted, isFalse);
      expect(verdict.reason, MapCameraSuppressionReason.manualMoveGrace);
    });

    test('Lesart B endet mit dem Ablauf der Karenzzeit, auf die Sekunde', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 20)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 65),
          lastUnexplainedMoveAt: const Duration(seconds: 60),
          lastFollowCenter: munich,
        ),
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });

    test('ohne unerklärte Bewegung greift auch Lesart B nicht', () {
      // `lastFollowAt` steht hier bewusst mit drin, und zwar innerhalb der
      // Karenzzeit: die Karenzzeit misst gegen die unerklärte Bewegung und
      // darf nicht auf den Zeitpunkt der letzten Ausführung zurückfallen.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 20)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 61),
          lastFollowAt: const Duration(seconds: 60),
          lastFollowCenter: munich,
        ),
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });
  });

  group('Bei mehreren Gründen gilt die festgeschriebene Reihenfolge', () {
    test('Animation schlägt Einrasten, Karenzzeit und Totzone', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: MapCameraFollow(
          kind: MapCameraFollowKind.compassBearing,
          change: MapCameraChange(center: munich, bearing: 0),
          motion: const MapCameraAnimated(Duration(milliseconds: 900)),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: true,
          deadZoneMeters: MapCameraThresholds.followDeadZoneMeters,
          bearingDeadZoneDegrees: MapCameraThresholds.bearingDeadZoneDegrees,
          minPause: MapCameraThresholds.followMinPause,
        ),
        situation: animating(
          bearingLocked: true,
          lastUnexplainedMoveAt: const Duration(milliseconds: 500),
          lastFollowAt: const Duration(milliseconds: 500),
          lastFollowCenter: munich,
        ),
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.runningAnimation);
    });

    test('Einrasten schlägt die Karenzzeit', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(90),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 61),
          bearingLocked: true,
          lastUnexplainedMoveAt: const Duration(seconds: 60),
        ),
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.bearingLocked);
    });

    test('die Karenzzeit schlägt die Totzone', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 1)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 61),
          lastUnexplainedMoveAt: const Duration(seconds: 60),
          lastFollowAt: const Duration(seconds: 60),
          lastFollowCenter: munich,
        ),
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.manualMoveGrace);
    });

    test('die Strecken-Totzone schlägt die Winkel-Totzone', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: MapCameraFollow(
          kind: MapCameraFollowKind.compassBearing,
          change: MapCameraChange(center: northOf(munich, 1), bearing: 0.5),
          motion: const MapCameraAnimated(Duration(milliseconds: 900)),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: false,
          deadZoneMeters: MapCameraThresholds.followDeadZoneMeters,
          bearingDeadZoneDegrees: MapCameraThresholds.bearingDeadZoneDegrees,
        ),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 61),
          lastFollowCenter: munich,
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.distanceDeadZone);
    });

    test('die Winkel-Totzone schlägt die Mindestpause', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: MapCameraFollow(
          kind: MapCameraFollowKind.compassBearing,
          change: const MapCameraChange(bearing: 0.5),
          motion: const MapCameraImmediate(),
          origin: MapCameraIntentOrigin.discovery,
          yieldsToUserGesture: false,
          bearingDeadZoneDegrees: MapCameraThresholds.bearingDeadZoneDegrees,
          minPause: MapCameraThresholds.followMinPause,
        ),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(seconds: 60, milliseconds: 100),
          lastFollowAt: const Duration(seconds: 60),
        ),
      );

      expect(verdict.reason, MapCameraSuppressionReason.bearingDeadZone);
    });
  });

  group('Das Einrasten der Blickrichtung', () {
    test('eine Drehung durch den Nutzer rastet ein', () {
      expect(
        isManualBearingChange(
          previousBearing: 0,
          newBearing: 40,
          hostIsSteering: false,
        ),
        isTrue,
      );
    });

    test('eine Drehung durch den Host rastet NICHT ein', () {
      // **Der wertvollste Test dieses Blocks.** Genau hier lag der Fehler in
      // der Quelle: ohne den `e.originalEvent`-Wächter (`screen-map.jsx:1692`)
      // schaltete das Folgen der Blickrichtung sich nach dem ersten eigenen
      // `setBearing` selbst ab. Die Karte drehte sich einmal und fror ein.
      expect(
        isManualBearingChange(
          previousBearing: 0,
          newBearing: 40,
          hostIsSteering: true,
        ),
        isFalse,
      );
    });

    test('auch eine sehr große Drehung des Hosts rastet nicht ein', () {
      expect(
        isManualBearingChange(
          previousBearing: 0,
          newBearing: 179,
          hostIsSteering: true,
        ),
        isFalse,
      );
    });

    test('das Einrasten hat eine eigene Schwelle, nicht die des Kompasses', () {
      // Zwei Fragen, zwei Zahlen. Hingen sie an einem Wert, änderte eine
      // Anpassung der Kompass-Totzone stillschweigend das Einrasten mit. Die
      // Quelle hat für das Einrasten überhaupt keine Schwelle
      // (`screen-map.jsx:1692` fragt nur `e.originalEvent`).
      expect(
        MapCameraThresholds.manualBearingNoiseDegrees,
        isNot(MapCameraThresholds.bearingDeadZoneDegrees),
      );
      expect(MapCameraThresholds.manualBearingNoiseDegrees, 0.25);
    });

    test('genau 0,25 Grad rasten nicht ein', () {
      expect(
        isManualBearingChange(
          previousBearing: 0,
          newBearing: 0.25,
          hostIsSteering: false,
        ),
        isFalse,
      );
    });

    test('0,3 Grad rasten ein', () {
      expect(
        isManualBearingChange(
          previousBearing: 0,
          newBearing: 0.3,
          hostIsSteering: false,
        ),
        isTrue,
      );
    });

    test('eine Grad-Drehung rastet ein, obwohl sie unter 1,5 liegt', () {
      // Der Beleg, dass hier nicht die Kompass-Totzone gilt: mit 1,5 Grad
      // bliebe diese Drehung folgenlos.
      expect(
        isManualBearingChange(
          previousBearing: 0,
          newBearing: 1,
          hostIsSteering: false,
        ),
        isTrue,
      );
    });

    test('eine eigene Schwelle lässt sich übergeben', () {
      expect(
        isManualBearingChange(
          previousBearing: 0,
          newBearing: 1,
          hostIsSteering: false,
          deadZoneDegrees: 5,
        ),
        isFalse,
      );
    });

    test('über die Datumsgrenze: 359 auf 1 sind zwei Grad und rasten ein', () {
      expect(
        isManualBearingChange(
          previousBearing: 359,
          newBearing: 1,
          hostIsSteering: false,
        ),
        isTrue,
      );
    });

    test('und andersherum: 1 auf 359 ebenso', () {
      expect(
        isManualBearingChange(
          previousBearing: 1,
          newBearing: 359,
          hostIsSteering: false,
        ),
        isTrue,
      );
    });

    test('über die Grenze hinweg: 359,75 auf 0 sind genau 0,25 Grad', () {
      expect(
        isManualBearingChange(
          previousBearing: 359.75,
          newBearing: 0,
          hostIsSteering: false,
        ),
        isFalse,
      );
    });
  });

  group('Gelöst wird das Einrasten nur vom Kompassknopf', () {
    test('der lange Druck löst es', () {
      expect(releasesBearingLock(hardReset()), isTrue);
    });

    test('der kurze Druck löst es', () {
      // `screen-map.jsx:3182-3183`: erst `manualBearingRef = false`, dann
      // `recenter()`.
      expect(releasesBearingLock(shortPress()), isTrue);
    });

    test('ein Befehl, der es nicht sagt, löst es nicht', () {
      expect(
        releasesBearingLock(
          const MapCameraCommand(
            change: MapCameraChange(zoom: 15),
            motion: MapCameraImmediate(),
            origin: MapCameraIntentOrigin.discovery,
            releasesBearingLock: false,
            clearsFollowAnchor: false,
          ),
        ),
        isFalse,
      );
    });

    test('keine Einmal-Absicht löst es, auch nicht der Sky-Fall', () {
      expect(
        releasesBearingLock(
          const MapCameraOneShot(
            change: MapCameraChange(zoom: 16.5, pitch: 58, bearing: 0),
            motion: MapCameraAnimated(Duration(milliseconds: 1200)),
            origin: MapCameraIntentOrigin.discovery,
          ),
        ),
        isFalse,
      );
    });

    test('keine Dauerabsicht löst es', () {
      expect(releasesBearingLock(bearingFollow(90)), isFalse);
    });
  });

  group('Die Winkelfunktion selbst', () {
    test('null Grad Unterschied', () {
      expect(shortestBearingDeltaDegrees(90, 90), 0);
    });

    test('positiv heißt im Uhrzeigersinn', () {
      expect(shortestBearingDeltaDegrees(0, 90), 90);
    });

    test('negativ heißt gegen den Uhrzeigersinn', () {
      expect(shortestBearingDeltaDegrees(90, 0), -90);
    });

    test('359 auf 1 ergibt +2, nicht -358', () {
      expect(shortestBearingDeltaDegrees(359, 1), closeTo(2, 1e-9));
    });

    test('1 auf 359 ergibt -2, nicht +358', () {
      expect(shortestBearingDeltaDegrees(1, 359), closeTo(-2, 1e-9));
    });

    test('der gegenüberliegende Winkel liegt am unteren Rand des Bereichs', () {
      // Der Bereich ist `[-180, 180)`. 180 Grad Unterschied ist der einzige
      // Fall, in dem die Drehrichtung nicht bestimmt ist, und er fällt auf
      // -180. Der Betrag ist 180, und darauf kommt es an beiden Aufrufstellen
      // an.
      expect(shortestBearingDeltaDegrees(0, 180), -180);
      expect(shortestBearingDeltaDegrees(0, 180).abs(), 180);
    });
  });

  group('MapCameraSituation.isAnimating', () {
    test('ohne Start und Ende läuft nichts', () {
      expect(calm().isAnimating, isFalse);
    });

    test('ein Start ohne geplantes Ende zählt nicht als laufend', () {
      // **Der gefährlichere der beiden Halbfälle, und kein konstruierter.**
      // `animateCamera` liefert auf iOS sofort `null` (`maplibre_gl 0.26.2`,
      // `lib/src/controller.dart:416`). Ein Host, der die Startzeit kennt und
      // die Dauer nicht, landet genau hier. Gälte das als „läuft ewig", fröre
      // ab diesem Moment jede Dauerabsicht dauerhaft ein.
      const MapCameraSituation situation = MapCameraSituation(
        view: MapCameraView(center: munich, zoom: 15, bearing: 0, pitch: 0),
        now: Duration(milliseconds: 500),
        animationStartedAt: Duration(milliseconds: 200),
      );

      expect(situation.isAnimating, isFalse);
    });

    test('und die Dauerabsicht läuft dann auch wirklich durch', () {
      // Der Beleg am Gate statt nur am Getter: hier zeigt sich das Einfrieren.
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: gpsFollow(northOf(munich, 100)),
        situation: MapCameraSituation(
          view: viewAt(),
          now: const Duration(milliseconds: 500),
          animationStartedAt: const Duration(milliseconds: 200),
        ),
      );

      expect(verdict.isExecuted, isTrue);
    });

    test('nur ein Ende ohne Start zählt nicht', () {
      const MapCameraSituation situation = MapCameraSituation(
        view: MapCameraView(center: munich, zoom: 15, bearing: 0, pitch: 0),
        now: Duration(milliseconds: 500),
        animationEndsAt: Duration(milliseconds: 800),
      );

      expect(situation.isAnimating, isFalse);
    });

    test('am Start läuft sie, am geplanten Ende nicht mehr', () {
      expect(
        animating(now: const Duration(milliseconds: 200)).isAnimating,
        isTrue,
      );
      expect(
        animating(now: const Duration(milliseconds: 799)).isAnimating,
        isTrue,
      );
      expect(
        animating(now: const Duration(milliseconds: 800)).isAnimating,
        isFalse,
      );
    });

    test('vor dem Start läuft sie noch nicht', () {
      expect(
        animating(now: const Duration(milliseconds: 199)).isAnimating,
        isFalse,
      );
    });
  });

  group('Die Schwellwerte als Wert', () {
    test('zwei zur Laufzeit gebaute Schwellwerte mit gleicher Karenzzeit', () {
      // Ohne `const`, sonst kanonisiert Dart beide zu demselben Objekt.
      final MapCameraThresholds left = MapCameraThresholds(
        manualMoveGrace: Duration(seconds: int.parse('5')),
      );
      final MapCameraThresholds right = MapCameraThresholds(
        manualMoveGrace: Duration(seconds: int.parse('5')),
      );

      expect(identical(left, right), isFalse);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('die Karenzzeit zählt für die Gleichheit', () {
      // Das einzige Instanzfeld. Ein `==`, das es übergeht, machte Lesart A
      // und Lesart B ununterscheidbar.
      expect(
        const MapCameraThresholds(manualMoveGrace: Duration(seconds: 5)),
        isNot(const MapCameraThresholds()),
      );
      expect(
        const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 5),
        ).hashCode,
        isNot(const MapCameraThresholds().hashCode),
      );
    });

    test('ein Schwellwertsatz ist nichts anderes', () {
      expect(const MapCameraThresholds(), isNot(Duration.zero));
    });

    test('die Textausgabe nennt die Karenzzeit', () {
      final String text = const MapCameraThresholds(
        manualMoveGrace: Duration(seconds: 5),
      ).toString();

      expect(text, contains('manualMoveGrace'));
      expect(text, contains('0:00:05.000000'));
    });
  });

  group('Geleert wird der Anker der Strecken-Totzone nur vom langen Druck', () {
    test('der lange Druck leert ihn', () {
      // `screen-map.jsx:3165`: `lastCameraPosRef.current = null`.
      expect(clearsFollowAnchor(hardReset()), isTrue);
    });

    test('der kurze Druck leert ihn nicht', () {
      // `:3182-3183` setzt nur `manualBearingRef = false` und ruft
      // `recenter()` (`:2983-2987`), das den Anker nicht anfasst. Die zwei
      // Befehle sind sich hier uneinig, deshalb gibt es keinen Standardwert.
      expect(clearsFollowAnchor(shortPress()), isFalse);
      expect(releasesBearingLock(shortPress()), isTrue);
    });

    test('keine Einmal-Absicht leert ihn', () {
      expect(clearsFollowAnchor(autoPitch()), isFalse);
    });

    test('keine Dauerabsicht leert ihn', () {
      expect(clearsFollowAnchor(gpsFollow(northOf(munich, 100))), isFalse);
    });
  });

  group('Blickrichtungen außerhalb von [0, 360)', () {
    test('negative Werte rechnen richtig', () {
      expect(shortestBearingDeltaDegrees(-10, 0), 10);
      expect(shortestBearingDeltaDegrees(0, -10), -10);
    });

    test('Werte über 360 Grad rechnen richtig', () {
      expect(shortestBearingDeltaDegrees(0, 370), 10);
      expect(shortestBearingDeltaDegrees(370, 0), -10);
    });

    test('auch weit außerhalb, wo die JavaScript-Fassung falsch läge', () {
      // JavaScript rechnet `(-460) % 360 = -100` und käme auf -280 Grad.
      // Darts `%` liefert bei positivem Divisor nie ein negatives Ergebnis:
      // `260 - 180 = 80`, und 1000 Grad entsprechen 280 Grad.
      expect(shortestBearingDeltaDegrees(1000, 0), 80);
    });

    test('eine negative Blickrichtung rastet genauso ein', () {
      expect(
        isManualBearingChange(
          previousBearing: -1,
          newBearing: 0,
          hostIsSteering: false,
        ),
        isTrue,
      );
      expect(
        isManualBearingChange(
          previousBearing: -0.25,
          newBearing: 0,
          hostIsSteering: false,
        ),
        isFalse,
      );
    });

    test('und das Gate misst auch dort gegen die Kartenausrichtung', () {
      final MapCameraVerdict verdict = decideMapCameraIntent(
        intent: bearingFollow(0),
        situation: calm(view: viewAt(bearing: -1)),
      );

      expect(verdict.reason, MapCameraSuppressionReason.bearingDeadZone);
    });
  });

  group('Das Urteil selbst', () {
    test('ausführen trägt keinen Grund, unterdrücken immer einen', () {
      const MapCameraVerdict executed = MapCameraVerdict.execute(
        interruptsRunningAnimation: false,
      );
      const MapCameraVerdict suppressed = MapCameraVerdict.suppressed(
        MapCameraSuppressionReason.minPause,
      );

      expect(executed.isExecuted, isTrue);
      expect(executed.reason, isNull);
      expect(suppressed.isExecuted, isFalse);
      expect(suppressed.reason, MapCameraSuppressionReason.minPause);
      expect(suppressed.interruptsRunningAnimation, isFalse);
    });

    test(
      'zwei zur Laufzeit gebaute Urteile mit gleichem Inhalt sind gleich',
      () {
        // Ohne `const`, sonst kanonisiert Dart beide zu demselben Objekt und
        // der Vergleich prüft nichts.
        final MapCameraVerdict left = MapCameraVerdict.execute(
          interruptsRunningAnimation: <bool>[true].first,
        );
        final MapCameraVerdict right = MapCameraVerdict.execute(
          interruptsRunningAnimation: <bool>[true].last,
        );

        expect(identical(left, right), isFalse);
        expect(left, right);
        expect(left.hashCode, right.hashCode);
        expect(
          left,
          isNot(
            const MapCameraVerdict.execute(interruptsRunningAnimation: false),
          ),
        );
      },
    );

    test('der Grund steht in der Textausgabe', () {
      expect(
        const MapCameraVerdict.suppressed(
          MapCameraSuppressionReason.bearingLocked,
        ).toString(),
        contains('bearingLocked'),
      );
    });
  });
}
