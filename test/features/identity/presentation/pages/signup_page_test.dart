import 'dart:async';

import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/identity/domain/failures/auth_failure.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/username_check_notifier.dart';
import 'package:fact_app/features/identity/presentation/notifiers/username_suggestion.dart';
import 'package:fact_app/features/identity/presentation/pages/login_page.dart';
import 'package:fact_app/features/identity/presentation/pages/signup_page.dart';
import 'package:fact_app/features/identity/presentation/pages/splash_page.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_checkbox.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_error_box.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_field.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_header.dart';
import 'package:fact_app/features/identity/presentation/widgets/auth_notice_box.dart';
import 'package:fact_app/features/identity/presentation/widgets/city_picker.dart';
import 'package:fact_app/features/identity/presentation/widgets/password_strength_meter.dart';
import 'package:fact_app/features/identity/presentation/widgets/signup_progress_bar.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:fact_app/features/identity/presentation/widgets/username_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';
import '../../fake_auth_repository.dart';

/// Die Registrierung als Bildschirm.
///
/// Gepumpt wird die ganze `FactApp` und dorthin **navigiert**, wie bei der
/// Anmeldung: der Bildschirm hat einen Zurück-Weg, einen Wechsel zur Anmeldung
/// und einen Ausgang auf die Karte, und Navigation ist ohne Router nicht
/// prüfbar.
///
/// ## Zwei Werkzeuge, die hier wichtiger sind als sonst
///
/// **Echte Schriften** ([loadAppFonts]) aus `setUpAll`. Ohne sie ist jede Glyphe
/// ein Quadrat der Schriftgröße, und die Überlaufprüfungen unten messen ein
/// Layout, das es auf keinem Gerät gibt.
///
/// **`tester.pump` mit einer Dauer statt `pumpAndSettle`**, sobald die
/// Username-Prüfung im Spiel ist. `pumpAndSettle` schiebt die Uhr in
/// 100-Millisekunden-Schritten vor, solange irgendeine Animation läuft; es würde
/// die Verzögerung von 500 ms also unkontrolliert anschieben. Wer prüfen will,
/// dass vor Ablauf **nicht** gefragt wurde, darf nicht settlen.
void main() {
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
  void useDeviceSurface(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Über den `PlatformDispatcher`, nicht über eine eigene `MediaQuery`: die läge
  /// unter der, die das `View` anlegt, und setzte `size` und `padding` auf null.
  /// Siehe die Begründung in `splash_page_test.dart`.
  void useReducedMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  void useTextScale(WidgetTester tester, double scale) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// Der Zufall des Vorschlags ist festgelegt: Index 6 ist `gold`.
  Widget app({AppLanguage language = AppLanguage.de, int suggestionIndex = 6}) {
    return ProviderScope(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(language),
        ),
        firstLaunchStoreProvider.overrideWithValue(firstLaunch),
        authRepositoryProvider.overrideWithValue(auth),
        randomIndexProvider.overrideWithValue((_) => suggestionIndex),
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

  /// Startbildschirm, dann der Knopf "Jetzt registrieren".
  Future<void> pumpSignup(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.de,
    int suggestionIndex = 6,
    Size size = const Size(390, 844),
  }) async {
    useDeviceSurface(tester, size: size);
    useReducedMotion(tester);
    await tester.pumpWidget(
      app(language: language, suggestionIndex: suggestionIndex),
    );
    await tester.pumpAndSettle();
    await tapText(
      tester,
      language == AppLanguage.de ? 'Jetzt registrieren →' : 'Create account →',
    );
    expect(find.byType(SignupPage), findsOneWidget);
  }

  Finder usernameInput() => find.descendant(
    of: find.byType(UsernameField),
    matching: find.byType(TextField),
  );

  Finder cityQueryInput() => find.descendant(
    of: find.byType(CityPicker),
    matching: find.byType(TextField),
  );

  Finder authFieldInput(int index) => find.descendant(
    of: find.byType(AuthField).at(index),
    matching: find.byType(TextField),
  );

  Finder usernameBadge(String text) => find.descendant(
    of: find.byType(UsernameField),
    matching: find.text(text),
  );

  /// Die Rahmenfarbe des Username-Feldes, wie sie gezeichnet wird.
  Color usernameBorderColor(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(UsernameField),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    return decoration.border!.top.color;
  }

  /// Tippt einen Username und lässt die Prüfung ablaufen.
  Future<void> enterUsername(WidgetTester tester, String value) async {
    await tester.enterText(usernameInput(), value);
    await tester.pump(UsernameCheckNotifier.checkDelay);
  }

  /// Füllt das Formular vollständig aus.
  Future<void> fillForm(
    WidgetTester tester, {
    String username = 'stadtfuchs_m',
    String email = 'jan@example.de',
    String password = 'geheim',
    bool acceptTerms = true,
  }) async {
    await enterUsername(tester, username);
    await tester.enterText(authFieldInput(0), email);
    await tester.enterText(authFieldInput(1), password);
    await tester.pump();
    if (acceptTerms) {
      await tester.ensureVisible(find.byType(AuthCheckbox));
      await tester.pump();
      await tester.tap(find.byType(AuthCheckbox));
      await tester.pump();
    }
  }

  Future<void> submit(WidgetTester tester) =>
      tapText(tester, 'Jetzt registrieren →');

  group('Der Weg hierher', () {
    testWidgets('der Startbildschirm öffnet die Registrierung, nicht die '
        'Anmeldung', (tester) async {
      await pumpSignup(tester);

      // Beide Richtungen: ohne die zweite Zeile bleibt ein vertauschtes Ziel
      // unentdeckt.
      expect(find.byType(SignupPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('der Zurück-Pfeil führt auf den Startbildschirm', (
      tester,
    ) async {
      await pumpSignup(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(AuthHeader),
          matching: find.byType(SplashPressable),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(SignupPage), findsNothing);
      // Die Merkung darf dabei **nicht** gesetzt worden sein.
      expect(firstLaunch.hasLaunched(), isFalse);
    });

    testWidgets('"Anmelden" in der Fußzeile wechselt zur Anmeldung', (
      tester,
    ) async {
      await pumpSignup(tester);

      await tapText(tester, 'Anmelden');

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SignupPage), findsNothing);
    });
  });

  group('Texte', () {
    testWidgets('zeigt die Texte der Quelle auf Deutsch', (tester) async {
      await pumpSignup(tester);

      for (final text in <String>[
        // Kopfzeile mit Titel, anders als bei der Anmeldung.
        'KONTO ERSTELLEN',
        // Hero.
        '+50 XP BEIM ERSTEN LOGIN',
        'Leg los.',
        'Dein Konto ist kostenlos und deine Fakten bleiben für immer.',
        // Username-Block.
        'Username',
        'z.B. stadtfuchs_m',
        'Sichtbar in der Rangliste — später änderbar',
        // Formular.
        'E-MAIL',
        'name@beispiel.de',
        'PASSWORT',
        'Mind. 6 Zeichen',
        'ZEIGEN',
        // Stadt-Picker.
        'HEIMATSTADT · OPTIONAL',
        'Stadt suchen…',
        'Aktiv · +50 XP Bonus',
        '73 Fakten',
        // Stadtname und Ländercode sind **ein** Text mit zwei Stilen, wie in der
        // Quelle. `find.text` vergleicht deshalb die zusammengesetzte Fassung.
        'München DE',
        'Rom IT',
        'Passau DE',
        'Regensburg DE',
        // Einwilligung, Knopf, Trenner, Fremdanmeldungen, Fußzeile.
        'ODER',
        'Mit Apple',
        'Mit Google',
        'Bereits Mitglied?',
        'Anmelden',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // Der Primärknopf trägt denselben Text wie der Knopf, der hierher
      // geführt hat.
      expect(find.text('Jetzt registrieren →'), findsOneWidget);
    });

    testWidgets('die Einwilligung setzt vier Bausteine und einen Punkt '
        'zusammen', (tester) async {
      await pumpSignup(tester);

      final checkbox = tester.widget<AuthCheckbox>(find.byType(AuthCheckbox));
      expect(
        checkbox.label,
        'Ich stimme den Nutzungsbedingungen und der Datenschutzerklärung.',
      );
      // Zwei rote, fette Teile, aber **keine Links**: die Quelle hat dort keinen
      // eigenen `onClick`, ein Tap kippt nur das Kästchen.
      expect(checkbox.labelSpans, hasLength(5));
    });

    testWidgets('auf Englisch stehen die englischen Texte', (tester) async {
      await pumpSignup(tester, language: AppLanguage.en);

      for (final text in <String>[
        'CREATE ACCOUNT',
        '+50 XP ON FIRST LOGIN',
        'Get started.',
        'Your account is free and your facts stay forever.',
        'e.g. cityfox_m',
        'Visible in the leaderboard — changeable later',
        'Min. 6 characters',
        'HOME CITY · OPTIONAL',
        'Search city…',
        'Active · +50 XP bonus',
        '73 facts',
        'Already a member?',
        'Sign in',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Leg los.'), findsNothing);
    });

    testWidgets('die hartcodierten deutschen Texte bleiben auf Englisch '
        'deutsch', (tester) async {
      // Die Zusicherung gegen ein versehentliches "Verbessern": Trenner,
      // Stärke-Beschriftung und Vorschlagsliste haben in der Quelle keinen
      // i18n-Schlüssel.
      await pumpSignup(tester, language: AppLanguage.en);

      expect(find.text('ODER'), findsOneWidget);

      await tester.enterText(authFieldInput(1), 'abcdefgA1!');
      await tester.pump();
      expect(find.text('STARK · +5 XP BONUS'), findsOneWidget);

      // Auch die Städteliste ist hartcodiert: der Eintrag heißt "Rom", nicht
      // "Rome", und der Vorschlag entsteht aus deutschen Wörtern.
      await tapText(tester, 'Rom IT');
      expect(
        tester.widget<TextField>(usernameInput()).controller!.text,
        'goldfuchs_r',
      );
    });

    testWidgets('die Fortschrittsleiste hat zwei Segmente und keinen '
        'Zustand', (tester) async {
      // Beide Segmente sind statisch: das erste immer rot, das zweite immer
      // leer. Es gibt keinen zweiten Schritt.
      await pumpSignup(tester);

      final colors = FactColors.light;
      final segments = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(SignupProgressBar),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => (box.decoration as BoxDecoration).color)
          .toList();

      expect(segments, <Color>[colors.red, colors.surface3]);
    });
  });

  group('Das Username-Feld', () {
    testWidgets('beginnt ohne Abzeichen und mit neutralem Rahmen', (
      tester,
    ) async {
      await pumpSignup(tester);

      expect(usernameBorderColor(tester), FactColors.light.border2);
      expect(usernameBadge('✓'), findsNothing);
      expect(usernameBadge('✗'), findsNothing);
      expect(usernameBadge('...'), findsNothing);
      expect(usernameBadge('Bereits vergeben'), findsNothing);
    });

    testWidgets('checking zeigt drei Punkte in Ocker, ohne Farbwechsel am '
        'Rahmen', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(usernameInput(), 'stadtfuchs_m');
      await tester.pump();

      expect(usernameBadge('...'), findsOneWidget);
      expect(
        tester.widget<Text>(usernameBadge('...')).style!.color,
        UsernameField.checkingColor,
      );
      expect(usernameBorderColor(tester), FactColors.light.border2);

      // Aufräumen: ein offener Scheintimer lässt den Test scheitern.
      await tester.pump(UsernameCheckNotifier.checkDelay);
    });

    testWidgets('ok zeigt die Glyphe und einen türkisen Rahmen', (
      tester,
    ) async {
      await pumpSignup(tester);

      await enterUsername(tester, 'stadtfuchs_m');

      // Die Glyphe ist hartcodiert. `username.available` ("Verfügbar")
      // **existiert** als Schlüssel und wird in der PWA nicht benutzt.
      expect(usernameBadge('✓'), findsOneWidget);
      expect(usernameBadge('Verfügbar'), findsNothing);
      expect(usernameBorderColor(tester), UsernameField.okColor);
    });

    testWidgets('taken zeigt den übersetzten Text und einen roten Rahmen', (
      tester,
    ) async {
      auth.usernameTaken = true;
      await pumpSignup(tester);

      await enterUsername(tester, 'stadtfuchs_m');

      expect(usernameBadge('Bereits vergeben'), findsOneWidget);
      expect(usernameBorderColor(tester), UsernameField.errorColor);
    });

    testWidgets('invalid zeigt die Glyphe und einen roten Rahmen', (
      tester,
    ) async {
      await pumpSignup(tester);

      await tester.enterText(usernameInput(), 'stadt fuchs');
      await tester.pump();

      // Auch hier eine Glyphe: `username.invalid` ("Nur Buchstaben, Ziffern und
      // _ (max. 20)") existiert und wird in der PWA nicht benutzt.
      expect(usernameBadge('✗'), findsOneWidget);
      expect(
        usernameBadge('Nur Buchstaben, Ziffern und _ (max. 20)'),
        findsNothing,
      );
      expect(usernameBorderColor(tester), UsernameField.errorColor);
      expect(auth.checkedUsernames, isEmpty);
    });

    testWidgets('ein geleertes Feld hat kein Abzeichen', (tester) async {
      // Bewusste Abweichung: die Quelle setzt hier `invalid` und zeigt ein rotes
      // Kreuz an einem leeren Feld.
      await pumpSignup(tester);

      await enterUsername(tester, 'stadtfuchs_m');
      expect(usernameBadge('✓'), findsOneWidget);

      await tester.enterText(usernameInput(), '');
      await tester.pump();

      expect(usernameBadge('✗'), findsNothing);
      expect(usernameBadge('✓'), findsNothing);
      expect(usernameBorderColor(tester), FactColors.light.border2);
    });

    testWidgets('vor Ablauf der Verzögerung ist der Server nicht gefragt', (
      tester,
    ) async {
      await pumpSignup(tester);

      await tester.enterText(usernameInput(), 'stadtfuchs_m');
      await tester.pump(
        UsernameCheckNotifier.checkDelay - const Duration(milliseconds: 1),
      );
      expect(auth.checkedUsernames, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(auth.checkedUsernames, <String>['stadtfuchs_m']);
    });

    testWidgets('das Feld nimmt höchstens zwanzig Zeichen', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(usernameInput(), 'a' * 30);
      await tester.pump();

      expect(
        tester.widget<TextField>(usernameInput()).controller!.text,
        'a' * 20,
      );
      await tester.pump(UsernameCheckNotifier.checkDelay);
    });
  });

  group('Das Passwortfeld', () {
    testWidgets('ist verdeckt, und "ZEIGEN" kippt Text und Verdeckung', (
      tester,
    ) async {
      // Die Anmeldung hat diesen Test seit Schritt 9, die Registrierung nicht.
      // Nachgemessen: `obscureText: _passwordVisible` statt `!_passwordVisible`
      // überlebte die Suite. Der Nutzer sähe sein Passwort von Anfang an im
      // Klartext, und "ZEIGEN" würde es verstecken.
      await pumpSignup(tester);

      TextField passwordField() => tester.widget<TextField>(authFieldInput(1));
      expect(passwordField().obscureText, isTrue);

      await tapText(tester, 'ZEIGEN');

      expect(find.text('VERBERGEN'), findsOneWidget);
      expect(find.text('ZEIGEN'), findsNothing);
      expect(passwordField().obscureText, isFalse);

      // Und zurück. Ohne diesen Teil bliebe eine Verdeckung unentdeckt, die nur
      // in eine Richtung schaltet.
      await tapText(tester, 'VERBERGEN');

      expect(find.text('ZEIGEN'), findsOneWidget);
      expect(passwordField().obscureText, isTrue);
    });

    testWidgets('kündigt dem Passwortspeicher ein neues Passwort an', (
      tester,
    ) async {
      // `autoComplete="new-password"` in der Quelle. Mit `AutofillHints.password`
      // setzt ein Passwortspeicher das **bestehende** Passwort ein, statt ein
      // neues vorzuschlagen: genau das falsche Verhalten in einer
      // Registrierung. Nachgemessen, die Vertauschung überlebte die Suite.
      await pumpSignup(tester);

      expect(
        tester.widget<TextField>(authFieldInput(1)).autofillHints,
        <String>[AutofillHints.newPassword],
      );
    });

    testWidgets('das E-Mail-Feld öffnet die E-Mail-Tastatur', (tester) async {
      // Ohne `TextInputType.emailAddress` fehlen @ und Punkt auf der ersten
      // Tastaturebene. Auch das überlebte als Mutation.
      await pumpSignup(tester);

      final email = tester.widget<TextField>(authFieldInput(0));
      expect(email.keyboardType, TextInputType.emailAddress);
      expect(email.autofillHints, <String>[AutofillHints.email]);
    });
  });

  group('Die Passwort-Stärke', () {
    testWidgets('erscheint erst mit einer Eingabe', (tester) async {
      await pumpSignup(tester);

      expect(find.byType(PasswordStrengthMeter), findsNothing);

      await tester.enterText(authFieldInput(1), 'a');
      await tester.pump();

      expect(find.byType(PasswordStrengthMeter), findsOneWidget);
    });

    testWidgets('zeigt die fünf Stufen mit ihren Texten', (tester) async {
      await pumpSignup(tester);

      const cases = <String, String>{
        'a': 'ZU SCHWACH',
        'abcdefgh': 'SCHWACH',
        'abcdefgA': 'OKAY',
        'abcdefgA1': 'GUT · +5 XP BONUS',
        'abcdefgA1!': 'STARK · +5 XP BONUS',
      };
      for (final entry in cases.entries) {
        await tester.enterText(authFieldInput(1), entry.key);
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      }
    });

    testWidgets('ab Stufe 3 wird die Beschriftung grün', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(authFieldInput(1), 'abcdefgA');
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('OKAY')).style!.color,
        FactColors.light.ink3,
      );

      await tester.enterText(authFieldInput(1), 'abcdefgA1');
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('GUT · +5 XP BONUS')).style!.color,
        PasswordStrengthMeter.strongColor,
      );
    });

    testWidgets('"Zu schwach" blockiert die Registrierung nicht', (
      tester,
    ) async {
      await pumpSignup(tester);

      await fillForm(tester, password: 'x');
      expect(find.text('ZU SCHWACH'), findsOneWidget);
      await submit(tester);

      expect(auth.signUpCount, 1);
      expect(find.byType(MapPage), findsOneWidget);
    });
  });

  group('Der Stadt-Picker', () {
    testWidgets('München ist vorbelegt', (tester) async {
      await pumpSignup(tester);

      // Genau eine Auswahlmarke, und sie steht bei München.
      final marks = find.descendant(
        of: find.byType(CityPicker),
        matching: find.text('✓'),
      );
      expect(marks, findsOneWidget);
      // Und sie sitzt in der Karte von München, nicht in einer anderen: dieselbe
      // antippbare Karte enthält beides.
      final munichCard = find.ancestor(
        of: find.text('München DE'),
        matching: find.byType(SplashPressable),
      );
      expect(munichCard, findsOneWidget);
      expect(find.descendant(of: munichCard, matching: marks), findsOneWidget);
    });

    testWidgets('die Suche filtert die Liste', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(cityQueryInput(), 'reg');
      await tester.pump();

      expect(find.text('Regensburg DE'), findsOneWidget);
      expect(find.text('München DE'), findsNothing);
      expect(find.text('Rom IT'), findsNothing);
      expect(find.text('Passau DE'), findsNothing);
    });

    testWidgets('ein leeres Ergebnis zeigt eine leere Liste ohne Hinweis', (
      tester,
    ) async {
      // `onboarding.noCityFound` existiert als Schlüssel und wird in der PWA
      // nicht benutzt.
      await pumpSignup(tester);

      await tester.enterText(cityQueryInput(), 'Paris');
      await tester.pump();

      for (final name in <String>[
        'München DE',
        'Rom IT',
        'Passau DE',
        'Regensburg DE',
      ]) {
        expect(find.text(name), findsNothing, reason: name);
      }
      expect(find.text('Keine Stadt gefunden'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('das Löschen-Zeichen erscheint nur bei gefüllter Suche', (
      tester,
    ) async {
      await pumpSignup(tester);

      expect(find.text('×'), findsNothing);

      await tester.enterText(cityQueryInput(), 'rom');
      await tester.pump();
      expect(find.text('×'), findsOneWidget);

      await tapText(tester, '×');
      expect(find.text('×'), findsNothing);
      expect(find.text('München DE'), findsOneWidget);
    });

    testWidgets('ein Tap wählt die Stadt aus und schickt sie mit', (
      tester,
    ) async {
      await pumpSignup(tester);

      await fillForm(tester);
      await tapText(tester, 'Passau DE');
      await submit(tester);

      expect(auth.lastSignUpHometown, 'Passau');
    });

    testWidgets('bei leerem Username-Feld entsteht ein Vorschlag, der sofort '
        'geprüft wird', (tester) async {
      await pumpSignup(tester);

      await tapText(tester, 'Rom IT');

      expect(
        tester.widget<TextField>(usernameInput()).controller!.text,
        'goldfuchs_r',
      );
      // Der Vorschlag löst die Prüfung aus: vorher keine Anfrage, nach Ablauf
      // der Verzögerung genau eine.
      expect(auth.checkedUsernames, isEmpty);
      await tester.pump(UsernameCheckNotifier.checkDelay);
      expect(auth.checkedUsernames, <String>['goldfuchs_r']);
      expect(usernameBadge('✓'), findsOneWidget);
    });

    testWidgets('ein gefülltes Username-Feld wird nicht überschrieben', (
      tester,
    ) async {
      await pumpSignup(tester);

      await enterUsername(tester, 'eigener_name');
      await tapText(tester, 'Rom IT');

      expect(
        tester.widget<TextField>(usernameInput()).controller!.text,
        'eigener_name',
      );
      expect(auth.checkedUsernames, <String>['eigener_name']);
    });
  });

  group('Die Reihenfolge der Validierung', () {
    testWidgets('leere Felder melden den Pflichttext und rufen nichts auf', (
      tester,
    ) async {
      await pumpSignup(tester);

      await submit(tester);

      expect(find.text('E-Mail und Passwort erforderlich.'), findsOneWidget);
      expect(auth.signUpCount, 0);
      expect(find.byType(SignupPage), findsOneWidget);
    });

    testWidgets('ohne Einwilligung erscheint der AGB-Text', (tester) async {
      await pumpSignup(tester);

      await fillForm(tester, acceptTerms: false);
      await submit(tester);

      expect(
        find.text('Bitte AGB und Datenschutz akzeptieren.'),
        findsOneWidget,
      );
      expect(auth.signUpCount, 0);
    });

    testWidgets('die AGB-Meldung schlägt die Username-Meldung', (tester) async {
      // **Der Kern dieser Gruppe.** Beide Meldungen erscheinen in derselben Box
      // und beide verhindern das Abschicken; eine vertauschte Reihenfolge fällt
      // ohne diesen Test nicht auf.
      auth.usernameTaken = true;
      await pumpSignup(tester);

      await fillForm(tester, acceptTerms: false);
      await submit(tester);

      expect(
        find.text('Bitte AGB und Datenschutz akzeptieren.'),
        findsOneWidget,
      );
      expect(find.text('Pflichtfeld'), findsNothing);
    });

    testWidgets('mit Einwilligung bleibt die Username-Meldung übrig', (
      tester,
    ) async {
      auth.usernameTaken = true;
      await pumpSignup(tester);

      await fillForm(tester);
      await submit(tester);

      expect(find.text('Pflichtfeld'), findsOneWidget);
      expect(auth.signUpCount, 0);
    });

    testWidgets('ein leeres Username-Feld blockiert ebenfalls', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(authFieldInput(0), 'jan@example.de');
      await tester.enterText(authFieldInput(1), 'geheim');
      await tester.pump();
      await tester.ensureVisible(find.byType(AuthCheckbox));
      await tester.pump();
      await tester.tap(find.byType(AuthCheckbox));
      await tester.pump();
      await submit(tester);

      expect(find.text('Pflichtfeld'), findsOneWidget);
      expect(auth.signUpCount, 0);
    });
  });

  group('Registrieren', () {
    testWidgets('Erfolg mit Sitzung merkt den Start, schreibt den Username '
        'und landet auf der Karte', (tester) async {
      auth.userId = 'user-42';
      await pumpSignup(tester);

      await fillForm(tester);
      expect(firstLaunch.hasLaunched(), isFalse);
      await submit(tester);

      expect(auth.signUpCount, 1);
      expect(auth.lastSignUpEmail, 'jan@example.de');
      expect(auth.lastSignUpName, 'stadtfuchs_m');
      expect(auth.lastSignUpHometown, 'München');
      expect(auth.setUsernameCount, 1);
      expect(auth.lastSetUsernameUserId, 'user-42');
      expect(auth.lastSetUsernameValue, 'stadtfuchs_m');
      expect(firstLaunch.hasLaunched(), isTrue);
      expect(find.byType(MapPage), findsOneWidget);
      expect(find.byType(SignupPage), findsNothing);
    });

    testWidgets('ohne Sitzung erscheint der Bestätigungshinweis in einer '
        'positiven Box, und der Bildschirm bleibt', (tester) async {
      // Bewusste Abweichung: die Quelle zeigt diesen Satz in der **roten**
      // Fehlerbox, weil sie für Meldungen nur eine Zustandsvariable hat.
      auth.signUpCreatesSession = false;
      await pumpSignup(tester);

      await fillForm(tester);
      await submit(tester);

      expect(find.byType(AuthNoticeBox), findsOneWidget);
      expect(find.byType(AuthErrorBox), findsNothing);
      expect(find.textContaining('Bitte E-Mail bestätigen'), findsOneWidget);
      // Auf dem Formular geblieben, kein Routenwechsel, kein Merken.
      expect(find.byType(SignupPage), findsOneWidget);
      expect(find.byType(MapPage), findsNothing);
      expect(firstLaunch.hasLaunched(), isFalse);
      // Und die Eingaben stehen noch da.
      expect(
        tester.widget<TextField>(usernameInput()).controller!.text,
        'stadtfuchs_m',
      );
      expect(
        tester.widget<TextField>(authFieldInput(0)).controller!.text,
        'jan@example.de',
      );
      expect(auth.setUsernameCount, 0);
    });

    testWidgets('ein fehlgeschlagenes Schreiben des Usernames wird gemeldet', (
      tester,
    ) async {
      // Die Quelle schluckt diesen Fehler (`.catch(() => {})`). Der Nutzer führt
      // dort einen Namen, den niemand gespeichert hat.
      //
      // Erreicht wird die Registrierung hier über `go` und mit erledigtem
      // Erstlauf, damit `matchedLocation` **`/signup`** ist. Warum das nötig ist,
      // steht im Test darunter.
      auth.setUsernameFailure = const AuthRequestRejected(code: '23505');
      firstLaunch = InMemoryFirstLaunchStore(hasLaunched: true);
      useDeviceSurface(tester);
      useReducedMotion(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      const SignupRoute().go(tester.element(find.byType(MapPage)));
      await tester.pumpAndSettle();
      expect(find.byType(SignupPage), findsOneWidget);

      await fillForm(tester);
      await submit(tester);

      expect(find.byType(AuthErrorBox), findsOneWidget);
      expect(find.text('Registrierung fehlgeschlagen.'), findsOneWidget);
      expect(auth.signUpCount, 1);
      expect(auth.setUsernameCount, 1);
      // Nicht navigiert: der Vorgang ist nicht durch. Über die Erstlauf-Merkung
      // sagt dieser Test nichts, sie war hier als Vorbedingung schon gesetzt;
      // der Test darunter prüft sie.
      expect(find.byType(SignupPage), findsOneWidget);
      expect(find.byType(MapPage), findsNothing);
    });

    testWidgets('über den Startbildschirm geöffnet, schiebt die Weiche den '
        'angemeldeten Nutzer trotzdem auf die Karte', (tester) async {
      // **Gemessen, nicht vermutet, und es gehört in einen Test statt in einen
      // Kommentar.** Nach einem fehlgeschlagenen Schreiben des Usernames ist der
      // Nutzer angemeldet, das Konto existiert. Wurde die Registrierung mit
      // `push` vom Startbildschirm geöffnet, bleibt `matchedLocation` `/splash`,
      // und die Weiche in `route_guards.dart` schickt jeden Angemeldeten von
      // dort auf die Karte. Die Fehlerbox ist dann nicht mehr zu sehen.
      //
      // Das restlos zu lösen bräuchte einen Zustand "Konto angelegt, Username
      // offen" samt Oberfläche und eigenem i18n-Schlüssel. Das gehört zu
      // `features/profile` (Phase 7). Der Fehlschlag wird trotzdem nicht
      // geschluckt: er steht im Zustand des Notifiers, und die Merkung bleibt
      // ungesetzt.
      auth.setUsernameFailure = const AuthRequestRejected(code: '23505');
      await pumpSignup(tester);

      await fillForm(tester);
      await submit(tester);

      expect(find.byType(MapPage), findsOneWidget);
      expect(find.byType(SignupPage), findsNothing);
      expect(firstLaunch.hasLaunched(), isFalse);
    });

    testWidgets('eine bekannte Adresse bekommt ihren eigenen Text', (
      tester,
    ) async {
      auth.signUpFailure = const AuthEmailAlreadyRegistered(
        code: 'user_already_exists',
      );
      await pumpSignup(tester);

      await fillForm(tester);
      await submit(tester);

      expect(
        find.text('Diese E-Mail ist bereits registriert.'),
        findsOneWidget,
      );
      expect(find.byType(SignupPage), findsOneWidget);
    });

    testWidgets('ein abgelehntes Passwort ebenso', (tester) async {
      auth.signUpFailure = const AuthPasswordRejected(code: 'weak_password');
      await pumpSignup(tester);

      await fillForm(tester, password: 'kurz');
      await submit(tester);

      expect(
        find.text('Passwort muss mindestens 6 Zeichen haben.'),
        findsOneWidget,
      );
    });

    testWidgets('ein Backend-Fehler nimmt den Sammeltext der Registrierung', (
      tester,
    ) async {
      // Nicht den der Anmeldung: die Quelle hat für die beiden Bildschirme zwei
      // verschiedene Sätze.
      auth.signUpFailure = const AuthBackendUnavailable(code: '503');
      await pumpSignup(tester);

      await fillForm(tester);
      await submit(tester);

      expect(find.text('Registrierung fehlgeschlagen.'), findsOneWidget);
      expect(find.text('Fehler beim Anmelden.'), findsNothing);
      expect(find.textContaining('503'), findsNothing);
    });

    testWidgets('der Ladezustand sperrt nur den Knopf', (tester) async {
      auth.signUpGate = Completer<void>();
      await pumpSignup(tester);

      await fillForm(tester);
      await tester.ensureVisible(find.text('Jetzt registrieren →'));
      await tester.pump();
      await tester.tap(find.text('Jetzt registrieren →'));
      await tester.pump();

      expect(find.text('Lädt…'), findsOneWidget);
      expect(find.text('Jetzt registrieren →'), findsNothing);
      await tester.tap(find.text('Lädt…'));
      await tester.pump();
      expect(auth.signUpCount, 1);

      // Der Rest bleibt bedienbar, es gibt keinen Spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AuthHeader), findsOneWidget);

      auth.signUpGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MapPage), findsOneWidget);
    });

    testWidgets('Wegnavigieren während der Registrierung erzeugt keinen '
        'Fehler', (tester) async {
      auth.signUpGate = Completer<void>();
      await pumpSignup(tester);

      await fillForm(tester);
      await tester.ensureVisible(find.text('Jetzt registrieren →'));
      await tester.pump();
      await tester.tap(find.text('Jetzt registrieren →'));
      await tester.pump();

      await tapText(tester, 'Anmelden');
      expect(find.byType(LoginPage), findsOneWidget);

      auth.signUpGate!.complete();
      await tester.pumpAndSettle();

      // Die Registrierung hat stattgefunden, die Merkung nicht: dafür hätte der
      // Bildschirm noch da sein müssen. Der Rest ist die Weiche, siehe die
      // Begründung im gleichnamigen Test der Anmeldung.
      expect(auth.signUpCount, 1);
      expect(firstLaunch.hasLaunched(), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Maße', () {
    testWidgets('die Fortschrittsleiste ist 5 hoch und zweigeteilt', (
      tester,
    ) async {
      // Ein Maßtest mit geladenen Schriften: die beiden Segmente teilen die
      // Breite abzüglich Innenabstand und Lücke.
      await pumpSignup(tester);

      final segments = find.descendant(
        of: find.byType(SignupProgressBar),
        matching: find.byType(DecoratedBox),
      );
      final first = tester.getRect(segments.at(0));
      final second = tester.getRect(segments.at(1));

      expect(first.height, 5);
      expect(second.height, 5);
      expect(first.left, 20);
      expect(second.right, 390 - 20);
      expect(second.left - first.right, 5);
      expect(first.width, second.width);
    });

    testWidgets('der Hero-Titel ist 30 groß, nicht die 32 der Anmeldung', (
      tester,
    ) async {
      await pumpSignup(tester);

      expect(tester.widget<Text>(find.text('Leg los.')).style!.fontSize, 30);
    });

    // Vier eigene Tests und keine Schleife in einem: eine Schleife meldet nur,
    // dass irgendeine Kombination scheitert, und man sieht nicht welche.
    for (final scale in <double>[1, 2]) {
      for (final size in <Size>[const Size(390, 844), const Size(360, 640)]) {
        final label =
            'Skalierung $scale auf ${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('$label laeuft nicht ueber', (tester) async {
          // Mit echten Schriften, siehe `test/support/app_fonts.dart`: ohne die
          // waere jede dieser Messungen wertlos. 2.0 ist Androids Maximum.
          useTextScale(tester, scale);
          await pumpSignup(tester, size: size);
          // Mit Inhalt, weil Staerkeanzeige und Statusabzeichen erst dann
          // gezeichnet werden.
          await fillForm(tester, password: 'abcdefgA1!');
          await tester.pump();

          expect(tester.takeException(), isNull, reason: label);
        });
      }
    }

    testWidgets('auf einem kurzen Bildschirm bleibt alles erreichbar', (
      tester,
    ) async {
      await pumpSignup(tester, size: const Size(320, 480));

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Bereits Mitglied?'));
      await tester.pumpAndSettle();
      expect(find.text('Mit Google'), findsOneWidget);
    });
  });
}
