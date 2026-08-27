import 'dart:async';

import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/login_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_auth_repository.dart';

/// Der Anmeldevorgang, ohne Widget-Baum.
void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());
  tearDown(() async => repository.close());

  late ProviderContainer scope;
  late ProviderSubscription<AsyncValue<void>> screen;

  /// Baut einen Container und **hält** den Provider am Leben.
  ///
  /// Das Abonnement ist nicht Dekoration: `loginProvider` ist `isAutoDispose`,
  /// und ohne einen Zuhörer entsorgt Riverpod den Notifier sofort nach dem
  /// ersten `read`. Ein Test ohne dieses `listen` prüft einen Provider, den es
  /// zwischen zwei Anweisungen nicht mehr gibt: gemessen, der Ladezustand war
  /// danach wieder `AsyncData`. Ein Bildschirm mit `ref.watch` ist genau dieses
  /// Abonnement.
  void openScreen() {
    scope = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(scope.dispose);
    screen = scope.listen(loginProvider, (_, _) {});
  }

  group('Startzustand', () {
    test('ist Daten und nicht Laden', () {
      // Sonst blitzt der gesperrte Knopf beim Öffnen des Bildschirms auf.
      openScreen();

      expect(scope.read(loginProvider).isLoading, isFalse);
      expect(scope.read(loginProvider).hasError, isFalse);
    });
  });

  group('Eingabeprüfung', () {
    test('leere Felder melden LoginInputIncomplete und rufen nichts', () async {
      openScreen();

      final succeeded = await scope
          .read(loginProvider.notifier)
          .signIn(email: '', password: '');

      expect(succeeded, isFalse);
      expect(scope.read(loginProvider).error, isA<LoginInputIncomplete>());
      expect(repository.signInCount, 0);
    });

    test('nur Leerzeichen zählt als leer', () async {
      openScreen();

      await scope
          .read(loginProvider.notifier)
          .signIn(email: '   ', password: '   ');

      expect(scope.read(loginProvider).error, isA<LoginInputIncomplete>());
      expect(repository.signInCount, 0);
    });

    test('eine fehlende Hälfte genügt', () async {
      openScreen();

      await scope
          .read(loginProvider.notifier)
          .signIn(email: 'jan@example.de', password: '');
      expect(scope.read(loginProvider).error, isA<LoginInputIncomplete>());

      await scope
          .read(loginProvider.notifier)
          .signIn(email: '', password: 'geheim');
      expect(scope.read(loginProvider).error, isA<LoginInputIncomplete>());
      expect(repository.signInCount, 0);
    });

    test('keine Formatprüfung der Adresse, wie in der Quelle', () async {
      // `screen-auth.jsx:460` prüft nur auf leer. Eine strengere Prüfung im
      // Client würde Konten aussperren, die der Server akzeptiert.
      openScreen();

      final succeeded = await scope
          .read(loginProvider.notifier)
          .signIn(email: 'keine-adresse', password: 'x');

      expect(succeeded, isTrue);
      expect(repository.lastEmail, 'keine-adresse');
    });
  });

  group('Erfolg', () {
    test('trimmt die Adresse, aber nicht das Passwort', () async {
      // `screen-auth.jsx:465`: `Api.signIn(email.trim(), password)`. Leerzeichen
      // in einem Passwort sind erlaubt und bedeutungstragend.
      openScreen();

      final succeeded = await scope
          .read(loginProvider.notifier)
          .signIn(email: '  jan@example.de  ', password: ' geheim ');

      expect(succeeded, isTrue);
      expect(repository.lastEmail, 'jan@example.de');
      expect(repository.lastPassword, ' geheim ');
      expect(scope.read(loginProvider).hasError, isFalse);
    });
  });

  group('Fehlschlag', () {
    test('eine AuthFailure landet im Fehlerkanal', () async {
      repository.failure = const AuthInvalidCredentials(
        code: 'invalid_credentials',
      );
      openScreen();

      final succeeded = await scope
          .read(loginProvider.notifier)
          .signIn(email: 'jan@example.de', password: 'falsch');

      expect(succeeded, isFalse);
      expect(scope.read(loginProvider).error, isA<AuthInvalidCredentials>());
      // Erwarteter Ausgang, trotzdem `AsyncError`: siehe die Begründung in
      // `auth_failure.dart`.
      expect(scope.read(loginProvider).isLoading, isFalse);
    });

    test('ein neuer Versuch räumt den alten Fehler weg', () async {
      repository.failure = const AuthInvalidCredentials();
      openScreen();
      await scope
          .read(loginProvider.notifier)
          .signIn(email: 'jan@example.de', password: 'falsch');
      expect(scope.read(loginProvider).hasError, isTrue);

      repository.failure = null;
      await scope
          .read(loginProvider.notifier)
          .signIn(email: 'jan@example.de', password: 'richtig');

      expect(scope.read(loginProvider).hasError, isFalse);
    });
  });

  group('Ladezustand', () {
    test('läuft, solange das Repository hängt', () async {
      repository.gate = Completer<void>();
      openScreen();

      final pending = scope
          .read(loginProvider.notifier)
          .signIn(email: 'jan@example.de', password: 'geheim');
      await pumpEventQueue();

      expect(scope.read(loginProvider).isLoading, isTrue);
      // Während des Ladens zeigt der Bildschirm keinen Fehler, genau wie die
      // Quelle, die `setError('')` vor dem Absenden setzt.
      expect(scope.read(loginProvider).hasError, isFalse);

      repository.gate!.complete();
      expect(await pending, isTrue);
      expect(scope.read(loginProvider).isLoading, isFalse);
    });

    test('ein zweiter Aufruf während des Ladens startet nichts', () async {
      repository.gate = Completer<void>();
      openScreen();
      final notifier = scope.read(loginProvider.notifier);

      final first = notifier.signIn(
        email: 'jan@example.de',
        password: 'geheim',
      );
      await pumpEventQueue();
      final second = await notifier.signIn(
        email: 'jan@example.de',
        password: 'geheim',
      );

      expect(second, isFalse);
      expect(repository.signInCount, 1);
      repository.gate!.complete();
      await first;
    });
  });

  group('Wegnavigieren während der Anmeldung', () {
    test('das Entsorgen des Notifiers wirft nicht', () async {
      // Der Provider ist `isAutoDispose`, ein verlassener Bildschirm entsorgt
      // ihn also, während das `Future` noch läuft. Ohne die
      // `ref.mounted`-Prüfungen wirft das folgende `state =`, und zwar
      // abgekoppelt: der Test wird durch den unbehandelten Fehler rot.
      repository.gate = Completer<void>();
      openScreen();
      final notifier = scope.read(loginProvider.notifier);

      final pending = notifier.signIn(
        email: 'jan@example.de',
        password: 'geheim',
      );
      await pumpEventQueue();

      // Das ist, was ein verlassener Bildschirm tut: er hört auf zuzuhören.
      screen.close();
      await pumpEventQueue();

      repository.gate!.complete();
      expect(await pending, isFalse);
      // Die Anmeldung selbst hat trotzdem stattgefunden.
      expect(repository.signInCount, 1);
    });

    test('ein Fehlschlag nach dem Entsorgen wirft auch nicht', () async {
      repository
        ..gate = Completer<void>()
        ..failure = const AuthBackendUnavailable();
      openScreen();
      final notifier = scope.read(loginProvider.notifier);

      final pending = notifier.signIn(
        email: 'jan@example.de',
        password: 'geheim',
      );
      await pumpEventQueue();
      screen.close();
      await pumpEventQueue();

      repository.gate!.complete();
      expect(await pending, isFalse);
    });
  });
}
