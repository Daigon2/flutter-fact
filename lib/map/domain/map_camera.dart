/// Die drei Kamerabegriffe des Karten-Hosts: Ist-Zustand, gewünschte Änderung
/// und die Art der Bewegung.
///
/// Getrennt gehalten, weil sie drei verschiedene Dinge sind und ihre
/// Verwechslung teuer wäre. [MapCameraView] beschreibt, **wo die Kamera
/// steht**, und ist immer vollständig. [MapCameraChange] beschreibt, **was
/// sich ändern soll**, und ist absichtlich lückenhaft. [MapCameraMotion]
/// beschreibt, **wie** die Änderung stattfindet.
library;

import 'package:fact_app/map/domain/map_position.dart';

/// Der Ist-Zustand der Kamera.
///
/// Alle vier Werte sind gesetzt. Es gibt keinen Kartenzustand, in dem die
/// Kamera keinen Zoom oder keine Neigung hätte, deshalb ist hier nichts
/// `null`. Wer eine Kamera hat, die noch nicht steht, hat gar keine: das
/// drückt `MapHost.camera` mit einem `null` auf dem Ganzen aus, nicht mit
/// halb gefüllten Feldern.
///
/// `final class`, weil dieser Typ Wertgleichheit hat. Eine offene Klasse mit
/// `==` lädt zur asymmetrischen Gleichheit ein: eine Unterklasse mit einem
/// fünften Feld wäre nach diesem `==` gleich einem [MapCameraView], das
/// umgekehrt aber nicht wäre, und `a == b` hinge davon ab, welche Seite links
/// steht. Vererbung ist hier ohnehin nichts wert, der Typ ist reine Angabe.
final class MapCameraView {
  /// Erzeugt einen vollständigen Kamerazustand.
  const MapCameraView({
    required this.center,
    required this.zoom,
    required this.bearing,
    required this.pitch,
  });

  /// Mittelpunkt der sichtbaren Karte.
  final MapPosition center;

  /// Zoomstufe. Die Quelle bewegt sich zwischen 0 und `maxZoom: 20`
  /// (`screen-map.jsx:1680`).
  final double zoom;

  /// Blickrichtung in Grad, 0 heißt Norden oben.
  final double bearing;

  /// Neigung in Grad, 0 heißt senkrecht von oben.
  final double pitch;

  @override
  bool operator ==(Object other) =>
      other is MapCameraView &&
      other.center == center &&
      other.zoom == zoom &&
      other.bearing == bearing &&
      other.pitch == pitch;

  @override
  int get hashCode => Object.hash(center, zoom, bearing, pitch);

  /// Ohne den Mittelpunkt in Zahlen, siehe `MapPosition.toString()`.
  ///
  /// Zoom, Blickrichtung und Neigung sind keine Ortsangabe und bleiben
  /// sichtbar: ohne sie wäre die Ausgabe für eine Diagnose wertlos.
  @override
  String toString() =>
      'MapCameraView(center: $center, zoom: $zoom, bearing: $bearing, '
      'pitch: $pitch)';
}

/// Was sich an der Kamera ändern soll.
///
/// **`null` heißt „unverändert lassen", nicht „auf null setzen".** Das ist die
/// eine Stelle, an der dieser Typ falsch gelesen werden kann, und der Fehler
/// wäre lautlos: eine Absicht, die nur die Neigung angibt, würde die Karte
/// sonst zusätzlich auf Zoom 0 und Norden ziehen. Genau so arbeitet die
/// Quelle, deren `easeTo({ pitch: target, duration: 300 })`
/// (`screen-map.jsx:1764`) Mittelpunkt, Zoom und Blickrichtung stehen lässt.
///
/// Alle vier Felder gleichzeitig `null` ist erlaubt und bedeutet „nichts tun".
/// Der Vertrag verbietet es nicht, weil er es nicht muss: das Gate entscheidet
/// über solche Absichten dieselbe Antwort wie über jede andere, und der Host
/// hat nichts zu tun.
///
/// `final class` aus demselben Grund wie [MapCameraView]: Wertgleichheit und
/// offene Vererbung zusammen ergeben asymmetrisches `==`.
final class MapCameraChange {
  /// Erzeugt eine Änderung. Jedes ausgelassene Feld bleibt, wie es ist.
  const MapCameraChange({this.center, this.zoom, this.bearing, this.pitch});

  /// Neuer Mittelpunkt oder `null` für „Mittelpunkt behalten".
  final MapPosition? center;

  /// Neue Zoomstufe oder `null` für „Zoom behalten".
  final double? zoom;

  /// Neue Blickrichtung in Grad oder `null` für „Blickrichtung behalten".
  final double? bearing;

  /// Neue Neigung in Grad oder `null` für „Neigung behalten".
  final double? pitch;

  /// Ob diese Änderung die Blickrichtung anfasst.
  ///
  /// Das Gate braucht die Unterscheidung: das Einrasten der Blickrichtung
  /// (`manualBearingRef` in `screen-map.jsx:1692`) hält nur Absichten auf, die
  /// die Blickrichtung betreffen. Die GPS-Folgeabsicht verschiebt bloß den
  /// Mittelpunkt und läuft weiter, auch wenn der Nutzer die Karte gedreht hat.
  bool get changesBearing => bearing != null;

  @override
  bool operator ==(Object other) =>
      other is MapCameraChange &&
      other.center == center &&
      other.zoom == zoom &&
      other.bearing == bearing &&
      other.pitch == pitch;

  @override
  int get hashCode => Object.hash(center, zoom, bearing, pitch);

  @override
  String toString() =>
      'MapCameraChange(center: $center, zoom: $zoom, bearing: $bearing, '
      'pitch: $pitch)';
}

/// Wie eine [MapCameraChange] stattfindet.
///
/// ## Warum ein Typ und nicht eine Dauer, die auch null sein darf
///
/// „Sofort" ließe sich als `Duration.zero` schreiben. Dann müsste der Host aus
/// einer Zahl raten, ob eine Animation von null Millisekunden gemeint ist oder
/// ein Sprung ohne Animation, und die Antwort stünde in keinem Vertrag,
/// sondern in einer stillen Übereinkunft. Der Unterschied ist außerdem echt:
/// `jumpTo` (`screen-map.jsx:3168`) bricht eine laufende Animation ab, eine
/// Animation der Länge null täte das je nach SDK nicht.
///
/// ## Was hier fehlt und warum
///
/// Die Quelle steuert ihre `flyTo`-Aufrufe teilweise über `speed: 4.2` und
/// `curve: 1.2` statt über eine Dauer (`screen-map.jsx:1732-1739`).
/// `maplibre_gl 0.26.2` kennt für `animateCamera` nur eine optionale
/// [Duration], es gibt dort kein Gegenstück zu Geschwindigkeit und Kurve.
///
/// **Folge, die jeder kennen muss, der später eine Zahl einträgt:** jede
/// Dauer, die für einen dieser `flyTo`-Aufrufe eingesetzt wird, ist ein
/// **Ersatzwert und keine Quellenangabe**. Sie gehört als solcher
/// gekennzeichnet, damit niemand sie später für einen belegten Wert hält und
/// gegen die PWA prüft. Hier steht deshalb keine einzige konkrete Dauer: in
/// dieser Datei entstehen keine Absichten, sondern nur ihre Form.
sealed class MapCameraMotion {
  /// Für Unterklassen.
  const MapCameraMotion();
}

/// Die Änderung wird über [duration] hinweg animiert.
final class MapCameraAnimated extends MapCameraMotion {
  /// Erzeugt eine animierte Bewegung.
  const MapCameraAnimated(this.duration);

  /// Wie lange die Animation dauert.
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is MapCameraAnimated && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'MapCameraAnimated($duration)';
}

/// Die Änderung findet sofort statt, ohne Animation.
///
/// Entspricht `jumpTo` und `setBearing` der Quelle
/// (`screen-map.jsx:3168` und `:2838`).
final class MapCameraImmediate extends MapCameraMotion {
  /// Erzeugt eine sofortige Bewegung.
  const MapCameraImmediate();

  @override
  bool operator ==(Object other) => other is MapCameraImmediate;

  @override
  int get hashCode => (MapCameraImmediate).hashCode;

  @override
  String toString() => 'MapCameraImmediate()';
}
