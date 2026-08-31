import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/identity/data/key_value_first_launch_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der persistente Startbildschirm-Merker.
void main() {
  test('ohne gespeicherten Wert gilt: noch nicht gestartet', () {
    // Der Standard muss `false` sein und nicht `null`-durchgereicht: die Weiche
    // im Router entscheidet daran, und „ich weiß es nicht" gibt es dort nicht.
    final KeyValueStore preferences = InMemoryKeyValueStore();

    expect(KeyValueFirstLaunchStore(preferences).hasLaunched(), isFalse);
  });

  test('ein gespeichertes true wird gelesen', () {
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueFirstLaunchStore.storageKey: true,
    });

    expect(KeyValueFirstLaunchStore(preferences).hasLaunched(), isTrue);
  });

  test('ein gespeichertes false wird gelesen', () {
    // Die Gegenprobe zum Test darüber. Ohne sie käme auch eine Umsetzung durch,
    // die jeden vorhandenen Schlüssel als `true` liest.
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueFirstLaunchStore.storageKey: false,
    });

    expect(KeyValueFirstLaunchStore(preferences).hasLaunched(), isFalse);
  });

  test('markLaunched schreibt und ist danach lesbar', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();
    final KeyValueFirstLaunchStore store = KeyValueFirstLaunchStore(
      preferences,
    );

    await store.markLaunched();

    expect(store.hasLaunched(), isTrue);
  });

  test('markLaunched schreibt unter den Schlüssel der Quelle', () async {
    // Geprüft am Speicher und nicht am Speicher-Objekt: dass der richtige
    // Schlüssel benutzt wird, ist aus `hasLaunched()` allein nicht zu sehen,
    // denn eine Umsetzung mit einem falschen, aber konsistenten Schlüssel wäre
    // in sich stimmig und trotzdem falsch.
    final KeyValueStore preferences = InMemoryKeyValueStore();

    await KeyValueFirstLaunchStore(preferences).markLaunched();

    expect(preferences.readBool('fact_has_launched'), isTrue);
  });

  test('markLaunched ist idempotent', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();
    final KeyValueFirstLaunchStore store = KeyValueFirstLaunchStore(
      preferences,
    );

    await store.markLaunched();
    await store.markLaunched();

    expect(store.hasLaunched(), isTrue);
  });
}
