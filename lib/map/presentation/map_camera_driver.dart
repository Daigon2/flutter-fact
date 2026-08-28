/// Die schmale Schnittstelle, über die der Karten-Host die Kamera des SDK
/// bewegt, und ihre MapLibre-Fassung.
///
/// ## Warum es diese Schnittstelle gibt
///
/// **Ohne sie wäre die gesamte Buchführung des Hosts ungetestet.** Im
/// Widget-Test entsteht nie ein `MapLibreMapController`: `MapLibreMap.build`
/// gibt auf Android eine Plattform-Ansicht zurück
/// (`method_channel_maplibre_gl.dart:133-185`), und ohne Plattformkanal läuft
/// `onPlatformViewCreated` nie, also erzeugt `maplibre_map.dart:390-418`
/// keinen Controller. Ein Host, der seine SDK-Aufrufe direkt absetzt, ist
/// damit nur auf einem Gerät prüfbar.
///
/// Sie ist bewusst **schmal**: zwei Methoden, beide auf einen vollständigen
/// [MapCameraView]. Jede weitere Methode wäre eine Einladung, Marker, Layer
/// und Abfragen ebenfalls hier durchzureichen, und dann wäre sie eine zweite
/// Fassung des SDK statt einer Naht.
library;

import 'package:fact_app/map/domain/map_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Was der Host vom Karten-SDK braucht.
///
/// `abstract interface class`: ein `extends` geht damit nicht durch, und jeder
/// Doppelgänger im Test schreibt sichtbar `implements MapCameraDriver`.
abstract interface class MapCameraDriver {
  /// Fährt die Kamera über [duration] hinweg nach [target].
  ///
  /// **Die Rückgabe ist plattformasymmetrisch, und das ist tragend.** Android
  /// liefert echtes `true`/`false` über den `OnCameraMoveFinishedListener`,
  /// **iOS liefert immer sofort `null`** (`maplibre_gl 0.26.2`,
  /// `lib/src/controller.dart:409-416`, eigene Doku des Pakets). Deshalb gilt
  /// beim Aufrufer: `true` und `false` löschen den Animationszustand, `null`
  /// heißt „keine Auskunft" und lässt ihn stehen. Ein
  /// `if (await animate(...) != true)` wäre auf Android richtig und auf iOS
  /// zerstörerisch.
  Future<bool?> animate(MapCameraView target, Duration duration);

  /// Setzt die Kamera ohne Animation auf [target].
  ///
  /// Rückgabe wie bei [animate], mit derselben Asymmetrie
  /// (`controller.dart:424-431`).
  Future<bool?> jump(MapCameraView target);
}

/// Die Fassung, die wirklich mit `maplibre_gl` spricht.
///
/// ## Warum immer ein vollständiger [MapCameraView] und nie eine Teiländerung
///
/// `CameraUpdate` hat für einzelne Felder eigene Fabriken (`zoomTo`,
/// `bearingTo`, `tiltTo`, `newLatLng`), aber **keine Möglichkeit, zwei davon in
/// einem Aufruf zu verbinden**. Eine Absicht, die Mittelpunkt und Neigung
/// zugleich ändert, bräuchte also zwei Aufrufe, zwei Animationen und damit
/// zwei Endezeitpunkte, die der Host beide führen müsste. Der Host löst eine
/// [MapCameraChange] deshalb vorher gegen die zuletzt bekannte Kamera auf und
/// gibt hier immer das vollständige Ziel weiter.
///
/// **Der Preis, und er ist bezahlbar:** ist die zuletzt bekannte Kamera
/// veraltet, zieht eine reine Neigungsänderung Mittelpunkt, Zoom und
/// Blickrichtung auf den veralteten Stand zurück. Genau dagegen steht
/// `trackCameraPosition: true` am Widget, das jede Bewegung meldet; die
/// bekannte Kamera ist damit höchstens einen Rückruf alt.
class MapLibreCameraDriver implements MapCameraDriver {
  /// Nimmt den Controller, den `onMapCreated` liefert.
  MapLibreCameraDriver(this._controller);

  final MapLibreMapController _controller;

  @override
  Future<bool?> animate(MapCameraView target, Duration duration) =>
      _controller.animateCamera(updateFor(target), duration: duration);

  @override
  Future<bool?> jump(MapCameraView target) =>
      _controller.moveCamera(updateFor(target));

  /// Übersetzt einen [MapCameraView] in die Kameraangabe des SDK.
  ///
  /// `tilt` heißt hier, was in der Domäne `pitch` heißt: die Quelle und die
  /// Style-Spezifikation sagen `pitch`, `maplibre_gl` sagt `tilt`
  /// (`maplibre_gl_platform_interface 0.26.2`, `lib/src/camera.dart:30-35`).
  /// Die Umbenennung passiert genau hier, an der Naht zum SDK, und nirgends
  /// sonst.
  ///
  /// **`@visibleForTesting` und nicht privat, weil die Verwechslung sonst
  /// lautlos wäre.** Der Weg hier hindurch läuft zur Laufzeit bei jeder
  /// Kameraabsicht, und ein vertauschtes Paar `bearing`/`tilt` sieht in jedem
  /// Widget-Test genauso aus wie das richtige: ohne Plattformkanal entsteht
  /// nie ein Controller, also ruft niemand [animate] oder [jump]. Als reine
  /// Funktion ist sie dagegen ohne Karte prüfbar. `@visibleForTesting` ist
  /// dabei kein guter Vorsatz, sondern ein Gate: ein Aufruf aus `lib/` bricht
  /// `dart analyze` ab.
  @visibleForTesting
  static CameraUpdate updateFor(MapCameraView target) =>
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(target.center.latitude, target.center.longitude),
          zoom: target.zoom,
          bearing: target.bearing,
          tilt: target.pitch,
        ),
      );
}
