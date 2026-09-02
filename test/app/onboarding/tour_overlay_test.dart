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
import 'package:fact_app/app/shell/floating_tab_bar.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
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
      // Nur noch der Avatar-Marker (3): Schritt 18 hängt an E-10. Schritt 2
      // (Ballon) meldet sich seit `discovery_balloon_anchor.dart` selbst an,
      // hier ohne Karte über das Ersatzrechteck, siehe dort. Die Schritte 4,
      // 6 und 8 zeigen auf Coin-Pille, Tour-Knopf und Kompass, und die meldet
      // das Top-Chrome des Kartenbildschirms seit Schritt 19 an.
      const degrading = <int>[3];
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
      // Und die zwei bekannt fehlenden fehlen wirklich, statt zufällig da zu
      // sein.
      for (final anchor in DiscoveryAnchors.knownMissing) {
        expect(registryOf(tester).rectOf(anchor), isNull, reason: anchor.value);
      }
      // Die fünf gebauten lösen umgekehrt wirklich auf. Ohne diese Zeile
      // bliebe offen, ob `degrading` oben nur deshalb kurz ist, weil der
      // Pfeil aus einem anderen Grund gezeichnet wird.
      for (final anchor in <AnchorId>[
        DiscoveryAnchors.balloon,
        DiscoveryAnchors.coins,
        DiscoveryAnchors.modeFactFinder,
        DiscoveryAnchors.modeTour,
        DiscoveryAnchors.compass,
      ]) {
        expect(
          registryOf(tester).rectOf(anchor),
          isNotNull,
          reason: anchor.value,
        );
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

    testWidgets('die drei Kartenanker liegen dort, wo ihr Element sichtbar '
        'ist', (tester) async {
      // Der eigentliche Gewinn von Schritt 19, und zwar gemessen statt
      // gezählt: "der Pfeil ist da" wäre auch dann wahr, wenn die Registry
      // irgendein Rechteck geliefert hätte. Hier deckt der Ring in jedem der
      // drei Schritte genau das Element ab, das die Quelle nennt.
      // In **einem** Durchlauf, aus demselben Grund wie beim
      // Neun-Schritte-Test: ein zweites `pumpWidget` setzt den Schrittzähler
      // des Overlays nicht zurück.
      await pumpApp(tester);

      const targets = <int, AnchorId>{
        4: DiscoveryAnchors.coins,
        6: DiscoveryAnchors.modeTour,
        8: DiscoveryAnchors.compass,
      };
      var current = 1;
      for (final number in targets.keys) {
        for (; current < number; current++) {
          await tapScrim(tester);
        }
        final where = 'Schritt $number, Anker ${targets[number]!.value}';
        final element = tester.getRect(anchorOf(targets[number]!));
        expect(
          tester.getRect(find.byType(TourHighlight)),
          element.inflate(5),
          reason: where,
        );
        expect(find.byType(TourArrow), findsOneWidget, reason: where);
      }
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

    testWidgets('die Meta-Zeile ist auf Englisch übersetzt', (tester) async {
      // Die Quelle schreibt beide Meta-Zeilen hart in das `STEPS`-Array und
      // übersetzt sie nicht; bis zum 02.09.2026 zeigte die Karte deshalb
      // auch im englischen Modus `PUSH AUS DER HOSENTASCHE` (E-61). Der
      // Eigentümer hat diese Begründung als gemessenen Defekt der Quelle
      // aufgehoben, `tour.step9.meta` trägt seither einen eigenen
      // englischen Wortlaut. `tour.step1.meta` bleibt dagegen bewusst
      // gleich: „— GOETHE" ist eine Namensnennung, kein zu übersetzender
      // Satz.
      await pumpApp(tester, language: AppLanguage.en);
      await goToStep(tester, TourSteps.count);

      expect(find.text('A PUSH FROM YOUR POCKET'), findsOneWidget);
      expect(find.text('PUSH AUS DER HOSENTASCHE'), findsNothing);
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

  group('Systemleisten', () {
    // Am 28.08.2026 am Emulator gesehen: "Ueberspringen" lag ueber Uhrzeit und
    // Funkanzeige, der Tipp-Hinweis und die Punktreihe sassen in der
    // Gestenleiste. Kein Test hat es gemeldet, und der Grund ist der
    // Testrahmen selbst: `tester.view.padding` ist standardmaessig null, es
    // gibt dort also gar keine Systemleiste, gegen die etwas stossen koennte.
    //
    // Oben bleibt es ein Zuschlag: die Quelle misst ihre 18 Pixel
    // **innerhalb** der `.app-frame`, und die traegt laut `index.html:101-107`
    // bereits `padding-top` aus `env(safe-area-inset-top)`. Ein `Positioned`
    // misst dagegen ab der Bildschirmkante.
    //
    // Unten gibt es diesen Zuschlag seit dem 28.08.2026 nicht mehr, und das
    // ist kein Rueckschritt: das untere Chrome haengt jetzt an der gemessenen
    // Oberkante der Tab-Leiste, und die haelt selbst `max(14, Safe Area)`
    // Abstand nach unten. Die Gestenleiste steckt also im gemessenen Wert.
    // Ein eigener Zuschlag waere doppelt.
    const statusBar = 141.0;
    const gestureBar = 48.0;

    testWidgets('das Chrome weicht Status- und Gestenleiste aus', (
      tester,
    ) async {
      useDeviceSurface(tester);
      tester.view.padding = const FakeViewPadding(
        top: statusBar * 3,
        bottom: gestureBar * 3,
      );
      addTearDown(tester.view.reset);
      useReducedMotion(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final screen = tester.getSize(find.byType(TourOverlay));
      final bar = tester.getRect(find.byType(FloatingTabBar));

      expect(
        tester.getRect(find.byType(TourSkipButton)).top,
        statusBar + TourSkipButton.inset,
        reason: 'Ueberspringen unter der Statusleiste',
      );
      // Vorbedingung der beiden folgenden Zusicherungen, keine Erwartung an
      // das Tutorial: die Leiste selbst weicht der Gestenleiste aus.
      expect(
        screen.height - bar.top,
        gestureBar + FloatingTabBar.nominalPillHeight,
        reason: 'Tab-Leiste in der Gestenleiste',
      );
      expect(
        screen.height - tester.getRect(find.byType(TourStepDots)).bottom,
        gestureBar +
            FloatingTabBar.nominalPillHeight +
            TourBottomChrome.dotsGap,
        reason: 'Punktreihe in der Gestenleiste oder in der Leiste',
      );
      expect(
        screen.height - tester.getRect(find.byType(TourTapHint)).bottom,
        gestureBar +
            FloatingTabBar.nominalPillHeight +
            TourBottomChrome.dotsGap +
            TourBottomChrome.gapToTapHint,
        reason: 'Tipp-Hinweis in der Gestenleiste oder in der Leiste',
      );
    });
  });

  group('Unteres Chrome ueber der Tab-Leiste', () {
    // Am 28.08.2026 vom Product Owner entschieden, in Kenntnis dessen, dass es
    // von der PWA abweicht: Punktreihe und Tipp-Hinweis liegen **ueber** der
    // Tab-Leiste. Die Quelle setzt beide auf `bottom: 24` und `bottom: 50`
    // (`screen-tour.jsx:310` und `:327`) und legt sie damit zwischen die
    // Tab-Symbole.
    //
    // Gemessen statt `takeException()`: eine Ueberlappung ist kein Ueberlauf.
    // `Stack` legt zwei Kinder ohne jede Meldung uebereinander, genau wie ein
    // Zeilenumbruch keiner ist. Nur ein Rechteckvergleich findet das.
    //
    // Die Hoehe der Leiste ist dabei der ganze Punkt: sie ist bei Skalierung
    // 1.0 genau 78 Pixel hoch und bei 2.0 schon 108, weil "Challenge"
    // umbricht. Eine feste Zahl im Chrome waere bei einer der beiden Groessen
    // falsch, deshalb misst `TourOverlay` die Leiste.
    for (final scale in <double>[1, 2]) {
      for (final size in <Size>[
        Size(360, 640),
        Size(375, 667),
        Size(390, 844),
      ]) {
        // Schritt 1 ist ein Hero-Schritt und fuellt den Bildschirm, Schritt 2
        // ein Blasen-Schritt. Das Chrome liegt auf beiden.
        for (final step in <int>[1, 2]) {
          final label =
              'Skalierung $scale auf ${size.width.toInt()}x'
              '${size.height.toInt()}, Schritt $step';
          testWidgets('$label: Punktreihe, Hinweis und Leiste ueberlappen '
              'sich nicht', (tester) async {
            useTextScale(tester, scale);
            await pumpApp(tester, size: size);
            await goToStep(tester, step);

            final rects = <String, Rect>{
              'Tab-Leiste': tester.getRect(find.byType(FloatingTabBar)),
              'Punktreihe': tester.getRect(find.byType(TourStepDots)),
              'Tipp-Hinweis': tester.getRect(find.byType(TourTapHint)),
            };

            // 1. Paarweise, damit die Meldung sagt, welche zwei es sind.
            final names = rects.keys.toList();
            for (var i = 0; i < names.length; i++) {
              for (var j = i + 1; j < names.length; j++) {
                final a = rects[names[i]]!;
                final b = rects[names[j]]!;
                expect(
                  a.overlaps(b),
                  isFalse,
                  reason: '$label: ${names[i]} $a ueberlappt ${names[j]} $b',
                );
              }
            }

            // 2. Und in der richtigen Reihenfolge. Ohne diese Zusicherung
            //    wuerde ein Chrome, das aus dem Bildschirm heraus nach unten
            //    rutscht, die Pruefung oben bestehen.
            expect(
              rects['Punktreihe']!.bottom,
              lessThanOrEqualTo(rects['Tab-Leiste']!.top),
              reason: '$label: Punktreihe nicht ueber der Leiste',
            );
            expect(
              rects['Tipp-Hinweis']!.bottom,
              lessThanOrEqualTo(rects['Punktreihe']!.top),
              reason: '$label: Tipp-Hinweis nicht ueber der Punktreihe',
            );

            // 3. Nichts haengt ausserhalb des Bildschirms.
            for (final entry in rects.entries) {
              expect(
                entry.value.top,
                greaterThanOrEqualTo(0),
                reason: '$label: ${entry.key} oben heraus',
              );
              expect(
                entry.value.bottom,
                lessThanOrEqualTo(size.height),
                reason: '$label: ${entry.key} unten heraus',
              );
            }
          });
        }
      }
    }

    testWidgets('der Abstand zwischen Punktreihe und Tipp-Hinweis bleibt der '
        'der Quelle', (tester) async {
      await pumpApp(tester);

      // 50 minus 24 aus `screen-tour.jsx:310` und `:327`. Nur der gemeinsame
      // Bezugspunkt darunter ist neu, der Abstand der beiden zueinander nicht.
      expect(
        tester.getRect(find.byType(TourStepDots)).bottom -
            tester.getRect(find.byType(TourTapHint)).bottom,
        TourBottomChrome.gapToTapHint,
      );
    });
  });

  group('Textstil', () {
    // Am 28.08.2026 auf dem Emulator gesehen, nicht im Test: **jeder** Text
    // des Overlays trug eine gelbe Doppellinie. Das ist Flutters Notsignal
    // fuer Text ohne `Material`-Vorfahren. Der `AppShell` daneben bringt sein
    // eigenes ueber sein `Scaffold` mit, das Geschwisterkind im `Stack` des
    // `OnboardingHost` erbt davon nichts.
    //
    // Warum 806 Zusicherungen das nicht gesehen haben: sie pruefen Text,
    // Rechtecke, Treffer und Umbrueche, aber keine einzige je die Dekoration.
    // `find.text` vergleicht Zeichenketten und interessiert sich nicht dafuer,
    // wie sie gemalt werden. Genau dieselbe Klasse Luecke wie "ein
    // Zeilenumbruch ist kein Overflow".
    for (final step in <int>[1, 2, 9]) {
      testWidgets('Schritt $step malt keinen Text mit Dekoration', (
        tester,
      ) async {
        await pumpApp(tester);
        await goToStep(tester, step);

        final paragraphs = tester
            .renderObjectList<RenderParagraph>(find.byType(RichText))
            .toList();
        expect(paragraphs, isNotEmpty, reason: 'nichts gemessen');

        for (final paragraph in paragraphs) {
          final decoration = paragraph.text.style?.decoration;
          expect(
            decoration == null || decoration == TextDecoration.none,
            isTrue,
            reason:
                'Text "${paragraph.text.toPlainText()}" traegt '
                '$decoration. Fehlt ein Material-Vorfahren?',
          );
        }
      });
    }

    // Die Behebung der Doppellinie hat sich am 28.08.2026 eine zweite Falle
    // eingehandelt, und die ist unauffälliger: ein `Material` ohne eigenen
    // `textStyle` vererbt `theme.textTheme.bodyMedium` an jeden Text darunter,
    // und darin steckt Materials Geometrie. Gemessen wurde am 29.08.2026 eine
    // Zeilenhöhe von 1.43 an vier Texten des Tutorials, die keine setzen:
    // der Meta-Zeile der Hero-Schritte, der Schrittanzeige der Blase,
    // "Überspringen" und dem Tipp-Hinweis. Die Laufweite kam nicht mit, weil
    // E-38 sie schon aus `ThemeData.typography` genommen hat; ohne E-38 wären
    // es beide.
    //
    // `screen-tour.jsx` gibt an keiner der vier Stellen eine `line-height` an
    // (`:286-306`, `:325-337`, `:383-390`, `:477-483`), und keine Regel im
    // Vorfahrenpfad tut es: `styles.css` kennt das Wort nicht, der einzige
    // Treffer in `index.html:96` gehört zum toten Splash. Der berechnete Wert
    // im Browser ist also `normal`, das sind die Metriken der Schrift, und in
    // Flutter heißt das `height: null`.

    /// Materials Geometrie, aus Flutter selbst gelesen statt abgetippt.
    ///
    /// Genau dieses `TextTheme` mischt das `Theme`-Widget beim Lokalisieren
    /// als Basis unter `textTheme` (siehe `FactTheme._withoutTracking`), und
    /// genau daraus speist sich `bodyMedium`. Ändert Flutter die Werte, folgt
    /// dieser Test ihnen, statt gegen eine veraltete Zahl grün zu bleiben.
    final materialGeometry = Typography.englishLike2021.bodyMedium!;

    /// Der wirksame Stil jedes Absatzes **des Overlays**, mit Klartext.
    ///
    /// Bewusst nur unterhalb von [TourOverlay]: die Shell darunter hängt an
    /// ihrem eigenen `Material` im `Scaffold` und ist hier nicht Gegenstand.
    List<(String, TextStyle?)> overlayStyles(WidgetTester tester) {
      return <(String, TextStyle?)>[
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.descendant(
            of: find.byType(TourOverlay),
            matching: find.byType(RichText),
          ),
        ))
          (paragraph.text.toPlainText(), paragraph.text.style),
      ];
    }

    /// Der wirksame Stil des Absatzes Nummer [at] eines Bauteils.
    ///
    /// Die Reihenfolge ist die des Baums und damit die der Quelle: in
    /// `TourHeroView` Titel, Fließtext, Meta, in `TourBubble` Schrittanzeige,
    /// Titel, Fließtext.
    TextStyle styleIn(WidgetTester tester, Finder part, {int at = 0}) {
      final paragraphs = tester
          .renderObjectList<RenderParagraph>(
            find.descendant(of: part, matching: find.byType(RichText)),
          )
          .toList();
      // `!`, weil ein Absatz ohne wirksamen Stil hier bereits der Defekt
      // wäre und die Meldung dann von der falschen Zeile käme.
      return paragraphs[at].text.style!;
    }

    for (var step = 1; step <= TourSteps.count; step++) {
      testWidgets('Schritt $step: kein Text erbt Materials Laufweite oder '
          'Zeilenhöhe', (tester) async {
        await pumpApp(tester);
        await goToStep(tester, step);

        final styles = overlayStyles(tester);
        // Ohne diese Zusicherung wäre eine leere Liste ein grüner Test.
        expect(
          styles,
          // Hero-Schritte: Titel, Fließtext, Meta, Überspringen, Hinweis.
          // Blasen-Schritte: Schrittanzeige, Titel, Fließtext plus dieselben
          // zwei Aufsaetze.
          hasLength(5),
          reason: 'erwartet: fünf Absätze, gemessen: $styles',
        );

        for (final (text, style) in styles) {
          expect(
            style?.height,
            isNot(materialGeometry.height),
            reason:
                'Text "$text" trägt Materials Zeilenhöhe. Fehlt am '
                '`Material` des OnboardingHost der Basisstil?',
          );
          expect(
            style?.letterSpacing,
            isNot(materialGeometry.letterSpacing),
            reason:
                'Text "$text" trägt Materials Laufweite. Fehlt am '
                '`Material` des OnboardingHost der Basisstil, oder ist E-38 '
                'aus `FactTheme` gefallen?',
          );
        }
      });
    }

    testWidgets('die vier Texte ohne `line-height` in der Quelle haben auch '
        'keine', (tester) async {
      // Der Gegenpart zur Zusicherung oben: dort steht, was nicht sein darf,
      // hier, was gelten muss. Ein Basisstil, der statt 1.43 irgendeine
      // andere fremde Zeilenhöhe durchreicht, käme oben durch.
      await pumpApp(tester);

      // Schritt 1, Hero: Titel, Fließtext, Meta-Zeile.
      final hero = find.byType(TourHeroView);
      // `lineHeight: 1.05`, `screen-tour.jsx:365-370`.
      expect(styleIn(tester, hero).height, 1.05);
      // `lineHeight: 1.45`, `:374-376`.
      expect(styleIn(tester, hero, at: 1).height, 1.45);
      // `:384-387` setzt Familie, Gewicht, Größe, Laufweite und Farbe und
      // **keine** `lineHeight`.
      expect(styleIn(tester, hero, at: 2).height, isNull);
      expect(
        styleIn(tester, hero, at: 2).letterSpacing,
        closeTo(11 * 0.22, 1e-9),
      );

      // `:293-295`, ebenfalls ohne `lineHeight` und ohne `letterSpacing`.
      expect(styleIn(tester, find.byType(TourSkipButton)).height, isNull);
      expect(
        styleIn(tester, find.byType(TourSkipButton)).letterSpacing,
        isNull,
      );

      // `:329-334`: `letterSpacing: '0.04em'`, keine `lineHeight`.
      expect(styleIn(tester, find.byType(TourTapHint)).height, isNull);
      expect(
        styleIn(tester, find.byType(TourTapHint)).letterSpacing,
        closeTo(11 * 0.04, 1e-9),
      );

      await goToStep(tester, 2);

      // Schritt 2, Blase: Schrittanzeige, Titel, Fließtext.
      final bubble = find.byType(TourBubble);
      // `:478-482` setzt `letterSpacing: '0.18em'` und keine `lineHeight`.
      expect(styleIn(tester, bubble).height, isNull);
      expect(styleIn(tester, bubble).letterSpacing, closeTo(10 * 0.18, 1e-9));
      // `lineHeight: 1.15`, `:485-489`.
      expect(styleIn(tester, bubble, at: 1).height, 1.15);
      // `lineHeight: 1.45`, `:496-498`.
      expect(styleIn(tester, bubble, at: 2).height, 1.45);
    });

    test('der Basisstil des Overlays gibt keine Geometrie vor', () {
      // Die Eigenschaft, aus der beide Zusicherungen oben folgen, direkt am
      // Stil: er darf Familie und Gewicht mitbringen, aber weder Größe noch
      // Zeilenhöhe noch Laufweite, denn all das steht in der Quelle am
      // einzelnen Element.
      final style = OnboardingHost.overlayTextStyle;

      expect(style.fontSize, isNull);
      expect(style.height, isNull);
      expect(style.letterSpacing, isNull);
      expect(style.fontFamily, FactFont.body);
      // Half-Leading wie in CSS, bewusst behalten und nicht Materials
      // Geschmack: `screen-tour.jsx` setzt vier `lineHeight`-Werte, und die
      // verteilt ein Browser je zur Hälfte über und unter den Text.
      expect(style.leadingDistribution, TextLeadingDistribution.even);
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
