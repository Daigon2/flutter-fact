import 'package:fact_app/map/domain/map_camera_fit.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_position_rect.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

/// [rectFitZoom] gegen von Hand hergeleitete Zahlen und gegen Eigenschaften.
///
/// **Keine der erwarteten Zahlen ist aus der Implementierung abgeschrieben**
/// (Muster 18 aus „Wie Tests hier blind werden"): jede stammt entweder aus
/// einer eigenständigen Rechnung mit Python (`math.log`, `math.tan`,
/// unabhängig von `dart:math` und von `map_camera_fit.dart` geschrieben, im
/// jeweiligen Kommentar nachvollziehbar) oder aus einer algebraischen
/// Eigenschaft, die für die Formel gelten **muss**, unabhängig von ihren
/// Konstanten.
///
/// Bewusst mit `MapPosition`/`MapPositionRect`/`MapViewport` zur Laufzeit
/// gebaut, nicht `const`: für diese Datei ist das ohne Belang, weil hier
/// keine `==`-Zusicherung zwischen zwei gleich geschriebenen Werten steht,
/// aber der Stil bleibt einheitlich mit den Nachbardateien.
void main() {
  group('Fläche null: die betroffene Richtung stellt keine Bedingung', () {
    test('ein einzelner Punkt ergibt maxZoom, nie Infinity oder NaN', () {
      final MapPosition point = MapPosition(
        latitude: 48.1351,
        longitude: 11.582,
      );
      final MapPositionRect rect = MapPositionRect(
        southWest: point,
        northEast: point,
      );
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 800,
        heightInScreenPixels: 600,
      );

      final double result = rectFitZoom(
        rect: rect,
        viewport: viewport,
        maxZoom: 17,
      );

      expect(result, 17);
      expect(result.isNaN, isFalse);
      expect(result.isInfinite, isFalse);
    });

    test('ein Rechteck mit vertauschten Ecken (Spanne unter null) stellt '
        'ebenfalls keine Bedingung, statt in Infinity zu laufen', () {
      // Kein gültiger Aufruf von enclosingOrNull, aber MapPositionRect
      // prüft seinen Konstruktor nicht (siehe map_position_rect.dart).
      // rectFitZoom darf an einer solchen Eingabe nicht zerbrechen.
      final MapPositionRect malformed = MapPositionRect(
        southWest: MapPosition(latitude: 10, longitude: 20),
        northEast: MapPosition(latitude: 10, longitude: 5),
      );
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 400,
        heightInScreenPixels: 400,
      );

      final double result = rectFitZoom(
        rect: malformed,
        viewport: viewport,
        maxZoom: 12,
      );

      expect(result, 12);
    });
  });

  group('Nur eine Richtung stellt eine Bedingung', () {
    test('nur Längenspanne: width=128, dLng=90° ergibt exakt Zoom 0 '
        '(von Hand: log2(128*360/(512*90)) = log2(1) = 0)', () {
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: 0, longitude: 0),
        northEast: MapPosition(latitude: 0, longitude: 90),
      );
      // Höhe bewusst weit von der Breite entfernt: vertauschte Breite und
      // Höhe im Fit gäben ein völlig anderes Ergebnis als 0.
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 128,
        heightInScreenPixels: 999999,
      );

      final double result = rectFitZoom(
        rect: rect,
        viewport: viewport,
        maxZoom: 20,
      );

      expect(result, closeTo(0, 1e-9));
    });

    test('nur Breitenspanne: Süd -45°, Nord 45°, height=1149,1324975906... '
        'ergibt exakt Zoom 3 (von Hand mit Python berechnet, siehe unten)', () {
      // Python, unabhängig von dart:math geschrieben:
      //   y(phi) = (1 - log(tan(pi/4 + radians(phi)/2)) / pi) / 2
      //   y(45)  = 0.35972503691520497
      //   y(-45) = 0.640274963084795
      //   dY     = 0.28054992616959007
      //   height = 512 * dY * 2**3 = 1149.132497590641
      //   log2(height / (512*dY)) = 3.0
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: -45, longitude: 7),
        northEast: MapPosition(latitude: 45, longitude: 7),
      );
      // Breite bewusst weit von der Höhe entfernt, aus demselben Grund wie
      // oben.
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 999999,
        heightInScreenPixels: 1149.132497590641,
      );

      final double result = rectFitZoom(
        rect: rect,
        viewport: viewport,
        maxZoom: 20,
      );

      expect(result, closeTo(3, 1e-6));
    });
  });

  group('Beide Richtungen stellen eine Bedingung, das Minimum gewinnt', () {
    test('Länge liefert die kleinere Zahl (2 gegen 5), Ergebnis ist 2', () {
      // Python:
      //   width  = 4 * 512 * 5 / 360 = 28,444... -> log2(width*360/(512*5)) = 2
      //   phi=30: y(30)=..., y(-30)=..., dY=0.17484957628302977
      //   height = 512 * dY * 2**5 = 2864.73545782116 -> Zoom 5
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: -30, longitude: -2.5),
        northEast: MapPosition(latitude: 30, longitude: 2.5),
      );
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 28.444444444444443,
        heightInScreenPixels: 2864.73545782116,
      );

      final double result = rectFitZoom(
        rect: rect,
        viewport: viewport,
        maxZoom: 20,
      );

      expect(result, closeTo(2, 1e-6));
    });

    test('Breite liefert die kleinere Zahl (6 gegen 1), Ergebnis ist 1', () {
      // Python:
      //   width  = 2**6 * 512 * 5 / 360 = 455,1111... -> Zoom 6 für die Länge
      //   phi=20: dY = 0.1134388012771892
      //   height = 512 * dY * 2**1 = 116,16133250784173 -> Zoom 1 für die Breite
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: -20, longitude: -2.5),
        northEast: MapPosition(latitude: 20, longitude: 2.5),
      );
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 455.1111111111111,
        heightInScreenPixels: 116.16133250784173,
      );

      final double result = rectFitZoom(
        rect: rect,
        viewport: viewport,
        maxZoom: 20,
      );

      expect(result, closeTo(1, 1e-6));
    });
  });

  group('maxZoom klemmt nach oben, nie nach unten', () {
    test('ein errechneter Zoom über maxZoom wird auf maxZoom gekappt', () {
      // Dieselbe Geometrie wie „Länge liefert die kleinere Zahl", die dort
      // unklemmt 2 ergibt. Mit maxZoom 1 muss das Ergebnis 1 sein, nicht 2.
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: -30, longitude: -2.5),
        northEast: MapPosition(latitude: 30, longitude: 2.5),
      );
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 28.444444444444443,
        heightInScreenPixels: 2864.73545782116,
      );

      final double result = rectFitZoom(
        rect: rect,
        viewport: viewport,
        maxZoom: 1,
      );

      expect(result, closeTo(1, 1e-9));
    });

    test(
      'ein negatives Ergebnis bleibt negativ, es wird nicht auf 0 gehoben',
      () {
        // Python: width = 0.25 * 512 * 1000 / 360 = 355,55555...
        //   log2(width*360/(512*1000)) = log2(0.25) = -2
        final MapPositionRect rect = MapPositionRect(
          southWest: MapPosition(latitude: 0, longitude: -500),
          northEast: MapPosition(latitude: 0, longitude: 500),
        );
        final MapViewport viewport = MapViewport(
          widthInScreenPixels: 355.55555555555554,
          heightInScreenPixels: 999999,
        );

        final double result = rectFitZoom(
          rect: rect,
          viewport: viewport,
          maxZoom: 20,
        );

        expect(result, closeTo(-2, 1e-6));
        expect(result, lessThan(0));
      },
    );
  });

  group('Viewport mit Breite oder Höhe null oder negativ', () {
    // Vier Kombinationen, jede mit einem echten, nicht entarteten Rechteck:
    // ein Fehler darf nicht daran hängen, dass das Rechteck ohnehin schon
    // maxZoom ergeben hätte.
    final MapPositionRect rect = MapPositionRect(
      southWest: MapPosition(latitude: 48, longitude: 11),
      northEast: MapPosition(latitude: 49, longitude: 12),
    );

    for (final (String label, double width, double height)
        in <(String, double, double)>[
          ('Breite null', 0, 600),
          ('Höhe null', 800, 0),
          ('Breite negativ', -10, 600),
          ('Höhe negativ', 800, -10),
        ]) {
      test('$label ergibt maxZoom, nicht Infinity oder NaN', () {
        final MapViewport viewport = MapViewport(
          widthInScreenPixels: width,
          heightInScreenPixels: height,
        );

        final double result = rectFitZoom(
          rect: rect,
          viewport: viewport,
          maxZoom: 14,
        );

        expect(result, 14);
      });
    }
  });

  group('Breitengrade an den Polen werden vor der Rechnung geklemmt', () {
    test('ein Rechteck, das über die Klemmgrenze hinausreicht, ergibt '
        'dasselbe Ergebnis wie eines, das genau an ihr endet', () {
      // Python: dY bei ±85,051129° ist 1,0000000141803989, bei ±89° dagegen
      // 1,5092181842693426. Ohne Klemmung wären beide Ergebnisse
      // verschieden; mit Klemmung fallen sie zusammen, weil beide Eingaben
      // auf dieselben ±85,051129° geklemmt werden.
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 999999,
        heightInScreenPixels: 4000,
      );

      double zoomFor(double latitude) => rectFitZoom(
        rect: MapPositionRect(
          southWest: MapPosition(latitude: -latitude, longitude: 7),
          northEast: MapPosition(latitude: latitude, longitude: 7),
        ),
        viewport: viewport,
        maxZoom: 20,
      );

      final double atClampBoundary = zoomFor(85.051129);
      final double beyondClampBoundary = zoomFor(89);

      expect(atClampBoundary, closeTo(beyondClampBoundary, 1e-6));
    });

    test('die Klemmgrenze liegt oberhalb von 85 Grad, nicht tiefer', () {
      // **Die Probe darüber prüft nur, dass irgendwo geklemmt wird.** Die
      // Klemmkonstante von 85,051129 auf 84,051129 zu verschieben lief am
      // 31.08.2026 durch, gefunden von der unabhängigen Review. Diese
      // Zusicherung schließt das ein: 85,0 liegt **unter** der Klemmgrenze
      // und wird deshalb nicht geklemmt, 85,1 liegt darüber und wird es. Ein
      // Rechteck bis 85,0 spannt damit weniger als eines bis 85,1 und ergibt
      // eine echt höhere Zoomstufe. Läge die Grenze bei 85,0 oder tiefer,
      // fielen beide Ergebnisse **exakt** zusammen, und `greaterThan`
      // schlägt an.
      //
      // Zusammen mit der Probe darüber (85,051129 und 89 ergeben dasselbe,
      // was eine Grenze oberhalb von 85,051129 ausschließt) ist die
      // Konstante damit auf das Intervall zwischen 85,0 und 85,051129
      // eingegrenzt. Exakt festnageln kann eine Zusicherung sie nicht, ohne
      // die Zahl aus der Implementierung abzuschreiben, und das wäre
      // Muster 18.
      //
      // Der Abstand der beiden Ergebnisse ist klein, ein Bruchteil einer
      // Zoomstufe. Eine Zahl dafür steht hier bewusst nicht: die Zusicherung
      // braucht nur die **Richtung**, und eine hingeschriebene Größenordnung
      // wäre eine Behauptung, die niemand nachgerechnet hat.
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 999999,
        heightInScreenPixels: 4000,
      );

      double zoomFor(double latitude) => rectFitZoom(
        rect: MapPositionRect(
          southWest: MapPosition(latitude: -latitude, longitude: 7),
          northEast: MapPosition(latitude: latitude, longitude: 7),
        ),
        viewport: viewport,
        maxZoom: 20,
      );

      expect(zoomFor(85), greaterThan(zoomFor(85.1)));
    });

    test('genau am Pol bleibt das Ergebnis endlich', () {
      final MapPositionRect rect = MapPositionRect(
        southWest: MapPosition(latitude: -90, longitude: 7),
        northEast: MapPosition(latitude: 90, longitude: 7),
      );
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 999999,
        heightInScreenPixels: 4000,
      );

      final double result = rectFitZoom(
        rect: rect,
        viewport: viewport,
        maxZoom: 20,
      );

      expect(result.isNaN, isFalse);
      expect(result.isInfinite, isFalse);
    });
  });

  group('Vertauschte Ecken: zugesichert, nicht nur behauptet', () {
    test('welche Ecke zuerst genannt wird, ändert das Ergebnis nicht', () {
      // **Diese Zusicherung fehlte, und die Zusage stand trotzdem im
      // Vertrag.** Der Konstruktorkommentar von `MapPositionRect` sagt zu,
      // `rectFitZoom` behandle eine vertauschte Eingabe robust. Das Entfernen
      // von `.abs()` in `map_camera_fit.dart` lief am 31.08.2026 dennoch
      // durch alle 16 Proben dieser Datei, gefunden von der unabhängigen
      // Review. Der Grund: die vorhandene Probe auf vertauschte Ecken
      // vertauscht nur die **Länge** und lässt die Breitenspanne bei null,
      // also genau in dem Zweig, in dem `.abs()` gar nichts tut.
      //
      // Keine von Hand gerechnete Zahl, sondern eine Eigenschaft, die für
      // jede Formel gelten muss: die Reihenfolge der beiden Ecken ist keine
      // Information über die Größe des Rechtecks.
      final MapPosition south = MapPosition(latitude: 48, longitude: 11);
      final MapPosition north = MapPosition(latitude: 48.6, longitude: 11.2);
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 400,
        heightInScreenPixels: 400,
      );
      double zoomFor(MapPositionRect rect) =>
          rectFitZoom(rect: rect, viewport: viewport, maxZoom: 22);

      // **Wache gegen einen leer laufenden Test.** Bindet die Breitenspanne
      // in diesem Beispiel gar nicht, dann wäre die Gleichheit unten auch
      // ohne jede Behandlung der Vertauschung wahr, und die Probe prüfte
      // nichts. Deshalb zuerst der Beleg, dass die Breite hier wirklich die
      // kleinere der beiden Zoomstufen liefert: dasselbe Rechteck ohne
      // Breitenspanne muss weiter hineinzoomen dürfen.
      final double withoutLatitudeSpan = zoomFor(
        MapPositionRect(
          southWest: south,
          northEast: MapPosition(
            latitude: south.latitude,
            longitude: north.longitude,
          ),
        ),
      );
      final double ordered = zoomFor(
        MapPositionRect(southWest: south, northEast: north),
      );
      expect(ordered, lessThan(withoutLatitudeSpan));

      final double swapped = zoomFor(
        MapPositionRect(southWest: north, northEast: south),
      );
      expect(swapped, closeTo(ordered, 1e-12));
    });
  });

  group('Eigenschaften, unabhängig von jeder Konstante der Formel', () {
    test(
      'ein doppelt so breiter Viewport ergibt genau eine Zoomstufe mehr',
      () {
        // log2(2*w*k) - log2(w*k) = log2(2) = 1, für jedes k. Das gilt für
        // jede Kachelgröße und jede Längenspanne, die Konstante der
        // Implementierung kürzt sich heraus. Trifft trotzdem `512 auf 256`
        // nicht direkt, dafür sorgen die von Hand gerechneten Fälle oben.
        final MapPositionRect rect = MapPositionRect(
          southWest: MapPosition(latitude: 0, longitude: 0),
          northEast: MapPosition(latitude: 0, longitude: 15),
        );

        double zoomForWidth(double width) => rectFitZoom(
          rect: rect,
          viewport: MapViewport(
            widthInScreenPixels: width,
            heightInScreenPixels: 999999,
          ),
          maxZoom: 50,
        );

        final double narrower = zoomForWidth(333);
        final double doubled = zoomForWidth(666);

        expect(doubled - narrower, closeTo(1, 1e-9));
      },
    );

    test('ein größeres Rechteck ergibt keine höhere Zoomstufe', () {
      MapPositionRect rectWithLongitudeSpan(double dLng) => MapPositionRect(
        southWest: MapPosition(latitude: 0, longitude: 0),
        northEast: MapPosition(latitude: 0, longitude: dLng),
      );
      final MapViewport viewport = MapViewport(
        widthInScreenPixels: 500,
        heightInScreenPixels: 999999,
      );

      final double smallerRect = rectFitZoom(
        rect: rectWithLongitudeSpan(10),
        viewport: viewport,
        maxZoom: 50,
      );
      final double largerRect = rectFitZoom(
        rect: rectWithLongitudeSpan(20),
        viewport: viewport,
        maxZoom: 50,
      );

      expect(largerRect, lessThanOrEqualTo(smallerRect));
    });
  });
}
