import 'package:fact_app/features/identity/data/datasources/remote/auth_remote_data_source.dart';
import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Die Anmeldung über Supabase Auth, `02_Frontend/app/api.jsx:56-59`.
///
/// ADR-001: Supabase-spezifischer Code ist in der Datenschicht erlaubt und nur
/// dort. Diese Datei ist die einzige im Feature `identity`, die den
/// Vendor-Client überhaupt sieht, und die einzige Stelle im Projekt, an der eine
/// `AuthException` auf eine [AuthFailure] abgebildet wird
/// (`cross-cutting-concerns.md`: "Infrastructure exceptions are translated at
/// the data/service boundary").
///
/// Nimmt den [GoTrueClient] und nicht den ganzen `SupabaseClient`: die Anmeldung
/// braucht keine Tabellen, keinen Speicher und kein Realtime.
///
/// ## Es gibt hier absichtlich keinen Provider
///
/// Anders als bei `factRemoteDataSourceProvider`. Ein Provider neben der
/// Implementierung ist genau das, was `presentation` nicht lesen darf, und ein
/// Provider, den niemand lesen darf, wird beim nächsten Verdrahten falsch
/// benutzt. Die Verdrahtung steht in `lib/app/bootstrap.dart`, also in der
/// App-Komposition, die laut `dependency-rules.md` als einzige Schicht "all
/// public feature entry points" kennen darf.
class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  /// [auth] ist `supabaseClientProvider.auth`.
  SupabaseAuthRemoteDataSource(this._auth);

  /// Fehlercode für falsche Zugangsdaten.
  ///
  /// ## Warum ein Vergleich gegen eine Zeichenkette und nicht gegen `ErrorCode`
  ///
  /// Nachgesehen in `gotrue 2.27.2` (transitiv über `supabase_flutter 2.17.2`):
  /// `AuthException.code` ist ein `String?` und trägt den Rohwert aus der
  /// Antwort (`fetch.dart:74-82`, Feld `code` ab API-Version 2024-01-01, davor
  /// `error_code`). Die Aufzählung `ErrorCode` in `types/error_code.dart` ist
  /// nur eine **Momentaufnahme** der Serverliste: sie enthält
  /// `email_not_confirmed`, aber **nicht** `invalid_credentials`. Ein Vergleich
  /// über die Aufzählung würde also genau den häufigsten Fall nicht erkennen.
  static const String invalidCredentialsCode = 'invalid_credentials';

  /// Fehlercode für eine unbestätigte E-Mail-Adresse,
  /// `ErrorCode.emailNotConfirmed` in `gotrue 2.27.2`.
  static const String emailNotConfirmedCode = 'email_not_confirmed';

  /// Rückfallebene für falsche Zugangsdaten, wenn das Backend keinen Code
  /// liefert.
  ///
  /// Derselbe Teilstring wie in der PWA (`screen-auth.jsx:476`). Die
  /// vollständige Meldung des Servers lautet "Invalid login credentials".
  /// **Dieser Vergleich steht hier und an keiner zweiten Stelle im Projekt.**
  static const String invalidCredentialsMessage = 'Invalid login';

  /// Rückfallebene für eine unbestätigte E-Mail-Adresse, PWA
  /// `screen-auth.jsx:477`.
  static const String emailNotConfirmedMessage = 'Email not confirmed';

  final GoTrueClient _auth;

  /// Bildet die Sitzung des Vendors auf den Domänentyp ab.
  ///
  /// Die ganze Abbildung: Nutzerkennung mitnehmen, alles andere liegen lassen.
  /// Access-Token, Refresh-Token und Ablaufzeitpunkt bleiben beim Client, siehe
  /// die Begründung in [AuthSession].
  @visibleForTesting
  static AuthSession toAuthSession(Session? session) => session == null
      ? const AuthSession.signedOut()
      : AuthSession.signedIn(userId: session.user.id);

  /// Bildet einen Fehlschlag des Vendors auf eine [AuthFailure] ab.
  ///
  /// Die Reihenfolge ist die eigentliche Regel:
  ///
  /// 1. `AuthRetryableFetchException` und `AuthUnknownException`: es kam keine
  ///    verwertbare Antwort. [AuthBackendUnavailable].
  /// 2. Der maschinenlesbare `code` aus der Antwort. Ist er da, entscheidet nur
  ///    er.
  /// 3. Ein unbekannter Code heißt "das Backend hat geantwortet und
  ///    abgelehnt", also [AuthRequestRejected], und **nicht** eine Suche in der
  ///    Meldung. Sonst bekäme ein Server, der Code und Meldung uneinheitlich
  ///    setzt, zwei verschiedene Antworten auf denselben Fehler.
  /// 4. Erst ohne Code wird die Meldung durchsucht. Das ist die Rückfallebene
  ///    für älteren oder selbst betriebenen GoTrue, der `error_code` nicht
  ///    füllt.
  /// 5. Alles übrige: [AuthBackendUnavailable] mit dem Typnamen als Code.
  ///
  /// Was **nicht** mitgeht: die Meldung des Backends. Sie kann Interna
  /// enthalten, und `cross-cutting-concerns.md` verlangt, dass Backend-Details
  /// den Nutzer nicht erreichen. Der Code genügt zur Diagnose.
  @visibleForTesting
  static AuthFailure translateError(Object error, StackTrace stackTrace) {
    if (error is AuthRetryableFetchException || error is AuthUnknownException) {
      final failed = error as AuthException;
      return AuthBackendUnavailable(
        code: failed.statusCode ?? failed.runtimeType.toString(),
        stackTrace: stackTrace,
      );
    }
    if (error is AuthException) {
      final code = error.code;
      if (code == invalidCredentialsCode) {
        return AuthInvalidCredentials(code: code, stackTrace: stackTrace);
      }
      if (code == emailNotConfirmedCode) {
        return AuthEmailNotConfirmed(code: code, stackTrace: stackTrace);
      }
      if (code != null) {
        return AuthRequestRejected(code: code, stackTrace: stackTrace);
      }
      if (error.message.contains(invalidCredentialsMessage)) {
        return AuthInvalidCredentials(
          code: error.statusCode,
          stackTrace: stackTrace,
        );
      }
      if (error.message.contains(emailNotConfirmedMessage)) {
        return AuthEmailNotConfirmed(
          code: error.statusCode,
          stackTrace: stackTrace,
        );
      }
      return AuthRequestRejected(
        code: error.statusCode,
        stackTrace: stackTrace,
      );
    }
    return AuthBackendUnavailable(
      code: error.runtimeType.toString(),
      stackTrace: stackTrace,
    );
  }

  @override
  AuthSession currentSession() => toAuthSession(_auth.currentSession);

  /// `onAuthStateChange` feuert auch bei `initialSession`, `tokenRefreshed` und
  /// `userUpdated`, also mehrfach mit derselben Kennung. Hier wird bewusst
  /// **nicht** entdoppelt: das erledigt `AuthSession ==` an der Stelle, die es
  /// braucht.
  ///
  /// Fehlerereignisse gehen unverändert durch. Der Strom des Vendors meldet
  /// eine fehlgeschlagene Token-Erneuerung als Fehler, und wer ihn abonniert,
  /// muss das behandeln, siehe `AuthSessionNotifier`.
  @override
  Stream<AuthSession> sessionChanges() =>
      _auth.onAuthStateChange.map((state) => toAuthSession(state.session));

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (error, stackTrace) {
      throw translateError(error, stackTrace);
    }
    final session = toAuthSession(response.session);
    if (!session.isSignedIn) {
      // Kommt vor, wenn das Projekt eine Bestätigung verlangt und GoTrue eine
      // Antwort ohne Sitzung liefert, statt zu werfen. Ohne Sitzung ist niemand
      // angemeldet, und das darf nicht als Erfolg durchgehen.
      throw const AuthBackendUnavailable(code: 'missing_session');
    }
    return session;
  }
}
