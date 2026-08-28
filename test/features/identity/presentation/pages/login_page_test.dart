import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:fact_app/features/identity/presentation/pages/login_page.dart';
import 'package:fact_app/features/identity/presentation/pages/signup_page.dart';
import 'package:fact_app/features/identity/presentation/pages/splash_page.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_checkbox.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_field.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_header.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';
import '../../fake_auth_repository.dart';

/// Die Anmeldung als Bildschirm.
///
/// Gepumpt wird die ganze `FactApp` und dorthin **navigiert**, statt `LoginPage`
/// allein zu bauen: der Bildschirm hat drei Ausgänge und einen Zurück-Weg, und
/// Navigation ist ohne Router nicht prüfbar. Der Weg über den Startbildschirm
/// prüft zusätzlich, dass dessen Knopf wirklich hier landet.
///
/// "Bewegung reduzieren" ist Vorbedingung, nicht Gegenstand: die Pins des
/// Startbildschirms animieren endlos, `pumpAndSettle` käme sonst nie zurück.
void main() {
  // Ohne echte Schriften ist jede Glyphe ein Quadrat der Schriftgröße, und die
  // Überlaufprüfung unten würde ein Layout messen, das es nicht gibt.
  setUpAll(loadAppFonts);

  late InMemoryFirstLaunchStore firstLaunch;
  late FakeAuthRepository auth;

  setUp(() {
    firstLaunch = InMemoryFirstLaunchStore();
    auth = FakeAuthRepository();
  });

  tearDown(() async {
    await auth.close();
  });

  /// Der Bildschirm ist mit 390 x 844 gebaut, dem Rahmenmaß der PWA
  /// (`chrome.jsx:135-136`).
  void useDeviceSurface(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Über den `PlatformDispatcher` und **nicht** über eine eigene `MediaQuery`:
  /// die läge unter der, die das `View` anlegt, und setzte `size` und `padding`
  /// auf null. Siehe die Begründung in `splash_page_test.dart`.
  void useReducedMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  void useTextScale(WidgetTester tester, double scale) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Widget app({required AppLanguage language}) {
    return ProviderScope(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(language),
        ),
        firstLaunchStoreProvider.overrideWithValue(firstLaunch),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const FactApp(),
    );
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Startbildschirm, dann der Knopf "Anmelden".
  Future<void> pumpLogin(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.de,
  }) async {
    useDeviceSurface(tester);
    useReducedMotion(tester);
    await tester.pumpWidget(app(language: language));
    await tester.pumpAndSettle();
    await tapText(tester, language == AppLanguage.de ? 'Anmelden' : 'Sign in');
    expect(find.byType(LoginPage), findsOneWidget);
  }

  Finder inputOf(int index) => find.descendant(
    of: find.byType(AuthField).at(index),
    matching: find.byType(TextField),
  );

  Future<void> fillCredentials(
    WidgetTester tester, {
    String email = 'jan@example.de',
    String password = 'geheim',
  }) async {
    await tester.enterText(inputOf(0), email);
    await tester.enterText(inputOf(1), password);
    await tester.pumpAndSettle();
  }

  group('Der Weg hierher', () {
    testWidgets('der Startbildschirm öffnet die Anmeldung, nicht die '
        'Registrierung', (tester) async {
      await pumpLogin(tester);

      // Beide Richtungen: ohne die zweite Zeile bleibt ein vertauschtes Ziel
      // unentdeckt.
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SignupPage), findsNothing);
    });

    testWidgets('der Zurück-Pfeil führt auf den Startbildschirm', (
      tester,
    ) async {
      await pumpLogin(tester);

      // Der Knopf und nicht die Kopfzeile: deren Mitte liegt zwischen den
      // beiden Elementen und trifft nichts.
      await tester.tap(
        find.descendant(
          of: find.byType(AuthHeader),
          matching: find.byType(SplashPressable),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      // Die Merkung darf dabei **nicht** gesetzt worden sein: nur eine
      // erfolgreiche Anmeldung setzt sie.
      expect(firstLaunch.hasLaunched(), isFalse);
    });

    testWidgets('"Konto erstellen" wechselt zur Registrierung', (tester) async {
      await pumpLogin(tester);

      await tapText(tester, 'Konto erstellen');

      expect(find.byType(SignupPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });
  });

  group('Texte', () {
    testWidgets('zeigt die Texte der Quelle auf Deutsch', (tester) async {
      await pumpLogin(tester);

      for (final text in <String>[
        // Hero. Eyebrow und Labels erscheinen großgeschrieben:
        // `text-transform: uppercase` steht am Element, nicht in der
        // Übersetzung.
        'WILLKOMMEN ZURÜCK',
        'Wieder da?',
        'Mach weiter, wo du aufgehört hast.',
        // Formular.
        'E-MAIL',
        'name@beispiel.de',
        'PASSWORT',
        '••••••••',
        'ZEIGEN',
        'Angemeldet bleiben',
        'Anmelden →',
        'ODER',
        'Mit Apple',
        'Mit Google',
        // Fußzeile.
        'Noch kein Konto?',
        'Konto erstellen',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('auf Englisch stehen die englischen Texte', (tester) async {
      await pumpLogin(tester, language: AppLanguage.en);

      for (final text in <String>[
        'WELCOME BACK',
        'Back again?',
        'Continue where you left off.',
        'E-MAIL',
        'name@example.com',
        'PASSWORD',
        'SHOW',
        'Stay signed in',
        'Sign in →',
        'With Apple',
        'With Google',
        'No account yet?',
        'Create account',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Angemeldet bleiben'), findsNothing);
    });

    testWidgets('der Trenner steht hartcodiert auf Deutsch', (tester) async {
      // `screen-auth.jsx:127` schreibt "oder" direkt ins Markup, es gibt dafür
      // keinen i18n-Schlüssel. Auf Englisch steht deshalb dasselbe Wort, genau
      // wie in der PWA.
      await pumpLogin(tester, language: AppLanguage.en);

      expect(find.text('ODER'), findsOneWidget);
    });

    testWidgets('es gibt keinen Knopf für den Passwort-Reset', (tester) async {
      // Bewusste Auslassung, siehe `LoginPage`: das Ziel des Rücksetz-Links
      // wäre eine neue öffentliche Vertragsfläche, und der PKCE-Ablauf macht
      // einen im Browser geöffneten Link unbrauchbar. Ein Knopf, der nichts
      // tut, wäre schlechter als keiner.
      await pumpLogin(tester);

      expect(find.text('Vergessen?'), findsNothing);
      expect(find.text('Wird gesendet…'), findsNothing);
    });
  });

  group('Eingabe', () {
    testWidgets('leere Felder melden den Pflichttext und rufen nichts auf', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tapText(tester, 'Anmelden →');

      expect(find.text('E-Mail und Passwort erforderlich.'), findsOneWidget);
      expect(auth.signInCount, 0);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('der Sichtbarkeitsschalter kippt Text und Verdeckung', (
      tester,
    ) async {
      await pumpLogin(tester);

      TextField passwordField() => tester.widget<TextField>(inputOf(1));
      expect(passwordField().obscureText, isTrue);

      await tapText(tester, 'ZEIGEN');

      expect(find.text('VERBERGEN'), findsOneWidget);
      expect(find.text('ZEIGEN'), findsNothing);
      expect(passwordField().obscureText, isFalse);
    });

    testWidgets('"Angemeldet bleiben" ist gesetzt und lässt sich kippen', (
      tester,
    ) async {
      // Parität ohne Wirkung: `stayIn` wird in der Quelle gesetzt und
      // **nirgends gelesen**. Geprüft wird deshalb nur, dass das Kästchen sich
      // wie ein Kästchen verhält.
      await pumpLogin(tester);
      AuthCheckbox checkbox() =>
          tester.widget<AuthCheckbox>(find.byType(AuthCheckbox));
      expect(checkbox().checked, isTrue);

      await tapText(tester, 'Angemeldet bleiben');

      expect(checkbox().checked, isFalse);
    });
  });

  group('Anmelden', () {
    testWidgets('Erfolg merkt den Start und landet auf der Karte', (
      tester,
    ) async {
      await pumpLogin(tester);
      await fillCredentials(tester);
      expect(firstLaunch.hasLaunched(), isFalse);

      await tapText(tester, 'Anmelden →');

      expect(auth.signInCount, 1);
      expect(firstLaunch.hasLaunched(), isTrue);
      expect(find.byType(MapPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('die beiden Felder gehen unvertauscht ans Repository', (
      tester,
    ) async {
      // Nachgemessen mit einer Mutation: `signIn(email: _password.text,
      // password: _email.text)` überlebte die ganze Suite. Der Bildschirm
      // navigierte weiter auf die Karte, und kein Test sah hin, **womit**
      // angemeldet wurde. Für die Registrierung war diese Stelle schon dicht
      // (`lastSignUpEmail` und `lastSignUpName`), für die Anmeldung nicht.
      //
      // Deshalb zwei Werte, die sich nicht verwechseln lassen. Das Passwort
      // trägt zusätzlich ein Leerzeichen: die Adresse kommt getrimmt an, das
      // Passwort **ungetrimmt**, wie in `screen-auth.jsx:465`.
      await pumpLogin(tester);
      await fillCredentials(
        tester,
        email: '  anmeldung@example.de  ',
        password: 'geheimes Wort ',
      );

      await tapText(tester, 'Anmelden →');

      expect(auth.lastEmail, 'anmeldung@example.de');
      expect(auth.lastPassword, 'geheimes Wort ');
    });

    testWidgets('nach Erfolg navigiert der Bildschirm selbst weg', (
      tester,
    ) async {
      // Der Test oben allein wäre schwach: bei offenem Erstlauf schickt die
      // Weiche nach dem Setzen der Merkung ohnehin auf die Karte, ein fehlendes
      // `go` fiele also nicht auf. Nachgemessen mit einer Mutation: ohne die
      // Navigation blieb `LoginPage` stehen.
      //
      // Hier ist der Erstlauf **erledigt**, die Anmeldung liegt über der Karte,
      // und die Weiche hat keinen Grund einzugreifen: `matchedLocation` ist
      // `/map`. Nur der Bildschirm selbst kann diesen Stapel abbauen.
      firstLaunch = InMemoryFirstLaunchStore(hasLaunched: true);
      useDeviceSurface(tester);
      useReducedMotion(tester);
      await tester.pumpWidget(app(language: AppLanguage.de));
      await tester.pumpAndSettle();
      expect(find.byType(MapPage), findsOneWidget);

      unawaited(
        const LoginRoute().push<void>(tester.element(find.byType(MapPage))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      await fillCredentials(tester);
      await tapText(tester, 'Anmelden →');

      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(MapPage), findsOneWidget);
    });

    testWidgets('falsche Zugangsdaten zeigen den Text der Quelle', (
      tester,
    ) async {
      auth.failure = const AuthInvalidCredentials(code: 'invalid_credentials');
      await pumpLogin(tester);
      await fillCredentials(tester, password: 'falsch');

      await tapText(tester, 'Anmelden →');

      expect(find.text('E-Mail oder Passwort falsch.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(firstLaunch.hasLaunched(), isFalse);
    });

    testWidgets('ein unbestätigtes Konto bekommt seinen eigenen Text', (
      tester,
    ) async {
      auth.failure = const AuthEmailNotConfirmed(code: 'email_not_confirmed');
      await pumpLogin(tester);
      await fillCredentials(tester);

      await tapText(tester, 'Anmelden →');

      expect(find.text('Bitte zuerst E-Mail bestätigen.'), findsOneWidget);
    });

    testWidgets('ein Backend-Fehler bleibt beim Sammeltext', (tester) async {
      // Bewusste Abweichung: die PWA zeigt hier die rohe englische Meldung des
      // Backends (`screen-auth.jsx:478`). `cross-cutting-concerns.md` verbietet
      // das, und `AuthFailure` trägt die Meldung gar nicht mit.
      auth.failure = const AuthBackendUnavailable(code: '503');
      await pumpLogin(tester);
      await fillCredentials(tester);

      await tapText(tester, 'Anmelden →');

      expect(find.text('Fehler beim Anmelden.'), findsOneWidget);
      expect(find.textContaining('503'), findsNothing);
    });

    testWidgets('der Ladezustand sperrt nur den Knopf', (tester) async {
      auth.gate = Completer<void>();
      await pumpLogin(tester);
      await fillCredentials(tester);

      await tester.tap(find.text('Anmelden →'));
      await tester.pump();

      // Beschriftung gewechselt, Knopf gesperrt.
      expect(find.text('Lädt…'), findsOneWidget);
      expect(find.text('Anmelden →'), findsNothing);
      await tester.tap(find.text('Lädt…'));
      await tester.pump();
      expect(auth.signInCount, 1);

      // Der Rest des Bildschirms bleibt bedienbar, es gibt keinen Spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AuthHeader), findsOneWidget);

      auth.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MapPage), findsOneWidget);
    });

    testWidgets('Wegnavigieren während der Anmeldung erzeugt keinen Fehler', (
      tester,
    ) async {
      // Der klassische Weg zu "setState after dispose": der Bildschirm ist weg,
      // das `Future` läuft weiter. Ohne die `mounted`-Prüfungen in `LoginPage`
      // und die `ref.mounted`-Prüfungen in `LoginNotifier` scheitert dieser
      // Test mit einem Fehler aus der Zone.
      auth.gate = Completer<void>();
      await pumpLogin(tester);
      await fillCredentials(tester);
      await tester.tap(find.text('Anmelden →'));
      await tester.pump();

      await tapText(tester, 'Konto erstellen');
      expect(find.byType(SignupPage), findsOneWidget);

      auth.gate!.complete();
      await tester.pumpAndSettle();

      // Die Anmeldung hat stattgefunden, die Merkung aber nicht: dafür hätte der
      // Bildschirm noch da sein müssen.
      expect(auth.signInCount, 1);
      expect(firstLaunch.hasLaunched(), isFalse);
      // Stattdessen greift die Weiche. Gemessen und erklärt: der
      // Startbildschirm hat die Anmeldung mit `push` geöffnet, die
      // **matchedLocation** ist deshalb weiter `/splash`, und wer angemeldet ist,
      // hat dort nichts zu suchen (`app.jsx:69`). Der Nutzer landet also auf der
      // Karte statt in der Registrierung. Das ist eine Folge der Weiche, keine
      // Navigation dieses Bildschirms, und es steht hier, damit niemand es für
      // einen Zufall hält.
      expect(find.byType(MapPage), findsOneWidget);
    });

    testWidgets('die beiden Fremdanmeldungen sind abgeschaltet', (
      tester,
    ) async {
      // Parität mit `disabled` und `title` der Quelle. Der Tooltip wandert in
      // die Semantik, weil ein `title` auf einem Touchgerät nie erscheint.
      final handle = tester.ensureSemantics();
      await pumpLogin(tester);

      for (final label in <String>['Mit Apple', 'Mit Google']) {
        final data = tester.getSemantics(find.text(label)).getSemanticsData();
        expect(data.flagsCollection.isEnabled, Tristate.isFalse, reason: label);
        expect(data.tooltip, 'Demnächst verfügbar', reason: label);
      }
      handle.dispose();
    });
  });

  group('Maße', () {
    testWidgets('läuft bei doppelter Systemschrift nicht über', (tester) async {
      // Androids Maximum. Gemessen mit echten Schriften, siehe
      // `test/support/app_fonts.dart`: ohne die wäre das Ergebnis wertlos.
      useTextScale(tester, 2);

      await pumpLogin(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('auf einem kurzen Bildschirm bleibt alles erreichbar', (
      tester,
    ) async {
      useReducedMotion(tester);
      tester.view
        ..physicalSize = const Size(320 * 3, 480 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(language: AppLanguage.de));
      await tester.pumpAndSettle();
      await tapText(tester, 'Anmelden');

      // Der Formularblock scrollt, die Fußzeile bleibt stehen. Ohne den
      // Scrollbereich wäre das ein Overflow-Fehler.
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Mit Google'));
      await tester.pumpAndSettle();
      expect(find.text('Noch kein Konto?'), findsOneWidget);
    });
  });
}
