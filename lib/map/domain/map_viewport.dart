/// Wie groß die Kartenfläche auf dem Bildschirm ist, in **Stilpixeln**.
///
/// ## Warum die Einheit der ganze Grund für diesen Typ ist
///
/// Zwei Zahlen `width` und `height` sagen nichts darüber, in welcher Einheit
/// sie gemeint sind, und eine Verwechslung wäre lautlos: derselbe Fehler wie
/// bei `MapScreenPoint`, dessen Kopfkommentar das ausführlich herleitet.
/// Deshalb trägt der Feldname hier die Einheit, genau wie bei
/// `MapOverlayGrouping.radiusInScreenPixels` (`map_overlay.dart:145`), das
/// bis zu diesem Typ die einzige Bildschirmeinheit im ganzen Kartenvertrag
/// war.
///
/// ## Stilpixel, nicht Gerätepixel, und wer umrechnet
///
/// Das ist die tragende Unterscheidung dieses Typs, und sie kostet, wenn sie
/// verwechselt wird: `MapScreenPoint` (`map_screen_point.dart`) trägt
/// **Geräte-Pixel**, weil `MapLibreMapController.toScreenLocation`
/// (`maplibre_gl 0.26.2`, `controller.dart:1779`) genau die liefert, am Gerät
/// gemessen am 30.08.2026 und in jenem Kommentar dokumentiert. Ein
/// [MapViewport] ist etwas anderes: er beschreibt die **Größe der
/// Kartenfläche im Flutter-Layout**, also in logischen Pixeln, den Pixeln,
/// mit denen `RenderBox.size`, `LayoutBuilder` und `MediaQuery.size` rechnen.
/// `map/domain/map_camera_fit.dart` nennt diese Einheit „Stilpixel", weil sie
/// dieselbe ist, in der ein Karten-Stil seine Zoomstufen definiert
/// (Web-Mercator-Kachelgröße mal Zoomfaktor, unabhängig vom
/// Geräte-Pixelverhältnis).
///
/// Wer diesen Typ befüllt, tut das aus der Breite und Höhe der
/// **Layout-Größe** der Kartenfläche (etwa aus `LayoutBuilder.constraints`
/// oder `RenderBox.size` im Karten-Host), **nicht** aus
/// `MediaQuery.size * MediaQuery.devicePixelRatio` und nicht aus einem
/// Ergebnis von `toScreenLocation`. Eine Umrechnung zwischen den beiden
/// Bildschirmeinheiten findet nirgends im Kartenvertrag statt: sie sind zwei
/// verschiedene Verwendungen, keine zwei Darstellungen derselben Größe, so
/// wie es der Kopfkommentar von `map_screen_point.dart` für den
/// Gruppierungsradius bereits festhält.
///
/// **Seit dem 31.08.2026 gibt es eine Rechnung, die beide Einheiten in einer
/// Formel braucht, und sie steht bewusst nicht hier.** Der Horizont der
/// geneigten Karte (`map_camera_horizon.dart`, D-17) folgt aus der Höhe der
/// Kartenfläche und der Neigung, und er muss im Geräteraster herauskommen,
/// weil die Projektion dort antwortet. Umgerechnet wird deshalb im
/// Karten-Host, an einer benannten Stelle, aus diesem Typ mal dem
/// Skalierungsfaktor der Fläche, den `MapSurface` mitmeldet
/// (`map_camera_host.dart`, `handleViewportChange`). Dieser Typ bleibt
/// Stilpixel, der Vertrag rechnet weiter nicht um, und die Aussage oben gilt
/// unverändert für alles, was in `map/domain/` liegt.
///
/// `final class`, weil der Typ Wertgleichheit hat, aus demselben Grund wie
/// `MapPosition`: eine offene Klasse mit `==` würde bei einer Unterklasse mit
/// einem dritten Feld zu asymmetrischer Gleichheit führen.
library;

/// Die Größe der Kartenfläche, in Stilpixeln (logischen Pixeln).
final class MapViewport {
  /// Erzeugt eine Kartenflächen-Größe, ohne Prüfung.
  ///
  /// Weder Breite noch Höhe werden hier auf positive Werte geprüft. Vor dem
  /// ersten Layout ist eine Größe von null nicht die Ausnahme, sondern der
  /// erwartbare Startzustand, und `rectFitZoom` behandelt genau diesen Fall
  /// ausdrücklich, siehe `map_camera_fit.dart`.
  const MapViewport({
    required this.widthInScreenPixels,
    required this.heightInScreenPixels,
  });

  /// Breite der Kartenfläche, in Stilpixeln.
  final double widthInScreenPixels;

  /// Höhe der Kartenfläche, in Stilpixeln.
  final double heightInScreenPixels;

  @override
  bool operator ==(Object other) =>
      other is MapViewport &&
      other.widthInScreenPixels == widthInScreenPixels &&
      other.heightInScreenPixels == heightInScreenPixels;

  @override
  int get hashCode => Object.hash(widthInScreenPixels, heightInScreenPixels);

  /// Mit den Zahlen, anders als `MapPosition.toString()`.
  ///
  /// Eine Flächengröße ist keine Standortangabe, `security.md` §6 betrifft
  /// sie nicht, und ohne die Zahlen wäre die Ausgabe für die Diagnose
  /// wertlos, um die es hier geht: „hat der Host eine Fläche von null
  /// Pixeln übergeben bekommen".
  @override
  String toString() =>
      'MapViewport($widthInScreenPixels x $heightInScreenPixels '
      'in Stilpixeln)';
}
