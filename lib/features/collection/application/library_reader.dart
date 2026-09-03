/// Welche Seite der Lesemodus zeigt und was links und rechts davon liegt,
/// `02_Frontend/app/screen-wallet.jsx:1459-1483`.
///
/// ## Die Reihenfolge ist der ganze Inhalt dieser Datei
///
/// Der Lesemodus blättert, und Blättern heißt: es gibt eine Folge. Die Quelle
/// baut sie in drei Schritten, und alle drei sind hier abgebildet:
///
/// 1. **Nur Gesammeltes.** `arr = cityFacts.filter(f => collectedSet.has(…))`
///    (`:1461`). Das Buch enthält, was man gelesen hat. Dieselbe Buchmetapher
///    wie bei den Seitenzahlen in `libraryChapterStartPages`.
/// 2. **Nach Kennung aufsteigend** (`:1462-1466`).
/// 3. **Im Kapitelzusammenhang zusätzlich nach Kategorie gefiltert**
///    (`:1474-1476`).
///
/// ## Warum die Sortierung nach Kennung und nicht nach Sammelzeit
///
/// Der Kommentar über der Stelle nennt den Anlass, und es ist eine behobene
/// Fehlermeldung: „STABILE Reihenfolge nach `fact.id`, damit `markRead()` die
/// Sortierung nicht jedes Mal umwirft (sonst springt „Nächste" zwischen den
/// zwei letzt-gelesenen Fakten)". Die Quelle hatte die Folge einmal nach
/// Leseverlauf sortiert; jedes Öffnen änderte damit die Folge, und „Nächste"
/// führte zurück auf die Seite davor.
///
/// **Das kann uns nicht passieren, und zwar aus einem anderen Grund als dort.**
/// Der Neubau kennt keinen Leseverlauf: „gesammelt ist gelesen" (E-80,
/// entschieden am 03.09.2026), es gibt also nur eine Liste und keine zweite,
/// die eine Sortierung verschieben könnte. Die Sortierung nach Kennung bleibt
/// trotzdem, weil sie das Verhalten der Quelle ist: die Folge im Buch ist die
/// der Datenbank und nicht die des Sammelns.
///
/// ## Eine Zeile der Quelle ist hier tot, und das ist der Typ
///
/// `:1463-1465` vergleicht die Kennungen als Zahl und fällt auf einen
/// Zeichenkettenvergleich zurück, wenn eine davon keine Zahl ist. Der Grund
/// steht in `screen-wallet.jsx:1812`: „heterogeneous factId
/// (number/string/'local-…')". `FactId` trägt ein `int`, und der Mapper lässt
/// nichts anderes durch. Der Rückfall hat hier keinen Zweig, in dem er
/// greifen könnte, und ein Zweig, der nie läuft, ist kein Netz, sondern
/// unprüfbarer Code.
///
/// ## Zwei Seitenzahlen, die verschiedene Dinge zählen
///
/// Die Kapitelliste zeigt „S. 7" (`libraryChapterStartPages`), der Lesemodus
/// darunter „1 / 4". Das sieht widersprüchlich aus und ist es nicht: die erste
/// ist die Seite **im Band**, über alle Kapitel gezählt, die zweite die
/// Position **im aktuellen Zusammenhang**. Wer Kapitel III öffnet, steht auf
/// Buchseite 7 und gleichzeitig auf der ersten von vier Seiten dieses
/// Kapitels. Beide Zahlen stehen so in der Quelle (`:748`, `:1783`).
library;

import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/collection/application/library_city_key.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';

/// Woraus die Blätterfolge besteht.
enum LibraryReaderScope {
  /// Alle gesammelten Fakten der Stadt, `ctx.type === 'chron'` (`:1836`).
  volume,

  /// Nur die eines Kapitels, `ctx.type === 'chapter'` (`:1727`).
  chapter,
}

/// Eine Seite des Lesemodus mit ihren Nachbarn.
final class LibraryReaderPage {
  /// Erzeugt die Seite zu [fact].
  const LibraryReaderPage({
    required this.fact,
    required this.number,
    required this.count,
    this.previous,
    this.next,
  });

  /// Der Fakt, der auf der Seite steht.
  final Fact fact;

  /// Die Seite davor, oder `null` am Anfang der Folge (`prev`, `:1479`).
  final Fact? previous;

  /// Die Seite danach, oder `null` am Ende (`next`, `:1480`).
  final Fact? next;

  /// Die Nummer dieser Seite im Zusammenhang, beginnend bei eins
  /// (`pageInTotal`, `:1489`).
  final int number;

  /// Wie viele Seiten der Zusammenhang hat (`totalInContext`, `:1490`).
  final int count;

  /// Ob es eine Seite davor gibt.
  bool get hasPrevious => previous != null;

  /// Ob es eine Seite danach gibt.
  bool get hasNext => next != null;

  @override
  String toString() => 'LibraryReaderPage(${fact.id.value}, $number/$count)';
}

/// Die Blätterfolge für die Stadt [cityKey].
///
/// [categoryKey] schaltet von [LibraryReaderScope.volume] auf
/// [LibraryReaderScope.chapter]: ist er gesetzt, bleiben nur Fakten dieses
/// Kapitels übrig.
///
/// Nimmt [collected] als Menge von Zahlen und nicht von `FactId`, wie
/// `libraryChaptersOf` und `libraryShelfOf` daneben: der Aufrufer ist immer
/// ein Provider, der die Menge einmal umrechnet.
List<Fact> libraryReaderOrder({
  required Iterable<Fact> facts,
  required String cityKey,
  required Set<int> collected,
  String? categoryKey,
}) {
  final List<Fact> order = <Fact>[
    for (final Fact fact in facts)
      if (collected.contains(fact.id.value) &&
          libraryCityKeyOf(fact) == cityKey &&
          (categoryKey == null ||
              libraryCategoryKeyOf(fact.canonicalCategory) == categoryKey))
        fact,
  ];
  order.sort((Fact a, Fact b) => a.id.value.compareTo(b.id.value));
  return order;
}

/// Die Seite zu [factId] in [order], oder `null`, wenn der Fakt nicht in der
/// Folge steht.
///
/// ## Warum `null` und keine Ausnahme
///
/// Der Fakt kann aus der Folge fallen, während er offen ist. Der Sammelzustand
/// ist ein Notifier, und die Folge enthält nur Gesammeltes; ein Zurücknehmen
/// leert die Seite unter dem Leser weg. Die Quelle hat denselben Fall und
/// zeigt dann nichts (`if (!fact) return null`, `:1449`, und
/// `{factsHasReader && …}`, `:1905`). Hier führt `null` zurück auf die
/// Kapitelliste, weil eine leere Buchseite kein Zustand ist, den ein Nutzer
/// deuten kann.
LibraryReaderPage? libraryReaderPageOf({
  required List<Fact> order,
  required int factId,
}) {
  final int index = order.indexWhere((Fact fact) => fact.id.value == factId);
  if (index < 0) {
    return null;
  }
  return LibraryReaderPage(
    fact: order[index],
    previous: index > 0 ? order[index - 1] : null,
    next: index < order.length - 1 ? order[index + 1] : null,
    number: index + 1,
    count: order.length,
  );
}
