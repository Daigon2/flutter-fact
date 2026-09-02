/// Welche Zoomstufe ein geografisches Rechteck gerade noch in eine
/// Bildschirmfläche passen lässt.
///
/// ## Reine Geometrie, keine Politik
///
/// Diese Datei kennt keine Stadt, keinen Ballon und keine Schwelle. Sie
/// rechnet aus einer Fläche in Grad und einer Fläche in Stilpixeln eine
/// Zoomstufe aus, mehr nicht. Werte wie „Zoom 16", „Zoom 18" oder ein
/// Gruppierungsradius gehören ins Feature `discovery`, das diese Funktion
/// mit seinen eigenen Zahlen aufruft.
///
/// ## Die Formel ist hergeleitet, nicht an diesem Paket gemessen
///
/// **Das ist die wichtigste Einschränkung dieser Datei, und sie steht hier
/// so deutlich, weil eine Begründung, die sich als gemessen ausgibt, in
/// diesem Repository schon mehrfach eine falsche Zahl unbemerkt durchgelassen
/// hat** (`REBUILD_STATUS.md`, „Wie Tests hier blind werden", Muster 9).
///
/// Die Web-Mercator-Projektion, auf der `rectFitZoom` beruht, ist Industrie-
/// Konvention: die Weltbreite bei Zoomstufe `z` ist `tileSize * 2^z`
/// Stilpixel, mit `tileSize = 512`. Diese Konvention geht auf Mapbox GL JS
/// zurück, von dem sich MapLibre abgespalten hat, und sie gilt **unabhängig
/// von der tatsächlichen Kachelgröße einer Kartenquelle**: eine Rasterquelle
/// mit 256 Pixel großen Kacheln (wie sie dieses Projekt tatsächlich verwendet,
/// siehe unten) bekommt intern doppelt so viele Kacheln bei `z+1` angefordert
/// und ändert an der Zoom-zu-Pixel-Umrechnung selbst nichts.
///
/// **Kein Beleg im Repository gefunden, der die Zahl 512 für `maplibre_gl
/// 0.26.2` konkret belegt.** Nachgesehen und mit Ergebnis:
///
///  * `assets/map/fact_map_style.json:6` setzt `"tileSize": 256` für die
///    Rasterquelle `ne2_shaded`. **Das ist nicht dieselbe Zahl und beweist
///    das Gegenteil nicht:** dieses Feld beschreibt, in welcher Auflösung die
///    Kachelbilder dieser einen Quelle abgerufen werden, nicht die Referenz-
///    Kachelgröße, mit der der Renderer Zoomstufen in Pixel umrechnet. Wer
///    diese Zeile als Beleg gegen 512 zitiert, verwechselt zwei verschiedene
///    Konstanten.
///  * `tool/bake_map_style.dart` und `tool/map_style/liberty_upstream.json`
///    backen nur Farben und Sichtbarkeiten, keine Zoom-Konstante.
///  * `maplibre_gl 0.26.2` (Pub-Cache,
///    `hosted/pub.dev/maplibre_gl-0.26.2/lib`) ist ein Plattformkanal-Paket:
///    die Zoom-zu-Pixel-Umrechnung liegt in den nativen SDKs (iOS, Android,
///    Web), nicht im Dart-Quelltext dieses Pakets. Eine Suche nach `512` und
///    `tileSize` in `lib/` des Pakets findet nur Bildmuster-Vorgaben
///    (`layer_properties.dart:1384,1657,1809`, „image width must be a factor
///    of two (2, 4, 8, ..., 512)"), keine Zoom-Konstante.
///
/// **Welche Messung die Formel bestätigen würde:** am Gerät eine
/// `MapPositionRect` bekannter Ausdehnung mit `rectFitZoom` in eine Zoomstufe
/// umrechnen, die Karte mit `moveCamera`/`animateCamera` auf genau diese
/// Zoomstufe und diesen Mittelpunkt setzen und danach mit
/// `MapLibreMapController.toScreenLocation` (device-pixel-genau, siehe
/// `map_screen_point.dart`) nachmessen, ob die beiden Ecken von
/// [MapPositionRect] tatsächlich an den Rändern der übergebenen
/// [MapViewport] ankommen. Eine einzelne solche Messung würde die Konstante
/// 512 entweder bestätigen oder durch die tatsächliche ersetzen.
library;

import 'dart:math' as math;

import 'package:fact_app/map/domain/map_position_rect.dart';
import 'package:fact_app/map/domain/map_viewport.dart';

/// Referenz-Kachelgröße der Zoom-zu-Pixel-Umrechnung, in Stilpixeln.
///
/// Siehe Kopfkommentar dieser Datei: hergeleitet aus der Mapbox-GL/MapLibre-
/// Konvention, nicht an diesem Paket gemessen.
const double _referenceTileSizeInStylePixels = 512;

/// Breitengrad, bei dem MapLibre die Kamera klemmt, in Grad.
///
/// Das ist die Breite, bei der die Web-Mercator-Projektion in einem
/// quadratischen Weltbild eine normierte Ordinate von genau 0 bzw. 1 ergibt;
/// jenseits davon verließe [_mercatorY] den Bereich `[0, 1]`. MapLibre GL JS
/// und, davon abgeleitet, MapLibre Native klemmen Kamerabreitengrade auf
/// diesen Wert (verbreitet dokumentiert als `MAX_MERCATOR_LATITUDE =
/// 85.051129`, aus `2 * atan(exp(pi)) - pi/2` in Grad umgerechnet). Die
/// Rechnung unten übernimmt die Klemmung, ohne die Herleitung an diesem
/// Paket nachgemessen zu haben, aus demselben Grund wie bei der Zahl 512.
const double _maxMercatorLatitudeInDegrees = 85.051129;

/// Die Zoomstufe, bei der [rect] gerade noch vollständig in [viewport]
/// passt, nach oben durch [maxZoom] begrenzt.
///
/// ## Die Rechnung, in Web-Mercator
///
/// Die Weltbreite in Stilpixeln ist `tileSize * 2^zoom`. Eine Längenspanne
/// `dLng` Grad belegt davon den Anteil `dLng / 360`, also
/// `(dLng / 360) * tileSize * 2^zoom` Stilpixel. Aus der Bedingung, dass das
/// höchstens die Breite von [viewport] sein darf, folgt
///
///     zoom = log2(width * 360 / (tileSize * dLng))
///
/// Für die Breite gilt dieselbe Überlegung über die normierte Mercator-
/// Ordinate `y(phi) = (1 - ln(tan(pi/4 + phi/2)) / pi) / 2`, die für Breiten
/// zwischen `-maxMercatorLatitude` und `+maxMercatorLatitude` im Bereich
/// `[0, 1]` liegt. Eine Ordinaten-Spanne `dY` belegt `dY * tileSize * 2^zoom`
/// Stilpixel, und aus derselben Bedingung folgt
///
///     zoom = log2(height / (tileSize * dY))
///
/// Das Ergebnis ist das Minimum beider Zoomstufen, dann nach oben mit
/// [maxZoom] geklemmt.
///
/// ## Randfälle
///
/// **Fläche null**, also [rect] ohne Ausdehnung in einer oder beiden
/// Richtungen (ein einzelner Punkt, oder eine Spanne von null Grad in nur
/// einer Richtung): die betroffene Richtung stellt keine Bedingung an das
/// Ergebnis. Stellen **beide** Richtungen keine Bedingung, ist das Ergebnis
/// [maxZoom]. Deshalb ist [maxZoom] hier ein Pflichtparameter und kein
/// optionaler Wert mit eingebautem Standard: ohne ihn gäbe es für diesen
/// Fall keine sinnvolle Zahl, die diese Datei aus eigenem Recht setzen
/// dürfte, denn „wie nah maximal gezoomt werden darf" ist eine Politik-
/// Entscheidung des Aufrufers, keine Geometrie.
///
/// **[viewport] mit Breite oder Höhe null oder negativ**, der Zustand vor
/// dem ersten Layout: das Ergebnis ist ebenfalls [maxZoom]. Eine halbe
/// Rechnung, bei der nur eine der beiden Richtungen eine gültige Ausdehnung
/// hat, wird hier bewusst nicht versucht. Eine Kartenfläche ohne Breite oder
/// ohne Höhe ist als Ganzes nicht layoutet, und eine Zoomstufe aus nur einer
/// gültigen Achse vorzuschlagen wäre eine Zahl mit einer Genauigkeit, die die
/// Eingabe nicht hergibt. Ohne diese Abfrage stünde hier außerdem eine
/// Division durch null oder eine negative Zahl im Logarithmus, und `NaN` in
/// einer Kameraabsicht ist der schlimmste mögliche Ausgang: `MapCameraChange`
/// hat keinen Schutz davor, ein solcher Wert reicht bis zum Karten-SDK durch.
///
/// **Breitengrade an den Polen:** Mercator ist bei ±90° nicht definiert,
/// [_mercatorY] wird dort unbeschränkt. Beide Breitengrade von [rect] werden
/// deshalb vor der Rechnung auf ±[_maxMercatorLatitudeInDegrees] geklemmt,
/// der Zahl, bei der MapLibre selbst die Kamera klemmt (siehe dort). Diese
/// Klemmung kann eine vorher positive Breitenspanne auf eine Ordinaten-Spanne
/// von null zusammenfallen lassen, wenn beide Breitengrade jenseits der
/// Klemmgrenze liegen (ein Rechteck, das vollständig näher am Pol liegt als
/// jede darstellbare Kamera): dann stellt die Breite ebenfalls keine
/// Bedingung, wie oben beschrieben.
///
/// **Negative Ergebnisse** (ein Rechteck, dessen Ausdehnung größer ist als
/// die Welt bei Zoomstufe 0 in [viewport] passen würde) werden **nicht**
/// geklemmt. Eine untere Grenze wie „mindestens Zoom 0" ist eine Annahme
/// über das einbettende Karten-SDK oder die App-weite Mindestzoomstufe, also
/// wieder eine Politik-Entscheidung, die hier so wenig hingehört wie eine
/// obere Grenze ohne den Parameter [maxZoom]. Ein negatives Ergebnis ist
/// deshalb ein gültiger, wenn auch unüblicher Rückgabewert.
double rectFitZoom({
  required MapPositionRect rect,
  required MapViewport viewport,
  required double maxZoom,
}) {
  final double width = viewport.widthInScreenPixels;
  final double height = viewport.heightInScreenPixels;
  if (width <= 0 || height <= 0) {
    return maxZoom;
  }

  final double longitudeSpan = rect.longitudeSpanInDegrees;
  final double? zoomForLongitude = longitudeSpan > 0
      ? _log2(width * 360 / (_referenceTileSizeInStylePixels * longitudeSpan))
      : null;

  final double southY = _mercatorY(_clampLatitude(rect.southWest.latitude));
  final double northY = _mercatorY(_clampLatitude(rect.northEast.latitude));
  final double latitudeSpanAsMercatorY = (southY - northY).abs();
  final double? zoomForLatitude = latitudeSpanAsMercatorY > 0
      ? _log2(
          height / (_referenceTileSizeInStylePixels * latitudeSpanAsMercatorY),
        )
      : null;

  if (zoomForLongitude == null && zoomForLatitude == null) {
    return maxZoom;
  }

  final List<double> candidateZooms = <double>[
    ?zoomForLongitude,
    ?zoomForLatitude,
  ];
  final double fitted = candidateZooms.reduce(math.min);

  return math.min(fitted, maxZoom);
}

/// Normierte Mercator-Ordinate für [latitudeInDegrees], in `[0, 1]` für
/// Breiten zwischen ±[_maxMercatorLatitudeInDegrees].
///
/// `y(phi) = (1 - ln(tan(pi/4 + phi/2)) / pi) / 2`, mit `phi` im Bogenmaß.
/// 0 entspricht dem Nordrand der quadratischen Weltkarte, 1 dem Südrand, 0,5
/// dem Äquator.
double _mercatorY(double latitudeInDegrees) {
  final double phi = latitudeInDegrees * math.pi / 180;
  return (1 - math.log(math.tan(math.pi / 4 + phi / 2)) / math.pi) / 2;
}

/// Klemmt [latitudeInDegrees] auf ±[_maxMercatorLatitudeInDegrees].
double _clampLatitude(double latitudeInDegrees) {
  if (latitudeInDegrees > _maxMercatorLatitudeInDegrees) {
    return _maxMercatorLatitudeInDegrees;
  }
  if (latitudeInDegrees < -_maxMercatorLatitudeInDegrees) {
    return -_maxMercatorLatitudeInDegrees;
  }
  return latitudeInDegrees;
}

/// Logarithmus zur Basis 2, die Dart-Standardbibliothek kennt nur `log`.
double _log2(double value) => math.log(value) / math.ln2;
