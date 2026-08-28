import 'dart:math' as math;

import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/onboarding/onboarding_host.dart';
import 'package:fact_app/app/onboarding/onboarding_providers.dart';
import 'package:fact_app/app/onboarding/tour_overlay.dart';
import 'package:fact_app/app/onboarding/tour_steps.dart';
import 'package:fact_app/app/onboarding/tour_store.dart';
import 'package:fact_app/app/onboarding/widgets/tour_arrow.dart';
import 'package:fact_app/app/onboarding/widgets/tour_bubble.dart';
import 'package:fact_app/app/onboarding/widgets/tour_chrome.dart';
import 'package:fact_app/app/onboarding/widgets/tour_hero_view.dart';
import 'package:fact_app/app/onboarding/widgets/tour_highlight.dart';
import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/app/shell/app_shell.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/identity/domain/entities/auth_session.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../features/identity/fake_auth_repository.dart';
import '../../support/app_fonts.dart';

/// Das Tutorial-Overlay in der echten App.
///
/// Gepumpt wird `FactApp` und nicht `TourOverlay` allein, und zwar aus einem
/// Grund, der den halben Gegenstand dieser Datei ausmacht: das Overlay misst
/// echte Anker aus dem Widget-Baum. Ohne Shell gäbe es keine Tab-Leiste, keine
/// angemeldeten Anker und damit weder Pfeil noch Ring, also genau das
/// Ergebnis, das ein Defekt auch liefern würde.
///
/// "Bewegung reduzieren" ist überall Vorbedingung und nicht Gegenstand: der
/// Leuchtring pulsiert endlos, `pumpAndSettle` käme sonst nie zurück.
void main() {
  // Ohne die echten Schriften misst der Zeilenumbruch-Test ein Layout, das es
  // auf keinem Gerät gibt, siehe `test/support/app_fonts.dart`.
  setUpAll(loadAppFonts);

  late InMemoryTourStore tourStore;
  late InMemoryFirstLaunchStore firstLaunch;

  setUp(() {
    tourStore = InMemoryTourStore();
    firstLaunch = InMemoryFirstLaunchStore(hasLaunched: true);
  });

  /// Das Rahmenmaß der PWA (`chrome.jsx:135-136`). Die Vorgabefläche von
  /// 800 x 600 ist zu flach: eine Blase mit `top: 380` hätte darunter kaum
  /// noch Platz, und die Punktreihe läge über ihr.
  void useDeviceSurface(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Über den `PlatformDispatcher` und **nicht** über eine eigene
  /// `MediaQuery`: die läge unter der von `pumpWidget` angelegten und würde
  /// `size` und `padding` auf null ziehen.
  void useReducedMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Ebenfalls über den `PlatformDispatcher`, siehe `useReducedMotion`.
  /// 2.0 ist Androids Maximum, siehe `test/support/app_fonts.dart`.
  void useTextScale(WidgetTester tester, double scale) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Widget app({
    AppLanguage language = AppLanguage.de,
    FakeAuthRepository? auth,
  }) {
    return ProviderScope(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(language),
        ),
        firstLaunchStoreProvider.overrideWithValue(firstLaunch),
        tourStoreProvider.overrideWithValue(tourStore),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const FactApp(),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.de,
    FakeAuthRepository? auth,
    Size size = const Size(390, 844),
  }) async {
    useDeviceSurface(tester, size: size);
    useReducedMotion(tester);
    await tester.pumpWidget(app(language: language, auth: auth));
    await tester.pumpAndSettle();
  }

  /// Tippt auf eine Stelle, an der nur der Verdunkler liegt.
  Future<void> tapScrim(WidgetTester tester) async {
    await tester.tapAt(const Offset(12, 300));
    await tester.pumpAndSettle();
  }

  /// Schaltet auf den Schritt mit der Nummer [number].
  Future<void> goToStep(WidgetTester tester, int number) async {
    for (var i = 1; i < number; i++) {
      await tapScrim(tester);
    }
  }

  AnchorRegistry registryOf(WidgetTester tester) {
    final scope = tester.element(find.byType(AnchorScope));
    late AnchorRegistry found;
    scope.visitChildElements((element) {
      found = AnchorScope.maybeOf(element)!;
    });
    return found;
  }

  Finder anchorOf(AnchorId id) => find.byWidgetPredicate(
    (widget) => widget is AnchorTarget && widget.anchorId == id,
  );

  int branchIndex(WidgetTester tester) => tester
      .widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell))
      .currentIndex;

  group('Der Ablauf', () {
    testWidgets('startet auf dem Hero-Schritt mit Zitat und Meta-Zeile', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byType(TourOverlay), findsOneWidget);
      expect(find.byType(TourHeroView), findsOneWidget);
      expect(find.text('»Man sieht nur,\nwas man weiß.«'), findsOneWidget);
      expect(find.text('— GOETHE'), findsOneWidget);
      // Ein Hero-Schritt hat keine Blase und keinen Anker.
      expect(find.byType(TourBubble), findsNothing);
      expect(find.byType(TourArrow), findsNothing);
      expect(find.byType(TourHighlight), findsNothing);
    });

    testWidgets('ein Tipp irgendwohin schaltet weiter', (tester) async {
      await pumpApp(tester);
      await tapScrim(tester);

      expect(find.byType(TourHeroView), findsNothing);
      expect(find.byType(TourBubble), findsOneWidget);
      expect(find.text('SCHRITT 2 VON 9'), findsOneWidget);
    });

    testWidgets('ein Tipp auf die Blase schaltet ebenfalls weiter', (
      tester,
    ) async {
      // In der Quelle ist der klickbare Bereich der Vater der Blase, ein Klick
      // blubbert also nach oben. In Flutter hört `RenderStack` beim ersten
      // getroffenen Kind auf; läge der `GestureDetector` als unterste Ebene im
      // `Stack`, täte ein Tipp auf die Blase nichts.
      await pumpApp(tester);
      await tapScrim(tester);

      await tester.tapAt(tester.getCenter(find.byType(TourBubble)));
      await tester.pumpAndSettle();

      expect(find.text('SCHRITT 3 VON 9'), findsOneWidget);
    });

    testWidgets('nach dem letzten Schritt ist das Tutorial weg und das Flag '
        'gesetzt', (tester) async {
      await pumpApp(tester);
      await goToStep(tester, TourSteps.count);

      expect(find.byType(TourHeroView), findsOneWidget);
      expect(tourStore.hasSeenTour(), isFalse, reason: 'noch nicht durch');

      await tapScrim(tester);

      expect(find.byType(TourOverlay), findsNothing);
      expect(tourStore.hasSeenTour(), isTrue);
    });

    testWidgets('das Ende des Tutorials baut die Shell nicht neu', (
      tester,
    ) async {
      // Gemessen, nicht befürchtet: solange `OnboardingHost` die Struktur
      // wechselte (mal mit `Stack`, mal ohne), verwarf Flutter beim Ende der
      // Tour die ganze Shell samt der vier Zweig-Navigatoren. Der Nutzer
      // verliert damit jeden Routenstapel. Gemeldet hat es der `assert` in
      // `AnchorRegistry.register`: die neue Tab-Leiste meldete ihre Anker an,
      // bevor die alte entsorgt war.
      await pumpApp(tester);
      final shellBefore = tester.element(find.byType(AppShell));

      await goToStep(tester, TourSteps.count);
      await tapScrim(tester);

      expect(find.byType(TourOverlay), findsNothing);
      expect(tester.element(find.byType(AppShell)), same(shellBefore));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Überspringen beendet sofort und setzt das Flag ebenfalls', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapScrim(tester);
      expect(find.text('SCHRITT 2 VON 9'), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.byType(TourSkipButton)));
      await tester.pumpAndSettle();

      expect(find.byType(TourOverlay), findsNothing);
      expect(tourStore.hasSeenTour(), isTrue);
    });

    testWidgets('Überspringen schaltet nicht zusätzlich weiter', (
      tester,
    ) async {
      // Die Quelle braucht dafür ein eigenes `stopPropagation`
      // (`screen-tour.jsx:282`). In Flutter gewinnt der innere Tipp-Erkenner
      // die Gestenarena. Ohne diese Zusicherung wäre ein Doppelschritt beim
      // Überspringen unsichtbar, weil das Overlay danach ohnehin verschwindet.
      await pumpApp(tester);
      await tester.tapAt(tester.getCenter(find.byType(TourSkipButton)));
      await tester.pump();

      // Nach dem ersten Tipp ist die Merkung gesetzt. Wäre zusätzlich
      // weitergeschaltet worden, stünde vorher Schritt 2 im Baum.
      expect(tourStore.hasSeenTour(), isTrue);
      expect(find.text('SCHRITT 2 VON 9'), findsNothing);
    });

    testWidgets('die Punktreihe zählt alle neun und markiert den laufenden', (
      tester,
    ) async {
      await pumpApp(tester);
      await goToStep(tester, 4);

      final dots = tester.widget<TourStepDots>(find.byType(TourStepDots));
      expect(dots.count, 9);
      expect(dots.current, 3, reason: 'Schritt 4, ab null gezählt');
    });
  });

  group('Degradation ohne gebauten Anker', () {
    testWidgets('alle neun Schritte einzeln durchgespielt', (tester) async {
      // Der Kern dieses Blocks: ein fehlender Anker überspringt den Schritt
      // **nicht**. Die Quelle setzt `targetRect` auf `null`
      // (`screen-tour.jsx:254`) und rendert die Blase trotzdem (`:456`).
      //
      // In **einem** Durchlauf und nicht je Schritt frisch gepumpt: ein
      // zweites `pumpWidget` mit demselben Widgettyp behält den Zustand des
      // Overlays, der Schrittzähler liefe also weiter statt von vorn. Genau
      // daran ist die erste Fassung dieses Tests gescheitert.
      const degrading = <int>[2, 3, 4, 6, 8];
      const withAnchor = <int>[2, 3, 4, 5, 6, 7, 8];
      await pumpApp(tester);

      for (var number = 1; number <= TourSteps.count; number++) {
        final where = 'Schritt $number';
        // Auf jedem Schritt gleich: Überspringen, Hinweis, Punktreihe.
        expect(find.byType(TourSkipButton), findsOneWidget, reason: where);
        expect(find.byType(TourTapHint), findsOneWidget, reason: where);
        final dots = tester.widget<TourStepDots>(find.byType(TourStepDots));
        expect(dots.current, number - 1, reason: where);
        expect(dots.count, TourSteps.count, reason: where);

        if (withAnchor.contains(number)) {
          expect(find.byType(TourBubble), findsOneWidget, reason: where);
          expect(
            find.text('SCHRITT $number VON 9'),
            findsOneWidget,
            reason: where,
          );
          expect(find.byType(TourHeroView), findsNothing, reason: where);
        } else {
          expect(find.byType(TourHeroView), findsOneWidget, reason: where);
          expect(find.byType(TourBubble), findsNothing, reason: where);
        }

        final expectsTarget =
            withAnchor.contains(number) && !degrading.contains(number);
        expect(
          find.byType(TourArrow),
          expectsTarget ? findsOneWidget : findsNothing,
          reason: '$where: Pfeil',
        );
        expect(
          find.byType(TourHighlight),
          expectsTarget ? findsOneWidget : findsNothing,
          reason: '$where: Ring',
        );

        // Der `assert` in `AnchorRegistry.rectOf` darf nicht angeschlagen
        // haben, sonst stimmt die Verdrahtung von `knownMissing` nicht.
        expect(tester.takeException(), isNull, reason: where);

        if (number < TourSteps.count) {
          await tapScrim(tester);
        }
      }
    });

    testWidgets('ein vertippter Anker schlägt weiterhin an', (tester) async {
      // Die Gegenprobe zum Test darüber. Ohne sie belegt "kein
      // Assertion-Fehler" nur, dass der `assert` überhaupt still ist, nicht
      // dass er den Tippfehler-Fall noch trennt.
      await pumpApp(tester);

      expect(
        () =>
            registryOf(tester).rectOf(const AnchorId('mode-tour-verschrieben')),
        throwsA(isA<AssertionError>()),
      );
      // Und die fünf bekannten fehlen wirklich, statt zufällig da zu sein.
      for (final anchor in DiscoveryAnchors.values) {
        expect(registryOf(tester).rectOf(anchor), isNull, reason: anchor.value);
      }
    });
  });

  group('Gemessen wird neu, nicht einmal', () {
    testWidgets('der Ring deckt genau den Tab-Knopf plus 5 Pixel ab', (
      tester,
    ) async {
      // Prüft zwei Dinge auf einmal: den Innenabstand des Rings und die
      // Annahme, dass die Bezugsfläche des `AnchorScope` und die Fläche des
      // Overlays denselben Ursprung haben. Läge das Overlay verschoben, wäre
      // jedes Rechteck aus der Registry um denselben Betrag falsch.
      await pumpApp(tester);
      await goToStep(tester, 5);

      final tab = tester.getRect(anchorOf(ShellTab.collection.anchorId));
      expect(tester.getRect(find.byType(TourHighlight)), tab.inflate(5));
    });

    testWidgets('Pfeil und Ring folgen einer Größenänderung', (tester) async {
      // Die Quelle misst in einem `requestAnimationFrame` und erneut bei jedem
      // `resize` (`screen-tour.jsx:180-264`). Ein Nachbau, der nur in
      // `initState` misst, sitzt nach einer Drehung falsch, und zwar
      // plausibel falsch: der Pfeil zeigt weiter irgendwohin.
      await pumpApp(tester);
      await goToStep(tester, 5);

      final ringBefore = tester.getRect(find.byType(TourHighlight));
      final arrowBefore = tester
          .widget<TourArrow>(find.byType(TourArrow))
          .geometry;

      tester.view.physicalSize = const Size(600, 844) * 3;
      await tester.pumpAndSettle();

      final ringAfter = tester.getRect(find.byType(TourHighlight));
      final arrowAfter = tester
          .widget<TourArrow>(find.byType(TourArrow))
          .geometry;

      expect(ringAfter, isNot(ringBefore), reason: 'der Ring ist mitgewandert');
      expect(arrowAfter, isNot(arrowBefore), reason: 'der Pfeil auch');
      // Und er sitzt danach wieder richtig, nicht nur anders.
      final tab = tester.getRect(anchorOf(ShellTab.collection.anchorId));
      expect(ringAfter, tab.inflate(5));
      // Der Pfeil endet weiterhin genau um die halbe längere Zielkante plus
      // 18 vor der neuen Zielmitte, schneidet den Ring also nicht.
      expect(
        (tab.center - arrowAfter.to).distance,
        closeTo(math.max(tab.width, tab.height) / 2 + 18, 0.01),
      );
    });
  });

  group('Die beiden Flags sind unabhängig', () {
    testWidgets('ein angemeldeter Rückkehrer ohne Startbildschirm bekommt das '
        'Tutorial', (tester) async {
      // `fact_has_launched` entscheidet über den Bildschirm, `fact_tour_shown`
      // über eine Ebene darüber. Die Quelle liest das zweite ohne jede weitere
      // Bedingung (`app.jsx:73`), während das erste zusätzlich am
      // Anmeldezustand hängt (`app.jsx:69`).
      firstLaunch = InMemoryFirstLaunchStore();
      final auth = FakeAuthRepository(
        initial: AuthSession.signedIn(userId: 'rueckkehrer'),
      );
      addTearDown(auth.close);

      await pumpApp(tester, auth: auth);

      expect(find.byType(AppShell), findsOneWidget, reason: 'kein Splash');
      expect(find.byType(TourOverlay), findsOneWidget);
    });

    testWidgets('über dem Startbildschirm liegt kein Overlay', (tester) async {
      // Die Umkehrung: das Tutorial darf nicht in `route_guards.dart`
      // einziehen. Es hängt an der Shell, und der Startbildschirm liegt
      // außerhalb davon.
      firstLaunch = InMemoryFirstLaunchStore();

      await pumpApp(tester);

      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(TourOverlay), findsNothing);
      expect(tourStore.hasSeenTour(), isFalse, reason: 'unangetastet');
    });
  });

  group('Wenn das Tutorial erledigt ist', () {
    testWidgets('hängt nichts im Baum und die Tab-Leiste ist bedienbar', (
      tester,
    ) async {
      // Ein unsichtbares Overlay wäre der teurere Fehler: es nimmt weiter am
      // Hit-Test teil und verschluckt Tipps, ohne dass man etwas sieht.
      tourStore = InMemoryTourStore(hasSeenTour: true);
      await pumpApp(tester);

      expect(find.byType(TourOverlay), findsNothing);
      expect(find.byType(OnboardingHost), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.text('Profil')));
      await tester.pumpAndSettle();

      expect(branchIndex(tester), ShellTab.profile.index);
    });
  });

  group('Über der Shell, aber über jedem Tab', () {
    testWidgets('während des Tutorials ist kein Tabwechsel möglich', (
      tester,
    ) async {
      // Genau das macht die Bedingung `route === 'map'` der Quelle
      // gegenstandslos: das Overlay liegt dort mit `zIndex: 5000` über der
      // Leiste (`zIndex: 50`), ein Klick auf einen Tab schaltet den Schritt
      // weiter statt den Bildschirm.
      await pumpApp(tester);

      await tester.tapAt(tester.getCenter(find.text('Profil')));
      await tester.pumpAndSettle();

      expect(branchIndex(tester), ShellTab.map.index);
      expect(find.text('SCHRITT 2 VON 9'), findsOneWidget);
    });

    testWidgets('auf einem anderen Tab läuft das Tutorial weiter', (
      tester,
    ) async {
      // Der einzige Fall, in dem der fehlende `route === 'map'`-Vergleich
      // einen Unterschied macht: ein Deep Link auf einen anderen Zweig. Die
      // PWA kennt ihn nicht, sie hat keine URLs.
      await pumpApp(tester);
      await goToStep(tester, 7);

      const CollectionRoute().go(tester.element(find.byType(AppShell)));
      await tester.pumpAndSettle();

      expect(branchIndex(tester), ShellTab.collection.index);
      expect(find.text('SCHRITT 7 VON 9'), findsOneWidget);
      // Der Anker sitzt in der Leiste und nicht in einem Zweig, der Schritt
      // bleibt also voll gebaut.
      expect(find.byType(TourArrow), findsOneWidget);
      expect(find.byType(TourHighlight), findsOneWidget);
    });
  });

  group('Texte', () {
    testWidgets('alle Beschriftungen kommen auf Deutsch aus AppStrings', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Überspringen'), findsOneWidget);
      expect(find.text('Tipp irgendwo für weiter'), findsOneWidget);

      await goToStep(tester, 5);
      expect(find.text('SCHRITT 5 VON 9'), findsOneWidget);
      expect(find.text('Dein Stadttagebuch.'), findsOneWidget);
    });

    testWidgets('ein Sprachwechsel schlägt durch', (tester) async {
      await pumpApp(tester, language: AppLanguage.en);

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Tap anywhere to continue'), findsOneWidget);
      expect(find.text('"We only see\nwhat we know."'), findsOneWidget);

      await goToStep(tester, 5);
      expect(find.text('STEP 5 OF 9'), findsOneWidget);
      expect(find.text('Your travel journal.'), findsOneWidget);
    });

    testWidgets('die Meta-Zeile bleibt auch auf Englisch deutsch, wie in der '
        'Quelle', (tester) async {
      // Offener Punkt, absichtlich festgenagelt statt stillschweigend
      // repariert: die Quelle schreibt beide Meta-Zeilen hart in das
      // `STEPS`-Array und übersetzt sie nicht. Ein Eintrag in
      // `app_strings_supplement.dart` wäre nach E-39 der richtige Weg und
      // braucht eine Freigabe. Bricht dieser Test, ist die Freigabe erteilt
      // worden und der Test gehört umgeschrieben.
      await pumpApp(tester, language: AppLanguage.en);
      await goToStep(tester, TourSteps.count);

      expect(find.text('PUSH AUS DER HOSENTASCHE'), findsOneWidget);
    });

    testWidgets('ein Zeilenumbruch im Titel bricht wirklich um', (
      tester,
    ) async {
      // Die Quelle zerlegt den Titel an `\n` und rendert jede Zeile als
      // eigenes `div` (`screen-tour.jsx:358-360`). Geprüft wird deshalb das
      // gerenderte Ergebnis und nicht die Zeichenkette: ein `Text` ohne
      // Umbruchbehandlung sähe im String genauso aus.
      const title = '»Man sieht nur,\nwas man weiß.«';
      await pumpApp(tester);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(TourHeroView),
          matching: find.text(title),
        ),
      );

      // `getBoxesForSelection` liefert je Zeile ein Rechteck. Zwei Rechtecke
      // über den ganzen Text heißen: zwei gerenderte Zeilen.
      expect(
        paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: title.length),
        ),
        hasLength(2),
      );
      // Und der Umbruch sitzt am Steuerzeichen und nicht irgendwo im
      // Fließsatz: die erste Hälfte belegt genau eine Zeile.
      expect(
        paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: title.indexOf('\n')),
        ),
        hasLength(1),
      );
      // Unabhängige Gegenprobe über die Höhe: zwei Zeilen zu 38 mal 1.05.
      expect(paragraph.size.height, closeTo(2 * 38 * 1.05, 1.5));
    });
  });

  group('Maße', () {
    // Fund 1 der Review von Schritt 11: `TourBubble` wuchs bei großer
    // Systemschrift auf einem kleinen Gerät lautlos unter den Bildschirmrand,
    // der `Stack` clippt ohne jede Überlauf-Meldung und
    // `tester.takeException()` blieb `null`. Deshalb hier eine echte
    // Rechteck- und Erreichbarkeitsprüfung statt nur der Abwesenheit einer
    // Ausnahme, siehe `test/features/identity/presentation/pages/signup_page_test.dart`,
    // Gruppe "Maße".
    const smallDevice = Size(375, 667);

    // Vier eigene Tests und keine Schleife in einem: eine Schleife meldet nur,
    // dass irgendeine Kombination scheitert, und man sieht nicht welche.
    for (final scale in <double>[1, 2]) {
      for (final size in <Size>[smallDevice, Size(360, 640)]) {
        final label =
            'Skalierung $scale auf ${size.width.toInt()}x'
            '${size.height.toInt()}';
        testWidgets(
          '$label: keine Blase reicht unter den Bildschirmrand oder über '
          'den Tipp-Hinweis',
          (tester) async {
            useTextScale(tester, scale);
            await pumpApp(tester, size: size);

            // Schritt 1 ist ein Hero-Schritt ohne Blase, deshalb ungeprüft;
            // die Schleife tippt sich trotzdem durch alle neun, damit auch
            // Schritt 9 (ebenfalls Hero) am Ende erreicht wird.
            for (var number = 1; number <= TourSteps.count; number++) {
              final bubbleFinder = find.byType(TourBubble);
              if (bubbleFinder.evaluate().isNotEmpty) {
                final where = '$label, Schritt $number';
                final rect = tester.getRect(bubbleFinder);
                final tapHintTop = tester.getRect(find.byType(TourTapHint)).top;

                expect(
                  rect.bottom,
                  lessThanOrEqualTo(size.height),
                  reason: '$where: unter dem Bildschirmrand',
                );
                expect(
                  rect.bottom,
                  lessThanOrEqualTo(tapHintTop),
                  reason: '$where: über dem Tipp-Hinweis',
                );
                expect(tester.takeException(), isNull, reason: where);
              }

              if (number < TourSteps.count) {
                await tapScrim(tester);
              }
            }
          },
        );
      }
    }

    testWidgets(
      'bei Skalierung 2.0 auf einem kleinen Gerät bleibt der Fließtext von '
      'Schritt 3 über Scrollen erreichbar, statt lautlos abgeschnitten zu '
      'werden',
      (tester) async {
        // Wortwörtlich `tour.step3.body` auf Deutsch, dieselbe Kombination
        // wie in der Sonde der Review.
        const body =
            'Die kleine Figur ist dein Avatar — sie schaut dorthin, wo du '
            'dein Handy hinhältst. Wie ein lebender Kompass.';

        useTextScale(tester, 2.0);
        await pumpApp(tester, size: smallDevice);
        await goToStep(tester, 3);

        final bubbleFinder = find.byType(TourBubble);
        // `skipOffstage: false`, weil der Text nach dem Scrollen außerhalb
        // des sichtbaren Ausschnitts liegt, aber weiterhin gebaut ist: er
        // steckt in einem `SingleChildScrollView`, nicht in einem
        // `Offstage`.
        final bodyFinder = find.descendant(
          of: bubbleFinder,
          matching: find.text(body, skipOffstage: false),
        );
        expect(bodyFinder, findsOneWidget);

        final bubbleRect = tester.getRect(bubbleFinder);
        final paragraph = tester.renderObject<RenderParagraph>(bodyFinder);

        // Das letzte Zeichen des Fließtexts, als Rechteck in Bildschirm-
        // koordinaten. `getBoxesForSelection` liefert das Rechteck relativ
        // zum Absatz, `localToGlobal` übersetzt es unter Berücksichtigung des
        // aktuellen Scrollversatzes.
        Rect lastCharacterRect() {
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: body.length - 1,
              extentOffset: body.length,
            ),
          );
          final box = boxes.last.toRect();
          return Rect.fromPoints(
            paragraph.localToGlobal(box.topLeft),
            paragraph.localToGlobal(box.bottomRight),
          );
        }

        final scrollable = find.descendant(
          of: bubbleFinder,
          matching: find.byType(Scrollable),
        );
        expect(
          scrollable,
          findsOneWidget,
          reason:
              'ohne Scrollable wäre der Inhalt bei dieser Kombination wieder '
              'stillschweigend abgeschnitten',
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(
          position.maxScrollExtent,
          greaterThan(0),
          reason:
              'Schritt 3 hat bei Skalierung 2.0 auf $smallDevice mehr Inhalt '
              'als Platz, sonst prüfte dieser Test nichts',
        );

        // Vor dem Scrollen liegt das letzte Zeichen unterhalb der Blase,
        // also außerhalb des sichtbaren Bereichs: genau das ist der Defekt
        // aus Fund 1, hier als Gegenprobe reproduziert.
        expect(
          lastCharacterRect().top,
          greaterThan(bubbleRect.bottom),
          reason: 'vor dem Scrollen ist das Textende noch nicht erreichbar',
        );

        position.jumpTo(position.maxScrollExtent);
        await tester.pump();

        // Nach dem Scrollen liegt es innerhalb der Blase, ist also
        // tatsächlich erreichbar und nicht nur theoretisch vorhanden.
        final afterScroll = lastCharacterRect();
        expect(
          afterScroll.bottom,
          lessThanOrEqualTo(bubbleRect.bottom + 0.5),
          reason: 'nach dem Scrollen muss das Textende sichtbar sein',
        );
        expect(afterScroll.top, greaterThanOrEqualTo(bubbleRect.top - 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
