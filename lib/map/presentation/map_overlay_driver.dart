/// Die schmale Schnittstelle, über die der Karten-Host Quellen, Layer und
/// Bilder im SDK anlegt, und ihre MapLibre-Fassung.
///
/// ## Warum es diese Schnittstelle gibt
///
/// Derselbe Grund wie bei [MapCameraDriver], und er wiegt hier schwerer:
/// **im Widget-Test entsteht nie ein `MapLibreMapController`.**
/// `MapLibreMap.build` gibt auf Android eine Plattform-Ansicht zurück
/// (`method_channel_maplibre_gl.dart:133-185`), ohne Plattformkanal läuft
/// `onPlatformViewCreated` nie, also erzeugt `maplibre_map.dart:390-418`
/// keinen Controller. Ein Host, der seine Layer direkt anlegt, ist damit nur
/// auf einem Gerät prüfbar, und die teuren Fehler dieses Schritts sind genau
/// die lautlosen: eine Quelle ohne Gruppierung, eine Kennung an der falschen
/// Stelle, ein fehlendes `minzoom`.
///
/// ## Warum sie die Typen des SDK benutzt und trotzdem eine Naht ist
///
/// [MapCameraDriver] spricht in Domänentypen. Diese hier nicht: sie reicht
/// [SourceProperties], [CircleLayerProperties] und [SymbolLayerProperties]
/// weiter. Das ist Absicht. Diese drei sind **reine Wertklassen** des Pakets,
/// im Test ohne Karte und ohne Plattformkanal erzeugbar und lesbar. Würde die
/// Schnittstelle sie hinter eigenen Typen verstecken, wanderte der Aufbau der
/// Ausdrücke in die MapLibre-Fassung, und dort ist er unprüfbar. So liegt jede
/// **Entscheidung** im Host, und die Fassung darunter ist siebenmal
/// Durchreichen.
///
/// Wo hier die Grenze verläuft, ist deshalb nicht „welche Typen", sondern
/// „wer entscheidet": Kennungen, Ausdrücke, Zoomgrenzen und Filter entstehen
/// im Host, das SDK bekommt sie fertig.
library;

import 'dart:typed_data';

import 'package:maplibre_gl/maplibre_gl.dart';

/// Was der Host vom Karten-SDK braucht, um eine Überlagerung zu zeichnen.
///
/// `abstract interface class`: ein `extends` geht damit nicht durch, und jeder
/// Doppelgänger im Test schreibt sichtbar `implements MapOverlayDriver`.
abstract interface class MapOverlayDriver {
  /// Registriert ein Bild unter [name].
  ///
  /// `sdf` bleibt beim Standard `false` (`controller.dart:1686`). Ein
  /// SDF-Bild ist eine einfarbige Maske, die das SDK zur Laufzeit einfärbt;
  /// die Ballons tragen Kategoriefarbe, Rahmen, Verlauf und ein farbiges Emoji
  /// und sind damit das Gegenteil davon.
  Future<void> addImage(String name, Uint8List bytes);

  /// Legt die Quelle [sourceId] an.
  ///
  /// **Ausdrücklich nicht `addGeoJsonSource`, und das ist der teuerste Fund
  /// dieses Schritts.** Die Methode, deren Name das Gegenteil verspricht,
  /// reicht auf Android nur `withSynchronousUpdate` durch
  /// (`MapLibreMapController.java:448`); einen Gruppierungsschalter gibt es
  /// dort nicht. Eine so angelegte Quelle gruppiert **nie**, ohne
  /// Fehlermeldung. Nur `addSource` mit [GeojsonSourceProperties]
  /// (`controller.dart:1805`, `source_properties.dart:407-522`) führt
  /// `cluster`, `clusterRadius` und `clusterMaxZoom`, und nur diese Felder
  /// setzt der `SourcePropertyConverter` auf beiden Plattformen um.
  ///
  /// Deshalb steht `addGeoJsonSource` gar nicht erst in dieser Schnittstelle:
  /// die Verwechslung ist damit kein Fehler, den ein Test finden muss, sondern
  /// einer, den der Übersetzer meldet.
  Future<void> addSource(String sourceId, SourceProperties properties);

  /// Schiebt neue Daten in die bestehende Quelle [sourceId].
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geoJson);

  /// Legt einen Kreis-Layer an.
  ///
  /// [minzoom] ist einschließlich, [maxzoom] ausschließlich, [filter] ein
  /// Style-Ausdruck.
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    CircleLayerProperties properties, {
    double? minzoom,
    double? maxzoom,
    Object? filter,
  });

  /// Legt einen Symbol-Layer an.
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    double? minzoom,
    double? maxzoom,
    Object? filter,
  });

  /// Entfernt den Layer [layerId].
  Future<void> removeLayer(String layerId);

  /// Entfernt die Quelle [sourceId].
  Future<void> removeSource(String sourceId);
}

/// Die Fassung, die wirklich mit `maplibre_gl` spricht.
///
/// Bewusst ohne jede eigene Entscheidung: keine Kennung, kein Ausdruck, kein
/// Standardwert entsteht hier. Wer in dieser Klasse etwas ergänzen möchte, das
/// nicht bloß durchreicht, gehört in den Host.
class MapLibreOverlayDriver implements MapOverlayDriver {
  /// Nimmt den Controller, den `onMapCreated` liefert.
  MapLibreOverlayDriver(this._controller);

  final MapLibreMapController _controller;

  @override
  Future<void> addImage(String name, Uint8List bytes) =>
      _controller.addImage(name, bytes);

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) =>
      _controller.addSource(sourceId, properties);

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geoJson,
  ) => _controller.setGeoJsonSource(sourceId, geoJson);

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    CircleLayerProperties properties, {
    double? minzoom,
    double? maxzoom,
    Object? filter,
  }) => _controller.addCircleLayer(
    sourceId,
    layerId,
    properties,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: filter,
  );

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    double? minzoom,
    double? maxzoom,
    Object? filter,
  }) => _controller.addSymbolLayer(
    sourceId,
    layerId,
    properties,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: filter,
  );

  @override
  Future<void> removeLayer(String layerId) => _controller.removeLayer(layerId);

  @override
  Future<void> removeSource(String sourceId) =>
      _controller.removeSource(sourceId);
}
