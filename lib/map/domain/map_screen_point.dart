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
/// ## Was „Bildschirmpixel" hier heißt, seit dem 30.08.2026 gemessen
///
/// Der Nullpunkt ist die **linke obere Ecke der Karte**, nicht die des
/// Bildschirms (`maplibre_gl 0.26.2`, `lib/src/controller.dart:1779`). Solange
/// die Kartenfläche den ganzen Bildschirm füllt, ist das dasselbe; sobald sie
/// es nicht mehr tut, ist es der Unterschied zwischen richtig und um die
/// Kopfhöhe verschoben.
///
/// **Am 30.08.2026 am Gerät entschieden: es sind Geräte-Pixel.** Dieselbe Zeile
/// sagt „screen pixels (not display pixels)", und dieser Satz konnte beides
/// heißen. Gemessen wurde nicht über einen Bildvergleich, sondern über die
/// projizierte **Kameramitte**: sie kommt auf (540,75 | 1200,94) heraus, bei
/// einer Kartenfläche von 1080 × 2400 Geräte-Pixeln und einem
/// Skalierungsfaktor von 2,625. Die Mitte der Fläche liegt bei (540 | 1200).
/// Damit sind Maßstab und Nullpunkt in einem Messsatz geklärt: der Faktor ist
/// der Skalierungsfaktor, einen Versatz gibt es nicht. Zahlen und Gegenprobe
/// in `REBUILD_STATUS.md` unter „Ungefragter Fund A".
///
/// **Die Umrechnung steht an genau einer Stelle**, so wie es der Aufbau
/// vorsah: `fact_balloon_overlay.dart`, dort wo eine Bildschirmlage zu einem
/// `Positioned` wird. Dieser Typ trägt die rohe Einheit des SDK, damit die
/// Umrechnung sichtbar bleibt statt sich über den Vertrag zu verteilen.
///
/// **Der Feldname sagt die Einheit nicht.** `xInScreenPixels` bliebe auch dann
/// stehen, wenn jemand den Wert für logische Pixel hielte; ehrlicher wäre
/// `xInDevicePixels`. Umbenannt ist er trotzdem nicht, weil
/// `MapOverlayGrouping.radiusInScreenPixels` **eine andere Einheit** meint,
/// nämlich die Stilpixel des Cluster-Radius, und eine pauschale Umbenennung
/// die beiden verschmölze. Der Umbau ist damit ein eigener Vorgang und kein
/// Nebeneffekt einer Fehlerbehebung.
library;

/// Ein Punkt in der Fläche der Karte, in **Geräte-Pixeln**.
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

  /// Abstand vom linken Rand der Karte, in Geräte-Pixeln.
  final double xInScreenPixels;

  /// Abstand vom oberen Rand der Karte, in Geräte-Pixeln.
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
