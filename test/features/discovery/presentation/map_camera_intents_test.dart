import 'package:fact_app/features/discovery/presentation/map_camera_intents.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_gate.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die vier Kameraabsichten des Kartenbildschirms gegen ihre Fundstellen.
///
/// Geprüft wird nicht „irgendeine Absicht entsteht", sondern jede Zahl und
/// jeder Rang einzeln. Der Rang ist dabei die Zusicherung mit der größten
/// Reichweite: ob eine Geste ein Nutzerbefehl ist, entscheidet, ob sie eine
/// laufende Animation abbricht und ob sie das Einrasten der Blickrichtung
/// löst.
void main() {
  const MapPosition target = MapPosition(latitude: 48.1351, longitude: 11.582);

  group('Sky-Fall, screen-map.jsx:1731-1739', () {
    test('setzt alle vier Felder der Kamera', () {
      final intent = skyFallIntent(target);

      expect(intent.change.center, target);
      expect(intent.change.zoom, 16.5);
      expect(intent.change.pitch, 58, reason: 'nicht 65 und nicht 75');
      expect(
        intent.change.bearing,
        0,
        reason:
            'die Quelle schreibt bearing: 0; ein weggelassenes Feld hieße '
            '"Blickrichtung behalten" und drehte die Karte nicht nach Norden',
      );
    });

    test('ist eine Einmal-Absicht, die einer Animation nicht weicht', () {
      final intent = skyFallIntent(target);

      expect(intent, isA<MapCameraOneShot>());
      expect(intent.rank, 3);
      expect(intent.yieldsToRunningAnimation, isFalse);
      expect(intent.origin, MapCameraIntentOrigin.discovery);
    });

    test('animiert, und die Dauer ist der eine Schätzwert', () {
      expect(
        skyFallIntent(target).motion,
        const MapCameraAnimated(skyFallDuration),
      );
      expect(skyFallDuration, const Duration(milliseconds: 900));
    });

    test('löst weder das Einrasten noch den Anker', () {
      // Nur ein `MapCameraCommand` darf das, und der Sky-Fall ist keiner.
      final intent = skyFallIntent(target);

      expect(releasesBearingLock(intent), isFalse);
      expect(clearsFollowAnchor(intent), isFalse);
    });
  });

  group('GPS-Folgen, screen-map.jsx:2665-2675', () {
    test('verschiebt nur den Mittelpunkt', () {
      final intent = userPositionFollowIntent(target);

      expect(intent.change.center, target);
      expect(intent.change.zoom, isNull);
      expect(intent.change.bearing, isNull);
      expect(intent.change.pitch, isNull);
      expect(
        intent.change.changesBearing,
        isFalse,
        reason:
            'sonst hielte das Einrasten der Blickrichtung das GPS-Folgen auf',
      );
    });

    test('trägt Totzone und Mindestpause der Quelle', () {
      final intent = userPositionFollowIntent(target);

      expect(intent.deadZoneMeters, 12);
      expect(intent.minPause, const Duration(milliseconds: 800));
      expect(
        intent.bearingDeadZoneDegrees,
        isNull,
        reason: 'die Winkel-Totzone gehört der anderen Dauerabsicht',
      );
    });

    test('weicht keiner Geste', () {
      // `applyPos` prüft in `:2668` allein `!m.isEasing()`. `userInteracting`
      // ist dort gar nicht erreichbar, es ist eine lokale Variable im Closure
      // des Kompass-Effekts (`:2807`).
      expect(userPositionFollowIntent(target).yieldsToUserGesture, isFalse);
    });

    test('ist die Dauerabsicht userPosition mit 900 Millisekunden', () {
      final intent = userPositionFollowIntent(target);

      expect(intent.kind, MapCameraFollowKind.userPosition);
      expect(intent.rank, 4);
      expect(
        intent.motion,
        const MapCameraAnimated(Duration(milliseconds: 900)),
      );
      expect(intent.origin, MapCameraIntentOrigin.discovery);
    });
  });

  group('Neuzentrieren, screen-map.jsx:2983-2987', () {
    test('der Zoom ist das Maximum aus aktuellem Zoom und 15', () {
      // Beide Seiten der Rechnung, sonst käme ein `min` ebenso durch wie ein
      // fest gesetztes 15.
      expect(
        recenterIntent(target: target, currentZoom: 17).change.zoom,
        17,
        reason: 'wer weiter drin steht, behält seinen Zoom',
      );
      expect(
        recenterIntent(target: target, currentZoom: 12).change.zoom,
        15,
        reason: 'wer weiter draußen steht, wird herangeholt',
      );
      expect(recenterIntent(target: target, currentZoom: 15).change.zoom, 15);
    });

    test('animiert 400 Millisekunden auf die Position', () {
      final intent = recenterIntent(target: target, currentZoom: 14);

      expect(intent.change.center, target);
      expect(
        intent.motion,
        const MapCameraAnimated(Duration(milliseconds: 400)),
      );
      expect(intent.change.bearing, isNull);
      expect(intent.change.pitch, isNull);
    });

    test('weicht keiner laufenden Animation', () {
      // **Der Tipp auf die Stadt-Pille wird ausgeführt, immer.** Die Quelle
      // ruft `recenter` (`:3106`) bedingungslos; nichts dort fragt nach einer
      // laufenden Animation. Stünde hier `true`, verschluckte ein Tipp
      // während des Sky-Falls oder eines GPS-Folgens sich lautlos, und genau
      // in dem Moment drückt ein Nutzer auf „bring mich zurück".
      //
      // Der Sky-Fall hat diese Zusicherung seit dem ersten Tag, das
      // Neuzentrieren nicht: nachgemessen, `yieldsToRunningAnimation: true`
      // zu ergänzen, überlebte alle 1177 Tests.
      expect(
        recenterIntent(
          target: target,
          currentZoom: 14,
        ).yieldsToRunningAnimation,
        isFalse,
      );
    });

    test('ist eine Einmal-Absicht und löst das Einrasten nicht', () {
      // **Der Unterschied zur Stadt-Pille und zum Kompass in einem Satz.** Die
      // Pille ruft in der Quelle nur `recenter` (`:3106`) und fasst
      // `manualBearingRef` nicht an; der Kompass tut beides (`:3182-3183`).
      final intent = recenterIntent(target: target, currentZoom: 14);

      expect(intent, isA<MapCameraOneShot>());
      expect(intent.rank, 3);
      expect(releasesBearingLock(intent), isFalse);
      expect(clearsFollowAnchor(intent), isFalse);
    });
  });

  group('Kompass kurz, screen-map.jsx:3175-3185', () {
    test('ist ein Nutzerbefehl und löst das Einrasten', () {
      final intent = compassTapIntent(currentZoom: 14, target: target);

      expect(intent, isA<MapCameraCommand>());
      expect(intent.rank, 1);
      expect(releasesBearingLock(intent), isTrue);
      expect(
        clearsFollowAnchor(intent),
        isFalse,
        reason: 'nur der lange Druck setzt lastCameraPosRef auf null (:3165)',
      );
    });

    test('zentriert mit derselben Rechnung neu wie die Stadt-Pille', () {
      expect(compassTapIntent(currentZoom: 17, target: target).change.zoom, 17);
      expect(compassTapIntent(currentZoom: 12, target: target).change.zoom, 15);
      expect(
        compassTapIntent(currentZoom: 12, target: target).motion,
        const MapCameraAnimated(Duration(milliseconds: 400)),
      );
    });

    test('löst das Einrasten auch ohne Ortung, ohne die Kamera zu bewegen', () {
      // `manualBearingRef.current = false` steht in `:3182` **vor** dem Aufruf
      // von `recenter`, und `recenter` kehrt ohne Position sofort zurück
      // (`:2978-2979`).
      final intent = compassTapIntent(currentZoom: 14);

      expect(releasesBearingLock(intent), isTrue);
      expect(intent.change.center, isNull);
      expect(intent.change.zoom, isNull);
      expect(intent.change.bearing, isNull);
      expect(intent.change.pitch, isNull);
      expect(intent.motion, const MapCameraImmediate());
    });
  });

  group('Kompass lang, screen-map.jsx:3158-3172', () {
    test('springt mit Position auf Zoom 15, Norden und Neigung 30', () {
      final intent = compassLongPressIntent(target: target);

      expect(intent.change.center, target);
      expect(intent.change.zoom, 15);
      expect(intent.change.bearing, 0);
      expect(intent.change.pitch, 30);
      expect(
        intent.motion,
        const MapCameraImmediate(),
        reason: 'die Quelle springt, sie animiert nicht',
      );
    });

    test('ohne Position bleiben Mittelpunkt und Zoom, wo sie sind', () {
      // Die Quelle hat dafür einen eigenen Zweig: `:3170` setzt nur
      // `{ bearing: 0, pitch: 30 }`. Wer den übersieht, zieht die Karte ohne
      // Ortung auf Zoom 15 an einen Ort, den niemand gewählt hat.
      final intent = compassLongPressIntent();

      expect(intent.change.center, isNull);
      expect(intent.change.zoom, isNull);
      expect(intent.change.bearing, 0);
      expect(intent.change.pitch, 30);
    });

    test('ist ein Nutzerbefehl, löst das Einrasten und leert den Anker', () {
      final intent = compassLongPressIntent(target: target);

      expect(intent.rank, 1);
      expect(releasesBearingLock(intent), isTrue);
      expect(
        clearsFollowAnchor(intent),
        isTrue,
        reason:
            'ohne das unterdrückte die Strecken-Totzone den nächsten GPS-Fix, '
            'während die Quelle ihn ausführt (:3165, :2660-2662)',
      );
    });
  });
}
