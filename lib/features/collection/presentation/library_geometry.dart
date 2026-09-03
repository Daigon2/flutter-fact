/// Die Maße des Bücherregals, `02_Frontend/app/screen-wallet.jsx:797-800`
/// und `:933-940`.
///
/// Reine Funktionen und Konstanten, ohne Flutter und ohne Widget-Baum prüfbar.
/// Sie stehen getrennt, weil an ihnen die Zahlen hängen, die man sonst erst am
/// Gerät sieht: eine Reihe zu wenig, ein Buch zu hoch, eine Bandnummer, die
/// mitwandert.
library;

import 'package:fact_app/features/collection/application/library_shelf.dart';

/// Wie viele Bände in einer Reihe stehen (`screen-wallet.jsx:933`).
const int libraryBooksPerRow = 4;

/// Wie viele Reihen das Regal mindestens zeigt (`screen-wallet.jsx:935`).
///
/// `while (chunks.length < 2) chunks.push([])`. Ein Regal mit einer Stadt hat
/// damit eine Reihe mit einem Buch und drei Leerplätzen, plus eine zweite
/// Reihe mit vier Leerplätzen. Das ist Absicht und kein Zufall der Quelle: das
/// Regal soll nach etwas aussehen, das noch zu füllen ist.
const int libraryMinimumRows = 2;

/// Die kleinste Höhe eines Buchrückens (`screen-wallet.jsx:799`).
const double libraryBookMinHeight = 165;

/// Die größte Höhe eines Buchrückens (`screen-wallet.jsx:799`).
const double libraryBookMaxHeight = 215;

/// Der Faktor, mit dem der Sammelanteil auf die Höhe geht
/// (`screen-wallet.jsx:798`).
///
/// `Math.min(1, collected / total * 2.2)`: die volle Höhe ist bei knapp 46
/// Prozent erreicht, nicht bei 100. Wer den Faktor für einen Tippfehler hält
/// und ihn auf 1 setzt, macht alle Bücher niedriger, und niemand merkt es,
/// weil sie untereinander weiter richtig stehen.
const double libraryBookHeightFactor = 2.2;

/// Die Höhe eines Leerplatzes (`screen-wallet.jsx:947`).
///
/// Eigene Zahl und nicht [libraryBookMinHeight]: 168 gegen 165. Der Leerplatz
/// ist damit drei Pixel höher als das leerste Buch, und weil das Gitter unten
/// ausgerichtet ist, sieht man den Unterschied oben.
const double libraryEmptySlotHeight = 168;

/// Die Höhe eines Buchrückens bei [collected] von [total] Fakten.
///
/// Bei `total == 0` die kleinste Höhe. Der Fall kann über
/// [libraryShelfOf] nicht entstehen, weil ein Band Fakten braucht; die Quelle
/// prüft ihn trotzdem (`total > 0 ? … : 0`), und die Division fiele hier sonst
/// auf `NaN`.
double libraryBookHeight({required int collected, required int total}) {
  if (total <= 0) {
    return libraryBookMinHeight;
  }
  final double share = (collected / total * libraryBookHeightFactor).clamp(
    0,
    1,
  );
  return (libraryBookMinHeight +
          share * (libraryBookMaxHeight - libraryBookMinHeight))
      .roundToDouble();
}

/// Die Reihen des Regals: [libraryBooksPerRow] Plätze je Reihe, leere Plätze
/// als `null`, mindestens [libraryMinimumRows] Reihen.
///
/// Gibt eine Liste von Reihen zurück, jede genau [libraryBooksPerRow] Einträge
/// lang. Das ist die Form, die das Gitter braucht: ein Leerplatz ist ein
/// eigenes Kästchen mit gestricheltem Rand und der Beschriftung „Nächste
/// Stadt …", kein weggelassenes Kind.
List<List<LibraryVolume?>> libraryShelfRows(List<LibraryVolume> volumes) {
  final List<List<LibraryVolume?>> rows = <List<LibraryVolume?>>[];
  for (var start = 0; start < volumes.length; start += libraryBooksPerRow) {
    final int end = start + libraryBooksPerRow;
    rows.add(<LibraryVolume?>[
      ...volumes.sublist(start, end > volumes.length ? volumes.length : end),
    ]);
  }
  while (rows.length < libraryMinimumRows) {
    rows.add(<LibraryVolume?>[]);
  }
  for (final List<LibraryVolume?> row in rows) {
    while (row.length < libraryBooksPerRow) {
      row.add(null);
    }
  }
  return rows;
}

/// Die Nummer auf dem Buchrücken.
///
/// ## Der Rückfall hängt an der Gitterposition, und das ist ein Fund
///
/// Die Quelle rechnet `cityObj.bandNo || (4 * ri + ci + 1)`
/// (`screen-wallet.jsx:966`). Eine Stadt ohne eigene Palette bekommt damit
/// eine Nummer, die sich **ändert, sobald eine andere Stadt dazukommt**: sie
/// steht dann eine Position weiter und heißt plötzlich „№ 4" statt „№ 3". Eine
/// Bandnummer, die von den Nachbarn abhängt, ist keine Bandnummer.
///
/// Nachgebaut wird sie trotzdem, und zwar unverändert. Es ist eine
/// Anzeigeentscheidung ohne Folge für Daten oder Punkte, und die Alternative
/// wäre, hier eine Nummerierung zu **erfinden**: eine fortlaufende Zahl nach
/// den fünf bekannten Bänden wäre neues Verhalten, für das es keine Vorlage
/// gibt. Festgehalten als Teil von E-75, damit die Wahl nicht als Versehen
/// gelesen wird.
int libraryVolumeNumber(
  LibraryVolume volume, {
  required int rowIndex,
  required int columnIndex,
}) => volume.bandNumber ?? (libraryBooksPerRow * rowIndex + columnIndex + 1);
