import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Erstlauf-Merkung als Zustand.
void main() {
  ProviderContainer containerWith(FirstLaunchStore store) {
    final container = ProviderContainer(
      overrides: [firstLaunchStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('der Anfangszustand kommt aus dem Speicher', () {
    expect(
      containerWith(InMemoryFirstLaunchStore()).read(firstLaunchProvider),
      isFalse,
    );
    expect(
      containerWith(
        InMemoryFirstLaunchStore(hasLaunched: true),
      ).read(firstLaunchProvider),
      isTrue,
    );
  });

  test('markLaunched setzt den Zustand und schreibt danach', () async {
    final store = InMemoryFirstLaunchStore();
    final container = containerWith(store);

    await container.read(firstLaunchProvider.notifier).markLaunched();

    expect(container.read(firstLaunchProvider), isTrue);
    expect(store.hasLaunched(), isTrue);
  });

  test('ein zweiter Aufruf ändert nichts', () async {
    final store = InMemoryFirstLaunchStore();
    final container = containerWith(store);
    final notifier = container.read(firstLaunchProvider.notifier);

    var updates = 0;
    container.listen(firstLaunchProvider, (_, _) => updates++);

    await notifier.markLaunched();
    await notifier.markLaunched();

    // Jede Zustandsänderung löst in `app_router.dart` ein `router.refresh()`
    // aus. Ein zweiter Aufruf darf deshalb nicht als Änderung durchgehen.
    expect(updates, 1);
    expect(store.hasLaunched(), isTrue);
  });
}
