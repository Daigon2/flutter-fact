import 'dart:async';
import 'dart:math' as math;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/features/discovery/presentation/fact_auto_collect.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_collect_burst.dart';
import 'package:fact_app/features/discovery/presentation/fact_collect_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/features/discovery/presentation/fact_teaser_card.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Sammel-Erlebnis: der Ablauf von einem Tipp bis zum Fakt-Blatt.
///
/// **Keine echte Zeit und kein Karten-SDK.** Der Karten-Host ist ein
/// Doppelgänger, weil im Widget-Test nie ein `MapLibreMapController` entsteht;
/// die 1400 Millisekunden werden mit `tester.pump(Duration(...))` vorgespult,
/// wie `.claude/rules/tests.md` es verlangt.
void main() {
  const MapPosition user = MapPosition(latitude: 48.1351, longitude: 11.582);

  /// Ein Punkt in [meters] Metern nördlich des Nutzers. Dieselbe Umrechnung
  /// wie in `fact_proximity_test.dart`.
  MapPosition northOf(double meters) => MapPosition(
    latitude: user.latitude + meters * 180 / (math.pi * 6371000),
    longitude: user.longitude,
  );

  late _FakeCollectMapHost host;
  late _FakeLocationService location;
  late List<String> collected;
  late List<String> opened;

  setUp(() {
    host = _FakeCollectMapHost();
    location = _FakeLocationService();
    collected = <String>[];
    opened = <String>[];
  });

  tearDown(() async {
    await host.close();
    await location.close();
  });

  MapOverlayPoint pointAt(String id, double meters) => MapOverlayPoint(
    id: id,
    position: northOf(meters),
    styleId: factBalloonStyleId('hist', factNotCollectedState),
    state: factNotCollectedState,
  );

  Fact factWith(int id, String title) => Fact(
    id: FactId(id),
    content: FactText(title: title, category: 'Historisch'),
    coordinates: FactCoordinates(
      latitude: user.latitude,
      longitude: user.longitude,
    ),
  );

  ProviderContainer newContainer({
    required List<MapOverlayPoint> points,
    FactProximity proximity = FactProximity.empty,
    List<Fact> facts = const <Fact>[],
    AppLanguage language = AppLanguage.de,
    List<FactId> collectedFacts = const <FactId>[],
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        collectedFactsStoreProvider.overrideWithValue(
          InMemoryCollectedFactsStore(collectedFacts),
        ),
        mapHostProvider.overrideWithValue(host),
        locationServiceProvider.overrideWithValue(location),
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(),
        ),
        appLanguageProvider.overrideWith(
          () => _FixedLanguageNotifier(language),
        ),
        // **Die Überlagerung und nicht das Repository.** Der Standard
        // `unavailableFactRepository` wirft, und Riverpod wiederholt das
        // zehnmal; der erste Timer überlebt den Widget-Baum. Dieselbe
        // Begründung wie in `map_page_test.dart`.
        factOverlayProvider.overrideWith(
          (ref) async => MapOverlay(id: factOverlayId, points: points),
        ),
        allFactsProvider.overrideWith((ref) async => facts),
        // Die Näherungsrechnung hat ihren eigenen Test, siehe
        // `fact_proximity_test.dart`. Hier wird nur gebraucht, wer als
        // lebender Ballon gezeichnet wird.
        factProximityProvider.overrideWithValue(proximity),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required ProviderContainer container,
    int coinAmount = 10,
    double Function()? nextDouble,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              FactCollectOverlay(
                coinAmount: coinAmount,
                onCollected: collected.add,
                onOpenFact: opened.add,
                nextDouble: nextDouble ?? () => 0.5,
              ),
            ],
          ),
        ),
      ),
    );
    // Zweimal: die erste Ausgabe von `factOverlayProvider` ist `AsyncLoading`.
    await tester.pump();
    await tester.pump();
  }

  /// Eine angenommene Ortung am Standort des Nutzers.
  Future<void> locateUser(WidgetTester tester) async {
    location.emit(
      DevicePosition(
        latitude: user.latitude,
        longitude: user.longitude,
        // Unter der 35-Meter-Schranke von `UserLocationNotifier`, sonst wird
        // die Ortung verworfen und der Test messe etwas anderes.
        accuracyInMeters: 10,
      ),
    );
    await tester.pump();
  }

  /// Die Karte meldet sich, wie `bindSurface` es tut.
  Future<void> mapComesAlive(WidgetTester tester, {double zoom = 16}) async {
    host.bind(MapCameraView(center: user, zoom: zoom, bearing: 0, pitch: 58));
    await tester.pump();
    await tester.pump();
  }

  /// Tippt einen nativen Punkt an und lässt den Strom durchlaufen.
  ///
  /// **Zweimal gepumpt, und das ist gemessen.** Ein Broadcast-Strom liefert
  /// sein Ereignis in einem Mikrotask; `tester.pump()` leert die Mikrotasks
  /// **vor** dem Bild, das Ereignis kommt aber erst danach an. Das `setState`
  /// des Empfängers braucht deshalb ein zweites Bild. Mit nur einem `pump`
  /// war jeder Test dieser Datei grün-durchgefallen: nichts kam an, und der
  /// erste Verdacht fiel auf die Verdrahtung statt auf den Takt.
  Future<void> tap(
    WidgetTester tester,
    MapOverlayPointTap tap_, {
    Duration? then,
  }) async {
    host.tapPoint(tap_);
    await tester.pump();
    await tester.pump();
    if (then != null) {
      await tester.pump(then);
    }
  }

  MapOverlayPointTap tapOn(String id, double meters) => MapOverlayPointTap(
    overlayId: factOverlayId,
    pointId: id,
    // Absichtlich **nicht** die Position des Punktes: das SDK liefert die
    // Fingerstelle. Der Empfänger muss die Koordinate über die Kennung
    // nachschlagen, siehe `_onPointTap`.
    position: northOf(meters + 500),
  );

  group('Die Regel am Punkt-Tipp', () {
    testWidgets('innerhalb des Radius wird gesammelt', (tester) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 100)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(tester, tapOn('7', 100));

      expect(collected, <String>['7']);
      expect(find.byType(FactTeaserCard), findsNothing);
    });

    testWidgets('eine Ortung, die schon vorlag, wird beim Entstehen gelesen', (
      tester,
    ) async {
      // Der Fall nach einem Tabwechsel: `userLocationProvider` trägt längst
      // eine Ortung, und dieses Widget entsteht neu. Ohne `fireImmediately`
      // am `listenManual` bliebe `_fix` leer, die Regel entschiede „ohne
      // Ortung", und es gäbe **nie** ein Sammeln.
      //
      // **Die Reihenfolge ist der ganze Test.** Alle anderen Tests dieser
      // Datei ordnen erst das Widget und dann die Ortung an, und in dieser
      // Richtung feuert der Hörer ohnehin. Deshalb hat eine Mutation, die
      // `fireImmediately` entfernt, am 02.09.2026 die **ganze Datei
      // überlebt**, obwohl der Kommentar am Hörer den Fall benennt. Muster
      // 25 aus dem Blindheitskatalog, nur andersherum: nicht die Zusicherung
      // war zu schwach, sondern der Aufbau prüfte den Fall nie.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 100)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );

      // Jemand muss lesen, sonst klinkt sich `UserLocationNotifier` gar
      // nicht am Ortungsdienst ein und die Meldung fällt ins Leere.
      container.read<UserLocationState>(userLocationProvider);
      location.emit(
        DevicePosition(
          latitude: user.latitude,
          longitude: user.longitude,
          accuracyInMeters: 10,
        ),
      );
      // Ein leeres Bild, damit der Halter die Meldung verarbeitet, **bevor**
      // das Widget entsteht.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await pumpOverlay(tester, container: container);
      await tap(tester, tapOn('7', 100));

      expect(collected, <String>['7']);
      expect(find.byType(FactTeaserCard), findsNothing);
    });

    testWidgets('außerhalb des Radius wird nicht gesammelt, sondern die '
        'Vorschau gezeigt', (tester) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 900)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(tester, tapOn('7', 900));

      expect(collected, isEmpty);
      // **Beides geprüft: die Anwesenheit der Vorschau und die Abwesenheit
      // des Blattes.** Ein Test, der nur die Abwesenheit prüft, unterscheidet
      // „nichts" nicht von „etwas anderes"; daran ist in diesem Projekt schon
      // ein Test blind gewesen (Muster 25).
      expect(find.byType(FactTeaserCard), findsOneWidget);
      expect(find.text('Alter Peter'), findsOneWidget);
      expect(opened, isEmpty);
      expect(find.byType(FactCollectBurst), findsNothing);
    });

    testWidgets('ohne Ortung wird nicht gesammelt, sondern die Vorschau '
        'gezeigt', (tester) async {
      // **Die Anti-Sofa-Regel, und sie braucht ihren eigenen Test.** Der Fakt
      // liegt hier genau **auf** dem Nutzer; nur die fehlende Ortung
      // verhindert das Sammeln. Ein Aufbau mit einem fernen Fakt wäre aus dem
      // falschen Grund grün.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 0)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      // **Kein `locateUser`**: das ist der Punkt dieses Tests.

      await tap(tester, tapOn('7', 0));

      expect(collected, isEmpty);
      expect(opened, isEmpty);
      expect(find.byType(FactCollectBurst), findsNothing);
      expect(find.byType(FactTeaserCard), findsOneWidget);
    });

    testWidgets('ohne Ortung zeigt die Vorschau keine Entfernung, sondern '
        'die eigene Zeile', (tester) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 0)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);

      await tap(tester, tapOn('7', 0));

      // `screen-map.jsx:3856-3858`, über die Ergänzungs-Map.
      final String expected = AppStrings.of(
        AppLanguage.de,
      ).text('map.teaser.locationUnknown').toUpperCase();
      expect(find.text(expected), findsOneWidget);
      expect(find.textContaining('0 m'), findsNothing);
    });

    testWidgets('ein Tipp auf eine fremde Überlagerung geht diesen '
        'Bildschirm nichts an', (tester) async {
      // **50 Meter und nicht 10, seit dem 02.09.2026.** Der Punkt muss
      // innerhalb des Sammelradius liegen, damit ein Tipp überhaupt sammeln
      // könnte, und **außerhalb** von `factAutoCollectRadiusInMeters`, sonst
      // sammelt ihn die Ortung von selbst ein und dieser Test prüfte den
      // Tipp-Weg nicht mehr. Bei 10 Metern war er nach dem Bau des
      // automatischen Sammelns rot, und das war richtig so.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 50)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(
        tester,
        MapOverlayPointTap(
          overlayId: 'events.today',
          pointId: '7',
          position: user,
        ),
      );
      await tester.pump();

      expect(collected, isEmpty);
      expect(find.byType(FactTeaserCard), findsNothing);
    });

    testWidgets('eine Kennung, die die Überlagerung nicht kennt, tut nichts', (
      tester,
    ) async {
      // 50 statt 10 Meter, aus dem Grund im Test darüber.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 50)],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(tester, tapOn('999', 50));

      expect(collected, isEmpty);
      expect(find.byType(FactTeaserCard), findsNothing);
    });

    testWidgets('die Entfernung kommt aus der Koordinate des Punktes und '
        'nicht aus der Fingerstelle', (tester) async {
      // **Der Tipp liegt 900 Meter weiter nördlich als der Punkt.** Rechnete
      // der Empfänger mit `tap.position`, wäre dieser Fakt außer Reichweite
      // und es gäbe nur die Vorschau. Der Punkt selbst liegt bei 50 Metern.
      //
      // **Und 50 und nicht 10, seit dem 02.09.2026.** Dieser Test war mit
      // 10 Metern grün, aber aus dem falschen Grund: die Ortung hätte den
      // Fakt ohnehin von selbst eingesammelt, und dann wäre die Zusicherung
      // unten auch bei einem Empfänger erfüllt, der mit der Fingerstelle
      // rechnet. Ein grüner Test, der seine eigene Aussage nicht mehr prüft,
      // ist die teuerste Sorte; er steht als Muster 26 im Blindheitskatalog.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 50)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(
        tester,
        MapOverlayPointTap(
          overlayId: factOverlayId,
          pointId: '7',
          position: northOf(950),
        ),
      );
      await tester.pump();

      expect(collected, <String>['7']);
    });
  });

  group('Die Vorschau', () {
    testWidgets('zeigt Entfernung, Titel und den Hinweis', (tester) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 320)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(tester, tapOn('7', 320));

      final AppStrings strings = AppStrings.of(AppLanguage.de);
      expect(
        find.text('🔒 320 M ${strings.text('map.away').toUpperCase()}'),
        findsOneWidget,
      );
      expect(find.text('Alter Peter'), findsOneWidget);
      expect(find.text(strings.text('map.walkToCollect')), findsOneWidget);
    });

    testWidgets('der Schließen-Knopf nimmt sie weg', (tester) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 320)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);
      await tap(tester, tapOn('7', 320));

      await tester.tap(find.text('×'));
      await tester.pump();

      expect(find.byType(FactTeaserCard), findsNothing);
    });

    testWidgets('ein Tipp auf den Titel öffnet nichts', (tester) async {
      // **Das ist die Produktregel und keine Kosmetik.** Der Kommentar der
      // Quelle sagt wörtlich „KEIN onClick mehr. Die Vorschau IST das
      // Erlebnis fuer entfernte Fakten; der Detail-Screen darf nur vor Ort
      // geoeffnet werden, sonst kann man die Stadt vom Sofa aus durchlesen."
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 320)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);
      await tap(tester, tapOn('7', 320));

      await tester.tap(find.text('Alter Peter'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));

      expect(opened, isEmpty);
      expect(collected, isEmpty);
      expect(find.byType(FactTeaserCard), findsOneWidget);
    });

    testWidgets('auf Englisch steht die Zeile ohne Ortung auf Englisch', (
      tester,
    ) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 0)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
        language: AppLanguage.en,
      );
      await pumpOverlay(tester, container: container);

      await tap(tester, tapOn('7', 0));

      expect(
        find.text(
          AppStrings.of(
            AppLanguage.en,
          ).text('map.teaser.locationUnknown').toUpperCase(),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          AppStrings.of(
            AppLanguage.de,
          ).text('map.teaser.locationUnknown').toUpperCase(),
        ),
        findsNothing,
      );
    });
  });

  group('Der Ablauf des Sammelns', () {
    Future<ProviderContainer> readyToCollect(WidgetTester tester) async {
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 20)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);
      return container;
    }

    testWidgets('der Sammel-Rückruf feuert sofort und nicht erst nach 1400 '
        'Millisekunden', (tester) async {
      await readyToCollect(tester);

      await tap(tester, tapOn('7', 20));
      // **Kein `pump` mit Dauer**: geprüft wird der Zustand unmittelbar nach
      // dem Tipp. Die Buchung darf nicht an der Animation hängen, siehe
      // `FactCollectOverlay.onCollected`.
      await tester.pump();

      expect(collected, <String>['7']);
      expect(opened, isEmpty, reason: 'das Blatt kommt erst nach 1400 ms');
    });

    testWidgets('die Münzen fliegen an der projizierten Lage los', (
      tester,
    ) async {
      await readyToCollect(tester);

      await tap(tester, tapOn('7', 20));

      expect(find.byType(FactCollectBurst), findsOneWidget);
      // **Die Projektion liefert Gerätepixel, `Positioned` rechnet in
      // logischen.** Der Testrahmen hat den Faktor 3, und genau daran ist
      // diese Zusicherung beim ersten Lauf gescheitert: erwartet war 200/400,
      // gekommen 66,7/133,3. Der Faktor steht hier deshalb ausgeschrieben und
      // nicht als fertige Zahl, sonst prüfte der Test eine Umrechnung, die er
      // selbst voraussetzt. Begründung und Gerätemessung stehen an
      // `FactBalloonOverlay._balloonAt`.
      final double ratio = tester.view.devicePixelRatio;
      expect(ratio, 3, reason: 'der Standard des Testrahmens');
      expect(
        tester.widget<FactCollectBurst>(find.byType(FactCollectBurst)).origin,
        Offset(200 / ratio, 400 / ratio),
      );
      expect(host.projected.single, <MapPosition>[northOf(20)]);
    });

    testWidgets('die Zahl im Münzflug ist die übergebene', (tester) async {
      await readyToCollect(tester);

      await tap(tester, tapOn('7', 20));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('+10 🪙'), findsOneWidget);
      // Die 12 der Quelle ist ein gemessener Defekt (E-06, Anzeigehälfte) und
      // wird nicht nachgebaut.
      expect(find.text('+12 🪙'), findsNothing);
    });

    testWidgets('eine andere übergebene Zahl steht auch anders da', (
      tester,
    ) async {
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 0,
          yInScreenPixels: 0,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 20)],
      );
      await pumpOverlay(tester, container: container, coinAmount: 50);
      await locateUser(tester);

      await tap(tester, tapOn('7', 20));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('+50 🪙'), findsOneWidget);
      expect(find.text('+10 🪙'), findsNothing);
    });

    testWidgets('nach 1400 Millisekunden ist die Animation weg und das Blatt '
        'offen', (tester) async {
      await readyToCollect(tester);

      await tap(tester, tapOn('7', 20));
      await tester.pump(const Duration(milliseconds: 1399));

      expect(
        find.byType(FactCollectBurst),
        findsOneWidget,
        reason: 'eine Millisekunde davor läuft die Animation noch',
      );
      expect(opened, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(FactCollectBurst), findsNothing);
      expect(opened, <String>['7']);
    });

    testWidgets('ein zweiter Tipp während der Animation tut nichts', (
      tester,
    ) async {
      // Die Sperre aus `screen-map.jsx:1474`: `if (collectAnim) return;`.
      await readyToCollect(tester);

      await tap(tester, tapOn('7', 20));
      await tap(tester, tapOn('7', 20));

      expect(collected, <String>['7']);
      expect(host.projected, hasLength(1));

      await tester.pump(const Duration(milliseconds: 1400));

      expect(opened, <String>['7'], reason: 'nur einmal, nicht zweimal');
    });

    testWidgets('die Sperre greift auch, bevor die Projektion geantwortet '
        'hat', (tester) async {
      // **Das Zeitfenster, das es in der Quelle nicht gibt**, siehe
      // `_collecting`. Dort ist `mapInst.project` synchron; hier liegt
      // zwischen Tipp und Animation ein Umlauf über den Plattformkanal, und
      // ohne eigenes Sperr-Feld wäre die Sperre in dieser Lücke offen.
      host.pendingProjection = Completer<List<MapScreenPoint?>>();
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 20)],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(tester, tapOn('7', 20));
      expect(find.byType(FactCollectBurst), findsNothing);

      await tap(tester, tapOn('7', 20));

      expect(collected, <String>['7']);
      expect(host.projected, hasLength(1));
    });

    testWidgets('nach dem Blatt ist die Sperre wieder offen', (tester) async {
      // In der Quelle hängt sie an `collectAnim`, und das wird in derselben
      // Zeile geleert, in der das Blatt aufgeht.
      await readyToCollect(tester);

      await tap(tester, tapOn('7', 20));
      await tester.pump(const Duration(milliseconds: 1400));
      await tap(tester, tapOn('7', 20));

      expect(collected, <String>['7', '7']);
    });

    testWidgets('eine gescheiterte Projektion sammelt trotzdem und fliegt '
        'von 0/0 los', (tester) async {
      // `screen-map.jsx:3059-3067` fängt den Fehler und macht mit `0/0`
      // weiter, statt abzubrechen. Eine Animation an der falschen Stelle ist
      // besser als kein Sammeln, denn das Fakt-Blatt hängt an derselben
      // Handlung.
      host.projectionAnswer = <MapScreenPoint?>[null];
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 20)],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(tester, tapOn('7', 20));

      expect(collected, <String>['7']);
      expect(
        tester.widget<FactCollectBurst>(find.byType(FactCollectBurst)).origin,
        Offset.zero,
      );

      await tester.pump(const Duration(milliseconds: 1400));
      expect(opened, <String>['7']);
    });

    testWidgets('ein gespiegelter Punkt zählt wie keiner', (tester) async {
      // `MapScreenPoint.isInFrontOfCamera` ist `false`: die Zahlen sehen
      // gültig aus und liegen geometrisch nirgends. Die Münzen flögen sonst
      // von einer Stelle los, an der nichts steht.
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 700,
          yInScreenPixels: 900,
          isInFrontOfCamera: false,
        ),
      ];
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 20)],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(tester, tapOn('7', 20));

      expect(
        tester.widget<FactCollectBurst>(find.byType(FactCollectBurst)).origin,
        Offset.zero,
      );
    });

    testWidgets('die Fluglängen liegen im Bereich [32, 54)', (tester) async {
      int index = 0;
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 0,
          yInScreenPixels: 0,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 20)],
      );
      await pumpOverlay(
        tester,
        container: container,
        nextDouble: () => (index++ % 10) / 10,
      );
      await locateUser(tester);

      await tap(tester, tapOn('7', 20));

      final List<double> distances = tester
          .widgetList<FactCollectBurstCoin>(find.byType(FactCollectBurstCoin))
          .map((FactCollectBurstCoin coin) => coin.distance)
          .toList();
      expect(distances, hasLength(10));
      for (final double distance in distances) {
        expect(distance, greaterThanOrEqualTo(32));
        expect(distance, lessThan(54));
      }
    });

    testWidgets('sammeln nimmt eine stehende Vorschau weg', (tester) async {
      // `setTeaserFactRef.current?.(null)` vor `triggerCollect` (`:2132`).
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 0,
          yInScreenPixels: 0,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('fern', 900), pointAt('nah', 20)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);

      await tap(tester, tapOn('fern', 900));
      expect(find.byType(FactTeaserCard), findsOneWidget);

      await tap(tester, tapOn('nah', 20));

      expect(find.byType(FactTeaserCard), findsNothing);
      expect(collected, <String>['nah']);
    });
  });

  group('Der Tipp auf einen lebenden Ballon', () {
    testWidgets('sammelt, obwohl der Punkt nicht mehr nativ liegt', (
      tester,
    ) async {
      // **Das ist der Normalfall des Sammelns und der Grund, warum dieses
      // Widget die Ballon-Überlagerung enthält.** Ein Fakt in Reichweite ist
      // aus der nativen Punktliste heraus (`factOverlayWithout`), `pointTaps`
      // meldet ihn also nicht.
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 100,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = newContainer(
        // Der Punkt liegt **nicht** in der Überlagerung, genau wie am Gerät.
        points: <MapOverlayPoint>[],
        proximity: FactProximity(
          points: <FactProximityPoint>[
            FactProximityPoint(
              id: '7',
              position: northOf(20),
              style: factCategoryStylesByKey['hist']!,
              distanceInMeters: 20,
            ),
          ],
        ),
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);
      await mapComesAlive(tester);

      await tester.tap(find.byType(CustomPaint).last, warnIfMissed: false);
      await tester.pump();

      expect(collected, <String>['7']);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(opened, <String>['7']);
    });

    testWidgets('ohne Rückruf verschluckt die Ballon-Fläche keine Geste', (
      tester,
    ) async {
      // Der Zustand, in dem `FactBalloonOverlay` außerhalb dieses Widgets
      // benutzt wird: dann liegt alles wie bisher in einem `IgnorePointer`.
      //
      // **Mit einem wirklich gezeichneten Ballon**, und das ist der Teil, an
      // dem der erste Anlauf vorbeigemessen hat: ohne Kamera und ohne
      // Nachbarschaft gibt der Zeichner ein `SizedBox.shrink()` zurück und
      // kommt am `IgnorePointer` gar nicht vorbei. Der Test war grün, ohne
      // etwas zu prüfen.
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 300,
          yInScreenPixels: 300,
          isInFrontOfCamera: true,
        ),
      ];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: newContainer(
            points: <MapOverlayPoint>[],
            proximity: FactProximity(
              points: <FactProximityPoint>[
                FactProximityPoint(
                  id: '7',
                  position: northOf(20),
                  style: factCategoryStylesByKey['hist']!,
                  distanceInMeters: 20,
                ),
              ],
            ),
          ),
          child: const MaterialApp(
            home: Stack(
              fit: StackFit.expand,
              children: <Widget>[FactBalloonOverlay()],
            ),
          ),
        ),
      );
      await mapComesAlive(tester);

      expect(
        find.byType(FactBalloonPainter),
        findsNothing,
        reason: 'der Zeichner steckt in einem CustomPaint, nicht im Baum',
      );
      // **Auf den Zeichner eingeschränkt.** `MaterialApp` bringt selbst
      // `IgnorePointer` mit; eine Suche über den ganzen Baum fand drei und
      // hätte auch dann gepasst, wenn dieser hier fehlte.
      expect(
        find.descendant(
          of: find.byType(FactBalloonOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((CustomPaint paint) => paint.painter)
            .whereType<FactBalloonPainter>(),
        hasLength(1),
        reason: 'es gibt wirklich einen Ballon, der etwas verschlucken könnte',
      );
    });
  });

  group('Das automatische Sammeln', () {
    // `scanAutoOpenRef`, `screen-map.jsx:1471-1489`. Die Regel selbst hat
    // ihren eigenen Test (`fact_auto_collect_test.dart`); hier steht die
    // Verdrahtung: wer den Scan auslöst, was ihn sperrt, und dass er im
    // selben Sammelvorgang endet wie der Tipp.

    testWidgets('eine Ortung neben einem Fakt sammelt ihn ohne Tipp', (
      tester,
    ) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 5)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);

      await locateUser(tester);

      expect(collected, <String>['7']);
    });

    testWidgets('und öffnet danach dasselbe Blatt wie ein Tipp', (
      tester,
    ) async {
      // Der automatische Weg endet in `_startCollect` und damit im selben
      // Zeitgeber. Wäre es ein zweiter Ablauf, könnte er sich mit dem des
      // Tipps überlagern.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 5)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);

      await locateUser(tester);
      expect(opened, isEmpty);
      await tester.pump(factCollectRevealDelay);

      expect(opened, <String>['7']);
    });

    testWidgets('ein Fakt außerhalb des Radius bleibt liegen', (tester) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 50)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);

      await locateUser(tester);

      expect(collected, isEmpty);
    });

    testWidgets('ohne Ortung sammelt nichts von selbst', (tester) async {
      // Der Fakt liegt **auf** dem Nutzer. Nur die fehlende Ortung hält den
      // Scan auf, wie `if (!pos) return` in `:1472`.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 0)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );

      await pumpOverlay(tester, container: container);

      expect(collected, isEmpty);
    });

    testWidgets('ein schon gesammelter Fakt springt nicht auf', (tester) async {
      // Der Ausschluss aus `:1480`, und der Grund, warum
      // `CollectedFactsStore` vor dieser Mechanik gebaut werden musste: ohne
      // ihn gäbe es das Wort „noch nicht gesammelt" nicht.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 5)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
        collectedFacts: const <FactId>[FactId(7)],
      );
      await pumpOverlay(tester, container: container);

      await locateUser(tester);

      expect(collected, isEmpty);
    });

    testWidgets('eine Kennung, die keine Zahl ist, springt nicht auf', (
      tester,
    ) async {
      // Strenger als der Tipp, und begründet: ein automatisches Sammeln, das
      // niemand vermerken kann, wäre eine Buchung, die die Sammlung nie
      // erreicht.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('keine-zahl', 5)],
      );
      await pumpOverlay(tester, container: container);

      await locateUser(tester);

      expect(collected, isEmpty);
    });

    testWidgets('der nächste Fakt gewinnt, nicht der erste in der Liste', (
      tester,
    ) async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('17', 15), pointAt('3', 2)],
        facts: <Fact>[factWith(17, 'Weiter'), factWith(3, 'Näher')],
      );
      await pumpOverlay(tester, container: container);

      await locateUser(tester);

      expect(collected, <String>['3']);
    });

    testWidgets('eine zweite Ortung sammelt denselben Fakt nicht erneut', (
      tester,
    ) async {
      // **Und hier hängt es allein an der Sitzungsmenge**, nicht an der
      // Sammlung: `onCollected` schreibt in diesem Test nur in eine Liste,
      // der Speicher bleibt leer. Genau so ist es auch am Gerät, wenn der
      // Schreibvorgang ins Leere läuft. Wer `_automaticallyTriggered`
      // entfernt, bekommt hier zwei Einträge.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 5)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await pumpOverlay(tester, container: container);

      await locateUser(tester);
      // Erst den Ablauf zu Ende laufen lassen, sonst prüfte dieser Test die
      // Animationssperre und nicht die Sitzungsmenge.
      await tester.pump(factCollectRevealDelay);
      await locateUser(tester);

      expect(collected, <String>['7']);
    });

    testWidgets('während der Animation sammelt nichts Zweites von selbst', (
      tester,
    ) async {
      // Die Sperre aus `:1475` (`if (collectAnim) return;`). **Beide Fakten
      // liegen in Reichweite**, der zweite ist nach dem ersten Durchlauf
      // immer noch frisch, und nur die laufende Animation hält ihn auf. Ohne
      // die Sperre stünde unten `['nah', 'mittel']`, also zwei Sammelvorgänge
      // in derselben Sekunde, mit zwei Zeitgebern auf dasselbe Blatt.
      final ProviderContainer container = newContainer(
        // **Zahlen als Kennungen, und das ist kein Zufall.** Ein Punkt mit
        // einer nicht lesbaren Kennung wird vom Scan bewusst übersprungen,
        // siehe den Test darüber; mit 'nah' und 'mittel' war dieser Test rot.
        points: <MapOverlayPoint>[pointAt('5', 5), pointAt('15', 15)],
        facts: <Fact>[factWith(5, 'Nah'), factWith(15, 'Mittel')],
      );
      await pumpOverlay(tester, container: container);
      await locateUser(tester);
      expect(collected, <String>['5']);

      // Eine zweite Ortung, mitten in der Animation.
      await locateUser(tester);

      expect(collected, <String>['5']);

      // Und danach ist der zweite fällig, damit dieser Test nicht auch dann
      // grün wäre, wenn der Scan gar nichts mehr täte.
      await tester.pump(factCollectRevealDelay);
      await locateUser(tester);

      expect(collected, <String>['5', '15']);
    });

    testWidgets('eine Ortung, die schon vorlag, sammelt beim Entstehen', (
      tester,
    ) async {
      // Derselbe Fall wie beim Tipp-Weg eine Gruppe weiter oben, nur für den
      // Scan: nach einem Tabwechsel entsteht dieses Widget neu, während eine
      // Ortung längst vorliegt. Ohne `fireImmediately` am Hörer sammelte
      // hier **nie** etwas von selbst, bis das nächste GPS-Signal kommt.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 5)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      container.read<UserLocationState>(userLocationProvider);
      location.emit(
        DevicePosition(
          latitude: user.latitude,
          longitude: user.longitude,
          accuracyInMeters: 10,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await pumpOverlay(tester, container: container);

      expect(collected, <String>['7']);
    });

    group('solange ein Blatt darüber liegt', () {
      testWidgets('sammelt der Scan nicht', (tester) async {
        // Die Sperre aus `:1474`. Ohne sie sammelte die Karte unter dem
        // offenen Blatt weiter, und wer liest, bekäme alle 1400
        // Millisekunden eine neue Akte vorgesetzt.
        final ProviderContainer container = newContainer(
          points: <MapOverlayPoint>[pointAt('7', 5)],
          facts: <Fact>[factWith(7, 'Alter Peter')],
        );
        await pumpOverlay(tester, container: container);
        await _pushSheet(tester);

        await locateUser(tester);

        expect(collected, isEmpty);
      });

      testWidgets('nach dem Schließen sucht er nach 600 Millisekunden', (
        tester,
      ) async {
        // `setTimeout(..., 600)` in `:1544`. Der Nutzer steht noch neben dem
        // Fakt, also soll er nicht auf das nächste GPS-Signal warten.
        final ProviderContainer container = newContainer(
          points: <MapOverlayPoint>[pointAt('7', 5)],
          facts: <Fact>[factWith(7, 'Alter Peter')],
        );
        await pumpOverlay(tester, container: container);
        await _pushSheet(tester);
        await locateUser(tester);
        expect(collected, isEmpty);

        await _popSheet(tester);
        expect(
          collected,
          isEmpty,
          reason: 'nicht sofort, die Schließ-Animation soll durchlaufen',
        );
        await tester.pump(factAutoCollectRescanDelay);

        expect(collected, <String>['7']);
      });
    });
  });
}

/// Legt eine Route über den Kartenbildschirm, wie das Fakt-Blatt es tut.
///
/// `FactRoute` ist eine volle Seite (`app_routes.dart`), also liegt der
/// Kartenbildschirm darunter und ist nicht mehr `isCurrent`. Genau daran
/// hängt die Sperre des Scans, siehe `didChangeDependencies`.
Future<void> _pushSheet(WidgetTester tester) async {
  final BuildContext context = tester.element(find.byType(FactCollectOverlay));
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const Text('Akte'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Schließt die Route wieder.
Future<void> _popSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.text('Akte'))).pop();
  await tester.pumpAndSettle();
}

/// Ein Karten-Host ohne Karte, mit einem steuerbaren Punkt-Tipp-Strom.
///
/// **Er muss ein Doppelgänger sein:** der echte bekommt seine Kamera erst aus
/// `onMapCreated`, und das läuft ohne Plattformkanal nie.
class _FakeCollectMapHost implements MapHost {
  final StreamController<MapCameraView> _cameras =
      StreamController<MapCameraView>.broadcast();

  final StreamController<MapOverlayPointTap> _pointTaps =
      StreamController<MapOverlayPointTap>.broadcast();

  MapCameraView? _camera;

  /// Die Anfragen an die Projektion, in der Reihenfolge des Eingangs.
  final List<List<MapPosition>> projected = <List<MapPosition>>[];

  /// Wenn gesetzt, antwortet die Projektion erst, wenn der Test es sagt.
  Completer<List<MapScreenPoint?>>? pendingProjection;

  /// Was die Projektion liefert, wenn sie sofort antwortet.
  List<MapScreenPoint?>? projectionAnswer;

  @override
  MapCameraView? get camera => _camera;

  @override
  Stream<MapCameraView> get cameraChanges => _cameras.stream;

  @override
  MapViewport? get viewport => null;

  @override
  Stream<MapOverlayGroupTap> get groupTaps => const Stream.empty();

  @override
  Stream<MapOverlayPointTap> get pointTaps => _pointTaps.stream;

  @override
  void submitIntent(MapCameraIntent intent) {}

  @override
  void registerOverlayImages(List<MapOverlayImage> images) {}

  @override
  void setOverlay(MapOverlay overlay) {}

  @override
  void removeOverlay(String overlayId) {}

  @override
  Future<List<MapScreenPoint?>> projectToScreen(List<MapPosition> positions) {
    projected.add(positions);
    final Completer<List<MapScreenPoint?>>? gate = pendingProjection;
    if (gate != null) {
      return gate.future;
    }
    return Future<List<MapScreenPoint?>>.value(
      projectionAnswer ?? List<MapScreenPoint?>.filled(positions.length, null),
    );
  }

  void tapPoint(MapOverlayPointTap tap) => _pointTaps.add(tap);

  void bind(MapCameraView view) {
    _camera = view;
    _cameras.add(view);
  }

  Future<void> close() {
    // Eine angehaltene Anfrage darf den Test nicht überleben.
    pendingProjection?.complete(const <MapScreenPoint?>[]);
    pendingProjection = null;
    return Future.wait<void>(<Future<void>>[
      _cameras.close(),
      _pointTaps.close(),
    ]);
  }
}

/// Ein Ortungsdienst, dessen Ortungen der Test selbst setzt.
class _FakeLocationService implements LocationService {
  final StreamController<DevicePosition> _controller =
      StreamController<DevicePosition>.broadcast();

  @override
  Stream<DevicePosition> positionUpdates() => _controller.stream;

  void emit(DevicePosition position) => _controller.add(position);

  Future<void> close() => _controller.close();
}

/// Eine Sprachwahl, die feststeht.
class _FixedLanguageNotifier extends AppLanguageNotifier {
  _FixedLanguageNotifier(this._language);

  final AppLanguage _language;

  @override
  AppLanguage build() => _language;
}
