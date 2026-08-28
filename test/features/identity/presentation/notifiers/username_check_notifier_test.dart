import 'dart:async';

import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/username_check_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_auth_repository.dart';

/// Die Username-Prüfung, ohne Widget-Baum.
///
/// ## Warum `testWidgets` und nicht `test`
///
/// Wegen der Zeit. Die Prüfung wartet 500 ms, und ein Test darf nicht wirklich
/// warten (`.claude/rules/tests.md`: "Never use arbitrary sleep-based
/// waiting."). `testWidgets` führt seinen Rumpf in einer `FakeAsync`-Zone aus:
/// jeder [Timer] darin ist ein Scheintimer, und `tester.pump(dauer)` schiebt die
/// Uhr um genau diese Dauer vor. Ein `fakeAsync` aus `package:fake_async` wäre
/// der direktere Weg und ist nicht erlaubt, weil das Paket keine deklarierte
/// Abhängigkeit ist.
///
/// Gepumpt wird ohne Widget: es gibt keines, geprüft wird ein Provider.
void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());
  tearDown(() async => repository.close());

  late ProviderContainer scope;
  late ProviderSubscription<UsernameStatus> field;

  /// Baut den Container und **hält** den Provider am Leben.
  ///
  /// `usernameCheckProvider` ist `isAutoDispose`; ohne Zuhörer entsorgt Riverpod
  /// den Notifier sofort nach dem ersten `read`, und der Test prüfte einen
  /// Provider, den es zwischen zwei Anweisungen nicht mehr gibt. Das Abonnement
  /// ist das, was ein `ref.watch` im Bildschirm tut.
  void openField() {
    scope = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(scope.dispose);
    field = scope.listen(usernameCheckProvider, (_, _) {});
  }

  void type(String value) =>
      scope.read(usernameCheckProvider.notifier).onChanged(value);

  UsernameStatus status() => scope.read(usernameCheckProvider);

  /// Kurz vor Ablauf der Verzögerung.
  Future<void> pumpAlmostDelay(WidgetTester tester) => tester.pump(
    UsernameCheckNotifier.checkDelay - const Duration(milliseconds: 1),
  );

  /// Der restliche Millisekundenschritt, plus die Antwort des Backends.
  Future<void> pumpRest(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 1));

  group('Startzustand', () {
    testWidgets('ist idle', (tester) async {
      openField();

      expect(status(), UsernameStatus.idle);
      expect(repository.checkedUsernames, isEmpty);
    });
  });

  group('Syntax', () {
    testWidgets('ein leeres Feld ist idle und nicht invalid', (tester) async {
      // Bewusste Abweichung von der Quelle: dort passt die Regex nicht auf `''`,
      // also setzt sie `invalid`, und ein unangetastetes oder geleertes Feld
      // trägt ein rotes Kreuz. Das ist eine Falschaussage über eine Eingabe, die
      // der Nutzer noch nicht gemacht hat.
      openField();

      type('stadtfuchs_m');
      type('');

      expect(status(), UsernameStatus.idle);
    });

    testWidgets('leeren bricht die geplante Prüfung ab', (tester) async {
      openField();

      type('stadtfuchs_m');
      type('');
      await tester.pump(UsernameCheckNotifier.checkDelay);

      expect(status(), UsernameStatus.idle);
      expect(repository.checkedUsernames, isEmpty);
    });

    testWidgets('ein einzelnes Zeichen ist invalid, mindestens sind zwei', (
      tester,
    ) async {
      openField();

      type('a');

      expect(status(), UsernameStatus.invalid);
      expect(repository.checkedUsernames, isEmpty);
    });

    testWidgets('verbotene Zeichen sind invalid', (tester) async {
      openField();

      for (final value in <String>[
        'stadt fuchs',
        'stadt.fuchs',
        'stadt-fuchs',
        'stadtfüchse',
        'ab@cd',
      ]) {
        type(value);
        expect(status(), UsernameStatus.invalid, reason: value);
      }
      expect(repository.checkedUsernames, isEmpty);
    });

    testWidgets('mehr als zwanzig Zeichen sind invalid', (tester) async {
      // Über das Feld nicht erreichbar (`maxLength`), über die Regex schon. Der
      // Test hält die Obergrenze fest, damit sie beim Umbau nicht verlorengeht.
      openField();

      type('a' * 20);
      expect(status(), UsernameStatus.checking);

      type('a' * 21);
      expect(status(), UsernameStatus.invalid);
    });

    testWidgets('Ziffern und Unterstrich sind erlaubt', (tester) async {
      openField();

      type('_1');
      expect(status(), UsernameStatus.checking);

      // Bis zum Ende gepumpt, nicht nur bis `checking`: ein Test, der einen
      // laufenden Scheintimer hinterlässt, scheitert an "A Timer is still
      // pending even after the widget tree was disposed". Gemessen, nicht
      // vermutet.
      await tester.pump(UsernameCheckNotifier.checkDelay);
      expect(status(), UsernameStatus.ok);
      expect(repository.checkedUsernames, <String>['_1']);
    });
  });

  group('Die Verzögerung von 500 Millisekunden', () {
    test('ist 500 Millisekunden lang', () {
      // Der Wert selbst, unabhängig von den Helfern oben: die pumpen mit
      // `checkDelay` und wären auch bei einer anderen Zahl grün. Gemessene
      // Wirkung einer Mutation auf `Duration.zero`: 46 Tests fallen, aber aus
      // Folgefehlern, nicht wegen des Wertes. Diese Zeile ist die Aussage.
      expect(UsernameCheckNotifier.checkDelay.inMilliseconds, 500);
    });

    testWidgets('vorher ist der Server nicht gefragt worden, danach genau '
        'einmal', (tester) async {
      openField();

      type('stadtfuchs_m');
      expect(status(), UsernameStatus.checking);

      await pumpAlmostDelay(tester);
      expect(repository.checkedUsernames, isEmpty);
      expect(status(), UsernameStatus.checking);

      await pumpRest(tester);
      expect(repository.checkedUsernames, <String>['stadtfuchs_m']);
      expect(status(), UsernameStatus.ok);
    });

    testWidgets('schnelles Tippen fragt nur den letzten Wert', (tester) async {
      // Das ist der Zweck der Verzögerung: aus zehn Tastendrücken werden nicht
      // zehn Anfragen.
      openField();

      type('st');
      await tester.pump(const Duration(milliseconds: 100));
      type('sta');
      await tester.pump(const Duration(milliseconds: 100));
      type('stadtfuchs_m');
      await tester.pump(UsernameCheckNotifier.checkDelay);

      expect(repository.checkedUsernames, <String>['stadtfuchs_m']);
    });
  });

  group('Antwort des Backends', () {
    testWidgets('vergeben wird taken', (tester) async {
      repository.usernameTaken = true;
      openField();

      type('stadtfuchs_m');
      await tester.pump(UsernameCheckNotifier.checkDelay);

      expect(status(), UsernameStatus.taken);
    });

    testWidgets('frei wird ok', (tester) async {
      repository.usernameTaken = false;
      openField();

      type('stadtfuchs_m');
      await tester.pump(UsernameCheckNotifier.checkDelay);

      expect(status(), UsernameStatus.ok);
    });

    testWidgets('ein Fehlschlag wird idle und blockiert nicht', (tester) async {
      // Übernommen aus der Quelle (`catch { setUsernameStatus('idle') }`): kein
      // Netz darf keine Registrierung verhindern. Über die Eindeutigkeit
      // entscheidet am Ende die Datenbank, nicht der Client.
      repository.checkUsernameFailure = const AuthBackendUnavailable(
        code: '503',
      );
      openField();

      type('stadtfuchs_m');
      await tester.pump(UsernameCheckNotifier.checkDelay);

      expect(status(), UsernameStatus.idle);
      expect(blocksSignup(status()), isFalse);
    });
  });

  group('Der Wettlauf, den die Quelle hat', () {
    testWidgets('ein Wechsel auf einen ungültigen Wert bleibt invalid', (
      tester,
    ) async {
      // Die Quelle ruft `clearTimeout` **nach** dem `return` des
      // Syntaxfehlschlags. Der geplante Check für den alten, gültigen Wert läuft
      // dort weiter ab und setzt danach `ok`: grüner Rahmen, Häkchen, und der
      // Absende-Guard lässt einen ungültigen Namen durch.
      openField();

      type('stadtfuchs_m');
      await pumpAlmostDelay(tester);
      type('stadtfuchs_m!');
      expect(status(), UsernameStatus.invalid);

      // Weit über die Verzögerung hinaus.
      await tester.pump(UsernameCheckNotifier.checkDelay * 3);

      expect(status(), UsernameStatus.invalid);
      expect(repository.checkedUsernames, isEmpty);
    });

    testWidgets('eine Antwort, die schon unterwegs war, wird verworfen', (
      tester,
    ) async {
      // Die zweite Hälfte desselben Wettlaufs: hier hilft kein Abbrechen des
      // Timers mehr, die Anfrage läuft. Dafür steht der Zähler im Notifier.
      repository.checkUsernameGate = Completer<void>();
      openField();

      type('stadtfuchs_m');
      await tester.pump(UsernameCheckNotifier.checkDelay);
      expect(repository.checkedUsernames, <String>['stadtfuchs_m']);
      expect(status(), UsernameStatus.checking);

      type('x');
      expect(status(), UsernameStatus.invalid);

      repository.checkUsernameGate!.complete();
      await tester.pump();

      expect(status(), UsernameStatus.invalid);
    });

    testWidgets('die Antwort auf einen überholten gültigen Wert zählt nicht', (
      tester,
    ) async {
      repository.checkUsernameGate = Completer<void>();
      openField();

      type('erster_wert');
      await tester.pump(UsernameCheckNotifier.checkDelay);
      // Der zweite Wert löst eine zweite Anfrage aus, während die erste hängt.
      type('zweiter_wert');
      await tester.pump(UsernameCheckNotifier.checkDelay);
      expect(repository.checkedUsernames, <String>[
        'erster_wert',
        'zweiter_wert',
      ]);

      repository.usernameTaken = true;
      repository.checkUsernameGate!.complete();
      await tester.pump();

      // Beide Antworten kommen zurück. Gültig ist nur die zweite, und weil
      // beide dasselbe sagen, wäre der Zustand auch ohne den Zähler richtig.
      // Geprüft wird deshalb die Zahl der Aufrufe: es wurde nicht entdoppelt.
      expect(status(), UsernameStatus.taken);
      expect(repository.checkUsernameCount, 2);
    });
  });

  group('Lebensdauer', () {
    testWidgets('das Verlassen des Bildschirms bricht die Prüfung ab', (
      tester,
    ) async {
      openField();

      type('stadtfuchs_m');
      scope.dispose();
      await tester.pump(UsernameCheckNotifier.checkDelay * 2);

      // Ohne `ref.onDispose` bliebe ein Scheintimer offen, und `flutter test`
      // meldete "A Timer is still pending even after the widget tree was
      // disposed".
      expect(repository.checkedUsernames, isEmpty);
    });
  });

  group('blocksSignup', () {
    test('sperrt taken, invalid und checking', () {
      for (final status in <UsernameStatus>[
        UsernameStatus.taken,
        UsernameStatus.invalid,
        UsernameStatus.checking,
      ]) {
        expect(blocksSignup(status), isTrue, reason: status.name);
      }
    });

    test('lässt ok und idle durch', () {
      // `idle` steht auch in der Quelle nicht in der Liste
      // (`screen-auth.jsx:614`). Ein Name, dessen Prüfung nie geantwortet hat,
      // darf abgeschickt werden.
      for (final status in <UsernameStatus>[
        UsernameStatus.ok,
        UsernameStatus.idle,
      ]) {
        expect(blocksSignup(status), isFalse, reason: status.name);
      }
    });
  });

  group('Beim Verlassen des Bildschirms', () {
    // Ein `test` und kein `testWidgets`: hier läuft keine Uhr, ein ungültiger
    // Name setzt seinen Zustand sofort und plant keinen Timer. Und
    // `pumpEventQueue` **hängt** in der `FakeAsync`-Zone von `testWidgets`,
    // gemessen bis zur Zeitüberschreitung.
    test('vergisst der Provider seinen Zustand', () async {
      // `isAutoDispose: true` ist hier die Zusicherung mit der schlimmsten
      // Gegenprobe: ohne sie steht beim Wiederkommen ein **leeres** Feld neben
      // einem ✗, und `blocksSignup` sperrt das Abschicken, bis jemand tippt.
      // Nachgemessen, die Mutation auf `false` überlebte die Suite.
      openField();
      type('nicht gültig!');
      expect(status(), UsernameStatus.invalid);

      // Das ist, was ein verlassener Bildschirm tut: das `ref.watch` endet.
      field.close();
      await pumpEventQueue();

      expect(status(), UsernameStatus.idle);
    });
  });
}
