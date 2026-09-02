import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_motion.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
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

/// Die lebenden Ballons über der Karte.
///
/// **Hier steht kein Karten-SDK und kein GPS.** Der Karten-Host ist ein
/// Doppelgänger, weil im Widget-Test nie ein `MapLibreMapController` entsteht,
/// und die Nachbarschaft kommt als überschriebener Provider: was aus einer
/// Ortung und einer Überlagerung wird, prüft `fact_proximity_test.dart`, und
/// die beiden Strecken zweimal zu prüfen hieße, dieselbe Sache an zwei Stellen
/// pflegen zu müssen.
void main() {
  const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);

  late FakeMapHost host;

  setUp(() => host = FakeMapHost());
  tearDown(() async => host.close());

  FactProximityPoint pointAt(
    String id, {
    required double meters,
    String category = 'hist',
  }) => FactProximityPoint(
    id: id,
    position: munich,
    style: factCategoryStylesByKey[category]!,
    distanceInMeters: meters,
  );

  ProviderContainer containerWith(FactProximity proximity) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        mapHostProvider.overrideWithValue(host),
        // **Der Provider und nicht der Ortungsdienst.** Die Näherungsrechnung
        // ist eine reine Funktion und hat ihren eigenen Test; hier geht es
        // ausschließlich darum, was aus ihrem Ergebnis auf dem Bildschirm
        // wird.
        factProximityProvider.overrideWithValue(proximity),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required ProviderContainer container,
  }) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: const <Widget>[FactBalloonOverlay()],
        ),
      ),
    ),
  );

  /// Die Karte meldet sich, wie `bindSurface` es tut.
  Future<void> mapComesAlive(WidgetTester tester, {double zoom = 16}) async {
    host.bind(MapCameraView(center: munich, zoom: zoom, bearing: 0, pitch: 58));
    await tester.pump();
    await tester.pump();
  }

  List<FactBalloonPainter> paintersOf(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((CustomPaint paint) => paint.painter)
      .whereType<FactBalloonPainter>()
      .toList();

  group('Wann überhaupt gezeichnet wird', () {
    testWidgets('ohne Karte liegt nichts über der Karte', (tester) async {
      // Ohne Kamerameldung gibt es keine Zoomstufe und keine Bildschirmlage.
      // Ein Ballon, der trotzdem erschiene, säße in der linken oberen Ecke.
      await pumpOverlay(
        tester,
        container: containerWith(
          FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 30)]),
        ),
      );

      expect(paintersOf(tester), isEmpty);
      expect(host.projected, isEmpty);
    });

    testWidgets('unterhalb der Gruppierungsgrenze wird nicht gezeichnet', (
      tester,
    ) async {
      // **Das ist Parität und keine Sparmaßnahme.** Die Quelle animiert nur
      // DOM-Marker, und die gibt es allein für ungruppierte Features
      // (`screen-map.jsx:2043-2045`). Ein Fakt in einer Gruppe animiert dort
      // ebenfalls nicht.
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 30)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester, zoom: 15);

      expect(paintersOf(tester), isEmpty);
      expect(host.projected, isEmpty, reason: 'auch nicht projiziert');
    });

    testWidgets('oberhalb der Grenze steht der Ballon da', (tester) async {
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 30)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      expect(paintersOf(tester), hasLength(1));
    });

    testWidgets('ohne Ortung ist die Fläche leer', (tester) async {
      final ProviderContainer container = containerWith(FactProximity.empty);
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      expect(paintersOf(tester), isEmpty);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('wer keine Bildschirmlage hat, wird nicht gezeichnet', (
      tester,
    ) async {
      // Ein Ballon ohne Lage gehört nicht auf (0, 0). Das ist der eine der
      // zwei Fälle, die der Vertrag auseinanderhält: **keine** Lage. Der
      // andere, eine Lage hinter der Kamera, steht in der Probe darunter.
      host.projectionAnswer = <MapScreenPoint?>[
        null,
        const MapScreenPoint(
          xInScreenPixels: 100,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(
          points: <FactProximityPoint>[
            pointAt('nah', meters: 10),
            pointAt('fern', meters: 100),
          ],
        ),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      expect(paintersOf(tester), hasLength(1));
      expect(find.byKey(const ValueKey<String>('fern')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('nah')), findsNothing);
    });

    testWidgets('wer hinter der Kamera liegt, wird nicht gezeichnet', (
      tester,
    ) async {
      // D-17. Bei 58 Grad Neigung liegt alles jenseits des Horizonts hinter
      // der Kamera, und `projectToScreen` liefert dafür **kein** `null`,
      // sondern eine gespiegelte Zahl, die wie eine Lage mitten im Bild
      // aussieht (`REBUILD_STATUS.md`, „Die vier Gerätemessungen“,
      // Messung 3). Genau das ist hier gestellt: der gespiegelte Punkt liegt
      // auf einer Lage, an der ein Ballon ohne Weiteres gezeichnet würde.
      //
      // **Der zweite, echte Ballon gehört zur Probe** (Muster 21): ohne ihn
      // wäre „nichts gezeichnet“ auch das Ergebnis eines Overlays, das
      // überhaupt nichts mehr zeichnet.
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: false,
        ),
        const MapScreenPoint(
          xInScreenPixels: 100,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(
          points: <FactProximityPoint>[
            pointAt('gespiegelt', meters: 10),
            pointAt('echt', meters: 100),
          ],
        ),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      expect(paintersOf(tester), hasLength(1));
      expect(find.byKey(const ValueKey<String>('echt')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('gespiegelt')), findsNothing);
    });

    testWidgets('die Fläche verschluckt keine Geste', (tester) async {
      // Das Antippen eines Ballons ist Schritt 21. Bis dahin gehören alle
      // Berührungen der Karte darunter.
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 30)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      final Finder ignoring = find.descendant(
        of: find.byType(FactBalloonOverlay),
        matching: find.byType(IgnorePointer),
      );
      expect(ignoring, findsOneWidget);
      expect(tester.widget<IgnorePointer>(ignoring).ignoring, isTrue);
    });
  });

  group('Wo der Ballon sitzt und wie groß er ist', () {
    // **Zwei Skalierungsfaktoren und nicht einer.** Mit einem einzigen wäre
    // die Umrechnung durch eine beliebige Konstante zu ersetzen, und der Test
    // bliebe grün; erst der zweite Faktor nagelt fest, dass wirklich durch den
    // Skalierungsfaktor geteilt wird. Der Wert 2,625 ist der des Pixel 8, an
    // dem die Sache am 30.08.2026 gemessen wurde.
    for (final double ratio in <double>[2.625, 1.5]) {
      testWidgets('seine Unterkante sitzt mittig auf der Bildschirmlage, '
          'Skalierungsfaktor $ratio', (tester) async {
        // **Dieselbe Verankerung wie `icon-anchor: bottom`.** Wäre sie hier
        // eine andere, spränge der Ballon beim Überqueren der
        // 150-Meter-Grenze, und zwar um seine ganze Höhe.
        //
        // **Und die Bildschirmlage kommt in Gerätepixeln.** Am 30.08.2026 am
        // Gerät gemessen: die projizierte Kameramitte landet auf
        // (540,75 | 1200,94) bei einer Fläche von 1080 × 2400 Gerätepixeln.
        // Ohne die Umrechnung stünde jeder Ballon um den Skalierungsfaktor
        // zu weit von der linken oberen Ecke weg. Belege in
        // `REBUILD_STATUS.md` unter „Ungefragter Fund A".
        //
        // Gesetzt wird über `tester.view` und nicht über eine eigene
        // `MediaQuery`: die läge unter der echten und wäre wirkungslos, siehe
        // „Wie Tests hier blind werden", Muster 11.
        tester.view.devicePixelRatio = ratio;
        addTearDown(tester.view.reset);

        host.projectionAnswer = <MapScreenPoint?>[
          const MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ];
        final ProviderContainer container = containerWith(
          FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 75)]),
        );
        await pumpOverlay(tester, container: container);
        await mapComesAlive(tester);

        final Rect rect = tester.getRect(
          find.byKey(const ValueKey<String>('7')),
        );
        expect(rect.bottomCenter.dx, closeTo(200 / ratio, 0.001));
        expect(rect.bottom, closeTo(400 / ratio, 0.001));
      });
    }

    testWidgets('die Zoomkurve wirkt auch auf den gezeichneten Ballon', (
      tester,
    ) async {
      // **Die Falle dieses Schritts.** Nativ wendet MapLibre
      // `overlayPointSizeExpression` auf jedes Symbol an; auf Zoom 16 steht
      // der Faktor bei 0,833 und nicht bei 1. Ein Ballon ohne diesen Faktor
      // wäre an der Grenze zwanzig Prozent zu groß.
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 75)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      final FactBalloonPainter painter = paintersOf(tester).single;
      expect(painter.scale, closeTo(5 / 6, 1e-9));

      final Rect rect = tester.getRect(find.byKey(const ValueKey<String>('7')));
      expect(
        rect.width,
        closeTo(painter.metrics.width * 5 / 6, 0.001),
        reason: 'die Fläche folgt dem Faktor mit',
      );
    });

    testWidgets('die Entfernung bestimmt die Betonung des Ballons', (
      tester,
    ) async {
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 100,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
        const MapScreenPoint(
          xInScreenPixels: 300,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(
          points: <FactProximityPoint>[
            pointAt('nah', meters: 15),
            pointAt('fern', meters: 135),
          ],
        ),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      final Rect near = tester.getRect(
        find.byKey(const ValueKey<String>('nah')),
      );
      final Rect far = tester.getRect(
        find.byKey(const ValueKey<String>('fern')),
      );
      expect(near.width, greaterThan(far.width));
      expect(near.height, greaterThan(far.height));
    });

    testWidgets('der nächste liegt obenauf', (tester) async {
      // Die Liste kommt aufsteigend nach Entfernung, gezeichnet wird
      // rückwärts. Läge der ferne oben, verdeckte er ausgerechnet den
      // größten.
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 100,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
        const MapScreenPoint(
          xInScreenPixels: 300,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(
          points: <FactProximityPoint>[
            pointAt('nah', meters: 15),
            pointAt('fern', meters: 135),
          ],
        ),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      final List<Key?> keys = tester
          .widgetList<Positioned>(find.byType(Positioned))
          .map((Positioned positioned) => positioned.key)
          .toList();
      expect(keys.last, const ValueKey<String>('nah'));
    });
  });

  group('Bewegung', () {
    testWidgets('der Ballon dreht sich, und der Winkel wächst', (tester) async {
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 10)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      await tester.pump(const Duration(milliseconds: 100));
      final double first = paintersOf(tester).single.spinDegrees;
      await tester.pump(const Duration(milliseconds: 100));
      final double second = paintersOf(tester).single.spinDegrees;

      expect(first, greaterThan(0));
      expect(second, greaterThan(first));
    });

    testWidgets('der Winkel folgt der echten Bilddauer und nicht dem Bild', (
      tester,
    ) async {
      // **Die Zusicherung, die die zentrale bewusste Abweichung dieses
      // Schritts trägt.** Dass `FactBalloonSpin` zeitbasiert rechnet, ist in
      // `fact_balloon_motion_test.dart` bewiesen; dass das **Widget** ihm die
      // echte Bilddauer gibt, war es nicht. `advance(_animated, delta)` durch
      // einen festen Betrag zu ersetzen hat die Suite überlebt, und damit
      // wären „Grad je Bild ist ein Fehler der Quelle" und alles, was daran
      // hängt, wieder offen.
      //
      // **Ein Verhältnis genügt hier nicht.** Zwei Pumpdauern im Verhältnis
      // 1 zu 2 ergeben auch dann Zuwächse im Verhältnis 1 zu 2, wenn statt
      // `delta` die aufgelaufene Zeit übergeben wird. Gemessen wird deshalb
      // der **absolute** Winkel gegen Tempo mal Zeit.
      final FactProximityPoint point = pointAt('7', meters: 10);
      final double speed = factSpinSpeedAt(point.emphasis);
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[point]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      await tester.pump(const Duration(milliseconds: 100));
      expect(paintersOf(tester).single.spinDegrees, closeTo(speed * 0.1, 1e-6));

      // Ein doppelt so langes Bild dreht doppelt so weit weiter.
      await tester.pump(const Duration(milliseconds: 200));
      expect(paintersOf(tester).single.spinDegrees, closeTo(speed * 0.3, 1e-6));
    });

    testWidgets('nur der nächste hüpft', (tester) async {
      // `screen-map.jsx:2297-2308`, mit Begründung im Kommentar der Quelle:
      // vorher hüpften alle Marker, und auf dichten Karten sahen Nutzer
      // „dauerndes Gehuepfe".
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 100,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
        const MapScreenPoint(
          xInScreenPixels: 300,
          yInScreenPixels: 200,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(
          points: <FactProximityPoint>[
            pointAt('nah', meters: 15),
            pointAt('fern', meters: 135),
          ],
        ),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);
      // Eine Viertelperiode weiter, dort ist das Auf-und-ab deutlich von null
      // verschieden.
      await tester.pump(const Duration(milliseconds: 550));

      final Map<String, double> floatById = <String, double>{
        for (final FactBalloonPainter painter in paintersOf(tester))
          painter.style.key: painter.floatProgress,
      };
      final List<double> progresses = paintersOf(
        tester,
      ).map((FactBalloonPainter painter) => painter.floatProgress).toList();

      expect(
        floatById,
        hasLength(1),
        reason: 'beide tragen dieselbe Kategorie',
      );
      expect(progresses.where((double p) => p != 0), hasLength(1));
      expect(progresses.where((double p) => p == 0), hasLength(1));
    });

    testWidgets('das Auf-und-ab folgt der Kurve der Quelle', (tester) async {
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 10)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      await tester.pump(const Duration(milliseconds: 1100));

      expect(
        paintersOf(tester).single.floatProgress,
        closeTo(1, 0.02),
        reason: 'nach der halben Periode steht der Kopf oben',
      );
    });

    testWidgets('ohne einen Ballon in Reichweite läuft kein Taktgeber', (
      tester,
    ) async {
      // **Ein laufender Ticker fordert jedes Bild an**, auch wenn er nichts
      // tut. Ohne das Abstellen liefe die Anzeige dauerhaft auf 60 Bildern je
      // Sekunde, obwohl kein Fakt in der Nähe ist.
      final ProviderContainer container = containerWith(FactProximity.empty);
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('mit einem Ballon in Reichweite läuft er', (tester) async {
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 10)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets(
      'beim Verlassen der Reichweite hält er an und der Winkel fällt weg',
      (tester) async {
        // **Der Abschaltzweig war nie geprüft.** Jeder Test dieser Gruppe
        // beginnt mit `FactProximity.empty` oder bleibt besetzt; der Übergang
        // nah → leer kam nicht vor, und deshalb überlebten drei Mutationen: das
        // fehlende `stop()`, das fehlende Löschen der Winkel und der ganze Zweig
        // durch ein `return;` ersetzt.
        //
        // Beide Aussagen stehen in einem Test, weil sie zwei Hälften derselben
        // Rückstellung sind: `screen-map.jsx:2312` löscht den Winkel beim
        // Verlassen, und beim erneuten Betreten beginnt die Drehung wieder
        // bei 0.
        final ProviderContainer container = ProviderContainer(
          overrides: [
            mapHostProvider.overrideWithValue(host),
            factProximityProvider.overrideWith(
              (Ref ref) => ref.watch(probeProximityProvider),
            ),
          ],
        );
        addTearDown(container.dispose);
        host.projectionAnswer = <MapScreenPoint?>[
          const MapScreenPoint(
            xInScreenPixels: 200,
            yInScreenPixels: 400,
            isInFrontOfCamera: true,
          ),
        ];
        final FactProximity near = FactProximity(
          points: <FactProximityPoint>[pointAt('7', meters: 10)],
        );

        await pumpOverlay(tester, container: container);
        await mapComesAlive(tester);
        container.read(probeProximityProvider.notifier).put(near);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final double turned = paintersOf(tester).single.spinDegrees;
        expect(turned, greaterThan(0));

        container
            .read(probeProximityProvider.notifier)
            .put(FactProximity.empty);
        await tester.pump();
        await tester.pump();

        expect(
          tester.binding.transientCallbackCount,
          0,
          reason: 'ohne Ballon fordert niemand mehr Bilder an',
        );

        // Und beim erneuten Betreten steht der Ballon wieder gerade.
        container.read(probeProximityProvider.notifier).put(near);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          paintersOf(tester).single.spinDegrees,
          lessThan(turned),
          reason: 'der Winkel hat den Ausflug nicht überlebt',
        );
        expect(
          paintersOf(tester).single.spinDegrees,
          closeTo(factSpinSpeedAt(near.points.single.emphasis) * 0.1, 1e-6),
        );
      },
    );
  });

  group('Die Projektion', () {
    testWidgets('jede Kamerameldung fragt neu', (tester) async {
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 30)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);
      final int afterFirst = host.projected.length;

      host.bind(
        const MapCameraView(
          center: MapPosition(latitude: 48.14, longitude: 11.59),
          zoom: 16,
          bearing: 0,
          pitch: 58,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(afterFirst, 1);
      expect(host.projected.length, 2);
    });

    testWidgets('nie zwei Anfragen gleichzeitig, und die letzte gewinnt', (
      tester,
    ) async {
      // **Ohne dieses Zusammenfassen baut sich bei 60 Meldungen je Sekunde
      // eine Warteschlange auf, die nie leer wird**, und die Ballons zeigten
      // immer weiter zurückliegende Stellungen.
      host.pendingProjection = Completer<List<MapScreenPoint?>>();
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 30)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);

      for (int i = 0; i < 5; i++) {
        host.bind(
          MapCameraView(
            center: MapPosition(latitude: 48.14 + i / 1000, longitude: 11.59),
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

      // **Die gemerkten Meldungen sind eine und nicht fünf.**
      expect(host.projected, hasLength(2));
      expect(host.peakInFlight, 1);
    });

    testWidgets('ein neuer Ballon wird sofort projiziert', (tester) async {
      // Ohne das Zuhören auf die Nachbarschaft erschiene er erst bei der
      // nächsten Kamerabewegung, und wer stehen bleibt, sähe ihn nie.
      final ProviderContainer container = ProviderContainer(
        overrides: [
          mapHostProvider.overrideWithValue(host),
          factProximityProvider.overrideWith(
            (Ref ref) => ref.watch(probeProximityProvider),
          ),
        ],
      );
      addTearDown(container.dispose);
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];

      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);
      expect(host.projected, isEmpty, reason: 'noch ist niemand nah');

      container
          .read(probeProximityProvider.notifier)
          .put(
            FactProximity(
              points: <FactProximityPoint>[pointAt('7', meters: 30)],
            ),
          );
      await tester.pump();
      await tester.pump();

      expect(host.projected, hasLength(1));
      expect(paintersOf(tester), hasLength(1));
    });

    testWidgets(
      'ein zweiter Ballon kommt dazu, während der erste schon läuft',
      (tester) async {
        // **Der Zwischenspeicher `_animated` ist die Liste, aus der die
        // Projektion ihre Punkte nimmt**, und er wird nur an zwei Stellen
        // geschrieben. Bisher war allein der Weg von leer auf einen geprüft.
        // Bliebe der Zwischenspeicher stehen, sobald der Taktgeber schon läuft,
        // bekäme der Neue nie eine Bildschirmlage und wäre unsichtbar, während
        // der Erste weiterdreht.
        final ProviderContainer container = ProviderContainer(
          overrides: [
            mapHostProvider.overrideWithValue(host),
            factProximityProvider.overrideWith(
              (Ref ref) => ref.watch(probeProximityProvider),
            ),
          ],
        );
        addTearDown(container.dispose);
        host.projectionAnswer = <MapScreenPoint?>[
          const MapScreenPoint(
            xInScreenPixels: 100,
            yInScreenPixels: 200,
            isInFrontOfCamera: true,
          ),
          const MapScreenPoint(
            xInScreenPixels: 300,
            yInScreenPixels: 200,
            isInFrontOfCamera: true,
          ),
        ];

        await pumpOverlay(tester, container: container);
        await mapComesAlive(tester);
        container
            .read(probeProximityProvider.notifier)
            .put(
              FactProximity(
                points: <FactProximityPoint>[pointAt('erster', meters: 10)],
              ),
            );
        await tester.pump();
        await tester.pump();
        expect(paintersOf(tester), hasLength(1));

        container
            .read(probeProximityProvider.notifier)
            .put(
              FactProximity(
                points: <FactProximityPoint>[
                  pointAt('erster', meters: 10),
                  pointAt('zweiter', meters: 20),
                ],
              ),
            );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(paintersOf(tester), hasLength(2));
        expect(host.projected.last, hasLength(2));
        // Und der Neue dreht sich auch: der Winkelzähler kennt ihn.
        for (final FactBalloonPainter painter in paintersOf(tester)) {
          expect(painter.spinDegrees, greaterThan(0));
        }
      },
    );

    testWidgets('eine gescheiterte Projektion friert die nächste nicht ein', (
      tester,
    ) async {
      // **Ohne dieses `whenComplete` fällt das ganze Bauteil nach einem
      // einzigen Fehlschlag aus.** `_projectionInFlight` bliebe dauerhaft
      // gesetzt, und danach ginge nie wieder eine Projektion hinaus: die
      // Ballons klebten an ihren alten Bildschirmstellen, während sich die
      // Karte darunter bewegt. Sichtbar wäre das als Ballons, die neben ihren
      // Fakten herwandern, und kein Fehler stünde dabei im Protokoll.
      host.pendingProjection = Completer<List<MapScreenPoint?>>();
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 30)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);
      expect(host.projected, hasLength(1));

      host.failProjection(StateError('der Plattformkanal hat aufgelegt'));
      await tester.pump();
      // `reportDetached` meldet den Fehler weiter, wie es soll. Ohne dieses
      // Abholen bräche der Lauf hier ab.
      expect(tester.takeException(), isA<StateError>());

      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      host.bind(
        const MapCameraView(
          center: MapPosition(latitude: 48.14, longitude: 11.59),
          zoom: 16,
          bearing: 0,
          pitch: 58,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(host.projected, hasLength(2), reason: 'die nächste geht hinaus');
      expect(paintersOf(tester), hasLength(1), reason: 'und kommt an');
    });

    testWidgets('nach dem Entsorgen hört niemand mehr auf die Kamera', (
      tester,
    ) async {
      // **Auf dem Gerät heißt ein fehlendes `cancel()`: nach dem Wegnavigieren
      // ruft der Hörer weiter**, also genau das, wogegen der Zwischenspeicher
      // `_animated` gebaut ist. Im Test blieb es unsichtbar, weil `tearDown`
      // den Strom ohnehin schließt und danach niemand mehr sendet.
      host.projectionAnswer = <MapScreenPoint?>[
        const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: true,
        ),
      ];
      final ProviderContainer container = containerWith(
        FactProximity(points: <FactProximityPoint>[pointAt('7', meters: 30)]),
      );
      await pumpOverlay(tester, container: container);
      await mapComesAlive(tester);
      expect(host.hasCameraListener, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(host.hasCameraListener, isFalse);
    });
  });

  group('Derselbe Pinsel wie das native Bild', () {
    testWidgets('bei Betonung 0 zeichnet das Widget genau das PNG', (
      tester,
    ) async {
      // **Ohne diese Zusicherung laufen zwei Umsetzungen desselben Ballons
      // auseinander, die nie gleichzeitig sichtbar sind.** Auffallen würde es
      // erst als Sprung beim Überqueren der 150-Meter-Grenze.
      //
      // `Picture.toImage` kommt in einem `testWidgets` nur zurück, wenn der
      // Aufruf in `tester.runAsync` läuft: der Unterschied ist die **Zone**,
      // nicht die Zeit.
      await tester.runAsync(() async {
        final FactCategoryStyle style = factCategoryStylesByKey['nat']!;

        final MapOverlayImage fromFactory = await buildFactBalloonImage(
          style,
          pixelRatio: 1,
        );

        final FactBalloonPainter painter = FactBalloonPainter(
          style: factCategoryStylesByKey['nat']!,
          metrics: FactBalloonMetrics.resting,
          scale: 1,
          spinDegrees: 0,
          floatProgress: 0,
        );
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        painter.paint(canvas, FactBalloonMetrics.resting.size);
        final ui.Picture picture = recorder.endRecording();
        final ui.Image image = await picture.toImage(
          factBalloonWidth.round(),
          factBalloonHeight.round(),
        );
        final ByteData? bytes = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        image.dispose();
        picture.dispose();

        expect(bytes, isNotNull);
        expect(bytes!.buffer.asUint8List(), fromFactory.bytes);
      });
    });

    testWidgets('der Zoomfaktor wirkt wirklich auf die Zeichnung', (
      tester,
    ) async {
      // **Die Prüfungen am Widget messen die Fläche, nicht den Inhalt.** Ein
      // Zeichner, der `scale` entgegennimmt und nicht anwendet, malt einen
      // Ballon in voller Größe in eine geschrumpfte Fläche, und die
      // Maßprüfungen bleiben grün. Genau diese Mutation hat die Suite
      // überlebt, bevor es diesen Test gab.
      await tester.runAsync(() async {
        Future<Uint8List> render(double scale) async {
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
          FactBalloonPainter(
            style: factCategoryStylesByKey['nat']!,
            metrics: FactBalloonMetrics.resting,
            scale: scale,
            spinDegrees: 0,
            floatProgress: 0,
          ).paint(canvas, FactBalloonMetrics.resting.size);
          final ui.Picture picture = recorder.endRecording();
          final ui.Image image = await picture.toImage(
            factBalloonWidth.round(),
            factBalloonHeight.round(),
          );
          final ByteData? bytes = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          image.dispose();
          picture.dispose();
          return bytes!.buffer.asUint8List();
        }

        expect(await render(0.5), isNot(await render(1)));
      });
    });

    testWidgets('ein gedrehter Ballon sieht anders aus als ein ruhender', (
      tester,
    ) async {
      // Die Gegenprobe zur Prüfung darüber: ohne sie wäre auch ein Pinsel
      // grün, der den Drehwinkel gar nicht anwendet.
      await tester.runAsync(() async {
        Future<Uint8List> render(double spinDegrees) async {
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
          FactBalloonPainter(
            style: factCategoryStylesByKey['nat']!,
            metrics: const FactBalloonMetrics(emphasis: 0.8),
            scale: 1,
            spinDegrees: spinDegrees,
            floatProgress: 0,
          ).paint(canvas, const FactBalloonMetrics(emphasis: 0.8).size);
          final ui.Picture picture = recorder.endRecording();
          final ui.Image image = await picture.toImage(120, 140);
          final ByteData? bytes = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          image.dispose();
          picture.dispose();
          return bytes!.buffer.asUint8List();
        }

        expect(await render(60), isNot(await render(0)));
      });
    });
  });
}

/// Eine Nachbarschaft, die ein Test von außen ändern kann.
///
/// Ein Notifier und kein `StateProvider`: den gibt es in Riverpod 3 nicht
/// mehr.
class ProbeProximity extends Notifier<FactProximity> {
  @override
  FactProximity build() => FactProximity.empty;

  /// Setzt die Nachbarschaft.
  void put(FactProximity value) => state = value;
}

/// Der Provider dazu.
final NotifierProvider<ProbeProximity, FactProximity> probeProximityProvider =
    NotifierProvider<ProbeProximity, FactProximity>(ProbeProximity.new);

/// Ein Karten-Host ohne Karte.
///
/// **Er muss ein Doppelgänger sein:** der echte bekommt seine Kamera erst aus
/// `onMapCreated`, und das läuft ohne Plattformkanal nie.
class FakeMapHost implements MapHost {
  final StreamController<MapCameraView> _cameras =
      StreamController<MapCameraView>.broadcast();

  MapCameraView? _camera;

  @override
  MapCameraView? get camera => _camera;

  @override
  Stream<MapCameraView> get cameraChanges => _cameras.stream;

  /// Ob überhaupt noch jemand am Kamerastrom hängt.
  ///
  /// **Das ist die einzige Stelle, an der ein fehlendes `cancel()` sichtbar
  /// wird.** Über den Strom zu senden und zu zählen, was danach passiert,
  /// taugt nicht: der Hörer eines entsorgten Widgets läuft in ein `setState`
  /// nach `dispose`, und eine Ausnahme aus einem Mikrotask ist ein wackliger
  /// Messwert. `hasListener` ist ein Rechteck.
  bool get hasCameraListener => _cameras.hasListener;

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

  /// Wie viele Anfragen gerade gleichzeitig unterwegs sind.
  int inFlight = 0;

  /// Der höchste je gleichzeitig erreichte Stand von [inFlight].
  ///
  /// Es gibt diesen Zähler, weil „nie zwei gleichzeitig" sonst nicht prüfbar
  /// wäre: eine bloße Anzahl der Aufrufe sagt nichts darüber, ob sie sich
  /// überlappt haben.
  int peakInFlight = 0;

  /// Wenn gesetzt, antwortet die Projektion erst, wenn der Test es sagt.
  Completer<List<MapScreenPoint?>>? pendingProjection;

  /// Was die Projektion liefert, wenn sie sofort antwortet.
  List<MapScreenPoint?>? projectionAnswer;

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

  /// Lässt eine angehaltene Projektion scheitern.
  ///
  /// **Der Vertrag sagt zwar zu, nicht zu werfen**, aber der Weg dorthin führt
  /// über einen Plattformkanal, und eine Zusage ist kein `catchError`.
  void failProjection(Object error) {
    final Completer<List<MapScreenPoint?>>? gate = pendingProjection;
    pendingProjection = null;
    gate?.completeError(error);
  }

  /// Die Karte meldet sich.
  void bind(MapCameraView view) {
    _camera = view;
    _cameras.add(view);
  }

  /// Schließt den Kamerastrom.
  Future<void> close() {
    // Eine angehaltene Anfrage darf den Test nicht überleben.
    pendingProjection?.complete(const <MapScreenPoint?>[]);
    pendingProjection = null;
    return _cameras.close();
  }
}
