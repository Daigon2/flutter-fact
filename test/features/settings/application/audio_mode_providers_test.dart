import 'package:fact_app/features/settings/application/audio_mode_providers.dart';
import 'package:fact_app/features/settings/domain/audio_mode_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Audio-Guide-Präferenz als Zustand.
void main() {
  ProviderContainer containerWith(AudioModeStore store) {
    final container = ProviderContainer(
      overrides: [audioModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('der Anfangszustand kommt aus dem Speicher', () {
    expect(
      containerWith(InMemoryAudioModeStore()).read(audioModeProvider),
      isFalse,
    );
    expect(
      containerWith(
        InMemoryAudioModeStore(enabled: true),
      ).read(audioModeProvider),
      isTrue,
    );
  });

  test('enable setzt den Zustand und schreibt danach', () async {
    final store = InMemoryAudioModeStore();
    final container = containerWith(store);

    await container.read(audioModeProvider.notifier).enable();

    expect(container.read(audioModeProvider), isTrue);
    expect(store.isEnabled(), isTrue);
  });

  test('ein zweiter Aufruf schreibt erneut, benachrichtigt aber nicht', () async {
    // Die Zusicherung zur Entscheidung in `AudioModeNotifier.enable`: dort
    // steht bewusst **kein** `if (state) return`. Der Schreibvorgang läuft also
    // ein zweites Mal, und trotzdem gilt der Zustand nicht als geändert, weil
    // Riverpod mit `!=` vergleicht. Ohne den zweiten Teil wäre der fehlende
    // Kurzschluss ein unnötiger Rebuild bei jedem Tippen.
    final store = _CountingAudioModeStore();
    final container = containerWith(store);
    final notifier = container.read(audioModeProvider.notifier);

    var updates = 0;
    container.listen(audioModeProvider, (_, _) => updates++);

    await notifier.enable();
    await notifier.enable();

    expect(updates, 1);
    expect(store.writes, 2);
    expect(store.isEnabled(), isTrue);
  });

  test(
    'der Vertrag kann auch ausschalten, auch wenn heute niemand das ruft',
    () async {
      // `setEnabled` ist kein Einbahn-Schalter, siehe `AudioModeStore`. Der
      // Ausschalter im Profil kommt später und findet den Vertrag vor.
      final store = InMemoryAudioModeStore(enabled: true);

      await store.setEnabled(false);

      expect(store.isEnabled(), isFalse);
    },
  );
}

/// Zählt die Schreibvorgänge, sonst wie [InMemoryAudioModeStore].
class _CountingAudioModeStore implements AudioModeStore {
  bool _enabled = false;
  int writes = 0;

  @override
  bool isEnabled() => _enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    writes++;
    _enabled = enabled;
  }
}
