import 'dart:async';

import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_group_expand.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/map_camera_intents.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_gate.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_position_rect.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:fact_app/services/orientation/device_heading.dart';
import 'package:fact_app/services/orientation/orientation_providers.dart';
import 'package:fact_app/services/orientation/orientation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Kartenbildschirm mit seinem Top-Chrome über der Karte.
///
/// Gegenstand ist hier die Verdrahtung: welche Werte der Bildschirm einsetzt,
/// solange die besitzenden Domänen fehlen, dass die Kartenfläche unter dem
/// Chrome liegt, dass der Modus-Umschalter wirklich schaltet, und seit Schritt
/// 13 **welche Kameraabsicht wann abgegeben wird**. Die Maße stehen im Test des
/// Chrome, die Zahlen jeder Absicht in `map_camera_intents_test.dart`.
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
/// **Auch der Karten-Host ist ein Doppelgänger.** Er muss es sein: der echte
/// bekommt seine Kamera erst aus `onMapCreated`, und das läuft ohne
/// Plattformkanal nie. Was der echte Host mit einer Absicht macht, prüft
/// `test/map/presentation/`.
void main() {
  /// Der Stellvertreter der Kartenfläche.
  ///
  /// **Nicht `const`:** Dart kanonisiert konstante Ausdrücke, und ein
  /// `identical` gegen einen const-Stellvertreter wäre auch dann grün, wenn
  /// `MapPage` sich selbst ein gleich geschriebenes Widget baute.
  final Widget mapSurfaceStandIn = Container(
    key: const ValueKey<String>('kartenflaeche'),
  );

  /// Die Überlagerung, die der überschriebene Provider liefert.
  const MapOverlay factOverlay = MapOverlay(
    id: factOverlayId,
    points: <MapOverlayPoint>[
      MapOverlayPoint(
        id: '17',
        position: MapPosition(latitude: 48.1371, longitude: 11.5754),
        styleId: 'fact.hist.uncollected',
        state: 'uncollected',
      ),
    ],
  );

  late FakeMapHost host;
  late FakeLocationService location;
  late FakeOrientationService orientation;

  setUp(() {
    host = FakeMapHost();
    location = FakeLocationService();
    orientation = FakeOrientationService();
  });

  tearDown(() async {
    await host.close();
    await location.close();
    await orientation.close();
  });

  /// Eine Überlagerung mit einem Fakt **auf** der Ortung und einem weit weg.
  ///
  /// Der nahe liegt genau auf `fixAt()`, die Entfernung ist also null und die
  /// Betonung eins. Der ferne steht rund 18 Kilometer nördlich und fällt damit
  /// nie in die Näherung.
  const MapOverlay overlayWithNearbyFact = MapOverlay(
    id: factOverlayId,
    points: <MapOverlayPoint>[
      MapOverlayPoint(
        id: 'nah',
        position: MapPosition(latitude: 48.1351, longitude: 11.582),
        styleId: 'fact.hist.uncollected',
        state: 'uncollected',
      ),
      MapOverlayPoint(
        id: 'fern',
        position: MapPosition(latitude: 48.3, longitude: 11.582),
        styleId: 'fact.hist.uncollected',
        state: 'uncollected',
      ),
    ],
  );

  /// Baut den Container für einen Test.
  ///
  /// [withFakeHost] `false` lässt die **echte** `MapHostRegistry` stehen. Das
  /// braucht genau eine Prüfung, und sie ist der Grund, warum es den Schalter
  /// gibt: der Doppelgänger meldet nichts, die Registry meldet
  /// `map.host.missing`, sobald jemand ohne Karte nach der Kamera fragt.
  ProviderContainer newContainer({
    bool withFakeHost = true,
    DiagnosticSink? diagnostics,
    MapOverlay overlay = factOverlay,
  }) {
    // **Mit `addTearDown`, und das ist seit Schritt 12 keine Kosmetik mehr:**
    // an diesem Container hängen jetzt eine `MapHostRegistry` und ein
    // Abonnement auf den Ortungsstrom, deren `ref.onDispose` sonst nie läuft.
    final container = ProviderContainer(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(),
        ),
        if (withFakeHost) mapHostProvider.overrideWithValue(host),
        if (diagnostics != null)
          diagnosticSinkProvider.overrideWithValue(diagnostics),
        locationServiceProvider.overrideWithValue(location),
        orientationServiceProvider.overrideWithValue(orientation),
        // **Ohne diesen Override endet jeder Test hier in „A Timer is still
        // pending".** Der Standard `unavailableFactRepository` wirft, und
        // Riverpod 3 wiederholt einen gescheiterten Provider von sich aus bis
        // zu zehnmal mit wachsender Pause
        // (`provider_container.dart:982-996`); der erste dieser Timer
        // überlebt den Widget-Baum.
        //
        // Überschrieben wird die **Überlagerung** und nicht das Repository:
        // dieser Test misst die Verdrahtung des Bildschirms, und die Strecke
        // vom Fakt zur Überlagerung steht vollständig in
        // `fact_overlay_test.dart`.
        factOverlayProvider.overrideWith((ref) async => overlay),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required ProviderContainer container,
    bool branchIsActive = true,
    Duration Function()? now,
    Widget? huntOverlay,
  }) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FactTheme.light(),
          home: AnchorScope(
            knownMissingAnchors: DiscoveryAnchors.knownMissing,
            child: Scaffold(
              // Dieselbe Verpackung, die `go_router 18.0.0` um jeden Zweig
              // seiner Shell legt (`route.dart:1630-1634`): `Offstage` plus
              // `TickerMode`. Der `TickerMode` ist der Teil, an dem dieser
              // Bildschirm erkennt, ob er sichtbar ist.
              body: TickerMode(
                enabled: branchIsActive,
                child: MapPage(
                  // Dieselbe Zusammensetzung wie in `MapRoute.build`, dem
                  // Kompositions-Adapter auf App-Ebene: `discovery` darf
                  // `map/presentation/` nicht selbst importieren (Regel 18).
                  mapSurface: mapSurfaceStandIn,
                  huntOverlay: huntOverlay,
                  now: now,
                ),
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

  DevicePosition fixAt({
    double latitude = 48.1351,
    double longitude = 11.582,
    double accuracy = 8,
  }) => DevicePosition(
    latitude: latitude,
    longitude: longitude,
    accuracyInMeters: accuracy,
  );

  /// Ein geprüfter Kopfwert des Kompasses.
  DeviceHeading headingAt(double degrees) => DeviceHeading.tryFrom(degrees)!;

  /// Die Karte meldet sich mit einer Startkamera, wie `bindSurface` es tut.
  Future<void> mapComesAlive(
    WidgetTester tester, {
    double zoom = 14,
    double bearing = 0,
  }) async {
    host.bind(
      MapCameraView(
        center: const MapPosition(latitude: 48.1351, longitude: 11.582),
        zoom: zoom,
        bearing: bearing,
        pitch: 35,
      ),
    );
    await tester.pump();
  }

  /// Schiebt eine Ortung in den Strom und lässt sie ankommen.
  ///
  /// **Zweimal gepumpt, und das ist kein Aberglaube.** Der erste Umlauf stellt
  /// die Stromausgabe zu, der Zuhörer setzt daraufhin den Zustand, und erst der
  /// zweite baut die Oberfläche neu. Wer nur einmal pumpt, sieht die Absicht
  /// beim Host, aber eine Stadt-Pille, die noch nicht antippbar ist.
  Future<void> emitFix(WidgetTester tester, DevicePosition position) async {
    location.emit(position);
    await tester.pump();
    await tester.pump();
  }

  /// Ein langer Druck, der lang genug ist.
  ///
  /// **`tester.longPress` reicht dafür nicht.** Es hält
  /// `kLongPressTimeout + kPressTimeout`, also 600 Millisekunden, und der
  /// Kompass wartet seit Schritt 13 auf die **700** der Quelle
  /// (`screen-map.jsx:3173`). Mit dem eingebauten Helfer wäre daraus ein
  /// kurzer Druck geworden, und die Prüfung hätte den falschen Rückruf
  /// gemessen. Die beiden Grenzen selbst stehen im Test des Chrome.
  Future<void> longPress(WidgetTester tester, Finder finder) async {
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(
      MapTopChrome.compassLongPressDuration + const Duration(milliseconds: 50),
    );
    await gesture.up();
    await tester.pump();
  }

  group('Aufbau', () {
    testWidgets('zeigt das Top-Chrome über der Kartenfläche', (tester) async {
      await pumpPage(tester, container: newContainer());
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
      await pumpPage(tester, container: newContainer());
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
      await pumpPage(tester, container: newContainer());
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

    testWidgets('die Nadel folgt der Kartenblickrichtung', (tester) async {
      // **Vorher zeigte sie eine Richtung an, die die Karte nicht hatte.** Sie
      // stand fest auf 0, während der Nutzer seit Schritt 12 mit zwei Fingern
      // drehen darf (`screen-map.jsx:1683-1688`). Die Quelle dreht die Nadel
      // gegen die Kartenblickrichtung (`:1792`), und dafür braucht es keinen
      // Gerätekompass, nur den Kamerastrom, den dieser Bildschirm ohnehin
      // abonniert.
      await pumpPage(tester, container: newContainer());
      await tester.pumpAndSettle();

      MapTopChrome chromeNow() =>
          tester.widget<MapTopChrome>(find.byType(MapTopChrome));

      expect(
        chromeNow().bearingDegrees,
        MapPage.placeholderCamera.bearing,
        reason: 'bis die Karte steht, gilt die Blickrichtung der Startkamera',
      );

      await mapComesAlive(tester, bearing: 90);
      // Zweimal gepumpt, wie bei einer Ortung: der erste Umlauf stellt die
      // Stromausgabe zu, der Zuhörer setzt den Zustand, erst der zweite baut
      // die Oberfläche neu.
      await tester.pump();

      expect(chromeNow().bearingDegrees, 90);

      // Und sie kommt bis zur Anzeige durch, nicht nur bis zum Parameter.
      final rotation = tester.widget<Transform>(
        find
            .descendant(
              of: anchorOf(DiscoveryAnchors.compass),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(rotation.transform.getRotation().storage[1], closeTo(-1, 0.001));
    });

    testWidgets('ohne Jagd-Overlay zeigt der Bildschirm dafür nichts an', (
      tester,
    ) async {
      // `huntOverlay` ist nullbar, siehe `MapPage.huntOverlay`: der weit
      // überwiegende Normalzustand ist, dass keine Jagd läuft.
      await pumpPage(tester, container: newContainer());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('jagd-pille')), findsNothing);
    });

    testWidgets(
      'das Jagd-Overlay liegt über der Karte und unter dem Top-Chrome',
      (tester) async {
        const Widget huntOverlayStandIn = SizedBox(
          key: ValueKey<String>('jagd-pille'),
        );
        await pumpPage(
          tester,
          container: newContainer(),
          huntOverlay: huntOverlayStandIn,
        );
        await tester.pumpAndSettle();

        expect(find.byWidget(huntOverlayStandIn), findsOneWidget);

        final Stack stack = tester.widget<Stack>(
          find
              .ancestor(
                of: find.byWidget(mapSurfaceStandIn),
                matching: find.byType(Stack),
              )
              .first,
        );
        final int mapIndex = stack.children.indexOf(mapSurfaceStandIn);
        final int chromeIndex = stack.children.lastIndexWhere(
          (widget) => widget is MapTopChrome,
        );
        final int overlayIndex = stack.children.indexWhere(
          (widget) =>
              widget is Positioned && widget.child == huntOverlayStandIn,
        );
        expect(overlayIndex, greaterThan(mapIndex));
        expect(overlayIndex, lessThan(chromeIndex));
      },
    );

    testWidgets('die dunkle Fassung bleibt unverdrahtet', (tester) async {
      // `mapDark` wird in der Quelle nie `true`, siehe `MapTopChrome.isDark`.
      await pumpPage(tester, container: newContainer());
      await tester.pumpAndSettle();

      expect(
        tester.widget<MapTopChrome>(find.byType(MapTopChrome)).isDark,
        isFalse,
      );
    });

    test('die Startkamera ist die Rückfallkamera der Quelle', () {
      // **Sie war nirgends festgenagelt.** `zoom: 14, pitch: 35` auf `9` und
      // `3` zu ändern überlebte die ganze Suite, und der Flächen-Test schrieb
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
  });

  group('Der erste Fix fällt vom Himmel, jeder weitere folgt', () {
    testWidgets('der erste Fix löst den Sky-Fall aus', (tester) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);

      await emitFix(tester, fixAt(latitude: 48.2, longitude: 11.7));

      expect(host.intents, hasLength(1));
      final intent = host.intents.single;
      expect(intent, isA<MapCameraOneShot>());
      expect(intent.change.zoom, skyFallZoom);
      expect(intent.change.pitch, skyFallPitch);
      expect(
        intent.change.center,
        const MapPosition(latitude: 48.2, longitude: 11.7),
        reason:
            'Breite und Länge dürfen dabei nicht tauschen; in jedem anderen '
            'Test dieser Datei sähe der Tausch gleich aus',
      );
    });

    testWidgets('jeder weitere Fix folgt statt zu fallen', (tester) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);

      await emitFix(tester, fixAt());
      await emitFix(tester, fixAt(latitude: 48.2));
      await emitFix(tester, fixAt(latitude: 48.3));

      expect(host.intents, hasLength(3));
      expect(host.intents[0], isA<MapCameraOneShot>());
      for (final intent in host.intents.skip(1)) {
        expect(intent, isA<MapCameraFollow>());
        expect(
          (intent as MapCameraFollow).kind,
          MapCameraFollowKind.userPosition,
        );
      }
    });

    testWidgets('eine zu ungenaue Ortung löst gar nichts aus', (tester) async {
      // Der Filter sitzt im Notifier, diese Prüfung hält fest, dass er auch
      // wirkt: ohne ihn fiele der Sky-Fall auf eine Funkzellen-Ortung, und
      // genau davor warnt der Kommentar der Quelle bei `:2740-2741`.
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);

      await emitFix(tester, fixAt(accuracy: 36));

      expect(host.intents, isEmpty);
    });

    testWidgets('ohne Karte wartet der Sky-Fall und wird nachgeholt', (
      tester,
    ) async {
      // **Der Grund, warum es diese Buchführung gibt.** Der Host verwirft jede
      // Absicht, die vor der Karte eintrifft (`map.host.intent_dropped`);
      // fiele der Sky-Fall dort hinein, gäbe es die Eröffnungsanimation nie.
      // Die Quelle hat dasselbe Problem und löst es für ihren
      // zwischengespeicherten Pfad mit `map.once('idle')` (`:1746-1747`).
      await pumpPage(tester, container: newContainer());

      await emitFix(tester, fixAt(latitude: 48.2));
      expect(host.intents, isEmpty, reason: 'noch gibt es keine Karte');

      await mapComesAlive(tester);

      expect(host.intents, hasLength(1));
      expect(host.intents.single, isA<MapCameraOneShot>());
      expect(host.intents.single.change.zoom, skyFallZoom);
    });

    testWidgets('nachgeholt wird auf die neueste Ortung', (tester) async {
      // Die Quelle kennt den Fall nicht, weil sie den Sky-Fall nie aufhebt.
      // Wer eine Minute später auf die Karte kommt, soll dorthin fallen, wo er
      // steht, und nicht dorthin, wo er stand.
      await pumpPage(tester, container: newContainer());

      await emitFix(tester, fixAt(latitude: 48.2));
      await emitFix(tester, fixAt(latitude: 48.4));
      await mapComesAlive(tester);

      expect(host.intents.single.change.center?.latitude, 48.4);
    });

    testWidgets('der Sky-Fall passiert genau einmal', (tester) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);
      await emitFix(tester, fixAt());

      // Zweite Kamerameldung und weitere Ortungen: nichts davon darf einen
      // zweiten Sky-Fall auslösen. Der Riegel `skyFallDone` der Quelle
      // (`:1726-1729`).
      await mapComesAlive(tester, zoom: 16.5);
      await emitFix(tester, fixAt(latitude: 48.9));

      final skyFalls = host.intents
          .where((intent) => intent.change.zoom == skyFallZoom)
          .toList();
      expect(skyFalls, hasLength(1));
    });
  });

  group('Im unsichtbaren Zweig bewegt sich die Karte nicht', () {
    testWidgets('inaktiv gibt der Bildschirm keine Absicht ab', (tester) async {
      // `go_router` entsorgt den Zweig beim Tabwechsel nicht, es legt ihn nur
      // offstage und schaltet den `TickerMode` ab. Ohne diese Sperre zöge die
      // Karte im Hintergrund weiter.
      final container = newContainer();
      await pumpPage(tester, container: container, branchIsActive: false);
      await mapComesAlive(tester);

      await emitFix(tester, fixAt());
      await emitFix(tester, fixAt(latitude: 48.2));

      expect(host.intents, isEmpty);
      expect(
        container.read(userLocationProvider).acceptedFixes,
        2,
        reason:
            'der Ortungsstrom läuft weiter, er trägt später Audio-Beacon und '
            'Geofencing',
      );
    });

    testWidgets('beim Sichtbarwerden wird der Sky-Fall nachgeholt', (
      tester,
    ) async {
      final container = newContainer();
      await pumpPage(tester, container: container, branchIsActive: false);
      await mapComesAlive(tester);
      await emitFix(tester, fixAt(latitude: 48.2));
      expect(host.intents, isEmpty);

      await pumpPage(tester, container: container);
      await tester.pump();

      expect(host.intents, hasLength(1));
      expect(host.intents.single.change.zoom, skyFallZoom);
    });

    testWidgets('danach folgt die Karte wieder', (tester) async {
      final container = newContainer();
      await pumpPage(tester, container: container, branchIsActive: false);
      await mapComesAlive(tester);
      await emitFix(tester, fixAt());
      await pumpPage(tester, container: container);
      await tester.pump();
      host.intents.clear();

      await emitFix(tester, fixAt(latitude: 48.2));

      expect(host.intents.single, isA<MapCameraFollow>());
    });
  });

  group('Die drei Bedienelemente bewegen die Kamera', () {
    testWidgets('die Stadt-Pille ist ohne Ortung nicht antippbar', (
      tester,
    ) async {
      // `cursor: userPos ? 'pointer' : 'default'` (`:3112`), und `recenter`
      // kehrt ohne Position sofort zurück (`:2978-2979`).
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);

      expect(
        tester.widget<MapTopChrome>(find.byType(MapTopChrome)).onCityTap,
        isNull,
      );

      await emitFix(tester, fixAt());
      host.intents.clear();

      expect(
        tester.widget<MapTopChrome>(find.byType(MapTopChrome)).onCityTap,
        isNotNull,
      );
    });

    testWidgets('die Stadt-Pille zentriert neu, ohne das Einrasten zu lösen', (
      tester,
    ) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester, zoom: 12);
      await emitFix(tester, fixAt(latitude: 48.2, longitude: 11.7));
      host.intents.clear();

      await tester.tap(find.text('München'));
      await tester.pump();

      final intent = host.intents.single;
      expect(intent, isA<MapCameraOneShot>());
      expect(
        intent.change.center,
        const MapPosition(latitude: 48.2, longitude: 11.7),
      );
      expect(intent.change.zoom, 15, reason: 'max(12, 15)');
      expect(releasesBearingLock(intent), isFalse);
    });

    testWidgets('die Stadt-Pille rechnet mit dem Live-Zoom der Karte', (
      tester,
    ) async {
      // **Der Spiegeltest zum Kompass-Tipp, und genau er hat gefehlt.** Der
      // Test darüber mountet mit Zoom 12 und erwartet 15, und das erfüllt jede
      // Konstante <= 15. Nachgemessen am 29.08.2026: `currentZoom:
      // camera.zoom` durch `currentZoom: 0` zu ersetzen, überlebte alle 1177
      // Tests. Zwei Stellen, gleiches Muster, nur eine geprüft.
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester, zoom: 17);
      await emitFix(tester, fixAt());
      host.intents.clear();

      await tester.tap(find.text('München'));
      await tester.pump();

      expect(
        host.intents.single.change.zoom,
        17,
        reason: 'max(17, 15), der Nutzer behält seinen Zoom',
      );
    });

    testWidgets('der kurze Druck auf den Kompass zentriert neu und löst das '
        'Einrasten', (tester) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester, zoom: 17);
      await emitFix(tester, fixAt());
      host.intents.clear();

      await tester.tap(anchorOf(DiscoveryAnchors.compass));
      await tester.pump();

      final intent = host.intents.single;
      expect(intent, isA<MapCameraCommand>());
      expect(intent.change.zoom, 17, reason: 'max(17, 15)');
      expect(releasesBearingLock(intent), isTrue);
      expect(clearsFollowAnchor(intent), isFalse);
    });

    testWidgets('der lange Druck setzt zurück und leert den Anker', (
      tester,
    ) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester, zoom: 17);
      await emitFix(tester, fixAt());
      host.intents.clear();

      await longPress(tester, anchorOf(DiscoveryAnchors.compass));
      await tester.pump();

      final intent = host.intents.single;
      expect(intent, isA<MapCameraCommand>());
      expect(
        intent.change.zoom,
        15,
        reason: 'der harte Reset setzt, nicht max',
      );
      expect(intent.change.bearing, 0);
      expect(intent.change.pitch, 30);
      expect(intent.motion, const MapCameraImmediate());
      expect(releasesBearingLock(intent), isTrue);
      expect(clearsFollowAnchor(intent), isTrue);
    });

    testWidgets('der Kompass bleibt ohne Ortung bedienbar', (tester) async {
      // Beide Gesten lösen das Einrasten unbedingt (`:3166`, `:3182`), und der
      // lange Druck stellt zusätzlich Neigung und Blickrichtung zurück, auch
      // ohne Position (`:3170`).
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);

      await longPress(tester, anchorOf(DiscoveryAnchors.compass));
      await tester.pump();

      final intent = host.intents.single;
      expect(intent.change.center, isNull);
      expect(intent.change.zoom, isNull);
      expect(intent.change.pitch, 30);
      expect(releasesBearingLock(intent), isTrue);
    });

    testWidgets('der kurze Druck ohne Ortung löst nur das Einrasten', (
      tester,
    ) async {
      // **Die bewusste Abweichung von der Quelle, auf Seitenebene.** Dort
      // entsteht ohne Position gar kein Kameraaufruf (`recenter` kehrt bei
      // `:2978-2979` sofort zurück), hier entsteht ein Befehl mit leerer
      // Änderung, weil das Einrasten nur über einen Befehl lösbar ist
      // (`:3182`, unbedingt). Geprüft war das bisher nur an der reinen
      // Funktion: `if (camera == null)` zu `if (camera == null || _target ==
      // null)` zu ändern, überlebte alle 1177 Tests, weil der einzige Test
      // ohne Ortung den **langen** Druck benutzte.
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);

      await tester.tap(anchorOf(DiscoveryAnchors.compass));
      await tester.pump();

      final intent = host.intents.single;
      expect(intent, isA<MapCameraCommand>());
      expect(intent.change.center, isNull);
      expect(intent.change.zoom, isNull);
      expect(intent.change.bearing, isNull);
      expect(intent.change.pitch, isNull);
      expect(intent.motion, const MapCameraImmediate());
      expect(releasesBearingLock(intent), isTrue);
    });

    testWidgets('ohne Karte fragt der Bildschirm den Host nicht nach der '
        'Kamera', (tester) async {
      // **Hier steht ausnahmsweise die echte Registry und kein
      // Doppelgänger**, denn nur sie meldet. `MapHost.camera` ohne
      // eingeklinkten Host gibt `map.host.missing`, und das ist als
      // Verdrahtungsfehler gedacht und nicht als Normalfall jedes
      // Startvorgangs; deshalb merkt sich `MapPage`, ob die Karte lebt, statt
      // zu fragen. Nachgemessen: den Wächter zu entfernen, überlebte alle 1177
      // Tests, weil jeder andere Test hier einen Fake benutzt, der gar nichts
      // meldet.
      final sink = RecordingSink();
      await pumpPage(
        tester,
        container: newContainer(withFakeHost: false, diagnostics: sink),
      );

      await tester.tap(anchorOf(DiscoveryAnchors.compass));
      await tester.pump();
      await longPress(tester, anchorOf(DiscoveryAnchors.compass));

      expect(
        sink.events
            .where(
              (event) =>
                  event.name == MapHostRegistry.missingHostEvent &&
                  event.attributes['access'] == 'camera',
            )
            .toList(),
        isEmpty,
      );
    });

    testWidgets('ohne Karte bewegt kein Knopf etwas', (tester) async {
      // Ohne `bindSurface` hat der Host keine Kamera, und ohne Kamera gibt es
      // keinen aktuellen Zoom, gegen den `max(zoom, 15)` rechnen könnte.
      await pumpPage(tester, container: newContainer());

      await tester.tap(anchorOf(DiscoveryAnchors.compass));
      await tester.pump();
      await longPress(tester, anchorOf(DiscoveryAnchors.compass));
      await tester.pump();

      expect(host.intents, isEmpty);
    });
  });

  group('Die Karte folgt dem Kompass, screen-map.jsx:2805-2895', () {
    MapTopChrome chromeOf(WidgetTester tester) =>
        tester.widget<MapTopChrome>(find.byType(MapTopChrome));

    testWidgets('ein Kopfwert löst genau eine Absicht mit der geglätteten, '
        'nicht der rohen Richtung aus', (tester) async {
      // 0 (Startwert der Glättung) und ein Kopfwert von 100 ergeben 25, nicht
      // 100: `0 + (100 - 0) * 0.25 = 25`.
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);
      host.intents.clear();

      orientation.emit(headingAt(100));
      await tester.pump();

      final MapCameraIntent intent = host.intents.single;
      expect(intent, isA<MapCameraFollow>());
      expect(
        (intent as MapCameraFollow).kind,
        MapCameraFollowKind.compassBearing,
      );
      expect(
        intent.change.bearing,
        25,
        reason: 'die geglättete Richtung, nicht der Rohwert 100',
      );
    });

    testWidgets('mehrere Kopfwerte laufen durch dieselbe Glättung, nicht '
        'jeder für sich', (tester) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);
      host.intents.clear();

      orientation.emit(headingAt(100));
      await tester.pump();
      orientation.emit(headingAt(100));
      await tester.pump();

      expect(host.intents, hasLength(2));
      expect(
        host.intents[0].change.bearing,
        25,
        reason: 'erster Schritt: 0 nach 100 ergibt 25',
      );
      expect(
        host.intents[1].change.bearing,
        43.75,
        reason:
            'zweiter Schritt von 25 aus, nicht noch einmal von 0: '
            '25 + (100 - 25) * 0.25 = 43.75. Würde jeder Kopfwert für sich '
            'geglättet, stünde hier wieder 25',
      );
    });

    testWidgets('ohne Kopfwerte entsteht keine Absicht', (tester) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);
      host.intents.clear();

      await tester.pump(const Duration(seconds: 1));

      expect(
        host.intents.where(
          (intent) =>
              intent is MapCameraFollow &&
              intent.kind == MapCameraFollowKind.compassBearing,
        ),
        isEmpty,
      );
    });

    testWidgets('ohne lebende Karte bleibt der Kopfwert ohne Absicht', (
      tester,
    ) async {
      // Derselbe Wächter wie beim GPS-Folgen, `_canSteer`.
      await pumpPage(tester, container: newContainer());

      orientation.emit(headingAt(100));
      await tester.pump();
      await tester.pump();

      expect(host.intents, isEmpty);
    });

    testWidgets('im unsichtbaren Zweig bleibt der Kopfwert ohne Absicht', (
      tester,
    ) async {
      // Ein einzelner, wiederverwendeter Container über den ganzen Test, wie
      // bei „beim Sichtbarwerden wird der Sky-Fall nachgeholt": zwei frische
      // Container in einem Test ließen den `factOverlayProvider` des ersten
      // ungenutzt und unversorgt stehen liegen.
      final ProviderContainer container = newContainer();
      await pumpPage(tester, container: container, branchIsActive: false);
      await mapComesAlive(tester);
      host.intents.clear();

      orientation.emit(headingAt(100));
      await tester.pump();
      await tester.pump();

      expect(host.intents, isEmpty);
    });

    testWidgets(
      'der Wachhund meldet einen toten Kompass nach mehr als 5 Sekunden, '
      'davor nicht, und ein neuer Kopfwert setzt ihn zurück',
      (tester) async {
        final TestClock clock = TestClock();
        await pumpPage(tester, container: newContainer(), now: clock.call);
        await tester.pump();

        expect(
          chromeOf(tester).isCompassDead,
          isFalse,
          reason: 'unmittelbar nach dem Start ist der Kompass nicht tot',
        );

        // Vier Sekunden, zwei Wachhund-Takte (bei 2 und 4 Sekunden), beide
        // noch unter der 5-Sekunden-Schwelle.
        clock.advance(const Duration(seconds: 4));
        await tester.pump(const Duration(seconds: 4));
        expect(
          chromeOf(tester).isCompassDead,
          isFalse,
          reason: 'vier Sekunden liegen unter der Schwelle von fünf',
        );

        // Zwei weitere Sekunden, macht sechs seit dem Start: über der
        // Schwelle, und der nächste Takt (bei 6 Sekunden) muss das melden.
        clock.advance(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        expect(
          chromeOf(tester).isCompassDead,
          isTrue,
          reason: 'sechs Sekunden liegen über der Schwelle von fünf',
        );

        // Ein neuer Kopfwert setzt den Wachhund zurück, ohne auf den
        // nächsten Takt zu warten. Zweimal gepumpt, wie bei einer Ortung: der
        // erste Umlauf stellt die Stromausgabe zu, der Zuhörer setzt den
        // Zustand, erst der zweite baut die Oberfläche neu.
        orientation.emit(headingAt(10));
        await tester.pump();
        await tester.pump();
        expect(chromeOf(tester).isCompassDead, isFalse);
      },
    );

    testWidgets('die Nadel dreht weiter nach der Kartenblickrichtung, ein '
        'Kopfwert allein bewegt sie nicht', (tester) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester, bearing: 40);
      await tester.pump();
      expect(chromeOf(tester).bearingDegrees, 40);

      // Ein Kopfwert allein löst zwar eine Absicht an den Host aus (siehe
      // oben), aber der Doppelgänger führt sie nicht aus und meldet keine
      // neue Kamera zurück; die Nadel darf sich deshalb nicht bewegen.
      orientation.emit(headingAt(200));
      await tester.pump();
      expect(chromeOf(tester).bearingDegrees, 40);

      // Eine echte Kameraänderung dagegen schon.
      await mapComesAlive(tester, bearing: 55);
      await tester.pump();
      expect(chromeOf(tester).bearingDegrees, 55);
    });

    testWidgets('die Kündigung des Kompass-Abonnements im Entsorgen wirkt', (
      tester,
    ) async {
      await pumpPage(tester, container: newContainer());
      await mapComesAlive(tester);
      host.intents.clear();

      await tester.pumpWidget(const SizedBox.shrink());

      // Ohne die Kündigung riefe der Strom `_onHeading` auf einem längst
      // entsorgten `State` auf, entweder mit einer Ausnahme beim `setState`
      // (falls der Kompass zwischenzeitlich als tot markiert war) oder,
      // unauffälliger, mit einer weiteren Absicht an einen `ref`, der nicht
      // mehr gültig ist.
      orientation.emit(headingAt(100));
      await tester.pump();

      expect(host.intents, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('Die Fakten landen auf der Karte', () {
    // **Diese Gruppe läuft in `tester.runAsync`, und das ist gemessen und
    // nicht Geschmack.** `Picture.toImage` antwortet aus der Engine, nicht aus
    // der fingierten Zeit eines `testWidgets`. Entscheidend ist dabei die
    // **Zone und nicht die Wartezeit**: ein Future, das im `didChangeDependencies`
    // innerhalb der fingierten Zeit entsteht, kommt auch nach 200 Millisekunden
    // in `runAsync` nicht zurück; wird dagegen `pumpWidget` selbst innerhalb
    // von `runAsync` gerufen, sind die zwölf Bilder in Millisekunden da.
    // Nachgemessen am 29.08.2026 mit vier Wegwerf-Proben, und mit einer
    // fünften für den vollständigen Rahmen dieser Datei: Riverpod-Container,
    // Ortungsstrom, Kamerastrom und `TickerMode` überstehen es unverändert.
    //
    // Deshalb gibt es hier **keinen Test-Haken mehr**. `MapPage` hatte einen
    // (`debugBuildBalloonImages`), begründet mit „überhaupt nicht prüfbar";
    // das galt für den einen Aufbau, der probiert worden war. Eine öffentliche
    // Fläche weniger an einem Widget, das der Routen-Adapter baut.

    /// Wartet, bis die zwölf echten Ballonbilder gezeichnet sind.
    ///
    /// `pump` und `pumpAndSettle` helfen dafür nicht: sie treiben die fingierte
    /// Zeit voran, die Bilder entstehen in der echten. Deshalb echte
    /// Wartezeit, gedeckelt, damit ein Ausfall als Zeitüberschreitung mit
    /// Ansage endet und nicht als Hänger.
    Future<void> awaitBalloons(WidgetTester tester) async {
      final Stopwatch watch = Stopwatch()..start();
      while (host.registeredImages.isEmpty &&
          watch.elapsed < const Duration(seconds: 10)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tester.pump();
    }

    testWidgets('die Bilder gehen vor der Überlagerung an den Host', (
      tester,
    ) async {
      // **Die Reihenfolge ist die Zusicherung, und sie war verletzt.**
      // `MapHost.registerOverlayImages` verlangt, vor `setOverlay` gerufen zu
      // werden; der Host meldet sonst jede Stil-Kennung als
      // `map.overlay.unknown_style`. Die Fakten kommen aus dem Netz, die Bilder
      // aus der Zeichenschleife, und bis zum 29.08.2026 gewann, wer schneller
      // war: kamen die Fakten zuerst, feuerte die Meldung mit allen zwölf
      // Kategorien, und ein „doch alles da" gibt es hinterher nicht. Der
      // einzige Schutz gegen eine wirklich vertippte Kennung war damit ein
      // Fehlalarm bei jedem Start.
      await tester.runAsync(() async {
        await pumpPage(tester, container: newContainer());
        await tester.pump();
        await awaitBalloons(tester);
      });

      expect(host.arrivals, <String>['images', 'overlay:discovery.facts']);
    });

    testWidgets('die geladene Überlagerung geht an den Host', (tester) async {
      await tester.runAsync(() async {
        await pumpPage(tester, container: newContainer());
        await tester.pump();
        await awaitBalloons(tester);
      });

      expect(host.overlays, <MapOverlay>[factOverlay]);
    });

    testWidgets('die Ballonbilder werden beim Karten-Host angemeldet', (
      tester,
    ) async {
      // Geprüft wird die **Verdrahtung**: dass der Bildschirm zeichnen lässt,
      // je Kategorie **und Sammelzustand** ein Bild, und mit dem
      // Bildverhältnis des Bildschirms.
      // Was dabei gezeichnet wird, steht in `fact_balloon_images_test.dart`.
      await tester.runAsync(() async {
        await pumpPage(tester, container: newContainer());
        await tester.pump();
        await awaitBalloons(tester);
      });

      expect(
        host.registeredImages,
        hasLength(factCategoryStyles.length * factBalloonStates.length),
      );
      expect(host.registeredImages.first.styleId, 'fact.hist.uncollected');
      // 3 ist das Bildverhältnis, mit dem `flutter test` rechnet. Wer hier
      // stumpf 1 liefert, bekommt auf jedem heutigen Telefon matschige
      // Ballons.
      expect(
        host.registeredImages
            .map((MapOverlayImage image) => image.pixelRatio)
            .toSet(),
        <double>{3},
      );
    });

    testWidgets('solange nichts geladen ist, geht nichts an den Host', (
      tester,
    ) async {
      // `AsyncLoading` ist kein Wert. Eine leere Überlagerung in diesem
      // Moment aufzulegen wäre schlimmer als gar keine: sie sähe aus wie eine
      // Stadt ohne Fakten. Der Ladevorgang endet hier nie, das ist der Punkt.
      //
      // **Und die Bilder kommen trotzdem an**, sonst prüfte dieser Test die
      // falsche Sache: ohne sie hielte der Riegel aus der Reihenfolge oben die
      // Überlagerung zurück, und der Test wäre aus dem falschen Grund grün.
      final Completer<MapOverlay> pending = Completer<MapOverlay>();
      addTearDown(() => pending.complete(factOverlay));
      final ProviderContainer container = ProviderContainer(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(),
          ),
          mapHostProvider.overrideWithValue(host),
          locationServiceProvider.overrideWithValue(location),
          factOverlayProvider.overrideWith((ref) => pending.future),
        ],
      );
      addTearDown(container.dispose);

      await tester.runAsync(() async {
        await pumpPage(tester, container: container);
        await tester.pump();
        await awaitBalloons(tester);
      });

      expect(
        host.registeredImages,
        hasLength(factCategoryStyles.length * factBalloonStates.length),
      );
      expect(host.overlays, isEmpty);
    });

    testWidgets('bei gleichem Bildverhältnis wird nicht neu gezeichnet', (
      tester,
    ) async {
      // `didChangeDependencies` läuft bei jeder Änderung der Umgebung erneut,
      // auch bei einem Tabwechsel. Ohne die Marke entstünden zwölf Bilder je
      // Wechsel.
      final ProviderContainer container = newContainer();
      await tester.runAsync(() async {
        await pumpPage(tester, container: container);
        await tester.pump();
        await awaitBalloons(tester);
        await pumpPage(tester, container: container, branchIsActive: false);
        await tester.pump();
        // Feste Wartezeit, weil hier **nichts** passieren soll und es dafür
        // kein Ereignis zum Abwarten gibt. Ein zweiter Durchgang wäre nach der
        // Messung oben lange fertig.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();
      });

      expect(
        host.registeredImages,
        hasLength(factCategoryStyles.length * factBalloonStates.length),
      );
    });
  });

  group('Die lebenden Ballons verlassen die native Liste', () {
    // **Warum das sein muss.** Ein Fakt innerhalb von 150 Metern wird von
    // `FactBalloonOverlay` als Widget über der Karte gezeichnet. Bliebe er
    // zusätzlich im Symbol-Layer, stünde er doppelt da: einmal lebend, einmal
    // als stehendes Bild darunter, und auffallen würde es genau dann, wenn er
    // wächst.
    //
    // Die Gruppe läuft aus demselben Grund in `tester.runAsync` wie die
    // vorige: die zwölf Ballonbilder entstehen in der echten Zeit, und ohne
    // sie hält der Riegel der Reihenfolge die Überlagerung zurück.

    Future<void> awaitBalloons(WidgetTester tester) async {
      final Stopwatch watch = Stopwatch()..start();
      while (host.registeredImages.isEmpty &&
          watch.elapsed < const Duration(seconds: 10)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tester.pump();
    }

    List<String> idsOfLastOverlay() => host.overlays.last.points
        .map((MapOverlayPoint point) => point.id)
        .toList();

    testWidgets('ohne Ortung geht die vollständige Liste hinaus', (
      tester,
    ) async {
      final ProviderContainer container = newContainer(
        overlay: overlayWithNearbyFact,
      );
      await tester.runAsync(() async {
        await pumpPage(tester, container: container);
        await tester.pump();
        await awaitBalloons(tester);
      });
      await mapComesAlive(tester, zoom: 16);

      expect(idsOfLastOverlay(), <String>['nah', 'fern']);
    });

    testWidgets('ein naher Fakt fehlt in der nativen Liste', (tester) async {
      final ProviderContainer container = newContainer(
        overlay: overlayWithNearbyFact,
      );
      await tester.runAsync(() async {
        await pumpPage(tester, container: container);
        await tester.pump();
        await awaitBalloons(tester);
      });
      await mapComesAlive(tester, zoom: 16);
      await emitFix(tester, fixAt());

      expect(idsOfLastOverlay(), <String>['fern']);
    });

    testWidgets('bei zu kleinem Zoom ist er wieder drin', (tester) async {
      // **Parität und keine Sparmaßnahme.** Die Quelle animiert nur, was als
      // DOM-Marker existiert, und das sind allein die ungruppierten Features
      // (`screen-map.jsx:2043-2045`). Wo nichts lebt, darf auch nichts fehlen,
      // sonst verschwände der Fakt aus seiner Gruppe, ohne dass etwas an
      // seine Stelle träte.
      final ProviderContainer container = newContainer(
        overlay: overlayWithNearbyFact,
      );
      await tester.runAsync(() async {
        await pumpPage(tester, container: container);
        await tester.pump();
        await awaitBalloons(tester);
      });
      await mapComesAlive(tester, zoom: 16);
      await emitFix(tester, fixAt());
      expect(idsOfLastOverlay(), <String>['fern']);

      await mapComesAlive(tester, zoom: 15);

      expect(idsOfLastOverlay(), <String>['nah', 'fern']);
    });

    testWidgets('ohne Änderung geht die Liste nicht noch einmal hinaus', (
      tester,
    ) async {
      // **Jeder `setOverlay` schiebt das vollständige GeoJSON über den
      // Plattformkanal.** Bei fünf Ortungen je Sekunde wäre das fünfmal je
      // Sekunde die ganze Sammlung, ohne dass sich etwas geändert hätte.
      final ProviderContainer container = newContainer(
        overlay: overlayWithNearbyFact,
      );
      await tester.runAsync(() async {
        await pumpPage(tester, container: container);
        await tester.pump();
        await awaitBalloons(tester);
      });
      await mapComesAlive(tester, zoom: 16);
      await emitFix(tester, fixAt());
      final int afterFirstFix = host.overlays.length;

      // Zweite Ortung an derselben Stelle: dieselbe Nachbarschaft, dieselbe
      // Liste.
      await emitFix(tester, fixAt());

      expect(host.overlays, hasLength(afterFirstFix));
    });
  });

  group('Ein Tipp auf eine Gruppe fährt aufs Rechteck', () {
    // **Genau die Sorte Verdrahtung, die in Schritt 15/16 schon einmal ohne
    // jeden Test durchging** (`REBUILD_STATUS.md`, Muster 10): sechs Zeilen
    // Durchreichung, die in der App wirklich laufen. Geprüft wird deshalb
    // nicht „es entsteht irgendeine Absicht", sondern die wirklich abgegebene
    // Absicht mit Mittelpunkt, Zoom und Dauer.

    const MapOverlayPoint near = MapOverlayPoint(
      id: 'nah',
      position: MapPosition(latitude: 48.1351, longitude: 11.582),
      styleId: 'fact.hist.uncollected',
      state: 'uncollected',
    );
    const MapOverlayPoint far = MapOverlayPoint(
      id: 'fern',
      position: MapPosition(latitude: 48.3, longitude: 11.582),
      styleId: 'fact.hist.uncollected',
      state: 'uncollected',
    );
    const MapOverlay overlayWithTwoFacts = MapOverlay(
      id: factOverlayId,
      points: <MapOverlayPoint>[near, far],
    );
    const MapOverlayGroupTap tapOnFacts = MapOverlayGroupTap(
      overlayId: factOverlayId,
      position: MapPosition(latitude: 48.14, longitude: 11.59),
    );

    /// Lässt eine ausstehende Projektion antworten und die Folgen ankommen.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'nur der eine Kandidat im Radius geht ins Rechteck, mit 700 ms Dauer',
      (tester) async {
        await pumpPage(
          tester,
          container: newContainer(overlay: overlayWithTwoFacts),
        );
        // Zoom unter `factOverlayMinZoom` (11): `DiscoveryBalloonAnchor` im
        // selben Baum projiziert sonst selbst über denselben Host und
        // verunreinigt `host.projected`, das dieser Test auswertet.
        await mapComesAlive(tester, zoom: 5);
        // Zweimal gepumpt: die erste Ausgabe von `factOverlayProvider` ist
        // `AsyncLoading`, erst danach löst sich das Future auf und
        // `_onFactOverlay` setzt `_latestOverlay`.
        await tester.pump();
        await tester.pump();
        host.intents.clear();

        // Zwei Kandidaten und die Tippstelle gehen in **einem** Aufruf hinaus,
        // in dieser Reihenfolge: `near`, `far`, Tippstelle. `far` liegt weit
        // draußen (1000 Gerätepixel vom Tipp), `near` genau auf ihm.
        host.projectionAnswer = const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 1200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ];
        host.viewport = const MapViewport(
          widthInScreenPixels: 400,
          heightInScreenPixels: 800,
        );

        host.emitGroupTap(tapOnFacts);
        await settle(tester);

        expect(host.projected, hasLength(1), reason: 'ein gemeinsamer Aufruf');
        expect(
          host.projected.single,
          <MapPosition>[near.position, far.position, tapOnFacts.position],
          reason: 'Kandidaten zuerst, die Tippstelle mitprojiziert am Ende',
        );

        expect(host.intents, hasLength(1));
        final MapCameraIntent intent = host.intents.single;
        expect(intent, isA<MapCameraOneShot>());
        expect(
          intent.motion,
          const MapCameraAnimated(Duration(milliseconds: 700)),
        );
        expect(
          intent.change.center,
          near.position,
          reason:
              'nur "nah" liegt im Radius, das Rechteck ist also ein einzelner '
              'Punkt und sein Mittelpunkt ist genau dieser Punkt',
        );
        expect(
          intent.change.zoom,
          18,
          reason:
              'ein Rechteck der Fläche null (ein einzelner Punkt) stellt an '
              'keine Richtung eine Bedingung, `rectFitZoom` liefert dafür '
              'unverändert die Obergrenze 18 zurück (`map_camera_fit_test.dart`, '
              '„Fläche null"); die Untergrenze 16 hebt sie nicht wieder, weil '
              'max(18, 16) = 18',
        );
        expect(intent.change.bearing, isNull);
        expect(intent.change.pitch, isNull);
      },
    );

    testWidgets('beide Kandidaten im Radius: das Rechteck spannt beide auf', (
      tester,
    ) async {
      await pumpPage(
        tester,
        container: newContainer(overlay: overlayWithTwoFacts),
      );
      // Zoom unter `factOverlayMinZoom` (11): `DiscoveryBalloonAnchor` im
      // selben Baum projiziert sonst selbst über denselben Host und
      // verunreinigt `host.projected`, das dieser Test auswertet.
      await mapComesAlive(tester, zoom: 5);
      // Zweimal gepumpt: die erste Ausgabe von `factOverlayProvider` ist
      // `AsyncLoading`, erst danach löst sich das Future auf und
      // `_onFactOverlay` setzt `_latestOverlay`.
      await tester.pump();
      await tester.pump();
      host.intents.clear();

      // Beide Kandidaten liegen jetzt nah am Tipp (50 und 30 Gerätepixel),
      // deutlich innerhalb von 70 Stilpixeln mal 3 (Bildverhältnis der
      // Testumgebung) = 210 Gerätepixeln.
      host.projectionAnswer = const <MapScreenPoint?>[
        MapScreenPoint(
          xInScreenPixels: 150,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
        MapScreenPoint(
          xInScreenPixels: 230,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
        MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      host.viewport = const MapViewport(
        widthInScreenPixels: 400,
        heightInScreenPixels: 800,
      );

      host.emitGroupTap(tapOnFacts);
      await settle(tester);

      final MapCameraIntent intent = host.intents.single;
      expect(
        intent.change.center,
        MapPositionRect.enclosingOrNull(<MapPosition>[
          near.position,
          far.position,
        ])!.center,
      );
    });

    // Zwei weitere Tipps, nur mit anderer Tippstelle als [tapOnFacts]: das
    // reicht, um in `host.projected` zu unterscheiden, welcher Tipp welche
    // Anfrage ausgelöst hat.
    const MapOverlayGroupTap tapOnFactsAgain = MapOverlayGroupTap(
      overlayId: factOverlayId,
      position: MapPosition(latitude: 48.145, longitude: 11.595),
    );
    const MapOverlayGroupTap tapOnFactsLatest = MapOverlayGroupTap(
      overlayId: factOverlayId,
      position: MapPosition(latitude: 48.15, longitude: 11.6),
    );

    testWidgets(
      'drei Tipps kurz hintereinander: kommt die Antwort auf den ersten '
      'erst nach den beiden anderen zurück, entsteht trotzdem nur eine '
      'Absicht, und zwar die zum dritten (letzten) Tipp',
      (tester) async {
        // **Die Probe für Fund 1.** Ohne Sequenzsicherung startet
        // `_onGroupTap` für jeden Tipp eine eigene, unabhängige Anfrage;
        // kommt die Antwort auf den älteren Tipp dann später zurück als die
        // auf den neueren, überschreibt ihre Absicht die frische, und die
        // Kamera fährt auf die falsche Gruppe zurück. Mit der
        // Sequenzsicherung (`_groupTapInFlight`, `_pendingGroupTap`) läuft
        // nie mehr als eine Anfrage gleichzeitig: Die Anfrage zum gemerkten
        // Tipp startet erst, nachdem die laufende beantwortet ist, und deren
        // eigene, jetzt veraltete Antwort löst keine Absicht mehr aus.
        //
        // **Der dritte Tipp prüft zusätzlich, dass es keine Warteschlange
        // gibt.** Trifft er ein, während schon der zweite gemerkt ist, muss
        // er den zweiten verwerfen und an dessen Stelle treten; eine Probe,
        // die den zweiten stattdessen festhielte (der ältere gewinnt statt
        // des neueren), bliebe sonst unentdeckt, weil nur zwei Tipps dafür
        // nicht reichen.
        await pumpPage(
          tester,
          container: newContainer(overlay: overlayWithTwoFacts),
        );
        // Zoom unter `factOverlayMinZoom` (11), aus demselben Grund wie in
        // den anderen Tests dieser Gruppe.
        await mapComesAlive(tester, zoom: 5);
        await tester.pump();
        await tester.pump();
        host.intents.clear();
        host.viewport = const MapViewport(
          widthInScreenPixels: 400,
          heightInScreenPixels: 800,
        );
        host.projectionGates = <Completer<List<MapScreenPoint?>>>[];

        host.emitGroupTap(tapOnFacts);
        await tester.pump();
        host.emitGroupTap(tapOnFactsAgain);
        await tester.pump();
        host.emitGroupTap(tapOnFactsLatest);
        await tester.pump();

        expect(
          host.projectionGates,
          hasLength(1),
          reason:
              'weder der zweite noch der dritte Tipp lösen schon eine '
              'eigene Anfrage aus, solange die erste noch läuft',
        );
        expect(
          host.peakInFlight,
          1,
          reason: 'nie zwei Anfragen gleichzeitig unterwegs',
        );

        // Die Antwort auf den ersten (ältesten) Tipp: „near" liegt auf der
        // Tippstelle, „far" weit weg, die Auswahl wäre also „near".
        host.answerProjectionAt(0, const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 1200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ]);
        await tester.pump();
        await tester.pump();

        expect(
          host.projectionGates,
          hasLength(2),
          reason: 'erst jetzt startet die Anfrage zum gemerkten Tipp',
        );
        expect(
          host.projected[1].last,
          tapOnFactsLatest.position,
          reason:
              'gemerkt bleibt der dritte, jüngste Tipp, nicht der zweite: '
              'es gibt keine Warteschlange, der letzte verwirft jeden '
              'davor',
        );
        expect(
          host.intents,
          isEmpty,
          reason:
              'die Antwort auf den ersten Tipp ist schon veraltet, '
              'sobald ein weiterer gemerkt ist, und gibt keine Absicht ab',
        );

        // Die Antwort auf den gemerkten (dritten) Tipp: umgekehrt, jetzt
        // liegt „far" auf der Tippstelle.
        host.answerProjectionAt(1, const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 1200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ]);
        await tester.pump();
        await tester.pump();

        expect(
          host.intents,
          hasLength(1),
          reason: 'genau eine Absicht insgesamt, nicht eine je Tipp',
        );
        expect(
          host.intents.single.change.center,
          far.position,
          reason:
              'die Absicht gehört zum dritten, gemerkten Tipp, dessen '
              'Antwort "far" auswählt, nicht "near" aus der veralteten '
              'ersten',
        );
      },
    );

    testWidgets('ein Tipp mit fremder overlayId bleibt folgenlos', (
      tester,
    ) async {
      await pumpPage(
        tester,
        container: newContainer(overlay: overlayWithTwoFacts),
      );
      // Zoom unter `factOverlayMinZoom` (11): `DiscoveryBalloonAnchor` im
      // selben Baum projiziert sonst selbst über denselben Host und
      // verunreinigt `host.projected`, das dieser Test auswertet.
      await mapComesAlive(tester, zoom: 5);
      // Zweimal gepumpt: die erste Ausgabe von `factOverlayProvider` ist
      // `AsyncLoading`, erst danach löst sich das Future auf und
      // `_onFactOverlay` setzt `_latestOverlay`.
      await tester.pump();
      await tester.pump();
      host.intents.clear();
      host.viewport = const MapViewport(
        widthInScreenPixels: 400,
        heightInScreenPixels: 800,
      );

      host.emitGroupTap(
        const MapOverlayGroupTap(
          overlayId: 'tours.stations',
          position: MapPosition(latitude: 48.14, longitude: 11.59),
        ),
      );
      await settle(tester);

      expect(host.intents, isEmpty);
      expect(
        host.projected,
        isEmpty,
        reason: 'nicht einmal die Projektion wird angestoßen',
      );
    });

    testWidgets('ohne viewport (vor dem ersten Layout) entsteht keine '
        'Absicht', (tester) async {
      await pumpPage(
        tester,
        container: newContainer(overlay: overlayWithTwoFacts),
      );
      // Zoom unter `factOverlayMinZoom` (11): `DiscoveryBalloonAnchor` im
      // selben Baum projiziert sonst selbst über denselben Host und
      // verunreinigt `host.projected`, das dieser Test auswertet.
      await mapComesAlive(tester, zoom: 5);
      // Zweimal gepumpt: die erste Ausgabe von `factOverlayProvider` ist
      // `AsyncLoading`, erst danach löst sich das Future auf und
      // `_onFactOverlay` setzt `_latestOverlay`.
      await tester.pump();
      await tester.pump();
      host.intents.clear();
      // `host.viewport` bleibt ausdrücklich `null`.

      host.emitGroupTap(tapOnFacts);
      await settle(tester);

      expect(host.intents, isEmpty);
      expect(host.projected, isEmpty);
    });

    testWidgets(
      'ohne Bildschirmlage der Tippstelle selbst entsteht keine Absicht',
      (tester) async {
        await pumpPage(
          tester,
          container: newContainer(overlay: overlayWithTwoFacts),
        );
        // Zoom unter `factOverlayMinZoom` (11), aus demselben Grund wie im
        // ersten Test dieser Gruppe: `DiscoveryBalloonAnchor` soll nicht
        // mitprojizieren.
        await mapComesAlive(tester, zoom: 5);
        await tester.pump();
        await tester.pump();
        host.intents.clear();
        host.viewport = const MapViewport(
          widthInScreenPixels: 400,
          heightInScreenPixels: 800,
        );
        // Die Tippstelle selbst hat keine Bildschirmlage (letztes Element
        // `null`), obwohl beide Kandidaten eine haben.
        host.projectionAnswer = const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 210,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          null,
        ];

        host.emitGroupTap(tapOnFacts);
        await settle(tester);

        expect(host.intents, isEmpty);
      },
    );

    testWidgets(
      'kein Punkt im Radius: keine Absicht, aber eine Diagnose-Meldung',
      (tester) async {
        final RecordingSink sink = RecordingSink();
        await pumpPage(
          tester,
          container: newContainer(
            overlay: overlayWithTwoFacts,
            diagnostics: sink,
          ),
        );
        await mapComesAlive(tester, zoom: 5);
        await tester.pump();
        await tester.pump();
        host.intents.clear();
        host.viewport = const MapViewport(
          widthInScreenPixels: 400,
          heightInScreenPixels: 800,
        );
        // Beide Kandidaten weit weg von der Tippstelle.
        host.projectionAnswer = const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 2000,
            yInScreenPixels: 2000,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 3000,
            yInScreenPixels: 3000,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ];

        host.emitGroupTap(tapOnFacts);
        await settle(tester);

        expect(host.intents, isEmpty);
        expect(
          sink.events.map((event) => event.name),
          contains(groupTapFoundNoMembersEvent),
        );
      },
    );

    testWidgets(
      'nur die Punkte der wirklich gelegten Überlagerung sind Kandidaten, '
      'nicht die vollständige Liste',
      (tester) async {
        // **Die Probe, die die Mutation „volle Liste statt der Überlagerung, '
        // die wirklich auf der Karte liegt" fängt.** `near` lebt gerade als
        // Ballon-Widget und ist deshalb aus der nativen Liste heraus; nur
        // `far` darf noch Kandidat sein.
        final ProviderContainer container = newContainer(
          overlay: overlayWithTwoFacts,
        );
        await pumpPage(tester, container: container);
        await mapComesAlive(tester, zoom: 16);
        await tester.pump();
        await tester.pump();
        await emitFix(tester, fixAt());
        host.intents.clear();
        host.viewport = const MapViewport(
          widthInScreenPixels: 400,
          heightInScreenPixels: 800,
        );
        host.projectionAnswer = const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ];

        host.emitGroupTap(tapOnFacts);
        await settle(tester);

        // **Keine Zusicherung gegen `host.projected` hier**: bei diesem Zoom
        // (16, nötig für `factAnimationRunsAt`) projiziert
        // `DiscoveryBalloonAnchor` im selben Baum über denselben Host mit,
        // und beide Aufrufe landen ununterscheidbar in derselben Liste. Die
        // eigentliche Zusicherung dieses Tests ist ohnehin die Absicht, nicht
        // der Kanalaufruf.
        expect(
          host.intents.single.change.center,
          far.position,
          reason: '"near" lebt gerade und ist kein nativer Kandidat mehr',
        );
      },
    );

    testWidgets('ein Tipp nach dem Entsorgen des Bildschirms bleibt '
        'folgenlos', (tester) async {
      await pumpPage(
        tester,
        container: newContainer(overlay: overlayWithTwoFacts),
      );
      // Zoom unter `factOverlayMinZoom` (11): `DiscoveryBalloonAnchor` im
      // selben Baum projiziert sonst selbst über denselben Host und
      // verunreinigt `host.projected`, das dieser Test auswertet.
      await mapComesAlive(tester, zoom: 5);
      // Zweimal gepumpt: die erste Ausgabe von `factOverlayProvider` ist
      // `AsyncLoading`, erst danach löst sich das Future auf und
      // `_onFactOverlay` setzt `_latestOverlay`.
      await tester.pump();
      await tester.pump();
      host.intents.clear();
      host.viewport = const MapViewport(
        widthInScreenPixels: 400,
        heightInScreenPixels: 800,
      );
      host.pendingProjection = Completer<List<MapScreenPoint?>>();

      host.emitGroupTap(tapOnFacts);
      await tester.pump();

      // Der Bildschirm verschwindet, während die Projektion noch unterwegs
      // ist.
      await tester.pumpWidget(const SizedBox.shrink());

      host.answerProjection(const <MapScreenPoint?>[
        MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
        MapScreenPoint(
          xInScreenPixels: 1200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
        MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(host.intents, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ein Tipp, der erst nach dem Entsorgen des Bildschirms eintrifft, '
      'bleibt folgenlos',
      (tester) async {
        // **Anders als der Test oben.** Dort trifft der Tipp noch vor dem
        // Entsorgen ein, nur seine Antwort kommt danach zurück; das prüft
        // `mounted` in der `.then()`-Fortsetzung. Hier trifft der Tipp selbst
        // erst nach dem Entsorgen ein, und das prüft das Abmelden in
        // `dispose`: bliebe `_groupTapSubscription` dort abonniert, riefe der
        // Strom `_onGroupTap` auf einem längst entsorgten `State` auf.
        await pumpPage(
          tester,
          container: newContainer(overlay: overlayWithTwoFacts),
        );
        await mapComesAlive(tester, zoom: 5);
        await tester.pump();
        await tester.pump();
        host.intents.clear();
        host.viewport = const MapViewport(
          widthInScreenPixels: 400,
          heightInScreenPixels: 800,
        );
        host.projectionAnswer = const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 1200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ];

        await tester.pumpWidget(const SizedBox.shrink());

        host.emitGroupTap(tapOnFacts);
        await settle(tester);

        expect(host.intents, isEmpty);
        expect(
          host.projected,
          isEmpty,
          reason:
              'ohne Abonnement erreicht der Tipp `_onGroupTap` gar nicht '
              'erst',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Ein gesammelter Fakt bleibt gesammelt', () {
    // **Diese Verdrahtung hatte bis zum 02.09.2026 keinen einzigen Test**,
    // und sie ist genau die Sorte, die `REBUILD_STATUS.md` als Muster 10
    // führt: wenige Zeilen Durchreichung, die in der App wirklich laufen. Bis
    // dahin gab es auch nichts zu prüfen, das Sammeln endete in einer
    // Diagnosemeldung.

    const MapOverlay numericOverlay = MapOverlay(
      id: factOverlayId,
      points: <MapOverlayPoint>[
        MapOverlayPoint(
          // Eine Zahl, weil `Fact.id` eine ist und weil der automatische
          // Sammelweg alles andere bewusst überspringt.
          id: '7',
          position: MapPosition(latitude: 48.1351, longitude: 11.582),
          styleId: 'fact.hist.uncollected',
          state: 'uncollected',
        ),
      ],
    );

    testWidgets('ein Fakt direkt neben dem Nutzer landet in der Sammlung', (
      tester,
    ) async {
      final ProviderContainer container = newContainer(overlay: numericOverlay);
      await pumpPage(tester, container: container);
      await mapComesAlive(tester, zoom: 16);

      await emitFix(tester, fixAt());

      expect(container.read(collectedFactsProvider), const <FactId>[FactId(7)]);
    });

    // **Dass derselbe Fakt nicht zweimal in der Sammlung landet, steht nicht
    // hier**, und das ist eine Grenze dieses Aufbaus und keine Auslassung.
    // Der zweite Sammelvorgang braucht das Ende des ersten, und nach
    // `factCollectRevealDelay` ruft `_onOpenFact` die Route auf. `pumpPage`
    // stellt keinen `GoRouter`, also endet der Test in „No GoRouter found in
    // context". Die Zusicherung liegt deshalb dort, wo sie ohne Navigation
    // prüfbar ist: `collected_facts_providers_test.dart` („ein zweiter
    // Sammelvorgang auf denselben Fakt") und
    // `fact_collect_overlay_test.dart` („eine zweite Ortung sammelt denselben
    // Fakt nicht erneut").

    testWidgets('eine Kennung, die keine Zahl ist, landet nirgends', (
      tester,
    ) async {
      // Die Kennungen setzt `factOverlayOf` aus `Fact.id`, eine unlesbare
      // wäre also ein Verdrahtungsfehler. Sie darf nicht mit einem `!` in
      // einen Absturz laufen, und sie darf auch nicht als Fakt Nummer
      // irgendetwas in der Sammlung landen.
      final ProviderContainer container = newContainer(
        overlay: overlayWithNearbyFact,
      );
      await pumpPage(tester, container: container);
      await mapComesAlive(tester, zoom: 16);

      await emitFix(tester, fixAt());

      expect(container.read(collectedFactsProvider), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('die Münzen bucht dabei niemand, und das ist gemeldet', (
      tester,
    ) async {
      // `MapPage.unbookedCollectEvent`. Die Naht ist absichtlich sichtbar:
      // die Belohnungsregel aus J-C verlangt ein Buchungsjournal, das es
      // nicht gibt. Wer die Buchung anschließt, löscht diese Meldung, und
      // dieser Test ist die Stelle, an der er es merkt.
      final RecordingSink sink = RecordingSink();
      final ProviderContainer container = newContainer(
        overlay: numericOverlay,
        diagnostics: sink,
      );
      await pumpPage(tester, container: container);
      await mapComesAlive(tester, zoom: 16);

      await emitFix(tester, fixAt());

      expect(
        sink.events
            .map((DiagnosticEvent event) => event.name)
            .where((String name) => name == MapPage.unbookedCollectEvent),
        <String>[MapPage.unbookedCollectEvent],
      );
      expect(
        sink.events
            .where(
              (DiagnosticEvent e) => e.name == MapPage.unbookedCollectEvent,
            )
            .single
            .attributes,
        isEmpty,
        reason:
            'die Fakt-Kennung darf nicht mitgehen, sie wäre zusammen mit der '
            'öffentlichen Koordinate eine Standortspur (security.md §6)',
      );
    });
  });
}

/// Ein Karten-Host, der jede Absicht mitschreibt statt sie auszuführen.
///
/// Er muss ein Doppelgänger sein: der echte Host bekommt seine Kamera aus
/// `onMapCreated`, und das läuft ohne Plattformkanal nie
/// (`maplibre_map.dart:390-418`).
class FakeMapHost implements MapHost {
  final StreamController<MapCameraView> _cameras =
      StreamController<MapCameraView>.broadcast();

  /// Alles, was abgegeben wurde, in der Reihenfolge des Eingangs.
  final List<MapCameraIntent> intents = <MapCameraIntent>[];

  MapCameraView? _camera;

  @override
  MapCameraView? get camera => _camera;

  @override
  Stream<MapCameraView> get cameraChanges => _cameras.stream;

  /// `null`, bis ein Test [viewport] setzt: genau der Zustand vor dem ersten
  /// Layout der Kartenfläche.
  @override
  MapViewport? viewport;

  final StreamController<MapOverlayPointTap> _pointTaps =
      StreamController<MapOverlayPointTap>.broadcast();

  final StreamController<MapOverlayGroupTap> _groupTaps =
      StreamController<MapOverlayGroupTap>.broadcast();

  @override
  Stream<MapOverlayGroupTap> get groupTaps => _groupTaps.stream;

  @override
  Stream<MapOverlayPointTap> get pointTaps => _pointTaps.stream;

  /// Schiebt einen Gruppen-Tipp in den Strom, wie `MapOverlayHost` es täte.
  void emitGroupTap(MapOverlayGroupTap tap) => _groupTaps.add(tap);

  void emitPointTap(MapOverlayPointTap tap) => _pointTaps.add(tap);

  @override
  void submitIntent(MapCameraIntent intent) => intents.add(intent);

  /// Die Bilder, die angemeldet wurden, in der Reihenfolge des Eingangs.
  final List<MapOverlayImage> registeredImages = <MapOverlayImage>[];

  /// Die Überlagerungen, die gesetzt wurden, in der Reihenfolge des Eingangs.
  final List<MapOverlay> overlays = <MapOverlay>[];

  /// Die Kennungen, die entfernt wurden.
  final List<String> removedOverlays = <String>[];

  /// Bilder und Überlagerungen in **einer** Liste, in der Reihenfolge des
  /// Eingangs.
  ///
  /// Zwei getrennte Listen sagen nichts über die Reihenfolge, und genau die
  /// ist die Zusage von `MapHost.registerOverlayImages`.
  final List<String> arrivals = <String>[];

  @override
  void registerOverlayImages(List<MapOverlayImage> images) {
    registeredImages.addAll(images);
    arrivals.add('images');
  }

  @override
  void setOverlay(MapOverlay overlay) {
    overlays.add(overlay);
    arrivals.add('overlay:${overlay.id}');
  }

  @override
  void removeOverlay(String overlayId) => removedOverlays.add(overlayId);

  /// Die Anfragen an die Projektion, in der Reihenfolge des Eingangs.
  final List<List<MapPosition>> projected = <List<MapPosition>>[];

  /// Wie viele Anfragen gerade gleichzeitig unterwegs sind.
  ///
  /// Es gibt diesen Zähler, weil „nie zwei gleichzeitig" sonst nicht prüfbar
  /// wäre: eine bloße Anzahl der Aufrufe sagt nichts darüber, ob sie sich
  /// überlappt haben.
  int inFlight = 0;

  /// Der höchste je gleichzeitig erreichte Stand von [inFlight].
  int peakInFlight = 0;

  /// Wenn gesetzt, antwortet die Projektion erst, wenn der Test es sagt.
  Completer<List<MapScreenPoint?>>? pendingProjection;

  /// Was die Projektion liefert, wenn sie sofort antwortet.
  List<MapScreenPoint?>? projectionAnswer;

  /// Ist diese Liste gesetzt (nicht `null`), reiht jeder Aufruf von
  /// [projectToScreen] einen eigenen Riegel hier ein, statt sofort oder über
  /// [pendingProjection] zu antworten.
  ///
  /// **Der Unterschied zu [pendingProjection]:** der eine Riegel dort passt
  /// nur für eine einzelne unterwegs befindliche Anfrage; zwei Anfragen, die
  /// sich zeitlich überlappen, teilten sich denselben Riegel und ließen sich
  /// nicht mehr unabhängig beantworten. Diese Liste gibt jedem Aufruf, in der
  /// Reihenfolge seines Eingangs, seinen eigenen Riegel, damit ein Test die
  /// Reihenfolge der **Antworten** unabhängig von der Reihenfolge der
  /// **Aufrufe** bestimmen kann, siehe [answerProjectionAt]. Das ist der Kern
  /// von Fund 1: die Antwort auf den ersten Tipp soll nach der Antwort auf
  /// den zweiten zurückkommen.
  List<Completer<List<MapScreenPoint?>>>? projectionGates;

  @override
  Future<List<MapScreenPoint?>> projectToScreen(List<MapPosition> positions) {
    projected.add(positions);
    inFlight++;
    peakInFlight = inFlight > peakInFlight ? inFlight : peakInFlight;
    final List<Completer<List<MapScreenPoint?>>>? gates = projectionGates;
    final Future<List<MapScreenPoint?>> answer;
    if (gates != null) {
      final Completer<List<MapScreenPoint?>> gate =
          Completer<List<MapScreenPoint?>>();
      gates.add(gate);
      answer = gate.future;
    } else {
      final Completer<List<MapScreenPoint?>>? gate = pendingProjection;
      answer = gate != null
          ? gate.future
          : Future<List<MapScreenPoint?>>.value(
              projectionAnswer ??
                  List<MapScreenPoint?>.filled(positions.length, null),
            );
    }
    return answer.whenComplete(() => inFlight--);
  }

  /// Lässt eine angehaltene Projektion antworten.
  void answerProjection(List<MapScreenPoint?> answer) {
    final Completer<List<MapScreenPoint?>>? gate = pendingProjection;
    pendingProjection = null;
    gate?.complete(answer);
  }

  /// Lässt den Aufruf mit dem Index [index] aus [projectionGates] antworten,
  /// in der Reihenfolge des Eingangs bei [projectToScreen] gezählt, nicht in
  /// der Reihenfolge der Antworten. Index 0 ist also immer der **erste**
  /// Aufruf, ganz gleich, ob er zuerst oder zuletzt antwortet.
  void answerProjectionAt(int index, List<MapScreenPoint?> answer) {
    projectionGates![index].complete(answer);
  }

  /// Die Karte steht: dasselbe Signal, das `MapCameraHost.bindSurface` sendet.
  void bind(MapCameraView view) {
    _camera = view;
    _cameras.add(view);
  }

  /// Schließt den Kamerastrom und den Gruppen-Tipp-Strom.
  Future<void> close() => Future.wait<void>([
    _cameras.close(),
    _groupTaps.close(),
    _pointTaps.close(),
  ]);
}

/// Eine Diagnose-Senke, die mitschreibt.
class RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}

/// Ein Ortungsdienst, dessen Ausgaben der Test selbst setzt.
class FakeLocationService implements LocationService {
  /// `broadcast`, damit `close()` auch dann erfüllt wird, wenn niemand
  /// zugehört hat.
  final StreamController<DevicePosition> _controller =
      StreamController<DevicePosition>.broadcast();

  @override
  Stream<DevicePosition> positionUpdates() => _controller.stream;

  /// Schiebt eine Ortung in den Strom.
  void emit(DevicePosition position) => _controller.add(position);

  /// Schließt den Strom.
  Future<void> close() => _controller.close();
}

/// Ein Orientierungsdienst, dessen Kopfwerte der Test selbst setzt.
///
/// Dasselbe Muster wie [FakeLocationService], nur für [DeviceHeading].
class FakeOrientationService implements OrientationService {
  /// `broadcast`, aus demselben Grund wie bei [FakeLocationService].
  final StreamController<DeviceHeading> _controller =
      StreamController<DeviceHeading>.broadcast();

  @override
  Stream<DeviceHeading> headingUpdates() => _controller.stream;

  /// Schiebt einen Kopfwert in den Strom.
  void emit(DeviceHeading heading) => _controller.add(heading);

  /// Schließt den Strom.
  Future<void> close() => _controller.close();
}

/// Eine von Hand vorspulbare Uhr für den Kompass-Wachhund.
///
/// Dasselbe Muster wie `TestClock` in `map_camera_host_test.dart`: der Test
/// stellt [now] selbst weiter, ohne echtes Warten und ohne sich auf die
/// Verzahnung von `Stopwatch` und `fake_async` zu verlassen, die
/// `map_page.dart`s eigener Kommentar bei `_now` beschreibt.
class TestClock {
  Duration now = Duration.zero;

  Duration call() => now;

  void advance(Duration by) => now += by;
}
