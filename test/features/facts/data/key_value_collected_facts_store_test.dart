import 'dart:convert';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/facts/data/key_value_collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Sammel-Speicher auf dem Gerätespeicher.
///
/// **Die teuerste Zusicherung hier ist die dritte Gruppe.** Ein Eintrag, den
/// niemand lesen kann, darf nicht die ganze Sammlung kosten. Der Jagd-Speicher
/// daneben entscheidet genau umgekehrt, und der Unterschied ist begründet: eine
/// halbe Jagd ist keine Jagd, eine Sammlung ohne einen Eintrag ist eine
/// Sammlung.
void main() {
  group('lesen', () {
    test('ohne gespeicherten Wert ist die Sammlung leer', () {
      final store = KeyValueCollectedFactsStore(InMemoryKeyValueStore());

      expect(store.readCollectedFacts(), isEmpty);
    });

    test('ein leerer Schlüssel meldet nichts', () {
      // Der Normalzustand jedes neuen Nutzers. Ihn zu melden hieße, die Senke
      // bei jedem Start mit einer Nichtmeldung zu füllen; dieselbe Regel wie
      // beim leeren Jagd-Schlüssel.
      final sink = RecordingDiagnosticSink();

      KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(),
        sink: sink,
      ).readCollectedFacts();

      expect(sink.events, isEmpty);
    });

    test('liest die gespeicherte Sammlung in ihrer Reihenfolge', () {
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: '[7,3,19]',
        }),
      );

      expect(store.readCollectedFacts(), const <FactId>[
        FactId(7),
        FactId(3),
        FactId(19),
      ]);
    });

    test('der Schlüssel heißt wie in der Quelle', () {
      // `'fact_' + 'collected'`, also `storage.jsx:4` und `:48`. Als
      // Nachvollziehbarkeit und **nicht** als gemeinsame Nutzung: die PWA und
      // diese App laufen nicht auf demselben Speicher.
      expect(KeyValueCollectedFactsStore.storageKey, 'fact_collected');
    });

    test('gibt eine Liste heraus, die der Aufrufer nicht ändern kann', () {
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: '[7]',
        }),
      );

      expect(
        () => store.readCollectedFacts().add(const FactId(9)),
        throwsUnsupportedError,
      );
    });

    test('liest jedes Mal neu vom Gerätespeicher', () async {
      // Kein eigener Zwischenspeicher, und das ist eine Entscheidung: ein
      // Feld, das nach dem ersten Lesen stehen bleibt, wäre eine zweite
      // Wahrheit neben dem Gerätespeicher.
      final preferences = InMemoryKeyValueStore(<String, Object>{
        KeyValueCollectedFactsStore.storageKey: '[7]',
      });
      final store = KeyValueCollectedFactsStore(preferences);

      expect(store.readCollectedFacts(), const <FactId>[FactId(7)]);
      await preferences.writeString(
        KeyValueCollectedFactsStore.storageKey,
        '[7,8]',
      );

      expect(store.readCollectedFacts(), const <FactId>[FactId(7), FactId(8)]);
    });
  });

  group('schreiben', () {
    test('nimmt einen Fakt auf', () async {
      final preferences = InMemoryKeyValueStore();
      final store = KeyValueCollectedFactsStore(preferences);

      await store.collectFact(const FactId(7));

      expect(
        preferences.readString(KeyValueCollectedFactsStore.storageKey),
        '[7]',
      );
    });

    test('hängt an und wirft die bestehende Sammlung nicht weg', () async {
      final preferences = InMemoryKeyValueStore(<String, Object>{
        KeyValueCollectedFactsStore.storageKey: '[7,3]',
      });
      final store = KeyValueCollectedFactsStore(preferences);

      await store.collectFact(const FactId(19));

      expect(
        preferences.readString(KeyValueCollectedFactsStore.storageKey),
        '[7,3,19]',
      );
    });

    test('schreibt für einen Fakt, der schon drin ist, gar nicht', () async {
      // Nicht bloß „ändert nichts": ein Schreibvorgang, der dasselbe
      // hinschreibt, ist auf dem Gerät trotzdem einer. Nachgewiesen über
      // einen Speicher, der jeden Schreibvorgang mitzählt.
      final preferences = CountingKeyValueStore(<String, Object>{
        KeyValueCollectedFactsStore.storageKey: '[7]',
      });
      final store = KeyValueCollectedFactsStore(preferences);

      await store.collectFact(const FactId(7));

      expect(preferences.writes, 0);
      expect(
        preferences.readString(KeyValueCollectedFactsStore.storageKey),
        '[7]',
      );
    });

    test('überlebt einen Speicher, der nicht schreiben kann', () async {
      // Der Vertrag von `KeyValueStore.writeString` verschluckt den Fehler,
      // und dieser Speicher darf deshalb nicht werfen. Der Preis steht im
      // Vertrag: derselbe Fakt kann beim nächsten Start noch einmal
      // eingesammelt werden.
      final store = KeyValueCollectedFactsStore(FailingKeyValueStore());

      await expectLater(store.collectFact(const FactId(7)), completes);
      expect(store.readCollectedFacts(), isEmpty);
    });
  });

  group('ein defekter Eintrag kostet nicht die ganze Sammlung', () {
    test('behält, was lesbar ist, und meldet den Rest', () {
      final sink = RecordingDiagnosticSink();
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: '[7,"acht",null,19]',
        }),
        sink: sink,
      );

      expect(store.readCollectedFacts(), const <FactId>[FactId(7), FactId(19)]);
      expect(sink.events.single.name, 'facts.collected_entries_discarded');
      expect(
        sink.events.single.attributes[KeyValueCollectedFactsStore
            .discardedCountField],
        '2',
      );
    });

    test('eine Zahl mit Nachkommastelle ist keine Kennung', () {
      // `jsonDecode` liefert für `7.0` ein `double`. Stillschweigend zu
      // runden hieße, einen fremden Fakt in die Sammlung zu nehmen.
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: '[7.5]',
        }),
      );

      expect(store.readCollectedFacts(), isEmpty);
    });

    test('die Null und negative Zahlen sind keine Kennungen', () {
      // `facts.id` ist `generated always as identity` und beginnt bei 1.
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: '[0,-3,5]',
        }),
      );

      expect(store.readCollectedFacts(), const <FactId>[FactId(5)]);
    });

    test('doppelte Einträge werden entdoppelt, aber nicht gemeldet', () {
      // `collectFact` erzeugt sie nie. Ein von Hand veränderter Speicher ist
      // keine Meldung wert, die wie ein Datenverlust aussieht.
      final sink = RecordingDiagnosticSink();
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: '[7,7,3]',
        }),
        sink: sink,
      );

      expect(store.readCollectedFacts(), const <FactId>[FactId(7), FactId(3)]);
      expect(sink.events, isEmpty);
    });

    test('eine ganz unlesbare Zeichenkette ergibt eine leere Sammlung', () {
      final sink = RecordingDiagnosticSink();
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: 'kein json',
        }),
        sink: sink,
      );

      expect(store.readCollectedFacts(), isEmpty);
      expect(sink.events.single.name, 'facts.collected_entries_discarded');
    });

    test('etwas, das kein JSON-Feld ist, ergibt eine leere Sammlung', () {
      // `{"7": true}` ist gültiges JSON und keine Liste. Der Unterschied zur
      // Zeile darüber ist kein Randfall, sondern der Fall „jemand hat unter
      // diesem Schlüssel etwas anderes abgelegt".
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: '{"7": true}',
        }),
      );

      expect(store.readCollectedFacts(), isEmpty);
    });

    test('ein Wert vom falschen Typ im Gerätespeicher meldet nichts', () {
      // `readString` gibt für einen `bool` unter demselben Schlüssel `null`
      // zurück, siehe den Vertrag von `KeyValueStore`. Für diesen Speicher
      // ist das nicht von „nichts gespeichert" zu unterscheiden, und er soll
      // daraus keinen Datenverlust melden.
      final sink = RecordingDiagnosticSink();
      final store = KeyValueCollectedFactsStore(
        InMemoryKeyValueStore(<String, Object>{
          KeyValueCollectedFactsStore.storageKey: true,
        }),
        sink: sink,
      );

      expect(store.readCollectedFacts(), isEmpty);
      expect(sink.events, isEmpty);
    });
  });

  group('lesen und schreiben zusammen', () {
    test('was geschrieben wurde, kommt zurück', () async {
      final preferences = InMemoryKeyValueStore();
      final store = KeyValueCollectedFactsStore(preferences);

      await store.collectFact(const FactId(7));
      await store.collectFact(const FactId(3));

      expect(
        KeyValueCollectedFactsStore(preferences).readCollectedFacts(),
        const <FactId>[FactId(7), FactId(3)],
      );
    });

    test('schreibt reines JSON aus Zahlen', () {
      // Damit ein Leser, der die Zeichenkette von Hand ansieht, dasselbe
      // Format vorfindet wie in der Quelle.
      expect(jsonDecode('[7,3]'), <int>[7, 3]);
    });
  });
}

/// Nimmt auf, was gemeldet wurde.
class RecordingDiagnosticSink implements DiagnosticSink {
  /// Alles, was gemeldet wurde, in der Reihenfolge des Eingangs.
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}

/// Zählt Schreibvorgänge mit.
///
/// **Umgelegt statt geerbt**, weil `InMemoryKeyValueStore` ein `final class`
/// ist und sich nicht beerben lässt. Das ist auch die bessere Form: dieser
/// Zähler soll nicht versehentlich am Innenleben des Vorbilds hängen.
class CountingKeyValueStore implements KeyValueStore {
  /// [values] setzt einen bereits gefüllten Speicher.
  CountingKeyValueStore([Map<String, Object> values = const {}])
    : _inner = InMemoryKeyValueStore(values);

  final InMemoryKeyValueStore _inner;

  /// Wie oft geschrieben wurde.
  int writes = 0;

  @override
  bool? readBool(String key) => _inner.readBool(key);

  @override
  String? readString(String key) => _inner.readString(key);

  @override
  Future<void> writeBool(String key, bool value) {
    writes++;
    return _inner.writeBool(key, value);
  }

  @override
  Future<void> writeString(String key, String value) {
    writes++;
    return _inner.writeString(key, value);
  }

  @override
  Future<void> remove(String key) => _inner.remove(key);
}

/// Ein Gerätespeicher, der nichts behält.
///
/// Kein Werfen: der Vertrag von `KeyValueStore` sagt „Schreiben scheitert
/// still", und das ist genau die Bauform, die dieser Test prüft.
class FailingKeyValueStore implements KeyValueStore {
  @override
  bool? readBool(String key) => null;

  @override
  String? readString(String key) => null;

  @override
  Future<void> writeBool(String key, bool value) async {}

  @override
  Future<void> writeString(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}
}
