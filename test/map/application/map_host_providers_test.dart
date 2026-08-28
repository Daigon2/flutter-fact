import 'dart:async';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
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
}
