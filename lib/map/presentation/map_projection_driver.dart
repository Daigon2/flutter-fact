/// Die schmale Schnittstelle, über die der Karten-Host Koordinaten in
/// Bildschirmlagen umrechnen lässt, und ihre MapLibre-Fassung.
///
/// ## Warum es diese Schnittstelle gibt
///
/// Derselbe Grund wie bei [MapCameraDriver] und [MapOverlayDriver]: **im
/// Widget-Test entsteht nie ein `MapLibreMapController`**. Ohne diese Naht
/// wäre die ganze Umrechnung nur auf einem Gerät prüfbar, und die Fehler
/// dieses Schritts sind wieder die lautlosen: vertauschte Breite und Länge,
/// eine Antwort mit weniger Punkten als die Anfrage, ein Punkt hinter dem
/// Horizont.
///
/// ## Sie spricht die Typen des SDK, und das ist dieselbe Entscheidung wie dort
///
/// [LatLng] und [Point] sind reine Wertklassen des Pakets, im Test ohne Karte
/// erzeugbar und lesbar. Die **Entscheidungen** liegen deshalb im Host: er
/// baut die [LatLng], er prüft die Länge der Antwort, er verwirft
/// unbrauchbare Zahlen, und er übersetzt in `MapScreenPoint`. Hier ist es
/// eine Zeile Durchreichen.
///
/// ## Eine Zusage des Pakets, die keine ist
///
/// `toScreenLocationBatch` gibt eine `Future<List<Point>>` zurück
/// (`maplibre_gl-0.26.2`, `lib/src/controller.dart:1789`), und die
/// Kanalfassung baut die Liste stumpf aus einer `Float64List`, zwei Zahlen je
/// Punkt (`maplibre_gl_platform_interface-0.26.2`,
/// `lib/src/method_channel_maplibre_gl.dart:598-613`). Kommt von der
/// Plattform ein kürzeres Feld zurück, ist die Liste kürzer, ohne Fehler und
/// ohne Warnung; kommt eine Zahl zurück, die keine ist, steht sie unverändert
/// darin. Beides fängt der Host ab, nicht diese Naht.
library;

import 'dart:math';

import 'package:maplibre_gl/maplibre_gl.dart';

/// Was der Host vom Karten-SDK braucht, um Koordinaten zu projizieren.
///
/// `abstract interface class`: ein `extends` geht damit nicht durch, und jeder
/// Doppelgänger im Test schreibt sichtbar `implements MapProjectionDriver`.
abstract interface class MapProjectionDriver {
  /// Rechnet [latLngs] in Bildschirmlagen um.
  ///
  /// **Ausdrücklich der Stapelaufruf und nicht `toScreenLocation` je Punkt.**
  /// Jeder Einzelaufruf ist ein eigener Umlauf über den Plattformkanal; bei
  /// bis zu 60 Kamerameldungen je Sekunde und einer Handvoll Ballons wären das
  /// mehrere hundert Umläufe je Sekunde, und die Warteschlange liefe voll,
  /// bevor sie leer wird.
  Future<List<Point<num>>> toScreenLocationBatch(Iterable<LatLng> latLngs);
}

/// Die Fassung, die wirklich mit `maplibre_gl` spricht.
///
/// Bewusst ohne jede eigene Entscheidung. Wer hier etwas ergänzen möchte, das
/// nicht bloß durchreicht, gehört in den Host.
class MapLibreProjectionDriver implements MapProjectionDriver {
  /// Nimmt den Controller, den `onMapCreated` liefert.
  MapLibreProjectionDriver(this._controller);

  final MapLibreMapController _controller;

  @override
  Future<List<Point<num>>> toScreenLocationBatch(Iterable<LatLng> latLngs) =>
      _controller.toScreenLocationBatch(latLngs);
}
