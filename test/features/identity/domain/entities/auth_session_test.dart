import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Wertobjekt der Sitzung. Ohne Flutter, ohne Riverpod: reine Domäne.
void main() {
  /// Baut eine **nicht konstante** Sitzung.
  ///
  /// Das ist der Kern dieser Tests, nicht Kosmetik: zwei identisch
  /// geschriebene `const`-Ausdrücke sind in Dart dasselbe Objekt
  /// (Kanonisierung). Ein Gleichheitstest über `const`-Literale ist deshalb
  /// wertlos, er wäre auch mit `operator ==(o) => identical(this, o)` grün.
  /// Nachgemessen mit genau dieser Mutation. Die echten Sitzungen entstehen zur
  /// Laufzeit aus einer Nutzerkennung, also nicht konstant.
  AuthSession sessionFor(String id) => AuthSession.signedIn(userId: id);

  /// Ebenfalls ohne `const`, aus demselben Grund.
  AuthSession signedOut() => AuthSession.signedOut();

  group('Anmeldezustand', () {
    test('abgemeldet hat keine Kennung', () {
      const session = AuthSession.signedOut();

      expect(session.isSignedIn, isFalse);
      expect(session.userId, isNull);
    });

    test('angemeldet trägt die Kennung', () {
      const session = AuthSession.signedIn(userId: 'abc-123');

      expect(session.isSignedIn, isTrue);
      expect(session.userId, 'abc-123');
    });
  });

  group('Wertgleichheit', () {
    test('gleiche Kennung ist gleich', () {
      // Das ist die Zusicherung gegen das Erneuerungs-Gewitter: Supabase
      // schickt bei `initialSession`, `tokenRefreshed` und `userUpdated`
      // dieselbe Kennung, und Riverpod benachrichtigt nur bei einer Änderung
      // nach `==`. Ohne dieses `==` wäre jede Token-Erneuerung ein
      // `router.refresh()`.
      final one = sessionFor('u1');
      final other = sessionFor('u1');

      expect(
        identical(one, other),
        isFalse,
        reason: 'sonst prüft der Test nichts',
      );
      expect(one, other);
      expect(one.hashCode, other.hashCode);
    });

    test('verschiedene Kennung ist verschieden', () {
      expect(sessionFor('u1'), isNot(sessionFor('u2')));
    });

    test('zwei abgemeldete Sitzungen sind gleich', () {
      final one = signedOut();
      final other = signedOut();

      expect(identical(one, other), isFalse);
      expect(one, other);
      expect(one.hashCode, other.hashCode);
    });

    test('abgemeldet ist nicht gleich angemeldet', () {
      expect(signedOut(), isNot(sessionFor('u1')));
    });
  });

  group('Ausgabe', () {
    test('trägt kein Token, weil der Typ keines hat', () {
      // Der Typ kann strukturell kein Token tragen. Dieser Test hält das fest,
      // damit ein späteres Feld nicht unbemerkt in den Zustand und von dort in
      // ein Log wandert (`cross-cutting-concerns.md`: keine Tokens im Log).
      const session = AuthSession.signedIn(userId: 'u1');

      expect(session.toString(), 'AuthSession(signedIn, u1)');
      expect(session.toString().toLowerCase(), isNot(contains('token')));
      expect(const AuthSession.signedOut().toString(), contains('signedOut'));
    });
  });
}
