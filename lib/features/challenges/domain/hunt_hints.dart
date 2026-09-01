/// Die gestuften Hinweise einer Jagd-Station.
///
/// ## Die drei Stufen und ihre Kosten
///
/// Aus `HuntPill` in `02_Frontend/app/screen-map.jsx:1030-1031`:
///
/// ```
/// // H1 = free, H2 = −20, H3 = −30. Kosten werden NICHT vom Wallet abgezogen,
/// // sondern beim Loesen des Faktes vom Fakt-Lohn (50 Coins) abgerechnet.
/// const HINT_COSTS = [0, 20, 30];
/// ```
///
/// Die Zahlen in [huntHintCosts] sind also **keine** Abbuchung vom Geldbeutel
/// des Spielers, sondern ein Abzug von der Belohnung, die das Lösen des Fakts
/// selbst bringt (50 Coins). Diese Datei bildet nur die drei Kosten ab; das
/// Verrechnen mit dem Fakt-Lohn passiert beim Auflösen einer Station und
/// gehört nicht hierher.
///
/// ## Warum der erste Hinweis eine eigene Funktion bekommt
///
/// Die Quelle startet den Hinweiszustand einer Station mit
/// `useState([true, false, false])` und kommentiert das mit „H1 is always
/// free" (`:1013-1014`). Der erste Hinweis ist also nicht bloß billig
/// ([huntHintCosts]`[0] == 0`), er ist auch **von Anfang an freigeschaltet**,
/// ohne dass ihn jemand kaufen muss. [isHuntHintFree] hält genau diese zweite
/// Eigenschaft fest, die aus den Kosten allein nicht folgt: eine vierte Stufe
/// mit Kosten 0 wäre nach den Kosten allein ebenfalls „gratis", müsste aber
/// trotzdem erst freigeschaltet werden, wenn sie nicht die erste ist.
///
/// ## Der Zusammenhang mit `ActiveHunt.unlockedHintIndices`
///
/// `ActiveHunt.unlockedHintIndices` speichert, welche Hinweise **gekauft**
/// wurden, seit dem 31.08.2026. Index 0 taucht darin nie auf, denn er ist
/// immer offen, ganz gleich, ob er in der gespeicherten Liste steht oder
/// nicht. Das ist kein Widerspruch, sondern die billigere der beiden
/// Darstellungen. Die Alternative wäre eine Liste, die die 0 immer mitführt.
/// Ein Wert, den kein Aufrufer setzen darf, weil er ohnehin immer da ist, und
/// den jeder Leser trotzdem prüfen müsste, ist genau die Art Zustand, die
/// dieses Feature bewusst vermeidet (vergleiche `HuntPlan`s Regel: ein Feld,
/// das immer denselben Wert trägt, sieht aus wie Zustand und ist keiner). Wer
/// wissen will, ob ein Hinweis an der aktuellen Station sichtbar ist, prüft
/// also `index == 0 || activeHunt.unlockedHintIndices.contains(index)`, und
/// [isHuntHintFree] ist die erste Hälfte dieser Prüfung.
library;

/// Die Kosten je Hinweisstufe, in Coins vom Fakt-Lohn, nicht vom Geldbeutel.
///
/// Wörtlich aus der Quelle (`screen-map.jsx:1031`): „H1 = free, H2 = −20, H3 =
/// −30. Kosten werden NICHT vom Wallet abgezogen, sondern beim Loesen des
/// Faktes vom Fakt-Lohn (50 Coins) abgerechnet."
const List<int> huntHintCosts = <int>[0, 20, 30];

/// Wie viele Hinweisstufen es gibt.
///
/// Eine eigene Konstante statt überall `huntHintCosts.length` zu schreiben,
/// damit eine vierte Stufe beide Stellen zwingt, sich zu ändern: wer
/// [huntHintCosts] um einen Eintrag erweitert und diese Zahl vergisst,
/// bekommt einen Test, der genau das meldet.
const int huntHintCount = 3;

/// Ob der Hinweis an [index] ohne Kosten und von Anfang an sichtbar ist.
///
/// Nur Index 0 ist frei, siehe die Begründung am Bibliothekskopf. Ein
/// [index] außerhalb von `[0, huntHintCount)` beschreibt keinen Hinweis, den
/// es gibt, und das ist ein Fehler des Aufrufers, keine ungeprüfte Eingabe
/// von außen wie bei einer gespeicherten Nutzlast. Deshalb **wirft** diese
/// Funktion, statt still `false` zurückzugeben, denn `false` würde einen
/// nicht existierenden Hinweis als „vorhanden, aber kostenpflichtig"
/// vortäuschen, und genau dieser Unterschied ist beim Anzeigen der Hinweise
/// wichtig.
bool isHuntHintFree(int index) {
  RangeError.checkValidIndex(index, huntHintCosts, 'index', huntHintCount);
  return index == 0;
}
