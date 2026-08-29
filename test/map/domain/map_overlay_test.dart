import 'dart:typed_data';

import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Wertetypen der Überlagerung.
///
/// **Jeder einzelne bekommt seinen eigenen Gleichheitstest, und das ist der
/// Grund, warum diese Datei so gleichförmig aussieht.** Am 28.08.2026 ist beim
/// Kartenfundament genau das durchgerutscht: ein Typ hatte `==`, der Nachbar
/// nicht, und weil niemand ihn verglich, fiel es nicht auf. Ein `==`, das
/// fehlt, macht keinen Fehler, es macht nur alles ungleich, und das sieht man
/// erst, wenn ein Vergleich still immer `false` sagt.
///
/// Geprüft wird jeweils **beides**: gleiche Werte sind gleich, und je ein
/// abweichendes Feld macht ungleich. Nur die erste Hälfte ginge auch mit einem
/// `==`, das immer `true` liefert.
void main() {
  const MapPosition munich = MapPosition(latitude: 48.1351, longitude: 11.582);
  const MapPosition rome = MapPosition(latitude: 41.896, longitude: 12.4822);

  MapOverlayPoint pointAt({
    String id = '1',
    MapPosition position = munich,
    String styleId = 'fact.hist.uncollected',
    String state = 'uncollected',
  }) => MapOverlayPoint(
    id: id,
    position: position,
    styleId: styleId,
    state: state,
  );

  group('MapOverlayPoint', () {
    test('gleiche Werte sind gleich, auch im Hash', () {
      expect(pointAt(), pointAt());
      expect(pointAt().hashCode, pointAt().hashCode);
    });

    test('jedes Feld einzeln macht ungleich', () {
      expect(pointAt(), isNot(pointAt(id: '2')));
      expect(pointAt(), isNot(pointAt(position: rome)));
      expect(pointAt(), isNot(pointAt(styleId: 'fact.myth.uncollected')));
      expect(pointAt(), isNot(pointAt(state: 'collected')));
    });

    test('toString nennt keine Koordinaten', () {
      // `security.md` §6: keine genauen Standorte im Log. Die Zahl steht
      // hier ausgeschrieben, damit der Test auch dann fehlschlägt, wenn
      // jemand `MapPosition.toString()` ändert statt dieses hier.
      expect(pointAt().toString(), isNot(contains('48.1351')));
      expect(pointAt().toString(), contains('fact.hist.uncollected'));
    });
  });

  group('MapOverlayGrouping', () {
    test('gleiche Werte sind gleich, jedes Feld macht ungleich', () {
      const MapOverlayGrouping a = MapOverlayGrouping(
        maxZoom: 15,
        radiusInScreenPixels: 70,
      );
      expect(
        a,
        const MapOverlayGrouping(maxZoom: 15, radiusInScreenPixels: 70),
      );
      expect(
        a.hashCode,
        const MapOverlayGrouping(
          maxZoom: 15,
          radiusInScreenPixels: 70,
        ).hashCode,
      );
      expect(
        a,
        isNot(const MapOverlayGrouping(maxZoom: 16, radiusInScreenPixels: 70)),
      );
      expect(
        a,
        isNot(const MapOverlayGrouping(maxZoom: 15, radiusInScreenPixels: 50)),
      );
    });
  });

  group('MapOverlay', () {
    MapOverlay overlayWith({
      String id = 'discovery.facts',
      List<MapOverlayPoint>? points,
      MapOverlayGrouping? grouping = const MapOverlayGrouping(
        maxZoom: 15,
        radiusInScreenPixels: 70,
      ),
      double? minZoom = 11,
      double? maxZoom,
    }) => MapOverlay(
      id: id,
      points: points ?? <MapOverlayPoint>[pointAt()],
      grouping: grouping,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    test('gleiche Werte sind gleich, auch bei getrennt gebauten Listen', () {
      // Zwei Listen mit gleichem Inhalt, aber verschiedener Identität: genau
      // das ist der Fall, den ein `==` über `identical` der Liste verpasste.
      expect(overlayWith(), overlayWith());
      expect(overlayWith().hashCode, overlayWith().hashCode);
    });

    test('jedes Feld einzeln macht ungleich', () {
      expect(overlayWith(), isNot(overlayWith(id: 'tours.stops')));
      expect(
        overlayWith(),
        isNot(overlayWith(points: <MapOverlayPoint>[pointAt(id: '2')])),
      );
      expect(overlayWith(), isNot(overlayWith(grouping: null)));
      expect(overlayWith(), isNot(overlayWith(minZoom: null)));
      expect(overlayWith(), isNot(overlayWith(maxZoom: 18)));
    });

    test('mehr Punkte machen ungleich, auch bei gleichem Anfang', () {
      // Die Längenprüfung allein reicht nicht, und eine Elementprüfung ohne
      // Längenprüfung auch nicht. Beides zusammen deckt diesen Fall ab.
      expect(
        overlayWith(points: <MapOverlayPoint>[pointAt()]),
        isNot(
          overlayWith(
            points: <MapOverlayPoint>[
              pointAt(),
              pointAt(id: '2'),
            ],
          ),
        ),
      );
    });

    test('toString nennt nur die Anzahl der Punkte', () {
      final String text = overlayWith(
        points: <MapOverlayPoint>[
          pointAt(),
          pointAt(id: '2'),
        ],
      ).toString();
      expect(text, contains('2 Punkte'));
      expect(text, isNot(contains('48.1351')));
    });
  });

  group('MapOverlayImage', () {
    MapOverlayImage imageWith({
      String styleId = 'fact.hist.uncollected',
      List<int> bytes = const <int>[1, 2, 3],
      double pixelRatio = 1,
    }) => MapOverlayImage(
      styleId: styleId,
      bytes: Uint8List.fromList(bytes),
      pixelRatio: pixelRatio,
    );

    test('gleicher Inhalt ist gleich, obwohl die Bytes zwei Objekte sind', () {
      // `Uint8List` erbt `==` von `Object`. Ohne den elementweisen Vergleich
      // wäre dieser Test rot, und `MapOverlayImage.==` wäre Identität mit
      // zusätzlichen Schritten.
      expect(imageWith(), imageWith());
      expect(imageWith().hashCode, imageWith().hashCode);
    });

    test('jedes Feld einzeln macht ungleich', () {
      expect(imageWith(), isNot(imageWith(styleId: 'fact.myth.uncollected')));
      expect(imageWith(), isNot(imageWith(bytes: const <int>[1, 2, 4])));
      expect(imageWith(), isNot(imageWith(bytes: const <int>[1, 2])));
      expect(imageWith(), isNot(imageWith(pixelRatio: 3)));
    });

    test('toString nennt die Bytes nicht', () {
      expect(imageWith().toString(), contains('3 Bytes'));
      expect(imageWith().toString(), contains('fact.hist.uncollected'));
    });
  });
}
