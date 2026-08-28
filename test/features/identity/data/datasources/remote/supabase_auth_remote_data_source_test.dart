import 'dart:convert';

import 'package:fact_app/features/identity/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
// `http` steht seit dem 28.08.2026 als `dev_dependency` in `pubspec.yaml`.
// Gebraucht wird der Typ, weil `SupabaseClient` seinen `httpClient` genau so
// entgegennimmt und kein Supabase-Paket ihn weiterexportiert.
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Die Vendor-Grenze des Features `identity`.
///
/// Zwei Teile, und sie brauchen verschiedene Werkzeuge:
///
/// 1. Die beiden **statischen** Abbildungen `translateError` und
///    `toAuthSession`. Das ist die einzige Stelle im Projekt, an der eine
///    `AuthException` zu einer `AuthFailure` wird, also die einzige, an der die
///    Zuordnung falsch sein kann. Reine Funktionen, direkt aufrufbar.
/// 2. Die vier **Instanzmethoden**. Sie waren ungeprüft, mit der Begründung,
///    ein Fake des `GoTrueClient` wäre eine Nachbildung des Vendors. Das
///    stimmt und ist trotzdem nicht der einzige Weg: [SupabaseClient] nimmt
///    einen `httpClient`, und darunter läuft der **echte** Vendor-Code.
///    Geprüft wird damit nicht unsere Nachbildung von Supabase, sondern unsere
///    Behandlung dessen, was Supabase aus einer gegebenen Antwort macht.
///
/// Warum Teil 2 nötig war, gemessen statt vermutet: drei Mutationen überlebten
/// die ganze Suite, darunter das Weglassen der Prüfung auf eine Anmeldeantwort
/// **ohne Sitzung**. Die App wäre danach auf die Karte gesprungen, ohne dass
/// jemand angemeldet ist.
///
/// Es geht dabei **kein Byte ins Netz**: [MockClient] beantwortet jede Anfrage
/// im Prozess.
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

  // -----------------------------------------------------------------------
  // Die vier Instanzmethoden, über einen gefälschten HTTP-Kanal.
  // -----------------------------------------------------------------------

  /// Jede Anfrage, die der Vendor-Client abgeschickt hat.
  late List<http.Request> requests;

  setUp(() => requests = <http.Request>[]);

  /// Baut die Datenquelle über einem [SupabaseClient], dessen HTTP-Kanal
  /// [respond] beantwortet.
  ///
  /// Zwei Feinheiten, beide gemessen und beide nötig:
  ///
  /// * `autoRefreshToken: false`. Der Standard ist `true`, und `GoTrueClient`
  ///   startet dann schon im Konstruktor einen `Timer.periodic`, den kein Test
  ///   wieder los wird.
  /// * `request: request` an jeder Antwort. `postgrest` greift in
  ///   `_parseResponse` mit `response.request!` darauf zu. Ohne das scheitert
  ///   jeder PostgREST-Aufruf an einem Null-Check, und zwar bevor der Test
  ///   überhaupt bei seinem Gegenstand ankommt.
  SupabaseAuthRemoteDataSource dataSource(
    http.Response Function(http.Request request) respond,
  ) {
    final client = SupabaseClient(
      'https://projekt.test',
      'sb_publishable_test',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _InMemoryPkceStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
    addTearDown(client.dispose);
    return SupabaseAuthRemoteDataSource(client);
  }

  /// Eine JSON-Antwort mit Statuscode [status]. `null` heißt leerer Rumpf, so
  /// wie PostgREST auf ein `update` ohne `select()` antwortet.
  http.Response reply(http.Request request, Object? body, {int status = 200}) {
    return http.Response(
      body == null ? '' : jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json'},
      request: request,
    );
  }

  /// Das Nutzerobjekt, wie GoTrue es liefert. Nur die Felder, ohne die
  /// `User.fromJson` nicht arbeitet, plus die Kennung, auf die es ankommt.
  Map<String, dynamic> userJson(String id) => <String, dynamic>{
    'id': id,
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  };

  /// Eine vollständige Anmeldeantwort samt Sitzung.
  Map<String, dynamic> sessionJson(String id) => <String, dynamic>{
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.ACCESS',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'REFRESH',
    'user': userJson(id),
  };

  group('signInWithPassword', () {
    test('eine Antwort mit Sitzung wird die angemeldete Sitzung', () async {
      final source = dataSource(
        (request) => reply(request, sessionJson('u-77')),
      );

      final session = await source.signInWithPassword(
        email: 'jan@example.de',
        password: 'geheim',
      );

      expect(session.isSignedIn, isTrue);
      expect(session.userId, 'u-77');
      // Und die beiden Werte gingen unvertauscht an GoTrue.
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['email'], 'jan@example.de');
      expect(body['password'], 'geheim');
    });

    test('eine Antwort ohne Sitzung ist ein Fehlschlag und kein Erfolg', () async {
      // **Der wichtigste Test dieser Datei.** GoTrue antwortet in einem Projekt
      // mit Bestätigungspflicht mit Status 200 und einem bloßen Nutzerobjekt,
      // also ohne `access_token`. Ginge das als Erfolg durch, spränge die App
      // auf die Karte, angemeldet wäre niemand, und jede geschützte Aktion
      // danach scheiterte still.
      //
      // Nachgemessen: den `throw` durch `return session` zu ersetzen überlebte
      // alle 614 Tests, die es vor diesem hier gab.
      final source = dataSource((request) => reply(request, userJson('u-77')));

      await expectLater(
        source.signInWithPassword(email: 'jan@example.de', password: 'geheim'),
        throwsA(
          isA<AuthBackendUnavailable>().having(
            (failure) => failure.code,
            'code',
            'missing_session',
          ),
        ),
      );
    });

    test(
      'ein abgelehnter Zugang kommt als AuthInvalidCredentials an',
      () async {
        // Belegt die Verdrahtung zwischen `catch` und `translateError`: der Weg
        // vom HTTP-Status zur `AuthFailure` läuft wirklich über die Abbildung
        // oben und nicht an ihr vorbei.
        final source = dataSource(
          (request) => reply(request, <String, dynamic>{
            'code': 'invalid_credentials',
            'error_code': 'invalid_credentials',
            'msg': 'Invalid login credentials',
            'message': 'Invalid login credentials',
          }, status: 400),
        );

        await expectLater(
          source.signInWithPassword(
            email: 'jan@example.de',
            password: 'falsch',
          ),
          throwsA(
            isA<AuthInvalidCredentials>().having(
              (failure) => failure.code,
              'code',
              'invalid_credentials',
            ),
          ),
        );
      },
    );
  });

  group('signUpWithPassword', () {
    test('eine Antwort ohne Sitzung ist hier der Bestätigungsfall', () async {
      // Die Gegenprobe zur Anmeldung: dieselbe Antwort ist hier **kein**
      // Fehlschlag. Ohne diesen Test ließe sich die Prüfung der Anmeldung
      // "reparieren", indem jemand sie in beide Methoden zieht.
      final source = dataSource((request) => reply(request, userJson('u-77')));

      final session = await source.signUpWithPassword(
        email: 'jan@example.de',
        password: 'geheim',
        name: 'jan',
        hometown: 'München',
      );

      expect(session.isSignedIn, isFalse);
    });

    test('Name und Heimatstadt gehen als Metadaten mit', () async {
      final source = dataSource(
        (request) => reply(request, sessionJson('u-9')),
      );

      final session = await source.signUpWithPassword(
        email: 'jan@example.de',
        password: 'geheim',
        name: 'jan',
        hometown: 'München',
      );

      expect(session.userId, 'u-9');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      expect(data['name'], 'jan');
      expect(data['hometown'], 'München');
    });
  });

  group('checkUsernameTaken', () {
    test('die RPC wird mit dem vereinbarten Parameternamen gerufen', () async {
      final source = dataSource((request) => reply(request, true));

      expect(await source.checkUsernameTaken('jan'), isTrue);
      expect(
        requests.single.url.path,
        endsWith('/rpc/${SupabaseAuthRemoteDataSource.checkUsernameFunction}'),
      );
      expect(jsonDecode(requests.single.body), <String, dynamic>{
        SupabaseAuthRemoteDataSource.checkUsernameParameter: 'jan',
      });
    });

    test('false heißt frei', () async {
      final source = dataSource((request) => reply(request, false));

      expect(await source.checkUsernameTaken('jan'), isFalse);
    });

    test('eine Antwort, die kein bool ist, wird ein Fehlschlag', () async {
      // Nachgemessen: die Prüfung so zu verbiegen, dass alles Nicht-Boolesche
      // als "frei" durchgeht, überlebte die Suite. Das ist der teuerste
      // Ausgang, weil das Schreiben danach am Eindeutigkeitsindex scheitert und
      // der Nutzer den Fehler erst hinter der Registrierung sieht.
      final source = dataSource((request) => reply(request, null, status: 200));

      await expectLater(
        source.checkUsernameTaken('jan'),
        throwsA(
          isA<AuthBackendUnavailable>().having(
            (failure) => failure.code,
            'code',
            'check_username_returned_Null',
          ),
        ),
      );
    });

    test('eine Zeichenkette ebenfalls, mit ihrem Typ im Code', () async {
      final source = dataSource((request) => reply(request, 'vielleicht'));

      await expectLater(
        source.checkUsernameTaken('jan'),
        throwsA(
          isA<AuthBackendUnavailable>().having(
            (failure) => failure.code,
            'code',
            'check_username_returned_String',
          ),
        ),
      );
    });

    test('eine abgelehnte Anfrage wird AuthRequestRejected', () async {
      // Der Vertrag in `_translateDataFailures`: eine `PostgrestException`
      // heißt "das Backend hat geantwortet und abgelehnt". Nachgemessen: sie
      // stattdessen auf `AuthBackendUnavailable` abzubilden überlebte die
      // Suite. Für den Nutzer ist das heute unsichtbar, der Vertrag sagt aber
      // etwas anderes, und die nächste Unterscheidung baut darauf auf.
      final source = dataSource(
        (request) => reply(request, <String, dynamic>{
          'code': '42501',
          'message': 'permission denied for function check_username',
          'details': null,
          'hint': null,
        }, status: 403),
      );

      await expectLater(
        source.checkUsernameTaken('jan'),
        throwsA(
          isA<AuthRequestRejected>().having(
            (failure) => failure.code,
            'code',
            '42501',
          ),
        ),
      );
    });
  });

  group('setUsername', () {
    test('schreibt genau eine Spalte in genau eine Zeile', () async {
      final source = dataSource((request) => reply(request, null, status: 204));

      await source.setUsername(userId: 'u-77', username: 'jan');

      final sent = requests.single;
      expect(sent.method, 'PATCH');
      expect(
        sent.url.path,
        endsWith('/${SupabaseAuthRemoteDataSource.profilesTable}'),
      );
      // Der Filter steht in der Abfrage, nicht im Rumpf. Ohne ihn schriebe das
      // `update` jede Zeile der Tabelle.
      expect(sent.url.query, 'id=eq.u-77');
      expect(jsonDecode(sent.body), <String, dynamic>{
        SupabaseAuthRemoteDataSource.usernameColumn: 'jan',
      });
    });

    test(
      'ein Verstoß gegen den Eindeutigkeitsindex wird AuthRequestRejected',
      () async {
        final source = dataSource(
          (request) => reply(request, <String, dynamic>{
            'code': '23505',
            'message': 'duplicate key value violates unique constraint',
            'details': null,
            'hint': null,
          }, status: 409),
        );

        await expectLater(
          source.setUsername(userId: 'u-77', username: 'jan'),
          throwsA(
            isA<AuthRequestRejected>().having(
              (failure) => failure.code,
              'code',
              '23505',
            ),
          ),
        );
      },
    );

    test('die Meldung des Backends geht nicht mit', () async {
      // Sie trägt hier einen Indexnamen und damit einen Spaltennamen.
      // `cross-cutting-concerns.md` verlangt, dass so etwas den Nutzer nicht
      // erreicht.
      final source = dataSource(
        (request) => reply(request, <String, dynamic>{
          'code': '23505',
          'message':
              'duplicate key value violates unique constraint '
              '"profiles_username_key"',
          'details': null,
          'hint': null,
        }, status: 409),
      );

      await expectLater(
        source.setUsername(userId: 'u-77', username: 'jan'),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.toString(),
            'toString',
            isNot(contains('profiles_username_key')),
          ),
        ),
      );
    });
  });

  group('currentSession und sessionChanges', () {
    test('vor der Anmeldung abgemeldet, danach angemeldet, und der Strom meldet '
        'es', () async {
      final source = dataSource(
        (request) => reply(request, sessionJson('u-9')),
      );
      expect(source.currentSession().isSignedIn, isFalse);

      final seen = <AuthSession>[];
      final subscription = source.sessionChanges().listen(seen.add);
      addTearDown(subscription.cancel);

      await source.signInWithPassword(
        email: 'jan@example.de',
        password: 'geheim',
      );
      // Der Strom des Vendors ist asynchron, ein Durchlauf der Ereignisschleife
      // genügt.
      await Future<void>.delayed(Duration.zero);

      expect(source.currentSession().userId, 'u-9');
      expect(seen.single.userId, 'u-9');
    });
  });
}

/// Ablage für den PKCE-Code-Verifier, im Speicher.
///
/// Nötig, weil `supabase_flutter` standardmäßig `AuthFlowType.pkce` fährt und
/// `GoTrueClient.signUp` dann eine Ablage **voraussetzt**: ohne sie bricht der
/// Vendor mit "You need to provide asyncStorage to perform pkce flow" ab, und
/// zwar als `AssertionError`, die unser `catch` in eine
/// `AuthBackendUnavailable` übersetzt. Der Testaufbau bliebe grün und prüfte
/// nichts. Gemessen, nicht vermutet.
///
/// Der Ablauf bleibt damit derselbe wie in der App. Eine Umstellung auf
/// `AuthFlowType.implicit` wäre der bequemere Weg gewesen und hätte etwas
/// anderes geprüft, als die App tut.
class _InMemoryPkceStorage implements GotrueAsyncStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
