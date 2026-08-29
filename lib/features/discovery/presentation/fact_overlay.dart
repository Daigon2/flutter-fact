/// Der Weg von den Fakten in die Kartensprache: aus einer Liste [Fact] wird
/// eine [MapOverlay].
///
/// Reine Funktion, ohne Karte und ohne Riverpod prüfbar. Genau darum steht sie
/// hier und nicht im Provider: die drei Regeln dieses Schrittes (Koordinate
/// vorhanden, Kategorie bekannt, Kennung als Zeichenkette) sind alles, was
/// zwischen einem Fakt und einem Ballon liegt, und jede von ihnen ist einzeln
/// zuzusichern.
library;

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Die Kennung der Fakt-Überlagerung.
///
/// Mit dem Feature davor, weil Überlagerungskennungen sich alle Features
/// teilen: zwei gleiche Kennungen überschreiben sich, und zwar lautlos.
const String factOverlayId = 'discovery.facts';

/// Gemeldet, wenn ein Fakt eine Kategorie trägt, die die Tabelle nicht kennt.
///
/// Der Rückfall auf `hist` ist Parität (`screen-map.jsx:260`) und wird nicht
/// angetastet. Ohne diese Meldung würde eine neu eingeführte Kategorie in den
/// Daten aber stillschweigend rot, und niemand erführe, dass die Aliastabelle
/// nachzuziehen ist.
const String unknownFactCategoryEvent = 'discovery.facts.unknown_category';

/// Wie eng Fakten zu einer Gruppe zusammengefasst werden.
///
/// `screen-map.jsx:1910-1912`: `cluster: true`, `clusterMaxZoom: 15`,
/// `clusterRadius: 70`. Beide Zahlen sind übernommen und nicht gewählt.
const MapOverlayGrouping factOverlayGrouping = MapOverlayGrouping(
  maxZoom: 15,
  radiusInScreenPixels: 70,
);

/// Ab welcher Zoomstufe die Fakten sichtbar sind.
///
/// Die vier Gruppen-Layer der Quelle tragen alle `minzoom: 11`
/// (`screen-map.jsx:1959`, `:1975`, `:1991`, `:2008`). Darunter zeigt die
/// Quelle statt der Gruppen einen Marker je Pilotstadt
/// (`screen-map.jsx:1805-1833`, `makeCityClusterEl`); der ist in diesem Schritt
/// ausdrücklich nicht gebaut.
///
/// **Hier gilt die Grenze für die ganze Überlagerung und nicht nur für die
/// Gruppen, und das ist eine kleine Abweichung.** Die Quelle setzt ihre
/// Einzelballons als DOM-Marker ohne jede Zoomgrenze; ein Fakt, der so allein
/// steht, dass er selbst auf Zoomstufe 5 keine Gruppe bildet, erscheint dort
/// über einem ganzen Land. Das ist eher eine Nebenwirkung ihres Aufbaus als
/// eine Absicht: unterhalb von 11 soll der Stadtmarker stehen, nicht ein
/// einzelner Ballon. Sobald die Stadt-Cluster gebaut sind, ist diese Zeile der
/// richtige Ort, um es noch einmal anzusehen.
const double factOverlayMinZoom = 11;

/// Übersetzt [facts] in die Überlagerung der Karte.
///
/// ## Drei Regeln, und alle drei sind belegt
///
/// 1. **Ein Fakt ohne Koordinate fällt heraus.** `FactCoordinates` ist bewusst
///    nullfähig (`Fact.coordinates`), die Quelle filtert genauso
///    (`screen-map.jsx:1892`: `f.lat != null && f.lng != null`), und im Backend
///    tut es `_team_generate_orders` auch.
/// 2. **Die Kategorie wird über die Aliastabelle abgebildet**, mit Rückfall auf
///    `hist` und einer Meldung, siehe [unknownFactCategoryEvent].
/// 3. **Der Sammelzustand ist heute immer „nicht gesammelt".** Es gibt keine
///    Quelle dafür, `features/collection` existiert nicht. Der Auslöser steht
///    bei [factNotCollectedState].
///
/// ## Keine Deckelung
///
/// Die Quelle zeigt ab Zoomstufe 16 nur die 25 nächsten Fakten
/// (`screen-map.jsx:2048-2056`). Ihr eigener Kommentar nennt als Grund den
/// Lag-Schutz im Browser, und dort ist jeder Ballon ein DOM-Element mit
/// eigenen CSS-Animationen. Nativ ist ein Punkt eine Zeile in einer
/// Vektorquelle. Der Grund fällt damit weg, und die Deckelung wird bewusst
/// nicht nachgebaut (entschieden von Janek am 29.08.2026).
MapOverlay factOverlayOf(
  Iterable<Fact> facts, {
  required DiagnosticSink diagnostics,
}) {
  final List<MapOverlayPoint> points = <MapOverlayPoint>[];
  final Set<String> unknownCategories = <String>{};

  for (final Fact fact in facts) {
    final FactCoordinates? coordinates = fact.coordinates;
    if (coordinates == null) {
      continue;
    }
    final String category = fact.canonicalCategory;
    final String? key = factCategoryKeyOrNull(category);
    if (key == null) {
      unknownCategories.add(category);
    }
    points.add(
      MapOverlayPoint(
        id: fact.id.value.toString(),
        position: MapPosition(
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        ),
        styleId: factBalloonStyleId(
          key ?? fallbackFactCategoryKey,
          factNotCollectedState,
        ),
        state: factNotCollectedState,
      ),
    );
  }

  if (unknownCategories.isNotEmpty) {
    final List<String> sorted = unknownCategories.toList()..sort();
    diagnostics.report(
      DiagnosticEvent(unknownFactCategoryEvent, <String, String>{
        'count': '${sorted.length}',
        // Die Kategorietexte selbst, nicht die Fakt-Kennungen: gebraucht wird
        // der fehlende Eintrag in der Aliastabelle, und der steht hier.
        'categories': sorted.join(','),
      }),
    );
  }

  return MapOverlay(
    id: factOverlayId,
    points: points,
    grouping: factOverlayGrouping,
    minZoom: factOverlayMinZoom,
  );
}
