/// Die sechs Kapitel eines Reiseführer-Bands und die Tabelle, die eine
/// Fakt-Kategorie darauf abbildet.
///
/// ## Quelle
///
/// `02_Frontend/app/wallet-colors.jsx:75-100`: `window.WalletCats` (sechs
/// Einträge), `window.WalletCatOrder` (ihre Reihenfolge) und
/// `window.walletKatToKey` (die Abbildung). Der Kommentar dort sagt, warum es
/// diese Tabelle überhaupt gibt: „Wird benutzt, weil die Reiseführer-Optik
/// andere Glyphen will als das normale `window.CAT`."
///
/// ## Warum das eine zweite, unabhängige Abschrift ist
///
/// `features/discovery/presentation/fact_categories.dart` hält **zwölf**
/// Kategorien mit Emoji und Farbe, aus `screen-map.jsx`. Diese hier hält
/// **sechs**, aus `wallet-colors.jsx`. Das sind zwei verschiedene Tabellen der
/// Quelle mit verschiedenen Zwecken, und Regel 8 lässt `collection` ohnehin
/// nicht in die Presentation von `discovery`.
///
/// **Die sechs sind eine Teilmenge der zwölf**, das ist geprüft: `hist`,
/// `arch`, `myth`, `fun`, `geo` und `heute` kommen in beiden vor. Die
/// Abbildung ist trotzdem nicht dieselbe, siehe unten.
///
/// ## Fünf Kartenkategorien landen im Kapitel „Historisch"
///
/// Gemessen am 03.09.2026 und in `library_categories_test.dart` festgenagelt.
/// `walletKatToKey` kennt nur sechs Ziele und fällt auf `hist` zurück. Von den
/// Kategorietexten, die `factCategoryAliases` kennt, treffen deshalb
/// **Kulinarik, Persönlichkeiten, Kultur, Dunkel & Kriminell und Kirche &
/// Glaube** alle auf `hist`, dazu `Historical Figures`, das die Karte als
/// eigene Kategorie `pers` führt. Ein Fakt über ein Restaurant steht im
/// Reiseführer damit im Kapitel „Historisch".
///
/// **Übernommen wie es ist, und das ist eine Abwägung.** Sechs Kapitel sind
/// eine gestalterische Entscheidung der Quelle; zwölf daraus zu machen wäre
/// neues Verhalten und keine Behebung. Dass ein kulinarischer Fakt unter
/// Geschichte einsortiert wird, ist einem Leser gegenüber trotzdem falsch, und
/// die Antwort darauf ist eine Inhaltsentscheidung des Eigentümers. Steht als
/// E-78 im Register. Der Test hält die Zuordnung fest, damit niemand sie
/// nebenbei „korrigiert" und damit die Kapitelzahl auf allen Covern verschiebt.
///
/// **Eine Ausnahme ist ausdrücklich gewollt:** `Natur` und `Nature` fallen auf
/// `geo`, weil `walletKatToKey` dafür eine eigene Zeile hat
/// (`if (k.startsWith('natur')) return 'geo'`). Das ist keine Rückfall-Folge.
library;

import 'package:fact_app/features/collection/application/library_city_key.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';

/// Die sechs Kapitelschlüssel in der Reihenfolge der Quelle,
/// `window.WalletCatOrder`.
const List<String> libraryCategoryOrder = <String>[
  'hist',
  'arch',
  'myth',
  'fun',
  'geo',
  'heute',
];

/// Auf welches Kapitel [category] fällt.
///
/// Wörtliche Abschrift von `walletKatToKey` (`wallet-colors.jsx:88-100`),
/// **einschließlich der Reihenfolge der Prüfungen**. Sie ist bedeutsam: `geo`
/// steht vor `natur`, und beide führen auf denselben Schlüssel, aber ein
/// späterer Umbau, der die Zeilen sortiert, ändert das Ergebnis für jeden Text,
/// der auf mehr als eine Regel passt.
///
/// Der Rückfall ist `hist` und nicht `null`. Das ist die Quelle, und es ist
/// gleichzeitig der Grund für E-78.
String libraryCategoryKeyOf(String category) {
  final String key = category.toLowerCase();
  if (key.startsWith('hist') || key.startsWith('gesch')) {
    return 'hist';
  }
  if (key.startsWith('arch')) {
    return 'arch';
  }
  if (key.startsWith('myth')) {
    return 'myth';
  }
  if (key.startsWith('fun')) {
    return 'fun';
  }
  if (key.startsWith('geo')) {
    return 'geo';
  }
  if (key.startsWith('natur')) {
    return 'geo';
  }
  if (key.startsWith('stadt heute') ||
      key.startsWith('heute') ||
      key.startsWith('aktuell') ||
      key.startsWith('city today') ||
      key == 'today') {
    return 'heute';
  }
  return 'hist';
}

/// Ein Kapitel eines Bands: wie viele Fakten es hat und wie viele davon
/// gesammelt sind.
final class LibraryChapter {
  /// Erzeugt ein Kapitel.
  const LibraryChapter({
    required this.categoryKey,
    required this.collected,
    required this.total,
  });

  /// Der Kapitelschlüssel, einer aus [libraryCategoryOrder].
  final String categoryKey;

  /// Wie viele Fakten dieses Kapitels gesammelt sind.
  final int collected;

  /// Wie viele Fakten das Kapitel hat.
  final int total;

  /// Ob das Kapitel auf dem Cover mitgezählt wird.
  ///
  /// `chaptersCount = cats.filter(c => c.collected > 0).length`
  /// (`screen-wallet.jsx:467`): gezählt wird, was **angefangen** ist, nicht
  /// was existiert. Ein Band mit 200 Fakten und einem gesammelten zeigt
  /// deshalb „1 Kapitel" und nicht „6".
  bool get isStarted => collected > 0;

  @override
  bool operator ==(Object other) =>
      other is LibraryChapter &&
      other.categoryKey == categoryKey &&
      other.collected == collected &&
      other.total == total;

  @override
  int get hashCode => Object.hash(categoryKey, collected, total);

  @override
  String toString() => 'LibraryChapter($categoryKey, $collected/$total)';
}

/// Die sechs Kapitel der Stadt [cityKey], immer alle sechs und immer in der
/// Reihenfolge von [libraryCategoryOrder].
///
/// **Auch leere Kapitel kommen mit**, genau wie in der Quelle:
/// `wltCityCats` legt für jeden Schlüssel eine Zeile an und zählt danach hoch
/// (`screen-wallet.jsx:77-89`). Die Kapitelliste aus Schritt 47 braucht das,
/// weil sie ein Kapitel mit 0 von 12 anders zeichnet als eines, das es nicht
/// gibt.
List<LibraryChapter> libraryChaptersOf({
  required Iterable<Fact> facts,
  required String cityKey,
  required Set<int> collected,
}) {
  final Map<String, int> totals = <String, int>{};
  final Map<String, int> collectedCounts = <String, int>{};

  for (final Fact fact in facts) {
    if (libraryCityKeyOf(fact) != cityKey) {
      continue;
    }
    final String key = libraryCategoryKeyOf(fact.canonicalCategory);
    totals[key] = (totals[key] ?? 0) + 1;
    if (collected.contains(fact.id.value)) {
      collectedCounts[key] = (collectedCounts[key] ?? 0) + 1;
    }
  }

  return <LibraryChapter>[
    for (final String key in libraryCategoryOrder)
      LibraryChapter(
        categoryKey: key,
        collected: collectedCounts[key] ?? 0,
        total: totals[key] ?? 0,
      ),
  ];
}
