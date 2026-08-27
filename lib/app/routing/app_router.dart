import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/app/routing/route_guards.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Zentrale Routing-Komposition (ADR-004). Der Routenbaum selbst steht in
/// `app_routes.dart` und wird von `go_router_builder` zu `$appRoutes`
/// übersetzt, die Weichenregeln stehen in `route_guards.dart`.
///
/// ## Warum die beiden Zustände hier nicht gewatcht werden
///
/// Ein `ref.watch(firstLaunchProvider)` im Rumpf dieses Providers würde bei
/// jeder Zustandsänderung einen **neuen** `GoRouter` erzeugen. Das
/// `ref.onDispose` unten entsorgt den alten, und mit ihm die vier unabhängigen
/// Zweig-Navigatoren der `StatefulShellRoute`: der Nutzer verliert jeden
/// Routenstapel, den er in einem Tab aufgebaut hat.
///
/// Deshalb zwei getrennte Wege:
///
/// - die Redirect-Closure liest mit `ref.read`, also ohne Abhängigkeit;
/// - `ref.listen` stößt `router.refresh()` an, damit go_router die Weiche neu
///   auswertet, ohne den Router zu ersetzen.
///
/// Bewusst **kein** `refreshListenable`: dafür bräuchte es eine
/// `ChangeNotifier`-Brücke, und ADR-003 schließt `ChangeNotifier` für neuen
/// Code aus. Ein früherer Kommentar an dieser Stelle empfahl genau das und war
/// damit falsch.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    // Die PWA startet auf der Karte: `app.jsx:68-70` setzt `'map'`, sofern
    // nicht der Erstlauf offen ist. Diese Bedingung steht hier absichtlich
    // nicht im Startort, sondern in der Weiche: ein zweiter Ort, der über den
    // Erstlauf entscheidet, wäre ein zweiter Ort, der falsch sein kann. Deep
    // Links kommen ohnehin nicht über `initialLocation` herein.
    initialLocation: const MapRoute().location,
    routes: $appRoutes,
    redirect: (context, state) => resolveRedirect(
      hasLaunched: ref.read(firstLaunchProvider),
      isSignedIn: ref.read(authSessionProvider).isSignedIn,
      location: state.matchedLocation,
    ),
  );
  // Ohne das hält jeder Provider-Container in Tests einen Router samt
  // Delegate und Listenern fest.
  ref.onDispose(router.dispose);
  // Erst nach dem Erzeugen: `refresh()` braucht den Router.
  //
  // Zwei Listener, weil die Weiche zwei Zustände liest. Beide sind nötig: ohne
  // den zweiten bliebe ein Nutzer, der sich anmeldet, auf dem Startbildschirm
  // stehen, bis er von sich aus navigiert. Riverpod ruft einen Listener nur bei
  // einer **Änderung** nach `==` auf; dass eine Token-Erneuerung deshalb keine
  // Neuauswertung auslöst, hängt an `AuthSession ==` und ist dort begründet.
  ref.listen(firstLaunchProvider, (_, _) => router.refresh());
  ref.listen(authSessionProvider, (_, _) => router.refresh());
  return router;
});
