import 'dart:async';

import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:fact_app/map/presentation/avatar/avatar_look.dart';
import 'package:fact_app/map/presentation/avatar/avatar_motion.dart';
import 'package:fact_app/map/presentation/avatar/avatar_providers.dart';
import 'package:fact_app/map/presentation/avatar/user_marker_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Nutzermarker, `02_Frontend/app/screen-map.jsx:655-682` und `:1768-1775`.
///
/// **Die Figur wird hier nicht gebaut.** `avatarFigureBuilderProvider` ist
/// überschrieben, und das ist der Sinn dieser Naht: ein `WebViewController`
/// entsteht in keinem Widget-Test. Geprüft wird, was der Marker entscheidet —
/// wo er sitzt, wann er verschwindet, und welche Animation er weitergibt.
void main() {
  const MapPosition marienplatz = MapPosition(
    latitude: 48.1374,
    longitude: 11.5755,
  );

  MapPosition northOf(MapPosition from, double meters) => MapPosition(
    latitude: from.latitude + meters / 111195,
    longitude: from.longitude,
  );

  const MapScreenPoint at200x400 = MapScreenPoint(
    xInScreenPixels: 200,
    yInScreenPixels: 400,
    isInFrontOfCamera: true,
  );

  late FakeMarkerMapHost host;
  late List<AvatarAnimation> animations;

  setUp(() {
    host = FakeMarkerMapHost();
    animations = <AvatarAnimation>[];
  });

  tearDown(() => host.dispose());

  /// Baut den Marker in einem `Stack`, weil er ein `Positioned` liefert.
  Future<void> pumpMarker(
    WidgetTester tester, {
    MapPosition? position,
    double devicePixelRatio = 1,
  }) async {
    tester.view
      ..physicalSize = Size(400, 800) * devicePixelRatio
      ..devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapHostProvider.overrideWithValue(host),
          avatarFigureBuilderProvider.overrideWithValue((
            AvatarAnimation animation,
          ) {
            animations.add(animation);
            return const SizedBox(key: Key('figur'));
          }),
        ],
        child: MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: <Widget>[UserMarkerOverlay(position: position)],
          ),
        ),
      ),
    );
    // `pump` und nicht `pumpAndSettle`: sobald der Marker sichtbar ist, läuft
    // der Pulsring endlos, und `pumpAndSettle` wartete darauf, dass er
    // aufhört.
    await tester.pump();
  }

  group('Ohne Ortung', () {
    testWidgets('zeichnet der Marker nichts', (tester) async {
      await pumpMarker(tester);

      expect(find.byKey(UserMarkerOverlay.markerKey), findsNothing);
      expect(find.byKey(const Key('figur')), findsNothing);
    });

    testWidgets('wird nichts projiziert', (tester) async {
      // Kein Punkt heißt keine Anfrage. Eine Projektion von `null` wäre eine
      // Koordinate, die niemand gemeldet hat.
      await pumpMarker(tester);
      host.emitCamera();
      await tester.pump();

      expect(host.projected, isEmpty);
    });

    testWidgets('läuft der Pulsring nicht, also kommt die App zur Ruhe', (
      tester,
    ) async {
      // Der teuerste Fehler dieses Widgets, gemessen am 04.09.2026: ein
      // dauerhaft laufender `AnimationController` lässt **jeden**
      // `pumpAndSettle` der ganzen Suite auflaufen, 88 Fehlschläge, und keiner
      // nennt den Avatar.
      await pumpMarker(tester);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Mit Ortung', () {
    testWidgets('wird die eigene Koordinate projiziert', (tester) async {
      await pumpMarker(tester, position: marienplatz);

      expect(host.projected, <List<MapPosition>>[
        <MapPosition>[marienplatz],
      ]);
    });

    testWidgets('steht die Figur mit den Füßen auf dem Punkt', (tester) async {
      host.projectionAnswer = const <MapScreenPoint?>[at200x400];
      await pumpMarker(tester, position: marienplatz);
      await tester.pump();

      final Rect rect = tester.getRect(find.byKey(UserMarkerOverlay.markerKey));

      // Ausgeschriebene Zahlen und keine Konstanten der Produktion: 118 breit,
      // 112 hoch, waagerecht mittig auf 200, Fuß auf 400.
      expect(rect.width, 118);
      expect(rect.height, 112);
      expect(rect.center.dx, 200);
      expect(rect.bottom, 400);
    });

    testWidgets('bei dreifacher Pixeldichte wird geteilt', (tester) async {
      // Die Lagen des Karten-SDK sind **Geräte-Pixel**, die von Flutter
      // logische. Ohne die Teilung sitzt die Figur dreimal zu weit rechts.
      host.projectionAnswer = const <MapScreenPoint?>[
        MapScreenPoint(
          xInScreenPixels: 600,
          yInScreenPixels: 900,
          isInFrontOfCamera: true,
        ),
      ];
      await pumpMarker(tester, position: marienplatz, devicePixelRatio: 3);
      await tester.pump();

      final Rect rect = tester.getRect(find.byKey(UserMarkerOverlay.markerKey));

      expect(rect.center.dx, 200, reason: '600 Geräte-Pixel bei Dichte 3.');
      expect(rect.bottom, 300, reason: '900 Geräte-Pixel bei Dichte 3.');
    });

    testWidgets('ein gespiegelter Punkt bekommt keine Figur', (tester) async {
      // Seine Lage sieht gültig aus und liegt geometrisch nirgends. Dieselbe
      // Prüfung wie bei den Ballons.
      host.projectionAnswer = const <MapScreenPoint?>[
        MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: false,
        ),
      ];
      await pumpMarker(tester, position: marienplatz);
      await tester.pump();

      expect(find.byKey(UserMarkerOverlay.markerKey), findsNothing);
    });

    testWidgets('eine leere Antwort bekommt keine Figur', (tester) async {
      // Der Kanal kann eine kürzere Liste liefern als die Anfrage, ohne Fehler
      // und ohne Warnung.
      host.projectionAnswer = const <MapScreenPoint?>[];
      await pumpMarker(tester, position: marienplatz);
      await tester.pump();

      expect(find.byKey(UserMarkerOverlay.markerKey), findsNothing);
    });

    testWidgets('verschwindet der Marker, kommt der Pulsring zur Ruhe', (
      tester,
    ) async {
      // **Der Test, der die Mutation `shouldRun = true` tötet**, und der
      // Grund, aus dem der Test „ohne Ortung läuft nichts" sie nicht tötet:
      // ohne Ortung wird `_syncPulse` gar nicht gerufen, die Zeile läuft also
      // nie. Erst der Weg sichtbar → unsichtbar prüft beide Richtungen.
      host.projectionAnswer = const <MapScreenPoint?>[at200x400];
      await pumpMarker(tester, position: marienplatz);
      await tester.pump();
      expect(
        find.byKey(UserMarkerOverlay.markerKey),
        findsOneWidget,
        reason: 'Vorbedingung: der Ring läuft jetzt.',
      );

      // Derselbe Punkt, aber hinter der Kamera: der Marker fällt weg.
      host.projectionAnswer = const <MapScreenPoint?>[
        MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
          isInFrontOfCamera: false,
        ),
      ];
      host.emitCamera();
      await tester.pump();
      expect(find.byKey(UserMarkerOverlay.markerKey), findsNothing);

      // Und jetzt muss die App zur Ruhe kommen. Ein Ring, der weiterläuft,
      // lässt `pumpAndSettle` auflaufen.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('eine Kamerabewegung fragt die Lage neu ab', (tester) async {
      host.projectionAnswer = const <MapScreenPoint?>[at200x400];
      await pumpMarker(tester, position: marienplatz);
      await tester.pump();
      expect(host.projected, hasLength(1));

      host.emitCamera();
      await tester.pump();

      expect(host.projected, hasLength(2));
    });

    testWidgets('zwei Bewegungen überlappen die Anfragen nicht', (
      tester,
    ) async {
      // Ohne die Sperre baut sich bei 60 Kamerameldungen je Sekunde eine
      // Warteschlange auf, die nie leer wird.
      host.pendingProjection = Completer<List<MapScreenPoint?>>();
      await pumpMarker(tester, position: marienplatz);

      host.emitCamera();
      host.emitCamera();
      await tester.pump();

      expect(host.peakInFlight, 1);
      expect(host.projected, hasLength(1));

      host.answerProjection(const <MapScreenPoint?>[at200x400]);
      await tester.pump();

      // Die gemerkte Meldung geht nach der Antwort hinaus, und zwar genau
      // einmal, nicht zweimal.
      expect(host.projected, hasLength(2));
    });
  });

  group('Laufen', () {
    testWidgets('die erste Ortung gibt idle weiter', (tester) async {
      host.projectionAnswer = const <MapScreenPoint?>[at200x400];
      await pumpMarker(tester, position: marienplatz);
      await tester.pump();

      expect(animations, isNotEmpty);
      expect(animations.last, AvatarAnimation.idle);
    });

    testWidgets('ein Schritt über 1,5 Meter gibt walk weiter', (tester) async {
      host.projectionAnswer = const <MapScreenPoint?>[at200x400];
      await pumpMarker(tester, position: marienplatz);
      await tester.pump();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapHostProvider.overrideWithValue(host),
            avatarFigureBuilderProvider.overrideWithValue((
              AvatarAnimation animation,
            ) {
              animations.add(animation);
              return const SizedBox(key: Key('figur'));
            }),
          ],
          child: MaterialApp(
            home: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                UserMarkerOverlay(position: northOf(marienplatz, 5)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(animations.last, AvatarAnimation.walk);
    });

    testWidgets('ein halber Meter lässt sie stehen', (tester) async {
      host.projectionAnswer = const <MapScreenPoint?>[at200x400];
      await pumpMarker(tester, position: marienplatz);
      await tester.pump();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapHostProvider.overrideWithValue(host),
            avatarFigureBuilderProvider.overrideWithValue((
              AvatarAnimation animation,
            ) {
              animations.add(animation);
              return const SizedBox(key: Key('figur'));
            }),
          ],
          child: MaterialApp(
            home: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                UserMarkerOverlay(position: northOf(marienplatz, 0.5)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(animations.last, AvatarAnimation.idle);
    });
  });

  group('Bewegung reduziert', () {
    testWidgets('ohne Bewegung gibt es keinen Ring, aber die Figur', (
      tester,
    ) async {
      host.projectionAnswer = const <MapScreenPoint?>[at200x400];
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapHostProvider.overrideWithValue(host),
            avatarFigureBuilderProvider.overrideWithValue(
              (AvatarAnimation animation) => const SizedBox(key: Key('figur')),
            ),
          ],
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Stack(
                fit: StackFit.expand,
                children: <Widget>[UserMarkerOverlay(position: marienplatz)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('figur')), findsOneWidget);
      expect(
        find.byKey(UserMarkerOverlay.pulseKey),
        findsNothing,
        reason:
            'Der Ring ist Zierrat. Genau das kann die CSS-Fassung der Vorlage '
            'nicht lesen.',
      );
    });
  });

  group('Maße', () {
    test('der Kasten fasst den Ring, der über die Figur hinausragt', () {
      // Ein `Stack` clippt lautlos (Muster 2). Die Rechnung ausgeschrieben:
      // Ring 118, sitzt 6 über dem Fuß, Figur 100 hoch, also 12 über dem Kopf.
      expect(avatarPulseOverhang, 12);
      expect(avatarMarkerHeight, 112);
      expect(avatarMarkerWidth, 118);
    });
  });
}

/// Ein Karten-Host, der nur die Projektion und die Kamera kann.
class FakeMarkerMapHost implements MapHost {
  final StreamController<MapCameraView> _cameras =
      StreamController<MapCameraView>.broadcast();

  /// Die Anfragen an die Projektion, in der Reihenfolge des Eingangs.
  final List<List<MapPosition>> projected = <List<MapPosition>>[];

  /// Was die Projektion liefert, wenn sie sofort antwortet.
  List<MapScreenPoint?>? projectionAnswer;

  /// Wie viele Anfragen gerade gleichzeitig unterwegs sind.
  int inFlight = 0;

  /// Der höchste je gleichzeitig erreichte Stand von [inFlight].
  ///
  /// Eine bloße Anzahl der Aufrufe sagt nichts darüber, ob sie sich überlappt
  /// haben.
  int peakInFlight = 0;

  /// Wenn gesetzt, antwortet die Projektion erst auf Zuruf.
  Completer<List<MapScreenPoint?>>? pendingProjection;

  /// Meldet eine Kamerabewegung.
  void emitCamera() => _cameras.add(
    const MapCameraView(
      center: MapPosition(latitude: 48.1374, longitude: 11.5755),
      zoom: 15,
      bearing: 0,
      pitch: 0,
    ),
  );

  /// Lässt eine angehaltene Projektion antworten.
  void answerProjection(List<MapScreenPoint?> answer) {
    final Completer<List<MapScreenPoint?>>? gate = pendingProjection;
    pendingProjection = null;
    gate?.complete(answer);
  }

  /// Schließt den Strom.
  void dispose() => _cameras.close();

  @override
  MapCameraView? get camera => null;

  @override
  Stream<MapCameraView> get cameraChanges => _cameras.stream;

  @override
  MapViewport? get viewport => null;

  @override
  Stream<MapOverlayGroupTap> get groupTaps => const Stream.empty();

  @override
  Stream<MapOverlayPointTap> get pointTaps => const Stream.empty();

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
}
