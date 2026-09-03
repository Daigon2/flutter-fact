/// Der Fakttext: die Zitat-Hochziffern (`renderCited`,
/// `02_Frontend/app/screen-fact.jsx:3-37`).
///
/// `isRealProse` (`:44-48`) stand bis Schritt 47 ebenfalls hier und liegt
/// jetzt in `domain/fact_prose.dart`, weil der Lesemodus des Reiseführers es
/// braucht und Regel 8 den Import aus dem `presentation` eines anderen
/// Features verbietet. Diese Datei gibt es weiter, damit es bei einer
/// Definition bleibt.
///
/// ## Was die Hochziffer tut
///
/// Sie springt zur Quellenliste. Die Quelle kennt daneben einen zweiten Weg:
/// trägt der zugehörige Eintrag in `fact.quellenListe` eine `url`, wird die
/// Hochziffer ein `<a>` auf diese Adresse (`:16-24`). **Dieser Zweig ist für
/// diese App unerreichbar**, und das ist nachgeschlagen, nicht vermutet:
///
/// * `quellenListe` steht **nicht** in `03_Backend/supabase-schema.sql`, die
///   Tabelle `public.facts` führt nur `quelle text`;
/// * in der PWA kommt das Feld ausschließlich aus den eingebauten
///   JS-Datendateien (`rome-data.jsx`, `data.jsx`, `muenchen-heute-data.jsx`)
///   und erreicht den Bildschirm über die Verschmelzung in `app.jsx:219`
///   (`{ ...(local || {}), ...sf }`);
/// * `muenchen-data.jsx` hat es null Mal, und diese App liest ausschließlich
///   Supabase.
///
/// Damit gibt es hier genau ein Verhalten: **die Hochziffer springt zur
/// Quellenliste**, wie in `:26-35`.
///
/// ## Warum das Zerlegen eine eigene Funktion ist
///
/// Weil es die einzige Stelle des Bildschirms ist, an der aus Text Struktur
/// wird, und weil sie ohne Widget-Baum prüfbar sein muss. `[12]` ist die
/// zwölfte Quelle und nicht die Ziffern 1 und 2, und ein `[a]` ist keine
/// Referenz. Beides sieht man einer gerenderten Fläche nicht an.
library;

import 'package:flutter/foundation.dart';

/// `isRealProse` liegt in der Domäne, wird aber weiter von hier bezogen: die
/// Akte und ihre Tests haben es immer hier gefunden, und zwei Importpfade für
/// eine Funktion sind ein Grund, den falschen zu erwischen.
export 'package:fact_app/features/facts/domain/fact_prose.dart'
    show isRealProse;

/// Ein Stück eines Fakttexts.
@immutable
sealed class CitedSegment {
  const CitedSegment();
}

/// Gewöhnlicher Text zwischen zwei Referenzen.
@immutable
final class CitedRun extends CitedSegment {
  /// Erzeugt ein Textstück. [text] ist nie leer.
  const CitedRun(this.text);

  /// Der Text, unverändert aus der Quelle.
  final String text;

  @override
  bool operator ==(Object other) => other is CitedRun && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'CitedRun("$text")';
}

/// Eine Zitat-Hochziffer, also `[3]`.
@immutable
final class CitedReference extends CitedSegment {
  /// [number] ist die Zahl in den Klammern, also **eins-basiert**.
  const CitedReference(this.number);

  /// Die Zahl aus den Klammern. `[3]` ergibt `3`.
  final int number;

  /// Der Platz in der Quellenliste, null-basiert. `screen-fact.jsx:9`:
  /// `parseInt(m[1], 10) - 1`.
  int get sourceIndex => number - 1;

  /// Wie die Hochziffer im Text steht, also `[3]`.
  String get label => '[$number]';

  @override
  bool operator ==(Object other) =>
      other is CitedReference && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'CitedReference($number)';
}

/// Das Muster der Quelle, `screen-fact.jsx:6`: `text.split(/(\[\d+\])/)`.
///
/// Bewusst ohne `\d`-Unicode-Feinheiten und ohne Vorzeichen: `\d` trifft in
/// JavaScript ohne `u`-Flag genau `[0-9]`, und `RegExp` in Dart ebenso.
final RegExp _reference = RegExp(r'\[(\d+)\]');

/// Zerlegt [text] in Textstücke und Referenzen.
///
/// Leere Stücke fallen weg. Die Quelle liefert sie mit (`split` mit einer
/// Fanggruppe erzeugt leere Zeichenketten am Anfang und am Ende), React
/// rendert sie nur nicht sichtbar; hier wären sie leere `TextSpan`s ohne
/// Zweck.
///
/// `null` und der leere Text ergeben eine leere Liste, wie `:4`
/// (`if (!text) return null`).
List<CitedSegment> parseCitedText(String? text) {
  if (text == null || text.isEmpty) {
    return const <CitedSegment>[];
  }
  final List<CitedSegment> segments = <CitedSegment>[];
  var cursor = 0;
  for (final RegExpMatch match in _reference.allMatches(text)) {
    if (match.start > cursor) {
      segments.add(CitedRun(text.substring(cursor, match.start)));
    }
    // `int.parse` und nicht `tryParse`: die Fanggruppe ist `\d+`, ein anderer
    // Inhalt kann sie nicht erreichen. Ein `[99999999999999999999]` wäre der
    // einzige Ausreißer, und der ist in einem Fakttext kein Fall, den ein
    // stiller Ersatzwert besser macht.
    segments.add(CitedReference(int.parse(match.group(1)!)));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(CitedRun(text.substring(cursor)));
  }
  return List<CitedSegment>.unmodifiable(segments);
}

/// Die höchste `[n]`-Referenz in [texts], `screen-fact.jsx:50-62`
/// (`highestSourceRef`). `0` heißt: keine einzige Referenz.
///
/// Die Quelle hängt `text`, `text2`, `text3` und `text4` mit einem Leerzeichen
/// aneinander und sucht darin. Feldweise zu suchen ist dasselbe Ergebnis: ein
/// Leerzeichen dazwischen kann keine Klammer schließen, die vorher offen war.
///
/// **Gezählt wird unabhängig davon, ob der Absatz gerade sichtbar ist.** Die
/// Quelle prüft weder `showMore` noch `isRealProse`, und das ist richtig
/// herum: die Quellenliste steht unter dem eingeklappten wie dem aufgeklappten
/// Text, und eine Zeile, die beim Aufklappen erst entstünde, ließe die Liste
/// unter dem Finger wachsen.
///
/// ## Eine Abweichung, die nur außerhalb des Deutschen sichtbar ist
///
/// Die Quelle liest `fact.text` und nicht `factField(fact, 'text', lang)`,
/// zählt also **immer im deutschen Grundtext**, auch im englischen Modus
/// (`storage.jsx:198`: `factField` löst `_i18n` auf, `highestSourceRef` in
/// `:52` nicht). Hier kommen die Texte aus `Fact.contentFor(...)`, also aus
/// der angezeigten Sprache.
///
/// Der Unterschied trägt genau dann, wenn eine Übersetzung eine höhere
/// Referenz führt als der deutsche Grundtext, und dann hätte die Quelle für
/// eine sichtbare Hochziffer keine Zeile, was `:454` („alle im Text
/// referenzierten [n] müssen einen Eintrag haben") ausdrücklich verhindern
/// will. Im Deutschen ist `contentFor` mit den flachen Spalten identisch, dort
/// sind beide Wege buchstäblich derselbe.
int highestSourceReference(Iterable<String?> texts) {
  var highest = 0;
  for (final String? text in texts) {
    if (text == null) {
      continue;
    }
    for (final RegExpMatch match in _reference.allMatches(text)) {
      final int number = int.parse(match.group(1)!);
      if (number > highest) {
        highest = number;
      }
    }
  }
  return highest;
}
