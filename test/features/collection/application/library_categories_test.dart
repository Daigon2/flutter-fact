import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die sechs Kapitel eines Bands.
///
/// Der wichtigste Block ist der letzte: er nagelt fest, welche der zwölf
/// Kartenkategorien im Reiseführer in „Historisch" landen (E-78). Ohne ihn
/// ließe sich der Rückfall „korrigieren", und die Kapitelzahl auf jedem Cover
/// verschöbe sich, ohne dass ein Test rot wird.
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
    test('die sechs Schlüssel der Quelle treffen sich selbst', () {
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

  group('E-78: was im Kapitel „Historisch" landet, ohne dort hinzugehören', () {
    // Diese fünf Kategorietexte kennt `factCategoryAliases` als eigene
    // Kartenkategorien (`kul`, `pers`, `kult`, `dark`, `kirche`).
    // `walletKatToKey` hat für keine von ihnen eine Zeile, alle fallen auf
    // `hist`. Ein Fakt über ein Restaurant steht damit im Reiseführer unter
    // Geschichte.
    const Map<String, String> foldedIntoHistory = <String, String>{
      'Kulinarik': 'kul',
      'Kulinarisch': 'kul',
      'Food & Drink': 'kul',
      'Persönlichkeiten': 'pers',
      'Personalities': 'pers',
      'Historical Figures': 'pers',
      'Kultur': 'kult',
      'Kunst & Kultur': 'kult',
      'Art & Culture': 'kult',
      'Dunkel & Kriminell': 'dark',
      'Dark & Criminal': 'dark',
      'Dark History': 'dark',
      'Kirche & Glaube': 'kirche',
      'Church & Faith': 'kirche',
    };

    test('alle vierzehn Texte fallen auf hist', () {
      for (final MapEntry<String, String> entry in foldedIntoHistory.entries) {
        expect(
          libraryCategoryKeyOf(entry.key),
          'hist',
          reason:
              '"${entry.key}" ist auf der Karte "${entry.value}" und '
              'im Reiseführer erwartet "hist"',
        );
      }
    });

    test('Historical Figures ist der auffälligste Fall', () {
      // Die Karte führt es als `pers`, ausdrücklich **nicht** als `hist`
      // (`factCategoryAliases`). Der Reiseführer macht daraus Geschichte,
      // weil der Text mit „hist" anfängt. Zwei Tabellen, ein Text, zwei
      // Antworten.
      expect(libraryCategoryKeyOf('Historical Figures'), 'hist');
    });

    test('„Dark History" trifft hist über den Rückfall, nicht über „hist"', () {
      // Die Prüfung ist `startsWith` und nicht `contains`: „dark history"
      // **enthält** `hist`, fängt aber nicht damit an. Es landet also über den
      // Rückfall dort, wie die anderen dreizehn. Steht als eigener Fall da,
      // weil ein Umbau auf `contains` denselben Wert liefern würde und damit
      // vier andere Texte still verschöbe (`Kunst & Kultur` enthält kein
      // `hist`, `Dunkel & Kriminell` auch nicht, `Historical Figures` schon).
      expect(libraryCategoryKeyOf('Dark History'), 'hist');
      expect('dark history'.startsWith('hist'), isFalse);
      expect('dark history'.contains('hist'), isTrue);
    });
  });

  group('Kapitel eines Bands', () {
    test('immer alle sechs, immer in der Reihenfolge der Quelle', () {
      final List<LibraryChapter> chapters = libraryChaptersOf(
        facts: <Fact>[factWith(id: 1)],
        cityKey: 'muenchen',
        collected: const <int>{},
      );

      expect(
        chapters.map((LibraryChapter c) => c.categoryKey),
        libraryCategoryOrder,
      );
      expect(chapters.length, 6);
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
