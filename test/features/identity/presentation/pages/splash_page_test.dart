import 'dart:io';
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
import 'package:flutter/rendering.dart';
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

    testWidgets('der Kopfhörer-Knopf tritt bei großer Schrift zurück', (
      tester,
    ) async {
      // Bei 1.0 bemisst sich der Knopf an seinem Inhalt, soweit die Karten ihn
      // lassen. Bei 2.0 bindet seine Untergrenze: er wird schmaler als sein
      // Inhalt, damit die Karten überhaupt noch Platz für Flagge und Abstand
      // haben. Ohne das lief die innere Zeile der Karte über.
      await pumpSplash(tester);
      final audio = tester.renderObject<RenderBox>(audioButton());
      final normal = audio.size.width;
      // Beides bei 1.0 abgelesen: die intrinsischen Breiten des Knopfes
      // wachsen mit der Systemschriftgröße, ein Vergleich über die Umstellung
      // hinweg wäre also keiner.
      final normalFloor = audio.getMinIntrinsicWidth(double.infinity);

      useTextScale(tester, 2.0);
      await tester.pumpAndSettle();

      final scaled = tester.renderObject<RenderBox>(audioButton());
      expect(
        scaled.size.width,
        scaled.getMinIntrinsicWidth(double.infinity),
        reason: 'bei 2.0 bindet die Untergrenze des Knopfes',
      );
      expect(
        scaled.size.width,
        lessThan(scaled.getMaxIntrinsicWidth(double.infinity)),
        reason: 'er ist damit schmaler als seine Beschriftung in einer Zeile',
      );
      // Die Gegenprobe: bei 1.0 ist es die Breite der Karten, die den Knopf
      // begrenzt, nicht seine eigene Untergrenze.
      expect(normal, greaterThan(normalFloor));
    });

    testWidgets('der Bildschirm läuft bei 1.0 und 2.0 nirgends über', (
      tester,
    ) async {
      // Androids Systemmaximum ist 2.0. Geprüft auf dem Rahmenmaß der Quelle,
      // auf dem Maß des Emulators, auf dem verbreitetsten kleinen
      // Android-Format und auf einem, das für diese Zeile zu schmal ist. Ein
      // Overflow würde hier als `FlutterError` auflaufen; `testWidgets` lässt
      // keinen durch.
      for (final size in <Size>[
        const Size(411, 914),
        const Size(390, 844),
        const Size(360, 640),
        const Size(320, 568),
      ]) {
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

  group('Die Breiten der Sprachzeile', () {
    /// Wie viele Zeilen [text] auf dem Bildschirm tatsächlich belegt.
    ///
    /// **Warum das nötig ist:** ein Zeilenumbruch ist **kein** Overflow.
    /// Flutter meldet ihn nicht, es bricht einfach um. Die Prüfungen dieser
    /// Zeile achteten bis hierher nur auf Overflow, und deshalb ist der
    /// zweizeilige Kartentitel "Deutsc / h" erst am Emulator aufgefallen,
    /// obwohl es Tests für die Zeile gab.
    ///
    /// Gezählt werden die unterschiedlichen Oberkanten der Auswahlrechtecke des
    /// ganzen Textes. Eine Zeile, eine Oberkante.
    int renderedLines(WidgetTester tester, String text) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      return paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: text.length),
          )
          .map((box) => box.top)
          .toSet()
          .length;
    }

    /// Der Startbildschirm auf einem Gerät von [width] logischen Pixeln.
    Future<void> pumpWidth(WidgetTester tester, double width) async {
      tester.view
        ..physicalSize = Size(width * 3, 900 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      useReducedMotion(tester);
      await tester.pumpWidget(app(language: AppLanguage.de));
      await tester.pumpAndSettle();
    }

    RenderBox fieldOf(WidgetTester tester, String text) {
      return tester.renderObject<RenderBox>(
        find.ancestor(
          of: find.text(text),
          matching: find.byType(SplashPressable),
        ),
      );
    }

    testWidgets('die Kartentitel stehen einzeilig', (tester) async {
      // Der Defekt aus dem ersten Gerätelauf. 411 ist das Maß des Emulators
      // (Pixel 8: 1080 Pixel bei Dichte 420), 390 das Rahmenmaß der Quelle
      // (`chrome.jsx:135`), 600 ein Format, auf dem reichlich Platz ist.
      for (final width in <double>[600, 411, 390]) {
        await pumpWidth(tester, width);

        expect(renderedLines(tester, 'Deutsch'), 1, reason: 'bei $width');
        expect(renderedLines(tester, 'English'), 1, reason: 'bei $width');
      }
    });

    testWidgets('der Zeilenzähler erkennt einen Umbruch', (tester) async {
      // Die Gegenprobe zum Test darüber: ohne sie wäre er auch dann grün, wenn
      // [renderedLines] immer 1 liefert. 320 Pixel sind für diese Zeile zu
      // schmal, siehe den Test über die Grenze weiter unten.
      await pumpWidth(tester, 320);

      expect(renderedLines(tester, 'Deutsch'), greaterThan(1));
    });

    testWidgets('die Karten bekommen ihre min-content-Breite, der Knopf den '
        'Rest', (tester) async {
      // Die Regel aus der Quelle: `flex: 1` heißt `flex-basis: 0%`, und ein
      // Flex-Kind mit dieser Basis schrumpft nicht unter seine automatische
      // Mindestbreite. Der Knopf ohne Breitenangabe gibt nach.
      await pumpWidth(tester, 411);

      final german = fieldOf(tester, 'Deutsch');
      final english = fieldOf(tester, 'English');
      final audio = fieldOf(tester, '🎧');

      expect(
        german.size.width,
        greaterThanOrEqualTo(german.getMinIntrinsicWidth(double.infinity)),
      );
      expect(english.size.width, german.size.width, reason: 'beide gleich');
      expect(
        audio.size.width,
        lessThan(audio.getMaxIntrinsicWidth(double.infinity)),
        reason: 'der Knopf tritt zurück, statt die Karten zu drängen',
      );
      expect(renderedLines(tester, 'Audio-Guide'), 2, reason: 'er bricht um');
    });

    testWidgets('alle drei Felder sind gleich hoch', (tester) async {
      // `align-items: stretch`, die Vorgabe eines Flex-Containers: die Rahmen
      // der drei Felder stehen auf einer Linie, obwohl der Knopf mehr Inhalt
      // hat als die Karten. Ohne diese Zusicherung überlebte eine Fassung des
      // Layouts, die jedes Feld nur so hoch macht wie sein Inhalt.
      await pumpWidth(tester, 411);

      final german = fieldOf(tester, 'Deutsch');
      final english = fieldOf(tester, 'English');
      final audio = fieldOf(tester, '🎧');

      expect(german.size.height, audio.size.height);
      expect(english.size.height, audio.size.height);
      // Die Gegenprobe: von sich aus wären die Karten flacher. Ohne sie wäre
      // der Test auch dann grün, wenn alle drei denselben Inhalt hätten.
      expect(
        german.getMaxIntrinsicHeight(german.size.width),
        lessThan(audio.getMaxIntrinsicHeight(audio.size.width)),
      );
    });

    testWidgets('wo Platz ist, bemisst sich der Knopf an seinem Inhalt', (
      tester,
    ) async {
      // Die Quelle gibt ihm keine Breite. Ohne diesen Test wäre auch eine
      // Lösung grün, die ihn dauerhaft klein hält und den Karten Platz
      // schenkt, den sie nicht brauchen.
      await pumpWidth(tester, 600);

      final audio = fieldOf(tester, '🎧');

      expect(audio.size.width, audio.getMaxIntrinsicWidth(double.infinity));
      expect(renderedLines(tester, 'Audio-Guide'), 1);
    });

    testWidgets('bei 360 Pixeln reicht die Breite in keiner Aufteilung', (
      tester,
    ) async {
      // **Das ist eine offene Gestaltungsfrage, kein grüner Zustand.** Auf 360
      // logischen Pixeln passen die drei Felder nicht nebeneinander, gleich wie
      // man die Breite verteilt: zwei Karten mit ihrer Mindestbreite, der Knopf
      // mit seiner Untergrenze und zweimal 8 Pixel Abstand sind mehr als die
      // Zeile hergibt. Die Quelle hat dasselbe Problem und schneidet den Knopf
      // mit `#root { overflow: hidden }` ab.
      //
      // Geprüft wird die Ursache und nicht nur die Folge: wer die Zeile später
      // auch dort einzeilig bekommt, muss eine Maßangabe der Quelle ändern, und
      // dann fällt dieser Test und will gelesen werden.
      await pumpWidth(tester, 360);

      final row = tester.getSize(find.byType(SplashLanguageRow)).width;
      final card = fieldOf(tester, 'Deutsch');
      final audio = fieldOf(tester, '🎧');
      final needed =
          2 * card.getMinIntrinsicWidth(double.infinity) +
          audio.getMinIntrinsicWidth(double.infinity) +
          2 * SplashLanguageRow.fieldSpacing;

      expect(row, 360 - SplashPage.contentPadding.horizontal);
      expect(needed, greaterThan(row));
      expect(
        renderedLines(tester, 'Deutsch'),
        greaterThan(1),
        reason: 'Folge davon: der Titel bricht um',
      );
    });
  });

  group('Der native Startbildschirm', () {
    // Bis der erste Flutter-Frame steht, zeichnet Android ein eigenes
    // Fensterbild. Läuft dessen Farbe von `SplashPage.surface` weg, blitzt beim
    // Kaltstart eine fremde Farbe auf. Genau das war der Zustand aus der
    // `flutter create`-Vorlage: weiß, mehrere Sekunden lang.
    //
    // **Was diese beiden Prüfungen können und was nicht:** sie vergleichen
    // Werte in Dateien. `flutter test` startet kein Android und kann kein Bild
    // sehen. Der optische Nachweis ist eine Aufnahme vom Emulator und gehört in
    // den Bericht, nicht hierher. Ohne diese Prüfungen überlebte eine Mutation
    // der Farbe auf Weiß alle vier Gates, nachgewiesen.
    //
    // Gelesen wird über `File` und relative Pfade: `flutter test` läuft im
    // Wurzelverzeichnis des Pakets, wie `test/support/app_fonts.dart` es für
    // die Schriften auch tut.
    String read(String path) => File(path).readAsStringSync();

    const colors = 'android/app/src/main/res/values/colors.xml';
    const resources = <String>[
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ];

    test('seine Farbe ist die des ersten Flutter-Frames', () {
      final match = RegExp(
        r'<color name="fact_splash_background">#([0-9A-Fa-f]{8})</color>',
      ).firstMatch(read(colors));

      expect(match, isNotNull, reason: '$colors benennt die Farbe nicht');
      expect(
        int.parse(match!.group(1)!, radix: 16),
        SplashPage.surface.toARGB32(),
        reason: 'colors.xml und SplashPage.surface müssen gleich sein',
      );
    });

    test('kein Theme und kein Fensterbild fällt auf die Vorlage zurück', () {
      // Die Falle, an der die erste Fehlersuche vorbeigelaufen ist: wirksam ist
      // auf jedem Gerät mit `minSdk` 24 nicht `drawable/`, sondern
      // `drawable-v21/`. Wer nur die eine Datei ändert, ändert nichts
      // Sichtbares. Deshalb sind hier alle vier Dateien aufgeführt.
      for (final path in resources) {
        final content = read(path);

        expect(
          content,
          contains('@color/fact_splash_background'),
          reason: '$path benutzt die benannte Farbe nicht',
        );
        expect(
          content.replaceAll(RegExp('<!--.*?-->', dotAll: true), ''),
          isNot(anyOf(contains('color/white'), contains('colorBackground'))),
          reason: '$path fällt auf einen Vorlagenwert zurück',
        );
      }
    });
  });
}
