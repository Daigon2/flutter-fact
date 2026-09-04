/// Wann der Avatar läuft und wann er steht,
/// `02_Frontend/app/screen-map.jsx:2624-2634`.
///
/// ## Die Regel in einem Satz
///
/// Bewegt sich die Ortung um mehr als 1,5 Meter, läuft die Figur drei Sekunden
/// lang; jede weitere Bewegung stellt die drei Sekunden neu.
///
/// ## Warum das zwei reine Funktionen sind und keine Klasse mit Zeitgeber
///
/// Die Quelle löst es mit `setTimeout` und `clearTimeout`, und der
/// eingefrorene Port mit `Timer` und `setState`
/// (`08_Flutter/lib/screens/map_screen.dart:227-239`). Beides vermischt zwei
/// Dinge: **wann** gelaufen wird, und **wer** den Bildaufbau anstößt.
///
/// Hier ist das getrennt. [avatarWalkUntil] rechnet aus zwei Ortungen und der
/// Uhr einen Zeitpunkt, [avatarAnimationAt] liest daraus die Animation. Kein
/// Zustand, kein Zeitgeber, kein `mounted`. Der Zeitgeber gehört dem Widget
/// und tut dort nur noch eine Sache: nach Ablauf einen Bildaufbau anfordern.
///
/// Der Gewinn ist prüfbar: „nach 2,9 Sekunden läuft sie noch, nach 3,1 nicht
/// mehr" ist ein Test über zwei Zahlen und kein Test über einen Zeitgeber.
///
/// ## Die Richtung dreht die Figur nicht
///
/// Ausdrücklich festgehalten, weil es die naheliegende Erwartung ist: die
/// Peilung geht **nicht** an den Avatar. Die Quelle dreht stattdessen die
/// **Karte** über den Kompass, und genau das baut Schritt 14. Der Kommentar im
/// eingefrorenen Port sagt es wörtlich: „Heading rotiert NICHT die Figur (die
/// PWA dreht stattdessen die Karte via Kompass)". Eine Figur, die sich dreht,
/// während sich die Karte unter ihr mitdreht, zeigte die Richtung zweimal.
library;

import 'package:fact_app/map/domain/map_position.dart';

/// Die Animationen, die `tourist-character.js` kennt.
///
/// Drei und nicht zwei: `wave` gibt es in der Figur (`play('wave')`), und die
/// Quelle ruft es an dieser Stelle nicht auf. Aufgenommen, weil ein
/// Wertebereich, der die Hälfte seiner Fälle verschweigt, beim nächsten
/// Gebrauch eine Erweiterung erzwingt; benutzt wird heute nur `idle` und
/// `walk`.
enum AvatarAnimation {
  /// Steht und atmet.
  idle('idle'),

  /// Geht.
  walk('walk'),

  /// Winkt. Von keinem Aufrufer benutzt, in der Figur vorhanden.
  wave('wave');

  const AvatarAnimation(this.jsName);

  /// Der Name, den `FactAvatar.setAnim` erwartet.
  final String jsName;
}

/// Wer die Figur ist.
///
/// ## Es gibt heute keine Wahl, und `male` ist die Vorgabe der Quelle
///
/// `tourist-character.js` nimmt `gender: 'male' | 'female'` und fällt selbst
/// auf `male` zurück. Die Quelle liest die Wahl aus dem Speicher; im Neubau
/// gibt es weder Einstellungs-Bildschirm noch Profilfeld dafür, also steht sie
/// fest.
///
/// Das ist eine Vorgabe und keine Entscheidung über das Produkt: sobald es
/// einen Ort gibt, an dem man sie ändern kann, wird sie gelesen statt gesetzt.
/// Aufgenommen als offene Entscheidung.
enum AvatarGender {
  /// Vorgabe.
  male('male'),

  /// Zweite Fassung derselben Figur.
  female('female');

  const AvatarGender(this.jsName);

  /// Der Name, den `FactAvatar.setGender` erwartet.
  final String jsName;
}

/// Ab welcher Bewegung die Figur losläuft, `moved > 1.5`
/// (`screen-map.jsx:2627`).
///
/// **Streng größer und nicht größer-gleich**, wie in der Quelle. Bei genau 1,5
/// Metern läuft sie nicht. Der Unterschied ist an einer stehenden Ortung
/// messbar: GPS-Rauschen liegt oft bei ein bis zwei Metern, und eine Figur,
/// die im Stehen läuft, ist die auffälligere Störung.
const double avatarWalkThresholdInMeters = 1.5;

/// Wie lange sie nach einer Bewegung weiterläuft, `setTimeout(…, 3000)`
/// (`screen-map.jsx:2630-2632`).
///
/// Die Zahl ist eine Entscheidung der Quelle und keine Physik: sie überbrückt
/// die Lücke zwischen zwei Ortungen. Ein Wert unter dem Ortungsabstand ließe
/// die Figur zwischen zwei Schritten stehenbleiben.
const Duration avatarWalkDuration = Duration(seconds: 3);

/// Bis wann die Figur laufen soll, nachdem [current] eingetroffen ist.
///
/// [previous] ist die vorige Ortung, `null` bei der ersten. [walkUntil] ist der
/// bisherige Zeitpunkt, `null`, wenn sie steht.
///
/// **Die erste Ortung lässt sie nicht laufen.** Ohne Vorgänger gibt es keine
/// Strecke, und eine Figur, die beim ersten GPS-Empfang losläuft, behauptet
/// eine Bewegung, die niemand gemacht hat. Die Quelle prüft dafür `if (prev &&
/// …)` (`:2625`).
///
/// **Eine zu kleine Bewegung verlängert nicht und verkürzt auch nicht.** Der
/// bisherige Zeitpunkt bleibt stehen: wer läuft und dessen Ortung einmal um
/// einen halben Meter springt, läuft weiter. Die Quelle macht es genauso, sie
/// ruft `clearTimeout` nur im Zweig über der Schwelle.
DateTime? avatarWalkUntil({
  required MapPosition current,
  required DateTime now,
  MapPosition? previous,
  DateTime? walkUntil,
}) {
  if (previous == null) {
    return walkUntil;
  }
  if (previous.distanceInMetersTo(current) <= avatarWalkThresholdInMeters) {
    return walkUntil;
  }
  return now.add(avatarWalkDuration);
}

/// Welche Animation zu [walkUntil] gehört, gemessen an [now].
///
/// **Der Ablauf ist einschließend**: genau auf dem Zeitpunkt läuft sie nicht
/// mehr. Das ist die Lesart, die zu [avatarWalkUntil] passt, denn dort wird
/// `now + 3s` gesetzt; wäre der Vergleich hier `<=`, dauerte das Laufen einen
/// Wimpernschlag länger als drei Sekunden. Der Unterschied ist unsichtbar und
/// die Festlegung trotzdem nötig, sonst entscheidet sie ein Zufall im Test.
AvatarAnimation avatarAnimationAt(DateTime? walkUntil, DateTime now) {
  if (walkUntil == null) {
    return AvatarAnimation.idle;
  }
  return now.isBefore(walkUntil) ? AvatarAnimation.walk : AvatarAnimation.idle;
}
