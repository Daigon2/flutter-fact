import 'package:fact_app/features/discovery/presentation/fact_group_expand.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:flutter_test/flutter_test.dart';

/// [selectGroupMembers], die Näherung für „welche Punkte stecken in dieser
/// angetippten Gruppe".
///
/// Reine Funktion, ohne Karte, ohne Riverpod und ohne Widget-Baum prüfbar.
void main() {
  MapOverlayPoint pointAt(String id) => MapOverlayPoint(
    id: id,
    position: const MapPosition(latitude: 48.1351, longitude: 11.582),
    styleId: 'fact.hist.uncollected',
    state: 'uncollected',
  );

  group('ohne Bildschirmlage der Tippstelle', () {
    test('entsteht keine Auswahl, auch wenn Kandidaten eine Lage haben', () {
      final List<MapOverlayPoint> selected = selectGroupMembers(
        candidates: <MapOverlayPoint>[pointAt('1')],
        candidateScreenPositions: const <MapScreenPoint?>[
          MapScreenPoint(xInScreenPixels: 200, yInScreenPixels: 400),
        ],
        tapScreenPosition: null,
        radiusInStylePixels: 70,
        pixelRatio: 1,
      );

      expect(selected, isEmpty);
    });
  });

  group('die Auswahl selbst', () {
    test('ein Punkt genau auf der Tippstelle wird gewählt', () {
      final List<MapOverlayPoint> selected = selectGroupMembers(
        candidates: <MapOverlayPoint>[pointAt('1')],
        candidateScreenPositions: const <MapScreenPoint?>[
          MapScreenPoint(xInScreenPixels: 200, yInScreenPixels: 400),
        ],
        tapScreenPosition: const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
        ),
        radiusInStylePixels: 70,
        pixelRatio: 1,
      );

      expect(selected.map((p) => p.id), <String>['1']);
    });

    test('ein Punkt außerhalb des Radius fällt heraus', () {
      // Radius 70 Stilpixel, Bildverhältnis 1: 70 Gerätepixel. Der Punkt
      // liegt 1000 Gerätepixel entfernt, weit darüber.
      final List<MapOverlayPoint> selected = selectGroupMembers(
        candidates: <MapOverlayPoint>[pointAt('fern')],
        candidateScreenPositions: const <MapScreenPoint?>[
          MapScreenPoint(xInScreenPixels: 1200, yInScreenPixels: 400),
        ],
        tapScreenPosition: const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
        ),
        radiusInStylePixels: 70,
        pixelRatio: 1,
      );

      expect(selected, isEmpty);
    });

    test('ein Punkt genau auf dem Radius (Abstand exakt gleich dem Radius) '
        'wird noch gewählt', () {
      // `<=` und nicht `<`: bei Radius 70, Bildverhältnis 1, sind 70
      // Gerätepixel Abstand die Grenze selbst. Ein `<` an dieser Stelle
      // überlebt jeden Test, der nur "deutlich innerhalb" gegen "deutlich
      // ausserhalb" prüft, siehe die beiden Tests oben.
      final List<MapOverlayPoint> selected = selectGroupMembers(
        candidates: <MapOverlayPoint>[pointAt('1')],
        candidateScreenPositions: const <MapScreenPoint?>[
          MapScreenPoint(xInScreenPixels: 270, yInScreenPixels: 400),
        ],
        tapScreenPosition: const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
        ),
        radiusInStylePixels: 70,
        pixelRatio: 1,
      );

      expect(selected, hasLength(1));
    });

    test('ein Punkt ohne eigene Bildschirmlage (null) fällt heraus', () {
      // Die Tippstelle liegt hier bewusst nah am Ursprung (200, 400) und der
      // Radius ist groß genug, dass (0, 0) selbst innerhalb des Radius um die
      // Tippstelle läge (Abstand rund 447 Gerätepixel bei einem Radius von
      // 500). Würde `continue` durch „`null` wird zu (0, 0)" ersetzt, wäre
      // Kandidat '1' also plötzlich mit ausgewählt, weil (0, 0) selbst im
      // Radius liegt. Bei den ursprünglichen, weit entfernten Testwerten
      // (Radius 70) lag (0, 0) zufällig ebenfalls außerhalb, und „herausge-
      // fallen, weil ohne Lage" und „herausgefallen, weil (0, 0) zu weit weg
      // ist" sahen im Ergebnis gleich aus. Das trennt jetzt beide Fälle.
      final List<MapOverlayPoint> selected = selectGroupMembers(
        candidates: <MapOverlayPoint>[pointAt('1'), pointAt('2')],
        candidateScreenPositions: const <MapScreenPoint?>[
          null,
          MapScreenPoint(xInScreenPixels: 200, yInScreenPixels: 400),
        ],
        tapScreenPosition: const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
        ),
        radiusInStylePixels: 500,
        pixelRatio: 1,
      );

      expect(selected.map((p) => p.id), <String>['2']);
    });

    test('nur die Kandidaten im Radius werden gewählt, andere nicht', () {
      final List<MapOverlayPoint> selected = selectGroupMembers(
        candidates: <MapOverlayPoint>[pointAt('nah'), pointAt('fern')],
        candidateScreenPositions: const <MapScreenPoint?>[
          MapScreenPoint(xInScreenPixels: 230, yInScreenPixels: 400),
          MapScreenPoint(xInScreenPixels: 1200, yInScreenPixels: 400),
        ],
        tapScreenPosition: const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
        ),
        radiusInStylePixels: 70,
        pixelRatio: 1,
      );

      expect(selected.map((p) => p.id), <String>['nah']);
    });
  });

  group('die Umrechnung von Stilpixeln in Gerätepixel', () {
    test('der Radius wird mit dem Bildverhältnis multipliziert, nicht '
        'unverändert gegen Gerätepixel verglichen', () {
      // Radius 10 Stilpixel, Bildverhältnis 3: 30 Gerätepixel. Der Kandidat
      // liegt 25 Gerätepixel entfernt, innerhalb von 30, aber außerhalb der
      // unumgerechneten 10. Eine fehlende Umrechnung (oder eine, die durch
      // statt mit dem Verhältnis rechnet) lässt diesen Kandidaten
      // herausfallen.
      final List<MapOverlayPoint> selected = selectGroupMembers(
        candidates: <MapOverlayPoint>[pointAt('1')],
        candidateScreenPositions: const <MapScreenPoint?>[
          MapScreenPoint(xInScreenPixels: 225, yInScreenPixels: 400),
        ],
        tapScreenPosition: const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
        ),
        radiusInStylePixels: 10,
        pixelRatio: 3,
      );

      expect(selected, hasLength(1));
    });

    test('derselbe Kandidat fällt bei Bildverhältnis 1 aus demselben Radius '
        'in Stilpixeln heraus', () {
      // Dieselben 10 Stilpixel, aber Bildverhältnis 1: 10 Gerätepixel, und
      // der Kandidat liegt weiterhin 25 Gerätepixel entfernt. Zusammen mit
      // dem Test oben zeigt das: derselbe Stilpixel-Radius ergibt bei
      // unterschiedlichem Bildverhältnis unterschiedliche Ergebnisse, und
      // das ist nur richtig, wenn wirklich multipliziert wird.
      final List<MapOverlayPoint> selected = selectGroupMembers(
        candidates: <MapOverlayPoint>[pointAt('1')],
        candidateScreenPositions: const <MapScreenPoint?>[
          MapScreenPoint(xInScreenPixels: 225, yInScreenPixels: 400),
        ],
        tapScreenPosition: const MapScreenPoint(
          xInScreenPixels: 200,
          yInScreenPixels: 400,
        ),
        radiusInStylePixels: 10,
        pixelRatio: 1,
      );

      expect(selected, isEmpty);
    });
  });

  test('mehrere Kandidaten und Bildschirmlagen bleiben Index für Index '
      'zugeordnet', () {
    final List<MapOverlayPoint> selected = selectGroupMembers(
      candidates: <MapOverlayPoint>[pointAt('a'), pointAt('b'), pointAt('c')],
      candidateScreenPositions: const <MapScreenPoint?>[
        MapScreenPoint(xInScreenPixels: 210, yInScreenPixels: 400),
        MapScreenPoint(xInScreenPixels: 1200, yInScreenPixels: 400),
        MapScreenPoint(xInScreenPixels: 195, yInScreenPixels: 400),
      ],
      tapScreenPosition: const MapScreenPoint(
        xInScreenPixels: 200,
        yInScreenPixels: 400,
      ),
      radiusInStylePixels: 70,
      pixelRatio: 1,
    );

    expect(selected.map((p) => p.id), <String>['a', 'c']);
  });
}
