import 'package:fact_app/app/routing/app_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Zentrale Routing-Komposition (ADR-004). Der Routenbaum selbst steht in
/// `app_routes.dart` und wird von `go_router_builder` zu `$appRoutes`
/// übersetzt.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    // Die PWA startet auf der Karte: `app.jsx:68-70` setzt `'map'`, sofern
    // nicht Onboarding fällig ist. Die Onboarding-Weiche kommt mit Identity,
    // siehe [_redirect].
    initialLocation: const MapRoute().location,
    routes: $appRoutes,
    redirect: _redirect,
  );
  // Ohne das hält jeder Provider-Container in Tests einen Router samt
  // Delegate und Listenern fest.
  ref.onDispose(router.dispose);
  return router;
});

/// Zentrale Weiche für Auth und Onboarding (ADR-004: "Auth/onboarding
/// redirects are centralized").
///
/// Noch ohne Entscheidung, weil es keinen Sitzungszustand gibt: `features/
/// identity` kommt in Phase 1. Die Stelle steht trotzdem schon hier, damit die
/// Weiche später nicht in einer Seite landet.
///
/// Was hier hingehört, sobald Identity steht:
///
/// - unangemeldet und Ziel geschützt: auf die Anmeldung umleiten und das
///   ursprüngliche Ziel mitgeben (`screen-auth.jsx` ist die Verhaltensquelle);
/// - angemeldet, aber Onboarding offen: auf das Onboarding umleiten
///   (`app.jsx:69` entscheidet das in der PWA über `fact_has_launched`);
/// - sonst `null`.
///
/// Dazu gehört ein `refreshListenable` am [GoRouter], das auf den
/// Sitzungszustand hört. Ohne das wertet go_router den Redirect erst bei der
/// nächsten Navigation neu aus, und ein Abmelden im Hintergrund bliebe
/// unbemerkt.
///
/// Wichtig für die Umsetzung: die Autorisierung liegt beim Server. Diese
/// Weiche ist Bequemlichkeit für den Nutzer, keine Sicherheitsgrenze.
String? _redirect(BuildContext context, GoRouterState state) => null;
