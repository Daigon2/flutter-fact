import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/onboarding/onboarding_providers.dart';
import 'package:fact_app/app/onboarding/tour_store.dart';
import 'package:fact_app/app/shell/floating_tab_bar.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Die Anker der App-Shell und das Verhalten eines Ankers in einem inaktiven
/// Zweig.
void main() {
  AnchorRegistry registryOf(WidgetTester tester) {
    final scope = tester.element(find.byType(AnchorScope));
    late AnchorRegistry found;
    scope.visitChildElements((element) {
      found = AnchorScope.maybeOf(element)!;
    });
    return found;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(AppLanguage.de),
          ),
          // Vorbedingung, keine Erwartung: ohne diese Überschreibung schickt
          // die Weiche in `route_guards.dart` die App auf den Startbildschirm,
          // und die Tab-Leiste existierte gar nicht.
          firstLaunchStoreProvider.overrideWithValue(
            InMemoryFirstLaunchStore(hasLaunched: true),
          ),
          // Vorbedingung, keine Erwartung: ohne diese Überschreibung
          // liegt das Tutorial-Overlay über der Shell und verschluckt jeden
          // Tipp auf die Tab-Leiste. Das Flag ist von `fact_has_launched`
          // unabhängig, ein zweites Override reicht also nicht.
          tourStoreProvider.overrideWithValue(
            InMemoryTourStore(hasSeenTour: true),
          ),
        ],
        child: const FactApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Tab-Anker in der echten Shell', () {
    testWidgets('alle vier Tabs sind unter ihrem PWA-Namen auffindbar', (
      tester,
    ) async {
      await pumpApp(tester);

      // Die vier Kartenanker stehen mit in der Liste, weil der Zweig `/map`
      // der Startzweig ist und sein Top-Chrome sich beim Aufbau anmeldet.
      // Absichtlich die vollständige Menge und keine Teilmengenprüfung: eine
      // unerwartete Anmeldung ist genauso ein Fund wie eine fehlende.
      expect(registryOf(tester).debugRegisteredIds, <AnchorId>{
        const AnchorId('tab-modus'),
        const AnchorId('tab-wallet'),
        const AnchorId('tab-challenge'),
        const AnchorId('tab-profil'),
        const AnchorId('coins'),
        const AnchorId('mode-fact-finder'),
        const AnchorId('mode-tour'),
        const AnchorId('compass'),
      });
    });

    testWidgets('das Rechteck deckt den ganzen Tab-Knopf ab', (tester) async {
      await pumpApp(tester);
      final registry = registryOf(tester);

      final wallet = registry.rectOf(ShellTab.collection.anchorId)!;
      final challenge = registry.rectOf(ShellTab.challenges.anchorId)!;

      // Vier gleich breite Knöpfe in einer 800 Pixel breiten Testansicht,
      // abzüglich 2 x 12 Seitenabstand der Leiste, 2 x 1 Rahmen und
      // 2 x 6 Innenabstand: (800 - 24 - 2 - 12) / 4 = 190,5.
      expect(wallet.width, closeTo(190.5, 0.01));
      expect(challenge.width, closeTo(190.5, 0.01));
      // Nebeneinander, in der Reihenfolge von `ShellTab`.
      expect(challenge.left, closeTo(wallet.right, 0.01));
      expect(wallet.top, challenge.top);
    });

    testWidgets('ein Tabwechsel lässt die Tab-Anker auflösbar', (tester) async {
      // Die Leiste liegt außerhalb der Zweige, also außerhalb des
      // `IndexedStack`. Ein Wechsel darf ihre Anker deshalb weder abmelden noch
      // unsichtbar machen. Ohne diese Zusicherung würde eine spätere
      // Verschiebung der Leiste in einen Zweig unbemerkt bleiben.
      await pumpApp(tester);
      final registry = registryOf(tester);
      final vorher = registry.rectOf(ShellTab.challenges.anchorId);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<StatefulNavigationShell>(
              find.byType(StatefulNavigationShell),
            )
            .currentIndex,
        ShellTab.profile.index,
      );
      expect(registry.rectOf(ShellTab.challenges.anchorId), vorher);
    });

    testWidgets('die Anker sitzen auf den Knöpfen der Leiste', (tester) async {
      await pumpApp(tester);
      final registry = registryOf(tester);
      final leiste = tester.getRect(find.byType(FloatingTabBar));

      for (final tab in ShellTab.values) {
        final rect = registry.rectOf(tab.anchorId)!;
        expect(
          leiste.inflate(1).contains(rect.center),
          isTrue,
          reason: '${tab.anchorId} liegt außerhalb der Tab-Leiste',
        );
      }
    });
  });

  group('Degradation in der echten App', () {
    testWidgets('ein noch nicht gebauter Anker liefert still null, statt '
        'anzuschlagen', (tester) async {
      // Das prüft die Verdrahtung in `lib/app/app.dart`: der Scope bekommt dort
      // `DiscoveryAnchors.knownMissing`. Ohne diese Übergabe schlüge der
      // `assert` in `AnchorRegistry.rectOf` bei jedem ungebauten Anker an, und
      // das Tutorial wäre in Debug nicht benutzbar. Eine Mutationsprobe hat
      // gezeigt, dass das sonst keine Zusicherung bemerkt.
      await pumpApp(tester);

      for (final anchor in DiscoveryAnchors.knownMissing) {
        expect(
          registryOf(tester).rectOf(anchor),
          isNull,
          reason: '${anchor.value} ist heute nicht gebaut',
        );
      }
    });

    testWidgets('ein gebauter Kartenanker liefert dagegen ein Rechteck', (
      tester,
    ) async {
      // Die Gegenrichtung: ohne sie bliebe offen, ob der Test darüber nur
      // deshalb grün ist, weil überhaupt nichts auflöst.
      await pumpApp(tester);

      for (final anchor in <AnchorId>[
        DiscoveryAnchors.coins,
        DiscoveryAnchors.modeFactFinder,
        DiscoveryAnchors.modeTour,
        DiscoveryAnchors.compass,
      ]) {
        expect(
          registryOf(tester).rectOf(anchor),
          isNotNull,
          reason: '${anchor.value} ist gebaut',
        );
      }
    });

    testWidgets('ein unbekannter Anker schlägt in der echten App an', (
      tester,
    ) async {
      // Die Gegenprobe: der Tippfehler-Fall darf nicht mit durchrutschen. Wäre
      // die Liste zu weit oder der `assert` wirkungslos, käme hier still `null`
      // heraus.
      await pumpApp(tester);

      expect(
        () => registryOf(tester).rectOf(const AnchorId('tab-collection')),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Anker in einem inaktiven Zweig', () {
    const inBranch = AnchorId('probe-in-zweig');
    final targetKey = GlobalKey();

    /// Derselbe Aufbau wie die echte Shell: `StatefulShellRouteData.$route`
    /// erzeugt ein `StatefulShellRoute.indexedStack`
    /// (`go_router/lib/src/route_data.dart:411`). Der Unterschied ist nur, dass
    /// hier ein Anker **innerhalb** eines Zweiges sitzt. Seit dem Top-Chrome
    /// gibt es das auch in der echten App: die vier Tab-Anker liegen in der
    /// Leiste, die vier Anker des Kartenbildschirms im Zweig `/map`. Dieser
    /// Aufbau bleibt trotzdem eigenständig, weil er den Zweigwechsel isoliert
    /// prüft.
    Widget buildShellApp() {
      final router = GoRouter(
        initialLocation: '/zweig-a',
        routes: <RouteBase>[
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => navigationShell,
            branches: <StatefulShellBranch>[
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: '/zweig-a',
                    builder: (context, state) => Align(
                      alignment: Alignment.topLeft,
                      child: AnchorTarget(
                        anchorId: inBranch,
                        child: SizedBox(key: targetKey, width: 42, height: 30),
                      ),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: '/zweig-b',
                    builder: (context, state) => const SizedBox.expand(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      return MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            AnchorScope(child: child ?? const SizedBox.shrink()),
      );
    }

    testWidgets('bleibt angemeldet und ausgelegt, liefert aber kein Rechteck', (
      tester,
    ) async {
      await tester.pumpWidget(buildShellApp());
      await tester.pumpAndSettle();
      final registry = registryOf(tester);

      final imAktivenZweig = registry.rectOf(inBranch);
      expect(imAktivenZweig, isNotNull);

      final router = GoRouter.of(tester.element(find.byType(SizedBox).first));
      router.go('/zweig-b');
      await tester.pumpAndSettle();

      // Der Zweig lebt weiter: `StatefulShellRoute` legt ihn nur beiseite.
      expect(registry.debugRegisteredIds, contains(inBranch));

      final box = targetKey.currentContext!.findRenderObject()! as RenderBox;
      expect(box.attached, isTrue);
      expect(box.hasSize, isTrue, reason: 'RenderOffstage legt sein Kind aus');

      // Und genau das ist die Falle: die rohe Rechnung liefert dasselbe
      // plausible Rechteck wie im aktiven Zweig, obwohl nichts davon zu sehen
      // ist. `getTransformTo` ignoriert `paintsChild` ausdrücklich
      // (`rendering/object.dart:3660-3662`).
      final frame = tester.renderObject<RenderBox>(find.byType(AnchorScope));
      final roh = MatrixUtils.transformRect(
        box.getTransformTo(frame),
        Offset.zero & box.size,
      );
      expect(roh, imAktivenZweig);

      // Der Sichtbarkeitslauf in `rectOf` ist der Unterschied.
      expect(registry.rectOf(inBranch), isNull);
    });

    testWidgets('nach der Rückkehr in den Zweig gibt es das Rechteck wieder', (
      tester,
    ) async {
      await tester.pumpWidget(buildShellApp());
      await tester.pumpAndSettle();
      final registry = registryOf(tester);
      final router = GoRouter.of(tester.element(find.byType(SizedBox).first));

      router.go('/zweig-b');
      await tester.pumpAndSettle();
      expect(registry.rectOf(inBranch), isNull);

      router.go('/zweig-a');
      await tester.pumpAndSettle();

      expect(registry.rectOf(inBranch), const Rect.fromLTWH(0, 0, 42, 30));
    });
  });
}
