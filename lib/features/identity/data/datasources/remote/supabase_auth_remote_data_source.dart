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
/// ## Warum hier der ganze [SupabaseClient] steht
///
/// Bis Schritt 9 nahm diese Klasse nur den [GoTrueClient], mit der Begründung,
/// die Anmeldung brauche keine Tabellen. Mit der Registrierung ist das nicht
/// mehr wahr: die Username-Prüfung ist eine RPC (`check_username`) und das
/// Setzen des Usernames ein `update` auf `profiles`. Beides geht über PostgREST,
/// nicht über GoTrue. Die Alternative wären zwei Konstruktorparameter für
/// denselben Client gewesen.
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
  /// [_client] kommt aus `supabaseClientProvider`.
  SupabaseAuthRemoteDataSource(this._client);

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

  /// Fehlercodes von GoTrue für "diese Adresse hat schon ein Konto".
  ///
  /// Zwei, weil GoTrue zwei kennt: `user_already_exists` bei
  /// `signUp` und `email_exists` beim Ändern einer Adresse
  /// (`gotrue 2.27.2`, `types/error_code.dart:9` und `:53`). Beide hier, damit
  /// eine Änderung der Serverantwort nicht auf den Sammelfall fällt.
  static const Set<String> alreadyRegisteredCodes = <String>{
    'user_already_exists',
    'email_exists',
  };

  /// Fehlercode für ein abgelehntes Passwort, `ErrorCode.weakPassword`.
  ///
  /// Denselben Code trägt `AuthWeakPasswordException`
  /// (`types/auth_exception.dart:93-100`), der Vergleich fängt also beide
  /// Formen.
  static const String weakPasswordCode = 'weak_password';

  /// Rückfallebene für ein vorhandenes Konto, wenn kein Code kommt.
  ///
  /// Derselbe Teilstring wie in der PWA (`screen-auth.jsx:640`). Die
  /// vollständige Meldung des Servers lautet "User already registered".
  static const String alreadyRegisteredMessage = 'already registered';

  /// Rückfallebene für ein abgelehntes Passwort, PWA `screen-auth.jsx:641`.
  ///
  /// Die vollständige Meldung lautet "Password should be at least 6
  /// characters".
  static const String weakPasswordMessage = 'Password should';

  /// Die Tabelle, in die [setUsername] schreibt.
  static const String profilesTable = 'profiles';

  /// Spalte des Usernames in [profilesTable].
  static const String usernameColumn = 'username';

  /// Primärschlüssel von [profilesTable], gleich `auth.users.id`.
  static const String profileIdColumn = 'id';

  /// Name der RPC hinter [checkUsernameTaken],
  /// `03_Backend/supabase-schema.sql:521`.
  static const String checkUsernameFunction = 'check_username';

  /// Parametername der RPC. PostgREST bildet Argumente über den Namen ab, ein
  /// Tippfehler hier ist keine Ausnahme, sondern ein `null`-Argument.
  static const String checkUsernameParameter = 'p_username';

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

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
  ///    er. Erkannt werden `invalid_credentials`, `email_not_confirmed`,
  ///    `user_already_exists`, `email_exists` und `weak_password`.
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
      if (alreadyRegisteredCodes.contains(code)) {
        return AuthEmailAlreadyRegistered(code: code, stackTrace: stackTrace);
      }
      if (code == weakPasswordCode) {
        return AuthPasswordRejected(code: code, stackTrace: stackTrace);
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
      if (error.message.contains(alreadyRegisteredMessage)) {
        return AuthEmailAlreadyRegistered(
          code: error.statusCode,
          stackTrace: stackTrace,
        );
      }
      if (error.message.contains(weakPasswordMessage)) {
        return AuthPasswordRejected(
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

  /// `sb.auth.signUp({ email, password, options: { data: { name, hometown } } })`
  /// aus `api.jsx:47-51`.
  ///
  /// **Hier fehlt jede Prüfung wie oben.** Eine Antwort ohne Sitzung ist bei der
  /// Registrierung der Bestätigungsfall und geht als `signedOut` durch, siehe
  /// `AuthRepository.signUpWithPassword`.
  ///
  /// [name] und [hometown] gehen in `raw_user_meta_data` und sind vom Client
  /// frei beschreibbar, also **nicht vertrauenswürdig**.
  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
    required String name,
    required String hometown,
  }) async {
    final AuthResponse response;
    try {
      response = await _auth.signUp(
        email: email,
        password: password,
        data: <String, dynamic>{'name': name, 'hometown': hometown},
      );
    } catch (error, stackTrace) {
      throw translateError(error, stackTrace);
    }
    return toAuthSession(response.session);
  }

  /// Die RPC [checkUsernameFunction], `api.jsx:246-249`.
  ///
  /// Die Funktion ist `SECURITY DEFINER` und vergleicht
  /// `lower(username) = lower(p_username)`
  /// (`03_Backend/supabase-schema.sql:521-526`), die Prüfung ist also
  /// **unabhängig von der Groß- und Kleinschreibung**. Der Eindeutigkeitsindex
  /// auf der Spalte ist es nicht (`username TEXT UNIQUE`, `:201`). Das ist eine
  /// Asymmetrie des Backends und wird hier nicht ausgeglichen: sie zu
  /// "verbessern" hieße, im Client eine Regel zu erfinden, die der Server nicht
  /// kennt.
  ///
  /// Eine Antwort, die kein `bool` ist, wird ein Fehlschlag statt einer
  /// stillschweigenden `false`. Fehler-Isolation durch Konstruktion, wie im
  /// Fakt-Mapper: eine erfundene "Name ist frei"-Antwort wäre der teuerste
  /// Ausgang, weil das Schreiben danach am Eindeutigkeitsindex scheitert.
  @override
  Future<bool> checkUsernameTaken(String username) async {
    final Object? answer = await _translateDataFailures(
      () => _client.rpc<Object?>(
        checkUsernameFunction,
        params: <String, dynamic>{checkUsernameParameter: username},
      ),
    );
    if (answer is bool) {
      return answer;
    }
    throw AuthBackendUnavailable(
      code: 'check_username_returned_${answer.runtimeType}',
    );
  }

  /// `sb.from('profiles').update({ username }).eq('id', userId)` aus
  /// `api.jsx:253-258`, mit `isChange = false`.
  ///
  /// `username_changed_at` bleibt deshalb leer, und das ist die Absicht der
  /// Quelle: die einmalige Änderung soll nach der Registrierung noch verfügbar
  /// sein.
  ///
  /// **Das ist ein direkter Schreibzugriff des Clients auf `profiles`.** Ob die
  /// RLS-Policy dort ein `WITH CHECK` hat, entscheidet, ob ein Nutzer damit nur
  /// sein eigenes Profil ändern kann. Das ist die offene Entscheidung E-24 in
  /// `REBUILD_STATUS.md` und wird hier nicht gelöst, sondern gemeldet: der
  /// Client bleibt unvertraut, die Grenze liegt im Backend.
  @override
  Future<void> setUsername({
    required String userId,
    required String username,
  }) async {
    await _translateDataFailures(() async {
      // Der Rückgabewert ist `dynamic` und interessiert nicht: PostgREST
      // antwortet ohne `select()` mit einem leeren Rumpf. Explizit `null`
      // zurückgeben, statt den `dynamic`-Wert durchzureichen.
      await _client
          .from(profilesTable)
          .update(<String, Object?>{usernameColumn: username})
          .eq(profileIdColumn, userId);
      return null;
    });
  }

  /// Führt [request] aus und übersetzt jeden Fehlschlag in eine [AuthFailure].
  ///
  /// Nötig, weil die beiden Username-Operationen über PostgREST laufen und
  /// deshalb `PostgrestException` werfen, nicht `AuthException`. Dieselbe
  /// Zuordnung wie in `SupabaseFactRemoteDataSource._translateFailures`, nur mit
  /// dem Fehlerbild dieses Features:
  ///
  /// * `PostgrestException`: das Backend hat geantwortet und abgelehnt, also
  ///   [AuthRequestRejected]. Deckt eine abgelehnte RLS-Policy (`42501`), einen
  ///   Verstoß gegen den Eindeutigkeitsindex (`23505`) und ein verschobenes
  ///   Schema. Nicht feiner, weil die Oberfläche daraus keine unterschiedliche
  ///   Handlung ableiten kann: für alle drei gibt es denselben Satz.
  /// * `AuthException`: über [translateError], damit ein abgelaufenes Token
  ///   dieselbe Antwort bekommt wie überall sonst.
  /// * alles übrige: [AuthBackendUnavailable].
  ///
  /// Die Meldung des Backends geht nicht mit. Sie kann Spaltennamen tragen.
  static Future<Object?> _translateDataFailures(
    Future<Object?> Function() request,
  ) async {
    try {
      return await request();
    } on PostgrestException catch (error, stackTrace) {
      throw AuthRequestRejected(code: error.code, stackTrace: stackTrace);
    } catch (error, stackTrace) {
      throw translateError(error, stackTrace);
    }
  }
}
