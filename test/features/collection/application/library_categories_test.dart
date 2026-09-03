import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die elf Kapitel eines Bands.
///
/// Der wichtigste Block ist der mittlere: er nagelt **jeden** der
/// zweiunddreißig Kategorietexte der Karte auf sein Kapitel fest. Vor dem
/// 03.09.2026 fielen vierzehn davon auf „Historisch", weil die Abbildung
/// nur sechs Ziele kannte (E-78). Ohne diesen Block ließe sich eine Zeile
/// der Abbildung entfernen, und die Kapitel auf jedem Cover verschoben
/// sich, ohne dass ein Test rot wird.
void main() {
  Fact factWith({
    required int id,
    String city = 'München',
    String category = 'Historisch',
  }) => Fact(
    id: FactId(id),
    content: FactText(title: 'Titel $id', category: category),
    city: FactCity(city),
  );

  group('Abbildung', () {
    test('die elf Schlüssel treffen sich selbst', () {
      expect(libraryCategoryKeyOf('Historisch'), 'hist');
      expect(libraryCategoryKeyOf('Architektur'), 'arch');
      expect(libraryCategoryKeyOf('Mythos'), 'myth');
      expect(libraryCategoryKeyOf('Fun-Fact'), 'fun');
      expect(libraryCategoryKeyOf('Geografie'), 'geo');
      expect(libraryCategoryKeyOf('Stadt heute'), 'heute');
    });

    test('die Groß- und Kleinschreibung ist gleichgültig', () {
      expect(libraryCategoryKeyOf('HISTORISCH'), 'hist');
      expect(libraryCategoryKeyOf('architektur'), 'arch');
    });

    test('Geschichte trifft dieselbe Zeile wie Historisch', () {
      // `k.startsWith('hist') || k.startsWith('gesch')`.
      expect(libraryCategoryKeyOf('Geschichte'), 'hist');
    });

    test('Natur fällt bewusst auf Geografie und nicht auf den Rückfall', () {
      // Eigene Zeile in der Quelle, deshalb keine Folge des Rückfalls.
      expect(libraryCategoryKeyOf('Natur'), 'geo');
      expect(libraryCategoryKeyOf('Nature'), 'geo');
    });

    test('die vier Schreibweisen von „Stadt heute" treffen alle', () {
      expect(libraryCategoryKeyOf('Stadt heute'), 'heute');
      expect(libraryCategoryKeyOf('heute'), 'heute');
      expect(libraryCategoryKeyOf('Aktuell'), 'heute');
      expect(libraryCategoryKeyOf('City Today'), 'heute');
      expect(libraryCategoryKeyOf('Today'), 'heute');
    });

    test('„today" trifft nur als ganzes Wort, nicht als Anfang', () {
      // In der Quelle steht dort `k === 'today'` und nicht `startsWith`.
      // Alles andere, was mit „today" anfängt, fällt auf den Rückfall.
      expect(libraryCategoryKeyOf('Todays Special'), 'hist');
    });

    test('ein leerer Text fällt auf den Rückfall', () {
      expect(libraryCategoryKeyOf(''), 'hist');
    });
  });

  group('E-78: jeder Kategorietext der Karte trifft sein Kapitel', () {
    // **Die vollständige Aliastabelle der Karte**, abgeschrieben aus
    // `features/discovery/presentation/fact_categories.dart`, und daneben das
    // Kapitel, in dem der Text im Reiseführer landen muss.
    //
    // Warum abgeschrieben und nicht importiert: Regel 8 lässt `collection`
    // nicht in die Presentation von `discovery`. Diese Liste ist damit die
    // zweite, unabhängige Abschrift, genau wie die Kategorietabelle selbst.
    // Läuft sie auseinander, wird dieser Test rot, und das ist sein Zweck.
    //
    // **`nat` ist der einzige Kartenschlüssel ohne eigenes Kapitel**, mit
    // Absicht: `walletKatToKey` hat für Natur eine Zeile auf `geo`.
    const Map<String, String> expectedChapter = <String, String>{
      'Historisch': 'hist',
      'Historical': 'hist',
      'Historical Figures': 'pers',
      'Architektur': 'arch',
      'Architecture': 'arch',
      'Fun-Fact': 'fun',
      'Fun Fact': 'fun',
      'Geografie': 'geo',
      'Geographie': 'geo',
      'Mythos': 'myth',
      'Mythen': 'myth',
      'Myth & Legend': 'myth',
      'Natur': 'geo',
      'Nature': 'geo',
      'Kulinarik': 'kul',
      'Kulinarisch': 'kul',
      'Food & Drink': 'kul',
      'Persönlichkeiten': 'pers',
      'Personalities': 'pers',
      'Kultur': 'kult',
      'Kunst & Kultur': 'kult',
      'Art & Culture': 'kult',
      'Dunkel & Kriminell': 'dark',
      'Dark & Criminal': 'dark',
      'Dark History': 'dark',
      'Kirche & Glaube': 'kirche',
      'Church & Faith': 'kirche',
      'Stadt heute': 'heute',
      'Stadt Heute': 'heute',
      'City Today': 'heute',
      'Today': 'heute',
      'Aktuell': 'heute',
    };

    test('alle zweiunddreißig Texte treffen', () {
      expect(expectedChapter.length, 32);
      for (final MapEntry<String, String> entry in expectedChapter.entries) {
        expect(
          libraryCategoryKeyOf(entry.key),
          entry.value,
          reason: '"${entry.key}" erwartet Kapitel "${entry.value}"',
        );
      }
    });

    test('kein Text landet mehr im Rückfall, außer er ist unbekannt', () {
      // Vor dem 03.09.2026 fielen vierzehn dieser Texte auf `hist`. Wären es
      // wieder mehr als die vier echten `hist`-Texte, hätte jemand eine Zeile
      // der Abbildung entfernt.
      final Iterable<String> toHistory = expectedChapter.entries
          .where((MapEntry<String, String> e) => e.value == 'hist')
          .map((MapEntry<String, String> e) => e.key);

      expect(toHistory, <String>['Historisch', 'Historical']);
    });

    test('Historical Figures war der auffälligste Fall und ist behoben', () {
      // Die Karte führt es als `pers`, ausdrücklich nicht als `hist`. Weil der
      // Text mit „hist" anfängt, gewinnt in der Quelle die Reihenfolge der
      // Prüfungen. Deshalb steht die `pers`-Zeile jetzt **vor** der
      // `hist`-Zeile, und dieser Test hält genau das fest.
      expect(libraryCategoryKeyOf('Historical Figures'), 'pers');
      expect(libraryCategoryKeyOf('Historisch'), 'hist');
    });

    test('Architektur gewinnt gegen Kunst, ein Buchstabe Unterschied', () {
      // `arch` muss vor `art` geprüft werden. „architektur" fängt mit „arc"
      // an, nicht mit „art", aber wer die Zeilen sortiert, merkt es nicht.
      expect(libraryCategoryKeyOf('Architektur'), 'arch');
      expect(libraryCategoryKeyOf('Art & Culture'), 'kult');
    });

    test('Kulinarik gewinnt gegen Kultur, drei Buchstaben Überschneidung', () {
      expect(libraryCategoryKeyOf('Kulinarik'), 'kul');
      expect(libraryCategoryKeyOf('Kultur'), 'kult');
      expect('kulinarik'.startsWith('kul'), isTrue);
      expect('kultur'.startsWith('kul'), isTrue);
    });

    test('ein unbekannter Text fällt weiter auf hist', () {
      // Der Rückfall der Quelle bleibt. Er fängt jetzt aber nur noch, was
      // wirklich niemand kennt.
      expect(libraryCategoryKeyOf('Quantenphysik'), 'hist');
      expect(libraryCategoryKeyOf(''), 'hist');
    });
  });

  group('Kapitel eines Bands', () {
    test('immer alle elf, immer in derselben Reihenfolge', () {
      final List<LibraryChapter> chapters = libraryChaptersOf(
        facts: <Fact>[factWith(id: 1)],
        cityKey: 'muenchen',
        collected: const <int>{},
      );

      expect(
        chapters.map((LibraryChapter c) => c.categoryKey),
        libraryCategoryOrder,
      );
      expect(chapters.length, 11);
    });

    test('gezählt werden Fakten der eigenen Stadt', () {
      final List<LibraryChapter> chapters = libraryChaptersOf(
        facts: <Fact>[
          factWith(id: 1, category: 'Architektur'),
          factWith(id: 2, category: 'Architektur', city: 'Rom'),
        ],
        cityKey: 'muenchen',
        collected: const <int>{1, 2},
      );

      final LibraryChapter arch = chapters.firstWhere(
        (LibraryChapter c) => c.categoryKey == 'arch',
      );
      expect(arch.total, 1);
      expect(arch.collected, 1);
    });

    test('ein leeres Kapitel bleibt in der Liste', () {
      // Die Kapitelliste aus Schritt 47 zeichnet „0 von 12" anders als ein
      // Kapitel, das es nicht gibt.
      final List<LibraryChapter> chapters = libraryChaptersOf(
        facts: <Fact>[factWith(id: 1, category: 'Mythos')],
        cityKey: 'muenchen',
        collected: const <int>{},
      );

      final LibraryChapter fun = chapters.firstWhere(
        (LibraryChapter c) => c.categoryKey == 'fun',
      );
      expect(fun.total, 0);
      expect(fun.collected, 0);
      expect(fun.isStarted, isFalse);
    });

    test('angefangen heißt mindestens ein gesammelter Fakt', () {
      final List<LibraryChapter> chapters = libraryChaptersOf(
        facts: <Fact>[
          factWith(id: 1, category: 'Mythos'),
          factWith(id: 2, category: 'Fun-Fact'),
          factWith(id: 3, category: 'Fun-Fact'),
        ],
        cityKey: 'muenchen',
        collected: const <int>{2},
      );

      expect(chapters.where((LibraryChapter c) => c.isStarted).length, 1);
      // Und das ist der Kern der Kapitelzahl auf dem Cover: gezählt wird, was
      // angefangen ist, nicht was existiert.
      expect(chapters.where((LibraryChapter c) => c.total > 0).length, 2);
    });

    test('ein Fakt ohne Stadt zählt in keinem Kapitel', () {
      final List<LibraryChapter> chapters = libraryChaptersOf(
        facts: <Fact>[
          Fact(
            id: FactId(1),
            content: const FactText(title: 'Ohne Stadt', category: 'Mythos'),
          ),
        ],
        cityKey: 'muenchen',
        collected: const <int>{1},
      );

      expect(chapters.every((LibraryChapter c) => c.total == 0), isTrue);
    });

    test('Kapitel haben Wertgleichheit', () {
      const LibraryChapter a = LibraryChapter(
        categoryKey: 'hist',
        collected: 1,
        total: 2,
      );
      const LibraryChapter b = LibraryChapter(
        categoryKey: 'hist',
        collected: 1,
        total: 2,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
