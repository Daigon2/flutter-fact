import 'package:fact_app/app/routing/app_router.dart';
import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../features/identity/fake_auth_repository.dart';

/// Die Verdrahtung der Weiche im Router.
void main() {
  test('eine Zustandsänderung ersetzt den Router nicht', () async {
    // Das ist die eigentliche Falle an dieser Stelle. Ein
    // `ref.watch(firstLaunchProvider)` im Rumpf von `appRouterProvider` würde
    // hier einen zweiten Router liefern. Das `ref.onDispose` entsorgt dann den
    // ersten, und mit ihm die vier unabhängigen Zweig-Navigatoren der
    // `StatefulShellRoute`: der Nutzer verliert jeden Routenstapel, den er in
    // einem Tab aufgebaut hat. Der Fehler wäre im Betrieb schwer zu finden,
    // weil die Navigation danach weiter funktioniert.
    final container = ProviderContainer(
      overrides: [
        firstLaunchStoreProvider.overrideWithValue(InMemoryFirstLaunchStore()),
      ],
    );
    addTearDown(container.dispose);

    final before = container.read(appRouterProvider);
    await container.read(firstLaunchProvider.notifier).markLaunched();
    final after = container.read(appRouterProvider);

    expect(after, same(before));
    expect(container.read(firstLaunchProvider), isTrue);
  });

  test('der Router hört auf die Erstlauf-Merkung', () {
    // `ref.listen` muss die Abhängigkeit aufbauen, sonst wertet go_router die
    // Weiche erst bei der nächsten Navigation neu aus. Sichtbar ist das daran,
    // dass der Provider nach dem Lesen des Routers bereits läuft.
    final container = ProviderContainer(
      overrides: [
        firstLaunchStoreProvider.overrideWithValue(InMemoryFirstLaunchStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.exists(firstLaunchProvider), isFalse);
    container.read(appRouterProvider);
    expect(container.exists(firstLaunchProvider), isTrue);
  });

  test('der Router wird beim Entsorgen des Containers mit entsorgt', () {
    // Ohne `ref.onDispose` hält jeder Test-Container einen Router samt Delegate
    // und Listenern fest.
    final container = ProviderContainer(
      overrides: [
        firstLaunchStoreProvider.overrideWithValue(InMemoryFirstLaunchStore()),
      ],
    );
    final router = container.read(appRouterProvider);
    container.dispose();

    expect(() => router.routerDelegate.addListener(() {}), throwsFlutterError);
  });

  group('Der Router hört auch auf die Sitzung', () {
    late FakeAuthRepository auth;

    setUp(() => auth = FakeAuthRepository());

    /// Baut eine **nicht konstante** Sitzung.
    ///
    /// Zwei gleich geschriebene `const`-Ausdrücke sind in Dart dasselbe Objekt.
    /// Mit `const` wäre der Test unten auch grün, wenn `AuthSession ==` nur
    /// `identical` prüfte, und die echten Sitzungen entstehen zur Laufzeit aus
    /// einer Kennung. Nachgemessen: mit `const` überlebte genau diese Mutation.
    AuthSession sessionFor(String id) => AuthSession.signedIn(userId: id);
    tearDown(() async => auth.close());

    /// Zählt, wie oft der Router seine Weiche neu auswerten soll.
    ///
    /// `GoRouter.refresh()` ruft `routeInformationProvider.notifyListeners()`
    /// (`go_router 18.0.0`, `router.dart:569-575`). Ein Zuhörer dort zählt also
    /// genau die Aufrufe, und nur die: ohne diesen Weg wäre "es wurde nicht
    /// aktualisiert" nicht von "es hat sich nichts geändert" zu unterscheiden.
    Future<int Function()> refreshCounter(GoRouter router) async {
      // Erst alles abklingen lassen, was der Aufbau selbst auslöst.
      await pumpEventQueue();
      var count = 0;
      void listener() => count++;
      router.routeInformationProvider.addListener(listener);
      addTearDown(
        () => router.routeInformationProvider.removeListener(listener),
      );
      return () => count;
    }

    ProviderContainer containerWithAuth() {
      final container = ProviderContainer(
        overrides: [
          firstLaunchStoreProvider.overrideWithValue(
            InMemoryFirstLaunchStore(),
          ),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('eine Anmeldung stößt eine Neuauswertung an', () async {
      // Ohne das zweite `ref.listen` in `appRouterProvider` bliebe ein Nutzer,
      // der sich anmeldet, auf dem Startbildschirm stehen, bis er von sich aus
      // navigiert.
      final container = containerWithAuth();
      final router = container.read(appRouterProvider);
      final refreshes = await refreshCounter(router);

      auth.emit(sessionFor('u1'));
      await pumpEventQueue();

      expect(refreshes(), 1);
    });

    test('dieselbe Kennung stößt keine an', () async {
      // Die Zusicherung gegen das Erneuerungs-Gewitter: `onAuthStateChange`
      // feuert bei `initialSession`, `tokenRefreshed` und `userUpdated` mit
      // derselben Kennung. Ohne `AuthSession ==` wäre jede Token-Erneuerung
      // eine Neuauswertung der Weiche, dauerhaft und ohne Anlass.
      final container = containerWithAuth();
      final router = container.read(appRouterProvider);
      final refreshes = await refreshCounter(router);

      auth.emit(sessionFor('u1'));
      await pumpEventQueue();
      expect(refreshes(), 1);

      auth.emit(sessionFor('u1'));
      auth.emit(sessionFor('u1'));
      await pumpEventQueue();

      expect(refreshes(), 1);

      // Gegenprobe: eine echte Änderung kommt weiterhin durch.
      auth.emit(sessionFor('u2'));
      await pumpEventQueue();
      expect(refreshes(), 2);
    });

    test('eine Zustandsänderung ersetzt den Router nicht', () async {
      final container = containerWithAuth();
      final before = container.read(appRouterProvider);

      auth.emit(sessionFor('u1'));
      await pumpEventQueue();

      expect(container.read(appRouterProvider), same(before));
    });

    test(
      'eine Ausgabe während des Entsorgens erreicht den Router nicht',
      () async {
        // Der Sitzungsstrom kommt von außen, `ref.onDispose(router.dispose)` ist
        // innen. Trifft eine zugestellte Ausgabe auf einen entsorgten Router,
        // wirft `refresh()` mit "was used after being disposed", und zwar
        // abgekoppelt in einer Stream-Rückrufkette: dieser Test wird dadurch rot.
        final container = containerWithAuth();
        final router = container.read(appRouterProvider);

        auth.emit(sessionFor('u1'));
        container.dispose();
        await pumpEventQueue();

        expect(
          () => router.routerDelegate.addListener(() {}),
          throwsFlutterError,
        );
        expect(auth.hasSessionListeners, isFalse);
      },
    );
  });
}
