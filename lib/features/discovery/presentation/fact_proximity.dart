/// Welche Fakten nah genug sind, um zu leben: die Näherungsrechnung der
/// Ballons und der Provider, der sie führt.
///
/// ## Was hier passiert
///
/// Eine reine Funktion, [factProximityOf], nimmt die fertige Überlagerung und
/// die Nutzerposition und beantwortet drei Fragen: **wer** liegt innerhalb der
/// 150 Meter, **wie stark** ist jeder betont, und **welcher** ist der nächste.
/// Alles Weitere, also Projektion, Drehung und Zeichnung, hängt daran.
///
/// ## Einmal je Ortung, nicht je Bild
///
/// Die Quelle rechnet die Entfernungen in `coinRafTick`, also 60-mal je
/// Sekunde (`screen-map.jsx:2213`, `:2229`, `:2248`). Das ist dort kein
/// Entwurf, sondern die Folge davon, dass es nur eine Schleife gibt. Hier
/// hängt die Rechnung an der **Ortung**: der Nutzer bewegt sich zwischen zwei
/// Bildern um Millimeter, und 600 Haversine-Rechnungen je Ortung sind
/// vernachlässigbar, 600 je Bild wären es nicht.
///
/// Was wirklich je Bild passieren muss, ist allein die Drehung, und die
/// braucht keine Entfernung mehr: ihr Tempo steht schon fest, sobald die
/// Betonung feststeht.
///
/// ## Warum das hier liegt und nicht in `notifiers/`
///
/// Weil reine Funktion und Provider hier fünf Zeilen auseinander stehen und
/// die eine ohne die andere nichts beantwortet. `fact_overlay.dart` und
/// `notifiers/fact_overlay_providers.dart` sind getrennt, weil dort ein
/// Repository dazwischen liegt; hier liegt nichts dazwischen.
library;

import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ab wie vielen Metern ein Fakt zu leben beginnt.
///
/// `screen-map.jsx:2207`: `const COIN_RADIUS = 150;`. **Einschließlich der
/// Kante nicht:** die Quelle prüft `dist < COIN_RADIUS` (`:2249`), genau
/// 150 Meter sind also außerhalb.
const double factProximityRadiusInMeters = 150;

/// Der Weg vom Ortungsdienst in die Kartensprache.
///
/// **Die Umrechnung passiert beim Verbraucher und nicht im Dienst.** Der
/// Ortungsdienst kennt keine Karte: gäbe er `MapPosition` heraus, hätte der
/// Karten-Host den Aufenthaltsort des Nutzers in seiner Vertragsfläche, und
/// das ist mit E-07 eine Sicherheitsfrage. Zwei Wertobjekte für denselben
/// Punkt sind der Preis dafür, siehe `DevicePosition`, dritte Instanz der
/// Geo-Typ-Sperre, und die offene Entscheidung D-9.
///
/// Öffentlich und nicht privat, damit ein Test die Richtung festnageln kann:
/// vertauschte Breite und Länge sähen in jedem Widget-Test gleich aus.
///
/// **Stand bis Schritt 17 in `pages/map_page.dart`.** Umgezogen, weil der
/// Provider dieser Datei sie braucht: ein Provider, der eine Seitendatei
/// importiert, zeigt in die falsche Richtung.
MapPosition mapPositionOf(DevicePosition fix) =>
    MapPosition(latitude: fix.latitude, longitude: fix.longitude);

/// Ein Fakt, der nah genug ist, um zu leben.
@immutable
final class FactProximityPoint {
  /// Erzeugt einen Nahpunkt.
  const FactProximityPoint({
    required this.id,
    required this.position,
    required this.style,
    required this.distanceInMeters,
  });

  /// Die Kennung des Fakts, dieselbe wie in der Überlagerung.
  final String id;

  /// Wo der Fakt liegt.
  final MapPosition position;

  /// Womit er gezeichnet wird.
  ///
  /// **Hier steht der Kategoriestil und nicht die Stil-Kennung**, weil der
  /// Zeichner Farbe und Zeichen braucht und nicht eine Zeichenkette. Aufgelöst
  /// wird sie einmal hier statt in jedem Bild.
  final FactCategoryStyle style;

  /// Wie weit der Nutzer entfernt ist, in Metern.
  final double distanceInMeters;

  /// Wie stark der Ballon betont ist, 0 am Rand und 1 auf dem Fakt.
  ///
  /// `screen-map.jsx:2254`: `const t = 1 - dist / COIN_RADIUS;`. Diese eine
  /// Zahl trägt alle vier Wirkungen: Größe, Zeichengröße, Bodenschatten und
  /// Drehtempo.
  double get emphasis => 1 - distanceInMeters / factProximityRadiusInMeters;

  @override
  bool operator ==(Object other) =>
      other is FactProximityPoint &&
      other.id == id &&
      other.position == position &&
      other.style == style &&
      other.distanceInMeters == distanceInMeters;

  @override
  int get hashCode => Object.hash(id, position, style, distanceInMeters);

  /// Ohne die Zahlen der Position, siehe `MapPosition.toString()`.
  ///
  /// **Und ohne die Entfernung**, denn die ist zusammen mit der öffentlich
  /// bekannten Fakt-Koordinate genau das, was `docs/engineering/security.md`
  /// §6 verbietet: sie legt den Aufenthaltsort des Nutzers auf einen Kreis
  /// von 150 Metern fest.
  @override
  String toString() => 'FactProximityPoint($id, ${style.key})';
}

/// Wer gerade nah ist, und wer davon der nächste.
@immutable
final class FactProximity {
  /// Erzeugt eine Nachbarschaft.
  const FactProximity({required this.points});

  /// Niemand ist nah. Der Zustand ohne Ortung und ohne Fakten.
  static const FactProximity empty = FactProximity(
    points: <FactProximityPoint>[],
  );

  /// Die Fakten in Reichweite, **aufsteigend nach Entfernung**.
  ///
  /// Die Reihenfolge ist Teil der Aussage und keine Bequemlichkeit: [nearest]
  /// liest den ersten Eintrag, und die Zeichenreihenfolge über der Karte soll
  /// den nächsten oben haben.
  final List<FactProximityPoint> points;

  /// Der nächste Fakt, oder `null`, wenn keiner in Reichweite ist.
  ///
  /// **Nur er hüpft.** Die Quelle hat das ausdrücklich nachgezogen, mit
  /// Begründung im Kommentar (`screen-map.jsx:2217-2220`): vorher animierten
  /// alle Marker, und auf dichten Karten sahen Nutzer „dauerndes Gehuepfe".
  FactProximityPoint? get nearest => points.isEmpty ? null : points.first;

  /// Ob [id] gerade in Reichweite ist.
  bool contains(String id) =>
      points.any((FactProximityPoint point) => point.id == id);

  /// Die Kennungen in Reichweite.
  Set<String> get ids =>
      points.map((FactProximityPoint point) => point.id).toSet();

  @override
  bool operator ==(Object other) =>
      other is FactProximity && _listsEqual(other.points, points);

  @override
  int get hashCode => Object.hashAll(points);

  @override
  String toString() => 'FactProximity(${points.length} in Reichweite)';
}

/// Wer von [overlay] innerhalb von 150 Metern um [user] liegt.
///
/// ## Drei Regeln, und alle drei sind belegt
///
/// 1. **Ohne Ortung ist niemand nah.** Die Quelle rechnet ihre Entfernung als
///    `pos ? haversine(...) : null` und behandelt `null` als außer Reichweite
///    (`screen-map.jsx:2248-2249`).
/// 2. **Gesammelte Fakten sind ausgenommen.** `screen-map.jsx:2245-2246`
///    bricht für sie ab, mit dem Kommentar „gold coins animate via CSS only",
///    und `:2226` nimmt sie schon aus der Suche nach dem nächsten heraus. Das
///    goldene Aussehen ist in diesem Schritt ausdrücklich nicht gebaut, der
///    **Ausschluss** ist es. Erkannt am Feld `MapOverlayPoint.state`, das
///    genau dafür schon im Vertrag steht.
/// 3. **Ein Punkt ohne auflösbaren Kategoriestil fällt heraus.** Zeichnen
///    ließe er sich ohnehin nicht, und er bleibt so in der nativen
///    Überlagerung stehen, wo ihn ein Symbol-Layer weiter zeichnet. Heute
///    unerreichbar: `factOverlayOf` setzt jede Kennung selbst und fällt auf
///    `hist` zurück.
///
/// Die Liste kommt **sortiert** heraus, siehe [FactProximity.points].
FactProximity factProximityOf(MapOverlay overlay, MapPosition? user) {
  if (user == null) {
    return FactProximity.empty;
  }

  final List<FactProximityPoint> near = <FactProximityPoint>[];
  for (final MapOverlayPoint point in overlay.points) {
    if (point.state != factNotCollectedState) {
      continue;
    }
    final double distance = user.distanceInMetersTo(point.position);
    if (distance >= factProximityRadiusInMeters) {
      continue;
    }
    final FactCategoryStyle? style = factBalloonCategoryOf(point.styleId);
    if (style == null) {
      continue;
    }
    near.add(
      FactProximityPoint(
        id: point.id,
        position: point.position,
        style: style,
        distanceInMeters: distance,
      ),
    );
  }

  near.sort(
    (FactProximityPoint a, FactProximityPoint b) =>
        a.distanceInMeters.compareTo(b.distanceInMeters),
  );
  return FactProximity(points: near);
}

/// Ob die Näherungs-Animation bei dieser Zoomstufe überhaupt läuft.
///
/// ## Warum es diese Bedingung gibt, und warum sie eine Näherung ist
///
/// **Die Quelle animiert nur, was als DOM-Marker existiert**, und ein Fakt
/// bekommt aus **zwei** Gründen keinen:
///
/// 1. **Er steckt in einer Gruppe.** `syncDomBalloons` fragt die Quelle mit
///    dem Filter `['!', ['has', 'point_count']]` ab
///    (`screen-map.jsx:2043-2045`), und `coinRafTick` läuft über genau diese
///    Marker (`:2224`, `:2234`).
/// 2. **Er ist nicht unter den 25 nächsten.** Ab Zoom 16 schneidet
///    `screen-map.jsx:2050-2056` die ungruppierten Features auf die 25 zur
///    **Kartenmitte** nächsten zu, ausdrücklich als Lag-Schutz. Genau
///    oberhalb der Gruppierungsgrenze greift also eine zweite Kante.
///
/// Beides lässt sich hier nicht abfragen. Welches Feature MapLibre gerade zu
/// einer Gruppe zusammengefasst hat, weiß nur das SDK, und die Antwort hinge
/// an einem Kanalaufruf je Kamerabild. Die Näherung ist stattdessen allein die
/// Zoomstufe: oberhalb von [MapOverlayGrouping.maxZoom] gruppiert MapLibre gar
/// nicht mehr.
///
/// **Sie hat damit zwei Kanten und ist nicht leer.** Unterhalb der Grenze
/// könnte ein einsam stehender Fakt ungruppiert bleiben und trotzdem nicht
/// animieren; dieser Rest ist klein, denn auf Zoom 15 sind 150 Meter rund 47
/// Bildschirmpixel und damit weniger als der Gruppierungsradius von 70. Wer so
/// nah steht, dass etwas leuchten würde, hat dort ohnehin eine Gruppe vor
/// sich. Ab Zoom 16 animieren hier dagegen **alle** in Reichweite, die Quelle
/// höchstens 25. Auch dieser Rest ist heute klein: in Reichweite
/// sind nur Fakten innerhalb von 150 Metern, und dass davon mehr als 25
/// ungruppiert nebeneinander liegen, setzt eine Dichte voraus, die München
/// nicht hat. **Der Grund für die Deckelung ist dort ohnehin ein anderer als
/// hier**: die Quelle schützt sich vor 600 DOM-Knoten, hier bleibt alles
/// jenseits der 150 Meter nativ.
///
/// **Diese eine Funktion beantwortet die Frage für beide Seiten**, für die
/// gezeichnete Überlagerung und für das Ausdünnen der nativen Punktliste.
/// Zwei Antworten wären zwei Gelegenheiten, sich zu widersprechen, und der
/// Widerspruch sähe aus wie ein Ballon, den es doppelt oder gar nicht gibt.
bool factAnimationRunsAt(double zoom) => zoom > factOverlayGrouping.maxZoom;

/// Wer gerade nah genug ist, um zu leben.
///
/// Hängt an der Ortung und an den geladenen Fakten, **nicht** an der Kamera:
/// Zoomen ändert keine Entfernung. Die Zoomfrage beantwortet
/// [factAnimationRunsAt] dort, wo die Kamera bekannt ist.
final Provider<FactProximity> factProximityProvider = Provider<FactProximity>((
  ref,
) {
  final MapOverlay? overlay = ref.watch(factOverlayProvider).value;
  if (overlay == null) {
    return FactProximity.empty;
  }
  // **Mit `select`, und das ist hier keine Kosmetik.** `UserLocationState` hat
  // bewusst keine Wertgleichheit, damit zwei Ortungen an derselben Stelle
  // zwei Ereignisse bleiben. Ohne `select` liefe diese Rechnung deshalb auch
  // dann erneut, wenn sich nichts bewegt hat.
  final DevicePosition? fix = ref.watch(
    userLocationProvider.select((UserLocationState state) => state.fix),
  );
  if (fix == null) {
    return FactProximity.empty;
  }
  return factProximityOf(overlay, mapPositionOf(fix));
});

/// Elementweiser Vergleich zweier Listen.
///
/// Steht als private Funktion in dieser Datei, wie in
/// `map/domain/map_overlay.dart` und aus demselben Grund: die eine geteilte
/// Fassung in `features/facts/domain/` ist von dort aus unerreichbar, und zwei
/// Aufrufer sind noch kein Anlass, sie nach `core` zu heben (ADR-002).
bool _listsEqual<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
