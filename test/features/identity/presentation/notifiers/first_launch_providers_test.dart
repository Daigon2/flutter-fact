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

  test('ein zweiter Aufruf schreibt auch nicht noch einmal', () async {
    // Der Test darüber allein ist **zu schwach**, und das ist gemessen: nimmt
    // man die Abkürzung `if (state) return;` heraus, bleibt er grün. Riverpod
    // meldet ein `state = true` auf einen Zustand, der schon `true` ist, gar
    // nicht erst als Änderung, der Zähler steht also so oder so auf 1.
    //
    // Beobachtbar wird der Unterschied erst am Speicher: ohne die Abkürzung
    // läuft der Schreibvorgang ein zweites Mal.
    final store = _CountingFirstLaunchStore();
    final notifier = containerWith(store).read(firstLaunchProvider.notifier);

    await notifier.markLaunched();
    await notifier.markLaunched();
    await notifier.markLaunched();

    expect(store.writes, 1);
  });
}

/// Zählt die Schreibvorgänge, sonst wie [InMemoryFirstLaunchStore].
class _CountingFirstLaunchStore implements FirstLaunchStore {
  bool _hasLaunched = false;

  /// Wie oft [markLaunched] gerufen wurde.
  int writes = 0;

  @override
  bool hasLaunched() => _hasLaunched;

  @override
  Future<void> markLaunched() async {
    writes++;
    _hasLaunched = true;
  }
}
