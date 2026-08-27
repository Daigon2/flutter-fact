import 'dart:ui' show Tristate;

import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/shell/floating_tab_bar.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:fact_app/features/identity/presentation/pages/login_page.dart';
import 'package:fact_app/features/identity/presentation/pages/signup_page.dart';
import 'package:fact_app/features/identity/presentation/pages/splash_page.dart';
import 'package:fact_app/features/identity/presentation/widgets/bubble_pin.dart';
import 'package:fact_app/features/identity/presentation/widgets/fact_wordmark.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_language_row.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pin_field.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Der Startbildschirm und die Weiche, die beim Erstlauf dorthin führt.
///
/// Gepumpt wird die ganze `FactApp` und nicht nur `SplashPage`: die drei
/// Ausgänge des Bildschirms sind Navigation, und Navigation ist ohne Router
/// nicht prüfbar.
///
/// "Bewegung reduzieren" ist in den meisten Tests Vorbedingung, nicht
/// Gegenstand: die Pins der Quelle animieren endlos, und `pumpAndSettle` käme
/// sonst nie zurück. Ein eigener Test unten prüft genau diesen Zusammenhang.
void main() {
  // Ohne die echten Schriften messen alle Maßprüfungen unten ein Layout, das es
  // auf keinem Gerät gibt, siehe `test/support/app_fonts.dart`. Der Kommentar
  // in `SplashPage` über die unbrauchbaren Breitenmessungen bezog sich auf
  // genau diesen Zustand.
  setUpAll(loadAppFonts);

  late InMemoryFirstLaunchStore firstLaunch;

  setUp(() {
    firstLaunch = InMemoryFirstLaunchStore();
  });

  /// Der Bildschirm ist mit 390 x 844 gebaut, dem Rahmenmaß der PWA
  /// (`chrome.jsx:135-136`). Die Testfläche von 800 x 600 ist dafür zu flach,
  /// die unteren Knöpfe lägen außerhalb des Sichtfensters.
  void useDeviceSurface(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget app({required AppLanguage language}) {
    return ProviderScope(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(language),
        ),
        firstLaunchStoreProvider.overrideWithValue(firstLaunch),
      ],
      child: const FactApp(),
    );
  }

  /// Schaltet die Systemeinstellung "Bewegung reduzieren" ein.
  ///
  /// Über den `PlatformDispatcher` und **nicht** über eine `MediaQuery` um
  /// `FactApp`. Das ist keine Geschmacksfrage: `pumpWidget` steckt das Widget in
  /// ein `View`, und erst dieses `View` legt `MediaQuery.fromView` an
  /// (`app.dart:369`: "WidgetsApp never introduces its own MediaQuery; the View
  /// widget takes care of that"). Eine eigene `MediaQuery` **darunter** verdeckt
  /// sie vollständig, und weil `MediaQueryData(disableAnimations: true)` alle
  /// übrigen Felder auf ihren Vorgaben lässt, wären `size` und `padding` dann
  /// null. Gemessen: mit Wrapper meldet `MediaQuery.paddingOf` 0 statt der
  /// gesetzten 47. Der Safe-Area-Test unten wäre damit stillschweigend
  /// wirkungslos gewesen.
  void useReducedMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Stellt die Systemschriftgröße ein, wie der Nutzer es täte.
  ///
  /// Über den `PlatformDispatcher`, aus demselben Grund wie
  /// [useReducedMotion].
  void useTextScale(WidgetTester tester, double scale) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> pumpSplash(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.de,
  }) async {
    useDeviceSurface(tester);
    useReducedMotion(tester);
    await tester.pumpWidget(app(language: language));
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Die Weiche beim Erstlauf', () {
    testWidgets('offener Erstlauf führt auf den Startbildschirm', (
      tester,
    ) async {
      await pumpSplash(tester);

      expect(find.byType(SplashPage), findsOneWidget);
      // Der Startbildschirm liegt außerhalb der Shell, also ohne Tab-Leiste.
      expect(find.byType(FloatingTabBar), findsNothing);
    });

    testWidgets('erledigter Erstlauf führt direkt auf die Karte', (
      tester,
    ) async {
      firstLaunch = InMemoryFirstLaunchStore(hasLaunched: true);

      await pumpSplash(tester);

      expect(find.byType(MapPage), findsOneWidget);
      expect(find.byType(SplashPage), findsNothing);
    });
  });

  group('Die Weiche reagiert auf Zustandsänderungen', () {
    testWidgets('eine Merkung von außen führt weg vom Startbildschirm', (
      tester,
    ) async {
      // Prüft die Verdrahtung in `app_router.dart`: das `ref.listen` stößt
      // `router.refresh()` an, und erst dadurch wertet go_router die Weiche neu
      // aus. Ohne diese Zeile bliebe der Bildschirm stehen, bis der Nutzer von
      // sich aus navigiert.
      await pumpSplash(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SplashPage)),
      );

      await container.read(firstLaunchProvider.notifier).markLaunched();
      await tester.pumpAndSettle();

      expect(find.byType(MapPage), findsOneWidget);
      expect(find.byType(SplashPage), findsNothing);
    });
  });

  group('Texte', () {
    testWidgets('zeigt die sechs Texte aus den Sprachdateien auf Deutsch', (
      tester,
    ) async {
      await pumpSplash(tester);

      // Die beiden Kennzahlen-Beschriftungen erscheinen großgeschrieben:
      // `text-transform: uppercase` steht am Element, nicht in der Übersetzung.
      for (final text in <String>[
        'FAKTEN',
        'STÄDTE',
        'Audio-Guide',
        'Jetzt registrieren →',
        'Anmelden',
        'Ohne Konto erkunden',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('ein Sprachwechsel auf Englisch tauscht sie aus', (
      tester,
    ) async {
      await pumpSplash(tester);

      await tapButton(tester, 'English');

      for (final text in <String>[
        'FACTS',
        'CITIES',
        'Audio Guide',
        'Create account →',
        'Sign in',
        'Explore without account',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Ohne Konto erkunden'), findsNothing);
    });

    testWidgets('die Sprachkarten bleiben in ihrer eigenen Sprache', (
      tester,
    ) async {
      // `screen-auth.jsx:334`: "Subs intentionally not translated". Ein
      // Sprachwechsel darf diese vier Texte nicht anfassen.
      await pumpSplash(tester, language: AppLanguage.en);

      for (final text in <String>[
        'Deutsch',
        'Weiter auf Deutsch',
        'English',
        'Continue in English',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('das Goethe-Zitat steht hartcodiert und ungeteilt', (
      tester,
    ) async {
      // Es gibt für diesen Text keinen i18n-Schlüssel, siehe `SplashQuote`.
      // Auf Englisch steht deshalb derselbe deutsche Satz, genau wie in der PWA.
      await pumpSplash(tester, language: AppLanguage.en);

      expect(
        find.textContaining('Man sieht nur, was man'),
        findsOneWidget,
        reason: 'Zitat',
      );
      expect(find.text('— Goethe'), findsOneWidget);
    });
  });

  group('Die drei Ausgänge', () {
    testWidgets('"Ohne Konto erkunden" merkt den Start und öffnet die Karte', (
      tester,
    ) async {
      await pumpSplash(tester);
      expect(firstLaunch.hasLaunched(), isFalse);

      await tapButton(tester, 'Ohne Konto erkunden');

      expect(firstLaunch.hasLaunched(), isTrue);
      expect(find.byType(MapPage), findsOneWidget);
      expect(find.byType(SplashPage), findsNothing);
      // Ab hier ist die Tab-Leiste wieder da: die Karte liegt in der Shell.
      expect(find.byType(FloatingTabBar), findsOneWidget);
    });

    testWidgets('"Jetzt registrieren" öffnet die Registrierung und der '
        'Zurück-Weg führt zurück', (tester) async {
      await pumpSplash(tester);

      await tapButton(tester, 'Jetzt registrieren →');

      // Beide Richtungen: das erwartete Ziel ist da, das verwechselbare nicht.
      // Ohne die zweite Zeile bleibt ein vertauschtes Ziel unentdeckt, weil
      // beide Seiten den Startbildschirm gleichermaßen verdecken.
      expect(find.byType(SignupPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      // `push` und nicht `go`: der Startbildschirm bleibt im Stapel darunter.
      // Und die Merkung darf hier noch **nicht** stehen, anders als in der PWA.
      expect(firstLaunch.hasLaunched(), isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(SignupPage), findsNothing);
    });

    testWidgets('"Anmelden" öffnet die Anmeldung und der Zurück-Weg führt '
        'zurück', (tester) async {
      await pumpSplash(tester);

      await tapButton(tester, 'Anmelden');

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SignupPage), findsNothing);
      expect(find.byType(SplashPage), findsNothing);
      expect(firstLaunch.hasLaunched(), isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });
  });

  group('Barrierefreiheit', () {
    testWidgets('die aktive Sprachkarte ist als ausgewählt ansagbar', (
      tester,
    ) async {
      // Bewusst über die Quelle hinaus, siehe `SplashPressable.selected`. Ohne
      // das ist für einen Screenreader nicht feststellbar, welche Sprache
      // aktiv ist: die Auswahl steckt sonst nur in Farbe und Rahmen.
      // Freigabe am Ende des Rumpfes und nicht per `addTearDown`:
      // `flutter_test` prüft offene Handles noch **vor** den Teardowns.
      final handle = tester.ensureSemantics();
      await pumpSplash(tester);

      SemanticsNode cardOf(String label) => tester.getSemantics(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(SplashPressable),
        ),
      );

      // `flagsCollection` statt des seit 3.32 veralteten `hasFlag`. Der
      // Auswahlzustand ist dreiwertig: `none` heißt "kein Auswahlzustand", und
      // genau das melden Knöpfe ohne `selected`.
      expect(cardOf('Deutsch').flagsCollection.isSelected, Tristate.isTrue);
      expect(cardOf('English').flagsCollection.isSelected, Tristate.isFalse);

      await tapButton(tester, 'English');

      expect(cardOf('English').flagsCollection.isSelected, Tristate.isTrue);
      expect(cardOf('Deutsch').flagsCollection.isSelected, Tristate.isFalse);

      handle.dispose();
    });

    testWidgets('der Kopfhörer-Knopf hat das aria-label der Quelle', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSplash(tester);

      // `aria-label={window.t('audio.splash.button')}` und derselbe Text als
      // Beschriftung. Das Label ersetzt den Inhalt, statt ihn zu ergänzen,
      // deshalb wird "Audio-Guide" genau einmal angesagt.
      expect(find.bySemanticsLabel('Audio-Guide'), findsOneWidget);

      handle.dispose();
    });
  });

  group('Maße der Inhaltsspalte', () {
    testWidgets('die Wortmarke sitzt 60 plus 110 Pixel unter der Safe Area', (
      tester,
    ) async {
      // Nagelt `contentPadding.top` und `wordmarkTopInset` geometrisch fest
      // statt als Zahlenvergleich. Vorher ließ sich `wordmarkTopInset` von 110
      // auf 11 setzen, ohne dass ein Gate anschlug.
      //
      // Ohne Geräte-Inset in der Testumgebung ist die Safe Area die
      // Bildschirmkante, die erwartete Höhe also 170.
      await pumpSplash(tester);

      expect(
        tester.getTopLeft(find.byType(FactWordmark)).dy,
        SplashPage.contentPadding.top + SplashPage.wordmarkTopInset,
      );
      expect(SplashPage.contentPadding.top, 60);
      expect(SplashPage.wordmarkTopInset, 110);
    });

    testWidgets('der Inhalt hält seitlich 22 Pixel Abstand', (tester) async {
      await pumpSplash(tester);

      expect(
        tester.getTopLeft(find.text('Ohne Konto erkunden')).dx,
        greaterThanOrEqualTo(SplashPage.contentPadding.left),
      );
      expect(SplashPage.contentPadding.left, 22);
      expect(SplashPage.contentPadding.bottom, 40);
    });
  });

  group('Safe Area', () {
    testWidgets('das Geräte-Inset verschiebt Inhalt und Pins gemeinsam', (
      tester,
    ) async {
      // Die Zusicherung zur korrigierten Entscheidung. In der Quelle ist das
      // Inset ein `padding` des `body` (`index.html:101-107`), es verschiebt
      // also den ganzen Bildschirm. Ein früherer Stand hatte die `SafeArea` nur
      // um die Inhaltsspalte: die Wortmarke saß dann richtig, die Pins 47 dp zu
      // hoch. Ohne dieser Test fällt das durch kein Gate, weil die
      // Testumgebung standardmäßig gar kein Inset hat.
      const inset = 47.0;
      useDeviceSurface(tester);
      tester.view.padding = const FakeViewPadding(top: inset * 3);
      useReducedMotion(tester);

      await tester.pumpWidget(app(language: AppLanguage.de));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byType(FactWordmark)).dy,
        inset + SplashPage.contentPadding.top + SplashPage.wordmarkTopInset,
        reason: 'Wortmarke: 47 + 60 + 110',
      );
      expect(
        tester.getTopLeft(find.byType(BubblePin).first).dy,
        inset + splashPins.first.top,
        reason: 'Pin 1: 47 + 110',
      );
    });
  });

  group('Überlauf', () {
    testWidgets('ein flacher Bildschirm scrollt statt überzulaufen', (
      tester,
    ) async {
      // Die bewusste Abweichung von der Quelle, siehe `SplashPage`. Ein
      // Overflow würde hier als Fehler auflaufen, `testWidgets` lässt keinen
      // `FlutterError` durch.
      //
      // Die Breite bleibt bei den 390 der Quelle. Schmaler geht dieser
      // Bildschirm auch in der PWA nicht auf: dort verhindert `min-width: auto`
      // das Schrumpfen der Sprachkarten und `#root { overflow: hidden }`
      // schneidet den Rest ab. Siehe Bericht.
      tester.view
        ..physicalSize = const Size(390, 520)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      useReducedMotion(tester);

      await tester.pumpWidget(app(language: AppLanguage.de));
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(SplashPage),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0),
      );
    });

    testWidgets('auf einem hohen Bildschirm bleibt der Abstandhalter wirksam', (
      tester,
    ) async {
      await pumpSplash(tester);

      // Der letzte Knopf sitzt unten, nicht direkt unter den Kennzahlen: der
      // `flex: 1`-Abstandhalter der Quelle wirkt.
      expect(
        tester.getRect(find.text('Ohne Konto erkunden')).bottom,
        greaterThan(844 * 0.7),
      );
    });
  });

  group('Bewegung reduzieren', () {
    testWidgets('bei reduzierter Bewegung läuft keine Animation weiter', (
      tester,
    ) async {
      useDeviceSurface(tester);
      useReducedMotion(tester);

      await tester.pumpWidget(app(language: AppLanguage.de));
      // Käme der Bildschirm nicht zur Ruhe, liefe dieser Aufruf in eine
      // Zeitüberschreitung.
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byType(SplashPage), findsOneWidget);
    });

    testWidgets('ohne die Einstellung animieren die Pins endlos', (
      tester,
    ) async {
      // Die Gegenprobe. Ohne sie könnte der Test darüber auch dann grün sein,
      // wenn es gar keine Animation gibt.
      // Bewusst ohne `useReducedMotion`, das ist der Gegenstand des Tests.
      useDeviceSurface(tester);

      await tester.pumpWidget(app(language: AppLanguage.de));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.binding.hasScheduledFrame, isTrue);
    });
  });
  group('Große Systemschrift', () {
    /// Der Kopfhörer-Knopf als Fläche, nicht als Text.
    Finder audioButton() => find.ancestor(
      of: find.text('🎧'),
      matching: find.byType(SplashPressable),
    );

    testWidgets('die Wortmarke bleibt bei doppelter Schrift gleich groß', (
      tester,
    ) async {
      // Die Entscheidung aus `FactWordmark`: das Logo folgt der
      // Textgrößen-Einstellung nicht. Ohne diese Zusicherung lief die Zeile bei
      // Skalierung 2.0 auf 390 Pixeln um 65 Pixel nach rechts über, und zwar
      // erst mit echten Schriften sichtbar.
      await pumpSplash(tester);
      final normal = tester.getSize(find.byType(FactWordmark));

      useTextScale(tester, 2.0);
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(FactWordmark)), normal);
    });

    testWidgets('alles andere auf dem Bildschirm skaliert weiter', (
      tester,
    ) async {
      // Die Gegenprobe. Ohne sie wäre der Test darüber auch dann grün, wenn der
      // ganze Bildschirm die Systemschriftgröße ignoriert, und das wäre eine
      // echte Barrierefreiheits-Lücke statt einer begründeten Ausnahme.
      await pumpSplash(tester);
      final finder = find.text('Ohne Konto erkunden');
      final normal = tester.getSize(finder).height;

      useTextScale(tester, 2.0);
      await tester.pumpAndSettle();

      expect(tester.getSize(finder).height, greaterThan(normal));
    });

    testWidgets('die Deckelung des Audio-Knopfes greift erst bei großer '
        'Schrift', (tester) async {
      // `SplashLanguageRow.audioButtonMaxWidth`. Bei 1.0 darf sie **nicht**
      // binden, sonst verändert sie das Aussehen des Normalfalls; bei 2.0 muss
      // sie binden, sonst nimmt der Knopf den Sprachkarten den Platz für Flagge
      // und Abstand weg und die Karte läuft über.
      await pumpSplash(tester);

      expect(
        tester.getSize(audioButton()).width,
        lessThan(SplashLanguageRow.audioButtonMaxWidth),
        reason: 'bei 1.0 bindet die Deckelung nicht',
      );

      useTextScale(tester, 2.0);
      await tester.pumpAndSettle();

      expect(
        tester.getSize(audioButton()).width,
        SplashLanguageRow.audioButtonMaxWidth,
        reason: 'bei 2.0 bindet sie',
      );
      expect(SplashLanguageRow.audioButtonMaxWidth, 115);
    });

    testWidgets('der Bildschirm läuft bei 1.0 und 2.0 nirgends über', (
      tester,
    ) async {
      // Androids Systemmaximum ist 2.0. Geprüft auf dem Rahmenmaß der Quelle
      // und auf dem verbreitetsten kleinen Android-Format. Ein Overflow würde
      // hier als `FlutterError` auflaufen; `testWidgets` lässt keinen durch.
      for (final size in <Size>[const Size(390, 844), const Size(360, 640)]) {
        for (final scale in <double>[1.0, 2.0]) {
          tester.view
            ..physicalSize = size * 3
            ..devicePixelRatio = 3;
          useReducedMotion(tester);
          useTextScale(tester, scale);
          addTearDown(tester.view.reset);

          await tester.pumpWidget(app(language: AppLanguage.de));
          await tester.pumpAndSettle();

          expect(
            find.byType(SplashPage),
            findsOneWidget,
            reason: '$size @$scale',
          );
        }
      }
    });
  });
}
