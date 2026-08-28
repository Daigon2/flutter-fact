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

/// Der Kartenbildschirm mit seinem Top-Chrome über der Karte.
///
/// Gegenstand ist hier ausschließlich die Verdrahtung: welche Werte der
/// Bildschirm einsetzt, solange die besitzenden Domänen fehlen, dass die
/// Kartenfläche unter dem Chrome liegt, und dass der Modus-Umschalter wirklich
/// schaltet. Die Maße stehen im Test des Chrome.
///
/// **Hier steht kein `MapSurface`, sondern ein Stellvertreter.** Regel 18
/// verbietet `features/discovery` den Import von `map/presentation/`, und ein
/// Test, der ihn doch nimmt, holt genau die Abhängigkeit zurück, die die Regel
/// fernhält; das Prüfskript sieht es nicht, weil seine Feature-Regel an
/// `^lib/features/` hängt und `test/` nicht darunter fällt. Der Stellvertreter
/// misst außerdem **mehr** als vorher: `isA<MapSurface>()` prüft einen Typ,
/// `identical` prüft die Durchreiche. Dass die echte Karte im Baum landet,
/// gehört zum Adapter und steht in `test/app/routing/app_routes_test.dart`.
///
/// Nebenbei fällt eine Fehlerquelle weg, an der nichts geschrieben stand: die
/// echte Fläche lud in jedem dieser Tests den gebackenen Stil, und `rootBundle`
/// cacht das `Future`. Der erste Test, der `pumpAndSettle` vergisst, hätte die
/// folgenden mit „Bad state: No element" umgerissen.
///
/// Was der Host tut, prüft `test/map/presentation/`.
void main() {
  /// Der Stellvertreter der Kartenfläche.
  ///
  /// **Nicht `const`:** Dart kanonisiert konstante Ausdrücke, und ein
  /// `identical` gegen einen const-Stellvertreter wäre auch dann grün, wenn
  /// `MapPage` sich selbst ein gleich geschriebenes Widget baute.
  final Widget mapSurfaceStandIn = Container(
    key: const ValueKey<String>('kartenflaeche'),
  );

  ProviderContainer newContainer() {
    // **Mit `addTearDown`, und das ist seit Schritt 12 keine Kosmetik mehr:**
    // an diesem Container hängt jetzt eine `MapHostRegistry`, deren
    // `ref.onDispose` sonst nie läuft. Ihr `StreamController` bliebe je Test
    // offen.
    final container = ProviderContainer(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpPage(WidgetTester tester, {ProviderContainer? container}) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container ?? newContainer(),
        child: MaterialApp(
          theme: FactTheme.light(),
          home: AnchorScope(
            knownMissingAnchors: DiscoveryAnchors.knownMissing,
            child: Scaffold(
              body: MapPage(
                // Dieselbe Zusammensetzung wie in `MapRoute.build`, dem
                // Kompositions-Adapter auf App-Ebene: `discovery` darf
                // `map/presentation/` nicht selbst importieren (Regel 18).
                mapSurface: mapSurfaceStandIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder anchorOf(AnchorId id) => find.byWidgetPredicate(
    (widget) => widget is AnchorTarget && widget.anchorId == id,
  );

  testWidgets('zeigt das Top-Chrome über der Kartenfläche', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(MapTopChrome), findsOneWidget);
    expect(find.byWidget(mapSurfaceStandIn), findsOneWidget);
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

  testWidgets('lässt die Karte unten und das Chrome oben liegen', (
    tester,
  ) async {
    // Die Reihenfolge im `Stack` ist die Zeichenreihenfolge. Stünde die Karte
    // oben, verdeckte sie Münzen, Stadt-Pille und Kompass vollständig, und
    // kein Tipp käme mehr an.
    await pumpPage(tester);
    await tester.pumpAndSettle();

    final Stack stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byWidget(mapSurfaceStandIn),
            matching: find.byType(Stack),
          )
          .first,
    );
    // `identical` und nicht `isA`: geprüft wird die Durchreiche, nicht der
    // Typ. Ein `MapPage`, das sich seine Fläche selbst baute, käme hier
    // durch, solange sie nur denselben Typ hätte.
    expect(identical(stack.children.first, mapSurfaceStandIn), isTrue);
    expect(stack.children.last, isA<MapTopChrome>());
  });

  testWidgets('reicht die drei Kamera-Gesten noch nicht durch', (tester) async {
    // Die Karte ist da, die Gesten gehören zu den Schritten 13 und 14. Ein
    // halb verdrahteter Kompass wäre schlechter als ein sichtbar untätiger.
    await pumpPage(tester);
    await tester.pumpAndSettle();

    final chrome = tester.widget<MapTopChrome>(find.byType(MapTopChrome));
    expect(chrome.onCityTap, isNull);
    expect(chrome.onCompassTap, isNull);
    expect(chrome.onCompassLongPress, isNull);
    expect(chrome.bearingDegrees, 0);
    expect(chrome.isDark, isFalse);
  });

  test('die Startkamera ist die Rückfallkamera der Quelle', () {
    // **Sie war nirgends festgenagelt.** `zoom: 14, pitch: 35` auf `9` und `3`
    // zu ändern überlebte die ganze Suite, und der Flächen-Test schrieb
    // dieselben Zahlen noch einmal als eigenes Literal hin, statt diese
    // Konstante zu benutzen. Jetzt gibt es eine Quelle und eine Prüfung.
    //
    // `screen-map.jsx:1668` nimmt `cachedPos || { lat: 48.1351, lng: 11.5820 }`
    // und setzt damit den Mittelpunkt, `:1673-1675` setzen Zoom, Neigung und
    // Blickrichtung.
    expect(MapPage.placeholderCamera.center.latitude, 48.1351);
    expect(MapPage.placeholderCamera.center.longitude, 11.582);
    expect(MapPage.placeholderCamera.zoom, 14);
    expect(MapPage.placeholderCamera.pitch, 35);
    expect(MapPage.placeholderCamera.bearing, 0);
  });

  testWidgets('ein Tipp auf Tour schaltet den Modus wirklich um', (
    tester,
  ) async {
    final container = newContainer();
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
