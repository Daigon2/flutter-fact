import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Das Top-Chrome des Kartenbildschirms.
///
/// ## Gebaut wird über einem beliebigen Untergrund
///
/// Unter dem Chrome liegt hier eine einfarbige Fläche und keine Karte. Das ist
/// nicht Bequemlichkeit, sondern die Zusicherung: das Chrome darf vom
/// Karten-Host nichts wissen, das ist seit dem 28.08.2026 auch Regel 18.
/// Läuft dieser Test, ist bewiesen, dass es ohne Karte baut und misst.
///
/// ## Gemessen wird an Rechtecken, nicht an Ausnahmen
///
/// Ein `Stack` schneidet lautlos, und ein Zeilenumbruch ist kein Überlauf.
/// `tester.takeException()` ist deshalb überall die schwächste Zusicherung der
/// Datei und nirgends die einzige.
void main() {
  // Ohne die echten Schriften misst jede Zusicherung ein Layout, das es auf
  // keinem Gerät gibt, siehe `test/support/app_fonts.dart`.
  setUpAll(loadAppFonts);

  /// Das Rahmenmaß der PWA, `chrome.jsx:134-135`.
  void useSurface(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Über den `PlatformDispatcher` und **nicht** über eine eigene
  /// `MediaQuery`: die läge unter der von `pumpWidget` angelegten und würde
  /// `size` und `padding` auf null ziehen.
  void useTextScale(WidgetTester tester, double scale) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  final selected = <MapMode>[];
  var cityTaps = 0;
  var compassTaps = 0;
  var compassLongPresses = 0;

  setUp(() {
    selected.clear();
    cityTaps = 0;
    compassTaps = 0;
    compassLongPresses = 0;
  });

  Future<void> pumpChrome(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    AppLanguage language = AppLanguage.de,
    String cityName = 'München',
    int coins = 0,
    int level = 1,
    double levelPercent = 0,
    MapMode mode = MapMode.factFinder,
    bool tourReady = false,
    bool isCompassDead = false,
    bool isDark = false,
    double bearingDegrees = 0,
    bool withCallbacks = false,
    bool withAnchorScope = true,
  }) async {
    useSurface(tester, size: size);
    final chrome = MapTopChrome(
      cityName: cityName,
      coins: coins,
      level: level,
      levelPercent: levelPercent,
      mode: mode,
      tourReady: tourReady,
      isCompassDead: isCompassDead,
      isDark: isDark,
      bearingDegrees: bearingDegrees,
      onModeSelected: selected.add,
      onCityTap: withCallbacks ? () => cityTaps++ : null,
      onCompassTap: withCallbacks ? () => compassTaps++ : null,
      onCompassLongPress: withCallbacks ? () => compassLongPresses++ : null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
        ],
        child: MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Ein beliebiger Untergrund, ausdrücklich keine Karte.
              const ColoredBox(color: Color(0xFF445566)),
              if (withAnchorScope)
                AnchorScope(
                  knownMissingAnchors: DiscoveryAnchors.knownMissing,
                  child: chrome,
                )
              else
                chrome,
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder anchorOf(AnchorId id) => find.byWidgetPredicate(
    (widget) => widget is AnchorTarget && widget.anchorId == id,
  );

  AnchorRegistry registryOf(WidgetTester tester) {
    final scope = tester.element(find.byType(AnchorScope));
    late AnchorRegistry found;
    scope.visitChildElements((element) {
      found = AnchorScope.maybeOf(element)!;
    });
    return found;
  }

  /// Der Abstand der sicheren Fläche von oben. In dieser Testumgebung null,
  /// aber ausgerechnet statt angenommen: fiele er anders aus, wären alle
  /// `top`-Zusicherungen still um denselben Betrag verschoben.
  double safeTop(WidgetTester tester) =>
      tester.view.padding.top / tester.view.devicePixelRatio;

  group('Die vier Anker melden sich an', () {
    testWidgets('coins, mode-fact-finder, mode-tour und compass lösen auf', (
      tester,
    ) async {
      await pumpChrome(tester);

      final registry = registryOf(tester);
      for (final anchor in <AnchorId>[
        DiscoveryAnchors.coins,
        DiscoveryAnchors.modeFactFinder,
        DiscoveryAnchors.modeTour,
        DiscoveryAnchors.compass,
      ]) {
        final rect = registry.rectOf(anchor);
        expect(rect, isNotNull, reason: anchor.value);
        // Nicht nur "ein Rechteck", sondern **das** Rechteck des sichtbaren
        // Elements. Ein zufällig gelieferter Nullpunkt käme sonst durch.
        expect(rect, tester.getRect(anchorOf(anchor)), reason: anchor.value);
        expect(rect!.width, greaterThan(0), reason: anchor.value);
        expect(rect.height, greaterThan(0), reason: anchor.value);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('die Kennungen kommen aus DiscoveryAnchors, nicht aus der '
        'Hand', (tester) async {
      // Gegenprobe zur Verdrahtung: hier wird ausdrücklich mit einer frisch
      // getippten Zeichenkette gesucht. Weicht eine Konstante davon ab, fällt
      // es hier auf und nicht erst am stummen Tutorial.
      await pumpChrome(tester);

      for (final name in <String>[
        'coins',
        'mode-fact-finder',
        'mode-tour',
        'compass',
      ]) {
        expect(anchorOf(AnchorId(name)), findsOneWidget, reason: name);
      }
    });

    testWidgets('ohne AnchorScope baut das Chrome trotzdem', (tester) async {
      // `AnchorTarget` darf keinen Scope voraussetzen, sonst wäre jeder
      // Widget-Test eines Kartenbauteils an das Tutorial gekoppelt.
      await pumpChrome(tester, withAnchorScope: false);

      expect(find.byType(MapTopChrome), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Maße gegen die Quelle, Skalierung 1.0 auf 390 Pixeln', () {
    testWidgets('die Stadt-Pille sitzt auf 54 und 14', (tester) async {
      await pumpChrome(tester);

      final pill = tester.getRect(find.byType(MapCityPill));
      expect(pill.top, safeTop(tester) + MapTopChrome.cityTop);
      expect(pill.left, MapTopChrome.sideInset);
    });

    testWidgets('die Coin-Pille sitzt auf 60 und ist 32 hoch', (tester) async {
      await pumpChrome(tester);

      final pill = tester.getRect(anchorOf(DiscoveryAnchors.coins));
      expect(pill.top, safeTop(tester) + MapTopChrome.topRightColumnTop);
      expect(pill.right, 390 - MapTopChrome.sideInset);
      // 4 + 22 + 4 plus zwei mal ein Pixel Rahmen, `screen-map.jsx:713-717`.
      expect(pill.height, 32);
    });

    testWidgets('der Level-Ring ist 42 mal 42 und steht 6 unter der '
        'Coin-Pille', (tester) async {
      await pumpChrome(tester);

      final coin = tester.getRect(anchorOf(DiscoveryAnchors.coins));
      final badge = tester.getRect(find.byType(MapLevelBadge));
      expect(badge.size, const Size(42, 42));
      expect(badge.top - coin.bottom, MapTopRightColumn.coinToLevelGap);
      expect(badge.right, 390 - MapTopChrome.sideInset);
    });

    testWidgets('der Kompass landet auf genau 148, obwohl niemand ihn dorthin '
        'setzt', (tester) async {
      // Die schärfste Zusicherung dieser Datei. Die 148 der Quelle
      // (`screen-map.jsx:3152`) wird hier nicht gesetzt, sondern ergibt sich
      // aus Coin-Pille, Level-Ring und den beiden Abständen. Stimmt eine der
      // vier Zahlen nicht, wandert der Kompass, und niemand sähe es sonst.
      await pumpChrome(tester);

      final compass = tester.getRect(anchorOf(DiscoveryAnchors.compass));
      expect(compass.top, safeTop(tester) + MapTopChrome.compassTop);
      expect(compass.size, const Size(44, 44));
      expect(compass.right, 390 - MapTopChrome.sideInset);
    });

    testWidgets('alle Oberkanten zählen ab der sicheren Fläche, nicht ab der '
        'Gerätekante', (tester) async {
      // `index.html:101-107` setzt `padding-top: env(safe-area-inset-top)` am
      // **`body`**, die PWA rückt also den ganzen Rahmen ein. Ohne diese
      // Zusicherung säße das ganze Chrome auf einem Gerät mit Notch unter der
      // Uhr, und in der Testumgebung mit Padding 0 fiele es nie auf.
      useSurface(tester);
      tester.view.padding = const FakeViewPadding(top: 141 * 3);
      addTearDown(tester.view.reset);
      await pumpChrome(tester);

      expect(safeTop(tester), 141);
      expect(
        tester.getRect(find.byType(MapCityPill)).top,
        141 + MapTopChrome.cityTop,
      );
      expect(
        tester.getRect(anchorOf(DiscoveryAnchors.compass)).top,
        141 + MapTopChrome.compassTop,
      );
      // Links und rechts **nicht**: die Quelle setzt dort keinen Inset, und
      // `left: 14` zählt ab der echten Kante.
      expect(
        tester.getRect(find.byType(MapCityPill)).left,
        MapTopChrome.sideInset,
      );
    });

    testWidgets('der Modus-Umschalter sitzt auf 136 und mittig', (
      tester,
    ) async {
      await pumpChrome(tester);

      final toggle = tester.getRect(find.byType(MapModeToggle));
      expect(toggle.top, safeTop(tester) + MapTopChrome.modeToggleTop);
      expect(toggle.center.dx, closeTo(390 / 2, 0.01));
    });

    testWidgets('ein Modus-Knopf hat 7 mal 16 Innenabstand und 3 Abstand zum '
        'Nachbarn', (tester) async {
      await pumpChrome(tester);

      final toggle = tester.getRect(find.byType(MapModeToggle));
      final first = tester.getRect(anchorOf(DiscoveryAnchors.modeFactFinder));
      final second = tester.getRect(anchorOf(DiscoveryAnchors.modeTour));

      // `padding: 4` der Pille plus ein Pixel Rahmen, `:3209-3210`.
      expect(first.left - toggle.left, 5);
      expect(second.left - first.right, 3);
      expect(toggle.right - second.right, 5);

      // `padding: '7px 16px'` am Knopf, `:3220`.
      final label = tester.getRect(find.text('🔍 Fact Finder'));
      expect(label.left - first.left, 16);
      expect(first.right - label.right, 16);
    });
  });

  group('Farben und Schriften gegen die Quelle', () {
    testWidgets('die helle Fassung trägt die Werte aus screen-map.jsx', (
      tester,
    ) async {
      await pumpChrome(tester);

      const palette = MapChromePalette.light;
      expect(palette.background, const Color(0xEBFFF8EE));
      expect(palette.border, const Color(0x338C6428));
      expect(palette.text, const Color(0xFF1A1208));
      expect(palette.muted, const Color(0x801A1208));
      // Die Coin-Pille hat eine **eigene** Palette (`:687-689`) und ist im
      // hellen Zustand grünlich. Wer beide zusammenlegt, verliert das.
      expect(palette.coinPillBackground, const Color(0xEBF0FFF8));
      expect(palette.coinPillBackground, isNot(palette.background));
      expect(palette.coinPillBorder, const Color(0x4050A050));
    });

    testWidgets('die dunkle Fassung ebenfalls', (tester) async {
      await pumpChrome(tester, isDark: true);

      const palette = MapChromePalette.dark;
      expect(palette.background, const Color(0xDB120E0A));
      expect(palette.border, const Color(0x1FFFC878));
      expect(palette.text, const Color(0xFFF5F0E8));
      expect(palette.muted, const Color(0x73F5F0E8));
      expect(palette.modeActiveBackground, const Color(0xFFFFFFFF));
      expect(palette.modeActiveText, const Color(0xFF111111));
    });

    testWidgets('die Fassung schlägt bis in den Stadtnamen durch', (
      tester,
    ) async {
      // Ohne diese Zusicherung könnte die Palette stimmen und trotzdem
      // niemand sie benutzen.
      await pumpChrome(tester);
      final light = tester.widget<Text>(find.text('München')).style!;
      expect(light.color, MapChromePalette.light.text);
      expect(light.fontFamily, 'Nunito');
      expect(light.fontWeight, FontWeight.w900);
      expect(light.fontSize, 24);

      await pumpChrome(tester, isDark: true);
      expect(
        tester.widget<Text>(find.text('München')).style!.color,
        MapChromePalette.dark.text,
      );
    });

    testWidgets('der Level-Ring füllt sich nach dem Prozentwert', (
      tester,
    ) async {
      // `conic-gradient(#F5C518 ${levelPct * 3.6}deg, <track> 0deg)`,
      // `screen-map.jsx:733`: zwei harte Stopps an derselben Stelle. Ohne
      // diese Zusicherung wäre ein fest verdrahteter Ring nicht von einem
      // rechnenden zu unterscheiden, weil der Startwert 0 ist.
      SweepGradient gradientOf(WidgetTester tester) {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(MapLevelBadge),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).gradient! as SweepGradient;
      }

      await pumpChrome(tester);
      expect(gradientOf(tester).stops, <double>[0, 0]);
      expect(gradientOf(tester).colors.first, const Color(0xFFF5C518));

      await pumpChrome(tester, level: 3, levelPercent: 40);
      expect(gradientOf(tester).stops, <double>[0.4, 0.4]);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('die Münzzahl steht in Gold und Nunito 900/13', (tester) async {
      await pumpChrome(tester, coins: 42);

      final style = tester.widget<Text>(find.text('42')).style!;
      expect(style.color, const Color(0xFFF5C518));
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w900);
      expect(style.fontFamily, 'Nunito');
    });
  });

  group('Zustände', () {
    testWidgets('der aktive Modus ist hinterlegt, der andere nicht', (
      tester,
    ) async {
      await pumpChrome(tester);

      Color backgroundOf(MapMode mode) {
        final container = tester.widget<Container>(
          find
              .descendant(
                of: anchorOf(mode.anchorId),
                matching: find.byType(Container),
              )
              .first,
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      expect(
        backgroundOf(MapMode.factFinder),
        MapChromePalette.light.modeActiveBackground,
      );
      expect(backgroundOf(MapMode.tour), const Color(0x00000000));

      await pumpChrome(tester, mode: MapMode.tour);
      expect(
        backgroundOf(MapMode.tour),
        MapChromePalette.light.modeActiveBackground,
      );
      expect(backgroundOf(MapMode.factFinder), const Color(0x00000000));
    });

    testWidgets('ein Tipp auf Tour meldet Tour und nicht Fact Finder', (
      tester,
    ) async {
      // Die Vertauschung zweier Knöpfe ist der Fehler, den eine Suite am
      // leichtesten überlebt, siehe die Anmelde-Lücke aus Schritt 9.
      await pumpChrome(tester);

      await tester.tap(anchorOf(DiscoveryAnchors.modeTour));
      await tester.pump();
      expect(selected, <MapMode>[MapMode.tour]);

      await tester.tap(anchorOf(DiscoveryAnchors.modeFactFinder));
      await tester.pump();
      expect(selected, <MapMode>[MapMode.tour, MapMode.factFinder]);
    });

    testWidgets('ein Tipp auf den bereits aktiven Modus meldet ebenfalls', (
      tester,
    ) async {
      // `handleModeChange` prüft in der Quelle nicht auf Gleichheit
      // (`screen-map.jsx:3218`).
      await pumpChrome(tester, mode: MapMode.tour);

      await tester.tap(anchorOf(DiscoveryAnchors.modeTour));
      await tester.pump();
      expect(selected, <MapMode>[MapMode.tour]);
    });

    testWidgets('der rote Punkt hängt an tourReady und am inaktiven '
        'Tour-Knopf', (tester) async {
      // `tourReady && modeBtn.id === 'tour' && !isAct`, `screen-map.jsx:3227`.
      await pumpChrome(tester);
      expect(find.byType(MapNotificationDot), findsNothing);

      await pumpChrome(tester, tourReady: true);
      expect(find.byType(MapNotificationDot), findsOneWidget);
      expect(
        find.descendant(
          of: anchorOf(DiscoveryAnchors.modeTour),
          matching: find.byType(MapNotificationDot),
        ),
        findsOneWidget,
      );

      // Aktiv wieder weg: die Quelle zeigt ihn nur als Hinweis auf einen
      // ungenutzten Modus.
      await pumpChrome(tester, tourReady: true, mode: MapMode.tour);
      expect(find.byType(MapNotificationDot), findsNothing);
    });

    testWidgets('ein stummer Kompass wird blass und bekommt einen Punkt', (
      tester,
    ) async {
      await pumpChrome(tester);
      expect(find.byType(MapNotificationDot), findsNothing);
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: anchorOf(DiscoveryAnchors.compass),
                matching: find.byType(Opacity),
              ),
            )
            .first
            .opacity,
        1,
      );

      await pumpChrome(tester, isCompassDead: true);
      expect(
        find.descendant(
          of: anchorOf(DiscoveryAnchors.compass),
          matching: find.byType(MapNotificationDot),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: anchorOf(DiscoveryAnchors.compass),
                matching: find.byType(Opacity),
              ),
            )
            .first
            .opacity,
        0.55,
      );
      // Der Knopf bleibt genau 44 mal 44: der Punkt sitzt in einem `Stack`
      // ohne Clip und darf die Kachel nicht aufblähen.
      expect(
        tester.getRect(anchorOf(DiscoveryAnchors.compass)).size,
        const Size(44, 44),
      );
    });

    testWidgets('die Nadel dreht gegen die Blickrichtung', (tester) async {
      await pumpChrome(tester, bearingDegrees: 90);

      final rotation = tester.widget<Transform>(
        find
            .descendant(
              of: anchorOf(DiscoveryAnchors.compass),
              matching: find.byType(Transform),
            )
            .first,
      );
      // `rotate(${-map.getBearing()}deg)`, `screen-map.jsx:1792`. Eine
      // Vierteldrehung nach links, also negativ.
      expect(rotation.transform.getRotation().storage[1], closeTo(-1, 0.001));
    });

    testWidgets('ohne Rückrufe reagiert nichts, mit Rückrufen alles', (
      tester,
    ) async {
      // Der Zustand von heute: die Karte fehlt, also gibt es nichts zu
      // zentrieren. Sichtbar und angemeldet sind die Elemente trotzdem.
      await pumpChrome(tester);
      await tester.tap(find.byType(MapCityPill));
      await tester.tap(anchorOf(DiscoveryAnchors.compass));
      await tester.pump();
      expect(cityTaps, 0);
      expect(compassTaps, 0);
      expect(tester.takeException(), isNull);

      await pumpChrome(tester, withCallbacks: true);
      await tester.tap(find.byType(MapCityPill));
      await tester.pump();
      expect(cityTaps, 1);

      await tester.tap(anchorOf(DiscoveryAnchors.compass));
      await tester.pump();
      expect(compassTaps, 1);

      await tester.longPress(anchorOf(DiscoveryAnchors.compass));
      await tester.pump();
      expect(compassLongPresses, 1);
      expect(compassTaps, 1, reason: 'ein langer Druck ist kein kurzer Tipp');
    });
  });

  group('Texte', () {
    testWidgets('die Beschriftungen kommen aus AppStrings', (tester) async {
      await pumpChrome(tester);

      expect(find.text('🔍 Fact Finder'), findsOneWidget);
      expect(find.text('🗺 Tour'), findsOneWidget);
    });

    testWidgets('ein Sprachwechsel schlägt durch', (tester) async {
      // Die beiden Modus-Schlüssel tragen in beiden Sprachen denselben Text,
      // deshalb ist der Kompass-Titel der einzige belastbare Beleg.
      await pumpChrome(tester, language: AppLanguage.en, withCallbacks: true);

      final semantics = tester.getSemantics(
        find.byType(MapCompassButton).first,
      );
      expect(semantics.label, contains('My location'));
      expect(semantics.label, contains('long-press to reset'));
    });

    testWidgets('ein stummer Kompass sagt das auch an', (tester) async {
      await pumpChrome(tester, isCompassDead: true, withCallbacks: true);

      final semantics = tester.getSemantics(
        find.byType(MapCompassButton).first,
      );
      expect(semantics.label, contains('Kompass aus'));
    });
  });

  group('Systemschrift 2.0 auf schmalen Geräten', () {
    /// Die beiden Breiten aus dem Auftrag. 390 ist das Rahmenmaß der Quelle
    /// und steht zum Vergleich daneben.
    for (final width in <double>[360, 375, 390]) {
      testWidgets('bei $width Pixeln bleibt alles im Rahmen und getrennt', (
        tester,
      ) async {
        useTextScale(tester, 2);
        await pumpChrome(tester, size: Size(width, 844));

        final frame = Rect.fromLTWH(0, 0, width, 844);
        final rects = <String, Rect>{
          'Stadt-Pille': tester.getRect(find.byType(MapCityPill)),
          'Coin-Pille': tester.getRect(anchorOf(DiscoveryAnchors.coins)),
          'Level-Ring': tester.getRect(find.byType(MapLevelBadge)),
          'Kompass': tester.getRect(anchorOf(DiscoveryAnchors.compass)),
          'Fact-Finder-Knopf': tester.getRect(
            anchorOf(DiscoveryAnchors.modeFactFinder),
          ),
          'Tour-Knopf': tester.getRect(anchorOf(DiscoveryAnchors.modeTour)),
        };

        // 1. Nichts ragt aus dem Bildschirm. Ein `Stack` würde das nur
        //    abschneiden, ohne einen Überlauf zu melden.
        for (final entry in rects.entries) {
          expect(
            frame.contains(entry.value.topLeft) &&
                frame.contains(entry.value.bottomRight - const Offset(0.01, 0)),
            isTrue,
            reason: '${entry.key} liegt bei ${entry.value} außerhalb $frame',
          );
        }

        // 2. Keine zwei Bedienelemente überlappen sich. Das ist der Fall, den
        //    die absoluten `top`-Werte der Quelle bei mitwachsender Schrift
        //    erzeugen würden.
        final names = rects.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final a = rects[names[i]]!;
            final b = rects[names[j]]!;
            expect(
              a.overlaps(b),
              isFalse,
              reason: '${names[i]} $a überlappt ${names[j]} $b',
            );
          }
        }

        // 3. Und erst danach die schwache Prüfung.
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('die Münze bleibt 22 Pixel groß', (tester) async {
      // Die Prägung skaliert bewusst nicht mit: eine mitwachsende Glyphe in
      // einer festen Scheibe wäre abgeschnitten, nicht größer.
      useTextScale(tester, 2);
      await pumpChrome(tester, size: const Size(360, 844));

      final disc = tester.getRect(
        find
            .ancestor(of: find.text('F'), matching: find.byType(Container))
            .first,
      );
      expect(disc.size, const Size(MapCoinPill.discSize, MapCoinPill.discSize));
    });

    testWidgets('der Stadtname bleibt einzeilig und kürzt statt umzubrechen', (
      tester,
    ) async {
      // Ein Umbruch ist kein Überlauf, Flutter meldet ihn nicht. Deshalb an
      // der Zeilenzahl gemessen und nicht an einer Ausnahme.
      useTextScale(tester, 2);
      await pumpChrome(
        tester,
        size: const Size(360, 844),
        cityName: 'Regensburg',
      );

      final text = tester.renderObject<RenderParagraph>(
        find.text('Regensburg'),
      );
      // `getBoxesForSelection` liefert je gerenderter Zeile ein Rechteck.
      expect(
        text.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 'Regensburg'.length),
        ),
        hasLength(1),
      );
      expect(text.didExceedMaxLines, isTrue, reason: 'gekürzt, nicht gedrängt');
    });

    testWidgets('auch bei 2.0 wird nichts gekürzt, der Umschalter '
        'verkleinert sich stattdessen', (tester) async {
      // Die Alternative wäre "🔍 Fact Fi…" gewesen. Gemessen wird beides: der
      // Text ist vollständig, und der Umschalter ist kleiner als seine
      // Eigenbreite von 296,2 bei dieser Skalierung.
      useTextScale(tester, 2);
      await pumpChrome(tester, size: const Size(360, 844));

      for (final label in <String>['🔍 Fact Finder', '🗺 Tour']) {
        final text = tester.renderObject<RenderParagraph>(find.text(label));
        expect(text.didExceedMaxLines, isFalse, reason: label);
      }
      final toggle = tester.getRect(find.byType(MapModeToggle));
      expect(
        toggle.width,
        lessThanOrEqualTo(360 - 2 * MapTopChrome.modeToggleSideBand),
      );
      // Und trotzdem größer als bei Skalierung 1.0: die Deckelung darf nicht
      // heimlich jede Vergrößerung wegnehmen.
      expect(toggle.width, greaterThan(196.8));
    });

    testWidgets('bei Skalierung 1.0 wird nichts gekürzt', (tester) async {
      // Gegenprobe zum Test darüber: die Kürzung darf nur der Notausgang sein
      // und nicht der Normalfall.
      await pumpChrome(tester, size: const Size(360, 844));

      for (final label in <String>['München', '🔍 Fact Finder', '🗺 Tour']) {
        final text = tester.renderObject<RenderParagraph>(find.text(label));
        expect(text.didExceedMaxLines, isFalse, reason: label);
      }
    });
  });
}
