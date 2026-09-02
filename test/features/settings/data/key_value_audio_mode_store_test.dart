import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/settings/data/key_value_audio_mode_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die persistente Audio-Präferenz.
void main() {
  test('ohne gespeicherten Wert ist der Audio-Modus aus', () {
    expect(
      KeyValueAudioModeStore(InMemoryKeyValueStore()).isEnabled(),
      isFalse,
    );
  });

  test('ein gespeichertes true wird gelesen', () {
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueAudioModeStore.storageKey: true,
    });

    expect(KeyValueAudioModeStore(preferences).isEnabled(), isTrue);
  });

  test('setEnabled schreibt unter den Schlüssel der Quelle', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();

    await KeyValueAudioModeStore(preferences).setEnabled(true);

    expect(preferences.readBool('fact_audio_mode'), isTrue);
  });

  test('setEnabled schaltet auch wieder aus', () async {
    // **Der Unterschied zu den beiden Einbahn-Schaltern**, und deshalb ein
    // eigener Test: der Vertrag verlangt hier einen echten Umschalter, weil der
    // Dialogtext das Ausschalten im Profil verspricht. Eine Umsetzung, die wie
    // `markLaunched` immer `true` schriebe, käme durch jeden anderen Test
    // dieser Datei.
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueAudioModeStore.storageKey: true,
    });
    final KeyValueAudioModeStore store = KeyValueAudioModeStore(preferences);

    await store.setEnabled(false);

    expect(store.isEnabled(), isFalse);
  });

  test('derselbe Wert zweimal ändert nichts', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();
    final KeyValueAudioModeStore store = KeyValueAudioModeStore(preferences);

    await store.setEnabled(true);
    await store.setEnabled(true);

    expect(store.isEnabled(), isTrue);
  });
}
