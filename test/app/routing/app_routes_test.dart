import 'dart:async';
import 'dart:io';

import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/routing/app_router.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_pill.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/presentation/map_surface.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Der erzeugte Routenbaum und der Vertrag zwischen ihm und [ShellTab].
///
/// `AppShell` bildet `StatefulNavigationShell.currentIndex` direkt auf
/// `ShellTab.values` ab. Diese Zuordnung ist nur richtig, solange die Zweige in
/// derselben Reihenfolge stehen. Ein `assert` in `AppShell` fängt eine falsche
/// Anzahl, aber keine vertauschte Reihenfolge; dafür sind die Tests hier da.
void main() {
  StatefulShellRoute shellRoute() =>
      $appRoutes.whereType<StatefulShellRoute>().single;

  String branchPath(StatefulShellBranch branch) =>
      (branch.routes.single as GoRoute).path;

  test('der Routenbaum besteht aus einer Shell und drei Seiten daneben', () {
    expect($appRoutes, hasLength(4));
    expect($appRoutes.whereType<StatefulShellRoute>(), hasLength(1));
  });

  test('Splash, Anmeldung und Registrierung liegen außerhalb der Shell', () {
    // Innerhalb der Shell hätten sie die Tab-Leiste über sich, und ein
    // Tabwechsel wäre vom Startbildschirm aus möglich. Die PWA kennt in diesem
    // Zustand keine Leiste.
    final topLevelPaths = $appRoutes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toList();

    expect(topLevelPaths, <String>['/splash', '/login', '/signup']);

    final branchPaths = shellRoute().branches.expand(
      (branch) => branch.routes.whereType<GoRoute>().map((r) => r.path),
    );
    for (final path in <String>['/splash', '/login', '/signup']) {
      expect(branchPaths, isNot(contains(path)), reason: path);
    }
  });

  test('es gibt einen Zweig je Tab, in der Reihenfolge von ShellTab', () {
    expect(shellRoute().branches, hasLength(ShellTab.values.length));
    expect(shellRoute().branches.map(branchPath).toList(), <String>[
      '/map',
      '/collection',
      '/challenges',
      '/profile',
    ]);
  });

  test('jeder Zweig hat einen eigenen Navigator', () {
    final keys = shellRoute().branches
        .map((branch) => branch.navigatorKey)
        .toSet();

    expect(keys, hasLength(ShellTab.values.length));
  });

  test('die typisierten Routen liefern die Pfade der Zweige', () {
    expect(const MapRoute().location, '/map');
    expect(const CollectionRoute().location, '/collection');
    expect(const ChallengesRoute().location, '/challenges');
    expect(const ProfileRoute().location, '/profile');
    expect(const SplashRoute().location, '/splash');
    expect(const LoginRoute().location, '/login');
    expect(const SignupRoute().location, '/signup');
  });

  testWidgets('die Karten-Route baut den Bildschirm samt Kartenfläche', (
    tester,
  ) async {
    // **Diese eine Zeile trägt Schritt 12, und sie war vollständig
    // ungetestet.** `mapSurface:` durch ein `SizedBox.shrink()` zu ersetzen
    // ließ alle 1084 Tests grün: „die App zeigt gar keine Karte" war nirgends
    // zugesichert. `MapRoute` kam bisher nur mit `.location` vor.
    //
    // Gebaut wird hier wirklich `MapRoute.build`, eingehängt als Bauer einer
    // eigenen Route. Ein `GoRouterState` von Hand ist nicht herstellbar, seine
    // Konfiguration ist ein privates Pflichtargument
    // (`go_router-18.0.0/lib/src/state.dart:19-33`); über einen echten Router
    // liefert go_router ihn selbst.
    rootBundle.clear();
    final container = ProviderContainer(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(),
        ),
        // **Ohne diesen Override endet der Test in „A Timer is still
        // pending".** Der Kartenbildschirm lädt seit Schritt 15 die Fakten,
        // der Standard `unavailableFactRepository` wirft, und Riverpod 3
        // wiederholt einen gescheiterten Provider von sich aus bis zu zehnmal
        // mit wachsender Pause (`provider_container.dart:982-996`). Der erste
        // dieser Timer überlebt den Widget-Baum. Hier geht es um die Route und
        // nicht um die Fakten, also liefert der Override eine leere
        // Überlagerung.
        factOverlayProvider.overrideWith(
          (ref) async => const MapOverlay(id: factOverlayId, points: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: const MapRoute().location,
      routes: <RouteBase>[
        GoRoute(path: '/map', builder: const MapRoute().build),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: FactTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MapPage), findsOneWidget);
    final MapSurface surface = tester.widget<MapSurface>(
      find.byType(MapSurface),
    );
    // Und sie startet an der Rückfallposition der Quelle, nicht an einer, die
    // sich der Karten-Host selbst ausdenkt: Mehrstädtigkeit hängt daran.
    expect(surface.initialCamera, MapPage.placeholderCamera);
  });

  testWidgets(
    'die Karten-Route versorgt die Jagd-Pille mit der Nutzerposition',
    (tester) async {
      // Schritt 37: derselbe Kompositions-Grund wie bei `mapSurface`, nur für
      // Regel 8 (`challenges/presentation` ist für `discovery` unerreichbar)
      // statt Regel 18.
      rootBundle.clear();
      final location = _FakeLocationService();
      addTearDown(location.close);
      final container = ProviderContainer(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(),
          ),
          factOverlayProvider.overrideWith(
            (ref) async => const MapOverlay(id: factOverlayId, points: []),
          ),
          locationServiceProvider.overrideWithValue(location),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: const MapRoute().location,
        routes: <RouteBase>[
          GoRoute(path: '/map', builder: const MapRoute().build),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: FactTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      HuntPill pillNow() => tester.widget<HuntPill>(find.byType(HuntPill));

      expect(
        pillNow().userPosition,
        isNull,
        reason: 'ohne Ortung gibt es keine Nutzerposition',
      );

      location.emit(
        const DevicePosition(
          latitude: 48.2,
          longitude: 11.7,
          accuracyInMeters: 8,
        ),
      );
      // Zweimal gepumpt, wie bei jeder Ortung in diesem Projekt: der erste
      // Umlauf stellt die Stromausgabe zu, der zweite baut die Oberfläche neu.
      await tester.pump();
      await tester.pump();

      expect(
        pillNow().userPosition,
        const MapPosition(latitude: 48.2, longitude: 11.7),
      );
    },
  );

  test('der Router startet auf der Karte, wie app.jsx:68-70', () {
    // Der Startort bleibt die Karte, auch wenn der Erstlauf offen ist: darüber
    // entscheidet die Weiche beim Auswerten der Route, nicht diese Zeile.
    // Siehe `route_guards.dart` und `app_router.dart`.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);

    // `routerDelegate.currentConfiguration` ist erst gefüllt, wenn der Router
    // an einem Widget hängt. Der Startort steht vorher schon im
    // `routeInformationProvider`.
    expect(
      router.routeInformationProvider.value.uri.path,
      const MapRoute().location,
    );
  });

  group('Die Fakt-Akte', () {
    test('liegt als Unterroute unter /map und nicht neben der Shell', () {
      // Unter `/map`, damit `context.pop()` auf der Karte landet und die
      // Tab-Leiste stehen bleibt (`screen-fact.jsx:686`).
      final GoRoute map = shellRoute().branches.first.routes.single as GoRoute;

      expect(map.path, '/map');
      expect(map.routes, hasLength(1));
      expect((map.routes.single as GoRoute).path, 'fact/:factId');

      final Iterable<String> topLevelPaths = $appRoutes
          .whereType<GoRoute>()
          .map((GoRoute route) => route.path);
      expect(topLevelPaths, isNot(contains('/map/fact/:factId')));
    });

    test('die typisierte Route baut den Pfad mit der Kennung', () {
      expect(const FactRoute(factId: 42).location, '/map/fact/42');
    });

    test('genau ein Bildschirm im Bestand navigiert dorthin, und es ist der '
        'Sammelweg', () {
      // **Produktregel, `screen-map.jsx:2137-2142`:** die Akte darf niemals
      // ohne räumliche Nähe erreichbar sein. Bis Schritt 20 gab es deshalb
      // **keinen** Einstieg, und dieser Test sicherte genau das zu, mit dem
      // Vermerk „fällt dieser Test, hat jemand einen gelegt, und die Frage ist
      // dann, ob er die Bedingung mitgebracht hat".
      //
      // **Er ist gefallen, und die Antwort auf die Frage ist ja.** Schritt 20
      // hat den Sammelweg gebaut: `_onOpenFact` navigiert 1400 Millisekunden
      // nach einem Tipp hierher, der `decideFactTap` passiert hat, also nur
      // mit Ortung und nur innerhalb des Sammelradius.
      //
      // Der Test bewacht ab jetzt die Zahl statt der Null. **Ein zweiter
      // Einstieg lässt ihn wieder fallen**, und dann gilt dieselbe Frage
      // erneut. Dass er auf `map_page.dart` festgenagelt ist und nicht nur
      // auf „irgendeine Datei", ist die Hälfte, die trägt: eine Prüfung auf
      // „höchstens einer" wäre auch grün, wenn der eine woanders läge und der
      // Sammelweg seinen verloren hätte.
      final Iterable<File> dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'));
      final List<String> callers = <String>[];
      for (final File file in dartFiles) {
        final String source = file.readAsStringSync();
        if (source.contains('FactRoute(') &&
            !file.path.endsWith('app_routes.dart') &&
            !file.path.endsWith('app_routes.g.dart')) {
          // `uri.path` statt `path`: unter Windows trennt `path` mit
          // Backslashes, und der Vergleich unten soll auf beiden Systemen
          // dieselbe Zeichenkette treffen.
          callers.add(file.uri.path);
        }
      }

      expect(callers, <String>[
        'lib/features/discovery/presentation/pages/map_page.dart',
      ]);
    });
  });
}

/// Ein Ortungsdienst, der genau die Ortungen liefert, die [emit] übergibt.
///
/// Dasselbe kleine Muster wie `FakeLocationService` in `map_page_test.dart`
/// und `user_location_providers_test.dart`, hier noch einmal lokal, weil
/// keine der beiden Dateien eine testfremde Klasse exportiert.
class _FakeLocationService implements LocationService {
  final StreamController<DevicePosition> _controller =
      StreamController<DevicePosition>.broadcast();

  void emit(DevicePosition position) => _controller.add(position);

  Future<void> close() => _controller.close();

  @override
  Stream<DevicePosition> positionUpdates() => _controller.stream;
}
