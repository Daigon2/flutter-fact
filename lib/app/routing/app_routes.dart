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
/// ## Warum Splash, Anmeldung und Registrierung eigene Routen sind
///
/// Sie stehen **außerhalb** der [AppShellRoute]. Wären sie ein Zweig der Shell,
/// erschiene die Tab-Leiste darüber, und ein Tabwechsel wäre aus dem
/// Startbildschirm heraus möglich. Die PWA kennt in diesem Zustand keine Leiste
/// (`app.jsx:1040-1060` rendert sie erst für die vier Tab-Bildschirme).
///
/// Wer zwischen ihnen und der Karte umleitet, ist nicht die Seite, sondern die
/// Weiche in `route_guards.dart`.
///
/// `/` bleibt frei.
library;

import 'dart:async';

import 'package:fact_app/app/shell/app_shell.dart';
import 'package:fact_app/features/challenges/presentation/pages/challenges_page.dart';
import 'package:fact_app/features/collection/presentation/pages/collection_page.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/identity/presentation/pages/login_page.dart';
import 'package:fact_app/features/identity/presentation/pages/signup_page.dart';
import 'package:fact_app/features/identity/presentation/pages/splash_page.dart';
import 'package:fact_app/features/profile/presentation/pages/profile_page.dart';
import 'package:fact_app/features/settings/presentation/widgets/audio_activation_dialog.dart';
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

/// Der Startbildschirm, `/splash`.
///
/// Kein Ladebildschirm: der zeitgesteuerte Boot-Splash der PWA
/// (`index.html:222-245`) ist seit Commit `83be52f` toter Code. Diese Route
/// zeigt `SplashScreen` aus `screen-auth.jsx:265-422` und wartet auf einen Tipp.
///
/// ## Hier hängen zwei Features zusammen, und nur hier dürfen sie das
///
/// Der Startbildschirm gehört `identity`, die Audio-Präferenz gehört
/// `settings` (`lib/features/README.md:22`). Regel 8 der `dependency-rules.md`
/// verbietet `identity/presentation` jeden Import aus `settings/presentation`.
/// Regel 10 erlaubt stattdessen "an app-level composition adapter", und die
/// Tabelle in derselben Datei gibt der App-Komposition Zugriff auf "all public
/// feature entry points". Das ist diese Zeile: der Bildschirm nennt nur, dass
/// sein Kopfhörer-Knopf getippt wurde, und `settings` liefert die
/// Öffnen-Funktion.
///
/// Der Dialog ist eine Route (`showAudioActivationDialog`), keine Ebene im
/// `Stack` des Bildschirms. `architecture-overview.md:250`:
/// "Modals and full-screen pages are routing decisions".
@TypedGoRoute<SplashRoute>(path: '/splash')
class SplashRoute extends GoRouteData with $SplashRoute {
  /// Erzeugt die Route.
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => SplashPage(
    // `context` ist der Build-Kontext dieser Route, liegt also unter dem
    // Navigator von go_router. Genau den braucht `showDialog`.
    //
    // `unawaited` und nicht `reportDetached` aus `core/async`: dieses `Future`
    // wird erfüllt, wenn der Dialog schließt. Es trägt keinen
    // Schreibvorgang, dessen Scheitern zu melden wäre.
    onAudioGuidePressed: () => unawaited(showAudioActivationDialog(context)),
  );
}

/// Die Anmeldung, `/login`.
@TypedGoRoute<LoginRoute>(path: '/login')
class LoginRoute extends GoRouteData with $LoginRoute {
  /// Erzeugt die Route.
  const LoginRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginPage();
}

/// Die Registrierung, `/signup`.
@TypedGoRoute<SignupRoute>(path: '/signup')
class SignupRoute extends GoRouteData with $SignupRoute {
  /// Erzeugt die Route.
  const SignupRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SignupPage();
}
