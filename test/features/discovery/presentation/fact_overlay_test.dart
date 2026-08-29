import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
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
}

/// Eine Diagnose-Senke, die mitschreibt.
class RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}
