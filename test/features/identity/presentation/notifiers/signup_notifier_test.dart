import 'dart:async';

import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/signup_notifier.dart';
import 'package:fact_app/features/identity/presentation/notifiers/username_check_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_auth_repository.dart';

/// Der Registriervorgang, ohne Widget-Baum.
void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());
  tearDown(() async => repository.close());

  late ProviderContainer scope;
  late ProviderSubscription<AsyncValue<SignupStatus>> screen;

  /// Baut den Container und hält den Provider am Leben, siehe die Begründung in
  /// `login_notifier_test.dart`.
  void openScreen() {
    scope = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(scope.dispose);
    screen = scope.listen(signupProvider, (_, _) {});
  }

  /// Eine gültige Eingabe. Einzelne Felder werden je Test überschrieben.
  Future<bool> submit({
    String email = 'jan@example.de',
    String password = 'geheim1A!',
    String username = 'stadtfuchs_m',
    UsernameStatus usernameStatus = UsernameStatus.ok,
    bool termsAccepted = true,
    String hometown = 'München',
  }) {
    return scope
        .read(signupProvider.notifier)
        .submit(
          email: email,
          password: password,
          username: username,
          usernameStatus: usernameStatus,
          termsAccepted: termsAccepted,
          hometown: hometown,
        );
  }

  AsyncValue<SignupStatus> state() => scope.read(signupProvider);

  group('Startzustand', () {
    test('ist Daten und nicht Laden', () {
      openScreen();

      expect(state().isLoading, isFalse);
      expect(state().hasError, isFalse);
      expect(state().value, SignupStatus.untouched);
    });
  });

  group('Die Reihenfolge der drei Prüfungen', () {
    test(
      'leere Felder melden SignupInputIncomplete und rufen nichts',
      () async {
        openScreen();

        final succeeded = await submit(email: '', password: '');

        expect(succeeded, isFalse);
        expect(state().error, isA<SignupInputIncomplete>());
        expect(repository.signUpCount, 0);
      },
    );

    test('nur Leerzeichen zählt als leer', () async {
      openScreen();

      await submit(email: '   ', password: '   ');

      expect(state().error, isA<SignupInputIncomplete>());
      expect(repository.signUpCount, 0);
    });

    test('die leeren Felder schlagen die fehlende Zustimmung', () async {
      openScreen();

      await submit(email: '', password: '', termsAccepted: false);

      expect(state().error, isA<SignupInputIncomplete>());
    });

    test('die fehlende Zustimmung schlägt den vergebenen Username', () async {
      // **Das ist der Kern dieser Gruppe.** Beide Meldungen erscheinen an
      // derselben Stelle und beide verhindern das Abschicken, eine vertauschte
      // Reihenfolge fällt also von außen nicht auf. Die Quelle prüft die
      // Zustimmung zuerst (`screen-auth.jsx:612` vor `:614`).
      openScreen();

      await submit(
        termsAccepted: false,
        usernameStatus: UsernameStatus.taken,
        username: 'schon_weg',
      );

      expect(state().error, isA<SignupTermsNotAccepted>());
      expect(state().error, isNot(isA<SignupUsernameUnusable>()));
      expect(repository.signUpCount, 0);
    });

    test('mit Zustimmung bleibt der Username übrig', () async {
      openScreen();

      await submit(usernameStatus: UsernameStatus.taken, username: 'schon_weg');

      expect(state().error, isA<SignupUsernameUnusable>());
      expect(repository.signUpCount, 0);
    });
  });

  group('Der Username-Guard', () {
    test('ein leeres Feld blockiert', () async {
      openScreen();

      await submit(username: '', usernameStatus: UsernameStatus.idle);

      expect(state().error, isA<SignupUsernameUnusable>());
      expect(repository.signUpCount, 0);
    });

    test('taken, invalid und checking blockieren', () async {
      openScreen();

      for (final status in <UsernameStatus>[
        UsernameStatus.taken,
        UsernameStatus.invalid,
        UsernameStatus.checking,
      ]) {
        await submit(usernameStatus: status);
        expect(
          state().error,
          isA<SignupUsernameUnusable>(),
          reason: status.name,
        );
      }
      expect(repository.signUpCount, 0);
    });

    test('idle blockiert nicht, wie in der Quelle', () async {
      // Ein Name, dessen Prüfung gescheitert ist, geht durch. Über die
      // Eindeutigkeit entscheidet die Datenbank.
      openScreen();

      final succeeded = await submit(usernameStatus: UsernameStatus.idle);

      expect(succeeded, isTrue);
      expect(repository.signUpCount, 1);
    });
  });

  group('Keine Prüfungen, die die Quelle nicht hat', () {
    test('keine Formatprüfung der Adresse', () async {
      openScreen();

      final succeeded = await submit(email: 'kein-at-zeichen');

      expect(succeeded, isTrue);
      expect(repository.lastSignUpEmail, 'kein-at-zeichen');
    });

    test('keine Mindestlänge des Passworts', () async {
      // Die Länge kommt als Serverfehler zurück, siehe `AuthPasswordRejected`.
      openScreen();

      final succeeded = await submit(password: 'x');

      expect(succeeded, isTrue);
      expect(repository.lastSignUpPassword, 'x');
    });
  });

  group('Erfolg mit Sitzung', () {
    test('schickt getrimmte Adresse, ungetrimmtes Passwort, Username als Name '
        'und die Stadt', () async {
      openScreen();

      final succeeded = await submit(
        email: '  jan@example.de  ',
        password: '  geheim  ',
        username: 'stadtfuchs_m',
        hometown: 'Regensburg',
      );

      expect(succeeded, isTrue);
      expect(repository.lastSignUpEmail, 'jan@example.de');
      // Leerzeichen in einem Passwort sind erlaubt und bedeutungstragend.
      expect(repository.lastSignUpPassword, '  geheim  ');
      // Die Quelle schickt `username || t('auth.defaultName')`; der zweite
      // Zweig ist toter Code, weil der Guard schon einen Username verlangt.
      expect(repository.lastSignUpName, 'stadtfuchs_m');
      expect(repository.lastSignUpHometown, 'Regensburg');
    });

    test('schreibt danach den Username in das Profil', () async {
      repository.userId = 'user-42';
      openScreen();

      await submit(username: 'stadtfuchs_m');

      expect(repository.setUsernameCount, 1);
      expect(repository.lastSetUsernameUserId, 'user-42');
      expect(repository.lastSetUsernameValue, 'stadtfuchs_m');
      expect(state().hasError, isFalse);
      expect(state().value, SignupStatus.untouched);
    });

    test('ein laufender Vorgang wird nicht zweimal gestartet', () async {
      repository.signUpGate = Completer<void>();
      openScreen();

      final first = submit();
      expect(state().isLoading, isTrue);
      final second = await submit();

      expect(second, isFalse);
      repository.signUpGate!.complete();
      expect(await first, isTrue);
      expect(repository.signUpCount, 1);
    });
  });

  group('Erfolg ohne Sitzung', () {
    test('meldet den Bestätigungsfall und ist kein Fehler', () async {
      repository.signUpCreatesSession = false;
      openScreen();

      final succeeded = await submit();

      expect(succeeded, isFalse);
      expect(state().hasError, isFalse);
      expect(state().value, SignupStatus.emailConfirmationPending);
    });

    test('schreibt keinen Username', () async {
      // Es gibt niemanden, in dessen Profil geschrieben werden könnte: ohne
      // Sitzung ist der Client nicht angemeldet, und die RLS-Policy auf
      // `profiles` würde das Schreiben ablehnen.
      repository.signUpCreatesSession = false;
      openScreen();

      await submit();

      expect(repository.setUsernameCount, 0);
    });
  });

  group('Fehlschläge des Backends', () {
    test('eine bekannte Adresse landet als AuthEmailAlreadyRegistered im '
        'Zustand', () async {
      repository.signUpFailure = const AuthEmailAlreadyRegistered(
        code: 'user_already_exists',
      );
      openScreen();

      final succeeded = await submit();

      expect(succeeded, isFalse);
      expect(state().error, isA<AuthEmailAlreadyRegistered>());
    });

    test('ein abgelehntes Passwort ebenso', () async {
      repository.signUpFailure = const AuthPasswordRejected(
        code: 'weak_password',
      );
      openScreen();

      await submit();

      expect(state().error, isA<AuthPasswordRejected>());
    });

    test(
      'ein fehlgeschlagenes setUsername wird gemeldet, nicht geschluckt',
      () async {
        // Die Quelle hängt `.catch(() => {})` daran. Der Fall ist echt: zwischen
        // Prüfung und Schreiben liegen mindestens 500 ms.
        repository.setUsernameFailure = const AuthRequestRejected(
          code: '23505',
        );
        openScreen();

        final succeeded = await submit();

        expect(succeeded, isFalse);
        expect(state().error, isA<AuthRequestRejected>());
        // Das Konto gibt es trotzdem, und die Sitzung auch. Nur der Name fehlt.
        expect(repository.signUpCount, 1);
        expect(repository.setUsernameCount, 1);
      },
    );
  });

  group('Lebensdauer', () {
    test('ein entsorgter Notifier setzt keinen Zustand mehr', () async {
      // Der klassische Weg zu "state after dispose": der Bildschirm ist weg, das
      // `Future` läuft weiter. Ohne die `ref.mounted`-Prüfungen wirft das
      // folgende `state =`.
      repository.signUpGate = Completer<void>();
      openScreen();

      final pending = submit();
      scope.dispose();
      repository.signUpGate!.complete();

      expect(await pending, isFalse);
      // Die Registrierung selbst hat stattgefunden.
      expect(repository.signUpCount, 1);
    });
  });

  group('Beim Verlassen des Bildschirms', () {
    test('vergisst der Provider seinen Fehler', () async {
      // `isAutoDispose: true` ist keine Deko: ohne das begrüßt die
      // Registrierung den Wiederkehrer mit der roten Box von vorhin.
      // Nachgemessen, die Mutation auf `false` überlebte die Suite.
      openScreen();
      expect(await submit(termsAccepted: false), isFalse);
      expect(state().hasError, isTrue);

      // Das ist, was ein verlassener Bildschirm tut: er hört auf zuzuhören.
      screen.close();
      await pumpEventQueue();

      expect(state().hasError, isFalse);
      expect(state().value, SignupStatus.untouched);
    });
  });
}
