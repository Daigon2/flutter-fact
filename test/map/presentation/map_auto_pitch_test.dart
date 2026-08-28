import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/presentation/map_auto_pitch.dart';
import 'package:flutter_test/flutter_test.dart';

const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);

MapCameraView viewAt({required double zoom, required double pitch}) =>
    MapCameraView(center: munich, zoom: zoom, bearing: 0, pitch: pitch);

void main() {
  group('Die Zoom-Winkel-Kurve, `screen-map.jsx:1755-1759`', () {
    test('flach bis Zoom 11, einschließlich der 11 selbst', () {
      // Die Quelle schreibt `if (z <= 11) return 0`, die Grenze gehört also
      // noch zum flachen Ast.
      expect(mapAutoPitchForZoom(0), 0);
      expect(mapAutoPitchForZoom(10.9), 0);
      expect(mapAutoPitchForZoom(11), 0);
    });

    test('volle Neigung ab Zoom 15, einschließlich der 15 selbst', () {
      expect(mapAutoPitchForZoom(15), 58);
      expect(mapAutoPitchForZoom(16.5), 58);
      expect(mapAutoPitchForZoom(20), 58);
    });

    test('dazwischen linear, an beiden Knickpunkten stetig', () {
      // `((z - 11) / 4) * 58`, unabhängig nachgerechnet:
      // z = 12 → 14,5; z = 13 → 29; z = 14 → 43,5.
      expect(mapAutoPitchForZoom(12), closeTo(14.5, 1e-12));
      expect(mapAutoPitchForZoom(13), closeTo(29, 1e-12));
      expect(mapAutoPitchForZoom(14), closeTo(43.5, 1e-12));
      // Stetigkeit an den Knicken: knapp innerhalb liegt knapp am Randwert.
      expect(mapAutoPitchForZoom(11.001), closeTo(0, 0.02));
      expect(mapAutoPitchForZoom(14.999), closeTo(58, 0.02));
    });

    test('die volle Neigung ist 58 Grad und nicht 65 oder 75', () {
      // Der Kommentar der Quelle (`:1752-1753`) nennt noch 65 und 75, der Code
      // in `:1757` sagt 58. Wer den Kommentar nachbaut, neigt die Karte um
      // 17 Grad zu steil.
      expect(mapAutoPitchFullDegrees, 58);
    });
  });

  group('Die 2-Grad-Schwelle, `screen-map.jsx:1764`', () {
    test('genau 2 Grad Abweichung löst nichts aus', () {
      // Die Quelle schreibt `> 2`. Beide Richtungen geprüft, sonst hinge das
      // Ergebnis am Vorzeichen von `cur - target`.
      expect(mapAutoPitchIntent(viewAt(zoom: 15, pitch: 56)), isNull);
      expect(mapAutoPitchIntent(viewAt(zoom: 15, pitch: 60)), isNull);
    });

    test('knapp über 2 Grad löst aus, in beide Richtungen', () {
      expect(mapAutoPitchIntent(viewAt(zoom: 15, pitch: 55.9)), isNotNull);
      expect(mapAutoPitchIntent(viewAt(zoom: 15, pitch: 60.1)), isNotNull);
    });

    test('gar keine Abweichung löst nichts aus', () {
      expect(mapAutoPitchIntent(viewAt(zoom: 11, pitch: 0)), isNull);
    });
  });

  group('Die Absicht selbst', () {
    test('ändert nur die Neigung und lässt alles andere stehen', () {
      final MapCameraOneShot? intent = mapAutoPitchIntent(
        viewAt(zoom: 16, pitch: 0),
      );

      expect(intent, isNotNull);
      expect(intent!.change.pitch, 58);
      // `null` heißt „unverändert lassen". Stünden hier Werte, zöge die
      // Auto-Neigung die Karte zusätzlich auf einen anderen Ausschnitt, was
      // `easeTo({ pitch, duration })` in der Quelle nicht tut.
      expect(intent.change.center, isNull);
      expect(intent.change.zoom, isNull);
      expect(intent.change.bearing, isNull);
      expect(intent.change.changesBearing, isFalse);
    });

    test('animiert 300 Millisekunden lang', () {
      final MapCameraOneShot intent = mapAutoPitchIntent(
        viewAt(zoom: 16, pitch: 0),
      )!;

      expect(
        intent.motion,
        const MapCameraAnimated(Duration(milliseconds: 300)),
      );
    });

    test('kommt vom Host und nicht von einem Feature', () {
      // Ohne `mapHost` müsste sie sich als `discovery` ausgeben, und die
      // Diagnose würde lügen.
      final MapCameraOneShot intent = mapAutoPitchIntent(
        viewAt(zoom: 16, pitch: 0),
      )!;

      expect(intent.origin, MapCameraIntentOrigin.mapHost);
    });

    test('weicht einer laufenden Animation', () {
      // Der Wächter `if (map.isEasing()) return;` aus `:1761`. Er steht als
      // Feld an der Absicht und nicht als Sonderfall im Gate.
      final MapCameraOneShot intent = mapAutoPitchIntent(
        viewAt(zoom: 16, pitch: 0),
      )!;

      expect(intent.yieldsToRunningAnimation, isTrue);
    });
  });
}
