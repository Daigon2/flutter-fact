/// Wo ein Kartenpunkt auf dem Bildschirm liegt.
///
/// ## Warum das ein eigener Typ ist und nicht `Point` aus `dart:math`
///
/// Weil die **Einheit** die ganze Aussage ist. `Point(120, 340)` sagt nicht, ob
/// das logische Pixel, Geräte-Pixel, Grad oder Meter sind, und eine
/// Verwechslung wäre lautlos: eine Überlagerung säße auf einem 3x-Gerät um den
/// Faktor drei daneben, ohne Fehler und ohne Warnung.
///
/// Der Präzedenzfall steht im selben Verzeichnis:
/// `MapOverlayGrouping.radiusInScreenPixels` trägt die Einheit aus genau
/// diesem Grund im Feldnamen, und ihr Kommentar sagt, dass sie bis heute die
/// einzige Bildschirmeinheit des Kartenvertrags war. Ab hier sind es zwei.
///
/// ## Was „Bildschirmpixel" hier heißt, und was daran offen ist
///
/// Der Nullpunkt ist die **linke obere Ecke der Karte**, nicht die des
/// Bildschirms (`maplibre_gl 0.26.2`, `lib/src/controller.dart:1779`). Solange
/// die Kartenfläche den ganzen Bildschirm füllt, ist das dasselbe; sobald sie
/// es nicht mehr tut, ist es der Unterschied zwischen richtig und um die
/// Kopfhöhe verschoben.
///
/// **Offen und nur auf einem Gerät zu beantworten:** dieselbe Zeile sagt
/// „screen pixels (not display pixels)", und dieser Satz kann beides heißen.
/// Liegt dort das Geräteraster statt des logischen, sitzt jede Überlagerung um
/// das Bildverhältnis daneben, also auf einem heutigen Telefon um den Faktor
/// drei. Der Aufrufer muss deshalb so gebaut sein, dass **eine** Messung am
/// Gerät die Frage entscheidet und nicht eine Umrechnung an fünf Stellen
/// nachgezogen werden muss.
library;

/// Ein Punkt in der Fläche der Karte, in logischen Bildschirmpixeln.
///
/// `final class`, weil der Typ Wertgleichheit hat: eine Unterklasse mit einem
/// dritten Feld wäre nach diesem `==` gleich einem [MapScreenPoint], umgekehrt
/// aber nicht, und `a == b` hinge an der Reihenfolge der Operanden. Dieselbe
/// Begründung wie bei `MapPosition`.
final class MapScreenPoint {
  /// Erzeugt einen Bildschirmpunkt.
  const MapScreenPoint({
    required this.xInScreenPixels,
    required this.yInScreenPixels,
  });

  /// Abstand vom linken Rand der Karte.
  final double xInScreenPixels;

  /// Abstand vom oberen Rand der Karte.
  final double yInScreenPixels;

  @override
  bool operator ==(Object other) =>
      other is MapScreenPoint &&
      other.xInScreenPixels == xInScreenPixels &&
      other.yInScreenPixels == yInScreenPixels;

  @override
  int get hashCode => Object.hash(xInScreenPixels, yInScreenPixels);

  /// **Mit den Zahlen**, anders als `MapPosition.toString()`.
  ///
  /// Der Unterschied ist kein Versehen: `docs/engineering/security.md` §6
  /// verbietet genaue **Standortangaben** im Log. Ein Bildschirmpunkt ist
  /// keine, er ist ohne die Kamera, die ihn erzeugt hat, nicht in einen Ort
  /// zurückzurechnen. Und ohne die Zahlen wäre eine Ausgabe für die eine
  /// Diagnose, um die es hier geht, wertlos: „sitzt die Überlagerung um den
  /// Faktor drei daneben".
  @override
  String toString() =>
      'MapScreenPoint($xInScreenPixels, $yInScreenPixels in Bildschirmpixeln)';
}
