import 'package:fact_app/app/routing/app_router.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
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
  StatefulShellRoute shellRoute() => $appRoutes.single as StatefulShellRoute;

  String branchPath(StatefulShellBranch branch) =>
      (branch.routes.single as GoRoute).path;

  test('der Routenbaum besteht aus genau einer Shell', () {
    expect($appRoutes, hasLength(1));
    expect($appRoutes.single, isA<StatefulShellRoute>());
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
  });

  test('der Router startet auf der Karte, wie app.jsx:68-70', () {
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
}
