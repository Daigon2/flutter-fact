import 'dart:math' as math;

import 'package:fact_app/map/domain/map_position.dart';

/// Ein Rechteck aus zwei [MapPosition], das kleinste geografische Fenster,
/// das eine Menge von Punkten umschließt.
///
/// ## Wofür es gebraucht wird
///
/// `rectFitZoom` in `map_camera_fit.dart` braucht genau dieses Rechteck, um
/// eine Zoomstufe zu berechnen, auf der eine Reihe von Punkten (zum Beispiel
/// alle Ballons einer Stadt) gerade noch vollständig ins Bild passt. Der Typ
/// steht hier und nicht dort, weil er unabhängig von der Kamera Sinn ergibt:
/// „welches Fenster umschließt diese Punkte" ist eine Frage der Geometrie,
/// keine der Kamera.
///
/// `final class` aus demselben Grund wie [MapPosition]: der Typ hat
/// Wertgleichheit, und eine offene Klasse mit `==` würde zu asymmetrischer
/// Gleichheit einladen, sobald eine Unterklasse ein drittes Feld ergänzt.
final class MapPositionRect {
  /// Erzeugt ein Rechteck aus den beiden Eckpunkten, ohne Prüfung.
  ///
  /// Es wird **nicht** geprüft, dass [southWest] tatsächlich südwestlich von
  /// [northEast] liegt. Nach ADR-002 wächst die Struktur mit der Komplexität,
  /// und der einzige Aufrufer im Vertrag, [enclosingOrNull], liefert immer
  /// geordnete Ecken. `rectFitZoom` behandelt eine vertauschte oder
  /// entartete Eingabe trotzdem robust, siehe dort.
  const MapPositionRect({required this.southWest, required this.northEast});

  /// Bildet das kleinste Rechteck, das alle [positions] umschließt.
  ///
  /// ## Warum eine statische Methode und keine Fabrik
  ///
  /// Ein Konstruktor, auch ein `factory`, hat als Rückgabetyp immer die
  /// eigene Klasse, hier also nicht-nullbar. Bei einer leeren Eingabe gibt
  /// es aber kein kleinstes umschließendes Rechteck, weil es keinen Punkt
  /// gibt, den es umschließen müsste. Eine Fabrik hätte an dieser Stelle nur
  /// zwei schlechte Optionen: werfen, obwohl eine leere Liste kein
  /// Ausnahmefall ist, sondern ein regulärer Zustand (zum Beispiel eine
  /// Stadt ohne sichtbare Fakten); oder raten, etwa mit einem Rechteck der
  /// Fläche null irgendwo auf der Welt, was `rectFitZoom` still eine falsche
  /// Zoomstufe liefern ließe. Eine statische Methode mit nullbarem
  /// Rückgabetyp sagt die Möglichkeit direkt in der Signatur, und der
  /// Analyzer erzwingt beim Aufrufer eine Fallunterscheidung.
  ///
  /// Ein einzelner Punkt ist eine gültige Eingabe: das Ergebnis ist dann ein
  /// Rechteck der Fläche null, dessen Ecken beide auf diesem Punkt liegen.
  static MapPositionRect? enclosingOrNull(Iterable<MapPosition> positions) {
    double? minLatitude;
    double? maxLatitude;
    double? minLongitude;
    double? maxLongitude;

    for (final position in positions) {
      minLatitude = minLatitude == null
          ? position.latitude
          : math.min(minLatitude, position.latitude);
      maxLatitude = maxLatitude == null
          ? position.latitude
          : math.max(maxLatitude, position.latitude);
      minLongitude = minLongitude == null
          ? position.longitude
          : math.min(minLongitude, position.longitude);
      maxLongitude = maxLongitude == null
          ? position.longitude
          : math.max(maxLongitude, position.longitude);
    }

    if (minLatitude == null) {
      // Leere Eingabe. `minLatitude` steht stellvertretend für alle vier,
      // sie werden im selben Durchlauf gesetzt oder bleiben alle `null`.
      return null;
    }

    return MapPositionRect(
      southWest: MapPosition(latitude: minLatitude, longitude: minLongitude!),
      northEast: MapPosition(latitude: maxLatitude!, longitude: maxLongitude!),
    );
  }

  /// Die südwestliche Ecke: kleinster Breitengrad, kleinster Längengrad.
  final MapPosition southWest;

  /// Die nordöstliche Ecke: größter Breitengrad, größter Längengrad.
  final MapPosition northEast;

  /// Der Mittelpunkt, als einfaches arithmetisches Mittel der Ecken.
  ///
  /// Das ist der Mittelpunkt des **Rechtecks in Dezimalgrad**, nicht der
  /// geografische Schwerpunkt der ursprünglichen Punkte und auch nicht der
  /// Mittelpunkt in der Mercator-Projektion, den `rectFitZoom` für die
  /// Zoomrechnung verwendet. Für die kleinen Ausdehnungen einer einzelnen
  /// Stadt ist der Unterschied ohne Bedeutung.
  MapPosition get center => MapPosition(
    latitude: (southWest.latitude + northEast.latitude) / 2,
    longitude: (southWest.longitude + northEast.longitude) / 2,
  );

  /// Spannweite in Grad Breite, `northEast.latitude - southWest.latitude`.
  ///
  /// Null für ein Rechteck ohne Ausdehnung in dieser Richtung, etwa eine
  /// einzelne Position oder mehrere Positionen auf demselben Breitengrad.
  double get latitudeSpanInDegrees => northEast.latitude - southWest.latitude;

  /// Spannweite in Grad Länge, `northEast.longitude - southWest.longitude`.
  ///
  /// ## Der 180. Längengrad
  ///
  /// [enclosingOrNull] bildet diesen Wert aus dem kleinsten und dem größten
  /// Längengrad der Eingabe. Das ist falsch, sobald die Punkte den 180.
  /// Längengrad überschreiten: zwei Punkte bei -179° und +179°, die in
  /// Wahrheit nur 2° auseinanderliegen (über die Datumsgrenze hinweg), liefern
  /// hier eine Spannweite von 358°, fast der gesamte Umfang der Erde. Der
  /// Auslöser ist nicht eine seltene Randlage, sondern jede Menge von
  /// Positionen, die auf beiden Seiten der Datumsgrenze liegt.
  ///
  /// **Was dann passiert:** [center] landet in der Nähe von 0° Länge statt in
  /// der Nähe von ±180°, also auf der gegenüberliegenden Seite der Erde, und
  /// `rectFitZoom` bekommt eine Spannweite von 358° statt 2° übergeben. Die
  /// errechnete Zoomstufe für die Länge fiele auf nahezu 0, die Karte würde
  /// versuchen, fast die ganze Erde ins Bild zu quetschen, obwohl alle Punkte
  /// tatsächlich eng beieinanderliegen.
  ///
  /// Diese Rechnung baut den Fall **nicht** aus: keine Stadt im heutigen
  /// Bestand liegt auf der Datumsgrenze, und eine Behandlung ohne einen
  /// echten Anwendungsfall wäre ungeprüfter Code. Wer künftig eine Stadt in
  /// der Nähe von ±180° Länge aufnimmt (etwa auf Fidschi oder in
  /// Ost-Sibirien), muss diesen Abschnitt zuerst schließen, sonst zeigt die
  /// Karte dort im besten Fall die ganze Welt und im schlechtesten Fall den
  /// falschen Ausschnitt.
  double get longitudeSpanInDegrees =>
      northEast.longitude - southWest.longitude;

  @override
  bool operator ==(Object other) =>
      other is MapPositionRect &&
      other.southWest == southWest &&
      other.northEast == northEast;

  @override
  int get hashCode => Object.hash(southWest, northEast);

  @override
  String toString() =>
      'MapPositionRect(southWest: $southWest, northEast: $northEast)';
}
