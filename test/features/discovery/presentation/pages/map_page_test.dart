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
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/map_camera_intents.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_gate.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
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

  setUp(() {
    host = FakeMapHost();
    location = FakeLocationService();
  });

  tearDown(() async {
    await host.close();
    await location.close();
  });

  /// [withFakeHost] `false` lässt die **echte** `MapHostRegistry` stehen.
  ///
  /// Das braucht genau eine Prüfung, und sie ist der Grund, warum es den
  /// Schalter gibt: der Doppelgänger meldet nichts, die Registry meldet
  /// `map.host.missing`, sobald jemand ohne Karte nach der Kamera fragt.
  ProviderContainer newContainer({
    bool withFakeHost = true,
    DiagnosticSink? diagnostics,
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
        factOverlayProvider.overrideWith((ref) async => factOverlay),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required ProviderContainer container,
    bool branchIsActive = true,
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
      // je Kategorie ein Bild, und mit dem Bildverhältnis des Bildschirms.
      // Was dabei gezeichnet wird, steht in `fact_balloon_images_test.dart`.
      await tester.runAsync(() async {
        await pumpPage(tester, container: newContainer());
        await tester.pump();
        await awaitBalloons(tester);
      });

      expect(host.registeredImages, hasLength(factCategoryStyles.length));
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

      expect(host.registeredImages, hasLength(factCategoryStyles.length));
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

      expect(host.registeredImages, hasLength(factCategoryStyles.length));
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

  /// Die Karte steht: dasselbe Signal, das `MapCameraHost.bindSurface` sendet.
  void bind(MapCameraView view) {
    _camera = view;
    _cameras.add(view);
  }

  /// Schließt den Kamerastrom.
  Future<void> close() => _cameras.close();
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
