/// Die elf Kapitel eines Reiseführer-Bands und die Tabelle, die eine
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
/// Kategorien mit Emoji und Farbe, aus `screen-map.jsx`. Diese hier hielt
/// bis zum 03.09.2026 **sechs**, aus `wallet-colors.jsx`, und hält seit der
/// Entscheidung zu E-78 **elf**. Das sind zwei Tabellen der Quelle mit
/// verschiedenen Zwecken, und Regel 8 lässt `collection` ohnehin nicht in
/// die Presentation von `discovery`.
///
/// **Die elf sind eine Teilmenge der zwölf**, das ist geprüft: es fehlt
/// allein `nat`, und zwar mit Absicht, siehe unten.
///
/// ## Elf Kapitel, und warum es vorher fünf zu wenig waren
///
/// Am 03.09.2026 gemessen: `walletKatToKey` kennt nur sechs Ziele und
/// fällt sonst auf `hist` zurück. Von den Kategorietexten, die
/// `factCategoryAliases` kennt, trafen deshalb **vierzehn** auf `hist`,
/// nämlich alle Schreibweisen von Kulinarik, Persönlichkeiten, Kultur,
/// Dunkel & Kriminell und Kirche & Glaube. Ein Fakt über ein Restaurant
/// stand im Reiseführer unter Geschichte, und `Historical Figures`, das
/// die Karte ausdrücklich als `pers` führt, ebenfalls.
///
/// **Der Eigentümer hat am 03.09.2026 entschieden, dass die fünf ihr
/// eigenes Kapitel bekommen** (E-78). Die Abbildung unten ist damit keine
/// wörtliche Abschrift von `walletKatToKey` mehr, sondern die Quelle plus
/// fünf Zeilen. Welche Reihenfolge die Prüfungen haben, ist dabei nicht
/// gleichgültig, und `library_categories_test.dart` nagelt jeden der
/// zweiunddreißig Kategorietexte einzeln fest.
///
/// **Kein Wortlaut war nötig, und das war beim Fragen noch nicht klar.**
/// `cat.kul`, `cat.pers` und `cat.chr` stehen zweisprachig in den
/// erzeugten Tabellen. Für `kult` und `dark` liefert die Aliastabelle der
/// Karte beide Sprachen als Paar mit, siehe die beiden Ergänzungs-Einträge
/// in `app_strings_supplement.dart`. Erfunden ist nichts.
///
/// **Eine Ausnahme ist ausdrücklich gewollt:** `Natur` und `Nature` fallen auf
/// `geo`, weil `walletKatToKey` dafür eine eigene Zeile hat
/// (`if (k.startsWith('natur')) return 'geo'`). Das ist keine Rückfall-Folge.
library;

import 'package:fact_app/features/collection/application/generated/wallet_categories.g.dart';
import 'package:fact_app/features/collection/application/library_city_key.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';

/// Die fünf Kapitel, die es in der Quelle nicht gibt.
///
/// **Entscheidung des Eigentümers vom 03.09.2026**, siehe E-78: „ne, das soll
/// nicht alles unter historisch. die bekommen ihr eigenes akapitel, wäre am
/// cleansten oder?"
///
/// Die Reihenfolge ist die der Kartentabelle (`screen-map.jsx:195-208`), und
/// sie stehen **hinten**, nicht zwischen den sechs. Der Grund ist sichtbar:
/// die Kapitelliste nummeriert römisch nach der Position in dieser Folge. Wer
/// die fünf einsortiert, verschiebt jedem bestehenden Nutzer die Nummern
/// seiner Kapitel; wer sie anhängt, lässt I bis VI stehen und ergänzt VII bis
/// XI.
const List<String> libraryExtraCategories = <String>[
  'kul',
  'pers',
  'kult',
  'dark',
  'kirche',
];

/// Die elf Kapitelschlüssel, erst die sechs der Quelle, dann die fünf neuen.
///
/// **Die sechs sind erzeugt und nicht abgeschrieben:** [walletCategoryOrder]
/// kommt aus `wallet-colors.jsx` durch `tool/generate_curated_data.dart`.
/// Stand hier vorher als Liste von Hand und wäre bei einer siebten Kategorie
/// der Quelle stumm veraltet.
///
/// **`nat` fehlt in beiden Teilen, und das ist Absicht.** `walletKatToKey` hat
/// für Natur eine eigene Zeile auf `geo` (`if (k.startsWith('natur')) return
/// 'geo'`). Das ist eine redaktionelle Entscheidung der Quelle und kein
/// Rückfall wie bei den fünf anderen, deshalb elf Kapitel und nicht zwölf.
final List<String> libraryCategoryOrder = <String>[
  ...walletCategoryOrder,
  ...libraryExtraCategories,
];

/// Der i18n-Schlüssel für den Namen von [categoryKey].
///
/// Zehn der elf heißen `cat.<schlüssel>`. **Die Ausnahme ist `kirche`:** das
/// Wörterbuch führt „Kirche & Glaube" unter `cat.chr`, während die
/// Kategorietabelle der Karte den Schlüssel `kirche` benutzt. Zwei Namen für
/// dieselbe Sache, und `t('cat.kirche')` fände nichts. Dieselbe Sorte
/// Stolperstelle wie E-28 und E-63, hier einmal abgefangen statt an jeder
/// Aufrufstelle.
String libraryChapterNameKey(String categoryKey) =>
    categoryKey == 'kirche' ? 'cat.chr' : 'cat.$categoryKey';

/// Auf welches Kapitel [category] fällt.
///
/// **Bis zum 03.09.2026 war das die wörtliche Abschrift von
/// `walletKatToKey` (`wallet-colors.jsx:88-100`). Jetzt ist es die Quelle
/// plus fünf Zeilen**, weil die fünf zusammengefalteten Kategorien ihr
/// eigenes Kapitel bekommen haben (E-78).
///
/// **Die Reihenfolge der Prüfungen ist der schwierige Teil**, und drei
/// Stellen sind heikel:
///
/// * `historical figures` muss **vor** `hist` stehen, sonst gewinnt der
///   Anfang des Wortes und eine Person landet unter Geschichte. Genau das
///   tut die Quelle.
/// * `arch` muss **vor** `art` stehen: `architektur` und `architecture`
///   fangen mit `arc` an, nicht mit `art`, und der Unterschied ist ein
///   Buchstabe.
/// * `kulinar` muss **vor** `kultur` stehen. Beide fangen mit `kul` an,
///   und eine Prüfung auf drei Buchstaben machte aus Kulinarik Kultur.
///
/// Der Rückfall bleibt `hist` und nicht `null`, wie in der Quelle. Er
/// fängt jetzt aber nur noch wirklich unbekannte Texte und nicht mehr fünf
/// ganze Kategorien.
String libraryCategoryKeyOf(String category) {
  final String key = category.toLowerCase();
  // **Steht vor der `hist`-Zeile, und das ist der Kern der Erweiterung.**
  // `Historical Figures` führt die Karte als `pers`, und der Text fängt mit
  // „hist" an. Bei der Quelle gewinnt deshalb `hist`, und eine Person landet
  // unter Geschichte. Genau dieser Fall war der auffälligste Beleg in E-78.
  if (key.startsWith('historical figures')) {
    return 'pers';
  }
  if (key.startsWith('hist') || key.startsWith('gesch')) {
    return 'hist';
  }
  // Vor `art`: `architektur` und `architecture` fangen mit „arc" an, nicht
  // mit „art", der Unterschied ist ein Buchstabe.
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
  // `kulinar` vor `kultur`: beide fangen mit „kul" an, und ein `startsWith`
  // auf drei Buchstaben würde Kulinarik zu Kultur machen.
  if (key.startsWith('kulinar') || key.startsWith('food')) {
    return 'kul';
  }
  if (key.startsWith('kultur') ||
      key.startsWith('kunst') ||
      key.startsWith('art')) {
    return 'kult';
  }
  if (key.startsWith('persön') || key.startsWith('person')) {
    return 'pers';
  }
  if (key.startsWith('dunkel') || key.startsWith('dark')) {
    return 'dark';
  }
  if (key.startsWith('kirche') || key.startsWith('church')) {
    return 'kirche';
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

/// Auf welcher Seite jedes Kapitel anfängt, `wltCatStartPages`
/// (`screen-wallet.jsx:184-196`).
///
/// Die Seitenzahl ist die laufende Summe der **gesammelten** Fakten der
/// vorherigen Kapitel, beginnend bei eins. Ein Kapitel, das nichts Gesammeltes
/// hat, verbraucht keine Seite; das nächste fängt auf derselben an.
///
/// Das ist die Buchmetapher zu Ende gedacht: das Buch enthält nur, was man
/// gelesen hat, und wächst mit dem Sammeln. Eine Seitenzahl über **alle**
/// Fakten wäre die andere plausible Lesart und ist nicht die der Quelle.
///
/// Gibt eine Liste in der Reihenfolge von [chapters] zurück und keine
/// Abbildung: die Kapitelliste läuft ohnehin mit Index darüber, und ein
/// Kartenschlüssel, der zufällig zweimal vorkommt, könnte hier eine Seite
/// verlieren.
List<int> libraryChapterStartPages(List<LibraryChapter> chapters) {
  final List<int> pages = <int>[];
  var page = 1;
  for (final LibraryChapter chapter in chapters) {
    pages.add(page);
    page += chapter.collected;
  }
  return pages;
}
