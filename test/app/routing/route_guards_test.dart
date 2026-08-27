import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/app/routing/route_guards.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die zentrale Weiche als reine Funktion, ohne Widget-Baum und ohne
/// Provider-Container. Genau dafür nimmt `resolveRedirect` weder `BuildContext`
/// noch `Ref`.
void main() {
  final splash = const SplashRoute().location;
  final login = const LoginRoute().location;
  final signup = const SignupRoute().location;
  final map = const MapRoute().location;

  /// Alle vier Kombinationen der beiden Zustände, damit keine unbemerkt fehlt.
  const combinations = <({bool hasLaunched, bool isSignedIn})>[
    (hasLaunched: false, isSignedIn: false),
    (hasLaunched: false, isSignedIn: true),
    (hasLaunched: true, isSignedIn: false),
    (hasLaunched: true, isSignedIn: true),
  ];

  group('Erstlauf offen und niemand angemeldet', () {
    test('leitet ein geschütztes Ziel auf den Startbildschirm', () {
      for (final target in <String>[
        map,
        const CollectionRoute().location,
        const ChallengesRoute().location,
        const ProfileRoute().location,
        '/gibtesnicht',
      ]) {
        expect(
          resolveRedirect(
            hasLaunched: false,
            isSignedIn: false,
            location: target,
          ),
          splash,
          reason: target,
        );
      }
    });

    test('lässt den Startbildschirm selbst durch', () {
      expect(
        resolveRedirect(
          hasLaunched: false,
          isSignedIn: false,
          location: splash,
        ),
        isNull,
      );
    });

    test('lässt Anmeldung und Registrierung durch', () {
      // Ohne diese Ausnahme führen zwei der drei Ausgänge des
      // Startbildschirms ins Leere: die Merkung steht beim Tippen noch nicht,
      // die Weiche schickte sofort zurück, und beide Knöpfe täten nichts.
      //
      // Es entsteht dabei **keine** Endlosschleife, entgegen einer früheren
      // Fassung dieses Kommentars. `/splash` ist ein Fixpunkt, go_router leitet
      // einmal um und ist fertig. Der Fehler wäre also still.
      expect(
        resolveRedirect(hasLaunched: false, isSignedIn: false, location: login),
        isNull,
      );
      expect(
        resolveRedirect(
          hasLaunched: false,
          isSignedIn: false,
          location: signup,
        ),
        isNull,
      );
    });
  });

  group('Erstlauf offen, aber angemeldet', () {
    test('kein Startbildschirm, das ist die zweite Hälfte von app.jsx:69', () {
      // `!localStorage.getItem('fact_has_launched') && !Storage.getUser()`. Wer
      // angemeldet ist, sieht das Onboarding nicht, auch ohne Merkung. Ohne
      // diese Regel bekäme ein angemeldeter Nutzer nach einer Neuinstallation
      // mit erhaltener Sitzung den Startbildschirm zu sehen.
      expect(
        resolveRedirect(hasLaunched: false, isSignedIn: true, location: map),
        isNull,
      );
      expect(
        resolveRedirect(hasLaunched: false, isSignedIn: true, location: splash),
        map,
      );
    });
  });

  group('Erstlauf erledigt', () {
    test('leitet den Startbildschirm auf die Karte, angemeldet oder nicht', () {
      for (final signedIn in <bool>[false, true]) {
        expect(
          resolveRedirect(
            hasLaunched: true,
            isSignedIn: signedIn,
            location: splash,
          ),
          map,
          reason: 'isSignedIn: $signedIn',
        );
      }
    });

    test('lässt alles andere durch', () {
      for (final signedIn in <bool>[false, true]) {
        for (final target in <String>[
          map,
          login,
          signup,
          const ProfileRoute().location,
          '/gibtesnicht',
        ]) {
          expect(
            resolveRedirect(
              hasLaunched: true,
              isSignedIn: signedIn,
              location: target,
            ),
            isNull,
            reason: '$signedIn $target',
          );
        }
      }
    });
  });

  test('alle sieben Pfade bleiben in jeder Kombination erreichbar', () {
    // Die Weiche ist Bequemlichkeit, **keine Sicherheitsgrenze**: es gibt einen
    // Gastmodus, und kein Zustand darf einen Pfad dauerhaft versperren. Geprüft
    // wird deshalb, dass jeder Pfad in mindestens einer Kombination ohne
    // Umleitung erreichbar ist.
    final reachable = <String>{};
    for (final combination in combinations) {
      for (final target in <String>[
        splash,
        login,
        signup,
        map,
        const CollectionRoute().location,
        const ChallengesRoute().location,
        const ProfileRoute().location,
      ]) {
        final redirect = resolveRedirect(
          hasLaunched: combination.hasLaunched,
          isSignedIn: combination.isSignedIn,
          location: target,
        );
        if (redirect == null) {
          reachable.add(target);
        }
      }
    }
    expect(reachable, hasLength(7));
  });

  test('jedes Umleitungsziel ist ein Fixpunkt', () {
    // Die stärkere Zusicherung, und die einzige, die künftige Regeln mit
    // abdeckt: wohin die Weiche auch schickt, dort schickt sie nicht weiter.
    // Damit ist eine Umleitungsschleife strukturell ausgeschlossen, egal welche
    // Regel jemand ergänzt. Die schwächere Form "das Ergebnis ist nie das
    // eigene Ziel" folgt daraus.
    for (final combination in combinations) {
      for (final target in <String>[
        splash,
        login,
        signup,
        map,
        const CollectionRoute().location,
        '/gibtesnicht',
      ]) {
        final first = resolveRedirect(
          hasLaunched: combination.hasLaunched,
          isSignedIn: combination.isSignedIn,
          location: target,
        );
        if (first == null) {
          continue;
        }
        expect(first, isNot(target), reason: '$combination $target');
        expect(
          resolveRedirect(
            hasLaunched: combination.hasLaunched,
            isSignedIn: combination.isSignedIn,
            location: first,
          ),
          isNull,
          reason: '$combination $target -> $first',
        );
      }
    }
  });
}
