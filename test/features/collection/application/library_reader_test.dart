import 'package:fact_app/features/collection/application/library_reader.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Blätterfolge des Lesemodus und die Seite darin.
///
/// Die Zahlen in den Erwartungen sind **ausgeschrieben** und lesen keine
/// Konstante der Produktion. Ein Test, der dieselbe Konstante liest, die er
/// prüft, hält jede Änderung für richtig; das ist Muster 18 des
/// Blindheitskatalogs und hat in Schritt 46 eine Mutation überlebt.
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

  group('libraryReaderOrder', () {
    test('nimmt nur gesammelte Fakten', () {
      final List<Fact> order = libraryReaderOrder(
        facts: <Fact>[factWith(id: 1), factWith(id: 2), factWith(id: 3)],
        cityKey: 'muenchen',
        collected: <int>{1, 3},
      );

      expect(
        order.map((Fact f) => f.id.value),
        <int>[1, 3],
        reason: 'Das Buch enthält, was man gelesen hat.',
      );
    });

    test('nimmt nur Fakten der Stadt', () {
      final List<Fact> order = libraryReaderOrder(
        facts: <Fact>[
          factWith(id: 1),
          factWith(id: 2, city: 'Rom'),
          factWith(id: 3),
        ],
        cityKey: 'muenchen',
        collected: <int>{1, 2, 3},
      );

      expect(order.map((Fact f) => f.id.value), <int>[1, 3]);
    });

    test('sortiert aufsteigend nach Kennung, unabhängig von der Eingabe', () {
      final List<Fact> order = libraryReaderOrder(
        facts: <Fact>[factWith(id: 412), factWith(id: 7), factWith(id: 99)],
        cityKey: 'muenchen',
        collected: <int>{7, 99, 412},
      );

      expect(
        order.map((Fact f) => f.id.value),
        <int>[7, 99, 412],
        reason:
            'Die Folge im Buch ist die der Datenbank und nicht die des '
            'Sammelns.',
      );
    });

    test('ohne Kapitel bleibt der ganze Band in der Folge', () {
      final List<Fact> order = libraryReaderOrder(
        facts: <Fact>[
          factWith(id: 1),
          factWith(id: 2, category: 'Mythos'),
        ],
        cityKey: 'muenchen',
        collected: <int>{1, 2},
      );

      expect(order.map((Fact f) => f.id.value), <int>[1, 2]);
    });

    test('mit Kapitel bleibt nur dessen Kategorie', () {
      final List<Fact> order = libraryReaderOrder(
        facts: <Fact>[
          factWith(id: 1),
          factWith(id: 2, category: 'Mythos'),
          factWith(id: 3),
        ],
        cityKey: 'muenchen',
        collected: <int>{1, 2, 3},
        categoryKey: 'hist',
      );

      expect(order.map((Fact f) => f.id.value), <int>[1, 3]);
    });

    test('der Kapitelfilter geht über den Kategorieschlüssel, nicht den '
        'Rohtext', () {
      // `Historical` ist der englische Kategorietext derselben Kategorie.
      // Verglichen wird nach `libraryCategoryKeyOf`, sonst fiele ein
      // englischer Datensatz aus seinem eigenen Kapitel heraus.
      final List<Fact> order = libraryReaderOrder(
        facts: <Fact>[
          factWith(id: 1, category: 'Historisch'),
          factWith(id: 2, category: 'Historical'),
        ],
        cityKey: 'muenchen',
        collected: <int>{1, 2},
        categoryKey: 'hist',
      );

      expect(order.map((Fact f) => f.id.value), <int>[1, 2]);
    });

    test('eine Stadt ohne Gesammeltes hat eine leere Folge', () {
      final List<Fact> order = libraryReaderOrder(
        facts: <Fact>[factWith(id: 1)],
        cityKey: 'muenchen',
        collected: <int>{},
      );

      expect(order, isEmpty);
    });
  });

  group('libraryReaderPageOf', () {
    List<Fact> order() => <Fact>[
      factWith(id: 10),
      factWith(id: 20),
      factWith(id: 30),
    ];

    test('die erste Seite hat keinen Vorgänger', () {
      final LibraryReaderPage page = libraryReaderPageOf(
        order: order(),
        factId: 10,
      )!;

      expect(page.previous, isNull);
      expect(page.hasPrevious, isFalse);
      expect(page.next?.id.value, 20);
      expect(page.number, 1);
      expect(page.count, 3);
    });

    test('die letzte Seite hat keinen Nachfolger', () {
      final LibraryReaderPage page = libraryReaderPageOf(
        order: order(),
        factId: 30,
      )!;

      expect(page.previous?.id.value, 20);
      expect(page.next, isNull);
      expect(page.hasNext, isFalse);
      expect(page.number, 3);
      expect(page.count, 3);
    });

    test('eine Seite in der Mitte hat beide Nachbarn', () {
      final LibraryReaderPage page = libraryReaderPageOf(
        order: order(),
        factId: 20,
      )!;

      expect(page.previous?.id.value, 10);
      expect(page.next?.id.value, 30);
      expect(page.number, 2);
    });

    test('eine einzelne Seite hat keine Nachbarn und heißt 1 von 1', () {
      final LibraryReaderPage page = libraryReaderPageOf(
        order: <Fact>[factWith(id: 5)],
        factId: 5,
      )!;

      expect(page.hasPrevious, isFalse);
      expect(page.hasNext, isFalse);
      expect(page.number, 1);
      expect(page.count, 1);
    });

    test('ein Fakt, der nicht in der Folge steht, gibt null', () {
      // Der Fall entsteht, wenn ein Fakt zurückgenommen wird, während seine
      // Seite offen ist.
      expect(libraryReaderPageOf(order: order(), factId: 999), isNull);
    });

    test('eine leere Folge gibt null', () {
      expect(libraryReaderPageOf(order: <Fact>[], factId: 10), isNull);
    });

    test('die Nummer zählt ab eins und nicht ab null', () {
      // Getrennt vom Nachbarn-Test, damit eine Mutation an `index + 1` nicht
      // von einer Erwartung an `previous` mitgedeckt wird.
      expect(libraryReaderPageOf(order: order(), factId: 10)!.number, 1);
      expect(libraryReaderPageOf(order: order(), factId: 20)!.number, 2);
      expect(libraryReaderPageOf(order: order(), factId: 30)!.number, 3);
    });

    test('toString nennt Kennung und Stand', () {
      expect(
        libraryReaderPageOf(order: order(), factId: 20)!.toString(),
        'LibraryReaderPage(20, 2/3)',
      );
    });
  });

  group('LibraryReaderScope', () {
    test('hat genau zwei Fälle', () {
      // Ein dritter Zusammenhang wäre eine Produktentscheidung. Die Quelle
      // kennt daneben `theme` für die thematischen Touren, und der verhält
      // sich in der Sortierung wie `chapter`; ein eigener Fall wäre hier ohne
      // Unterschied.
      expect(LibraryReaderScope.values, <LibraryReaderScope>[
        LibraryReaderScope.volume,
        LibraryReaderScope.chapter,
      ]);
    });
  });
}
