import 'package:fact_app/features/identity/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Die Übersetzung an der Vendor-Grenze. Das ist die einzige Stelle im Projekt,
/// an der eine `AuthException` in eine `AuthFailure` wird, also die einzige, an
/// der die Zuordnung falsch sein kann.
///
/// Geprüft werden die beiden statischen Abbildungen und nicht die Aufrufe am
/// `GoTrueClient`: der Client ist eine konkrete Klasse mit HTTP dahinter, ein
/// Fake dafür wäre eine Nachbildung des Vendors und würde nichts über unseren
/// Code aussagen.
void main() {
  final stack = StackTrace.current;

  AuthFailure translate(Object error) =>
      SupabaseAuthRemoteDataSource.translateError(error, stack);

  group('Maschinenlesbarer Code entscheidet', () {
    test('invalid_credentials wird AuthInvalidCredentials', () {
      final failure = translate(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );

      expect(failure, isA<AuthInvalidCredentials>());
      expect(failure.code, 'invalid_credentials');
    });

    test('email_not_confirmed wird AuthEmailNotConfirmed', () {
      final failure = translate(
        const AuthApiException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
      );

      expect(failure, isA<AuthEmailNotConfirmed>());
      expect(failure.code, 'email_not_confirmed');
    });

    test('ein unbekannter Code wird AuthRequestRejected', () {
      // Ratenbegrenzung ist der häufigste Fall davon.
      final failure = translate(
        const AuthApiException(
          'Email rate limit exceeded',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      );

      expect(failure, isA<AuthRequestRejected>());
      expect(failure.code, 'over_email_send_rate_limit');
    });

    test('user_already_exists wird AuthEmailAlreadyRegistered', () {
      final failure = translate(
        const AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'user_already_exists',
        ),
      );

      expect(failure, isA<AuthEmailAlreadyRegistered>());
      expect(failure.code, 'user_already_exists');
    });

    test('email_exists ebenfalls', () {
      // GoTrue kennt zwei Codes für denselben Sachverhalt.
      final failure = translate(
        const AuthApiException(
          'Email address already in use',
          statusCode: '422',
          code: 'email_exists',
        ),
      );

      expect(failure, isA<AuthEmailAlreadyRegistered>());
    });

    test('weak_password wird AuthPasswordRejected', () {
      final failure = translate(
        const AuthApiException(
          'Password should be at least 6 characters',
          statusCode: '422',
          code: 'weak_password',
        ),
      );

      expect(failure, isA<AuthPasswordRejected>());
      expect(failure.code, 'weak_password');
    });

    test('AuthWeakPasswordException trägt denselben Code', () {
      // Ein eigener Ausnahmetyp in gotrue, der seinen Code selbst setzt
      // (`types/auth_exception.dart:93-100`). Ohne diesen Test wäre nicht
      // belegt, dass der Vergleich über den Code beide Formen fängt.
      final failure = translate(
        AuthWeakPasswordException(
          message: 'Password should be at least 6 characters',
          statusCode: '422',
          reasons: const <String>['length'],
        ),
      );

      expect(failure, isA<AuthPasswordRejected>());
    });

    test('der Code schlägt die Meldung', () {
      // Die Rückfallebene darf nicht mitreden, wenn ein Code da ist. Sonst
      // bekäme ein Server, der Code und Meldung uneinheitlich setzt, zwei
      // verschiedene Antworten auf denselben Fehler.
      final failure = translate(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'over_request_rate_limit',
        ),
      );

      expect(failure, isA<AuthRequestRejected>());
    });
  });

  group('Ohne Code entscheidet die Meldung', () {
    test('"Invalid login credentials" wird AuthInvalidCredentials', () {
      // Der exakte Meldungstext des Servers. Derselbe Teilstring wie in der PWA
      // (`screen-auth.jsx:476`).
      final failure = translate(
        const AuthApiException('Invalid login credentials', statusCode: '400'),
      );

      expect(failure, isA<AuthInvalidCredentials>());
      expect(failure.code, '400');
    });

    test('"Email not confirmed" wird AuthEmailNotConfirmed', () {
      final failure = translate(
        const AuthApiException('Email not confirmed', statusCode: '400'),
      );

      expect(failure, isA<AuthEmailNotConfirmed>());
    });

    test('"already registered" wird AuthEmailAlreadyRegistered', () {
      // Rückfallebene für älteren oder selbst betriebenen GoTrue, der
      // `error_code` nicht füllt. Derselbe Teilstring wie in der PWA
      // (`screen-auth.jsx:640`).
      final failure = translate(
        const AuthApiException('User already registered', statusCode: '422'),
      );

      expect(failure, isA<AuthEmailAlreadyRegistered>());
      expect(failure.code, '422');
    });

    test('"Password should" wird AuthPasswordRejected', () {
      final failure = translate(
        const AuthApiException(
          'Password should be at least 6 characters',
          statusCode: '422',
        ),
      );

      expect(failure, isA<AuthPasswordRejected>());
    });

    test('eine unbekannte Meldung wird AuthRequestRejected', () {
      final failure = translate(
        const AuthApiException(
          'Signups not allowed for this instance',
          statusCode: '422',
        ),
      );

      expect(failure, isA<AuthRequestRejected>());
      expect(failure.code, '422');
    });
  });

  group('Keine verwertbare Antwort', () {
    test('AuthRetryableFetchException wird AuthBackendUnavailable', () {
      // Der Offline-Fall: gotrue wirft das, wenn die Anfrage nicht durchkommt.
      final failure = translate(AuthRetryableFetchException(statusCode: '503'));

      expect(failure, isA<AuthBackendUnavailable>());
      expect(failure.code, '503');
    });

    test('AuthUnknownException wird AuthBackendUnavailable', () {
      final failure = translate(
        AuthUnknownException(
          message: 'Failed to decode error response',
          originalError: 'kaputt',
        ),
      );

      expect(failure, isA<AuthBackendUnavailable>());
    });

    test('alles Nicht-Auth wird AuthBackendUnavailable mit Typnamen', () {
      final failure = translate(const FormatException('kaputte Antwort'));

      expect(failure, isA<AuthBackendUnavailable>());
      expect(failure.code, 'FormatException');
    });
  });

  group('Namen der Backend-Objekte', () {
    test('Tabelle, Spalten und RPC stehen wie im Schema', () {
      // Diese fünf Zeichenketten sind der Datenvertrag der Username-Operationen.
      // Ein Tippfehler darin ist keine Ausnahme, sondern eine stille falsche
      // Anfrage: PostgREST bildet RPC-Argumente über den Namen ab, ein
      // unbekannter Parametername kommt als `null` an.
      //
      // Belegt gegen `03_Backend/supabase-schema.sql:201` und `:521-526`.
      expect(SupabaseAuthRemoteDataSource.profilesTable, 'profiles');
      expect(SupabaseAuthRemoteDataSource.usernameColumn, 'username');
      expect(SupabaseAuthRemoteDataSource.profileIdColumn, 'id');
      expect(
        SupabaseAuthRemoteDataSource.checkUsernameFunction,
        'check_username',
      );
      expect(SupabaseAuthRemoteDataSource.checkUsernameParameter, 'p_username');
    });
  });

  group('Nichts vom Backend erreicht die Domäne', () {
    test('die Meldung des Backends wandert nicht in die AuthFailure', () {
      // `cross-cutting-concerns.md`: "Sensitive backend details are never shown
      // to users." Die Meldung ist der Ort, an dem Interna auftauchen, deshalb
      // bleibt sie draußen.
      const secret = 'relation "auth.users" does not exist, hint: 12345';
      final failure = translate(
        const AuthApiException(secret, statusCode: '500'),
      );

      expect(failure.toString(), isNot(contains('auth.users')));
      expect(failure.toString(), isNot(contains('12345')));
      expect(failure.code, '500');
    });
  });

  group('Sitzung abbilden', () {
    /// Eine Sitzung, wie Supabase sie liefert, samt Tokens.
    Session sessionWithTokens() {
      return Session(
        accessToken: 'eyJhbGciOiJIUzI1NiJ9.GEHEIMES-ACCESS-TOKEN',
        refreshToken: 'GEHEIMES-REFRESH-TOKEN',
        tokenType: 'bearer',
        expiresIn: 3600,
        user: const User(
          id: 'a1b2c3',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{'name': 'Jan'},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
          email: 'jan@example.de',
        ),
      );
    }

    test('nimmt die Kennung und lässt die Tokens liegen', () {
      final session = SupabaseAuthRemoteDataSource.toAuthSession(
        sessionWithTokens(),
      );

      expect(session.isSignedIn, isTrue);
      expect(session.userId, 'a1b2c3');
      // Der eigentliche Punkt: das Token kommt nicht in den Riverpod-Zustand,
      // also auch nicht in ein `toString()`, das irgendwann in einem Log landet.
      expect(session.toString(), isNot(contains('GEHEIMES')));
      expect(session.toString(), isNot(contains('eyJ')));
      // Und auch nichts anderes aus dem Nutzerobjekt.
      expect(session.toString(), isNot(contains('jan@example.de')));
      expect(session.toString(), isNot(contains('Jan')));
    });

    test('keine Sitzung heißt abgemeldet', () {
      expect(
        SupabaseAuthRemoteDataSource.toAuthSession(null).isSignedIn,
        isFalse,
      );
    });
  });
}
