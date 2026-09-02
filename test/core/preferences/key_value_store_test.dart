import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der flüchtige Schlüssel-Wert-Speicher, Rückfall und Testdoppel in einem.
void main() {
  test('ein leerer Speicher liefert für jeden Schlüssel null', () {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();

    expect(store.readBool('a'), isNull);
    expect(store.readString('a'), isNull);
  });

  test('vorgesetzte Werte werden gelesen', () {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      'flag': true,
      'text': 'de',
    });

    expect(store.readBool('flag'), isTrue);
    expect(store.readString('text'), 'de');
  });

  test('ein falsch typisierter Wert liest sich wie ein fehlender', () {
    // Der Fall entsteht bei einem Formatwechsel: gestern eine Zeichenkette,
    // heute ein Wahrheitswert. Der Vertrag verlangt dafür `null` und keine
    // Ausnahme, weil der Aufrufer in beiden Fällen dasselbe tun kann.
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      'flag': 'true',
      'text': 1,
    });

    expect(store.readBool('flag'), isNull);
    expect(store.readString('text'), isNull);
  });

  test('geschrieben wird gelesen', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();

    await store.writeBool('flag', true);
    await store.writeString('text', 'en');

    expect(store.readBool('flag'), isTrue);
    expect(store.readString('text'), 'en');
  });

  test('ein zweiter Schreibvorgang ersetzt den ersten', () async {
    // Drei Schreibvorgänge und nicht zwei, wie im Jagd-Speicher: bei zwei sind
    // „der letzte gewinnt" und „der erste bleibt" nicht unterscheidbar, wenn
    // der Anfangszustand leer ist.
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();

    await store.writeString('text', 'de');
    await store.writeString('text', 'en');
    await store.writeString('text', 'fr');

    expect(store.readString('text'), 'fr');
  });

  test(
    'ein Schreibvorgang darf den Typ unter einem Schlüssel wechseln',
    () async {
      // Nicht verboten, und deshalb geprüft: der Speicher hält Werte und nicht
      // Typzusagen. Wer den Typ wechselt, verliert den alten Wert, und genau das
      // ist die Wirkung eines Formatwechsels.
      final InMemoryKeyValueStore store = InMemoryKeyValueStore(
        <String, Object>{'k': 'text'},
      );

      await store.writeBool('k', true);

      expect(store.readBool('k'), isTrue);
      expect(store.readString('k'), isNull);
    },
  );

  test('löschen macht den Schlüssel leer', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      'flag': true,
    });

    await store.remove('flag');

    expect(store.readBool('flag'), isNull);
  });

  test('löschen ohne Wert ist erlaubt und ändert nichts', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      'flag': true,
    });

    await store.remove('unbekannt');

    expect(store.readBool('flag'), isTrue);
  });

  test('die vorgesetzte Abbildung wird kopiert', () async {
    // Ohne die Kopie im Konstruktor teilte sich ein Test seine Vorgabe mit dem
    // Speicher, und ein Schreibvorgang veränderte rückwirkend das Literal, mit
    // dem er gebaut wurde. Das ist die Art Kopplung, die erst im dritten Test
    // einer Datei auffällt.
    final Map<String, Object> initial = <String, Object>{'flag': true};
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(initial);

    await store.writeBool('flag', false);
    await store.writeString('neu', 'x');

    expect(initial, <String, Object>{'flag': true});
    expect(store.readBool('flag'), isFalse);
  });
}
