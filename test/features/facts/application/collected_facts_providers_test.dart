import 'dart:async';

import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/domain/collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Riverpod-Verdrahtung der Sammlung.
void main() {
  ProviderContainer containerWith(CollectedFactsStore store) {
    final container = ProviderContainer(
      overrides: [collectedFactsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('collectedFactsProvider', () {
    test('startet mit dem, was im Speicher liegt', () {
      final container = containerWith(
        InMemoryCollectedFactsStore(const <FactId>[FactId(7), FactId(3)]),
      );

      expect(container.read(collectedFactsProvider), const <FactId>[
        FactId(7),
        FactId(3),
      ]);
    });

    test('der Standard ist flüchtig und leer', () {
      // Die Gegenprobe zum Override in `bootstrap()`. Ohne sie könnte der
      // Test darüber auch grün sein, wenn der Standard selbst persistierte.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(collectedFactsStoreProvider),
        isA<InMemoryCollectedFactsStore>(),
      );
      expect(container.read(collectedFactsProvider), isEmpty);
    });

    test('collect hängt an und schreibt in den Speicher', () async {
      final store = InMemoryCollectedFactsStore();
      final container = containerWith(store);

      await container
          .read(collectedFactsProvider.notifier)
          .collect(const FactId(7));

      expect(container.read(collectedFactsProvider), const <FactId>[FactId(7)]);
      expect(store.readCollectedFacts(), const <FactId>[FactId(7)]);
    });

    test('die Oberfläche folgt sofort, nicht erst nach dem Schreiben', () {
      // `state` wird vor dem `await` gesetzt. Ein fehlgeschlagenes Speichern
      // soll den gerade gefundenen Fakt nicht wieder wegnehmen, und ein
      // langsamer Gerätespeicher soll die Anzeige nicht aufhalten.
      final container = containerWith(SlowCollectedFactsStore());

      // Ohne `await`, und genau darum geht es: der Zustand muss schon stehen.
      // `unawaited` statt eines fehlenden `await`, damit der Lint sieht, dass
      // das Absicht ist und keine Vergesslichkeit.
      unawaited(
        container
            .read(collectedFactsProvider.notifier)
            .collect(const FactId(7)),
      );

      expect(container.read(collectedFactsProvider), const <FactId>[FactId(7)]);
    });

    test('gibt eine Liste heraus, die der Leser nicht ändern kann', () async {
      final container = containerWith(InMemoryCollectedFactsStore());

      await container
          .read(collectedFactsProvider.notifier)
          .collect(const FactId(7));

      expect(
        () => container.read(collectedFactsProvider).add(const FactId(9)),
        throwsUnsupportedError,
      );
    });

    group('ein zweiter Sammelvorgang auf denselben Fakt', () {
      test('ändert die Sammlung nicht', () async {
        final container = containerWith(InMemoryCollectedFactsStore());
        final notifier = container.read(collectedFactsProvider.notifier);

        await notifier.collect(const FactId(7));
        await notifier.collect(const FactId(7));

        expect(container.read(collectedFactsProvider), const <FactId>[
          FactId(7),
        ]);
      });

      test('weckt niemanden', () async {
        // Der Grund für den frühen Ausstieg im Notifier, und ohne ihn wäre
        // dieser Test rot: eine `List` hat keine Wertgleichheit, Riverpods
        // `defaultUpdateShouldNotify` vergleicht mit `!=`, und eine neue
        // Instanz mit demselben Inhalt weckt deshalb **alle** Leser. Auf der
        // Karte wäre das ein Neuaufbau, weil nichts passiert ist.
        final container = containerWith(InMemoryCollectedFactsStore());
        final notifier = container.read(collectedFactsProvider.notifier);
        await notifier.collect(const FactId(7));

        int builds = 0;
        container.listen<List<FactId>>(
          collectedFactsProvider,
          (_, _) => builds++,
        );

        await notifier.collect(const FactId(7));

        expect(builds, 0);
      });

      test('schreibt nicht noch einmal', () async {
        final store = CountingCollectedFactsStore();
        final container = containerWith(store);
        final notifier = container.read(collectedFactsProvider.notifier);

        await notifier.collect(const FactId(7));
        await notifier.collect(const FactId(7));

        expect(store.writes, 1);
      });
    });
  });

  group('isFactCollectedProvider', () {
    test('sagt für einen gesammelten Fakt wahr', () {
      final container = containerWith(
        InMemoryCollectedFactsStore(const <FactId>[FactId(7)]),
      );

      expect(container.read(isFactCollectedProvider(const FactId(7))), isTrue);
      expect(container.read(isFactCollectedProvider(const FactId(3))), isFalse);
    });

    test('folgt einem neuen Sammelvorgang', () async {
      final container = containerWith(InMemoryCollectedFactsStore());
      // Halten, sonst wird der Provider zwischen den Lesezugriffen entsorgt
      // und der Test prüfte zwei frische Instanzen statt einer Änderung.
      final subscription = container.listen<bool>(
        isFactCollectedProvider(const FactId(7)),
        (_, _) {},
      );

      expect(subscription.read(), isFalse);
      await container
          .read(collectedFactsProvider.notifier)
          .collect(const FactId(7));

      expect(subscription.read(), isTrue);
    });

    test('weckt den Leser eines anderen Fakts nicht', () async {
      // Der Grund, warum es diesen Provider überhaupt gibt. Ein Ballon, der
      // nur wissen will, ob **er** gesammelt ist, soll nicht bei jedem
      // fremden Sammelvorgang neu bauen. `false != false` weckt niemanden.
      final container = containerWith(InMemoryCollectedFactsStore());
      int builds = 0;
      container.listen<bool>(
        isFactCollectedProvider(const FactId(99)),
        (_, _) => builds++,
      );

      await container
          .read(collectedFactsProvider.notifier)
          .collect(const FactId(7));

      expect(builds, 0);
    });
  });
}

/// Ein Speicher, dessen Schreibvorgang nie fertig wird.
///
/// Damit ein Test sehen kann, dass der Zustand **vor** dem Schreiben steht.
class SlowCollectedFactsStore implements CollectedFactsStore {
  @override
  List<FactId> readCollectedFacts() => const <FactId>[];

  @override
  Future<void> collectFact(FactId factId) => Completer<void>().future;
}

/// Zählt Schreibvorgänge mit.
class CountingCollectedFactsStore implements CollectedFactsStore {
  final List<FactId> _collected = <FactId>[];

  /// Wie oft geschrieben wurde.
  int writes = 0;

  @override
  List<FactId> readCollectedFacts() => List<FactId>.unmodifiable(_collected);

  @override
  Future<void> collectFact(FactId factId) async {
    writes++;
    _collected.add(factId);
  }
}
