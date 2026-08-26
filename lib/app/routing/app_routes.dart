/// Der Routenbaum als typisierte Routen (ADR-004).
///
/// Diese Datei ist die einzige Stelle im Projekt, an der ein Pfad als
/// Zeichenkette steht. `tool/check_architecture.dart` prüft das maschinell für
/// alles außerhalb von `lib/app/routing/`. Aufrufer navigieren über die
/// erzeugten Klassen, also `const ProfileRoute().go(context)`, nie über einen
/// Pfad.
///
/// ## Warum die vier Zweige so heißen
///
/// Die Tabs stammen aus `02_Frontend/app/chrome.jsx:55-60`. Die PWA kennt
/// keine URLs, sie schaltet mit `setRoute(...)` (`app.jsx:476-490`) zwischen
/// Bildschirmen um. Die Pfade hier sind also neu und folgen den Domänennamen
/// aus `docs/architecture/domain-map.md`, nicht den internen PWA-Bezeichnern:
///
/// | Tab (chrome.jsx) | PWA-Bildschirm | Pfad hier | Besitzende Domäne |
/// |---|---|---|---|
/// | `modus` | `map` | `/map` | Discovery |
/// | `wallet` | `wallet` | `/collection` | Collection |
/// | `challenge` | `challenge` | `/challenges` | Challenges |
/// | `profil` | `profil` | `/profile` | Profile |
///
/// ## Reihenfolge
///
/// Die Reihenfolge der Zweige **muss** der Reihenfolge von `ShellTab` folgen.
/// `AppShell` bildet `StatefulNavigationShell.currentIndex` direkt auf
/// `ShellTab.values` ab und prüft die Länge per `assert`. Wer hier einen Zweig
/// einschiebt, muss `ShellTab` mitziehen.
///
/// `/` bleibt frei. Dort kommt in Schritt 7 der Splash hin.
library;

import 'package:fact_app/app/shell/app_shell.dart';
import 'package:fact_app/features/challenges/presentation/pages/challenges_page.dart';
import 'package:fact_app/features/collection/presentation/pages/collection_page.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

part 'app_routes.g.dart';

/// Der Rahmen um die vier Tabs.
///
/// `StatefulShellRoute` gibt jedem Zweig einen eigenen `Navigator`
/// (`architecture-overview.md` §11: "Bottom-navigation branches use
/// independent navigation stacks"). Ein Tabwechsel legt den Stapel des vorigen
/// Tabs nicht ab, sondern stellt ihn beim Zurückwechseln wieder her.
@TypedStatefulShellRoute<AppShellRoute>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<MapBranch>(
      routes: <TypedRoute<RouteData>>[TypedGoRoute<MapRoute>(path: '/map')],
    ),
    TypedStatefulShellBranch<CollectionBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<CollectionRoute>(path: '/collection'),
      ],
    ),
    TypedStatefulShellBranch<ChallengesBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ChallengesRoute>(path: '/challenges'),
      ],
    ),
    TypedStatefulShellBranch<ProfileBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ProfileRoute>(path: '/profile'),
      ],
    ),
  ],
)
class AppShellRoute extends StatefulShellRouteData {
  /// Erzeugt den Shell-Zweig des Routenbaums.
  const AppShellRoute();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return AppShell(navigationShell: navigationShell);
  }
}

/// Zweig "Karte", Wurzel `/map`.
class MapBranch extends StatefulShellBranchData {
  /// Erzeugt den Zweig.
  const MapBranch();
}

/// Zweig "Fakten", Wurzel `/collection`.
class CollectionBranch extends StatefulShellBranchData {
  /// Erzeugt den Zweig.
  const CollectionBranch();
}

/// Zweig "Challenge", Wurzel `/challenges`.
class ChallengesBranch extends StatefulShellBranchData {
  /// Erzeugt den Zweig.
  const ChallengesBranch();
}

/// Zweig "Profil", Wurzel `/profile`.
class ProfileBranch extends StatefulShellBranchData {
  /// Erzeugt den Zweig.
  const ProfileBranch();
}

/// Wurzelseite des Karten-Tabs.
class MapRoute extends GoRouteData with $MapRoute {
  /// Erzeugt die Route.
  const MapRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MapPage();
}

/// Wurzelseite des Fakten-Tabs.
class CollectionRoute extends GoRouteData with $CollectionRoute {
  /// Erzeugt die Route.
  const CollectionRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const CollectionPage();
}

/// Wurzelseite des Challenge-Tabs.
class ChallengesRoute extends GoRouteData with $ChallengesRoute {
  /// Erzeugt die Route.
  const ChallengesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ChallengesPage();
}

/// Wurzelseite des Profil-Tabs.
class ProfileRoute extends GoRouteData with $ProfileRoute {
  /// Erzeugt die Route.
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfilePage();
}
