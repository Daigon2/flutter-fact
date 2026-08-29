import 'dart:async';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/features/discovery/presentation/map_camera_intents.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/presentation/map_camera_driver.dart';
import 'package:fact_app/map/presentation/map_camera_host.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die vier Absichten des Kartenbildschirms **durch das echte Gate und den
/// echten Host**.
///
/// ## Warum es diese Datei gibt
///
/// Bis zum 29.08.2026 lief keine einzige Prüfung diesen Weg zu Ende.
/// `map_camera_intents_test.dart` prüft reine Funktionen, also was in einer
/// Absicht steht. `map_page_test.dart` prüft, welche Absicht bei welcher Geste
/// entsteht, und benutzt dafür einen Doppelgänger des Hosts. Und
/// `test/map/presentation/map_camera_host_test.dart` kennt diese vier
/// Absichten überhaupt nicht, es baut sich eigene. **Zwischen „die Absicht ist
/// richtig" und „der Host tut damit das Richtige" lag also nichts**, und genau
/// dort saß der eine echte Fehler aus Schritt 13: ein Kompass-Tipp ohne
/// Ortung fror eine laufende Auto-Neigung ein.
///
/// Ohne Widget und ohne Karte: die Uhr ist gestellt, das SDK ist gefälscht.
/// Im Widget-Test entstünde nie ein `MapLibreMapController`
/// (`maplibre_map.dart:390-418` läuft ohne Plattformkanal nicht).
///
/// **Die Doppelgänger stehen hier noch einmal und nicht in `test/support/`.**
/// Sie sind drei kurze Klassen, und der einzige andere Aufrufer ist eine
/// Testdatei mit eigenem `main()`, die man nicht importieren kann, ohne sie zu
/// verstecken. Fällt ein dritter Aufrufer an, ist eine gemeinsame Datei
/// richtig; heute wäre sie Vorrat.
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

  /// Bringt die Blickrichtung zum Einrasten, so wie eine Zwei-Finger-Drehung
  /// es tut: eine Kamerabewegung, die der Host nicht verursacht hat.
  void userRotatesTo(double bearing, {double zoom = 15, double pitch = 58}) {
    host.handleCameraMove(viewAt(bearing: bearing, zoom: zoom, pitch: pitch));
    expect(host.debugBearingLocked, isTrue, reason: 'Vorbedingung');
  }

  /// Der letzte Grund, aus dem eine Absicht unterdrückt wurde.
  String? lastSuppression() {
    for (final DiagnosticEvent event in sink.events.reversed) {
      if (event.name == MapHostRegistry.suppressedEvent) {
        return event.attributes['reason'];
      }
    }
    return null;
  }

  group('Sky-Fall', () {
    test('fliegt in einem einzigen Aufruf auf alle vier Werte', () {
      bind(camera: viewAt(zoom: 14, pitch: 35));

      host.submitIntent(skyFallIntent(northOf(munich, 400)));

      final DriverCall call = driver.calls.single;
      expect(call.duration, skyFallDuration);
      expect(call.target.zoom, skyFallZoom);
      expect(call.target.pitch, skyFallPitch);
      expect(call.target.bearing, skyFallBearing);
      expect(call.target.center, northOf(munich, 400));
    });

    test('überschreibt, was gerade läuft', () {
      // Er weicht keiner Animation, und das ist am Host das einzige, woran
      // man es sehen kann: die Auto-Neigung liefe hier weiter.
      bind(camera: viewAt(zoom: 11, pitch: 0));
      host.handleCameraMove(viewAt(zoom: 16, pitch: 0));
      host.handleCameraIdle();
      expect(driver.calls, hasLength(1), reason: 'die Auto-Neigung läuft');

      host.submitIntent(skyFallIntent(munich));

      expect(driver.calls, hasLength(2));
      expect(driver.calls.last.target.zoom, skyFallZoom);
    });
  });

  group('GPS-Folgen', () {
    test('folgt, wenn die Strecke reicht, und schweigt, wenn nicht', () {
      bind();

      host.submitIntent(userPositionFollowIntent(northOf(munich, 100)));
      expect(driver.calls, hasLength(1));
      expect(driver.calls.single.duration, followDuration);
      expect(driver.calls.single.target.center, northOf(munich, 100));
      expect(
        driver.calls.single.target.zoom,
        15,
        reason: 'die Absicht fasst den Zoom nicht an, der Host füllt ihn auf',
      );

      // Die Animation ist um, und die Mindestpause von 800 Millisekunden auch.
      clock.advance(const Duration(milliseconds: 1000));
      host.submitIntent(userPositionFollowIntent(northOf(munich, 102)));

      expect(driver.calls, hasLength(1), reason: 'zwei Meter sind zu wenig');
      expect(lastSuppression(), 'distanceDeadZone');

      clock.advance(const Duration(milliseconds: 1000));
      host.submitIntent(userPositionFollowIntent(northOf(munich, 220)));

      expect(driver.calls, hasLength(2));
    });

    test(
      'die Mindestpause bremst, sobald das SDK die Animation abmeldet',
      () async {
        // **Mit den Zahlen der Quelle greift die Pause nur dort, wo das SDK
        // antwortet.** Die Animation dauert 900 Millisekunden, die Pause misst
        // 800: solange der Host die Animation für laufend hält, unterdrückt
        // bereits Vorrangregel 3, und wenn sie abgelaufen ist, ist auch die
        // Pause um. Erst die Rückmeldung `true`, die es nach eigener Doku des
        // Pakets nur auf Android gibt, löscht den Animationszustand früher, und
        // dann ist die Pause die Grenze, die zählt. Auf iOS (`null`, „keine
        // Auskunft") ist dieser Zweig unerreichbar.
        bind();
        host.submitIntent(userPositionFollowIntent(northOf(munich, 100)));
        driver.pending.last.complete(true);
        await pumpEventQueue();
        clock.advance(const Duration(milliseconds: 500));

        host.submitIntent(userPositionFollowIntent(northOf(munich, 400)));

        expect(driver.calls, hasLength(1));
        expect(lastSuppression(), 'minPause');
      },
    );
  });

  group('Neuzentrieren über die Stadt-Pille', () {
    test('läuft mitten im Sky-Fall', () {
      // **Die Zusicherung, die dem Neuzentrieren gefehlt hat.** Wäre es eine
      // Absicht, die einer laufenden Animation weicht, verschluckte der Tipp
      // sich lautlos, und zwar genau dann, wenn ein Nutzer „bring mich
      // zurück" drückt. Die Quelle ruft `recenter` (`:3106`) bedingungslos.
      bind(camera: viewAt(zoom: 14));
      host.submitIntent(skyFallIntent(northOf(munich, 400)));
      expect(driver.calls, hasLength(1));

      host.submitIntent(recenterIntent(target: munich, currentZoom: 14));

      expect(driver.calls, hasLength(2));
      final DriverCall call = driver.calls.last;
      expect(call.duration, recenterDuration);
      expect(call.target.center, munich);
      expect(call.target.zoom, 15, reason: 'max(14, 15)');
    });

    test('lässt das Einrasten der Blickrichtung stehen', () {
      // Der ganze Unterschied zwischen Pille und Kompass, am Host gemessen:
      // die Pille fasst `manualBearingRef` nicht an.
      bind();
      userRotatesTo(50);

      host.submitIntent(recenterIntent(target: munich, currentZoom: 17));

      expect(driver.calls.last.target.zoom, 17);
      expect(host.debugBearingLocked, isTrue);
    });
  });

  group('Kompass, kurzer Druck', () {
    test('zentriert neu und löst das Einrasten', () {
      bind();
      userRotatesTo(50);

      host.submitIntent(compassTapIntent(currentZoom: 17, target: munich));

      expect(host.debugBearingLocked, isFalse);
      final DriverCall call = driver.calls.single;
      expect(call.duration, recenterDuration);
      expect(call.target.center, munich);
      expect(call.target.zoom, 17);
    });

    test('lässt ohne Ortung eine laufende Auto-Neigung zu Ende laufen', () {
      // **Der eine echte Fehler aus Schritt 13.** Der leere Befehl galt als
      // unsichtbar, weil es „ohne Position auch keinen Sky-Fall gab". Die
      // Auto-Neigung braucht aber keine Position: sie hängt am Zoom-Ende. Ein
      // Sprung auf die Zwischenstellung der laufenden Animation fror die
      // Neigung auf halbem Weg ein, und der Nutzer sah eine Karte, die mitten
      // in der Bewegung stehen bleibt.
      bind(camera: viewAt(zoom: 11, pitch: 0, bearing: 0));
      userRotatesTo(50, zoom: 11, pitch: 0);
      host.handleCameraIdle();
      host.handleCameraMove(viewAt(zoom: 16, pitch: 0, bearing: 50));
      host.handleCameraIdle();

      expect(driver.calls, hasLength(1), reason: 'die Auto-Neigung läuft');
      expect(driver.calls.single.duration, const Duration(milliseconds: 300));
      expect(driver.calls.single.target.pitch, 58);

      host.submitIntent(compassTapIntent(currentZoom: 16));

      expect(
        driver.calls,
        hasLength(1),
        reason: 'ohne Ortung gibt es nichts zu bewegen, also keinen Aufruf',
      );
      expect(
        host.debugAnimationEndsAt,
        isNotNull,
        reason: 'die Animation läuft weiter, sie wurde nicht abgebrochen',
      );
      expect(
        host.debugBearingLocked,
        isFalse,
        reason: 'gelöst wird das Einrasten trotzdem, unbedingt (:3182)',
      );
    });
  });

  group('Kompass, langer Druck', () {
    test('springt mit Ortung auf die Werte des harten Resets', () {
      bind(camera: viewAt(zoom: 12, pitch: 58, bearing: 90));

      host.submitIntent(compassLongPressIntent(target: munich));

      final DriverCall call = driver.calls.single;
      expect(call.duration, isNull, reason: 'die Quelle springt');
      expect(call.target.center, munich);
      expect(call.target.zoom, hardResetZoom);
      expect(call.target.pitch, hardResetPitch);
      expect(call.target.bearing, hardResetBearing);
    });

    test('versetzt die Karte ohne Ortung nicht', () {
      // Hier ist die Änderung **nicht** leer, und deshalb wird gesprungen: der
      // Zweig `:3170` setzt Blickrichtung und Neigung. Mittelpunkt und Zoom
      // füllt der Host aus dem Ist-Zustand auf.
      bind(camera: viewAt(center: northOf(munich, 500), zoom: 12, bearing: 90));

      host.submitIntent(compassLongPressIntent());

      final DriverCall call = driver.calls.single;
      expect(call.target.center, northOf(munich, 500));
      expect(call.target.zoom, 12);
      expect(call.target.pitch, hardResetPitch);
      expect(call.target.bearing, hardResetBearing);
    });

    test('leert den Anker, und der nächste Fix folgt trotz Totzone', () {
      // `lastCameraPosRef.current = null` (`:3165`). Ohne das unterdrückte die
      // Strecken-Totzone den nächsten GPS-Fix, während die Quelle ihn
      // ausführt.
      bind();
      host.submitIntent(userPositionFollowIntent(northOf(munich, 100)));
      clock.advance(const Duration(milliseconds: 1000));
      host.submitIntent(userPositionFollowIntent(northOf(munich, 102)));
      expect(driver.calls, hasLength(1), reason: 'die Totzone greift');

      host.submitIntent(compassLongPressIntent(target: munich));
      expect(driver.calls, hasLength(2));
      expect(host.debugFollowAnchor(MapCameraFollowKind.userPosition), isNull);

      clock.advance(const Duration(milliseconds: 1000));
      host.submitIntent(userPositionFollowIntent(northOf(munich, 102)));

      expect(driver.calls, hasLength(3));
    });
  });
}
