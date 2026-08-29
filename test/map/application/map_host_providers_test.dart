import 'dart:async';
import 'dart:typed_data';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);
const MapPosition rome = MapPosition(latitude: 41.896, longitude: 12.4822);

MapCameraView viewAt(MapPosition center) =>
    MapCameraView(center: center, zoom: 15, bearing: 0, pitch: 0);

/// Ein Host ohne Karte, wie ihn `map/presentation/` liefert.
class FakeMapHost implements MapHost {
  final StreamController<MapCameraView> _controller =
      StreamController<MapCameraView>.broadcast();
  final List<MapCameraIntent> submitted = <MapCameraIntent>[];

  MapCameraView? _camera;

  @override
  MapCameraView? get camera => _camera;

  @override
  Stream<MapCameraView> get cameraChanges => _controller.stream;

  @override
  void submitIntent(MapCameraIntent intent) => submitted.add(intent);

  /// Die Bilder, die angemeldet wurden, in der Reihenfolge des Eingangs.
  final List<MapOverlayImage> registeredImages = <MapOverlayImage>[];

  /// Die Überlagerungen, die gesetzt wurden, in der Reihenfolge des Eingangs.
  final List<MapOverlay> overlays = <MapOverlay>[];

  /// Die Kennungen, die entfernt wurden.
  final List<String> removedOverlays = <String>[];

  /// Ob zuerst Bilder oder zuerst Überlagerungen ankamen.
  final List<String> order = <String>[];

  @override
  void registerOverlayImages(List<MapOverlayImage> images) {
    order.add('images');
    registeredImages.addAll(images);
  }

  @override
  void setOverlay(MapOverlay overlay) {
    order.add('overlay');
    overlays.add(overlay);
  }

  @override
  void removeOverlay(String overlayId) => removedOverlays.add(overlayId);

  void moveTo(MapCameraView view) {
    _camera = view;
    _controller.add(view);
  }

  Future<void> close() => _controller.close();
}

class RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);

  List<String> get names =>
      events.map((DiagnosticEvent event) => event.name).toList();
}

MapOverlayImage imageFor(String styleId) => MapOverlayImage(
  styleId: styleId,
  bytes: Uint8List.fromList(const <int>[1, 2, 3]),
  pixelRatio: 1,
);

MapOverlay overlayNamed(String id) => MapOverlay(
  id: id,
  points: const <MapOverlayPoint>[
    MapOverlayPoint(
      id: '1',
      position: munich,
      styleId: 'a',
      state: 'uncollected',
    ),
  ],
);

MapCameraOneShot skyFall() => const MapCameraOneShot(
  change: MapCameraChange(zoom: 16.5, pitch: 58, bearing: 0),
  motion: MapCameraAnimated(Duration(milliseconds: 1200)),
  origin: MapCameraIntentOrigin.discovery,
);

void main() {
  late RecordingSink sink;
  late MapHostRegistry registry;
  late FakeMapHost host;

  setUp(() {
    sink = RecordingSink();
    registry = MapHostRegistry(diagnostics: sink);
    host = FakeMapHost();
  });

  tearDown(() async {
    registry.dispose();
    await host.close();
  });

  group('Ohne eingeklinkten Host', () {
    test('gibt es keine Kamera, und das wird gemeldet', () {
      // Geschluckt wäre der teurere Fehler: eine Karte, die nichts tut, sieht
      // von außen aus wie eine Karte, die nichts tun soll.
      expect(registry.camera, isNull);
      expect(sink.names, <String>[MapHostRegistry.missingHostEvent]);
      expect(sink.events.single.attributes['access'], 'camera');
    });

    test('geht eine Absicht verloren, und das wird gemeldet', () {
      registry.submitIntent(skyFall());

      expect(sink.names, <String>[MapHostRegistry.missingHostEvent]);
      expect(sink.events.single.attributes['access'], 'submitIntent');
      expect(sink.events.single.attributes['origin'], 'discovery');
      expect(sink.events.single.attributes['rank'], '3');
    });

    test('bleibt der Kamerastrom still, ohne zu melden', () {
      // Der einzige Zugriff, bei dem nichts verloren geht: das Abonnement
      // bleibt gültig. Ein Ereignis dafür wäre der Normalfall jedes
      // Bildschirmaufbaus und damit Rauschen.
      final StreamSubscription<MapCameraView> subscription = registry
          .cameraChanges
          .listen((_) {});
      addTearDown(subscription.cancel);

      expect(sink.events, isEmpty);
    });
  });

  group('Mit eingeklinktem Host', () {
    setUp(() => registry.attach(host));

    test('reicht die Registry Absichten durch, ohne zu melden', () {
      final MapCameraOneShot intent = skyFall();
      registry.submitIntent(intent);

      expect(host.submitted, <MapCameraIntent>[intent]);
      expect(sink.events, isEmpty);
    });

    test('liefert sie die Kamera des Hosts', () {
      host.moveTo(viewAt(munich));

      expect(registry.camera, viewAt(munich));
      expect(sink.events, isEmpty);
    });
  });

  group('Ausklinken', () {
    test('meldet den Host ab und fällt auf die Meldung zurück', () {
      registry.attach(host);

      expect(registry.detach(host), isTrue);

      registry.submitIntent(skyFall());
      expect(host.submitted, isEmpty);
      expect(sink.names, <String>[MapHostRegistry.missingHostEvent]);
    });

    test('durch einen fremden Host tut nichts', () async {
      // **Die Lehre aus Schritt 11.** Beim Bildschirmwechsel meldet sich die
      // neue Fläche an, bevor die alte entsorgt ist. Ohne Identitätsprüfung
      // räumt das späte `dispose` der alten die frische Anmeldung weg, und die
      // Karte ist danach still tot.
      final FakeMapHost stale = FakeMapHost();
      addTearDown(stale.close);
      registry.attach(host);

      expect(registry.detach(stale), isFalse);

      final MapCameraOneShot intent = skyFall();
      registry.submitIntent(intent);
      expect(host.submitted, <MapCameraIntent>[intent]);
      expect(sink.events, isEmpty);
    });
  });

  group('Der Kamerastrom', () {
    test('überlebt einen Wechsel des Hosts', () async {
      // Der Strom gehört der Registry und nicht dem Host. Ein Feature, das
      // direkt am Host abonniert hätte, hielte nach dem Wechsel ein totes
      // Abonnement, und zwar ohne Fehler: es wäre einfach still.
      final List<MapCameraView> seen = <MapCameraView>[];
      final StreamSubscription<MapCameraView> subscription = registry
          .cameraChanges
          .listen(seen.add);
      addTearDown(subscription.cancel);

      registry.attach(host);
      host.moveTo(viewAt(munich));
      await pumpEventQueue();

      registry.detach(host);
      final FakeMapHost second = FakeMapHost();
      addTearDown(second.close);
      registry.attach(second);
      second.moveTo(viewAt(rome));
      await pumpEventQueue();

      expect(seen, <MapCameraView>[viewAt(munich), viewAt(rome)]);
    });

    test('meldet nach dem Ausklinken nichts mehr vom alten Host', () async {
      final List<MapCameraView> seen = <MapCameraView>[];
      final StreamSubscription<MapCameraView> subscription = registry
          .cameraChanges
          .listen(seen.add);
      addTearDown(subscription.cancel);

      registry.attach(host);
      registry.detach(host);
      host.moveTo(viewAt(rome));
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });

  group('Die beiden Provider', () {
    test('liefern dasselbe Objekt', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        identical(
          container.read(mapHostProvider),
          container.read(mapHostRegistryProvider),
        ),
        isTrue,
      );
    });

    test('benutzen die Diagnose-Senke aus dem Container', () {
      final ProviderContainer container = ProviderContainer(
        // Ohne Typangabe: `Override` ist aus `flutter_riverpod 3.4.2` nicht
        // exportiert, siehe Protokoll zu Schritt 9.
        overrides: [diagnosticSinkProvider.overrideWithValue(sink)],
      );
      addTearDown(container.dispose);

      container.read(mapHostProvider).submitIntent(skyFall());

      expect(sink.names, <String>[MapHostRegistry.missingHostEvent]);
    });

    // **Was hier bewusst nicht als Test steht, und warum.**
    //
    // „Über `mapHostProvider` ist kein `attach` erreichbar" ist eine Aussage
    // über die **Übersetzung** und nicht über die Laufzeit:
    // `container.read(mapHostProvider).attach(...)` übersetzt nicht, weil
    // `MapHost` die Methode nicht hat. Ein Test kann das nicht ausdrücken, denn
    // eine Testdatei, die nicht übersetzt, läuft überhaupt nicht.
    //
    // Zur Laufzeit prüfbar wäre nur `isNot(isA<MapHostRegistry>())`, und das
    // ist **falsch**: es ist dasselbe Objekt. Ein `isA<Provider<MapHost>>()`
    // misst ebenfalls nichts, weil Darts Generics kovariant sind und
    // `Provider<MapHostRegistry>` deshalb auch dazu passte.
    //
    // Nachgewiesen wurde es stattdessen mit einer Wegwerf-Datei unter `lib/`,
    // die `attach` über `mapHostProvider` aufruft. Gemessen, nicht vermutet:
    // `dart analyze` meldet `The method 'attach' isn't defined for the type
    // 'MapHost'` und bricht mit **Exit-Code 3** ab. Die Probe steht im Bericht
    // zu Schritt 12 und nicht hier, weil ein Test, der nichts misst,
    // schlechter ist als keiner.
  });

  group('Überlagerungen', () {
    test('ohne Host gehen Bilder und Überlagerungen nicht verloren', () async {
      // **Der belegte Startablauf, nicht ein gedachter.**
      // `MapPage.didChangeDependencies` läuft, bevor die Kartenfläche als Kind
      // gebaut ist, und erst deren `initState` klinkt den Host ein. Ohne diesen
      // Zwischenspeicher wären die zwölf Ballonbilder in genau diesem Fenster
      // weg, und der Symbol-Layer zeichnete später **nichts**, ohne Fehler.
      final MapHostRegistry registry = MapHostRegistry(diagnostics: sink);
      addTearDown(registry.dispose);

      registry
        ..registerOverlayImages(<MapOverlayImage>[imageFor('a')])
        ..setOverlay(overlayNamed('discovery.facts'))
        ..attach(host);

      expect(host.registeredImages.map((image) => image.styleId), <String>[
        'a',
      ]);
      expect(host.overlays.map((overlay) => overlay.id), <String>[
        'discovery.facts',
      ]);
      await host.close();
    });

    test('nichts davon meldet einen fehlenden Host', () {
      // Anders als bei einer Absicht: die verfällt, ein Bild wartet. Ein
      // Ereignis, das im Normalbetrieb jedes Startvorgangs feuert, liest nach
      // der dritten Woche niemand mehr.
      final MapHostRegistry registry = MapHostRegistry(diagnostics: sink);
      addTearDown(registry.dispose);

      registry
        ..registerOverlayImages(<MapOverlayImage>[imageFor('a')])
        ..setOverlay(overlayNamed('discovery.facts'))
        ..removeOverlay('discovery.facts');

      expect(sink.events, isEmpty);
    });

    test(
      'beim Einklinken kommen erst die Bilder, dann die Überlagerung',
      () async {
        final MapHostRegistry registry = MapHostRegistry(diagnostics: sink);
        addTearDown(registry.dispose);

        registry
          ..setOverlay(overlayNamed('discovery.facts'))
          ..registerOverlayImages(<MapOverlayImage>[imageFor('a')])
          ..attach(host);

        // Gesetzt wurde die Überlagerung zuerst, weitergereicht wird sie zuletzt:
        // ein Symbol-Layer ohne sein Bild zeichnet nichts.
        expect(host.registeredImages, isNotEmpty);
        expect(host.overlays, isNotEmpty);
        expect(host.order, <String>['images', 'overlay']);
        await host.close();
      },
    );

    test('eine entfernte Überlagerung wird nicht nachgereicht', () async {
      final MapHostRegistry registry = MapHostRegistry(diagnostics: sink);
      addTearDown(registry.dispose);

      registry
        ..setOverlay(overlayNamed('discovery.facts'))
        ..removeOverlay('discovery.facts')
        ..attach(host);

      expect(host.overlays, isEmpty);
      await host.close();
    });

    test('ein zweiter Host bekommt denselben Stand', () async {
      // Der Grund, warum die Registry das überhaupt aufhebt: sie überlebt den
      // Wechsel des Hosts, so wie der Kamerastrom es tut.
      final MapHostRegistry registry = MapHostRegistry(diagnostics: sink);
      addTearDown(registry.dispose);
      final FakeMapHost second = FakeMapHost();

      registry
        ..registerOverlayImages(<MapOverlayImage>[imageFor('a')])
        ..setOverlay(overlayNamed('discovery.facts'))
        ..attach(host)
        ..attach(second);

      expect(second.registeredImages, hasLength(1));
      expect(second.overlays, hasLength(1));
      await host.close();
      await second.close();
    });
  });
}
