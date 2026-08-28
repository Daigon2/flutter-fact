import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Kartenbildschirm mit seinem Top-Chrome.
///
/// Gegenstand ist hier ausschließlich die Verdrahtung: welche Werte der
/// Bildschirm einsetzt, solange die besitzenden Domänen fehlen, und dass der
/// Modus-Umschalter wirklich schaltet. Die Maße stehen im Test des Chrome.
void main() {
  Future<void> pumpPage(WidgetTester tester, {ProviderContainer? container}) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container:
            container ??
            ProviderContainer(
              overrides: [
                languagePreferenceStoreProvider.overrideWithValue(
                  InMemoryLanguagePreferenceStore(),
                ),
              ],
            ),
        child: MaterialApp(
          theme: FactTheme.light(),
          home: AnchorScope(
            knownMissingAnchors: DiscoveryAnchors.knownMissing,
            child: const Scaffold(body: MapPage()),
          ),
        ),
      ),
    );
  }

  Finder anchorOf(AnchorId id) => find.byWidgetPredicate(
    (widget) => widget is AnchorTarget && widget.anchorId == id,
  );

  testWidgets('zeigt das Top-Chrome über einer Platzhalterfläche', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(MapTopChrome), findsOneWidget);
    // Und die vier gebauten Anker sind da, also degradiert das Tutorial auf
    // diesem Bildschirm nicht mehr.
    for (final anchor in <AnchorId>[
      DiscoveryAnchors.coins,
      DiscoveryAnchors.modeFactFinder,
      DiscoveryAnchors.modeTour,
      DiscoveryAnchors.compass,
    ]) {
      expect(anchorOf(anchor), findsOneWidget, reason: anchor.value);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('setzt die Platzhalter der noch fehlenden Domänen ein', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    final chrome = tester.widget<MapTopChrome>(find.byType(MapTopChrome));
    // Keine erfundenen Zahlen: alle vier sind der Zustand, den die PWA bei
    // leerem Speicher selbst anzeigt, siehe Kommentar in `map_page.dart`.
    expect(chrome.coins, 0);
    expect(chrome.level, 1);
    expect(chrome.levelPercent, 0);
    expect(chrome.cityName, 'München');
    // Sichtbar und nicht nur gesetzt.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('München'), findsOneWidget);
  });

  testWidgets('reicht keinen Karten-Rückruf durch, solange es keine Karte '
      'gibt', (tester) async {
    // Sonst sähe ein späterer Leser einen verdrahteten Knopf, der nichts tut.
    await pumpPage(tester);
    await tester.pumpAndSettle();

    final chrome = tester.widget<MapTopChrome>(find.byType(MapTopChrome));
    expect(chrome.onCityTap, isNull);
    expect(chrome.onCompassTap, isNull);
    expect(chrome.onCompassLongPress, isNull);
    expect(chrome.bearingDegrees, 0);
    expect(chrome.isDark, isFalse);
  });

  testWidgets('ein Tipp auf Tour schaltet den Modus wirklich um', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await pumpPage(tester, container: container);
    await tester.pumpAndSettle();

    expect(container.read(mapModeProvider), MapMode.factFinder);

    await tester.tap(anchorOf(DiscoveryAnchors.modeTour));
    await tester.pumpAndSettle();

    expect(container.read(mapModeProvider), MapMode.tour);
    expect(
      tester.widget<MapTopChrome>(find.byType(MapTopChrome)).mode,
      MapMode.tour,
      reason: 'die Oberfläche folgt dem Zustand',
    );
  });
}
