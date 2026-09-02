import 'dart:async';

import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
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

  /// Die Bilder, die angemeldet wurden, in der Reihenfolge des Eingangs.
  final List<MapOverlayImage> registeredImages = <MapOverlayImage>[];

  /// Die Überlagerungen, die gesetzt wurden, in der Reihenfolge des Eingangs.
  final List<MapOverlay> overlays = <MapOverlay>[];

  /// Die Kennungen, die entfernt wurden.
  final List<String> removedOverlays = <String>[];

  @override
  void registerOverlayImages(List<MapOverlayImage> images) =>
      registeredImages.addAll(images);

  @override
  void setOverlay(MapOverlay overlay) => overlays.add(overlay);

  @override
  void removeOverlay(String overlayId) => removedOverlays.add(overlayId);

  /// Die Anfragen an die Projektion, in der Reihenfolge des Eingangs.
  final List<List<MapPosition>> projected = <List<MapPosition>>[];

  /// Was die Projektion zurückgeben soll. `null` heißt „nichts sichtbar".
  List<MapScreenPoint?>? projectionAnswer;

  @override
  Future<List<MapScreenPoint?>> projectToScreen(List<MapPosition> positions) {
    projected.add(positions);
    return Future<List<MapScreenPoint?>>.value(
      projectionAnswer ?? List<MapScreenPoint?>.filled(positions.length, null),
    );
  }

  /// Tut so, als hätte sich die Karte bewegt.
  void moveTo(MapCameraView view) {
    _camera = view;
    _controller.add(view);
  }

  MapViewport? _viewport;

  @override
  MapViewport? get viewport => _viewport;

  /// Tut so, als hätte `MapSurface` eine Größe gemeldet.
  void measure(MapViewport size) => _viewport = size;

  final StreamController<MapOverlayPointTap> _pointTaps =
      StreamController<MapOverlayPointTap>.broadcast();

  final StreamController<MapOverlayGroupTap> _groupTaps =
      StreamController<MapOverlayGroupTap>.broadcast();

  @override
  Stream<MapOverlayGroupTap> get groupTaps => _groupTaps.stream;

  @override
  Stream<MapOverlayPointTap> get pointTaps => _pointTaps.stream;

  /// Tut so, als hätte das SDK einen Tipp auf eine Gruppe gemeldet.
  void tapGroup(MapOverlayGroupTap tap) => _groupTaps.add(tap);

  void tapPoint(MapOverlayPointTap tap) => _pointTaps.add(tap);

  Future<void> close() => Future.wait(<Future<void>>[
    _controller.close(),
    _groupTaps.close(),
    _pointTaps.close(),
  ]);
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
        kind: MapCameraFollowKind.userPosition,
        change: MapCameraChange(center: munich),
        motion: MapCameraAnimated(Duration(milliseconds: 900)),
        origin: MapCameraIntentOrigin.discovery,
        yieldsToUserGesture: false,
      ),
    );

    expect(host.submitted, hasLength(1));
  });

  test('ohne gemessene Fläche ist die Kartenfläche null', () {
    // `null` ist hier der Normalfall beim Start, genau wie bei `camera`.
    expect(host.viewport, isNull);
  });

  test('nach der Messung steht die Größe der Kartenfläche', () {
    const MapViewport size = MapViewport(
      widthInScreenPixels: 400,
      heightInScreenPixels: 800,
    );

    host.measure(size);

    expect(host.viewport, size);
  });

  test(
    'der Gruppen-Tipp-Strom meldet jeden Tipp in seiner Reihenfolge',
    () async {
      const MapOverlayGroupTap first = MapOverlayGroupTap(
        overlayId: 'discovery.facts',
        position: munich,
      );
      const MapOverlayGroupTap second = MapOverlayGroupTap(
        overlayId: 'discovery.facts',
        position: rome,
      );
      final Future<List<MapOverlayGroupTap>> seen = host.groupTaps
          .take(2)
          .toList();

      host.tapGroup(first);
      host.tapGroup(second);

      // Verglichen wird über `identical` und nicht über `==`: `==` gibt es für
      // [MapOverlayGroupTap] bewusst nicht, siehe dessen Kopfkommentar. Ein
      // `expect` mit `equals` prüfte hier über `identical` mit zusätzlichen
      // Schritten und würde eine zurückgegebene Objektgleichheit nicht von
      // einer stillschweigend eingeführten `==`-Methode unterscheiden.
      final List<MapOverlayGroupTap> taps = await seen;
      expect(identical(taps[0], first), isTrue);
      expect(identical(taps[1], second), isTrue);
    },
  );
}
