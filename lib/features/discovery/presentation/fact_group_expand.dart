/// Welche Punkte eine angetippte Gruppe „enthält": eine Näherung, kein
/// Nachbau der MapLibre-Gruppierung.
///
/// ## Warum das überhaupt eine Näherung ist
///
/// `getClusterLeaves` und `getClusterChildren` fehlen im Paket `maplibre_gl
/// 0.26.2`; das SDK sagt also **nicht**, welche Punkte in einer angetippten
/// Gruppe stecken. Gewählt wird stattdessen: die eigenen Punkte, deren
/// Bildschirmlage innerhalb des Gruppierungsradius um die getippte Stelle
/// liegt (`factOverlayGrouping.radiusInScreenPixels`, `fact_overlay.dart`).
///
/// ## Die Fehlerrichtung ist die sichere, und das ist der Grund für diese Wahl
///
/// Supercluster kettet, eine Gruppe kann also breiter sein als der Radius.
/// Diese Näherung wählt dann **zu wenige** Punkte, das Rechteck wird zu
/// klein, die Kamera fährt zu weit hinein. Zu weit hinein heißt: die Gruppe
/// geht auf. Zu wenig weit hinein hieße: der Nutzer muss noch einmal tippen,
/// und genau das hat D-12 bei Variante (a) verworfen, siehe der Kopfkommentar
/// von `map_camera_intents.dart`, „Vier Sorten". [groupExpandMinZoom]
/// (`fact_overlay.dart`) fängt den Fall auf, in dem diese Näherung trotzdem
/// zu vorsichtig bleibt, etwa bei einem geketteten Stadt-Cluster, das über
/// den Radius hinausreicht.
///
/// ## Zwei Einheiten, eine Umrechnung
///
/// `MapHost.projectToScreen` liefert **Gerätepixel** (`map_screen_point.dart`),
/// `factOverlayGrouping.radiusInScreenPixels` ist **Stilpixel**
/// (`map_overlay.dart`). Umgerechnet wird genau einmal, an derselben Stelle,
/// die `fact_balloon_overlay.dart:357` (dort) begründet: Stilpixel mal
/// Bildverhältnis ergibt Gerätepixel. Das ist dieselbe Umrechnung, nur
/// umgekehrt angewendet: dort wird durch das Verhältnis **geteilt**, um von
/// Geräte- auf Stilpixel zu kommen; hier wird der Stilpixel-Radius mit dem
/// Verhältnis **multipliziert**, um ihn ins Geräteraster der Projektion zu
/// heben, in dem [MapOverlayPoint]-Bildschirmlagen und die getippte Stelle
/// ohnehin schon liegen.
///
/// ## Ein Punkt hinter der Kamera
///
/// `MapHost.projectToScreen` liefert für einen Punkt hinter der Kamera keine
/// Ausnahme und kein `null`, sondern eine still gespiegelte Zahl, die wie
/// eine plausible Bildschirmlage aussieht (`REBUILD_STATUS.md`, „Die vier
/// Gerätemessungen"; dieselbe Lücke ist in `discovery_balloon_anchor.dart`
/// um Zeile 115 beschrieben, unter „Ein Fakt hinter der Kamera"). Ein solcher
/// Punkt kann hier in den Radius fallen und das Rechteck verfälschen: es
/// wird dann **zu groß**, die Fahrt zu vorsichtig, und [groupExpandMinZoom]
/// fängt genau diesen Fall auf. Diese Datei löst die Lücke nicht, sie erbt
/// sie, wie `discovery_balloon_anchor.dart` es für seine eigene Auswahl auch
/// tut.
library;

import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';

/// Gemeldet, wenn ein Tipp auf eine Gruppe der Fakt-Überlagerung keinen
/// einzigen eigenen Punkt im Gruppierungsradius findet.
///
/// ## Warum das ein Diagnose-Ereignis verdient, und keine stille Rückkehr
///
/// Ein Tipp auf eine Gruppe kommt nur zustande, weil MapLibre an dieser
/// Stelle einen Zahl- oder Kreis-Layer gezeichnet hat, also **selbst** meint,
/// dort läge eine Gruppe (siehe `MapHost.groupTaps`). Findet
/// [selectGroupMembers] dort keinen einzigen eigenen Punkt, widerspricht das
/// dem, was gerade auf dem Bildschirm stand: entweder hat sich die Näherung
/// (Radius, Umrechnung, projizierte Tippstelle) vergriffen, oder die
/// Überlagerung war zwischen dem Zeichnen und dem Tipp schon eine andere.
/// Beides ist wissenswert und keins davon ein Fehler des Nutzers, deshalb ein
/// Ereignis und keine stumme Rückkehr.
///
/// Gemeldet wird das vom Aufrufer (`pages/map_page.dart`), nicht hier: diese
/// Datei bleibt eine reine Funktion ohne `DiagnosticSink`.
const String groupTapFoundNoMembersEvent = 'discovery.group_tap.no_members';

/// Wählt aus [candidates] jene, deren Bildschirmlage im Gruppierungsradius um
/// [tapScreenPosition] liegt.
///
/// [candidates] und [candidateScreenPositions] gehören zusammen, Index für
/// Index, genau wie bei `MapHost.projectToScreen`s eigenem Vertrag. Ein
/// fehlender Bildschirmpunkt (`null`, siehe dort: außerhalb der Karte oder
/// hinter der Kamera) fällt heraus, er hat gerade keine Lage.
///
/// Ist [tapScreenPosition] `null`, entsteht **keine** Auswahl (leere Liste):
/// ohne eine Bildschirmlage der getippten Stelle selbst gibt es nichts,
/// wogegen verglichen werden könnte.
///
/// [radiusInStylePixels] ist `factOverlayGrouping.radiusInScreenPixels`, in
/// **Stilpixeln**; [pixelRatio] rechnet ihn in dasselbe Geräteraster um, in
/// dem [candidateScreenPositions] und [tapScreenPosition] liegen (siehe
/// Kopfkommentar dieser Datei, „Zwei Einheiten, eine Umrechnung").
List<MapOverlayPoint> selectGroupMembers({
  required List<MapOverlayPoint> candidates,
  required List<MapScreenPoint?> candidateScreenPositions,
  required MapScreenPoint? tapScreenPosition,
  required double radiusInStylePixels,
  required double pixelRatio,
}) {
  assert(
    candidates.length == candidateScreenPositions.length,
    'Kandidaten und Bildschirmlagen müssen dieselbe Reihenfolge tragen.',
  );
  final MapScreenPoint? tap = tapScreenPosition;
  if (tap == null) {
    return const <MapOverlayPoint>[];
  }

  final double radiusInScreenPixels = radiusInStylePixels * pixelRatio;
  final double radiusSquaredInScreenPixels =
      radiusInScreenPixels * radiusInScreenPixels;

  final List<MapOverlayPoint> selected = <MapOverlayPoint>[];
  for (
    int i = 0;
    i < candidates.length && i < candidateScreenPositions.length;
    i++
  ) {
    final MapScreenPoint? at = candidateScreenPositions[i];
    if (at == null) {
      continue;
    }
    final double dxInScreenPixels = at.xInScreenPixels - tap.xInScreenPixels;
    final double dyInScreenPixels = at.yInScreenPixels - tap.yInScreenPixels;
    final double distanceSquaredInScreenPixels =
        dxInScreenPixels * dxInScreenPixels +
        dyInScreenPixels * dyInScreenPixels;
    if (distanceSquaredInScreenPixels <= radiusSquaredInScreenPixels) {
      selected.add(candidates[i]);
    }
  }
  return selected;
}
