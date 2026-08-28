import 'package:fact_app/app/onboarding/onboarding_providers.dart';
import 'package:fact_app/app/onboarding/tour_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Speicher und Notifier der Tutorial-Merkung, `fact_tour_shown`.
void main() {
  group('Der flüchtige Speicher', () {
    test('startet auf "noch nie gezeigt"', () {
      // Die Richtung ist wichtig: der sichere Standard ist "zeigen", nicht
      // "unterdrücken". Ein Speicher, der im Zweifel `true` liefert, würde das
      // Tutorial stumm verschlucken, und niemand würde es je vermissen.
      expect(InMemoryTourStore().hasSeenTour(), isFalse);
    });

    test('merkt sich das Zeigen', () async {
      final store = InMemoryTourStore();
      await store.markTourSeen();

      expect(store.hasSeenTour(), isTrue);
    });

    test('ein zweiter Aufruf ändert nichts', () async {
      final store = InMemoryTourStore(hasSeenTour: true);
      await store.markTourSeen();

      expect(store.hasSeenTour(), isTrue);
    });
  });

  group('Der Notifier', () {
    test('übernimmt den Startwert aus dem Speicher', () {
      final container = ProviderContainer(
        overrides: [
          tourStoreProvider.overrideWithValue(
            InMemoryTourStore(hasSeenTour: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(tourShownProvider), isTrue);
    });

    test('ohne Überschreibung ist das Tutorial offen', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(tourShownProvider), isFalse);
    });

    test('markSeen setzt den Zustand und schreibt', () async {
      final store = _CountingTourStore();
      final container = ProviderContainer(
        overrides: [tourStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(tourShownProvider), isFalse);
      await container.read(tourShownProvider.notifier).markSeen();

      expect(container.read(tourShownProvider), isTrue);
      expect(store.writes, 1);
    });

    test('markSeen ist idempotent und schreibt kein zweites Mal', () async {
      // Ohne die Abkürzung im Notifier löste jeder Aufruf einen
      // Provider-Zyklus aus. Zählbar ist das nur an den Schreibvorgängen.
      final store = _CountingTourStore();
      final container = ProviderContainer(
        overrides: [tourStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tourShownProvider.notifier);
      await notifier.markSeen();
      await notifier.markSeen();

      expect(store.writes, 1);
    });

    test(
      'die Oberfläche folgt sofort, auch wenn das Schreiben scheitert',
      () async {
        // Bewusst so herum: ein fehlgeschlagenes Speichern soll das Overlay
        // nicht wieder aufklappen lassen, während der Nutzer schon die Karte
        // bedient. Gemeldet wird der Fehler trotzdem, dafür sorgt der Aufrufer
        // mit `reportDetached`.
        final container = ProviderContainer(
          overrides: [tourStoreProvider.overrideWithValue(_FailingTourStore())],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(tourShownProvider.notifier).markSeen(),
          throwsStateError,
        );
        expect(container.read(tourShownProvider), isTrue);
      },
    );
  });
}

/// Zählt die Schreibvorgänge. Ein Fake mit Zustand, kein Mock
/// (`docs/engineering/testing.md` §5).
class _CountingTourStore implements TourStore {
  bool _seen = false;
  int writes = 0;

  @override
  bool hasSeenTour() => _seen;

  @override
  Future<void> markTourSeen() async {
    writes++;
    _seen = true;
  }
}

class _FailingTourStore implements TourStore {
  @override
  bool hasSeenTour() => false;

  @override
  Future<void> markTourSeen() async => throw StateError('Platte voll');
}
