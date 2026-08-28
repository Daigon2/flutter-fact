// Bäckt den FACT-Kartenstil aus dem Liberty-Stil von OpenFreeMap.
//
// Aufruf:
//   dart run tool/bake_map_style.dart          schreibt assets/map/fact_map_style.json
//   dart run tool/bake_map_style.dart --check  vergleicht nur, Exit-Code 1 bei Drift
//
// ── Warum gebacken und nicht zur Laufzeit umgefärbt ─────────────────────────
//
// Die PWA (`02_Frontend/app/screen-map.jsx`, Funktion `applyGameStyle`) färbt
// den Stil nach jedem `style.load` im Browser um. Sie ändert dabei je Layer
// genau **eine** Eigenschaft über `setPaintProperty` / `setLayoutProperty`.
//
// Beides gibt es in `maplibre_gl 0.26.2` nicht. Am Paket nachgesehen: null
// Treffer für `setPaintProperty`, null für `setLayoutProperty`. Was es gibt,
// ist `setLayerProperties(String layerId, LayerProperties properties)`, und
// dessen eigene Doku sagt: "NOTE: The properties will not skip null values, so
// setting a property to null will potentially reset it to default." Eine
// einzelne Eigenschaft ließe sich damit nur ändern, indem man für jeden der
// 111 Layer den vollständigen Eigenschaftssatz aus `getStyle()` zurückliest,
// neu aufbaut und über den Plattformkanal zurückschiebt.
//
// Deshalb: einmal backen, statisch, überprüfbar. Das Ergebnis liegt als Asset
// im Repository, `--check` meldet Drift.
//
// ── Warum der Ausgangsstil eingecheckt ist ──────────────────────────────────
//
// `tool/map_style/liberty_upstream.json` ist eine Kopie, kein Download zur
// Laufzeit. Ein Werkzeug, das bei jedem Lauf aus dem Netz lädt, erzeugt
// stillschweigend bei jedem Lauf ein anderes Ergebnis, und niemand sieht, wann
// sich der Anbieter geändert hat. Eingecheckt ist die Aktualisierung ein
// sichtbarer, reviewbarer Diff.
//
// Herkunft:
//   URL      https://tiles.openfreemap.org/styles/liberty
//   Abruf    29.08.2026, HTTP 200
//   Größe    43079 Bytes (eine Zeile, abschließendes LF)
//   SHA-256  6010998863b4876911ac9a2d62c9a28d97c8877f6d20cd158b74808572257b60
//   Inhalt   version 8, 111 Layer, Quellen `ne2_shaded` (raster) und
//            `openmaptiles` (vector)
//
// Die Prüfsumme steht hier nur als Beleg. Das Werkzeug prüft sie **nicht**
// nach: `package:crypto` steht nicht in `pubspec.yaml` (nur transitiv im
// Lockfile), und ein neues Paket wäre eine Freigabeentscheidung. Geprüft wird
// stattdessen die Bytezahl, siehe [_upstreamBytes]. Das fängt jeden
// versehentlichen Austausch, aber keine gezielte Fälschung.
//
// ── Was gebacken wird ───────────────────────────────────────────────────────
//
// Eine statische Umsetzung von `applyGameStyle` unter `PLAIN_MAP_LOOK = true`.
// Reihenfolge und Fallunterscheidungen sind aus `screen-map.jsx:361-641`
// übernommen, die Zeilennummern stehen an den einzelnen Schritten.
//
// **Achtung, die Falle dieses Schritts:** `screen-map.jsx:13` setzt
// `PLAIN_MAP_LOOK = true` und der Kommentar darüber liest sich, als schalte
// diese Zeile die ganze Spielgrafik ab. Sie kippt nur vier Dinge: den
// aufwendigen `buildings-game`-Extrusionslayer, den Kenney-3D-Layer und
// zweimal das Landmark-Overlay. `applyGameStyle` selbst läuft unbedingt bei
// jedem `style.load`. **Und die Häuser sind trotzdem sichtbar**: die Liste in
// `:370-375` blendet Libertys Gebäude-Layer aus, der große Durchlauf schaltet
// sie in `:502` wieder sichtbar und färbt sie um. Wer nur die erste Stelle
// liest, backt eine Karte ohne Häuser.
//
// `setLights` (`:627-641`) ist bewusst **nicht** portiert. Der Kommentar der
// Quelle sagt selbst "Mapbox-only API, no-op on MapLibre".
//
// ── Bekannte Abweichung von der Quelle ──────────────────────────────────────
//
// Die Quelle liest die Straßenbreite mit `map.getPaintProperty(id,
// 'line-width')` von der **laufenden** Karte. Die kann auch den Standardwert
// der Style-Spezifikation liefern, wenn der Layer selbst keinen trägt. Dieses
// Werkzeug liest aus dem JSON und sieht nur, was dort steht; fehlt
// `line-width`, wird der Layer übersprungen, wie es `if (w != null)` in `:587`
// tut. Am eingecheckten Ausgangsstil gemessen ist die Abweichung folgenlos:
// **alle 58 `transportation`-Linienlayer tragen eine eigene `line-width`**,
// die Zahl der übersprungenen Layer ist 0. Das Werkzeug zählt sie bei jedem
// Lauf mit und gibt sie aus, damit eine spätere Liberty-Version das nicht
// still ändert.

import 'dart:convert';
import 'dart:io';

/// Eingecheckte Kopie des Ausgangsstils. Wird nie überschrieben.
const upstreamPath = 'tool/map_style/liberty_upstream.json';

/// Gebackenes Ergebnis, als Asset in `pubspec.yaml` eingetragen.
const outputPath = 'assets/map/fact_map_style.json';

/// Erwartete Größe von [upstreamPath], gemessen mit LF-Zeilenenden.
///
/// Verglichen wird gegen den auf LF normalisierten Inhalt, nicht gegen die
/// Dateigröße auf der Platte: `core.autocrlf` steht in diesem Repository auf
/// `true` und macht beim Auschecken CRLF daraus.
///
/// Zeichenzahl und Bytezahl fallen hier zusammen, weil der Ausgangsstil
/// reines ASCII ist (nachgezählt: 0 Bytes über 127).
const _upstreamBytes = 43079;

// ── Palette, aus screen-map.jsx:459-477 ─────────────────────────────────────
// Namen wie in der Quelle, damit die Zuordnung beim Nachlesen erhalten bleibt.

/// `PG_GREEN_BASE`: helles Gras für Wohngebiet, Restflächen und Hintergrund.
const pgGreenBase = '#97D26E';

/// `PG_GREEN_PARK`: satteres Grün für Parks, Wald und Wiese.
const pgGreenPark = '#6CB845';

/// `PG_WATER`: Wasserflächen und Fließgewässer.
const pgWater = '#46A8E2';

/// `PG_BUILDING`: Häuser.
const pgBuilding = '#F1EBDB';

/// `PG_BUILDING_EDGE`: Hausumriss.
const pgBuildingEdge = '#D2C6AC';

/// `PG_BUILDING_H`: feste, niedrige Haushöhe.
const pgBuildingHeight = 3;

/// `PG_BUILDING_OP`: Deckkraft der Häuser, das Grün scheint durch.
const pgBuildingOpacity = 0.72;

/// `PG_ROAD`: Fahrbahn.
const pgRoad = '#FFFDF7';

/// `PG_ROAD_EDGE`: warmer Saum links und rechts der Fahrbahn.
const pgRoadEdge = '#E3CD93';

/// `ROAD_FILL_F`: Verbreiterung der Fahrbahn.
const roadFillFactor = 2.7;

/// `ROAD_CASE_F`: Verbreiterung des Casings, nur knapp mehr als die Fahrbahn.
const roadCaseFactor = 3.1;

// ── Muster, aus derselben Quelle ────────────────────────────────────────────

/// `screen-map.jsx:371`: Libertys eigene Gebäude-Layer, die zuerst verschwinden.
const _libertyBuildingLayerIds = <String>[
  'building',
  'building-3d',
  'building-top',
  '3d-buildings',
  'building-extrusion',
];

/// `screen-map.jsx:435`: Straßennamen und Ortslabels.
final _labelIdPattern = RegExp(
  'road|street|highway|name',
  caseSensitive: false,
);

/// `screen-map.jsx:501`: alles, was nach Gebäude aussieht.
final _buildingIdPattern = RegExp('building', caseSensitive: false);

/// `screen-map.jsx:521`: FACTs eigenes Landmark-Overlay.
final _landmarkIdPattern = RegExp('^landmark', caseSensitive: false);

/// `screen-map.jsx:529`: Verwaltungsgrenzen.
final _boundaryIdPattern = RegExp('boundary|admin', caseSensitive: false);

/// `screen-map.jsx:544`: Parks und alles Grüne innerhalb von `landcover` und
/// `landuse`.
final _parkIdPattern = RegExp(
  'wood|forest|park|grass|recreation|garden|pitch|cemetery|scrub',
  caseSensitive: false,
);

/// `screen-map.jsx:569`: Schienen, ÖPNV, Feldwege, Zufahrten, Fuß- und Gehwege.
final _hiddenTransportPattern = RegExp(
  'rail|transit|service|track|path|pedestrian',
  caseSensitive: false,
);

/// `screen-map.jsx:582`: Casing, also der Saum unter der Fahrbahn.
///
/// Ohne `caseSensitive: false`, weil die Quelle hier `/casing/` ohne `i`
/// schreibt. Die drei Zeilen darüber und darunter tragen das `i`, diese nicht.
final _casingIdPattern = RegExp('casing');

// ── Einstiegspunkt ──────────────────────────────────────────────────────────

void main(List<String> args) {
  final checkOnly = _parseArgs(args);

  final upstreamFile = File(upstreamPath);
  if (!upstreamFile.existsSync()) {
    stderr
      ..writeln('Ausgangsstil nicht gefunden: $upstreamPath')
      ..writeln(
        'Das Werkzeug läuft aus der Projektwurzel und lädt nichts aus dem '
        'Netz. Herkunft der Datei steht im Kopfkommentar.',
      );
    exit(2);
  }

  final upstreamText = _normalizeLineEndings(upstreamFile.readAsStringSync());
  if (upstreamText.length != _upstreamBytes) {
    stderr
      ..writeln(
        '$upstreamPath hat ${upstreamText.length} Zeichen, erwartet sind '
        '$_upstreamBytes.',
      )
      ..writeln(
        'Wenn der Austausch gewollt ist: _upstreamBytes und die '
        'Herkunftsangaben im Kopfkommentar mit anpassen, damit der Wechsel im '
        'Diff sichtbar bleibt.',
      );
    exit(2);
  }

  final upstream = _decodeStyle(upstreamText, upstreamPath);

  final report = BakeReport();
  final baked = bakeFactMapStyle(upstream, report: report);
  final rendered = renderStyleJson(baked);

  if (checkOnly) {
    _runCheck(rendered, report);
    return;
  }

  final outFile = File(outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(rendered);
  report.print();
  stdout.writeln('geschrieben: $outputPath (${rendered.length} Zeichen)');
}

bool _parseArgs(List<String> args) {
  var checkOnly = false;
  for (final arg in args) {
    if (arg == '--check') {
      checkOnly = true;
    } else {
      stderr
        ..writeln('Unbekanntes Argument: $arg')
        ..writeln('Erlaubt ist nur --check.');
      exit(2);
    }
  }
  return checkOnly;
}

void _runCheck(String rendered, BakeReport report) {
  final outFile = File(outputPath);
  if (!outFile.existsSync()) {
    stderr
      ..writeln('Kartenstil-Check: $outputPath fehlt.')
      ..writeln('Erzeugen: dart run tool/bake_map_style.dart');
    exit(1);
  }

  final current = _normalizeLineEndings(outFile.readAsStringSync());
  if (current == _normalizeLineEndings(rendered)) {
    report.print();
    stdout.writeln(
      'Kartenstil-Check: $outputPath stimmt mit dem Ausgangsstil überein.',
    );
    return;
  }

  final differences = describeStyleDrift(current, rendered);
  stderr.writeln(
    'Kartenstil-Check: $outputPath weicht vom gebackenen Ergebnis ab '
    '(${differences.length} Unterschied bzw. Unterschiede):',
  );
  for (final line in differences) {
    stderr.writeln('  $line');
  }
  stderr.writeln('Erneut erzeugen: dart run tool/bake_map_style.dart');
  exit(1);
}

// ── Der Backvorgang ─────────────────────────────────────────────────────────

/// Zählt mit, was der Durchlauf getroffen hat.
///
/// Kein Selbstzweck: die Zahlen sind der einzige Weg zu merken, dass eine neue
/// Liberty-Version einen Fall leerlaufen lässt. Ein Muster, das nichts mehr
/// trifft, ist optisch nicht von einem Muster zu unterscheiden, das nie etwas
/// getroffen hat.
class BakeReport {
  int hiddenLibertyBuildings = 0;
  int hiddenLabels = 0;
  int buildingsRestored = 0;
  int landmarksHidden = 0;
  int boundariesHidden = 0;
  int symbolsHidden = 0;
  int groundPark = 0;
  int groundBase = 0;
  int waterFills = 0;
  int waterwayLines = 0;
  int transportHidden = 0;
  int transportFills = 0;
  int transportLines = 0;
  int transportCasings = 0;
  int transportLinesWithoutWidth = 0;
  int untouched = 0;

  void print() {
    stdout
      ..writeln('Kartenstil gebacken:')
      ..writeln(
        '  Libertys Gebäude-Layer ausgeblendet: $hiddenLibertyBuildings',
      )
      ..writeln('  Label-Layer vorab ausgeblendet:      $hiddenLabels')
      ..writeln('  Gebäude wieder sichtbar gemacht:     $buildingsRestored')
      ..writeln('  Landmark-Layer ausgeblendet:         $landmarksHidden')
      ..writeln('  Grenz-Layer ausgeblendet:            $boundariesHidden')
      ..writeln('  Symbol-Layer ausgeblendet:           $symbolsHidden')
      ..writeln(
        '  Boden grün (Park / Basis):           $groundPark / $groundBase',
      )
      ..writeln(
        '  Wasser (Flächen / Linien):           $waterFills / $waterwayLines',
      )
      ..writeln('  Verkehr ausgeblendet:                $transportHidden')
      ..writeln('  Verkehr Flächen:                     $transportFills')
      ..writeln(
        '  Verkehr Linien (davon Casing):       $transportLines ($transportCasings)',
      )
      ..writeln(
        '  davon ohne eigene line-width:        $transportLinesWithoutWidth',
      )
      ..writeln('  vom Durchlauf nicht berührt:         $untouched');
    if (landmarksHidden == 0) {
      stdout.writeln(
        '  Hinweis: kein Layer passt auf /^landmark/i. Erwartet, das '
        'Landmark-Overlay ist FACTs eigenes und steht nicht im Liberty-Stil. '
        'Der Fall bleibt portiert, damit die Vorlage vollständig abgebildet '
        'ist.',
      );
    }
    if (transportLinesWithoutWidth > 0) {
      stdout.writeln(
        '  Achtung: $transportLinesWithoutWidth Verkehrslinie(n) ohne eigene '
        'line-width. Die bleiben schmal, weil hier der Style-Default nicht '
        'bekannt ist. Siehe "Bekannte Abweichung" im Kopfkommentar.',
      );
    }
  }
}

/// Erzeugt den FACT-Stil aus [upstream]. [upstream] wird nicht verändert.
Map<String, Object?> bakeFactMapStyle(
  Map<String, Object?> upstream, {
  BakeReport? report,
}) {
  final progress = report ?? BakeReport();
  final style = _deepCopyMap(upstream);

  // screen-map.jsx:362-368: ohne Vektorquelle steigt die Quelle stumm aus.
  // Hier ist das kein Grund zu schweigen: ein unverändert durchgereichter
  // Stil wäre ein Backvorgang, der nichts gebacken hat.
  final sources = style['sources'];
  if (sources is! Map<String, Object?>) {
    throw const FormatException('Der Stil hat keinen `sources`-Block.');
  }
  final vectorSource = sources.entries
      .where((entry) => _asMap(entry.value)['type'] == 'vector')
      .map((entry) => entry.key)
      .firstOrNull;
  if (vectorSource == null) {
    throw const FormatException(
      'Der Stil hat keine Vektorquelle. applyGameStyle baut den '
      'Gebäude-Umriss aus der `building` source-layer, mit Rasterkacheln gäbe '
      'es die nicht.',
    );
  }

  final layers = _layersOf(style);
  final byId = <String, Map<String, Object?>>{
    for (final entry in layers) _layerId(_asMap(entry)): _asMap(entry),
  };

  // 1) screen-map.jsx:370-375: Libertys Gebäude-Layer ausblenden, unbedingt.
  //    Der große Durchlauf unten macht sie wieder sichtbar. Beides steht so in
  //    der Quelle und beides bleibt hier stehen, damit der Diff die Vorlage
  //    abbildet und nicht ihr Ergebnis.
  for (final id in _libertyBuildingLayerIds) {
    final layer = byId[id];
    if (layer != null) {
      _setLayout(layer, 'visibility', 'none');
      progress.hiddenLibertyBuildings++;
    }
  }

  // 2) screen-map.jsx:428-440: Straßennamen und Ortslabels ausblenden.
  //    Schritt 3 blendet ohnehin jeden Symbol-Layer aus, dieser Schritt ist am
  //    heutigen Liberty-Stil also vollständig darin enthalten. Er bleibt
  //    trotzdem portiert: er wirkt vor Fall 1 des Durchlaufs, und ein
  //    Symbol-Layer, dessen `id` auf /building/i passt, käme dort wieder auf
  //    `visible`. Heute gibt es keinen solchen Layer.
  for (final entry in layers) {
    final layer = _asMap(entry);
    if (_layerType(layer) != 'symbol') {
      continue;
    }
    final sourceLayer = _sourceLayer(layer);
    final id = _layerId(layer);
    if (sourceLayer == 'transportation_name' ||
        sourceLayer == 'place' ||
        _labelIdPattern.hasMatch(id)) {
      _setLayout(layer, 'visibility', 'none');
      progress.hiddenLabels++;
    }
  }

  // 3) screen-map.jsx:493-599: ein autoritativer Durchlauf über alle Layer.
  //    Die Fallreihenfolge ist tragend, jeder Fall bricht ab.
  for (final entry in layers) {
    final layer = _asMap(entry);
    final id = _layerId(layer);
    final sourceLayer = _sourceLayer(layer);
    final type = _layerType(layer);

    // 3a) screen-map.jsx:501-517: Häuser als niedrige, gleich hohe, helle
    //     Klötzchen. Und zwar wieder **sichtbar**.
    if (sourceLayer == 'building' || _buildingIdPattern.hasMatch(id)) {
      _setLayout(layer, 'visibility', 'visible');
      progress.buildingsRestored++;
      if (type == 'fill-extrusion') {
        _setPaint(layer, 'fill-extrusion-color', pgBuilding);
        _setPaint(layer, 'fill-extrusion-height', pgBuildingHeight);
        _setPaint(layer, 'fill-extrusion-base', 0);
        _setPaint(layer, 'fill-extrusion-opacity', pgBuildingOpacity);
        // Weiche Schatten: keine harten dunklen Wände.
        _setPaint(layer, 'fill-extrusion-vertical-gradient', false);
      } else if (type == 'fill') {
        _setPaint(layer, 'fill-color', pgBuilding);
        _setPaint(layer, 'fill-opacity', pgBuildingOpacity);
      }
      continue;
    }

    // 3b) screen-map.jsx:521-524: FACTs eigenes Landmark-Overlay aus.
    //     Im Liberty-Stil gibt es das nicht, siehe Hinweis im Bericht.
    if (_landmarkIdPattern.hasMatch(id)) {
      _setLayout(layer, 'visibility', 'none');
      progress.landmarksHidden++;
      continue;
    }

    // 3c) screen-map.jsx:529-532: Verwaltungsgrenzen aus, die sind gestrichelt.
    if (sourceLayer == 'boundary' || _boundaryIdPattern.hasMatch(id)) {
      _setLayout(layer, 'visibility', 'none');
      progress.boundariesHidden++;
      continue;
    }

    // 3d) screen-map.jsx:535-538: alle Labels, POIs, Hausnummern und
    //     Einbahn-Pfeile aus. Alle Symbol-Layer, ohne Ausnahme.
    if (type == 'symbol') {
      _setLayout(layer, 'visibility', 'none');
      progress.symbolsHidden++;
      continue;
    }

    // 3e) screen-map.jsx:543-549: Boden, zwei Grüntöne.
    if (type == 'fill' &&
        (sourceLayer == 'landcover' ||
            sourceLayer == 'landuse' ||
            sourceLayer == 'park' ||
            sourceLayer == 'aeroway')) {
      final isPark = sourceLayer == 'park' || _parkIdPattern.hasMatch(id);
      final color = isPark ? pgGreenPark : pgGreenBase;
      _setPaint(layer, 'fill-color', color);
      _setPaint(layer, 'fill-opacity', 1);
      _setPaint(layer, 'fill-outline-color', color);
      if (isPark) {
        progress.groundPark++;
      } else {
        progress.groundBase++;
      }
      continue;
    }

    // 3f) screen-map.jsx:552-560: Wasser.
    if (sourceLayer == 'water') {
      if (type == 'fill') {
        _setPaint(layer, 'fill-color', pgWater);
        progress.waterFills++;
      }
      continue;
    }
    if (sourceLayer == 'waterway' && type == 'line') {
      _setPaint(layer, 'line-color', pgWater);
      progress.waterwayLines++;
      continue;
    }

    // 3g) screen-map.jsx:563-598: Verkehr.
    if (sourceLayer == 'transportation') {
      if (_hiddenTransportPattern.hasMatch(id)) {
        _setLayout(layer, 'visibility', 'none');
        progress.transportHidden++;
        continue;
      }
      if (type == 'fill') {
        // `road_area_pattern` legt sonst eine diagonale Schraffur über Plätze.
        // Die Quelle setzt die Eigenschaft auf null, was MapLibre als
        // "zurück auf Default" liest; im gebackenen JSON heißt das: entfernen.
        _removePaint(layer, 'fill-pattern');
        _setPaint(layer, 'fill-color', pgRoad);
        progress.transportFills++;
        continue;
      }
      if (type == 'line') {
        final isCasing = _casingIdPattern.hasMatch(id);
        _setPaint(layer, 'line-color', isCasing ? pgRoadEdge : pgRoad);
        _setPaint(layer, 'line-opacity', 1);
        final width = _paintOf(layer)['line-width'];
        if (width != null) {
          _setPaint(
            layer,
            'line-width',
            widenLineWidth(width, isCasing ? roadCaseFactor : roadFillFactor),
          );
        } else {
          progress.transportLinesWithoutWidth++;
        }
        _setLayout(layer, 'line-cap', 'round');
        _setLayout(layer, 'line-join', 'round');
        // [1, 0] = durchgehende Linie statt gepunktet.
        _setPaint(layer, 'line-dasharray', <Object?>[1, 0]);
        progress.transportLines++;
        if (isCasing) {
          progress.transportCasings++;
        }
      }
      continue;
    }

    // Am heutigen Liberty-Stil sind das fünf: `background` (bekommt seine
    // Farbe erst in Schritt 5), das Raster `natural_earth` und die drei
    // Linienlayer `park_outline`, `aeroway_runway`, `aeroway_taxiway`. Die
    // Quelle fasst sie ebenfalls nicht an, Fall 3e verlangt `type == 'fill'`.
    progress.untouched++;
  }

  // 4) screen-map.jsx:605-620: zarter Häuser-Umriss als oberster Layer.
  //    fill-extrusion kann keinen eigenen Rand, also ein eigener line-Layer
  //    aus derselben `building` source-layer.
  if (!byId.containsKey('building-outline')) {
    layers.add(<String, Object?>{
      'id': 'building-outline',
      'type': 'line',
      'source': vectorSource,
      'source-layer': 'building',
      'minzoom': 14,
      'paint': <String, Object?>{
        'line-color': pgBuildingEdge,
        'line-width': <Object?>[
          'interpolate',
          <Object?>['linear'],
          <Object?>['zoom'],
          14,
          0.3,
          16,
          0.6,
          18,
          1.0,
        ],
        'line-opacity': 0.5,
      },
    });
  }

  // 5) screen-map.jsx:622-625: Basis-Boden, füllt alle Lücken.
  final background = byId['background'];
  if (background != null) {
    _setPaint(background, 'background-color', pgGreenBase);
  }

  // 6) screen-map.jsx:627-641, `setLights`: bewusst nicht portiert. Der
  //    Kommentar der Quelle sagt selbst "Mapbox-only API, no-op on MapLibre".

  return style;
}

/// Port von `widen` aus `screen-map.jsx:481-491`.
///
/// Ist [width] eine Zahl, wird sie mit [factor] multipliziert. Ist sie ein
/// `interpolate`-Ausdruck, werden **nur die Ausgabe-Stops** skaliert, also ab
/// Index 4 in Zweierschritten. Alles andere bleibt unverändert.
///
/// Warum nicht einfach `['*', w, f]`: ein Zoom-`interpolate` darf laut
/// Style-Spezifikation nicht in einen anderen Ausdruck geschachtelt werden.
/// Der Kommentar der Quelle nennt genau diesen Grund.
///
/// Der Aufbau eines solchen Ausdrucks:
///
///     ['interpolate', ['exponential', 1.2], ['zoom'], 5, 0.4, 6, 0.7, ...]
///        0             1                    2         3  4    5  6
///
/// Index 3 ist eine Zoomstufe und bleibt stehen, Index 4 ist die Breite bei
/// dieser Zoomstufe und wird skaliert.
Object? widenLineWidth(Object? width, double factor) {
  if (width is num) {
    return width * factor;
  }
  if (width is List<Object?> &&
      width.isNotEmpty &&
      width.first == 'interpolate') {
    final out = List<Object?>.of(width);
    for (var i = 4; i < out.length; i += 2) {
      final value = out[i];
      if (value is num) {
        out[i] = value * factor;
      }
    }
    return out;
  }
  return width;
}

// ── Ausgabeformat ───────────────────────────────────────────────────────────

/// Schreibt [style] deterministisch als JSON.
///
/// Kopf und Quellen stehen eingerückt, **jeder Layer steht auf genau einer
/// Zeile**. Grund ist der Diff: bei voll eingerücktem JSON bläht ein einziger
/// geänderter Farbwert den Ausschnitt auf, und die Datei wächst von rund 46 KB
/// auf ein Vielfaches, das mit in das App-Bundle geht. Eine Zeile je Layer
/// heißt: eine geänderte Zeile je geändertem Layer.
///
/// Die Schlüsselreihenfolge ist die des Ausgangsstils, weil `jsonDecode` die
/// Einfügereihenfolge erhält und dieses Werkzeug nur an Ort und Stelle ändert.
/// Neu gesetzte Schlüssel hängen hinten an. Damit ist die Ausgabe bei gleicher
/// Eingabe byteweise identisch, und `--check` meldet kein Rauschen.
String renderStyleJson(Map<String, Object?> style) {
  const encoder = JsonEncoder.withIndent('  ');
  const compact = JsonEncoder();

  final buffer = StringBuffer('{\n');
  final keys = style.keys.toList();
  for (var i = 0; i < keys.length; i++) {
    final key = keys[i];
    final comma = i == keys.length - 1 ? '' : ',';
    if (key != 'layers') {
      final body = encoder.convert(style[key]).split('\n').join('\n  ');
      buffer.write('  ${compact.convert(key)}: $body$comma\n');
      continue;
    }
    buffer.write('  "layers": [\n');
    final layers = _layersOf(style);
    for (var j = 0; j < layers.length; j++) {
      final tail = j == layers.length - 1 ? '' : ',';
      buffer.write('    ${compact.convert(layers[j])}$tail\n');
    }
    buffer.write('  ]$comma\n');
  }
  buffer.write('}\n');
  return buffer.toString();
}

// ── Drift-Bericht ───────────────────────────────────────────────────────────

/// Nennt die Unterschiede zwischen [currentJson] und [expectedJson].
///
/// Die Meldung sagt bewusst, **welche Layer** abweichen. "Die Datei ist anders"
/// ist bei 112 Layern keine verwertbare Auskunft.
List<String> describeStyleDrift(String currentJson, String expectedJson) {
  final Map<String, Object?> current;
  final Map<String, Object?> expected;
  try {
    current = _decodeStyle(currentJson, outputPath);
    expected = _decodeStyle(expectedJson, 'gebackenes Ergebnis');
  } on FormatException catch (error) {
    return <String>['$outputPath ist kein lesbares JSON: ${error.message}'];
  }

  final findings = <String>[];

  for (final key in <String>{...current.keys, ...expected.keys}) {
    if (key == 'layers') {
      continue;
    }
    if (!_deepEquals(current[key], expected[key])) {
      findings.add('Kopf: "$key" weicht ab.');
    }
  }

  final currentLayers = <String, Map<String, Object?>>{
    for (final entry in _layersOf(current))
      _layerId(_asMap(entry)): _asMap(entry),
  };
  final expectedLayers = <String, Map<String, Object?>>{
    for (final entry in _layersOf(expected))
      _layerId(_asMap(entry)): _asMap(entry),
  };

  for (final id in expectedLayers.keys) {
    if (!currentLayers.containsKey(id)) {
      findings.add('Layer fehlt in der Datei: $id');
    }
  }
  for (final id in currentLayers.keys) {
    if (!expectedLayers.containsKey(id)) {
      findings.add('Layer steht zu viel in der Datei: $id');
    }
  }
  for (final id in expectedLayers.keys) {
    final mine = currentLayers[id];
    if (mine == null) {
      continue;
    }
    final theirs = expectedLayers[id]!;
    if (!_deepEquals(mine, theirs)) {
      final changed = <String>{
        ...mine.keys,
        ...theirs.keys,
      }.where((key) => !_deepEquals(mine[key], theirs[key])).toList()..sort();
      findings.add('Layer weicht ab: $id (${changed.join(', ')})');
    }
  }

  final currentOrder = _layersOf(current).map((e) => _layerId(_asMap(e)));
  final expectedOrder = _layersOf(expected).map((e) => _layerId(_asMap(e)));
  if (findings.isEmpty &&
      !_deepEquals(currentOrder.toList(), expectedOrder.toList())) {
    findings.add('Die Layer-Reihenfolge weicht ab.');
  }

  if (findings.isEmpty) {
    findings.add(
      'Inhaltlich gleich, aber die Textform weicht ab (Formatierung oder '
      'Zeichenkodierung).',
    );
  }
  return findings;
}

// ── Kleinkram ───────────────────────────────────────────────────────────────

Map<String, Object?> _decodeStyle(String text, String origin) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$origin: erwartet wurde ein JSON-Objekt.');
  }
  return decoded;
}

String _normalizeLineEndings(String text) => text.replaceAll('\r\n', '\n');

List<Object?> _layersOf(Map<String, Object?> style) {
  final layers = style['layers'];
  if (layers is! List<Object?>) {
    throw const FormatException('Der Stil hat keine Layer-Liste.');
  }
  return layers;
}

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Erwartet wurde ein JSON-Objekt.');
  }
  return value;
}

String _layerId(Map<String, Object?> layer) {
  final id = layer['id'];
  if (id is! String) {
    throw const FormatException('Ein Layer hat keine `id`.');
  }
  return id;
}

String _layerType(Map<String, Object?> layer) {
  final type = layer['type'];
  if (type is! String) {
    throw const FormatException('Ein Layer hat keinen `type`.');
  }
  return type;
}

String? _sourceLayer(Map<String, Object?> layer) =>
    layer['source-layer'] as String?;

Map<String, Object?> _paintOf(Map<String, Object?> layer) {
  final paint = layer['paint'];
  if (paint is Map<String, Object?>) {
    return paint;
  }
  final created = <String, Object?>{};
  layer['paint'] = created;
  return created;
}

Map<String, Object?> _layoutOf(Map<String, Object?> layer) {
  final layout = layer['layout'];
  if (layout is Map<String, Object?>) {
    return layout;
  }
  final created = <String, Object?>{};
  layer['layout'] = created;
  return created;
}

void _setPaint(Map<String, Object?> layer, String key, Object? value) {
  _paintOf(layer)[key] = value;
}

void _removePaint(Map<String, Object?> layer, String key) {
  final paint = layer['paint'];
  if (paint is Map<String, Object?>) {
    paint.remove(key);
  }
}

void _setLayout(Map<String, Object?> layer, String key, Object? value) {
  _layoutOf(layer)[key] = value;
}

Map<String, Object?> _deepCopyMap(Map<String, Object?> value) =>
    _deepCopy(value)! as Map<String, Object?>;

Object? _deepCopy(Object? value) {
  if (value is Map<String, Object?>) {
    return <String, Object?>{
      for (final entry in value.entries) entry.key: _deepCopy(entry.value),
    };
  }
  if (value is List<Object?>) {
    return <Object?>[for (final item in value) _deepCopy(item)];
  }
  return value;
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}
