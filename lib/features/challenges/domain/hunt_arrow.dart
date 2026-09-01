/// Der Richtungspfeil zu einer Jagd-Station, aus einer Peilung in Grad.
///
/// ## Warum eine eigene Datei und nicht bei den Navigationshilfen
///
/// `hunt_navigation_aids.dart` beantwortet **ob** überhaupt navigiert werden
/// darf (Pfeil, Distanz, beides, nichts), gestaffelt nach
/// [PuzzleDifficulty]. Diese Datei beantwortet eine ganz andere Frage: **wie**
/// eine Peilung in Grad auf einen von acht Pfeilen abbildet, unabhängig davon,
/// ob die aufrufende Stelle den Pfeil überhaupt zeigen darf. Eine Jagd mit
/// Schwierigkeit `schwer` hat trotzdem eine Peilung zur Station, sie wird nur
/// nirgends angezeigt. Die beiden Fragen haben nichts miteinander zu tun
/// außer dem gemeinsamen Thema „Navigation", und ein Import würde in keine
/// Richtung gebraucht: [huntArrowIndexFor] kennt keine
/// [PuzzleDifficulty], und `HuntNavigationAids` kennt keine Peilung.
/// Getrennte Dateien halten diese Unabhängigkeit sichtbar, so wie
/// `hunt_duration.dart` und `active_hunt.dart` schon getrennt sind, obwohl
/// beide zur selben Jagd gehören.
///
/// ## Die Formel der Quelle
///
/// `screen-map.jsx:1056-1059`:
///
/// ```js
/// function bearingToArrow(deg) {
///   const arrows = ['↑','↗','→','↘','↓','↙','←','↖'];
///   return arrows[Math.round(((deg % 360) + 360) / 45) % 8];
/// }
/// ```
///
/// [huntArrowIndexFor] bildet nur den Index, nicht die Glyphe: Pfeilzeichen
/// sind Oberflächentext und kommen erst mit dem Widget, das sie zeigt.
///
/// ## Nachgerechnet, nicht übersetzt: `%` bei negativen Zahlen
///
/// JavaScripts `%` behält das Vorzeichen des Dividenden: `-10 % 360` ist in
/// JavaScript `-10`. Genau deshalb steht in der Quelle das `+ 360` danach,
/// als Korrektur für negative Peilungen.
///
/// Darts `%` tut das **nicht**. Ich habe es nachgemessen, nicht angenommen:
///
/// ```
/// -10 % 360   ==  350   (Dart)
/// -45 % 360   ==  315   (Dart)
/// -450 % 360  ==  270   (Dart)
/// ```
///
/// Dart liefert bei `a % b` mit positivem `b` immer ein Ergebnis in
/// `[0, b)`, also nach derselben Euklidischen Regel, die die Quelle mit ihrem
/// eigenen `+ 360` erst herstellen muss. Das `+ 360` in [huntArrowIndexFor]
/// unten ist damit in Dart **beweisbar überflüssig**, denn `bearingDegrees %
/// 360` liegt hier schon in `[0, 360)`, und eine weitere volle Umdrehung
/// (`+360`, die nach der Division durch 45 und vor dem `% 8` wieder
/// herausfällt) ändert am Endergebnis nichts. Ich lasse es trotzdem stehen:
/// es hält den Code Zeile für Zeile neben der Quelle lesbar, und „beweisbar
/// wirkungslos" ist ein anderer Zustand als „vergessen zu prüfen". Wer diese
/// Zeile künftig vereinfacht, verändert damit kein Verhalten.
///
/// **Was NICHT überflüssig ist:** das Nachrechnen selbst. Eine reine
/// Übersetzung von `((deg % 360) + 360) / 45` ohne diese Prüfung hätte
/// unterstellt, Darts `%` verhalte sich wie JavaScripts, und das ist falsch.
/// Für **negative Eingaben, die nicht auf `deg % 360` reduziert werden**, wäre
/// das ein echter Fehler gewesen, siehe den nächsten Abschnitt.
///
/// ## Nachgerechnet: `Math.round` gegen `.round()` bei `.5`
///
/// JavaScripts `Math.round` rundet `.5` immer aufwärts: `Math.round(-0.5)` ist
/// `-0`. Darts `.round()` rundet `.5` von der Null weg: nachgemessen liefert
/// `(-0.5).round()` in Dart `-1`, nicht `0`. Für positive Zahlen fallen beide
/// Regeln zusammen (`(2.5).round()` ist in beiden Sprachen `3`), sie
/// unterscheiden sich einzig bei einer **negativen** `.5`-Zahl.
///
/// Erreicht [huntArrowIndexFor] diesen Unterschied? Das Argument von
/// `.round()` ist hier `((bearingDegrees % 360) + 360) / 45`. Weil Darts `%`
/// für den positiven Teiler `360` immer ein Ergebnis in `[0, 360)` liefert,
/// ist dieser Ausdruck für **jede** endliche `bearingDegrees` mindestens `360
/// / 45 = 8`, also nie negativ. Der Unterschied zwischen den beiden
/// Rundungsregeln ist damit in dieser Formel **unerreichbar**, und zwar nicht
/// aus Zufall, sondern weil die Normalisierung über `%` ihn strukturell
/// ausschließt. Das habe ich mit einer Gegenprobe geprüft: eine **naive**
/// Übersetzung ohne die Normalisierung, `(deg / 45).round() % 8`, rundet bei
/// `deg = -22.5` das Zwischenergebnis `-0.5` **direkt**, und dort schlägt der
/// Unterschied zu: `(-22.5 / 45).round()` ist in Dart `-1` (von Null weg), was
/// nach `% 8` (Dart, ebenfalls Euklidisch für int) `7` ergibt, während die
/// korrekte Formel für `-22.5` (dasselbe wie `337,5`, das zwischen dem
/// Pfeil für `315` und dem für `360`/`0` liegt) `0` liefert. Genau dieser
/// Fall steht deshalb als eigener Test in der Testdatei, zusätzlich zu den
/// im Auftrag genannten Fällen: er ist der einzige unter den hier
/// erreichbaren Eingaben, an dem die fehlende Normalisierung sichtbar
/// **falsch** würde statt nur zufällig richtig zu bleiben.
library;

/// Der Index (0 bis 7) des Pfeils, der am ehesten in Richtung [bearingDegrees]
/// zeigt. Index 0 ist Norden (nach oben), die Zählung geht im Uhrzeigersinn in
/// 45-Grad-Schritten weiter, wie `arrows` in der Quelle. Die Glyphen selbst
/// gehören der Oberfläche.
int huntArrowIndexFor(double bearingDegrees) {
  final double normalized = ((bearingDegrees % 360) + 360) / 45;
  return normalized.round() % 8;
}
