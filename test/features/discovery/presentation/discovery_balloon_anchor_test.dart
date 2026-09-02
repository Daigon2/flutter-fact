import 'dart:async';

import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/features/discovery/presentation/discovery_balloon_anchor.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der `balloon`-Anker: die reine Auswahlregel, dazu das Widget, das sie mit
/// echten Kamerameldungen füttert.
///
/// **Der wertvollste Teil ist die reine Regel**, weil sie ohne Widget-Test
/// festnagelbar ist: das Verwerfen zu kleiner Marker, das Verwerfen
/// ausserhalb des Rahmens, der euklidische Vergleich, der Gleichstand und der
/// Rückfall auf das Ersatzrechteck.
void main() {
  const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);

  MapOverlayPoint pointAt(
    String id, {
    double latOffset = 0,
    double lngOffset = 0,
  }) => MapOverlayPoint(
    id: id,
    position: MapPosition(
      latitude: munich.latitude + latOffset,
      longitude: munich.longitude + lngOffset,
    ),
    styleId: factBalloonStyleId('hist', factNotCollectedState),
    state: factNotCollectedState,
  );

  group('nearestOverlayPointsTo', () {
    test('sortiert aufsteigend nach Entfernung zum Zentrum', () {
      final List<MapOverlayPoint> points = <MapOverlayPoint>[
        pointAt('fern', latOffset: 0.01),
        pointAt('nah', latOffset: 0.0001),
        pointAt('mittel', latOffset: 0.001),
      ];

      final List<MapOverlayPoint> sorted = nearestOverlayPointsTo(
        points,
        munich,
      );

      expect(sorted.map((MapOverlayPoint p) => p.id).toList(), <String>[
        'nah',
        'mittel',
        'fern',
      ]);
    });

    test('schneidet auf count zu', () {
      final List<MapOverlayPoint> points = <MapOverlayPoint>[
        for (int i = 0; i < 5; i++) pointAt('$i', latOffset: i * 0.001),
      ];

      final List<MapOverlayPoint> nearest = nearestOverlayPointsTo(
        points,
        munich,
        count: 2,
      );

      expect(nearest, hasLength(2));
      expect(nearest.map((MapOverlayPoint p) => p.id), <String>['0', '1']);
    });

    test('gibt alle zurück, wenn weniger als count vorhanden sind', () {
      final List<MapOverlayPoint> points = <MapOverlayPoint>[
        pointAt('a'),
        pointAt('b'),
      ];

      expect(nearestOverlayPointsTo(points, munich, count: 25), hasLength(2));
    });
  });

  group('balloonAnchorCandidatesOf', () {
    test('lebende Ballons behalten ihre echte Betonung', () {
      final FactProximityPoint near = FactProximityPoint(
        id: '7',
        position: munich,
        style: factCategoryStylesByKey['hist']!,
        distanceInMeters: 15,
      );
      final MapOverlay overlay = MapOverlay(
        id: 'x',
        points: <MapOverlayPoint>[pointAt('7')],
      );

      final List<BalloonAnchorCandidate> candidates = balloonAnchorCandidatesOf(
        overlay: overlay,
        cameraCenter: munich,
        nearby: <FactProximityPoint>[near],
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.emphasis, near.emphasis);
      expect(candidates.single.emphasis, greaterThan(0));
    });

    test('ein Fakt aus nearby wird nicht doppelt aus der Überlagerung '
        'übernommen', () {
      final FactProximityPoint near = FactProximityPoint(
        id: '7',
        position: munich,
        style: factCategoryStylesByKey['hist']!,
        distanceInMeters: 15,
      );
      final MapOverlay overlay = MapOverlay(
        id: 'x',
        points: <MapOverlayPoint>[pointAt('7'), pointAt('8', latOffset: 0.01)],
      );

      final List<BalloonAnchorCandidate> candidates = balloonAnchorCandidatesOf(
        overlay: overlay,
        cameraCenter: munich,
        nearby: <FactProximityPoint>[near],
      );

      expect(candidates, hasLength(2), reason: '7 und 8, aber 7 nur einmal');
      final BalloonAnchorCandidate seven = candidates.firstWhere(
        (BalloonAnchorCandidate c) => c.position == munich,
      );
      expect(seven.emphasis, near.emphasis);
    });

    test('rein geografisch ausgewählte Punkte bekommen Betonung 0', () {
      final MapOverlay overlay = MapOverlay(
        id: 'x',
        points: <MapOverlayPoint>[pointAt('fern', latOffset: 0.001)],
      );

      final List<BalloonAnchorCandidate> candidates = balloonAnchorCandidatesOf(
        overlay: overlay,
        cameraCenter: munich,
        nearby: const <FactProximityPoint>[],
      );

      expect(candidates.single.emphasis, 0);
    });
  });

  group('selectBalloonAnchorRect', () {
    // Zoom 16: derselbe Wert wie in `fact_balloon_overlay_test.dart`,
    // Zoomfaktor 5/6. Bei Betonung 0 ist die Fläche dann 41,67 auf 79,17
    // logische Pixel, deutlich über der 30-Pixel-Schwelle.
    const double zoomWithRoom = 16;
    const Size frame = Size(400, 800);

    BalloonAnchorCandidate candidateAt(MapPosition p, {double emphasis = 0}) =>
        BalloonAnchorCandidate(position: p, emphasis: emphasis);

    test('ein zu kleiner Marker fällt weg', () {
      // Zoomfaktor am unteren Anschlag (0,42): Breite 50 × 0,42 = 21, unter
      // der Schwelle. Die Position selbst wäre sonst ein Treffer, genau in
      // der Rahmenmitte.
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: 11,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect, isNull);
    });

    test('die Schwelle liegt bei genau 30 logischen Pixeln, wie in der '
        'Quelle, nicht irgendwo in einem weiten Intervall', () {
      // **Gegen die Zahl der Quelle geprüft, nicht gegen ein Intervall.**
      // `zu kleiner Marker fällt weg` oben prüft nur „deutlich zu klein
      // gegen deutlich groß genug"; jede Schwelle zwischen 21 und 30 bliebe
      // dabei unentdeckt (Muster 18). Gemessen: bei Zoom 14,5 beträgt die
      // Fläche 29,166... logische Pixel, unter 30 und damit verworfen; bei
      // Zoom 14,6 sind es exakt 30,0, und `< 30` ist dann falsch, also
      // behalten. Verschiebt man `discoveryBalloonAnchorMinMarkerSize` auch
      // nur um einen Punkt in irgendeine Richtung, kippt eine der beiden
      // Zeilen unten.
      Rect? rectAt(double zoom) => selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rectAt(14.5), isNull, reason: 'Breite 29,166..., unter 30');
      expect(rectAt(14.6), isNotNull, reason: 'Breite genau 30,0');
    });

    test('die Betonung des Kandidaten wirkt in der Größenrechnung, nicht nur '
        'im Vertrag', () {
      // Bei Zoom 11 (Skalierung am unteren Anschlag, 0,42) fällt Betonung 0
      // durch die Schwelle, siehe oben (21 Pixel). Ein Kandidat mit echter
      // Betonung wächst dagegen auf einen 48-Pixel-Kopf plus 30 Pixel
      // Schattenrand je Seite (`FactBalloonMetrics(emphasis: 1).width == 108`,
      // selbst nachgerechnet und nicht angenommen), macht bei dieser
      // Zoomstufe 45,36 Pixel und besteht die Schwelle klar. Würde die
      // Größenrechnung die Betonung durch eine feste 0 ersetzen, verschwände
      // der einzige Kandidat, und aus dem Rechteck würde `null`.
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[candidateAt(munich, emphasis: 1)],
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: 11,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect, isNotNull);
      expect(rect!.width, closeTo(45.36, 0.01));
    });

    // **Vier Tests, nicht einer.** Der Rahmenfilter ist im Code eine
    // Veroderung aus zwei Halbbedingungen je Achse (`rect.right < 0 ||
    // rect.left > frameSize.width`, ebenso senkrecht). Ein einzelner
    // Kandidat, der wie in einer ersten Fassung dieser Datei gleichzeitig
    // links **und** oberhalb des Rahmens liegt, prueft immer nur, ob
    // ueberhaupt eine der vier Haelften anschlaegt: entfernt man eine davon,
    // greift die andere trotzdem, und der Test bleibt gruen, obwohl die
    // Pruefung luecken hat. Jede Haelfte braucht deshalb einen Kandidaten,
    // der **nur** an dieser einen Kante scheitert, sonst innerhalb der
    // anderen drei Grenzen liegt.
    test('links ausserhalb des Rahmens (rect.right < 0) fällt weg', () {
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
        // x weit links, rect.right bleibt trotzdem negativ; y in der Mitte,
        // also innerhalb beider senkrechter Grenzen.
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: -100,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect, isNull);
    });

    test('rechts ausserhalb des Rahmens (rect.left > frameSize.width) fällt '
        'weg', () {
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
        // x weit rechts von 400, y in der Mitte: nur die rechte Kante
        // schlägt an, `rect.right < 0` bleibt falsch.
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 1000,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect, isNull);
    });

    test('oberhalb des Rahmens (rect.bottom < 0) fällt weg', () {
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
        // y weit oberhalb, x in der Mitte: nur die obere Kante schlägt an.
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: -100,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect, isNull);
    });

    test('unterhalb des Rahmens (rect.top > frameSize.height) fällt weg', () {
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
        // y weit unterhalb von 800, x in der Mitte: nur die untere Kante
        // schlägt an.
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 1000,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect, isNull);
    });

    test('ein fehlender Bildschirmpunkt wird übersprungen', () {
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[
          candidateAt(munich),
          candidateAt(const MapPosition(latitude: 48.2, longitude: 11.7)),
        ],
        screenPositions: const <MapScreenPoint?>[
          null,
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect, isNotNull);
    });

    test(
      'kein Kandidat taugt: null, der Aufrufer legt das Ersatzrechteck an',
      () {
        final Rect? rect = selectBalloonAnchorRect(
          candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
          screenPositions: const <MapScreenPoint?>[null],
          zoom: zoomWithRoom,
          frameSize: frame,
          pixelRatio: 1,
        );

        expect(rect, isNull);
      },
    );

    test('der bildschirmnächste zur Rahmenmitte gewinnt', () {
      // Rahmenmitte bei pixelRatio 1: (200, 400).
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[
          candidateAt(munich),
          candidateAt(const MapPosition(latitude: 48.14, longitude: 11.6)),
        ],
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 390,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect!.center.dx, closeTo(200, 0.001));
    });

    test('ein Punkt hinter der Kamera gewinnt den Wettbewerb nicht, obwohl er '
        'näher an der Rahmenmitte liegt', () {
      // **Die teuerste der drei Folgen von D-17, und die einzige, die eine
      // Auswahl umdreht statt nur ein Bild zu verderben.** Eine Spiegelung an
      // der Kameraachse zieht gespiegelte Punkte in Richtung Bildmitte, also
      // genau dorthin, wo dieser Wettbewerb entschieden wird.
      //
      // **Die Eingaben sind so gewählt, dass ein ignoriertes Feld ein anderes
      // Ergebnis liefert** (Muster 21): der gespiegelte Punkt liegt **genau**
      // in der Rahmenmitte und würde jeden anderen schlagen. Eine Probe, in
      // der er ohnehin verliert, wäre blind.
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[
          candidateAt(munich),
          candidateAt(const MapPosition(latitude: 48.14, longitude: 11.6)),
        ],
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: false,
          ),
          MapScreenPoint(
            xInScreenPixels: 390,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      // **Der zweite Kandidat gehört zur Probe.** Mit nur einem wäre `null`
      // auch das Ergebnis einer Mutation, die immer `null` liefert; so muss
      // der Gewinner der **andere** sein, und das trennt „ausgeschlossen“ von
      // „nichts gefunden“.
      expect(rect!.center.dx, closeTo(390, 0.001));
    });

    test('taugt nur ein gespiegelter Punkt, gibt es kein Ziel', () {
      // Der Rest ist Sache des Aufrufers: er legt dann das Ersatzrechteck der
      // Quelle an, siehe `discoveryBalloonAnchorFallbackRect`.
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: false,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect, isNull);
    });

    test('bei Gleichstand gewinnt der zuerst geprüfte, wie `d < bestD` in der '
        'Quelle', () {
      // Beide Kandidaten liegen symmetrisch 50 Pixel links und rechts der
      // Rahmenmitte (200): gleicher Abstand, der erste muss gewinnen.
      final Rect? rect = selectBalloonAnchorRect(
        candidates: <BalloonAnchorCandidate>[
          candidateAt(munich),
          candidateAt(const MapPosition(latitude: 48.14, longitude: 11.6)),
        ],
        screenPositions: const <MapScreenPoint?>[
          MapScreenPoint(
            xInScreenPixels: 150,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
          MapScreenPoint(
            xInScreenPixels: 250,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ],
        zoom: zoomWithRoom,
        frameSize: frame,
        pixelRatio: 1,
      );

      expect(rect!.center.dx, closeTo(150, 0.001));
    });

    for (final double ratio in <double>[2.625, 1.5]) {
      test(
        'die Verankerung ist die Unterkante, mittig, Skalierungsfaktor $ratio',
        () {
          final Rect? rect = selectBalloonAnchorRect(
            candidates: <BalloonAnchorCandidate>[candidateAt(munich)],
            screenPositions: const <MapScreenPoint?>[
              MapScreenPoint(
                xInScreenPixels: 200,
                yInScreenPixels: 400,
                isInFrontOfCamera: true,
              ),
            ],
            zoom: zoomWithRoom,
            frameSize: frame,
            pixelRatio: ratio,
          );

          expect(rect!.bottomCenter.dx, closeTo(200 / ratio, 0.001));
          expect(rect.bottom, closeTo(400 / ratio, 0.001));
        },
      );
    }
  });

  group('discoveryBalloonAnchorFallbackRect', () {
    test('steht bei 45 Prozent Breite und 55 Prozent Höhe, 38 mal 38', () {
      const Size frame = Size(400, 800);

      final Rect rect = discoveryBalloonAnchorFallbackRect(frame);

      expect(rect.left, closeTo(180, 0.001));
      expect(rect.top, closeTo(440, 0.001));
      expect(rect.width, 38);
      expect(rect.height, 38);
    });
  });

  group('DiscoveryBalloonAnchor', () {
    late FakeAnchorMapHost host;

    setUp(() => host = FakeAnchorMapHost());
    tearDown(() async => host.close());

    ProviderContainer containerWith({
      MapOverlay overlay = const MapOverlay(
        id: 'x',
        points: <MapOverlayPoint>[],
      ),
      FactProximity proximity = FactProximity.empty,
    }) {
      // **`factOverlayProvider` wird immer überschrieben, auch wenn ein Test
      // sich für die Überlagerung gar nicht interessiert.** Das Widget hört
      // ihm über `ref.listen` zu, und ein Zuhörer baut den Provider auf.
      // Ohne diese Überschreibung liefe die echte Kette bis zu
      // `allFactsProvider`, ohne Repository, mit Fehlschlag und einem
      // Wiederholungs-Zeitgeber, der den Test überlebt. Dasselbe Muster wie
      // in `map_page_test.dart`.
      final ProviderContainer container = ProviderContainer(
        overrides: [
          mapHostProvider.overrideWithValue(host),
          factProximityProvider.overrideWithValue(proximity),
          factOverlayProvider.overrideWith((Ref ref) async => overlay),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> pumpAnchor(
      WidgetTester tester, {
      required ProviderContainer container,
    }) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: <Widget>[DiscoveryBalloonAnchor()],
          ),
        ),
      ),
    );

    testWidgets('ohne Karte meldet sich das Ersatzrechteck an', (tester) async {
      await pumpAnchor(tester, container: containerWith());
      await tester.pump();

      final Rect rect = tester.getRect(find.byType(AnchorTarget));
      final Size frame =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(rect, discoveryBalloonAnchorFallbackRect(frame));
    });

    testWidgets('unterhalb von factOverlayMinZoom bleibt das Ersatzrechteck', (
      tester,
    ) async {
      final MapOverlay overlay = MapOverlay(
        id: 'x',
        points: <MapOverlayPoint>[pointAt('1')],
      );
      await pumpAnchor(tester, container: containerWith(overlay: overlay));
      await tester.pump();
      host.bind(
        MapCameraView(
          center: munich,
          zoom: factOverlayMinZoom - 1,
          bearing: 0,
          pitch: 58,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        host.projected,
        isEmpty,
        reason: 'unter dieser Zoomstufe gibt es keine Fakten',
      );
    });

    testWidgets('mit Karte und Treffer steht der Anker an der berechneten '
        'Stelle', (tester) async {
      final MapOverlay overlay = MapOverlay(
        id: 'x',
        points: <MapOverlayPoint>[pointAt('1')],
      );
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      await pumpAnchor(tester, container: containerWith(overlay: overlay));
      await tester.pump();
      host.bind(
        const MapCameraView(center: munich, zoom: 16, bearing: 0, pitch: 58),
      );
      await tester.pump();
      await tester.pump();

      expect(host.projected, hasLength(1));
      final double pixelRatio = tester.view.devicePixelRatio;
      final Rect rect = tester.getRect(find.byType(AnchorTarget));
      expect(rect.bottomCenter.dx, closeTo(200 / pixelRatio, 0.001));
      expect(rect.bottom, closeTo(400 / pixelRatio, 0.001));
    });

    testWidgets('kein Kandidat unterwegs bleibt beim Ersatzrechteck', (
      tester,
    ) async {
      final MapOverlay overlay = MapOverlay(
        id: 'x',
        points: const <MapOverlayPoint>[],
      );
      await pumpAnchor(tester, container: containerWith(overlay: overlay));
      await tester.pump();
      host.bind(
        const MapCameraView(center: munich, zoom: 16, bearing: 0, pitch: 58),
      );
      await tester.pump();
      await tester.pump();

      expect(host.projected, isEmpty);
      final Rect rect = tester.getRect(find.byType(AnchorTarget));
      final Size frame =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(rect, discoveryBalloonAnchorFallbackRect(frame));
    });

    testWidgets('eine neue Nachbarschaft ohne Kamerabewegung löst eine neue '
        'Auswahl aus', (tester) async {
      // **Fängt das Fehlen von `ref.listen(factProximityProvider, ...)`.**
      // Ohne diesen Zuhörer bliebe die einmal getroffene Auswahl stehen, auch
      // wenn ein Fakt inzwischen in Reichweite kommt: kein Kamera-Ereignis
      // stösst danach noch etwas an, und ein GPS-Fix ist genau so ein Fall.
      final MapOverlay overlay = MapOverlay(
        id: 'x',
        points: <MapOverlayPoint>[pointAt('1')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          mapHostProvider.overrideWithValue(host),
          factOverlayProvider.overrideWith((Ref ref) async => overlay),
          factProximityProvider.overrideWith(
            (Ref ref) => ref.watch(probeProximityProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Stack(
              fit: StackFit.expand,
              children: <Widget>[DiscoveryBalloonAnchor()],
            ),
          ),
        ),
      );
      await tester.pump();
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      // Zoom 11: Betonung 0 fällt durch die Schwelle (siehe
      // `selectBalloonAnchorRect`, „die Betonung … wirkt“), der Anker steht
      // deshalb zunächst auf dem Ersatzrechteck.
      host.bind(
        const MapCameraView(center: munich, zoom: 11, bearing: 0, pitch: 58),
      );
      await tester.pump();
      await tester.pump();

      final Size frame =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getRect(find.byType(AnchorTarget)),
        discoveryBalloonAnchorFallbackRect(frame),
        reason: 'Betonung 0 besteht die Schwelle bei Zoom 11 nicht',
      );

      // Derselbe Fakt kommt jetzt mit voller Betonung in Reichweite, ohne
      // dass sich die Kamera rührt.
      container
          .read(probeProximityProvider.notifier)
          .put(
            FactProximity(
              points: <FactProximityPoint>[
                FactProximityPoint(
                  id: '1',
                  position: munich,
                  style: factCategoryStylesByKey['hist']!,
                  distanceInMeters: 0,
                ),
              ],
            ),
          );
      await tester.pump();
      await tester.pump();

      expect(
        tester.getRect(find.byType(AnchorTarget)),
        isNot(discoveryBalloonAnchorFallbackRect(frame)),
        reason:
            'die neue Betonung besteht jetzt die Schwelle und sollte den '
            'Anker vom Ersatzrechteck wegziehen',
      );
    });

    testWidgets('nie zwei Anfragen gleichzeitig, und die letzte gewinnt', (
      tester,
    ) async {
      // **Fängt das Fehlen der `_selectionInFlight`-Wache.** Ohne sie liefe
      // bei mehreren Kamerameldungen kurz hintereinander mehr als eine
      // Projektion gleichzeitig, genau das Muster, das
      // `fact_balloon_overlay_test.dart` für seinen eigenen
      // Zusammenfassungscode schon prüft; diese Auswahl hat einen eigenen
      // Riegel und braucht deshalb eine eigene Probe dafür.
      final MapOverlay overlay = MapOverlay(
        id: 'x',
        points: <MapOverlayPoint>[pointAt('1')],
      );
      host.pendingProjection = Completer<List<MapScreenPoint?>>();
      await pumpAnchor(tester, container: containerWith(overlay: overlay));
      await tester.pump();
      host.bind(
        const MapCameraView(center: munich, zoom: 16, bearing: 0, pitch: 58),
      );
      await tester.pump();

      for (var i = 0; i < 5; i++) {
        host.bind(
          MapCameraView(
            center: MapPosition(
              latitude: munich.latitude + i / 1000,
              longitude: munich.longitude,
            ),
            zoom: 16,
            bearing: 0,
            pitch: 58,
          ),
        );
        await tester.pump();
      }

      expect(host.projected, hasLength(1), reason: 'eine ist unterwegs');
      expect(host.peakInFlight, 1);

      host.answerProjection(<MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      // Die gemerkten Meldungen sind eine und nicht fünf.
      expect(host.projected, hasLength(2));
      expect(host.peakInFlight, 1);
    });
  });
}

/// Eine Nachbarschaft, die ein Test von aussen ändern kann, wie in
/// `fact_balloon_overlay_test.dart`. Ein Notifier und kein `StateProvider`,
/// den gibt es in Riverpod 3 nicht mehr.
class ProbeProximity extends Notifier<FactProximity> {
  @override
  FactProximity build() => FactProximity.empty;

  /// Setzt die Nachbarschaft.
  void put(FactProximity value) => state = value;
}

/// Der Provider dazu.
final NotifierProvider<ProbeProximity, FactProximity> probeProximityProvider =
    NotifierProvider<ProbeProximity, FactProximity>(ProbeProximity.new);

/// Ein Karten-Host ohne Karte, wie in `fact_balloon_overlay_test.dart`, hier
/// aber ohne Zusammenfassungs-Buchhaltung: die reicht dort schon aus, das
/// Zusammenfassungsverhalten dieser Auswahl wiederzuverwenden zu prüfen, wäre
/// dieselbe Sache zweimal getestet.
class FakeAnchorMapHost implements MapHost {
  final StreamController<MapCameraView> _cameras =
      StreamController<MapCameraView>.broadcast();

  MapCameraView? _camera;

  @override
  MapCameraView? get camera => _camera;

  @override
  Stream<MapCameraView> get cameraChanges => _cameras.stream;

  /// Kein Test hier braucht eine gemessene Fläche.
  @override
  MapViewport? get viewport => null;

  /// Kein Test hier braucht einen Gruppen-Tipp.
  @override
  Stream<MapOverlayGroupTap> get groupTaps => const Stream.empty();

  @override
  void submitIntent(MapCameraIntent intent) {}

  @override
  void registerOverlayImages(List<MapOverlayImage> images) {}

  @override
  void setOverlay(MapOverlay overlay) {}

  @override
  void removeOverlay(String overlayId) {}

  /// Die Anfragen an die Projektion, in der Reihenfolge des Eingangs.
  final List<List<MapPosition>> projected = <List<MapPosition>>[];

  /// Was die Projektion liefert, wenn sie sofort antwortet.
  List<MapScreenPoint?>? projectionAnswer;

  /// Wie viele Anfragen gerade gleichzeitig unterwegs sind.
  int inFlight = 0;

  /// Der höchste je gleichzeitig erreichte Stand von [inFlight].
  ///
  /// Es gibt diesen Zähler aus demselben Grund wie in
  /// `fact_balloon_overlay_test.dart`: eine bloße Anzahl der Aufrufe sagt
  /// nichts darüber, ob sie sich überlappt haben.
  int peakInFlight = 0;

  /// Wenn gesetzt, antwortet die Projektion erst, wenn der Test es sagt.
  Completer<List<MapScreenPoint?>>? pendingProjection;

  @override
  Future<List<MapScreenPoint?>> projectToScreen(List<MapPosition> positions) {
    projected.add(positions);
    inFlight++;
    peakInFlight = inFlight > peakInFlight ? inFlight : peakInFlight;
    final Completer<List<MapScreenPoint?>>? gate = pendingProjection;
    final Future<List<MapScreenPoint?>> answer = gate != null
        ? gate.future
        : Future<List<MapScreenPoint?>>.value(
            projectionAnswer ??
                List<MapScreenPoint?>.filled(positions.length, null),
          );
    return answer.whenComplete(() => inFlight--);
  }

  /// Lässt eine angehaltene Projektion antworten.
  void answerProjection(List<MapScreenPoint?> answer) {
    final Completer<List<MapScreenPoint?>>? gate = pendingProjection;
    pendingProjection = null;
    gate?.complete(answer);
  }

  /// Die Karte meldet sich.
  void bind(MapCameraView view) {
    _camera = view;
    _cameras.add(view);
  }

  /// Schliesst den Kamerastrom.
  ///
  /// Eine angehaltene Anfrage darf den Test nicht überleben, sonst hängt ein
  /// `Completer` über die Testgrenze hinweg.
  Future<void> close() {
    pendingProjection?.complete(const <MapScreenPoint?>[]);
    pendingProjection = null;
    return _cameras.close();
  }
}
