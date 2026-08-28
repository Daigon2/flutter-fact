import 'dart:async';

import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);
const MapPosition rome = MapPosition(latitude: 41.896, longitude: 12.4822);

/// Ein Doppelgänger des Karten-Hosts, ohne Karte und ohne Flutter.
///
/// `implements` und nicht `extends`: [MapHost] ist eine
/// `abstract interface class`, ein `extends` wäre ein Übersetzungsfehler.
/// Genau dafür ist der Vertrag so deklariert.
class FakeMapHost implements MapHost {
  final StreamController<MapCameraView> _controller =
      StreamController<MapCameraView>.broadcast();

  /// Alles, was das Feature abgegeben hat, in der Reihenfolge des Eingangs.
  final List<MapCameraIntent> submitted = <MapCameraIntent>[];

  MapCameraView? _camera;

  @override
  MapCameraView? get camera => _camera;

  @override
  Stream<MapCameraView> get cameraChanges => _controller.stream;

  @override
  void submitIntent(MapCameraIntent intent) => submitted.add(intent);

  /// Tut so, als hätte sich die Karte bewegt.
  void moveTo(MapCameraView view) {
    _camera = view;
    _controller.add(view);
  }

  Future<void> close() => _controller.close();
}

MapCameraView viewAt(MapPosition center) =>
    MapCameraView(center: center, zoom: 15, bearing: 0, pitch: 0);

void main() {
  late FakeMapHost host;

  setUp(() => host = FakeMapHost());
  tearDown(() async => host.close());

  test('ohne Karte gibt es keine Kamera', () {
    // `null` ist der Normalfall beim Start und kein Fehler.
    expect(host.camera, isNull);
  });

  test('nach der ersten Bewegung steht die Kamera', () {
    host.moveTo(viewAt(munich));

    expect(host.camera, viewAt(munich));
  });

  test('der Strom meldet jede Bewegung in ihrer Reihenfolge', () async {
    // Der Aufrufer dafür existiert: `map_page.dart:45-52` zeigt den
    // Stadtnamen aus der Kartenmitte, `detectCity` läuft über zwölf Städte
    // (`screen-map.jsx:310-322`). Ohne diesen Strom hinge die
    // Mehrstädtigkeit in der Luft.
    final Future<List<MapCameraView>> seen = host.cameraChanges
        .take(2)
        .toList();

    host.moveTo(viewAt(munich));
    host.moveTo(viewAt(rome));

    expect(await seen, <MapCameraView>[viewAt(munich), viewAt(rome)]);
  });

  test('eine abgegebene Absicht erreicht den Host unverändert', () {
    const MapCameraOneShot skyFall = MapCameraOneShot(
      change: MapCameraChange(
        center: munich,
        zoom: 16.5,
        pitch: 58,
        bearing: 0,
      ),
      motion: MapCameraAnimated(Duration(milliseconds: 1200)),
      origin: MapCameraIntentOrigin.discovery,
    );

    host.submitIntent(skyFall);

    expect(host.submitted, <MapCameraIntent>[skyFall]);
  });

  test('eine Absicht darf abgegeben werden, bevor eine Karte steht', () {
    // Was der Host dann damit tut, ist **offen** und gehört nicht in diesen
    // Vertrag: fallen lassen, die letzte aufheben oder alle aufheben. Der
    // Vertrag sagt nur, dass der Aufruf zulässig ist, und dieser Test hält
    // fest, dass das keine Nachlässigkeit ist. Der Fall tritt in Schritt 12
    // sofort auf, weil der Sky-Fall am ersten GPS-Fix hängt und nicht am
    // Kartenwidget (`screen-map.jsx:1745`).
    expect(host.camera, isNull);

    host.submitIntent(
      const MapCameraFollow(
        change: MapCameraChange(center: munich),
        motion: MapCameraAnimated(Duration(milliseconds: 900)),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: false,
      ),
    );

    expect(host.submitted, hasLength(1));
  });
}
