/// Eine Blickrichtung des Geräts, so wie der Orientierungsdienst sie liefert.
///
/// ## Was hier ausdrücklich fehlt: der Bezugsrahmen
///
/// [DeviceHeading] trägt eine Gradzahl und sonst nichts. Wogegen sie gemessen
/// ist, magnetisch Nord, wahr Nord oder ein beliebiger Startwert, entscheidet
/// nicht dieser Typ, sondern der Dienst, der ihn erzeugt.
/// `RotationSensorOrientationService` setzt magnetisch Nord, mit Begründung
/// dort. Ein zweites Feld dafür wäre eine Wiederholung derselben Entscheidung
/// an zwei Stellen, und die offene Frage E-59, ob die App künftig wahr Nord
/// braucht (etwa für eine Kompassnadel, die auf einen Fakt statt auf eine
/// Bildschirmkante zeigt), bliebe trotzdem offen. Sie gehört an den Dienst, der
/// die Wahl trifft, nicht an den Wert, der das Ergebnis trägt.
///
/// ## Normalisieren ist hier kein Reparieren
///
/// Ein Winkel ist eine Restklasse modulo 360: `-90` und `270` bezeichnen
/// dieselbe Richtung, genauso wie `450` und `90`. [tryFrom] bildet deshalb
/// jeden endlichen Wert auf sein kanonisches Element in `[0, 360)` ab, statt
/// Werte außerhalb dieses Bereichs abzulehnen. Das ist keine Nachsicht mit
/// einer falschen Eingabe, so wie `ActiveHunt.tryFrom` freigeschaltete
/// Hinweise sortiert und Duplikate entfernt: beides wählt nur eine kanonische
/// Darstellung desselben Werts, es biegt keinen kaputten zurecht.
///
/// `-90` entsteht in der Praxis nicht aus Bosheit: ein Kompass, der bei 0°
/// vorbeidreht, oder eine Rechnung, die eine Differenz statt einer absoluten
/// Richtung liefert, erzeugt genau solche Werte, und sie sind so gültig wie
/// jeder Wert in `[0, 360)`.
///
/// ## Warum `NaN` trotzdem abgewiesen wird
///
/// `NaN` ist keine Richtung, es ist die Abwesenheit einer Antwort, und keine
/// Normalisierung macht daraus eine. Der zweite, technische Grund steht schon
/// bei `ActiveHunt.tryFrom`
/// (`lib/features/challenges/domain/entities/active_hunt.dart`): in Dart ist
/// `double.nan == double.nan` falsch, ein [DeviceHeading] mit `NaN`-Gradzahl
/// wäre also sich selbst nicht gleich, und in einem `Provider<DeviceHeading?>`
/// sähe jede Neuberechnung wie eine Änderung aus, obwohl sich nichts geändert
/// hat. Die beiden Unendlichkeiten tragen dieselbe Abwesenheit einer Richtung
/// und werden aus demselben ersten Grund verworfen; das zweite,
/// Gleichheits-Argument träfe auf sie gar nicht zu, `double.infinity ==
/// double.infinity` ist wahr.
library;

/// Eine geprüfte Blickrichtung in Grad, kanonisch in `[0, 360)`.
///
/// `final class`, weil der Typ Wertgleichheit hat: eine Unterklasse mit einem
/// vierten Feld wäre nach diesem `==` gleich einem [DeviceHeading], umgekehrt
/// aber nicht.
final class DeviceHeading {
  /// Erzeugt eine Blickrichtung ohne Prüfung. **Privat**, siehe [tryFrom]: der
  /// einzige Weg zu einem Wert ist die geprüfte und normalisierte Fassung, es
  /// gibt kein [DeviceHeading] mit `NaN`, einer Unendlichkeit oder einem Wert
  /// außerhalb von `[0, 360)`.
  const DeviceHeading._(this.degrees);

  /// Die Blickrichtung in Grad, kanonisch im Bereich `[0, 360)`.
  ///
  /// Gemessen gegen den Bezugsrahmen, den der erzeugende Dienst gewählt hat,
  /// siehe den Kopfkommentar dieser Datei.
  final double degrees;

  /// Prüft [degrees] und normalisiert sie, oder gibt `null` zurück, wenn kein
  /// endlicher Wert vorliegt.
  ///
  /// `NaN`, `double.infinity` und `double.negativeInfinity` ergeben `null`,
  /// siehe die Begründung im Kopfkommentar. Jeder andere Wert wird per `%`
  /// auf sein kanonisches Element in `[0, 360)` abgebildet: Darts `%` liefert
  /// bei positivem Divisor immer ein nicht-negatives Ergebnis, anders als in
  /// JavaScript, siehe dieselbe Eigenschaft bei
  /// `shortestBearingDeltaDegrees` in `lib/map/domain/map_camera_gate.dart`.
  /// `-90 % 360` ergibt damit `270`, und `450 % 360` ergibt `90`.
  static DeviceHeading? tryFrom(double degrees) {
    if (!degrees.isFinite) {
      return null;
    }
    return DeviceHeading._(degrees % 360);
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceHeading && other.degrees == degrees;

  @override
  int get hashCode => degrees.hashCode;

  @override
  String toString() => 'DeviceHeading(degrees: $degrees)';
}
