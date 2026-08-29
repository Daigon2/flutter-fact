import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
// **Ausdrücklich der Import über die Grenze, und nur hier.** Regel 18 hält
// `features/` aus `map/presentation/` heraus, und der Produktivcode hält sich
// daran: `factBalloonZoomScale` und `overlayPointSizeExpression` sind zwei
// unabhängige Abschriften derselben Quellzeile (`screen-map.jsx:1799`). Genau
// deshalb braucht es **eine** Stelle, an der beide nebeneinander liegen und
// ihre Übereinstimmung geprüft wird. Ohne sie ist der erste Beleg für ein
// Auseinanderlaufen ein Sprung an der 150-Meter-Grenze, sichtbar nur am Gerät.
import 'package:fact_app/map/presentation/map_overlay_host.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Weg vom Fakt zum Punkt auf der Karte.
///
/// Reine Funktion, deshalb ohne Karte, ohne Riverpod und ohne Widget-Baum
/// prüfbar. Die drei Regeln stehen einzeln da: Koordinate vorhanden, Kategorie
/// bekannt, Kennung als Zeichenkette.
void main() {
  Fact factWith({
    int id = 1,
    String category = 'Historisch',
    double? latitude = 48.1351,
    double? longitude = 11.582,
  }) => Fact(
    id: FactId(id),
    content: FactText(title: 'Titel $id', category: category),
    coordinates: latitude == null || longitude == null
        ? null
        : FactCoordinates(latitude: latitude, longitude: longitude),
  );

  test('ein Fakt wird zu einem Punkt mit seiner Kennung als Zeichenkette', () {
    final MapOverlay overlay = factOverlayOf(<Fact>[
      factWith(id: 4711),
    ], diagnostics: const SilentDiagnosticSink());

    expect(overlay.id, factOverlayId);
    final MapOverlayPoint point = overlay.points.single;
    expect(point.id, '4711');
    expect(point.position.latitude, 48.1351);
    expect(point.position.longitude, 11.582);
    expect(point.styleId, 'fact.hist.uncollected');
    expect(point.state, factNotCollectedState);
  });

  test('ein Fakt ohne Koordinate fällt heraus', () {
    // `Fact.coordinates` ist bewusst nullfähig, die Quelle filtert genauso
    // (`screen-map.jsx:1892`), und `_team_generate_orders` im Backend
    // ebenfalls. Ein Punkt bei (0, 0) wäre im Golf von Guinea.
    final MapOverlay overlay = factOverlayOf(<Fact>[
      factWith(id: 1),
      factWith(id: 2, latitude: null, longitude: null),
      factWith(id: 3),
    ], diagnostics: const SilentDiagnosticSink());

    expect(overlay.points.map((MapOverlayPoint point) => point.id), <String>[
      '1',
      '3',
    ]);
  });

  test('eine unbekannte Kategorie fällt auf hist und wird gemeldet', () {
    // Der Rückfall ist Parität (`screen-map.jsx:260`), die Meldung ist es
    // nicht: ohne sie würde eine neu eingeführte Kategorie in den Daten
    // stillschweigend rot, und niemand zöge die Aliastabelle nach.
    final RecordingSink diagnostics = RecordingSink();
    final MapOverlay overlay = factOverlayOf(<Fact>[
      factWith(category: 'Raumfahrt'),
    ], diagnostics: diagnostics);

    expect(overlay.points.single.styleId, 'fact.hist.uncollected');
    expect(diagnostics.events, hasLength(1));
    expect(diagnostics.events.single.name, unknownFactCategoryEvent);
    expect(diagnostics.events.single.attributes['categories'], 'Raumfahrt');
  });

  test('gemeldet wird je unbekanntem Text einmal, nicht je Fakt', () {
    // 600 Fakten derselben unbekannten Kategorie sind ein Fehler, nicht 600.
    final RecordingSink diagnostics = RecordingSink();
    factOverlayOf(<Fact>[
      factWith(id: 1, category: 'Raumfahrt'),
      factWith(id: 2, category: 'Raumfahrt'),
      factWith(id: 3, category: 'Sport'),
    ], diagnostics: diagnostics);

    expect(diagnostics.events, hasLength(1));
    expect(
      diagnostics.events.single.attributes['categories'],
      'Raumfahrt,Sport',
    );
    expect(diagnostics.events.single.attributes['count'], '2');
  });

  test('bekannte Kategorien melden nichts', () {
    final RecordingSink diagnostics = RecordingSink();
    factOverlayOf(<Fact>[
      factWith(id: 1, category: 'Kirche & Glaube'),
      factWith(id: 2, category: 'Food & Drink'),
    ], diagnostics: diagnostics);

    expect(diagnostics.events, isEmpty);
  });

  test('die Kategorie bestimmt das Bild', () {
    final MapOverlay overlay = factOverlayOf(<Fact>[
      factWith(id: 1, category: 'Kirche & Glaube'),
      factWith(id: 2, category: 'Food & Drink'),
    ], diagnostics: const SilentDiagnosticSink());

    expect(
      overlay.points.map((MapOverlayPoint point) => point.styleId),
      <String>['fact.kirche.uncollected', 'fact.kul.uncollected'],
    );
  });

  test('die Gruppierung trägt die Zahlen der Quelle', () {
    final MapOverlay overlay = factOverlayOf(
      const <Fact>[],
      diagnostics: const SilentDiagnosticSink(),
    );

    expect(overlay.grouping, factOverlayGrouping);
    expect(factOverlayGrouping.maxZoom, 15);
    expect(factOverlayGrouping.radiusInScreenPixels, 70);
    expect(overlay.minZoom, 11);
  });

  test('es gibt keine Deckelung bei 25 Punkten', () {
    // Die Quelle zeigt ab Zoom 16 nur die 25 nächsten (`screen-map.jsx:2048`),
    // ihr Kommentar nennt als Grund den Lag-Schutz im Browser: dort ist jeder
    // Ballon ein DOM-Element mit eigenen CSS-Animationen. Nativ ist ein Punkt
    // eine Zeile in einer Vektorquelle, der Grund fällt weg. Entschieden von
    // Janek am 29.08.2026.
    final MapOverlay overlay = factOverlayOf(<Fact>[
      for (int id = 1; id <= 200; id++) factWith(id: id),
    ], diagnostics: const SilentDiagnosticSink());

    expect(overlay.points, hasLength(200));
  });

  test('ohne Fakten bleibt die Überlagerung leer und entsteht trotzdem', () {
    // Wichtig für das Entfernen: eine leere Überlagerung nimmt die vorige vom
    // Bild, ein `null` täte gar nichts.
    final MapOverlay overlay = factOverlayOf(
      const <Fact>[],
      diagnostics: const SilentDiagnosticSink(),
    );

    expect(overlay.points, isEmpty);
    expect(overlay.id, factOverlayId);
  });

  group('Die Punkte, die leben, fallen aus der nativen Liste', () {
    MapOverlay overlayWith(List<String> ids) => MapOverlay(
      id: factOverlayId,
      points: <MapOverlayPoint>[
        for (final String id in ids)
          MapOverlayPoint(
            id: id,
            position: const MapPosition(latitude: 48.1351, longitude: 11.582),
            styleId: factBalloonStyleId('hist', factNotCollectedState),
            state: factNotCollectedState,
          ),
      ],
      grouping: factOverlayGrouping,
      minZoom: factOverlayMinZoom,
    );

    test('die genannten Punkte fehlen, die anderen bleiben', () {
      // Ohne das Ausdünnen stünde jeder Ballon in Reichweite **doppelt** da:
      // einmal lebend als Widget, einmal als stehendes Bild darunter. Auffallen
      // würde es genau dann, wenn er wächst.
      final MapOverlay thinned = factOverlayWithout(
        overlayWith(<String>['1', '2', '3']),
        <String>{'2'},
      );

      expect(
        thinned.points.map((MapOverlayPoint point) => point.id).toList(),
        <String>['1', '3'],
      );
    });

    test('Gruppierung und Zoomgrenzen bleiben unangetastet', () {
      // Ein Punkt weniger heißt eine Gruppe mit einem Mitglied weniger, und
      // genau so soll es sein. Fiele hier die Gruppierung weg, zerfielen beim
      // ersten nahen Fakt **alle** Gruppen der Karte in Einzelballons.
      final MapOverlay thinned = factOverlayWithout(
        overlayWith(<String>['1', '2']),
        <String>{'1'},
      );

      expect(thinned.id, factOverlayId);
      expect(thinned.grouping, factOverlayGrouping);
      expect(thinned.minZoom, factOverlayMinZoom);
      expect(thinned.maxZoom, isNull);
    });

    test('ohne Kennungen kommt dieselbe Überlagerung zurück', () {
      // **Dieselbe und keine Kopie.** Jeder `setOverlay` schiebt das
      // vollständige GeoJSON über den Plattformkanal; eine gleich aussehende
      // Kopie wäre ein Kanalaufruf für nichts.
      final MapOverlay overlay = overlayWith(<String>['1']);

      expect(
        identical(factOverlayWithout(overlay, const <String>{}), overlay),
        isTrue,
      );
    });

    test('eine unbekannte Kennung nimmt nichts weg', () {
      final MapOverlay overlay = overlayWith(<String>['1']);

      expect(
        factOverlayWithout(overlay, <String>{'gibtsnicht'}).points,
        hasLength(1),
      );
    });
  });

  group('Die Zoomkurve gilt für beide Seiten', () {
    /// Wertet den `interpolate`-Ausdruck des Karten-Hosts von Hand aus.
    ///
    /// Damit steht hier keine dritte Abschrift der Kurve, sondern der Ausdruck
    /// selbst: die Stützstellen werden aus [overlayPointSizeExpression]
    /// **gelesen** und nicht wiederholt. Wer eine davon ändert, ändert damit
    /// auch die Erwartung, und der Vergleich unten fällt trotzdem, wenn die
    /// Flutter-Seite nicht mitgeht.
    double nativeScaleAt(double zoom) {
      const List<Object> expression = overlayPointSizeExpression;
      expect(expression[0], 'interpolate');
      expect(expression[1], <Object>['linear']);
      expect(expression[2], <Object>['zoom']);
      final double lowZoom = expression[3] as double;
      final double lowScale = expression[4] as double;
      final double highZoom = expression[5] as double;
      final double highScale = expression[6] as double;

      // MapLibre hält außerhalb der Stützstellen den jeweiligen Randwert.
      if (zoom <= lowZoom) {
        return lowScale;
      }
      if (zoom >= highZoom) {
        return highScale;
      }
      return lowScale +
          (highScale - lowScale) * (zoom - lowZoom) / (highZoom - lowZoom);
    }

    test('nativ und gezeichnet ergeben denselben Faktor', () {
      // **Die Falle dieses Schritts.** Auf Zoom 16 steht der Faktor bei 0,833
      // und nicht bei 1; wer ihn auf der Flutter-Seite vergisst, sieht den
      // Fehler erst am Gerät, als Sprung beim Überqueren der
      // 150-Meter-Grenze.
      for (double zoom = 10; zoom <= 20; zoom += 0.25) {
        expect(
          factBalloonZoomScale(zoom),
          closeTo(nativeScaleAt(zoom), 1e-9),
          reason: 'Zoom $zoom',
        );
      }
    });

    test('sie ist unten und oben geklammert', () {
      // `Math.max(0.42, Math.min(1.25, (z - 11) / 6))`
      // (`screen-map.jsx:1799`).
      expect(factBalloonZoomScale(0), 0.42);
      expect(factBalloonZoomScale(13.52), closeTo(0.42, 1e-9));
      expect(factBalloonZoomScale(18.5), closeTo(1.25, 1e-9));
      expect(factBalloonZoomScale(22), 1.25);
    });

    test('auf Zoom 16 steht sie bei 0,833 und nicht bei 1', () {
      // Die eine Zahl, die man hinschreiben muss, damit niemand „ab 16 ist es
      // eins" denkt.
      expect(factBalloonZoomScale(16), closeTo(5 / 6, 1e-9));
    });
  });
}

/// Eine Diagnose-Senke, die mitschreibt.
class RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}
