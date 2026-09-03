/// Ob ein Textfeld eines Fakts überhaupt Fließtext trägt.
///
/// ## Warum das aus `presentation/cited_text.dart` hierher gezogen ist
///
/// Dieselbe Begründung wie bei `spoken_fact_text.dart`, und derselbe Anlass:
/// ein zweites Feature braucht die Regel. Der Lesemodus des Reiseführers
/// (`features/collection`, Schritt 47) entscheidet mit ihr, ob `text2` als
/// Absatz auf die Buchseite kommt, und Regel 8 verbietet jedem Feature den
/// Import aus dem `presentation` eines anderen.
///
/// Es ist reines Dart auf einer Zeichenkette, ohne Flutter und ohne Widget,
/// also gehört es in die Domäne. `cited_text.dart` gibt es weiter nach außen,
/// damit die Akte und ihre Tests unverändert bleiben und es **eine**
/// Definition gibt.
///
/// Was ausdrücklich **nicht** mitgezogen ist: das Zerlegen des Textes in
/// Hochziffern und Zwischenstücke. Das erzeugt Widgets und bleibt dort, wo es
/// hingehört.
library;

/// Ob [text] als Absatz taugt, `02_Frontend/app/screen-fact.jsx:44-48`
/// (`isRealProse`).
///
/// Länger als 25 Zeichen **und** mindestens ein Leerraum, also mehr als ein
/// Wort. Der Kommentar über der Funktion nennt den Anlass: `text2` enthielt in
/// vielen Weimar-Fakten nur das Emotion-Tag („Nachdenklichkeit", „Staunen",
/// „Trauer"), gedacht als interne Meta-Angabe. Ohne diesen Filter erschien es
/// als sichtbarer Absatz, sobald der Nutzer „mehr zeigen" tippte.
///
/// Gemessen wird am **getrimmten** Text, die Länge also ohne führende und
/// nachlaufende Leerzeichen; das Leerraum-Kriterium prüft die Quelle ebenfalls
/// am getrimmten Wert.
bool isRealProse(String? text) {
  if (text == null) {
    return false;
  }
  final String trimmed = text.trim();
  return trimmed.length > 25 && _whitespace.hasMatch(trimmed);
}

/// `/\s/` aus `screen-fact.jsx:47`.
final RegExp _whitespace = RegExp(r'\s');

/// [text] ohne die Zitat-Hochziffern und ohne die Lücken, die dabei entstehen.
///
/// Aus „Der Turm [3] wurde" wird „Der Turm wurde" und nicht „Der Turm  wurde".
/// Getrimmt am Ende, weil eine Hochziffer auch als letztes Zeichen eines
/// Absatzes vorkommt und dann ein Leerzeichen zurücklässt. `null` wird zur
/// leeren Zeichenkette.
///
/// ## Wer das braucht, und warum es zwei sind
///
/// **Die Sprachausgabe** (`spoken_fact_text.dart`, Schritt 25): eine Zahl
/// mitten im Satz wird zu „Der Turm **drei** wurde" oder „Der Turm
/// **Klammer auf drei Klammer zu** wurde". Für einen blinden Nutzer ist der
/// Vortrag nicht die Beigabe zum Text, sondern der Text.
///
/// **Der Lesemodus** (`features/collection`, Schritt 47), und das ist ein
/// zweiter gemessener Defekt der Quelle. Die Buchseite gibt den Rohtext aus
/// (`screen-wallet.jsx:1651`, `{restText}`), zeigt also `[3]` mitten im
/// Fließtext, **ohne irgendwo eine Quellenliste zu haben**: sie hat nur den
/// Link „Mehr erfahren" (`:1671-1679`). Die Hochziffer verweist dort auf
/// nichts. In der Akte ist sie richtig, weil die Liste darunter steht; auf der
/// Buchseite ist sie eine Ziffer ohne Ziel.
///
/// Es braucht dafür keine Wortlaut-Entscheidung: es wird nichts erfunden,
/// sondern etwas weggelassen, das an dieser Stelle nicht lesbar ist.
String factTextWithoutReferences(String? text) {
  if (text == null) {
    return '';
  }
  return text.replaceAll(_reference, '').replaceAll(_doubleSpace, ' ').trim();
}

/// Die Zitat-Hochziffern, dieselbe Form wie in `cited_text.dart`, also `[3]`,
/// **samt dem Leerraum davor**.
///
/// `\s*` davor ist gemessen und nicht vorsorglich: ohne es wurde aus
/// „Text [42]." ein „Text ." mit Leerzeichen vor dem Punkt. Manche
/// Sprachausgaben machen daraus eine zusätzliche Pause, andere sprechen die
/// Satzzeichen anders. Der Leerraum **hinter** der Hochziffer bleibt, er ist
/// der Wortabstand zum nächsten Wort.
final RegExp _reference = RegExp(r'\s*\[(\d+)\]');

/// Zwei oder mehr Leerzeichen.
///
/// Bleibt als Netz, obwohl [_reference] den Leerraum davor schon mitnimmt:
/// „Wort  [1]  Wort" mit doppeltem Abstand auf beiden Seiten lässt sonst zwei
/// Leerzeichen zurück.
final RegExp _doubleSpace = RegExp(r'  +');
