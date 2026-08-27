import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der untätige Standard. Er ist das, was jeder Test und jeder Build ohne
/// `--dart-define` sieht, deshalb ist sein Verhalten Vertrag und nicht Zufall.
void main() {
  group('unavailableAuthRepository', () {
    test('niemand ist angemeldet', () {
      expect(
        unavailableAuthRepository.currentSession(),
        const AuthSession.signedOut(),
      );
    });

    test('jeder Anmeldeversuch liefert AuthBackendUnavailable', () {
      // Untätig heißt nicht stillschweigend: ein Anmeldeversuch endet sichtbar
      // in einem Fehlschlag, statt nichts zu tun.
      expect(
        () => unavailableAuthRepository.signInWithPassword(
          email: 'jan@example.de',
          password: 'geheim',
        ),
        throwsA(
          isA<AuthBackendUnavailable>().having(
            (failure) => failure.code,
            'code',
            'auth_repository_not_configured',
          ),
        ),
      );
    });

    test('jeder Registrierversuch liefert AuthBackendUnavailable', () {
      expect(
        () => unavailableAuthRepository.signUpWithPassword(
          email: 'jan@example.de',
          password: 'geheim',
          name: 'stadtfuchs_m',
          hometown: 'München',
        ),
        throwsA(
          isA<AuthBackendUnavailable>().having(
            (failure) => failure.code,
            'code',
            'auth_repository_not_configured',
          ),
        ),
      );
    });

    test(
      'die Username-Prüfung wirft, statt frei oder vergeben zu behaupten',
      () {
        // Beide Antworten wären eine Lüge, und "vergeben" die schlechtere: sie
        // zeigte am Feld "Bereits vergeben" für einen Namen, den niemand hat.
        expect(
          () => unavailableAuthRepository.checkUsernameTaken('stadtfuchs_m'),
          throwsA(isA<AuthBackendUnavailable>()),
        );
      },
    );

    test('das Setzen des Usernames wirft ebenfalls', () {
      expect(
        () => unavailableAuthRepository.setUsername(
          userId: 'user-1',
          username: 'stadtfuchs_m',
        ),
        throwsA(isA<AuthBackendUnavailable>()),
      );
    });

    test('kann keinen angemeldeten Nutzer erfinden', () async {
      // Die sicherheitsrelevante Richtung: der Strom liefert nichts, es gibt
      // also keinen Weg, über den dieser Standard jemanden anmeldet.
      expect(
        await unavailableAuthRepository.sessionChanges().toList(),
        isEmpty,
      );
    });
  });
}
