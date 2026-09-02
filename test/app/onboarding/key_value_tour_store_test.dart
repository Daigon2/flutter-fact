import 'package:fact_app/app/onboarding/key_value_tour_store.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der persistente Tutorial-Merker.
void main() {
  test('ohne gespeicherten Wert gilt: Tutorial noch nicht gesehen', () {
    expect(KeyValueTourStore(InMemoryKeyValueStore()).hasSeenTour(), isFalse);
  });

  test('ein gespeichertes true wird gelesen', () {
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueTourStore.storageKey: true,
    });

    expect(KeyValueTourStore(preferences).hasSeenTour(), isTrue);
  });

  test('ein gespeichertes false wird gelesen', () {
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueTourStore.storageKey: false,
    });

    expect(KeyValueTourStore(preferences).hasSeenTour(), isFalse);
  });

  test('die Zeichenkette der Quelle zählt hier nicht als true', () {
    // Die Quelle legt unter diesem Schlüssel „true" als **Zeichenkette** ab
    // (`storage.jsx:101`). Hier ist es ein Wahrheitswert. Die beiden Speicher
    // haben nichts miteinander zu tun, aber der Fall ist billig zu prüfen und
    // hält fest, dass niemand versehentlich eine Zeichenkette erwartet.
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueTourStore.storageKey: 'true',
    });

    expect(KeyValueTourStore(preferences).hasSeenTour(), isFalse);
  });

  test('markTourSeen schreibt unter den Schlüssel der Quelle', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();

    await KeyValueTourStore(preferences).markTourSeen();

    expect(preferences.readBool('fact_tour_shown'), isTrue);
  });

  test('markTourSeen ist idempotent', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();
    final KeyValueTourStore store = KeyValueTourStore(preferences);

    await store.markTourSeen();
    await store.markTourSeen();

    expect(store.hasSeenTour(), isTrue);
  });
}
