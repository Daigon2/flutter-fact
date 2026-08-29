import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_gate.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/presentation/map_auto_pitch.dart';
import 'package:fact_app/map/presentation/map_camera_driver.dart';
import 'package:fact_app/map/presentation/map_camera_host.dart';
import 'package:fact_app/map/presentation/map_overlay_driver.dart';
import 'package:fact_app/map/presentation/map_projection_driver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Die Buchführung des Karten-Hosts, **ohne Widget und ohne Karte**.
///
/// Hier liegt der Wert dieser Trennung: im Widget-Test entsteht nie ein
/// `MapLibreMapController` (`maplibre_map.dart:390-418` läuft ohne
/// Plattformkanal nicht), also wäre nichts von dem, was diese Datei prüft, an
/// einem Widget prüfbar. Die Uhr ist gestellt, das SDK ist gefälscht.
const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);

/// Meter je Grad Breite, unabhängig hergeleitet in `map_position_test.dart`.
const double metersPerDegreeLatitude = 111194.92664455873;

MapPosition northOf(MapPosition from, double meters) => MapPosition(
  latitude: from.latitude + meters / metersPerDegreeLatitude,
  longitude: from.longitude,
);

MapCameraView viewAt({
  MapPosition center = munich,
  double zoom = 15,
  double bearing = 0,
  double pitch = 58,
}) => MapCameraView(center: center, zoom: zoom, bearing: bearing, pitch: pitch);

/// Ein Aufruf, der beim gefälschten SDK angekommen ist.
class DriverCall {
  DriverCall(this.target, this.duration);

  final MapCameraView target;

  /// `null` bei einem Sprung ohne Animation.
  final Duration? duration;
}

/// Das SDK, so schmal wie die Naht [MapCameraDriver].
///
/// Jede Animation gibt ein [Completer] zurück, damit ein Test die Antwort des
/// SDK selbst bestimmt: **das ist die einzige Möglichkeit, `null` von `true`
/// und `false` zu unterscheiden**, und genau daran hängt das Verhalten auf
/// iOS.
class FakeCameraDriver implements MapCameraDriver {
  final List<DriverCall> calls = <DriverCall>[];
  final List<Completer<bool?>> pending = <Completer<bool?>>[];

  @override
  Future<bool?> animate(MapCameraView target, Duration duration) {
    calls.add(DriverCall(target, duration));
    final Completer<bool?> completer = Completer<bool?>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<bool?> jump(MapCameraView target) {
    calls.add(DriverCall(target, null));
    return Future<bool?>.value(true);
  }

  /// Beantwortet die zuletzt gestartete Animation.
  Future<void> answerLast(bool? result) async {
    pending.last.complete(result);
    // Der Host hängt seine Auswertung an das `Future`; ohne diesen Umlauf
    // wäre sie beim Prüfen noch nicht gelaufen.
    await pumpEventQueue();
  }
}

/// Eine Senke, die mitschreibt.
class RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);

  List<String> get names =>
      events.map((DiagnosticEvent event) => event.name).toList();
}

/// Eine Uhr, die nur vorwärts geht, wenn ein Test es sagt.
class TestClock {
  Duration now = Duration.zero;

  Duration call() => now;

  void advance(Duration by) => now += by;
}

MapCameraOneShot oneShot({
  MapCameraChange change = const MapCameraChange(zoom: 16.5),
  MapCameraMotion motion = const MapCameraAnimated(Duration(seconds: 1)),
  bool yieldsToRunningAnimation = false,
}) => MapCameraOneShot(
  change: change,
  motion: motion,
  origin: MapCameraIntentOrigin.discovery,
  yieldsToRunningAnimation: yieldsToRunningAnimation,
);

MapCameraFollow gpsFollow(MapPosition target) => MapCameraFollow(
  kind: MapCameraFollowKind.userPosition,
  change: MapCameraChange(center: target),
  motion: const MapCameraAnimated(Duration(milliseconds: 900)),
  origin: MapCameraIntentOrigin.discovery,
  yieldsToUserGesture: false,
  deadZoneMeters: MapCameraThresholds.followDeadZoneMeters,
  minPause: MapCameraThresholds.followMinPause,
);

MapCameraFollow bearingFollow(double bearing) => MapCameraFollow(
  kind: MapCameraFollowKind.compassBearing,
  change: MapCameraChange(bearing: bearing),
  motion: const MapCameraImmediate(),
  origin: MapCameraIntentOrigin.discovery,
  yieldsToUserGesture: true,
  bearingDeadZoneDegrees: MapCameraThresholds.bearingDeadZoneDegrees,
);

/// Der harte Reset am Kompass, `screen-map.jsx:3164-3170`.
MapCameraCommand hardReset() => const MapCameraCommand(
  change: MapCameraChange(center: munich, bearing: 0, pitch: 30, zoom: 15),
  motion: MapCameraImmediate(),
  origin: MapCameraIntentOrigin.discovery,
  releasesBearingLock: true,
  clearsFollowAnchor: true,
);

/// Eine Überlagerung, wie `features/discovery` sie auflegt.
const MapOverlay overlay = MapOverlay(
  id: 'discovery.facts',
  points: <MapOverlayPoint>[
    MapOverlayPoint(
      id: '4711',
      position: munich,
      styleId: 'fact.hist.uncollected',
      state: 'uncollected',
    ),
  ],
  grouping: MapOverlayGrouping(maxZoom: 15, radiusInScreenPixels: 70),
  minZoom: 11,
);

/// Ein Ballonbild, wie `features/discovery` es anmeldet.
final MapOverlayImage balloonImage = MapOverlayImage(
  styleId: 'fact.hist.uncollected',
  bytes: Uint8List.fromList(const <int>[137, 80, 78, 71]),
  pixelRatio: 1,
);

/// Die zweite Naht zum SDK, die jeden Aufruf in Reihenfolge mitschreibt.
///
/// Denselben Doppelgänger führt `map_overlay_host_test.dart`. Er steht hier
/// noch einmal und wird nicht geteilt: dort prüft er, **was** der
/// Überlagerungsteil baut, hier nur, **dass** dieses Objekt ihn überhaupt
/// erreicht.
class RecordingOverlayDriver implements MapOverlayDriver {
  final List<String> calls = <String>[];

  @override
  Future<void> addImage(String name, Uint8List bytes) async =>
      calls.add('addImage:$name');

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async =>
      calls.add('addSource:$sourceId');

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
  }) async => calls.add('addCircleLayer:$layerId');

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    double? minzoom,
    double? maxzoom,
    Object? filter,
  }) async => calls.add('addSymbolLayer:$layerId');

  @override
  Future<void> removeLayer(String layerId) async =>
      calls.add('removeLayer:$layerId');

  @override
  Future<void> removeSource(String sourceId) async =>
      calls.add('removeSource:$sourceId');
}

/// Die Projektionsnaht, so schmal wie [MapProjectionDriver].
///
/// Sie antwortet, was der Test ihr sagt, **auch Unsinn**: eine zu kurze Liste
/// und `NaN` sind genau die Ausfälle, gegen die der Host gebaut ist, und beide
/// wären auf einem Gerät nur mit Glück zu treffen.
class FakeProjectionDriver implements MapProjectionDriver {
  /// Die Anfragen, in der Reihenfolge des Eingangs.
  final List<List<LatLng>> requests = <List<LatLng>>[];

  /// Was zurückkommt. `null` heißt „so viele Punkte wie angefragt, alle 0".
  List<Point<num>>? answer;

  /// Wenn gesetzt, scheitert die Naht, statt zu antworten.
  Object? failure;

  @override
  Future<List<Point<num>>> toScreenLocationBatch(Iterable<LatLng> latLngs) {
    final List<LatLng> asked = latLngs.toList();
    requests.add(asked);
    final Object? thrown = failure;
    if (thrown != null) {
      return Future<List<Point<num>>>.error(thrown);
    }
    return Future<List<Point<num>>>.value(
      answer ??
          <Point<num>>[
            for (int i = 0; i < asked.length; i++) const Point<num>(0, 0),
          ],
    );
  }
}

void main() {
  late FakeCameraDriver driver;
  late RecordingSink sink;
  late TestClock clock;
  late MapCameraHost host;

  setUp(() {
    driver = FakeCameraDriver();
    sink = RecordingSink();
    clock = TestClock();
    host = MapCameraHost(diagnostics: sink, now: clock.call);
  });

  tearDown(() => host.dispose());

  void bind({MapCameraView? camera}) =>
      host.bindSurface(driver: driver, camera: camera ?? viewAt());

  group('Ohne Karte', () {
    test('gibt es keine Kamera', () {
      expect(host.camera, isNull);
    });

    test('wird eine Absicht fallen gelassen und gemeldet', () {
      // Der Vertrag in `map_host.dart` hielt diese Frage offen. Schritt 12
      // beantwortet sie mit „fallen lassen", und das darf nicht still
      // passieren.
      host.submitIntent(oneShot());

      expect(driver.calls, isEmpty);
      expect(sink.names, <String>[MapCameraHost.droppedEvent]);
      expect(sink.events.single.attributes['cause'], 'no_surface');
      expect(sink.events.single.attributes['origin'], 'discovery');
    });
  });

  group('Sobald die Karte steht', () {
    test('steht die Startkamera, ohne dass sich etwas bewegt hat', () {
      // `maplibre_gl` meldet ohne Bewegung nichts. Ohne den Startwert wäre
      // `camera` bis zur ersten Geste `null`, obwohl die Karte längst da ist.
      bind();

      expect(host.camera, viewAt());
    });

    test('meldet der Kamerastrom die Startkamera', () async {
      final Future<MapCameraView> first = host.cameraChanges.first;
      bind();

      expect(await first, viewAt());
    });

    test('füllt eine Teiländerung mit dem Ist-Zustand auf', () async {
      // `null` heißt „unverändert lassen", nicht „auf null setzen". Ohne das
      // zöge eine reine Neigungsänderung die Karte zusätzlich auf Zoom 0 und
      // Norden.
      bind(camera: viewAt(zoom: 16, bearing: 90, pitch: 0));
      host.submitIntent(oneShot(change: const MapCameraChange(pitch: 58)));

      final DriverCall call = driver.calls.single;
      expect(call.target.pitch, 58);
      expect(call.target.zoom, 16);
      expect(call.target.bearing, 90);
      expect(call.target.center, munich);
    });

    test('springt ohne Dauer, wenn die Absicht sofort wirkt', () {
      bind();
      host.submitIntent(
        oneShot(
          change: const MapCameraChange(bearing: 90),
          motion: const MapCameraImmediate(),
        ),
      );

      expect(driver.calls.single.duration, isNull);
    });
  });

  group('Der Animationszustand', () {
    test('steht nach dem Start auf Startzeit plus mitgegebener Dauer', () {
      bind();
      clock.advance(const Duration(seconds: 5));
      host.submitIntent(oneShot());

      expect(host.debugAnimationEndsAt, const Duration(seconds: 6));
    });

    test('bleibt stehen, wenn `animateCamera` `null` liefert', () async {
      // **Der iOS-Fall.** `animateCamera` liefert dort immer sofort `null`
      // (`controller.dart:409-416`). Wer das wie `false` behandelt, löscht den
      // Zustand im selben Atemzug, in dem er ihn gesetzt hat, und jede
      // Dauerabsicht liefe danach mitten in die laufende Bewegung.
      bind();
      host.submitIntent(oneShot());
      await driver.answerLast(null);

      expect(host.debugAnimationEndsAt, const Duration(seconds: 1));

      // Und die Folge, um die es wirklich geht:
      host.submitIntent(gpsFollow(northOf(munich, 100)));
      expect(driver.calls, hasLength(1));
      expect(sink.events.last.attributes['reason'], 'runningAnimation');
    });

    test('ist gelöscht, wenn `animateCamera` `true` liefert', () async {
      bind();
      host.submitIntent(oneShot());
      await driver.answerLast(true);

      expect(host.debugAnimationEndsAt, isNull);
    });

    test('ist gelöscht, wenn `animateCamera` `false` liefert', () async {
      // `false` heißt „abgebrochen", also läuft ebenfalls nichts mehr.
      bind();
      host.submitIntent(oneShot());
      await driver.answerLast(false);

      expect(host.debugAnimationEndsAt, isNull);
    });

    test('ist gelöscht, sobald das SDK Stillstand meldet', () {
      bind();
      host.submitIntent(oneShot());
      host.handleCameraIdle();

      expect(host.debugAnimationEndsAt, isNull);
    });

    test('ist gelöscht, wenn die mitgegebene Dauer um ist', () {
      // Geprüft mit einer sofort wirkenden Dauerabsicht, damit nicht gleich
      // eine neue Animation den Zustand wieder füllt und der Test das für
      // Aufräumen hält.
      bind(camera: viewAt(bearing: 0));
      host.submitIntent(oneShot());
      clock.advance(const Duration(seconds: 2));
      host.submitIntent(bearingFollow(90));

      expect(host.debugAnimationEndsAt, isNull);
      expect(driver.calls, hasLength(2));
    });

    test('ist gelöscht, wenn eine unerklärte Bewegung eintrifft', () {
      bind();
      host.submitIntent(oneShot());
      // Nach dem Steuerfenster: was jetzt kommt, kam nicht vom Host.
      clock.advance(const Duration(seconds: 3));
      host.handleCameraMove(viewAt(zoom: 12));

      expect(host.debugAnimationEndsAt, isNull);
    });

    test(
      'eine späte Antwort löscht nicht den Zustand der nächsten Animation',
      () async {
        // Ohne die Marke am Animationszustand würde die Antwort einer längst
        // überschriebenen Animation die aktuelle für beendet erklären.
        bind();
        host.submitIntent(oneShot());
        final Completer<bool?> first = driver.pending.first;
        clock.advance(const Duration(milliseconds: 100));
        host.submitIntent(oneShot());

        first.complete(false);
        await pumpEventQueue();

        expect(host.debugAnimationEndsAt, const Duration(milliseconds: 1100));
      },
    );
  });

  group('Unerklärte Bewegung', () {
    test('macht aus einer Kamerabewegung eine Nutzergeste', () {
      bind();
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(zoom: 12));

      expect(host.debugUserIsGesturing, isTrue);
      expect(host.debugLastUnexplainedMoveAt, const Duration(seconds: 4));
    });

    test('gilt nicht für die eigene Bewegung des Hosts', () {
      // Innerhalb der eigenen Animation ist jede Rückmeldung erklärt. Sonst
      // hielte der Host sich selbst für den Nutzer.
      bind();
      host.submitIntent(oneShot());
      clock.advance(const Duration(milliseconds: 200));
      host.handleCameraMove(viewAt(zoom: 15.5));

      expect(host.debugUserIsGesturing, isFalse);
      expect(host.debugLastUnexplainedMoveAt, isNull);
    });

    test('gilt auch im Nachlauf nach einem Sprung nicht', () {
      // Ein `jumpTo` hat keine Dauer, seine Rückmeldung kommt trotzdem erst
      // ein paar Bilder später. Ohne dieses Fenster hielte der Host seine
      // eigene Drehung für die des Nutzers.
      bind();
      host.submitIntent(
        oneShot(
          change: const MapCameraChange(bearing: 90),
          motion: const MapCameraImmediate(),
        ),
      );
      clock.advance(
        MapCameraHost.steeringGrace - const Duration(milliseconds: 1),
      );
      host.handleCameraMove(viewAt(bearing: 90));

      expect(host.debugUserIsGesturing, isFalse);
      expect(host.debugBearingLocked, isFalse);
    });

    test('gilt auch im Nachlauf nach einer Animation', () {
      // Der Nachlauf hängt an **jedem** eigenen Aufruf und nicht nur am
      // Sprung: auch nach dem geplanten Ende einer Animation trifft die
      // letzte Rückmeldung des SDK erst ein paar Bilder später ein. Ohne
      // dieses Stück hielte der Host sie für den Nutzer und löschte im selben
      // Moment jede Dauerabsicht aus.
      bind();
      host.submitIntent(oneShot());
      clock.advance(
        const Duration(seconds: 1) + const Duration(milliseconds: 100),
      );
      host.handleCameraMove(viewAt(zoom: 16.5));

      expect(host.debugUserIsGesturing, isFalse);
      expect(host.debugLastUnexplainedMoveAt, isNull);
    });

    test('ist eine Viertelsekunde nach einem Sprung vorbei', () {
      // **Absichtlich eine feste Zahl statt `steeringGrace`.** Ein Test, der
      // die Konstante selbst einsetzt, wandert mit ihr mit und bindet sie nach
      // oben überhaupt nicht: `steeringGrace` auf eine Stunde zu setzen
      // überlebte ihn. Gebunden wird hier die Größenordnung, nicht der
      // Schätzwert selbst, denn ein Fenster, das eine Viertelsekunde übersteht,
      // verschluckt das Schieben des Nutzers unmittelbar nach jeder eigenen
      // Kamerabewegung.
      bind();
      host.submitIntent(
        oneShot(
          change: const MapCameraChange(zoom: 16),
          motion: const MapCameraImmediate(),
        ),
      );
      clock.advance(const Duration(milliseconds: 250));
      host.handleCameraMove(viewAt(zoom: 16));

      expect(host.debugUserIsGesturing, isTrue);
      expect(
        host.debugLastUnexplainedMoveAt,
        const Duration(milliseconds: 250),
      );
    });

    test('merkt sich jede unerklärte Bewegung, nicht nur die erste', () {
      // Lesart B von `manualMoveGrace` misst gegen diesen Zeitpunkt. Bliebe er
      // auf der allerersten Nutzerbewegung stehen, ginge der Umschalter beim
      // ersten Versuch kaputt, und zwar in die gefährliche Richtung: die Karte
      // folgte wieder, während der Nutzer noch schiebt.
      bind();
      clock.advance(const Duration(seconds: 1));
      host.handleCameraMove(viewAt(zoom: 12));
      clock.advance(const Duration(seconds: 1));
      host.handleCameraMove(viewAt(zoom: 13));

      expect(host.debugLastUnexplainedMoveAt, const Duration(seconds: 2));
    });

    test('endet erst mit dem Stillstand', () {
      // Das SDK hat kein `touchend`. `onCameraIdle` ist das einzige Ende, das
      // es hergibt.
      bind();
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(zoom: 12));
      expect(host.debugUserIsGesturing, isTrue);

      host.handleCameraIdle();
      expect(host.debugUserIsGesturing, isFalse);
    });
  });

  group('Das Einrasten der Blickrichtung', () {
    test('rastet ein, wenn der Nutzer selbst dreht', () {
      bind(camera: viewAt(bearing: 0));
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(bearing: 30));

      expect(host.debugBearingLocked, isTrue);
    });

    test('rastet bei Rundungszittern nicht ein', () {
      // `manualBearingNoiseDegrees` ist 0,25 und ausdrücklich nicht die
      // Totzone des Kompass-Folgens.
      bind(camera: viewAt(bearing: 0));
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(bearing: 0.1));

      expect(host.debugBearingLocked, isFalse);
    });

    test('hält danach jede Absicht auf, die die Blickrichtung anfasst', () {
      bind(camera: viewAt(bearing: 0));
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(bearing: 30));
      host.handleCameraIdle();

      host.submitIntent(bearingFollow(90));

      expect(driver.calls, isEmpty);
      expect(sink.events.last.attributes['reason'], 'bearingLocked');
    });

    test('rastet auch ein, während der Kompass die Karte dreht', () {
      // **Der Fall, für den es Vorrangregel 2 gibt**, und der einzige echte
      // Verhaltensfehler dieses Schritts: der Nutzer übernimmt die Karte,
      // *während* das Blickrichtungs-Folgen sie dreht.
      //
      // Das Folgen arbeitet mit `MapCameraImmediate`, und jeder Aufruf schob
      // das Steuerfenster um weitere 200 ms nach vorn. Bei einem Tick alle
      // 100 ms war es dauerhaft offen, `handleCameraMove` kehrte vor der
      // Frage nach der Nutzerdrehung zurück, und es rastete **nie** ein.
      bind(camera: viewAt(bearing: 0));
      for (int tick = 1; tick <= 5; tick++) {
        clock.advance(const Duration(milliseconds: 100));
        host.submitIntent(bearingFollow(tick * 10));
        // Die Rückmeldung des SDK zum eigenen Aufruf.
        host.handleCameraMove(viewAt(bearing: tick * 10));
      }
      expect(driver.calls, hasLength(5), reason: 'jeder Tick ist ausgeführt');
      expect(
        host.debugBearingLocked,
        isFalse,
        reason: 'die eigenen Ticks sind keine Nutzerdrehung',
      );

      // 60 ms nach dem letzten Tick, also mitten im Steuerfenster, dreht der
      // Nutzer mit zwei Fingern um 45 Grad.
      clock.advance(const Duration(milliseconds: 60));
      host.handleCameraMove(viewAt(bearing: 95));

      expect(host.debugBearingLocked, isTrue);
      expect(host.debugUserIsGesturing, isTrue);
    });

    test('löst sich nur durch einen Befehl, der es ausdrücklich sagt', () {
      bind(camera: viewAt(bearing: 0));
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(bearing: 30));
      expect(host.debugBearingLocked, isTrue);

      host.submitIntent(hardReset());

      expect(host.debugBearingLocked, isFalse);
    });
  });

  group('Der Anker der Strecken-Totzone', () {
    test('entsteht mit der ersten ausgeführten Dauerabsicht', () {
      bind();
      host.submitIntent(gpsFollow(northOf(munich, 100)));

      expect(
        host.debugFollowAnchor(MapCameraFollowKind.userPosition),
        northOf(munich, 100),
      );
    });

    test('bremst den nächsten Fix innerhalb der Totzone', () {
      bind();
      host.submitIntent(gpsFollow(northOf(munich, 100)));
      clock.advance(const Duration(seconds: 5));
      host.handleCameraIdle();
      host.submitIntent(gpsFollow(northOf(munich, 105)));

      expect(driver.calls, hasLength(1));
      expect(sink.events.last.attributes['reason'], 'distanceDeadZone');
    });

    test('wird von einem Befehl mit `clearsFollowAnchor` geleert', () {
      // `screen-map.jsx:3165` setzt `lastCameraPosRef.current = null`. Ohne
      // das unterdrückte die Totzone den nächsten Fix, obwohl die Quelle ihn
      // ausführt.
      bind();
      host.submitIntent(gpsFollow(northOf(munich, 100)));
      host.submitIntent(hardReset());

      expect(host.debugFollowAnchor(MapCameraFollowKind.userPosition), isNull);
    });

    test('der Zeitpunkt bleibt dabei stehen', () {
      // Der lange Druck löscht in `:3165` nur den Ort, `lastCameraAtRef` fasst
      // er nicht an. Beweis: gleich danach greift die Mindestpause und nicht
      // die Streckenprüfung.
      bind();
      host.submitIntent(gpsFollow(northOf(munich, 100)));
      host.submitIntent(hardReset());
      clock.advance(const Duration(milliseconds: 300));
      host.handleCameraIdle();
      host.submitIntent(gpsFollow(northOf(munich, 400)));

      expect(sink.events.last.attributes['reason'], 'minPause');
    });
  });

  group('Die Karenzzeit nach einer Nutzerbewegung', () {
    /// Ein Host mit Lesart B, siehe `MapCameraThresholds.manualMoveGrace`.
    ///
    /// Der Standard ist Lesart A und die Bedingung feuert dort nie. Geprüft
    /// wird hier der Umschalter, den das Gate schon für beide Lesarten
    /// zusichert: **der Host, der die Lage füllt, war es nicht.**
    MapCameraHost gracedHost() {
      final MapCameraHost graced = MapCameraHost(
        diagnostics: sink,
        thresholds: const MapCameraThresholds(
          manualMoveGrace: Duration(seconds: 2),
        ),
        now: clock.call,
      );
      addTearDown(graced.dispose);
      graced.bindSurface(driver: driver, camera: viewAt());
      return graced;
    }

    test('läuft ab der letzten Bewegung und nicht ab der ersten', () {
      final MapCameraHost graced = gracedHost();
      clock.advance(const Duration(seconds: 1));
      graced.handleCameraMove(viewAt(zoom: 12));
      clock.advance(const Duration(seconds: 1));
      graced.handleCameraMove(viewAt(zoom: 13));

      // 1,5 s nach der zweiten Bewegung, aber 2,5 s nach der ersten: gegen die
      // erste gemessen wäre die Karenzzeit schon vorbei.
      clock.advance(const Duration(milliseconds: 1500));
      graced.submitIntent(gpsFollow(northOf(munich, 100)));

      expect(driver.calls, isEmpty);
      expect(sink.events.last.attributes['reason'], 'manualMoveGrace');
    });

    test('ist vorbei, wenn seit der letzten Bewegung genug Zeit vergeht', () {
      // Das Gegenstück: ohne diesen Test wäre auch „unterdrückt für immer"
      // grün.
      final MapCameraHost graced = gracedHost();
      clock.advance(const Duration(seconds: 1));
      graced.handleCameraMove(viewAt(zoom: 12));
      clock.advance(const Duration(milliseconds: 2001));
      graced.submitIntent(gpsFollow(northOf(munich, 100)));

      expect(driver.calls, hasLength(1));
    });
  });

  group('Zustand je Dauerabsicht', () {
    test('die beiden Dauerabsichten bremsen sich nicht gegenseitig', () {
      // Beide sind `MapCameraIntentOrigin.discovery`. Nach der Herkunft
      // geschlüsselt teilten sie sich einen Platz, und die Mindestpause des
      // GPS-Folgens legte das Kompass-Folgen still.
      bind(camera: viewAt(bearing: 0));
      host.submitIntent(gpsFollow(northOf(munich, 100)));
      host.handleCameraIdle();
      host.submitIntent(bearingFollow(90));

      expect(driver.calls, hasLength(2));
      expect(driver.calls.last.target.bearing, 90);
    });

    test('jede Sorte führt ihren eigenen Zeitpunkt', () {
      bind(camera: viewAt(bearing: 0));
      host.submitIntent(bearingFollow(90));
      host.handleCameraIdle();
      clock.advance(const Duration(milliseconds: 100));
      // Für das GPS-Folgen ist das die erste Ausführung überhaupt, es gibt
      // also keine Pause, die es bremsen könnte.
      host.submitIntent(gpsFollow(northOf(munich, 100)));

      expect(driver.calls, hasLength(2));
    });

    test('eine Dauerabsicht ohne Mittelpunkt erfindet keinen Anker', () {
      // Das Kompass-Folgen hat in der Quelle gar keinen Anker. Einen zu
      // erfinden hieße, seiner Totzone eine Messung unterzuschieben.
      bind(camera: viewAt(bearing: 0));
      host.submitIntent(bearingFollow(90));

      expect(
        host.debugFollowAnchor(MapCameraFollowKind.compassBearing),
        isNull,
      );
    });
  });

  group('Die Auto-Neigung', () {
    test('läuft, wenn der Zoom sich geändert hat und still steht', () {
      bind(camera: viewAt(zoom: 11, pitch: 0));
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(zoom: 16, pitch: 0));
      host.handleCameraIdle();

      final DriverCall call = driver.calls.single;
      expect(call.target.pitch, 58);
      expect(call.duration, const Duration(milliseconds: 300));
      // Und sie kommt vom Host, nicht von einem Feature.
      expect(host.camera!.zoom, 16);
    });

    test('läuft nicht, wenn der Zoom gleich geblieben ist', () {
      // Das Gegenstück zu `zoomend`: `maplibre_gl` hat kein solches Ereignis,
      // und ein Schwenk darf die Neigung nicht zurückziehen, die der Nutzer
      // von Hand gesetzt hat.
      bind(camera: viewAt(zoom: 16, pitch: 0));
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(zoom: 16, pitch: 10));
      host.handleCameraIdle();

      expect(driver.calls, isEmpty);
    });

    test('läuft nicht, wenn die Neigung schon nah genug ist', () {
      bind(camera: viewAt(zoom: 11, pitch: 56));
      clock.advance(const Duration(seconds: 4));
      host.handleCameraMove(viewAt(zoom: 15, pitch: 56));
      host.handleCameraIdle();

      expect(driver.calls, isEmpty);
    });

    test('zieht die Kamera nach dem harten Reset wieder hoch', () {
      // **Das sieht beim Lesen wie ein Fehler aus und ist Parität.** Der harte
      // Reset setzt `pitch: 30` (`screen-map.jsx:3168`), und der nächste
      // Stillstand zieht die Neigung sofort auf 58. Die Quelle tut dasselbe:
      // ein `jumpTo` mit geändertem Zoom feuert `zoomend`, und `isEasing()`
      // ist dabei falsch, der Wächter in `:1761` greift also nicht. Ohne
      // diesen Test „behebt" der nächste Leser die Parität weg.
      bind(camera: viewAt(zoom: 12, pitch: 20));
      host.submitIntent(hardReset());
      expect(driver.calls.single.target.pitch, 30);
      expect(driver.calls.single.target.zoom, 15);

      host.handleCameraMove(viewAt(zoom: 15, pitch: 30));
      host.handleCameraIdle();

      expect(driver.calls, hasLength(2));
      expect(driver.calls.last.target.pitch, 58);
      expect(driver.calls.last.target.zoom, 15);
    });

    test('weicht einer laufenden Animation', () {
      // Der Wächter `if (map.isEasing()) return;` aus `:1761`, hier über das
      // Gate statt über einen Sonderfall im Host.
      //
      // **Kein Integrationsnachweis, und das ist wichtig:** die Absicht wird
      // hier von Hand eingereicht. Im Produktivpfad entsteht sie in
      // `handleCameraIdle`, und das **löscht den Animationszustand
      // unbedingt**, bevor es sie abgibt. `yieldsToRunningAnimation` ist dort
      // also wirkungslos; gemessen wird eine Lage, die die Karte selbst nie
      // erzeugt. Wirksam wird der Wächter erst, wenn eine Absicht aus einer
      // anderen Quelle als dem Stillstand kommt.
      bind(camera: viewAt(zoom: 16, pitch: 0));
      host.submitIntent(oneShot());
      host.submitIntent(mapAutoPitchIntentOrFail(viewAt(zoom: 16, pitch: 0)));

      expect(driver.calls, hasLength(1));
      expect(sink.events.last.name, MapHostRegistry.suppressedEvent);
      expect(sink.events.last.attributes['reason'], 'runningAnimation');
      expect(sink.events.last.attributes['origin'], 'mapHost');
    });
  });

  group('Die Durchreichungen an den Überlagerungsteil', () {
    // **Hier lag die teuerste Lücke der Review zu Schritt 15.**
    // `MapOverlayHost` war vorbildlich geprüft, `MapHostRegistry` auch, der
    // Bildschirm gegen einen Doppelgänger. Ungeprüft war genau das Stück
    // dazwischen, das in der App wirklich läuft: dieses Objekt ist die einzige
    // Produktivfassung von `MapHost`. Jede der Durchreichungen fällt
    // lautlos aus, und die erste kostet **jeden Fakt auf der Karte**.
    late RecordingOverlayDriver overlays;

    setUp(() => overlays = RecordingOverlayDriver());

    /// Bindet Kamera **und** Überlagerungsnaht, wie `MapSurface` es tut.
    void bindBoth() =>
        host.bindSurface(driver: driver, camera: viewAt(), overlays: overlays);

    test('setOverlay legt die Überlagerung wirklich an', () async {
      // Ohne diese Durchreichung erscheint **kein einziger Fakt**, ohne Fehler
      // und ohne Meldung.
      bindBoth();
      host.setOverlay(overlay);
      await host.debugOverlays.debugSettled;

      expect(overlays.calls, contains('addSource:discovery.facts.source'));
      expect(overlays.calls, contains('addSymbolLayer:discovery.facts.points'));
    });

    test('registerOverlayImages meldet die Bilder wirklich an', () async {
      // Ein Symbol-Layer ohne sein Bild zeichnet nichts, ohne Fehler.
      bindBoth();
      host.registerOverlayImages(<MapOverlayImage>[balloonImage]);
      await host.debugOverlays.debugSettled;

      expect(overlays.calls, <String>['addImage:fact.hist.uncollected']);
    });

    test('removeOverlay nimmt sie wirklich herunter', () async {
      bindBoth();
      host.setOverlay(overlay);
      await host.debugOverlays.debugSettled;
      overlays.calls.clear();

      host.removeOverlay('discovery.facts');
      await host.debugOverlays.debugSettled;

      expect(overlays.calls.first, 'removeLayer:discovery.facts.groups');
      expect(overlays.calls.last, 'removeSource:discovery.facts.source');
    });

    test('bindSurface reicht die Überlagerungsnaht weiter', () async {
      // Die Umkehrung: alles vor der Karte gesetzt, und erst das Binden
      // schiebt es hinaus. Wer den Parameter ignoriert, lässt die Karte leer
      // und behält trotzdem einen vollständigen Zwischenspeicher.
      host
        ..registerOverlayImages(<MapOverlayImage>[balloonImage])
        ..setOverlay(overlay);
      bindBoth();
      await host.debugOverlays.debugSettled;

      expect(overlays.calls.first, 'addImage:fact.hist.uncollected');
      expect(overlays.calls, contains('addSource:discovery.facts.source'));
    });

    test('unbindSurface löst auch die Überlagerungsnaht', () async {
      // Bliebe sie stehen, schöbe der Host nach dem Kartenwechsel Daten in
      // eine Quelle, die es nicht mehr gibt.
      bindBoth();
      host.setOverlay(overlay);
      await host.debugOverlays.debugSettled;
      host.unbindSurface();
      overlays.calls.clear();

      host.setOverlay(overlay);
      await host.debugOverlays.debugSettled;

      expect(overlays.calls, isEmpty);
    });

    test('ein zweites bindSurface ohne Naht löst die alte', () async {
      // Der Vertrag von `bindSurface` verspricht, ohne Überlagerungen gehe
      // nichts verloren. Das galt nur beim **ersten** Mal: ein zweiter Aufruf
      // tauschte den Kamera-Treiber und ließ die alte Naht stehen. Heute nicht
      // erreichbar, `MapSurface` gibt immer beides mit.
      bindBoth();
      host.setOverlay(overlay);
      await host.debugOverlays.debugSettled;
      overlays.calls.clear();

      host.bindSurface(driver: driver, camera: viewAt());
      host.setOverlay(overlay);
      await host.debugOverlays.debugSettled;

      expect(overlays.calls, isEmpty);
    });

    test('dispose vergisst Bilder und Überlagerungen', () async {
      // Ohne die Durchreichung überlebten sie die Karte, und der nächste Host
      // erbte den Zwischenspeicher des vorigen.
      bindBoth();
      host
        ..registerOverlayImages(<MapOverlayImage>[balloonImage])
        ..setOverlay(overlay);
      await host.debugOverlays.debugSettled;

      host.dispose();

      expect(host.debugOverlays.debugRegisteredStyleIds, isEmpty);
      expect(host.debugOverlays.debugInstalledOverlayIds, isEmpty);
    });
  });

  group('Die Projektion', () {
    late FakeProjectionDriver projections;

    setUp(() => projections = FakeProjectionDriver());

    void bindWithProjections() => host.bindSurface(
      driver: driver,
      camera: viewAt(),
      projections: projections,
    );

    test('ohne Karte kommt lauter null, und zwar ohne Meldung', () async {
      // Der Normalfall jedes Startvorgangs. Ein Ereignis, das dabei feuert,
      // liest nach der dritten Woche niemand mehr.
      final List<MapScreenPoint?> located = await host.projectToScreen(
        <MapPosition>[munich, munich],
      );

      expect(located, <MapScreenPoint?>[null, null]);
      expect(sink.names, isEmpty);
    });

    test('Breite und Länge gehen in der Reihenfolge des SDK hinaus', () async {
      // **Die eine Vertauschung, die lautlos wäre.** `LatLng` nimmt Breite vor
      // Länge, die Domäne auch, GeoJSON umgekehrt: hier liegt der einzige Ort,
      // an dem das noch einmal falsch werden kann.
      bindWithProjections();

      await host.projectToScreen(<MapPosition>[
        const MapPosition(latitude: 48.1351, longitude: 11.582),
      ]);

      expect(projections.requests.single.single.latitude, 48.1351);
      expect(
        projections.requests.single.single.longitude,
        closeTo(11.582, 1e-9),
      );
    });

    test('eine Antwort wird elementweise übernommen', () async {
      bindWithProjections();
      projections.answer = <Point<num>>[
        const Point<num>(12.5, 340),
        const Point<num>(7, 8),
      ];

      final List<MapScreenPoint?> located = await host.projectToScreen(
        <MapPosition>[munich, munich],
      );

      expect(located, <MapScreenPoint?>[
        const MapScreenPoint(xInScreenPixels: 12.5, yInScreenPixels: 340),
        const MapScreenPoint(xInScreenPixels: 7, yInScreenPixels: 8),
      ]);
    });

    test('x bleibt x und y bleibt y', () async {
      // Auf einer quadratischen Testfläche wäre die Vertauschung unsichtbar,
      // auf einem Telefon säße jeder Ballon an der gespiegelten Stelle.
      bindWithProjections();
      projections.answer = <Point<num>>[const Point<num>(10, 900)];

      expect(
        await host.projectToScreen(<MapPosition>[munich]),
        <MapScreenPoint?>[
          const MapScreenPoint(xInScreenPixels: 10, yInScreenPixels: 900),
        ],
      );
    });

    test('ein einzelner unbrauchbarer Punkt fällt als null heraus', () async {
      // **Ein Punkt hinter dem Horizont ist bei 58 Grad Neigung ein realer
      // Fall**, und das Paket widerspricht sich, was dann kommt:
      // `controller.dart:1784` sagt „Returns null if not currently visible",
      // die Signatur auf `:1785` ist nicht nullfähig.
      bindWithProjections();
      projections.answer = <Point<num>>[
        const Point<num>(5, 5),
        const Point<num>(double.nan, 3),
        const Point<num>(double.infinity, 3),
      ];

      final List<MapScreenPoint?> located = await host.projectToScreen(
        <MapPosition>[munich, munich, munich],
      );

      expect(located.first, isNotNull);
      expect(located[1], isNull);
      expect(located[2], isNull);
      // **Und die Reihenfolge bleibt.** Wer die unbrauchbaren Punkte
      // herausfiltert, statt sie auf `null` zu setzen, verschiebt die
      // Zuordnung, und jeder Ballon säße auf der Koordinate seines Nachbarn.
      expect(located, hasLength(3));
    });

    test('eine zu kurze Antwort wird ganz verworfen und gemeldet', () async {
      // Die Kanalfassung baut ihre Liste stumpf aus einer `Float64List`, zwei
      // Zahlen je Punkt (`method_channel_maplibre_gl.dart:598-613`). Kommt von
      // der Plattform ein kürzeres Feld, wäre eine elementweise Zuordnung
      // **verschoben**.
      bindWithProjections();
      projections.answer = <Point<num>>[const Point<num>(1, 2)];

      final List<MapScreenPoint?> located = await host.projectToScreen(
        <MapPosition>[munich, munich],
      );

      expect(located, <MapScreenPoint?>[null, null]);
      expect(sink.names, <String>[MapCameraHost.projectionFailedEvent]);
      expect(sink.events.single.attributes['reason'], 'length:1');
    });

    test('ein Fehler auf dem Kanal wird gemeldet und nicht geworfen', () async {
      // Ein Aufrufer, der 60-mal je Sekunde projiziert, kann mit einer
      // Ausnahme nichts anfangen; er zeichnet dann eben nichts.
      bindWithProjections();
      projections.failure = StateError('Kanal weg');

      final List<MapScreenPoint?> located = await host.projectToScreen(
        <MapPosition>[munich],
      );

      expect(located, <MapScreenPoint?>[null]);
      expect(sink.names, <String>[MapCameraHost.projectionFailedEvent]);
      expect(sink.events.single.attributes['reason'], 'StateError');
    });

    test('eine leere Anfrage geht gar nicht erst hinaus', () async {
      bindWithProjections();

      expect(await host.projectToScreen(<MapPosition>[]), isEmpty);
      expect(projections.requests, isEmpty);
    });

    test('unbindSurface löst auch die Projektionsnaht', () async {
      // Bliebe sie stehen, rechnete der Host gegen eine Kamera, die es nicht
      // mehr gibt, und die Ballons stünden an den Stellen der alten Karte.
      bindWithProjections();
      host.unbindSurface();

      expect(
        await host.projectToScreen(<MapPosition>[munich]),
        <MapScreenPoint?>[null],
      );
      expect(projections.requests, isEmpty);
    });

    test('ein zweites bindSurface ohne Naht löst die alte', () async {
      // Dieselbe Zusage wie beim Überlagerungsteil und aus demselben Grund.
      bindWithProjections();
      host.bindSurface(driver: driver, camera: viewAt());

      expect(
        await host.projectToScreen(<MapPosition>[munich]),
        <MapScreenPoint?>[null],
      );
      expect(projections.requests, isEmpty);
    });
  });

  group('Wird die Karte entsorgt', () {
    test('fällt der Host auf „keine Karte" zurück', () {
      bind();
      host.unbindSurface();

      expect(host.camera, isNull);
      host.submitIntent(oneShot());
      expect(driver.calls, isEmpty);
      expect(sink.names.last, MapCameraHost.droppedEvent);
    });
  });
}

/// Die Auto-Neigung als Absicht, mit lautem Scheitern statt `!`.
MapCameraOneShot mapAutoPitchIntentOrFail(MapCameraView view) {
  final MapCameraOneShot? intent = mapAutoPitchIntent(view);
  expect(intent, isNotNull, reason: 'die Lage soll eine Neigung auslösen');
  return intent!;
}
