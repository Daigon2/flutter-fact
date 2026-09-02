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
/// **Die Umrechnung steht an benannten Stellen und nicht verteilt im
/// Vertrag**, so wie es der Aufbau vorsah: zuerst `fact_balloon_overlay.dart`,
/// dort wo eine Bildschirmlage zu einem `Positioned` wird, seit
/// `discovery_balloon_anchor.dart` eine zweite, aus demselben Grund. Dieser
/// Typ trägt die rohe Einheit des SDK, damit jede Umrechnung sichtbar bleibt
/// statt sich über den Vertrag zu verteilen.
///
/// ## Das dritte Feld, seit dem 31.08.2026
///
/// Eine Bildschirmlage allein sagt nicht, ob der Punkt überhaupt vor der
/// Kamera liegt. `maplibre_gl 0.26.2` meldet einen Punkt **hinter** der Kamera
/// nicht, es liefert eine still gespiegelte Zahl, die von der Lage eines weit
/// voraus liegenden Punktes nicht zu unterscheiden ist (am 30.08.2026 am Gerät
/// gemessen, `REBUILD_STATUS.md`, „Die vier Gerätemessungen", Messung 3). Bei
/// 58 Grad Neigung liegt alles jenseits des Horizonts hinter der Kamera, der
/// Fall ist also der Normalfall und nicht exotisch.
///
/// Bis zu diesem Datum erbte jeder Verbraucher diese Lücke und beschrieb sie
/// erneut, an drei Stellen mit drei verschiedenen Folgen. **D-17 hat das am
/// 31.08.2026 entschieden:** die Antwort liegt dem Ergebnis bei, als
/// [isInFrontOfCamera], und der Host rechnet sie aus, siehe
/// `map_camera_horizon.dart`. Nicht gewählt wurde `null` für einen solchen
/// Punkt, denn „keine Bildschirmlage" und „Lage bekannt, liegt aber hinter der
/// Kamera" sind zwei verschiedene Aussagen: `discovery_balloon_anchor.dart`
/// braucht die Unterscheidung, weil ein Punkt hinter der Kamera eine Lage hat,
/// nur eben nicht mitspielen darf.
///
/// **Der Feldname sagt die Einheit nicht.** `xInScreenPixels` bliebe auch dann
/// stehen, wenn jemand den Wert für logische Pixel hielte; ehrlicher wäre
/// `xInDevicePixels`. Umbenannt ist er trotzdem nicht, weil
/// `MapOverlayGrouping.radiusInScreenPixels` **eine andere Einheit** meint,
/// nämlich die Stilpixel des Cluster-Radius, und eine pauschale Umbenennung
/// die beiden verschmölze. Der Umbau ist damit ein eigener Vorgang und kein
/// Nebeneffekt einer Fehlerbehebung.
library;

/// Ein Punkt in der Fläche der Karte, in **Geräte-Pixeln**, mit der Aussage,
/// ob er vor der Kamera liegt.
///
/// `final class`, weil der Typ Wertgleichheit hat: eine Unterklasse mit einem
/// **zusätzlichen** Feld wäre nach diesem `==` gleich einem [MapScreenPoint],
/// umgekehrt aber nicht, und `a == b` hinge an der Reihenfolge der Operanden.
/// Dieselbe Begründung wie bei `MapPosition`.
///
/// **Diese Begründung stand bis zum 31.08.2026 mit dem Wort „drittes Feld" da,
/// und das dritte Feld ist inzwischen gekommen** ([isInFrontOfCamera], D-17).
/// Sie trägt trotzdem weiter, denn es ging nie um die Anzahl: `final class`
/// hält die Gleichheit dort, wo auch die Felder liegen. Der Zuwachs hat genau
/// das gezeigt, was der Verschluss verspricht: `==`, [hashCode] und
/// [toString] sind an **einer** Stelle mitgezogen, und es gibt keine
/// Unterklasse, in der jemand das vergessen konnte.
final class MapScreenPoint {
  /// Erzeugt einen Bildschirmpunkt.
  ///
  /// [isInFrontOfCamera] ist **Pflicht und hat keinen Standardwert**, obwohl
  /// „liegt vor der Kamera" der häufigere Fall ist. Ein Standard wäre hier die
  /// stille Variante: wer den Punkt baut, ohne über die Kamera nachgedacht zu
  /// haben, bekäme lautlos „liegt davor", und genau diese Sorte Ersatzwert hat
  /// in diesem Repository schon eine Probe blind gemacht
  /// (`REBUILD_STATUS.md`, „Wie Tests hier blind werden", Muster 21).
  const MapScreenPoint({
    required this.xInScreenPixels,
    required this.yInScreenPixels,
    required this.isInFrontOfCamera,
  });

  /// Abstand vom linken Rand der Karte, in Geräte-Pixeln.
  final double xInScreenPixels;

  /// Abstand vom oberen Rand der Karte, in Geräte-Pixeln.
  final double yInScreenPixels;

  /// Ob der Punkt vor der Kamera liegt und seine Bildschirmlage damit etwas
  /// bedeutet.
  ///
  /// `false` heißt: die Karte ist geneigt, der Punkt liegt jenseits des
  /// Horizonts, und [xInScreenPixels] und [yInScreenPixels] sind eine
  /// **Spiegelung**. Sie sehen aus wie eine gültige Lage, sie sind endlich, sie
  /// tragen kein `NaN`, und sie liegen in genau demselben Zahlenbereich wie ein
  /// Punkt weit voraus. Wer sie benutzt, zeichnet ein Bauteil an eine Stelle,
  /// an der es geometrisch nichts zu suchen hat.
  ///
  /// **Ein Verbraucher prüft dieses Feld, er rechnet es nicht nach.** Die Zahl
  /// entsteht im Karten-Host aus Flächenhöhe und Neigung
  /// (`map_camera_horizon.dart`); ein Feature, das sie selbst herleitete,
  /// bräuchte die Kamerastellung und baute damit die Kamerahoheit nach, siehe
  /// den Prüfstein im Kopfkommentar von `map_host.dart`.
  ///
  /// `false` heißt **nicht** „unsichtbar". Ein Punkt vor der Kamera kann
  /// trotzdem weit außerhalb der Fläche liegen, und das ist der Normalfall
  /// jeder Überlagerung, die mehr als den Bildausschnitt kennt. Wer
  /// Sichtbarkeit meint, prüft die Lage gegen die Fläche, so wie
  /// `selectBalloonAnchorRect` es tut.
  final bool isInFrontOfCamera;

  @override
  bool operator ==(Object other) =>
      other is MapScreenPoint &&
      other.xInScreenPixels == xInScreenPixels &&
      other.yInScreenPixels == yInScreenPixels &&
      other.isInFrontOfCamera == isInFrontOfCamera;

  @override
  int get hashCode =>
      Object.hash(xInScreenPixels, yInScreenPixels, isInFrontOfCamera);

  /// **Mit den Zahlen**, anders als `MapPosition.toString()`.
  ///
  /// Der Unterschied ist kein Versehen: `docs/engineering/security.md` §6
  /// verbietet genaue **Standortangaben** im Log. Ein Bildschirmpunkt ist
  /// keine, er ist ohne die Kamera, die ihn erzeugt hat, nicht in einen Ort
  /// zurückzurechnen. Und ohne die Zahlen wäre eine Ausgabe für die eine
  /// Diagnose, um die es hier geht, wertlos: „sitzt die Überlagerung um den
  /// Faktor drei daneben".
  ///
  /// **Mit der Lage zur Kamera im Klartext und nicht als `true`/`false`.** Die
  /// eine Diagnose, für die dieses Feld gebaut ist, lautet „warum steht da ein
  /// Ballon, wo keiner sein kann", und ein nackter Wahrheitswert am Ende der
  /// Zeile ließe offen, wozu er gehört.
  @override
  String toString() =>
      'MapScreenPoint($xInScreenPixels, $yInScreenPixels in Bildschirmpixeln, '
      '${isInFrontOfCamera ? 'vor' : 'hinter'} der Kamera)';
}
