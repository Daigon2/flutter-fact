/// Die Glättung der Kompass-Blickrichtung, und der Wachhund, der einen toten
/// Kompass erkennt. Beides reine Rechnung, ohne Flutter, ohne Riverpod und
/// ohne `flutter_rotation_sensor`.
///
/// ## Die Formel, wörtlich aus der Quelle
///
/// `02_Frontend/app/screen-map.jsx:2831-2832`:
/// ```js
/// const diff = ((heading - smoothBearing + 540) % 360) - 180;
/// smoothBearing = (smoothBearing + diff * 0.25 + 360) % 360;
/// ```
/// [SmoothedBearing.towards] baut das nach, mit derselben Rolle für jede
/// Variable: `smoothBearing` ist [SmoothedBearing.degrees], `heading` ist das
/// Argument, `0.25` ist [SmoothedBearing.smoothingFactor]. Die
/// `+540) % 360) - 180`-Konstruktion in der ersten Zeile ist bereits als
/// `shortestBearingDeltaDegrees` in `lib/map/domain/map_camera_gate.dart`
/// gebaut, geprüft und dokumentiert; diese Datei ruft sie auf, statt dieselbe
/// Rechnung ein zweites Mal hinzuschreiben. Getrennte Kopien derselben Formel
/// sind genau das Risiko, das `map_camera_gate.dart` im eigenen
/// Kopfkommentar für die Schwellwerte beschreibt: „Getrennt driften sie."
///
/// **Warum die `+540`-Konstruktion die kürzere Drehrichtung wählt.** `diff`
/// ist eine Winkeldifferenz, aber der Rest-Operator allein lieferte bei einem
/// Sprung von 350° nach 10° die falsche Zahl: `10 - 350 = -340`, und eine
/// Drehung um -340° sieht zwar am Ziel richtig aus, dreht die Karte aber fast
/// einmal ganz herum. Die `540`, das Dreifache von `180`, verschiebt den Wert
/// so, dass der anschließende `% 360` ihn auf `[0, 360)` faltet, bevor `180`
/// wieder abgezogen wird; das Ergebnis liegt danach immer in `(-180, 180]` und
/// ist damit immer die **kürzere** der beiden möglichen Drehrichtungen. Für
/// 350° nach 10° liefert das `+20`, für 10° nach 350° liefert es `-20`, beides
/// eine Vierteldrehung in die jeweils nähere Richtung und keine fast volle
/// Umdrehung. Ein Test sichert beide Richtungen des Sprungs zu.
///
/// ## Was hier ausdrücklich fehlt: die Winkel-Totzone
///
/// Die 1,5°-Totzone, ab der die Karte einer neuen Blickrichtung überhaupt
/// folgt, steht bereits als `MapCameraThresholds.bearingDeadZoneDegrees` in
/// `map_camera_gate.dart`. Eine zweite Stelle dafür wäre eine zweite Wahrheit
/// über dieselbe Zahl, mit demselben Driftrisiko wie oben. Diese Datei
/// glättet nur; ob die Karte die geglättete Blickrichtung überhaupt anfährt,
/// entscheidet das Gate.
///
/// ## Der Wachhund kennt keine Uhr
///
/// [isCompassStale] nimmt eine bereits verstrichene [Duration] entgegen und
/// nicht `DateTime.now()`. Dieselbe Begründung wie in `map_camera_gate.dart`:
/// eine Domäne, die die Uhr selbst liest, ist ohne Warten nicht testbar, und
/// `DateTime.now()` kann rückwärts springen. Es steht auch kein `Timer` hier,
/// das im 2-Sekunden-Takt prüft (`screen-map.jsx:2846-2853`): der Takt ist
/// Oberflächenverhalten und gehört dorthin, wo die Uhr tatsächlich läuft.
library;

import 'package:fact_app/map/domain/map_camera_gate.dart'
    show shortestBearingDeltaDegrees;

/// Die geglättete Kompass-Blickrichtung, ein exponentiell gleitender
/// Mittelwert über die rohen Werte des Kompasses.
///
/// `final class`, weil der Typ Wertgleichheit hat: eine Unterklasse mit einem
/// vierten Feld wäre nach diesem `==` gleich einer [SmoothedBearing],
/// umgekehrt aber nicht, dasselbe Argument wie bei `DevicePosition` in
/// `lib/services/location/device_position.dart`.
final class SmoothedBearing {
  /// Erzeugt eine geglättete Blickrichtung ohne Prüfung. Anders als
  /// `DeviceHeading.tryFrom` bewusst offen: der Startwert einer Glättung ist
  /// keine gespeicherte Nutzlast, und der einzige Aufrufer, der `degrees`
  /// wählt, ist bereits eine geprüfte `DeviceHeading`.
  const SmoothedBearing(this.degrees);

  /// Der Glättungsfaktor der Quelle, `0.25` in `screen-map.jsx:2831`. Als
  /// statische Konstante mit Fundstelle, damit niemand ihn ohne Beleg ändert.
  static const double smoothingFactor = 0.25;

  /// Die geglättete Blickrichtung in Grad, im Bereich `[0, 360)`.
  final double degrees;

  /// Nähert die Glättung um [smoothingFactor] an [heading] an, über die
  /// kürzere Drehrichtung, siehe den Kopfkommentar dieser Datei.
  ///
  /// Ist [heading] bereits gleich [degrees], ändert sich nichts: `diff` ist
  /// dann `0`, und `degrees + 0 * smoothingFactor` bleibt `degrees`. Die
  /// Glättung hat damit einen Fixpunkt genau am Ziel und schießt nicht
  /// darüber hinaus.
  SmoothedBearing towards(double heading) {
    final double diff = shortestBearingDeltaDegrees(degrees, heading);
    return SmoothedBearing((degrees + diff * smoothingFactor + 360) % 360);
  }

  @override
  bool operator ==(Object other) =>
      other is SmoothedBearing && other.degrees == degrees;

  @override
  int get hashCode => degrees.hashCode;

  @override
  String toString() => 'SmoothedBearing(degrees: $degrees)';
}

/// Wie lange ohne ein Kompass-Ereignis der Kompass als tot gilt.
///
/// `screen-map.jsx:2846-2853`, dort geprüft im 2-Sekunden-Takt gegen
/// `Date.now() - lastCompassEventTime`. Die 5 Sekunden selbst stehen dort als
/// Schwelle, gegen die dieser Takt vergleicht; der Takt ist Sache der
/// Oberfläche, siehe den Kopfkommentar dieser Datei.
const Duration compassStaleAfter = Duration(seconds: 5);

/// Gilt der Kompass als tot, wenn seit dem letzten Ereignis [sinceLastHeading]
/// vergangen ist?
///
/// **Echt größer**, wie `Date.now() - last > 5000` in der Quelle: genau
/// [compassStaleAfter] gilt noch als lebendig, erst eine Überschreitung zählt
/// als tot.
bool isCompassStale({required Duration sinceLastHeading}) =>
    sinceLastHeading > compassStaleAfter;
