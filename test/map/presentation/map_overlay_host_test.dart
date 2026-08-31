import 'dart:async';
import 'dart:typed_data';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/presentation/map_overlay_driver.dart';
import 'package:fact_app/map/presentation/map_overlay_host.dart';
import 'package:flutter/foundation.dart'
    show FlutterError, FlutterErrorDetails, FlutterExceptionHandler;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Der Führer der Überlagerungen und die reinen Funktionen, aus denen er seine
/// Quellen und Layer baut.
///
/// **Hier gibt es keinen `MapLibreMapController`, und es kann keinen geben.**
/// Ohne Plattformkanal läuft `onPlatformViewCreated` nie, also entsteht in
/// keinem Widget-Test einer (`maplibre_map.dart:390-418`). Alles, was am
/// echten SDK hängt, ist ausschließlich über die Naht [MapOverlayDriver]
/// prüfbar. Der Doppelgänger unten schreibt deshalb **die Reihenfolge** mit
/// und nicht nur die Summe der Aufrufe: dass die Quelle vor ihren Layern
/// entsteht, ist die eine Zusicherung, die man am Ergebnis nicht ablesen kann.
void main() {
  const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);

  const MapOverlayPoint point = MapOverlayPoint(
    id: '4711',
    position: munich,
    styleId: 'fact.hist.uncollected',
    state: 'uncollected',
  );

  const MapOverlay grouped = MapOverlay(
    id: 'discovery.facts',
    points: <MapOverlayPoint>[point],
    grouping: MapOverlayGrouping(maxZoom: 15, radiusInScreenPixels: 70),
    minZoom: 11,
  );

  MapOverlayImage imageFor(String styleId) => MapOverlayImage(
    styleId: styleId,
    bytes: Uint8List.fromList(const <int>[137, 80, 78, 71]),
    pixelRatio: 1,
  );

  group('overlayGeoJson', () {
    test('die Kennung steht oben und nicht unter properties', () {
      // **Der teuerste stille Fehler dieses Schritts.** Der Antipp-Rückruf des
      // Pakets liefert nur `id`, `layerId` und die Positionen; `properties`
      // kommt nicht mit. Eine Kennung unter `properties.id` ergibt beim
      // Antippen die Zeichenkette "null", ohne Ausnahme und ohne Warnung. Die
      // Verhaltensquelle legt sie genau dorthin (`screen-map.jsx:1896`), wer
      // ihr GeoJSON eins zu eins übernimmt, erbt den Fehler.
      final Map<String, dynamic> json = overlayGeoJson(grouped);
      final List<dynamic> features = json['features'] as List<dynamic>;
      final Map<String, dynamic> feature =
          features.single as Map<String, dynamic>;

      expect(feature['id'], '4711');
      final Map<String, dynamic> properties =
          feature['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('id'), isFalse);
    });

    test('die Koordinaten stehen als Länge, Breite', () {
      // RFC 7946 §3.1.1 zählt Länge vor Breite, die Domäne umgekehrt. Wer sie
      // vertauscht, legt München nach Somalia, und im Widget-Test sieht das
      // niemand.
      final List<dynamic> features =
          overlayGeoJson(grouped)['features'] as List<dynamic>;
      final Map<String, dynamic> geometry =
          (features.single as Map<String, dynamic>)['geometry']
              as Map<String, dynamic>;

      expect(geometry['coordinates'], <double>[11.582, 48.1351]);
    });

    test('Stil und Zustand stehen als Eigenschaften', () {
      final List<dynamic> features =
          overlayGeoJson(grouped)['features'] as List<dynamic>;
      final Map<String, dynamic> properties =
          (features.single as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;

      expect(properties[overlayStyleProperty], 'fact.hist.uncollected');
      expect(properties[overlayStateProperty], 'uncollected');
    });

    test('ohne Punkte bleibt eine leere FeatureCollection', () {
      final Map<String, dynamic> json = overlayGeoJson(
        const MapOverlay(id: 'leer', points: <MapOverlayPoint>[]),
      );
      expect(json['type'], 'FeatureCollection');
      expect(json['features'], isEmpty);
    });
  });

  group('overlaySourceProperties', () {
    test('die Gruppierung trägt 15 und 70, wie die Quelle', () {
      // `screen-map.jsx:1910-1912`. Diese drei Werte gibt es **nur** über
      // `addSource` mit `GeojsonSourceProperties`; `addGeoJsonSource` reicht
      // auf Android allein `withSynchronousUpdate` durch
      // (`MapLibreMapController.java:448`) und gruppiert nie.
      final GeojsonSourceProperties properties = overlaySourceProperties(
        grouped,
      );

      expect(properties.cluster, isTrue);
      expect(properties.clusterMaxZoom, 15);
      expect(properties.clusterRadius, 70);
      expect(properties.data, overlayGeoJson(grouped));
    });

    test('ohne Gruppierung wird nicht gruppiert', () {
      final GeojsonSourceProperties properties = overlaySourceProperties(
        const MapOverlay(id: 'leer', points: <MapOverlayPoint>[]),
      );
      expect(properties.cluster, isFalse);
      expect(properties.clusterMaxZoom, isNull);
      // Der Rückfall ist ausdrücklich der Standard des Pakets
      // (`source_properties.dart:517`) und keine gewählte Zahl. Ohne diese
      // Zeile wäre jede andere Zahl hier grün, und sie wirkte in dem Moment,
      // in dem jemand `cluster` einschaltet und den Radius vergisst.
      expect(properties.clusterRadius, 50);
    });
  });

  group('Layer', () {
    // **Diese Gruppe ist bewusst langweilig, und das ist ihr ganzer Sinn.**
    // Das Aussehen der Gruppen ist aus der Quelle abgeschrieben, also genau
    // die Sorte Code, bei der ein einzelnes falsches Zeichen niemandem
    // auffällt: eine Farbe um eins verschoben, ein Radiusfaktor von 0,92 auf
    // 0,29, die Grundstufe der Schrift von 14 auf 13. Nichts davon bricht,
    // nichts davon meldet sich, die Karte sieht nur anders aus als die PWA.
    // Hier stehen die Werte deshalb ein zweites Mal, abgetippt aus
    // `screen-map.jsx:1918-2029`, nach dem Muster von
    // `fact_categories_test.dart`. Eine Schleife über die Implementierung wäre
    // immer grün.
    const List<Object> radiusExpr = <Object>[
      'step',
      <Object>['get', 'point_count'],
      24,
      20,
      30,
      50,
      38,
      100,
      46,
      200,
      54,
    ];

    test('die drei Gruppenkreise heißen wie in der Quelle', () {
      // `:1956`, `:1972`, `:1988`, in Zeichenreihenfolge.
      final List<MapOverlayGroupLayer> layers = overlayGroupCircleLayers('x');
      expect(layers, hasLength(3));
      expect(
        layers.map((MapOverlayGroupLayer layer) => layer.layerId),
        <String>['x.groups', 'x.groups-mid', 'x.groups-shine'],
      );
    });

    test('der Grundkreis trägt baseColorExpr, radiusExpr und den Rand', () {
      // `:1929-1936` und `:1961-1967`.
      final CircleLayerProperties base = overlayGroupCircleLayers(
        'x',
      ).first.properties;

      expect(base.circleColor, <Object>[
        'step',
        <Object>['get', 'point_count'],
        '#C9740A',
        20,
        '#A04210',
        50,
        '#7A1B0A',
        100,
        '#5A1208',
        200,
        '#3A0A04',
      ]);
      expect(base.circleRadius, radiusExpr);
      expect(base.circleStrokeWidth, 4);
      expect(base.circleStrokeColor, 'rgba(255,255,255,0.95)');
      expect(base.circleOpacity, 1);
      // Der Grundkreis ist der einzige ohne Weichzeichner.
      expect(base.circleBlur, isNull);
      expect(base.circleTranslate, isNull);
    });

    test('der Mittelkreis trägt midColorExpr, 0,92 und Blur 0,35', () {
      // `:1937-1944` und `:1977-1983`.
      final CircleLayerProperties mid = overlayGroupCircleLayers(
        'x',
      )[1].properties;

      expect(mid.circleColor, <Object>[
        'step',
        <Object>['get', 'point_count'],
        '#F39C0E',
        20,
        '#E8380D',
        50,
        '#B83A2E',
        100,
        '#8E1F0A',
        200,
        '#6B1A0A',
      ]);
      expect(mid.circleRadius, <Object>['*', radiusExpr, 0.92]);
      expect(mid.circleBlur, 0.35);
      expect(mid.circleStrokeWidth, 0);
      expect(mid.circleOpacity, 1);
      expect(mid.circleTranslate, isNull);
    });

    test('der Glanz trägt shineColorExpr, 0,72, Blur 0,9 und den Versatz', () {
      // `:1945-1952` und `:1993-2000`.
      final CircleLayerProperties shine = overlayGroupCircleLayers(
        'x',
      )[2].properties;

      expect(shine.circleColor, <Object>[
        'step',
        <Object>['get', 'point_count'],
        '#FFD27A',
        20,
        '#F39C0E',
        50,
        '#E8380D',
        100,
        '#C82A0A',
        200,
        '#A82508',
      ]);
      expect(shine.circleRadius, <Object>['*', radiusExpr, 0.72]);
      expect(shine.circleTranslate, <double>[-2, -3]);
      expect(shine.circleBlur, 0.9);
      expect(shine.circleStrokeWidth, 0);
      expect(shine.circleOpacity, 1);
    });

    test('die Beschriftung zählt die Gruppe ab', () {
      // `:2010-2027`, vollständig und nicht in Auswahl: `textColor`,
      // `textHaloColor` und `textHaloWidth` entscheiden darüber, ob die Zahl
      // auf dem dunkelroten Kreis überhaupt lesbar ist.
      final SymbolLayerProperties properties = overlayGroupCountProperties();

      expect(properties.textField, '{point_count_abbreviated}');
      expect(properties.textFont, <String>['Noto Sans Bold']);
      expect(properties.textSize, <Object>[
        'step',
        <Object>['get', 'point_count'],
        14,
        20,
        16,
        50,
        18,
        100,
        20,
        200,
        22,
      ]);
      expect(properties.textAllowOverlap, isTrue);
      expect(properties.textColor, '#ffffff');
      expect(properties.textHaloColor, 'rgba(0,0,0,0.25)');
      expect(properties.textHaloWidth, 1);
    });

    test('die einzelnen Punkte hängen am Bild und stehen unten', () {
      final SymbolLayerProperties properties = overlayPointProperties();
      // `icon-anchor: bottom` wie `new mapboxgl.Marker({ anchor: 'bottom' })`
      // (`screen-map.jsx:2187`): der Punkt sitzt am unteren Ende, der Kopf
      // schwebt darüber.
      expect(properties.iconAnchor, 'bottom');
      // DOM-Marker verdrängen einander nie. Ohne diesen Schalter blendete
      // MapLibre in einer dichten Altstadt die Hälfte der Ballons aus.
      expect(properties.iconAllowOverlap, isTrue);
      expect(properties.iconImage, <Object>['get', 'style']);
    });

    test('die Zoom-Skalierung bildet mapGetScale ab', () {
      // `screen-map.jsx:1799`:
      // `z => Math.max(0.42, Math.min(1.25, (z - 11) / 6))`.
      // Die beiden Stützstellen sind die Knickpunkte der Klammer und keine
      // gewählten Zahlen: `(z - 11) / 6` erreicht 0,42 bei 13,52 und 1,25 bei
      // 18,5.
      expect((13.52 - 11) / 6, closeTo(0.42, 1e-12));
      expect((18.5 - 11) / 6, closeTo(1.25, 1e-12));
      expect(overlayPointSizeExpression, <Object>[
        'interpolate',
        <Object>['linear'],
        <Object>['zoom'],
        13.52,
        0.42,
        18.5,
        1.25,
      ]);
    });

    test('die Filter trennen Gruppen von einzelnen Punkten', () {
      expect(groupFilter, <Object>['has', 'point_count']);
      expect(singlePointFilter, <Object>[
        '!',
        <Object>['has', 'point_count'],
      ]);
    });
  });

  group('mapOverlayLayerTapOf', () {
    // **Reine Funktion, ohne Karte und ohne SDK prüfbar.** Genau das ist ihr
    // Zweck: `_onMapCreated` läuft im Widget-Test nie, also muss die
    // Übersetzung aus dem Rückruf des SDK hier stehen und nicht dort.
    const LatLng tapAt = LatLng(48.1351, 11.582);

    test('ein Kreis-Layer meldet einen Gruppen-Tipp mit lng/lat, nicht x/y', () {
      // **Der teuerste denkbare Vertauschungsfehler dieses Schritts:** GeoJSON
      // zählt Länge vor Breite, die Domäne umgekehrt. Vertauschte `lat` und
      // `lng` gingen sonst durch jede Suite und fielen erst am Gerät auf, als
      // Ballon-Tipp mit einer Stelle in Somalia.
      final MapOverlayLayerTap result = mapOverlayLayerTapOf(
        layerId: 'discovery.facts.groups-mid',
        coordinates: tapAt,
        installedOverlayIds: <String>['discovery.facts'],
      );

      final MapOverlayLayerTapGroup group = result as MapOverlayLayerTapGroup;
      expect(group.tap.overlayId, 'discovery.facts');
      expect(group.tap.position.latitude, 48.1351);
      // **Nicht auf den Zahlenwert genau**: `LatLng` normalisiert den
      // Längengrad im Konstruktor, aus 11.582 wird 11.581999999999994, wie in
      // `map_surface_test.dart` gemessen.
      expect(group.tap.position.longitude, closeTo(11.582, 1e-9));
    });

    test('die Beschriftung einer Gruppe zählt genauso als Gruppen-Tipp', () {
      final MapOverlayLayerTap result = mapOverlayLayerTapOf(
        layerId: 'discovery.facts.group-count',
        coordinates: tapAt,
        installedOverlayIds: <String>['discovery.facts'],
      );

      expect(result, isA<MapOverlayLayerTapGroup>());
    });

    test('der Punkt-Layer einer installierten Überlagerung bleibt still', () {
      final MapOverlayLayerTap result = mapOverlayLayerTapOf(
        layerId: 'discovery.facts.points',
        coordinates: tapAt,
        installedOverlayIds: <String>['discovery.facts'],
      );

      expect(result, isA<MapOverlayLayerTapPoint>());
    });

    test('eine Kennung, die keine installierte Überlagerung kennt, ist '
        'unbekannt', () {
      final MapOverlayLayerTap result = mapOverlayLayerTapOf(
        layerId: 'discovery.facts.points',
        coordinates: tapAt,
        // Die Überlagerung ist gesetzt, aber nicht installiert: ohne Karte
        // hat sie keine echten Layer, ein Tipp darauf kann also gar nicht
        // entstehen, und eine ankommende Kennung ist dann unbekannt.
        installedOverlayIds: <String>[],
      );

      expect(result, isA<MapOverlayLayerTapUnknown>());
    });

    test('eine Kennung, die zu keiner installierten Überlagerung gehört, ist '
        'unbekannt', () {
      final MapOverlayLayerTap result = mapOverlayLayerTapOf(
        layerId: 'irgendein.anderer.layer',
        coordinates: tapAt,
        installedOverlayIds: <String>['discovery.facts'],
      );

      expect(result, isA<MapOverlayLayerTapUnknown>());
    });

    group('mit zwei installierten Überlagerungen', () {
      // **Block 2 hat nie zwei Überlagerungen gleichzeitig installiert.**
      // Eine Mutation, die bei einem Treffer immer die *erste* installierte
      // Kennung zurückgibt statt der wirklich getroffenen, blieb dadurch in
      // allen 642 Tests unter `test/map/` und `test/features/discovery/`
      // unentdeckt. Vier Features teilen sich diese Karte; sobald ein
      // zweites gruppiertes Overlay liegt, würde ein Tipp auf dessen Gruppe
      // lautlos der ersten Überlagerung zugeschrieben.
      const List<String> installed = <String>[
        'discovery.facts',
        'events.today',
      ];

      test('jeder der vier Gruppen-Layer der zweiten Überlagerung meldet ihre '
          'eigene Kennung, nicht die der ersten', () {
        // Die Kennungen kommen aus den echten Funktionen und stehen nicht
        // als abgeschriebene Zeichenkette da: sonst prüfte der Test die
        // Konstante gegen sich selbst (Regel 18).
        final List<String> secondGroupLayerIds = <String>[
          ...overlayGroupCircleLayerIds('events.today'),
          overlayGroupCountLayerId('events.today'),
        ];

        for (final String layerId in secondGroupLayerIds) {
          final MapOverlayLayerTap result = mapOverlayLayerTapOf(
            layerId: layerId,
            coordinates: tapAt,
            installedOverlayIds: installed,
          );

          final MapOverlayLayerTapGroup group =
              result as MapOverlayLayerTapGroup;
          expect(
            group.tap.overlayId,
            'events.today',
            reason: 'layerId: $layerId',
          );
        }
      });

      test('der Punkt-Layer der zweiten Überlagerung bleibt still, auch mit '
          'zwei installierten Überlagerungen', () {
        final MapOverlayLayerTap result = mapOverlayLayerTapOf(
          layerId: overlayPointLayerId('events.today'),
          coordinates: tapAt,
          installedOverlayIds: installed,
        );

        expect(result, isA<MapOverlayLayerTapPoint>());
      });
    });
  });

  group('MapOverlayHost', () {
    late RecordingOverlayDriver driver;
    late RecordingSink diagnostics;
    late MapOverlayHost host;

    setUp(() {
      driver = RecordingOverlayDriver();
      diagnostics = RecordingSink();
      host = MapOverlayHost(diagnostics: diagnostics);
    });

    test('ohne Karte geht nichts ans SDK und nichts verloren', () async {
      host
        ..registerImages(<MapOverlayImage>[imageFor('fact.hist.uncollected')])
        ..setOverlay(grouped);
      await host.debugSettled;

      expect(driver.calls, isEmpty);
      expect(host.debugRegisteredStyleIds, <String>['fact.hist.uncollected']);
      expect(host.debugInstalledOverlayIds, isEmpty);
    });

    test('beim Binden kommen erst die Bilder, dann die Quelle, dann die '
        'Layer', () async {
      // **Die Reihenfolge ist die Zusicherung.** Ein Symbol-Layer ohne sein
      // Bild zeichnet nichts, ohne Fehler; ein Layer ohne seine Quelle
      // ebenfalls nicht. Am Endzustand ist beides nicht zu unterscheiden.
      host
        ..registerImages(<MapOverlayImage>[imageFor('fact.hist.uncollected')])
        ..setOverlay(grouped)
        ..bindSurface(driver);
      await host.debugSettled;

      expect(driver.calls, <String>[
        'addImage:fact.hist.uncollected',
        'addSource:discovery.facts.source',
        'addCircleLayer:discovery.facts.groups',
        'addCircleLayer:discovery.facts.groups-mid',
        'addCircleLayer:discovery.facts.groups-shine',
        'addSymbolLayer:discovery.facts.group-count',
        'addSymbolLayer:discovery.facts.points',
      ]);
    });

    test('die Gruppen-Layer tragen minzoom 11', () async {
      // `screen-map.jsx:1959`, `:1975`, `:1991`, `:2008`: alle vier
      // Gruppen-Layer der Quelle tragen `minzoom: 11`. Darunter zeigt sie
      // statt der Gruppen einen Marker je Stadt.
      host
        ..setOverlay(grouped)
        ..bindSurface(driver);
      await host.debugSettled;

      expect(
        driver.layers.map((RecordedLayer layer) => layer.minzoom),
        everyElement(11),
      );
    });

    test(
      'Gruppen-Layer filtern auf Gruppen, der Punkt-Layer dagegen',
      () async {
        host
          ..setOverlay(grouped)
          ..bindSurface(driver);
        await host.debugSettled;

        final RecordedLayer points = driver.layers.last;
        expect(points.layerId, 'discovery.facts.points');
        expect(points.filter, singlePointFilter);
        for (final RecordedLayer layer in driver.layers.take(4)) {
          expect(layer.filter, groupFilter);
        }
      },
    );

    test('ohne Gruppierung entstehen nur die einzelnen Punkte', () async {
      host
        ..setOverlay(
          const MapOverlay(id: 'nur.punkte', points: <MapOverlayPoint>[point]),
        )
        ..bindSurface(driver);
      await host.debugSettled;

      expect(driver.layers, hasLength(1));
      expect(driver.layers.single.layerId, 'nur.punkte.points');
    });

    test('eine zweite Überlagerung tauscht nur die Daten aus', () async {
      // Ein zweites `addSource` auf dieselbe Kennung wäre auf Android ein
      // Fehler im Logcat und sonst nichts sichtbares.
      host
        ..setOverlay(grouped)
        ..bindSurface(driver);
      await host.debugSettled;
      driver.calls.clear();

      host.setOverlay(
        const MapOverlay(
          id: 'discovery.facts',
          points: <MapOverlayPoint>[],
          grouping: MapOverlayGrouping(maxZoom: 15, radiusInScreenPixels: 70),
          minZoom: 11,
        ),
      );
      await host.debugSettled;

      expect(driver.calls, <String>['setGeoJsonSource:discovery.facts.source']);
    });

    test('das Entfernen nimmt erst die Layer, dann die Quelle', () async {
      host
        ..setOverlay(grouped)
        ..bindSurface(driver);
      await host.debugSettled;
      driver.calls.clear();

      host.removeOverlay('discovery.facts');
      await host.debugSettled;

      expect(driver.calls, <String>[
        'removeLayer:discovery.facts.groups',
        'removeLayer:discovery.facts.groups-mid',
        'removeLayer:discovery.facts.groups-shine',
        'removeLayer:discovery.facts.group-count',
        'removeLayer:discovery.facts.points',
        'removeSource:discovery.facts.source',
      ]);
    });

    test('eine unbekannte Kennung wird entfernt, ohne etwas zu tun', () async {
      host.bindSurface(driver);
      host.removeOverlay('gibt.es.nicht');
      await host.debugSettled;

      expect(driver.calls, isEmpty);
    });

    test('eine unbekannte Stil-Kennung wird gemeldet, einmal je Kennung', () {
      // MapLibre zeichnet für ein unbekanntes `icon-image` **gar nichts**,
      // ohne Fehler. Diese Meldung ist der einzige Schutz, den ein Vertrag mit
      // freien Zeichenketten haben kann.
      host.setOverlay(
        const MapOverlay(
          id: 'discovery.facts',
          points: <MapOverlayPoint>[
            point,
            MapOverlayPoint(
              id: '2',
              position: munich,
              styleId: 'fact.hist.uncollected',
              state: 'uncollected',
            ),
            MapOverlayPoint(
              id: '3',
              position: munich,
              styleId: 'fact.aliens.uncollected',
              state: 'uncollected',
            ),
          ],
        ),
      );

      expect(diagnostics.events, hasLength(1));
      final DiagnosticEvent event = diagnostics.events.single;
      expect(event.name, MapOverlayHost.unknownStyleEvent);
      expect(
        event.attributes['styles'],
        'fact.aliens.uncollected,fact.hist.uncollected',
      );
    });

    test('bekannte Kennungen melden nichts', () {
      host
        ..registerImages(<MapOverlayImage>[imageFor('fact.hist.uncollected')])
        ..setOverlay(grouped);

      expect(diagnostics.events, isEmpty);
    });

    test('nach dem Lösen der Karte wird neu aufgelegt und nicht nur '
        'nachgeschoben', () async {
      // Mit der Karte verschwindet die Quelle. Bliebe der Host der Meinung,
      // sie stünde noch, schöbe er Daten in etwas, das es nicht gibt, und
      // `setGeoJsonSource` liefe auf Android in „source not found" ins Leere
      // (`MapLibreMapController.java:471-474`).
      host
        ..setOverlay(grouped)
        ..bindSurface(driver);
      await host.debugSettled;
      host.unbindSurface();
      driver.calls.clear();

      host.bindSurface(driver);
      await host.debugSettled;

      expect(driver.calls.first, 'addSource:discovery.facts.source');
    });

    test('ein später registriertes Bild geht noch ans SDK', () async {
      host.bindSurface(driver);
      host.registerImages(<MapOverlayImage>[imageFor('fact.myth.uncollected')]);
      await host.debugSettled;

      expect(driver.calls, <String>['addImage:fact.myth.uncollected']);
    });

    test('ein Fehlschlag beendet die Kette nicht und wird gemeldet', () async {
      // `MapOverlayHost._enqueue` verspricht genau das, und ohne Prüfung war
      // weder zugesichert, dass die Kette weiterläuft, noch dass der
      // Fehlschlag herauskommt. Bliebe der Fehler in `_work` stehen, scheiterte
      // **jeder** spätere Vorgang mit ihm, und ein einziger fehlerhafter Layer
      // legte die Karte für den Rest der Sitzung still.
      final FlutterExceptionHandler? previous = FlutterError.onError;
      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final FailingOverlayDriver failing = FailingOverlayDriver();
      final MapOverlayHost brittle = MapOverlayHost();
      brittle
        ..setOverlay(grouped)
        ..bindSurface(failing);
      await brittle.debugSettled;

      // Die Kette lebt: der nächste Vorgang kommt beim SDK an.
      brittle.registerImages(<MapOverlayImage>[
        imageFor('fact.hist.uncollected'),
      ]);
      await brittle.debugSettled;

      expect(failing.calls, contains('addImage:fact.hist.uncollected'));
      expect(reported, hasLength(1));
      expect(
        reported.single.context.toString(),
        contains('map.overlay.install'),
      );
    });

    test('dispose vergisst alles', () async {
      host
        ..registerImages(<MapOverlayImage>[imageFor('fact.hist.uncollected')])
        ..setOverlay(grouped)
        ..dispose();
      await host.debugSettled;

      expect(host.debugRegisteredStyleIds, isEmpty);
      expect(host.debugInstalledOverlayIds, isEmpty);
    });

    test('dispose schließt auch den Gruppen-Tipp-Strom', () async {
      bool closed = false;
      host.groupTaps.listen(null, onDone: () => closed = true);

      host.dispose();
      await pumpEventQueue();

      expect(closed, isTrue);
    });

    test('eine gesetzte, aber nie installierte Überlagerung zählt nicht als '
        'bekannt', () {
      // **Ohne Karte hat eine gesetzte Überlagerung keine echten Layer im
      // SDK**, ein Tipp auf ihre errechnete Layer-Kennung kann also gar
      // nicht entstehen. Zählte `handleFeatureTapped` trotzdem jede
      // *gesetzte* statt jede *installierte* Überlagerung mit, würde diese
      // Kennung fälschlich als Gruppen-Tipp durchgehen.
      host.setOverlay(
        const MapOverlay(
          id: 'nicht.installiert',
          points: <MapOverlayPoint>[],
          grouping: MapOverlayGrouping(maxZoom: 15, radiusInScreenPixels: 70),
        ),
      );

      host.handleFeatureTapped(
        layerId: 'nicht.installiert.groups',
        at: const LatLng(48.1351, 11.582),
      );

      expect(diagnostics.events, hasLength(1));
      expect(
        diagnostics.events.single.name,
        MapOverlayHost.unknownLayerTapEvent,
      );
    });

    group('handleFeatureTapped', () {
      const LatLng tapAt = LatLng(48.1351, 11.582);

      setUp(() async {
        host
          // Registriert, damit `setOverlay` keine unbekannte Stil-Kennung
          // meldet und diese Gruppe damit ununterscheidbar von der
          // gesuchten Meldung dieses Tests macht.
          ..registerImages(<MapOverlayImage>[imageFor('fact.hist.uncollected')])
          ..setOverlay(grouped)
          ..bindSurface(driver);
        await host.debugSettled;
        diagnostics.events.clear();
      });

      test('ein Gruppen-Layer meldet einen Tipp über groupTaps', () async {
        final Future<MapOverlayGroupTap> seen = host.groupTaps.first;

        host.handleFeatureTapped(layerId: 'discovery.facts.groups', at: tapAt);

        final MapOverlayGroupTap tap = await seen;
        expect(tap.overlayId, 'discovery.facts');
        expect(tap.position.latitude, 48.1351);
        // **Nicht auf den Zahlenwert genau**, aus demselben Grund wie in
        // `map_surface_test.dart`: `LatLng` normalisiert den Längengrad im
        // Konstruktor, aus 11.582 wird 11.581999999999994.
        expect(tap.position.longitude, closeTo(11.582, 1e-9));
      });

      test('der Punkt-Layer meldet nichts und bleibt still', () async {
        final List<MapOverlayGroupTap> seen = <MapOverlayGroupTap>[];
        final StreamSubscription<MapOverlayGroupTap> subscription = host
            .groupTaps
            .listen(seen.add);
        addTearDown(subscription.cancel);

        host.handleFeatureTapped(layerId: 'discovery.facts.points', at: tapAt);
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(diagnostics.events, isEmpty);
      });

      test('eine unbekannte Kennung wird gemeldet', () async {
        host.handleFeatureTapped(layerId: 'gibt.es.nicht.points', at: tapAt);

        expect(diagnostics.events, hasLength(1));
        final DiagnosticEvent event = diagnostics.events.single;
        expect(event.name, MapOverlayHost.unknownLayerTapEvent);
        expect(event.attributes['layerId'], 'gibt.es.nicht.points');
      });

      test('ein Tipp auf (0, 0) wird ganz normal gemeldet: keine Position '
          'ist hier ein Sonderfall', () async {
        // Real-weltlich läge der Punkt im Atlantik, aber (0, 0) ist der
        // Nullwert, den viele Typen als Standard tragen, und deshalb der
        // naheliegendste Randfall für einen übersehenen frühen
        // Rückgabe-Zweig. Dieser Pfad filtert grundsätzlich keine Position.
        final Future<MapOverlayGroupTap> seen = host.groupTaps.first;

        host.handleFeatureTapped(
          layerId: 'discovery.facts.groups',
          at: const LatLng(0, 0),
        );

        final MapOverlayGroupTap tap = await seen;
        expect(tap.overlayId, 'discovery.facts');
        expect(tap.position.latitude, 0);
        expect(tap.position.longitude, 0);
      });
    });

    group('zwei installierte Überlagerungen', () {
      // **Der echte Weg, nicht nur die reine Funktion.** Eine Überlagerung
      // wird nur auf einem **gebundenen** Host wirklich installiert; dieser
      // Test bindet deshalb zuerst und setzt die Überlagerungen danach, damit
      // `_install` sofort greift. Der Bauende von Block 2 hat sich genau an
      // dieser Reihenfolge schon einmal geschnitten, und ein Test, der sie
      // vertauscht, wäre aus dem falschen Grund grün: eine gesetzte, aber nie
      // installierte Überlagerung zählt für `handleFeatureTapped` nicht.
      const MapOverlay second = MapOverlay(
        id: 'events.today',
        points: <MapOverlayPoint>[point],
        grouping: MapOverlayGrouping(maxZoom: 15, radiusInScreenPixels: 70),
        minZoom: 11,
      );

      test('ein Tipp auf die zweite Überlagerung trifft die zweite, nicht '
          'die erste', () async {
        host
          ..registerImages(<MapOverlayImage>[imageFor('fact.hist.uncollected')])
          ..bindSurface(driver)
          ..setOverlay(grouped)
          ..setOverlay(second);
        await host.debugSettled;

        final Future<MapOverlayGroupTap> seen = host.groupTaps.first;

        host.handleFeatureTapped(
          layerId: 'events.today.groups-mid',
          at: const LatLng(48.1351, 11.582),
        );

        final MapOverlayGroupTap tap = await seen;
        expect(tap.overlayId, 'events.today');
      });
    });
  });
}

/// Ein Aufruf von `addCircleLayer` oder `addSymbolLayer`, wie er ankam.
class RecordedLayer {
  RecordedLayer({
    required this.layerId,
    required this.minzoom,
    required this.filter,
  });

  final String layerId;
  final double? minzoom;
  final Object? filter;
}

/// Ein [MapOverlayDriver], der jeden Aufruf in der Reihenfolge mitschreibt.
///
/// `implements` und nicht `extends`: [MapOverlayDriver] ist eine
/// `abstract interface class`, ein `extends` wäre ein Übersetzungsfehler.
class RecordingOverlayDriver implements MapOverlayDriver {
  /// Aufruf und Gegenstand, in der Reihenfolge des Eingangs.
  final List<String> calls = <String>[];

  /// Die angelegten Quellen, nach Kennung.
  final Map<String, SourceProperties> sources = <String, SourceProperties>{};

  /// Die angelegten Layer, in der Reihenfolge des Eingangs.
  final List<RecordedLayer> layers = <RecordedLayer>[];

  @override
  Future<void> addImage(String name, Uint8List bytes) async =>
      calls.add('addImage:$name');

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    calls.add('addSource:$sourceId');
    sources[sourceId] = properties;
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geoJson,
  ) async => calls.add('setGeoJsonSource:$sourceId');

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    CircleLayerProperties properties, {
    double? minzoom,
    double? maxzoom,
    Object? filter,
  }) async {
    calls.add('addCircleLayer:$layerId');
    layers.add(
      RecordedLayer(layerId: layerId, minzoom: minzoom, filter: filter),
    );
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    double? minzoom,
    double? maxzoom,
    Object? filter,
  }) async {
    calls.add('addSymbolLayer:$layerId');
    layers.add(
      RecordedLayer(layerId: layerId, minzoom: minzoom, filter: filter),
    );
  }

  @override
  Future<void> removeLayer(String layerId) async =>
      calls.add('removeLayer:$layerId');

  @override
  Future<void> removeSource(String sourceId) async =>
      calls.add('removeSource:$sourceId');
}

/// Ein Treiber, dessen `addSource` wirft. Sonst wie [RecordingOverlayDriver].
///
/// `extends` und nicht noch ein `implements`: die Aufrufliste soll dieselbe
/// sein, nur `addSource` scheitert.
class FailingOverlayDriver extends RecordingOverlayDriver {
  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    await super.addSource(sourceId, properties);
    throw StateError('Quelle $sourceId ließ sich nicht anlegen');
  }
}

/// Eine Diagnose-Senke, die mitschreibt.
class RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}
