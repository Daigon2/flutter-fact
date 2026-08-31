/// Der `balloon`-Anker der Tutorial-Führung: der Fakt-Marker, der der
/// Rahmenmitte am nächsten liegt, `02_Frontend/app/screen-tour.jsx:193-222`
/// (selbst nachgezählt: der `if`-Zweig beginnt in Zeile 193 und schließt in
/// Zeile 222; der Kopfkommentar von `discovery_anchors.dart` nennt „193-224“,
/// Zeile 224 gehört aber schon zum nächsten Zweig, `user-marker`).
///
/// ## Die Regel der Quelle, in vier Schritten
///
/// 1. Alle `.maplibregl-marker` einsammeln.
/// 2. Zu kleine verwerfen, unter 30 mal 30 (der Nutzermarker ist rund 28 mal
///    28, Ballons 40 bis 54, Kommentar der Quelle auf derselben Zeile).
/// 3. Ausserhalb des Rahmens verwerfen, in beiden Achsen.
/// 4. Von den übrigen den nehmen, dessen Mittelpunkt der Rahmenmitte am
///    nächsten liegt, euklidisch. Ist keiner übrig, ein festes
///    Ersatzrechteck: `x = Breite × 0,45`, `y = Höhe × 0,55`, 38 mal 38.
///
/// Der Nutzermarker selbst existiert bei uns noch nicht (Schritt 18, hängt an
/// E-10); die 30-Pixel-Schwelle bleibt trotzdem Teil dieser Auswahlregel, weil
/// sie es in der Quelle auch ohne ihn ist, siehe unten.
///
/// ## Was hier anders ist als bei der Quelle, und warum
///
/// **Nativ und lebend sind bei uns getrennt, bei der Quelle nicht.** Nur die
/// Fakten innerhalb von 150 Metern werden bei uns als Flutter-Widgets über der
/// Karte gezeichnet (`fact_balloon_overlay.dart`), alles andere ist ein
/// nativer Symbol-Layer ohne eigenen `BuildContext`, den `AnchorTarget` nicht
/// anmelden kann. Die Quelle kennt diesen Unterschied nicht: jeder
/// ungruppierte Fakt ist dort derselbe DOM-Marker, ob nah oder fern
/// (`screen-map.jsx:2032-2046`, `syncDomBalloons`). Eine treue Auswahl muss
/// deshalb beide Mengen gleich behandeln und selbst projizieren, statt sich
/// auf die schon gezeichneten Bildschirmlagen von `FactBalloonOverlay` zu
/// verlassen, siehe [balloonAnchorCandidatesOf].
///
/// **Ein Fund beim Nachrechnen, der noch offen ist und den Janek entscheidet.**
/// Naheliegend wäre gewesen, jedem Kandidaten dieselbe Betonung null zu geben,
/// denn ein nativer Ballon hat ja keine Nutzerposition, die ihn wachsen lässt.
/// Das wäre aber nicht die Quelle. `coinRafTick` (`screen-map.jsx:2213-2323`)
/// setzt für jeden DOM-Marker die Kopfgröße auf 26 Pixel, solange er nicht
/// innerhalb von 150 Metern liegt, und wächst nur dort auf bis zu 48.
///
/// **Die Kopfgröße wird über `.coin-float-wrap` mit dem Zoomfaktor skaliert
/// (`syncDomBalloons`, `screen-map.jsx:2038` und `:2109-2110`), aber dieser
/// Zoomfaktor fasst die gemessene Markerbreite gar nicht an.** `.coin-head`
/// ist ein **Nachfahre** von `.coin-float-wrap`, nicht dasselbe Element, und
/// der Marker selbst ist `el` (`new mapboxgl.Marker({ element: el, anchor:
/// 'bottom' })`), ein Vorfahre von beiden. `getBoundingClientRect()` liefert
/// die Border-Box durch die Transformationen der **Vorfahren** des
/// gemessenen Elements; ein `transform` an einem Nachfahren ändert deren
/// Layout nie. Ein `transform: scale()` an `.coin-float-wrap` verkleinert
/// also die Anzeige des Kopfes, ohne die Breite zu ändern, die `el.
/// getBoundingClientRect()` (der Marker) meldet. Der Bodenschatten
/// (`.coin-shadow`, `sizePx * 0,9`, `:2269`) sitzt ausserdem als **Geschwister**
/// von `.coin-float-wrap` und nicht darunter, trägt also ohnehin nie den
/// Zoomfaktor. **Die gemessene Markerbreite eines ruhenden Ballons ist damit
/// konstant, nicht vom Zoom abhängig**: `max(26, 23,4) = 26`, immer unter 30.
/// Ein ferner, ruhender Ballon fällt in der Quelle deshalb **immer**, nicht
/// nur meistens, durch die 30-Pixel-Schwelle; die Quelle zeigt auf einen
/// Ballon nur, wenn der Nutzer nah genug steht, sonst auf das Ersatzrechteck.
///
/// **Diese Herleitung ist aus der CSS-Semantik hergeleitet und nicht am
/// laufenden Browser nachgemessen.** Ein Blick mit den Entwicklerwerkzeugen
/// auf die Markerbreite bei zwei Zoomstufen würde es in dreissig Sekunden
/// entscheiden; das ist bisher nicht geschehen.
///
/// **Und hier weicht dieser Bau von der so hergeleiteten Quelle ab, gemessen
/// und nicht nur behauptet:** [selectBalloonAnchorRect] misst
/// `FactBalloonMetrics(...).size`, und das ist bei Betonung 0 nicht der
/// 26-Pixel-Kopf, sondern die ganze Zeichenfläche samt 12 logischen Pixeln
/// durchsichtigem Schattenrand je Seite (`factBalloonWidth = 50`). Skaliert
/// mit dem Zoomfaktor ergibt das:
///
/// | Zoom | Breite | Gewählt |
/// |---|---|---|
/// | 14,5 | 29,17 | nein |
/// | 14,6 | 30,00 | ja |
/// | 16,0 | 41,67 | ja |
///
/// **Ab Zoom 14,6, bei jedem üblichen Gehzoom, wählt dieser Bau also ferne,
/// ruhende Ballons aus, wo die (so hergeleitete) Quelle immer auf das
/// Ersatzrechteck zeigt.** Ob der Pfeil auf einen echten fernen Ballon zeigen
/// darf oder ausschließlich auf das Ersatzrechteck, ist eine sichtbare
/// Verhaltensfrage. **Sie ist hier bewusst nicht entschieden** und liegt bei
/// Janek, nicht in diesem Kommentar; bis zur Antwort bleibt das Verhalten wie
/// gebaut.
///
/// Deshalb trägt [BalloonAnchorCandidate] trotzdem eine eigene Betonung: real
/// für jeden Ballon, der [FactProximityPoint] gerade als nah kennt, und null
/// für jeden nur geografisch ausgewählten. Das ist keine Häufigkeitsangabe,
/// sondern eine Übersetzung: die Quelle hat kein Konzept „nativ“, sie hat nur
/// „innerhalb von 150 Metern“ und „außerhalb“, und genau diese Grenze ist
/// [FactProximityPoint.emphasis]. Woran diese Übersetzung heute vorbeizielt,
/// steht oben.
///
/// ## Die bewusste Lücke: Gruppen werden hier nicht ausgeschlossen
///
/// Unterhalb von `factOverlayGrouping.maxZoom` (15) fasst MapLibre nahe Fakten
/// nativ zu einer Gruppe mit einer Zahl zusammen, und ein gruppierter Fakt hat
/// in der Quelle **keinen** eigenen DOM-Marker
/// (`screen-map.jsx:2043-2045`, gefiltert über `['!', ['has', 'point_count']]`).
/// Diese Datei kennt den Gruppierungszustand einzelner Fakten nicht: es gibt
/// keinen Vertrag, über den `map/domain/` beantworten könnte, welches Feature
/// der native Cluster-Algorithmus gerade zusammengefasst hat, und ihn hier
/// nachzubauen hieße, MapLibres Gruppierung ein zweites Mal zu schreiben, mit
/// echtem Risiko, dass beide Seiten auseinanderlaufen. **Diese Auswahl kann
/// deshalb unterhalb von Zoom 15 einen Fakt wählen, der gerade in einer Gruppe
/// steckt**, während die Quelle dort korrekt nichts fände. Oberhalb von Zoom 15
/// gruppiert MapLibre gar nicht mehr (dieselbe Grenze, die `factAnimationRunsAt`
/// schon nutzt), und dort ist diese Auswahl exakt. Wer das schließen will,
/// braucht zuerst eine Antwort auf die Frage, ob `map/domain/` den
/// Gruppierungszustand einzelner Punkte überhaupt melden soll; das ist eine
/// Erweiterung des Kartenvertrags und keine, die diese Datei allein
/// entscheidet.
///
/// ## Ein Fakt hinter der Kamera
///
/// Ein solcher Punkt fällt aus dem Wettbewerb heraus, weil
/// `MapScreenPoint.isInFrontOfCamera` es sagt; [selectBalloonAnchorRect] prüft
/// das Feld und rechnet nichts nach.
///
/// **Bis zum 31.08.2026 stand hier eine halbe Seite darüber, dass der Vertrag
/// diese Aussage nicht macht.** Er macht sie jetzt (D-17,
/// `map_screen_point.dart` und `map_camera_horizon.dart`), und das war für
/// diese Datei die teuerste der drei Folgen: in `fact_balloon_overlay.dart`
/// zeichnete ein gespiegelter Punkt einen Ballon an falscher Stelle, ein
/// optischer Aussetzer, hier konnte derselbe Punkt den Wettbewerb um die
/// Rahmenmitte **gewinnen** und zum Tutorial-Ziel werden. Eine Spiegelung an
/// der Kameraachse zieht gespiegelte Punkte nämlich in Richtung Bildmitte
/// statt an den Rand, sie sind also nicht bloß falsch, sie sind bevorzugt
/// falsch.
library;

import 'dart:async';

import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wie viele geografisch nächste Fakten der Überlagerung als Kandidaten
/// zusätzlich zu den lebenden Ballons geprüft werden.
///
/// ## Warum es diese Zahl überhaupt braucht
///
/// `MapHost.projectToScreen` kostet einen Plattformkanal-Umlauf. Alle Fakten
/// einer Stadt (heute rund 700) bei jeder Kamerabewegung zu projizieren, nur
/// um hinterher eine Handvoll zu behalten, wäre teuer und unnötig: eine
/// geografische Vorauswahl über `MapPosition.distanceInMetersTo` kostet keinen
/// Kanal und reicht, um die Kandidaten auf die Kameramitte einzugrenzen.
///
/// ## Warum 25, und was diese Zahl wirklich trägt
///
/// Kein neu gewählter Wert, sondern derselbe Präzedenzfall wie in
/// `fact_proximity.dart`s `factAnimationRunsAt`: die Quelle selbst schneidet
/// beim Gehzoom auf die 25 zur Kartenmitte nächsten Features zu
/// (`screen-map.jsx:2050-2056`). Der Grund dort ist ein anderer (Lag-Schutz
/// bei 600 DOM-Knoten) als hier (Bildschirmabstand statt Kanalkosten), die
/// Größenordnung beantwortet aber dieselbe Frage: wie viele der nächsten
/// Punkte reichen, um die Umgebung eines Zentrums verlässlich zu vertreten.
///
/// **Was diese Zahl in der Praxis trägt, hängt an der offenen Verhaltensfrage
/// im Kopfkommentar dieser Datei.** Bestünde dieser Bau exakt wie die (so
/// hergeleitete) Quelle, bestünde ein rein geografisch ausgewählter, ruhender
/// Kandidat die 30-Pixel-Schwelle nie, und diese 25 wären nur ein Netz für
/// einen Fall, den es dann gar nicht gäbe. Gemessen an dem, was tatsächlich
/// gebaut ist, gilt das Gegenteil: ein solcher Kandidat besteht die Schwelle
/// schon ab Zoom 14,6, bei jedem üblichen Gehzoom, und diese 25 tragen dann
/// das übliche Auswahlergebnis mit, nicht nur einen Randfall.
///
/// **Die Garantie, die diese Zahl gibt, und wo sie wirklich endet.** Hier
/// stand zuerst eine falsch benannte Bedingung: „die Garantie hält, sobald im
/// sichtbaren Ausschnitt mindestens 25 Fakten liegen". Das genügt nicht: dass
/// 25 Fakten sichtbar sind, sagt nichts darüber, ob die 25 geografisch
/// nächsten genau diese 25 sind. Richtig lautet die hinreichende Bedingung:
/// **die 25 geografisch nächsten Fakten enthalten jeden tatsächlich
/// sichtbaren Fakt.** Und genau die bricht bei geneigter Kamera: der
/// sichtbare Bereich ist bei 58 Grad ein unsymmetrisches Trapez und kein
/// Kreis um die Kameramitte. Ein Fakt direkt hinter der Kamera ist
/// geografisch nah und trotzdem nicht sichtbar (dass er es nicht ist, sagt
/// seit D-17 `MapScreenPoint.isInFrontOfCamera`, seine Zahlen sagen es nicht);
/// ein Fakt weit voraus Richtung
/// Horizont ist geografisch fern und sehr wohl sichtbar. Die geografische
/// Vorauswahl ist eine reine Entfernungsprüfung und keine Sichtbarkeitsprüfung,
/// sie kennt die Neigung nicht. Das macht 25 nicht zu einer schlechten Zahl,
/// bei den Dichten der Pilotstädte dürfte die Lücke zwischen Entfernungs-Rang
/// und Sichtbarkeits-Rang meist klein bleiben, aber das ist eine unbelegte
/// Vermutung und keine bewiesene Garantie. Eine echte Garantie bräuchte eine
/// Vorauswahl gegen den sichtbaren Ausschnitt, nicht gegen die Luftlinie.
const int discoveryBalloonAnchorCandidateCount = 25;

/// Unter dieser Breite oder Höhe gilt ein Marker als zu klein für dieses Ziel.
///
/// `screen-tour.jsx:201`: `if (r.width < 30 || r.height < 30) return;`.
const double discoveryBalloonAnchorMinMarkerSize = 30;

/// Anteil der Rahmenbreite, an dem das Ersatzrechteck steht,
/// `screen-tour.jsx:219`: `x: frect.width * 0.45`.
const double discoveryBalloonAnchorFallbackXFraction = 0.45;

/// Anteil der Rahmenhöhe, an dem das Ersatzrechteck steht,
/// `screen-tour.jsx:219`: `y: frect.height * 0.55`.
const double discoveryBalloonAnchorFallbackYFraction = 0.55;

/// Seitenlänge des quadratischen Ersatzrechtecks,
/// `screen-tour.jsx:219`: `w: 38, h: 38`.
const double discoveryBalloonAnchorFallbackSize = 38;

/// Das feste Rechteck, wenn kein Ballon als Ziel taugt.
///
/// `screen-tour.jsx:217-220`, der `else`-Zweig: kein Treffer unter den Markern
/// heißt „Frame-Mitte unten“, nicht „kein Ziel“. [frameSize] ist dieselbe
/// Fläche, gegen die auch [selectBalloonAnchorRect] misst.
Rect discoveryBalloonAnchorFallbackRect(Size frameSize) => Rect.fromLTWH(
  frameSize.width * discoveryBalloonAnchorFallbackXFraction,
  frameSize.height * discoveryBalloonAnchorFallbackYFraction,
  discoveryBalloonAnchorFallbackSize,
  discoveryBalloonAnchorFallbackSize,
);

/// Ein möglicher Zielpunkt des `balloon`-Ankers: eine Position und die
/// Betonung, mit der sein Marker gerade gezeichnet würde.
///
/// [emphasis] ist 0 für jeden nur geografisch ausgewählten (fernen) Fakt und
/// der reale Wert für einen lebenden Ballon innerhalb von 150 Metern, siehe
/// [FactProximityPoint.emphasis]. Der Unterschied trägt in der Quelle die
/// 30-Pixel-Schwelle, nicht der Zoom, siehe der Kopfkommentar dieser Datei.
@immutable
class BalloonAnchorCandidate {
  /// Erzeugt einen Kandidaten.
  const BalloonAnchorCandidate({required this.position, this.emphasis = 0});

  /// Wo der Fakt liegt.
  final MapPosition position;

  /// Wie stark sein Marker gerade betont ist, 0 bis 1.
  final double emphasis;

  @override
  bool operator ==(Object other) =>
      other is BalloonAnchorCandidate &&
      other.position == position &&
      other.emphasis == emphasis;

  @override
  int get hashCode => Object.hash(position, emphasis);
}

/// Die [count] geografisch nächsten Punkte von [points] zu [center],
/// aufsteigend nach Entfernung.
///
/// Reine Vorauswahl vor der einzigen Projektion, siehe
/// [discoveryBalloonAnchorCandidateCount]. Eine Kategorie- oder
/// Sammelzustandsprüfung wie in `factProximityOf` ist hier nicht nötig:
/// `factOverlayOf` löst jede Kennung mit Rückfall auf `hist` auf, und einen
/// zweiten Sammelzustand gibt es noch nicht.
List<MapOverlayPoint> nearestOverlayPointsTo(
  List<MapOverlayPoint> points,
  MapPosition center, {
  int count = discoveryBalloonAnchorCandidateCount,
}) {
  final List<MapOverlayPoint> sorted = List<MapOverlayPoint>.of(points)
    ..sort(
      (MapOverlayPoint a, MapOverlayPoint b) => center
          .distanceInMetersTo(a.position)
          .compareTo(center.distanceInMetersTo(b.position)),
    );
  return sorted.length <= count ? sorted : sorted.sublist(0, count);
}

/// Baut die Kandidatenliste des `balloon`-Ankers: jeder lebende Ballon aus
/// [nearby] mit seiner echten Betonung, dazu die geografisch nächsten Punkte
/// von [overlay] mit Betonung 0, ohne Dopplung.
///
/// Ein Fakt, der in [nearby] steht, kommt nicht ein zweites Mal mit Betonung 0
/// herein: [nearby] kennt die echte, größere Rolle, die dieser Ballon gerade
/// spielt.
List<BalloonAnchorCandidate> balloonAnchorCandidatesOf({
  required MapOverlay overlay,
  required MapPosition cameraCenter,
  required List<FactProximityPoint> nearby,
  int count = discoveryBalloonAnchorCandidateCount,
}) {
  final Map<String, BalloonAnchorCandidate> byId =
      <String, BalloonAnchorCandidate>{
        for (final FactProximityPoint point in nearby)
          point.id: BalloonAnchorCandidate(
            position: point.position,
            emphasis: point.emphasis,
          ),
      };
  for (final MapOverlayPoint point in nearestOverlayPointsTo(
    overlay.points,
    cameraCenter,
    count: count,
  )) {
    byId.putIfAbsent(
      point.id,
      () => BalloonAnchorCandidate(position: point.position),
    );
  }
  return byId.values.toList();
}

/// Wählt aus bereits projizierten Bildschirmlagen die eine, die der
/// Rahmenmitte am nächsten liegt, oder gibt `null` zurück, wenn keine taugt.
///
/// `screen-tour.jsx:193-222`, in dieser Reihenfolge geprüft:
///
/// 0. Ein Punkt ohne Bildschirmlage fällt weg, und seit D-17 auch einer, der
///    laut `MapScreenPoint.isInFrontOfCamera` hinter der Kamera liegt. **In
///    der Quelle steht diese Stufe nicht**, und warum sie dort fehlt, ist
///    hier ausdrücklich **nicht** geprüft: ob MapLibre GL JS einen DOM-Marker
///    hinter der Kamera von selbst versteckt, wäre am laufenden Browser in
///    einer Minute zu sehen und ist es nicht. Die Stufe steht hier, weil der
///    eigene Vertrag die Aussage macht, nicht weil die Quelle sie verlangt.
/// 1. Ein zu kleiner Marker fällt weg, siehe [discoveryBalloonAnchorMinMarkerSize].
///    Die Größe folgt aus [BalloonAnchorCandidate.emphasis] und [zoom], genau
///    wie beim gezeichneten Ballon in `fact_balloon_overlay.dart`.
/// 2. Ein Marker, der den Rahmen gar nicht berührt, fällt weg.
/// 3. Von den übrigen gewinnt der euklidisch nächste Mittelpunkt zur
///    Rahmenmitte; bei Gleichstand der zuerst geprüfte, wie
///    `if (d < bestD)` in der Quelle es auch hält.
///
/// [candidates] und [screenPositions] gehören zusammen, Index für Index,
/// genau wie bei `MapHost.projectToScreen`s eigenem Vertrag. [frameSize] ist
/// die Kartenfläche in logischen Pixeln, [pixelRatio] die Umrechnung von
/// Geräte- auf logische Pixel für die Karten-Gerätepixel aus
/// [MapScreenPoint]. Das ist dieselbe Umrechnung, die in
/// `fact_balloon_overlay.dart` ausdrücklich „nirgendwo sonst“ stehen sollte;
/// hier steht sie ein zweites Mal, weil diese Auswahl denselben rohen
/// Kartenpunkt entgegennimmt und ihn nicht über den Zeichner beziehen kann,
/// ohne Regel 18 zu verletzen.
///
/// Die Verankerung folgt [FactBalloonMetrics.anchor]: die Unterkante,
/// mittig, sitzt auf dem Punkt, wie `icon-anchor: bottom` im Symbol-Layer.
Rect? selectBalloonAnchorRect({
  required List<BalloonAnchorCandidate> candidates,
  required List<MapScreenPoint?> screenPositions,
  required double zoom,
  required Size frameSize,
  required double pixelRatio,
}) {
  assert(
    candidates.length == screenPositions.length,
    'Kandidaten und Bildschirmlagen müssen dieselbe Reihenfolge tragen.',
  );
  final double zoomScale = factBalloonZoomScale(zoom);
  final Offset frameCenter = Offset(frameSize.width / 2, frameSize.height / 2);

  Rect? best;
  double bestDistanceSquared = double.infinity;
  for (int i = 0; i < candidates.length && i < screenPositions.length; i++) {
    final MapScreenPoint? at = screenPositions[i];
    if (at == null || !at.isInFrontOfCamera) {
      // Keine Bildschirmlage, oder eine, die hinter der Kamera liegt und
      // deshalb gespiegelt ist. **Die zweite Hälfte dieser Zeile ist die
      // wichtigere**: ein `null` verliert den Wettbewerb von selbst, ein
      // gespiegelter Punkt gewinnt ihn tendenziell, siehe den Kopfkommentar
      // dieser Datei unter „Ein Fakt hinter der Kamera“.
      continue;
    }
    final Size markerSize =
        FactBalloonMetrics(emphasis: candidates[i].emphasis).size * zoomScale;
    if (markerSize.width < discoveryBalloonAnchorMinMarkerSize ||
        markerSize.height < discoveryBalloonAnchorMinMarkerSize) {
      continue;
    }
    final Rect rect = Rect.fromLTWH(
      at.xInScreenPixels / pixelRatio - markerSize.width / 2,
      at.yInScreenPixels / pixelRatio - markerSize.height,
      markerSize.width,
      markerSize.height,
    );
    if (rect.right < 0 || rect.left > frameSize.width) {
      continue;
    }
    if (rect.bottom < 0 || rect.top > frameSize.height) {
      continue;
    }
    final double distanceSquared = (rect.center - frameCenter).distanceSquared;
    if (distanceSquared < bestDistanceSquared) {
      bestDistanceSquared = distanceSquared;
      best = rect;
    }
  }
  return best;
}

/// Meldet den `balloon`-Anker der Tutorial-Führung an, ohne selbst etwas zu
/// zeichnen.
///
/// ## Wo das im Baum sitzt, und warum
///
/// Muss im selben `Stack` wie die Kartenfläche liegen, aus demselben Grund wie
/// `FactBalloonOverlay`: `MapHost.projectToScreen` liefert Lagen relativ zur
/// linken oberen Ecke der Karte, nicht des Bildschirms.
///
/// ## Warum ein unsichtbares `AnchorTarget`, und keine Erweiterung der Registry
///
/// `AnchorRegistry.register` nimmt einen `BuildContext` entgegen und rechnet
/// das Rechteck erst beim Abfragen aus einem echten Renderobjekt aus (siehe
/// Kopfkommentar von `anchor_registry.dart`); ein schon berechnetes `Rect`
/// lässt sich dort nicht direkt anmelden. Der Ausweg ist ein `AnchorTarget`,
/// das an der berechneten Stelle, in der berechneten Größe, nichts zeichnet:
/// sein Renderobjekt ist das Rechteck, das `AnchorRegistry.rectOf`
/// zurückgibt, ohne dass `core/anchors/` einen zweiten Anmeldeweg braucht.
/// Dasselbe `Positioned` trägt auch das Ersatzrechteck der Quelle, siehe
/// [discoveryBalloonAnchorFallbackRect].
///
/// ## Warum hier ein Rahmenmass genügt, das nicht extra gemessen wird
///
/// Am 30.08.2026 am Gerät belegt (`REBUILD_STATUS.md`, „Ungefragter Fund A“):
/// die projizierte Kameramitte trifft die Mitte der Kartenfläche, und die
/// Kartenfläche deckt sich mit der Bildschirmgröße. `MediaQuery.sizeOf`
/// genügt deshalb als Rahmenmass, ohne einen eigenen Messlauf über
/// `LayoutBuilder`; dieselbe Größe wird für die Rahmenmitte, den
/// Rahmenfilter und das Ersatzrechteck benutzt, damit alle drei
/// übereinstimmen.
///
/// ## Warum hier trotzdem dauerhaft ein Kamera-Zuhörer hängt
///
/// Anders als beim Tutorial-Overlay selbst (das nur bei Schrittwechsel und
/// Größenänderung misst, siehe `tour_overlay.dart`) muss diese Klasse selbst
/// wissen, wo die Karte gerade steht, denn niemand sonst fragt sie danach. Der
/// Kamerastrom projiziert trotzdem nicht 600 Fakten je Bild: eine geografische
/// Vorauswahl (siehe [balloonAnchorCandidatesOf]) hält die Kandidatenzahl
/// klein, und dasselbe Zusammenfassungsmuster wie in `FactBalloonOverlay`
/// sorgt dafür, dass nie zwei Projektionen gleichzeitig unterwegs sind.
class DiscoveryBalloonAnchor extends ConsumerStatefulWidget {
  /// Erzeugt den Anker.
  const DiscoveryBalloonAnchor({super.key});

  @override
  ConsumerState<DiscoveryBalloonAnchor> createState() =>
      _DiscoveryBalloonAnchorState();
}

class _DiscoveryBalloonAnchorState
    extends ConsumerState<DiscoveryBalloonAnchor> {
  StreamSubscription<MapCameraView>? _cameraSubscription;

  double? _zoom;
  MapPosition? _cameraCenter;

  /// Das zuletzt gewählte Rechteck, oder `null` für das Ersatzrechteck.
  Rect? _rect;

  bool _selectionInFlight = false;
  bool _selectionPending = false;

  @override
  void initState() {
    super.initState();
    _cameraSubscription = ref
        .read(mapHostProvider)
        .cameraChanges
        .listen(_onCameraChange);
  }

  @override
  void dispose() {
    unawaited(_cameraSubscription?.cancel());
    _cameraSubscription = null;
    super.dispose();
  }

  void _onCameraChange(MapCameraView view) {
    _zoom = view.zoom;
    _cameraCenter = view.center;
    _requestSelection();
  }

  /// Wählt neu, wer der Rahmenmitte am nächsten liegt.
  ///
  /// Läuft schon eine Anfrage, wird nur gemerkt, dass danach noch eine fällig
  /// ist, genau wie bei `FactBalloonOverlay._requestProjection` und aus
  /// demselben Grund: bei bis zu 60 Kamerameldungen je Sekunde soll nie mehr
  /// als eine Projektion gleichzeitig unterwegs sein.
  void _requestSelection() {
    if (_selectionInFlight) {
      _selectionPending = true;
      return;
    }
    final double? zoom = _zoom;
    final MapPosition? center = _cameraCenter;
    if (zoom == null || center == null || zoom < factOverlayMinZoom) {
      // Unterhalb dieser Zoomstufe zeigt die Karte gar keine Fakten, siehe
      // `factOverlayMinZoom`; ein Treffer wäre hier unehrlich.
      _settle(null);
      return;
    }
    final MapOverlay? overlay = ref.read(factOverlayProvider).value;
    if (overlay == null) {
      _settle(null);
      return;
    }
    final List<BalloonAnchorCandidate> candidates = balloonAnchorCandidatesOf(
      overlay: overlay,
      cameraCenter: center,
      nearby: ref.read(factProximityProvider).points,
    );
    if (candidates.isEmpty) {
      _settle(null);
      return;
    }

    _selectionInFlight = true;
    final MapHost host = ref.read(mapHostProvider);
    reportDetached(
      host
          .projectToScreen(<MapPosition>[
            for (final BalloonAnchorCandidate candidate in candidates)
              candidate.position,
          ])
          .then((List<MapScreenPoint?> located) {
            if (!mounted) {
              return;
            }
            final double? zoomNow = _zoom;
            if (zoomNow == null) {
              _settle(null);
              return;
            }
            _settle(
              selectBalloonAnchorRect(
                candidates: candidates,
                screenPositions: located,
                zoom: zoomNow,
                frameSize: MediaQuery.sizeOf(context),
                pixelRatio: MediaQuery.devicePixelRatioOf(context),
              ),
            );
          })
          .whenComplete(() {
            _selectionInFlight = false;
            if (!mounted) {
              return;
            }
            if (_selectionPending) {
              _selectionPending = false;
              _requestSelection();
            }
          }),
      origin: 'discovery.balloon_anchor.selection',
    );
  }

  void _settle(Rect? rect) {
    if (rect == _rect) {
      return;
    }
    setState(() => _rect = rect);
  }

  @override
  Widget build(BuildContext context) {
    // Zuhören und nicht beobachten, wie in `FactBalloonOverlay.build`: neue
    // Fakten oder eine neue Nachbarschaft sollen eine neue Auswahl anstossen,
    // aber kein `watch` soll diesen unsichtbaren Anker bei jeder Änderung neu
    // aufbauen, ohne dass sich am Ergebnis etwas ändert.
    ref.listen(factOverlayProvider, (
      AsyncValue<MapOverlay>? previous,
      AsyncValue<MapOverlay> next,
    ) {
      if (next.value != null) {
        _requestSelection();
      }
    });
    ref.listen(factProximityProvider, (
      FactProximity? previous,
      FactProximity next,
    ) {
      _requestSelection();
    });

    final Size frameSize = MediaQuery.sizeOf(context);
    final Rect rect = _rect ?? discoveryBalloonAnchorFallbackRect(frameSize);

    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: AnchorTarget(
          anchorId: DiscoveryAnchors.balloon,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
