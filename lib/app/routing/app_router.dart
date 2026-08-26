import 'package:fact_app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Zentrale Routing-Komposition. Auth- und Onboarding-Redirects leben hier,
/// nicht in den Features (ADR-004). Features liefern später ihre Route-Zweige
/// als typisierte Routen zu.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoute.splash.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.routeName,
        builder: (context, state) =>
            const _ScaffoldPlaceholder(label: 'Splash'),
      ),
    ],
  );
});

/// Platzhalter, bis das erste Feature seine Seite liefert. Wird mit Schritt 7
/// (Splash) ersetzt.
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
