import 'package:fact_app/features/facts/domain/collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der flüchtige Sammel-Speicher.
///
/// Er ist der Standard, solange `bootstrap()` den Provider nicht überschrieben
/// hat, und damit derselbe stille Ausfall, den `bootstrap_test.dart` für die
/// fünf Speicher davor absichert. Hier steht nur, dass er sich innerhalb einer
/// Sitzung richtig verhält.
void main() {
  group('InMemoryCollectedFactsStore', () {
    test('ist leer, wenn niemand etwas gesammelt hat', () {
      expect(InMemoryCollectedFactsStore().readCollectedFacts(), isEmpty);
    });

    test('nimmt auf und behält die Reihenfolge', () async {
      // Die Reihenfolge ist keine Zufälligkeit der Umsetzung: die Quelle
      // liest den **letzten** Eintrag, um nach dem Sammeln das Tour-Rätsel
      // des gerade gefundenen Fakts nachzuschieben
      // (`screen-map.jsx:1514`).
      final store = InMemoryCollectedFactsStore();

      await store.collectFact(const FactId(7));
      await store.collectFact(const FactId(3));
      await store.collectFact(const FactId(19));

      expect(store.readCollectedFacts(), const <FactId>[
        FactId(7),
        FactId(3),
        FactId(19),
      ]);
    });

    test('nimmt denselben Fakt nicht zweimal auf', () async {
      final store = InMemoryCollectedFactsStore();

      await store.collectFact(const FactId(7));
      await store.collectFact(const FactId(7));

      expect(store.readCollectedFacts(), const <FactId>[FactId(7)]);
    });

    test('ein zweiter Aufruf verschiebt den Fakt nicht ans Ende', () async {
      // Der Unterschied zu „entfernen und neu anhängen", und er ist die
      // Form der Quelle (`if (!arr.includes(id)) arr.push(id)`,
      // `storage.jsx:51`). Wer zweimal sammelt, hat beim ersten Mal
      // gesammelt, und der letzte Eintrag der Liste hängt daran.
      final store = InMemoryCollectedFactsStore();

      await store.collectFact(const FactId(7));
      await store.collectFact(const FactId(3));
      await store.collectFact(const FactId(7));

      expect(store.readCollectedFacts().last, const FactId(3));
    });

    test('nimmt eine vorgefüllte Sammlung an', () {
      expect(
        InMemoryCollectedFactsStore(const <FactId>[
          FactId(4),
        ]).readCollectedFacts(),
        const <FactId>[FactId(4)],
      );
    });

    test('kopiert die vorgefüllte Liste', () {
      // Ein Test, der sein Literal nach dem Bau noch ändert, soll den
      // Speicher nicht mitverändern. Dieselbe Zusicherung wie bei
      // `InMemoryKeyValueStore`.
      final List<FactId> given = <FactId>[const FactId(4)];
      final store = InMemoryCollectedFactsStore(given);

      given.add(const FactId(9));

      expect(store.readCollectedFacts(), const <FactId>[FactId(4)]);
    });

    test('gibt eine Liste heraus, die der Aufrufer nicht ändern kann', () {
      // Sonst könnte ein Leser die Sammlung eines anderen erweitern, ohne
      // dass sie je gespeichert wird.
      final store = InMemoryCollectedFactsStore(const <FactId>[FactId(4)]);

      expect(
        () => store.readCollectedFacts().add(const FactId(9)),
        throwsUnsupportedError,
      );
    });
  });
}
