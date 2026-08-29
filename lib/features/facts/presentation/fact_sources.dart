/// Die Quellenliste der Akte, `02_Frontend/app/screen-fact.jsx:455-499`.
///
/// ## Woher die Einträge kommen
///
/// Aus **einem** Feld: `facts.quelle`, hier `FactText.source`. Die Quelle
/// bevorzugt `fact.quellenListe` und greift erst dann zu `quelle`
/// (`:456`, `:459`). Diese App erreicht den ersten Weg nie, siehe die
/// Begründung mit Fundstellen in `cited_text.dart`.
///
/// Zerlegt wird an `·` mit beliebigem Leerraum drumherum (`:460`), jedes Stück
/// getrimmt, leere Stücke fallen weg. Aus
/// `"Wikipedia · Stadtarchiv München"` werden also zwei Einträge.
///
/// ## Was bewusst fehlt
///
/// **Die Verlinkung.** `:463-469` baut jedem Eintrag eine Adresse: eine echte
/// URL bleibt stehen, ein Stück mit „wikipedia" darin bekommt eine
/// Wikipedia-Suche, alles andere eine Google-Suche über
/// `p + ' ' + fact.titel`. Angezeigt wird das als Link mit `↗` (`:485-488`).
/// Zum Öffnen bräuchte es `url_launcher`, und ein neues Paket ist eine
/// Entscheidung, die dieser Schritt nicht trifft. Ein Eintrag, der wie ein
/// Link aussieht und keiner ist, wäre die schlechtere Hälfte davon; deshalb
/// steht hier nur der Name.
///
/// ## Die Auffüllung mit Platzhaltern
///
/// `:472-475` hängt so lange
/// `{ name: 'Quelle fehlt' | 'Source missing', missing: true }` an, bis die
/// Liste so lang ist wie die höchste `[n]`-Referenz aller Textfelder
/// (`highestSourceRef`, `:50-62`). Das ist gebaut, siehe [factSourcesOf].
///
/// Der Text dafür steht in der Quelle als hartcodierter Sprach-Ternär und hat
/// **keinen i18n-Schlüssel**. Er liegt deshalb als `fact.sourceMissing` in
/// `app/localization/app_strings_supplement.dart` (E-39), mit beiden
/// Wortlauten wörtlich aus `:474`. Erfunden ist daran nichts.
///
/// Die Beschriftung kommt als Parameter herein und wird hier nicht
/// nachgeschlagen: diese Datei ist die einzige Stelle des Bildschirms, an der
/// aus einer Zeichenkette Struktur wird, und sie soll ohne `AppStrings` und
/// ohne Widget-Baum prüfbar bleiben, aus demselben Grund wie `cited_text.dart`.
library;

import 'package:flutter/foundation.dart';

/// Ein Eintrag der Quellenliste.
@immutable
final class FactSource {
  /// Erzeugt einen Eintrag. [name] ist getrimmt und nicht leer.
  const FactSource(this.name, {this.missing = false});

  /// Der angezeigte Name, ein Stück von `facts.quelle`.
  ///
  /// Bei einem Platzhalter ist es die Beschriftung, die [factSourcesOf]
  /// bekommen hat, also `fact.sourceMissing`.
  final String name;

  /// `missing: true` aus `screen-fact.jsx:474`: diese Zeile steht nur da,
  /// damit eine `[n]`-Hochziffer sie findet, und benennt keine Quelle.
  ///
  /// Trägt eine sichtbare Folge und ist deshalb ein Feld und keine Ableitung
  /// aus dem Namen: `:490` färbt solche Zeilen `ink3` statt `ink2` und setzt
  /// sie kursiv. Über den Namen zu erkennen, ob eine Zeile ein Platzhalter
  /// ist, würde eine echte Quelle namens „Quelle fehlt" mitfärben.
  final bool missing;

  @override
  bool operator ==(Object other) =>
      other is FactSource && other.name == name && other.missing == missing;

  @override
  int get hashCode => Object.hash(name, missing);

  @override
  String toString() => 'FactSource("$name"${missing ? ', fehlend' : ''})';
}

/// Das Trennmuster der Quelle, `screen-fact.jsx:460`: `/\s*·\s*/`.
final RegExp _separator = RegExp(r'\s*·\s*');

/// Zerlegt [source], also `facts.quelle`, in die Zeilen der Quellenliste und
/// füllt sie bis [highestReference] mit Platzhaltern auf.
///
/// Die Reihenfolge bleibt die der Zeichenkette, und **jedes Stück ergibt genau
/// eine Zeile**. Es wird nicht entdoppelt: stünde in `quelle` zweimal
/// dasselbe, zeigte die Quelle es auch zweimal, und stillschweigend eine
/// Angabe zu schlucken wäre bei einer Quellenangabe die falsche Freundlichkeit.
///
/// [highestReference] ist die höchste `[n]`-Hochziffer der Textfelder, also
/// das Ergebnis von `highestSourceReference` aus `cited_text.dart`. Fehlen
/// Zeilen bis dorthin, entstehen genau so viele Platzhalter mit
/// [missingLabel], und **keiner mehr**: die Auffüllung zählt bis
/// [highestReference] und nicht bis zur Zahl der Hochziffern im Text. Ein
/// einzelnes `[5]` ergibt fünf Zeilen, dreimal `[1]` ergibt eine.
///
/// Gibt es mehr Angaben in `quelle` als Referenzen im Text, wird nichts
/// gekürzt. `:473` ist eine `while`-Schleife über die Länge und keine
/// Zuweisung.
///
/// [missingLabel] ist `fact.sourceMissing`. Ohne die Beschriftung bleibt die
/// Auffüllung aus, statt eine Zeile ohne Text zu erzeugen; im Debug-Lauf
/// schlägt der `assert` an, damit dieser Weg nicht unbemerkt genommen wird.
List<FactSource> factSourcesOf(
  String? source, {
  int highestReference = 0,
  String? missingLabel,
}) {
  assert(
    highestReference <= 0 || missingLabel != null,
    'factSourcesOf: highestReference ist $highestReference, aber es gibt '
    'keine Beschriftung für die Platzhalter. Sie steht als '
    '"fact.sourceMissing" in app_strings_supplement.dart.',
  );
  final List<FactSource> entries = <FactSource>[];
  for (final String part in (source ?? '').split(_separator)) {
    final String trimmed = part.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    entries.add(FactSource(trimmed));
  }
  if (missingLabel != null) {
    while (entries.length < highestReference) {
      entries.add(FactSource(missingLabel, missing: true));
    }
  }
  return List<FactSource>.unmodifiable(entries);
}
