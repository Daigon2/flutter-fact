import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/presentation/map_camera_driver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Naht zum Karten-SDK, geprüft an der einzigen Stelle, die ohne Karte
/// erreichbar ist.
///
/// **Warum es diese Datei überhaupt gibt:** `animate` und `jump` brauchen einen
/// `MapLibreMapController`, und den gibt es im Test nie. Bis hierher war
/// `MapLibreCameraDriver` deshalb in **keiner** Testdatei erwähnt, obwohl der
/// Weg hier hindurch bei jeder Kameraabsicht läuft. Eine vertauschte
/// Zuordnung `bearing`/`tilt` hätte die ganze Suite überlebt und wäre erst am
/// Gerät aufgefallen, als Karte, die sich beim Neigen dreht.
void main() {
  /// Vier unterscheidbare Werte: mit `zoom == bearing` wäre eine Vertauschung
  /// unsichtbar.
  const MapCameraView view = MapCameraView(
    center: MapPosition(latitude: 48.1351, longitude: 11.582),
    zoom: 14,
    bearing: 90,
    pitch: 35,
  );

  /// Der Inhalt der Kameraangabe, so wie sie über den Plattformkanal geht.
  ///
  /// `CameraUpdate` gibt seine Felder nicht einzeln heraus, `toJson` ist der
  /// einzige Weg (`maplibre_gl_platform_interface-0.26.2`,
  /// `lib/src/camera.dart:174-176`). Gemessen wird damit genau das, was das
  /// SDK wirklich bekommt.
  Map<String, dynamic> positionOf(MapCameraView target) {
    final List<dynamic> update =
        MapLibreCameraDriver.updateFor(target).toJson() as List<dynamic>;
    expect(update.first, 'newCameraPosition');
    return update[1] as Map<String, dynamic>;
  }

  test('setzt `pitch` der Domäne als `tilt` des SDK', () {
    // Die eine Stelle, an der eine Verwechslung lautlos wäre: die Quelle und
    // die Style-Spezifikation sagen `pitch`, `maplibre_gl` sagt `tilt`.
    final Map<String, dynamic> position = positionOf(view);

    expect(position['tilt'], 35);
    expect(position['bearing'], 90);
  });

  test('reicht Mittelpunkt und Zoom unverändert durch', () {
    final Map<String, dynamic> position = positionOf(view);

    expect(position['zoom'], 14);
    // `LatLng.toJson` liefert `[lat, lng]`, in dieser Reihenfolge. Der
    // Längengrad geht durch die verlustbehaftete Normalisierung des
    // Konstruktors, siehe `map_surface_test.dart`.
    expect(position['target'], <Object>[48.1351, closeTo(11.582, 1e-9)]);
  });
}
