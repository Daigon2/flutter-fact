/// Die Auswahl des Startpunkts, gerechnet: `HotspotPickView` in
/// `02_Frontend/app/screen-challenge.jsx:2979-3102`.
///
/// ## Der Picker zeigt keine Karte
///
/// Das ist an der Quelle gemessen und nicht angenommen: `HotspotPickView` ist
/// eine Liste mit **höchstens vier** Radioknöpfen (`:3022-3038`,
/// `:3062-3086`). Die beiden `map`-Treffer in der Funktion sind
/// `Array.prototype.map`. Die Regel aus Schritt 12, dass ein Feature den
/// Karten-Host niemals selbst mountet, wird hier also gar nicht berührt.
///
/// ## Zwei verschiedene Dichten, und das ist die Falle
///
/// Die Quelle rechnet die Dichte **zweimal auf verschiedene Art**:
///
/// * Für „Hier wo ich bin" **zählt** sie Fakten im Umkreis von 600 Metern,
///   und zwar nur solche mit Koordinate und nicht leerem `puzzle_fit`
///   (`:2995-3001`). Die Schwellen sind 15 und 5 (`:3005-3007`).
/// * Für einen Hotspot **liest** sie das Feld `density` aus der kuratierten
///   Datei und bildet es auf eine Beschriftung ab (`:3014-3018`). Gezählt wird
///   dort nichts.
///
/// Beide Wege können „Hohe Faktendichte" ergeben, **mit verschiedenen
/// Zeichen**: `✓` bei der gezählten, `💎` bei der gelesenen. Gleiche Worte,
/// anderes Symbol. Das steht so in der Quelle und ist hier deshalb als zwei
/// getrennte Werte von [HuntDensityLabel] abgebildet und nicht als einer.
///
/// ## Warum hier keine Texte stehen
///
/// Regel 15: Geschäftsregeln hängen nicht an Lokalisierung. Diese Datei
/// liefert [HuntDensityLabel] und Minuten, die Zuordnung zu Sprachschlüsseln
/// macht `hunt_start_point_view.dart`. Nebeneffekt, der hier mehr wert ist als
/// die Regel: die ganze Rechnung ist ohne Widget prüfbar, und genau das ist
/// der Grund, warum sie nicht im Bildschirm steht.
library;

import 'package:fact_app/features/challenges/application/hunt_hotspot.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Umkreis der Zählung um die Nutzerposition, `screen-challenge.jsx:3004`.
const double huntLocalDensityRadiusInMeters = 600;

/// Ab so vielen Fakten im Umkreis gilt die Dichte als hoch, `:3005`.
const int huntHighDensityFactCount = 15;

/// Ab so vielen als mittel, `:3006`.
const int huntMediumDensityFactCount = 5;

/// Wie viele Hotspots höchstens angeboten werden, `:3011` und `:3012`.
const int huntHotspotOptionLimit = 3;

/// Gehgeschwindigkeit in km/h, `:3020`.
const double huntWalkingSpeedKmh = 4.5;

/// Umwegfaktor auf die Luftlinie, `:3020`.
///
/// Die Quelle rechnet `(m / 1000) / 4.5 * 60 * 1.3`, also Luftlinie in
/// Stunden, mal 60 zu Minuten, mal 1,3 für den Umweg gegenüber der Luftlinie.
const double huntWalkingDetourFactor = 1.3;

/// Die Beschriftungen, die die Quelle für die Dichte kennt.
///
/// Sieben Werte für zwei Rechenwege, siehe Kopf dieser Datei. Die Trennung ist
/// nicht kosmetisch: [localHigh] und [hotspotHigh] tragen denselben Satz mit
/// verschiedenen Zeichen.
enum HuntDensityLabel {
  /// „Hohe Faktendichte ✓", gezählt, `:3005`.
  localHigh,

  /// „Mittlere Dichte 🟡", gezählt, `:3006`.
  localMedium,

  /// „Wenig Fakten ⚠ — empfohlen sind dichte Gebiete", gezählt, `:3007`.
  localLow,

  /// „Sehr hohe Faktendichte 💎", gelesen, `:3015`.
  hotspotVeryHigh,

  /// „Hohe Faktendichte 💎", gelesen, `:3016`.
  hotspotHigh,

  /// „Mittlere Faktendichte ✨", gelesen, `:3017`.
  hotspotMedium,

  /// „Faktendichte", der Rückfall der Quelle für jeden anderen Wert, `:3018`.
  ///
  /// **Heute unerreichbar und trotzdem gebaut.** Die eingecheckte Datei kennt
  /// nur `sehr hoch`, `hoch` und `mittel` (21 Hotspots, nachgezählt vom
  /// Generator). Der Rückfall greift, sobald `compute_hotspots.py` die Datei
  /// überschreibt und dabei eine vierte Stufe schreibt. Ohne ihn stünde dort
  /// dann eine Ausnahme oder ein leeres Feld.
  hotspotUnknown,
}

/// Eine Zeile der Auswahl, `options` in `:3022-3038`.
class HuntStartOption {
  /// Erzeugt eine Zeile.
  const HuntStartOption({
    required this.point,
    required this.density,
    this.hotspotName,
    this.walkingMinutes,
  });

  /// Der Punkt, mit dem die Jagd erzeugt wird, `opt.point`.
  final MapPosition point;

  /// Die Dichte-Beschriftung dieser Zeile.
  final HuntDensityLabel density;

  /// Der Name des Hotspots, oder `null` für „Hier wo ich bin".
  ///
  /// Die Quelle unterscheidet dieselben zwei Fälle mit `isLocal` (`:3028`,
  /// `:3036`). Ein Name **und** ein Kennzeichen wären zwei Quellen für
  /// dieselbe Aussage; hier ist es eine.
  final String? hotspotName;

  /// Fußweg in Minuten, oder `null` ohne Nutzerposition.
  ///
  /// Die Quelle hängt den Zusatz nur an, wenn sie eine Position hat
  /// (`:3034`), und nie an „Hier wo ich bin".
  final int? walkingMinutes;

  /// Ist das die Zeile „Hier wo ich bin"?
  bool get isCurrentLocation => hotspotName == null;
}

/// Zählt die Fakten um [center], die ein Rätsel **und** eine Koordinate haben.
///
/// `countFactsNear`, `:2995-3001`. Zwei Dinge daran sind leicht zu übersehen:
///
/// * Der Filter verlangt `Array.isArray(f.puzzle_fit) && f.puzzle_fit.length >
///   0`, also mindestens ein Rätsel. Ein Fakt ohne Rätsel taugt nicht als
///   Station und darf die Dichte nicht schönen. Im Neubau ist das
///   [Fact.hasPuzzles].
/// * Gezählt wird über **alle** geladenen Fakten, `window.FACTS`, nicht über
///   die der Stadt. Das ist in der Quelle kein Zufall: `api.jsx:119` lädt alle
///   freigegebenen Fakten, und der Umkreis von 600 Metern grenzt schärfer ein
///   als jeder Stadtfilter. Der Aufrufer übergibt hier deshalb die
///   ungefilterte Liste.
///
/// Die Grenze ist `<=`, wie `<= radius_m` in `:2999`.
int countFactsWithPuzzlesNear(
  List<Fact> facts,
  MapPosition center, {
  double radiusInMeters = huntLocalDensityRadiusInMeters,
}) {
  var count = 0;
  for (final Fact fact in facts) {
    final coordinates = fact.coordinates;
    if (coordinates == null || !fact.hasPuzzles) {
      continue;
    }
    final MapPosition position = MapPosition(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
    if (center.distanceInMetersTo(position) <= radiusInMeters) {
      count++;
    }
  }
  return count;
}

/// Die Beschriftung zu einer gezählten Dichte, `:3005-3007`.
///
/// `>= 15` hoch, `>= 5` mittel, sonst wenig. Beide Grenzen sind einschließend.
HuntDensityLabel localDensityLabelOf(int factCount) {
  if (factCount >= huntHighDensityFactCount) {
    return HuntDensityLabel.localHigh;
  }
  if (factCount >= huntMediumDensityFactCount) {
    return HuntDensityLabel.localMedium;
  }
  return HuntDensityLabel.localLow;
}

/// Die Beschriftung zu einem gelesenen `density`-Wert, `:3014-3018`.
///
/// Der Vergleich ist exakt und ohne Trimmen, wie `d === 'sehr hoch'` in der
/// Quelle. Alles andere fällt auf [HuntDensityLabel.hotspotUnknown].
HuntDensityLabel hotspotDensityLabelOf(String density) => switch (density) {
  'sehr hoch' => HuntDensityLabel.hotspotVeryHigh,
  'hoch' => HuntDensityLabel.hotspotHigh,
  'mittel' => HuntDensityLabel.hotspotMedium,
  _ => HuntDensityLabel.hotspotUnknown,
};

/// Fußweg in Minuten, `walkMin` in `:3020`.
///
/// `Math.max(1, Math.round((m / 1000) / 4.5 * 60 * 1.3))`. Die Untergrenze 1
/// ist der Grund, warum ein Hotspot direkt vor der Nase nicht „~0 Min" sagt.
///
/// `Math.round` rundet in JavaScript zur nächsten Ganzzahl und bei genau `.5`
/// nach oben; Darts `round` rundet bei `.5` vom Nullpunkt weg. Für die hier
/// ausschließlich positiven Werte ist das dasselbe.
int walkingMinutesFor(double distanceInMeters) {
  final double minutes =
      (distanceInMeters / 1000) /
      huntWalkingSpeedKmh *
      60 *
      huntWalkingDetourFactor;
  final int rounded = minutes.round();
  return rounded < 1 ? 1 : rounded;
}

/// Baut die Zeilen der Auswahl, `:3022-3038`.
///
/// Reihenfolge und Länge sind Vertrag: höchstens vier Zeilen, „Hier wo ich
/// bin" immer zuerst und nur mit [userPosition], danach die bis zu drei
/// nächstgelegenen Hotspots.
///
/// **Ohne [userPosition] wird nicht sortiert**, die Quelle nimmt dann die
/// ersten drei in Dateireihenfolge (`:3012`). Das ist keine Nachlässigkeit:
/// eine Sortierung ohne Bezugspunkt hätte keinen Schlüssel.
List<HuntStartOption> huntStartOptions({
  required List<HuntHotspot> hotspots,
  required List<Fact> facts,
  MapPosition? userPosition,
}) {
  final List<HuntStartOption> options = <HuntStartOption>[];

  if (userPosition != null) {
    options.add(
      HuntStartOption(
        point: userPosition,
        density: localDensityLabelOf(
          countFactsWithPuzzlesNear(facts, userPosition),
        ),
      ),
    );
  }

  final List<HuntHotspot> nearest = userPosition == null
      ? hotspots.take(huntHotspotOptionLimit).toList()
      : _sortedByDistance(
          hotspots,
          userPosition,
        ).take(huntHotspotOptionLimit).toList();

  for (final HuntHotspot hotspot in nearest) {
    options.add(
      HuntStartOption(
        point: hotspot.position,
        density: hotspotDensityLabelOf(hotspot.density),
        hotspotName: hotspot.name,
        walkingMinutes: userPosition == null
            ? null
            : walkingMinutesFor(
                userPosition.distanceInMetersTo(hotspot.position),
              ),
      ),
    );
  }

  return options;
}

/// Sortiert aufsteigend nach Entfernung und **stabil**.
///
/// `Array.prototype.sort` ist seit ES2019 stabil, `List.sort` in Dart ist es
/// nicht. Bei zwei gleich weit entfernten Hotspots entschiede sonst die
/// Laufzeit, welcher in der Liste steht und welcher wegfällt. Der Index als
/// zweiter Schlüssel stellt die Dateireihenfolge wieder her.
List<HuntHotspot> _sortedByDistance(
  List<HuntHotspot> hotspots,
  MapPosition from,
) {
  final List<({HuntHotspot hotspot, double distance, int index})> ranked =
      <({HuntHotspot hotspot, double distance, int index})>[
        for (int i = 0; i < hotspots.length; i++)
          (
            hotspot: hotspots[i],
            distance: from.distanceInMetersTo(hotspots[i].position),
            index: i,
          ),
      ]..sort((
        ({HuntHotspot hotspot, double distance, int index}) a,
        ({HuntHotspot hotspot, double distance, int index}) b,
      ) {
        final int byDistance = a.distance.compareTo(b.distance);
        return byDistance != 0 ? byDistance : a.index.compareTo(b.index);
      });

  return <HuntHotspot>[
    for (final ({HuntHotspot hotspot, double distance, int index}) entry
        in ranked)
      entry.hotspot,
  ];
}
