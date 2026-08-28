// Prüft das **Ergebnis** von tool/bake_map_style.dart, nicht seine Bauweise.
//
// Die Zusicherungen sind aus `02_Frontend/app/screen-map.jsx` abgelesen, nicht
// aus dem Werkzeug. Wo eine Menge von Layern geprüft wird, steht die erwartete
// Zuordnung als Liste im Test: eine Prüfung, die ihre Erwartung aus derselben
// Regel ableitet wie der Code, prüft nichts.
//
// Zwei Dinge sind hier besonders wichtig:
//
// 1. **Häuser sind sichtbar.** `screen-map.jsx:370-375` blendet Libertys
//    Gebäude-Layer aus, `:502` schaltet sie wieder ein. Wer nur die erste
//    Stelle liest, backt eine Karte ohne Häuser, und das fiele in keinem
//    anderen Test auf.
// 2. **Jede Menge, über die geprüft wird, ist nachweislich nicht leer.** Sonst
//    prüft `every` die leere Menge und ist immer grün.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/bake_map_style.dart'
    show describeStyleDrift, outputPath, upstreamPath, widenLineWidth;

void main() {
  late Map<String, Object?> style;
  late List<Map<String, Object?>> layers;
  late Map<String, Map<String, Object?>> byId;
  late Map<String, Map<String, Object?>> upstreamById;

  setUpAll(() {
    style = _readJson(outputPath);
    layers = _layers(style);
    byId = <String, Map<String, Object?>>{
      for (final layer in layers) _id(layer): layer,
    };
    upstreamById = <String, Map<String, Object?>>{
      for (final layer in _layers(_readJson(upstreamPath))) _id(layer): layer,
    };
  });

  group('Gebackener Stil, Grundgerüst', () {
    test(
      'ist ein Style-8-Dokument mit allen 111 Liberty-Layern plus Umriss',
      () {
        expect(style['version'], 8);
        // 111 aus dem Ausgangsstil, dazu `building-outline`.
        expect(layers, hasLength(112));
        expect(upstreamById, hasLength(111));
      },
    );

    test('behält Glyphen und Sprites des Anbieters', () {
      expect(style['glyphs'], isA<String>());
      expect(style['sprite'], isA<String>());
      expect(style['sources'], isA<Map<String, Object?>>());
    });
  });

  group('Beschriftungen', () {
    test('kein einziger Symbol-Layer ist sichtbar', () {
      final symbols = layers
          .where((layer) => layer['type'] == 'symbol')
          .toList();
      // screen-map.jsx:535-538 blendet ausnahmslos jeden Symbol-Layer aus.
      expect(symbols, hasLength(25), reason: 'Liberty hat 25 Symbol-Layer.');
      for (final layer in symbols) {
        expect(
          _visible(layer),
          isFalse,
          reason: 'Symbol-Layer ${_id(layer)} ist sichtbar.',
        );
      }
    });
  });

  group('Boden und Wasser', () {
    test('der Hintergrund trägt PG_GREEN_BASE', () {
      expect(_paint(byId['background']!)['background-color'], '#97D26E');
    });

    test('jede Wasserfläche trägt PG_WATER', () {
      final waterFills = layers
          .where(
            (layer) =>
                layer['source-layer'] == 'water' && layer['type'] == 'fill',
          )
          .toList();
      expect(waterFills, isNotEmpty);
      for (final layer in waterFills) {
        expect(_paint(layer)['fill-color'], '#46A8E2', reason: _id(layer));
      }
    });

    test('Fließgewässer-Linien tragen PG_WATER', () {
      // `waterway_line_label` ist ein Symbol und fällt vorher aus dem
      // Durchlauf, deshalb stehen hier nur die drei Linien.
      const expected = <String>[
        'waterway_tunnel',
        'waterway_river',
        'waterway_other',
      ];
      for (final id in expected) {
        expect(_paint(byId[id]!)['line-color'], '#46A8E2', reason: id);
      }
    });

    test('Parks tragen PG_GREEN_PARK, Restflächen PG_GREEN_BASE', () {
      // Von Hand aus screen-map.jsx:544 abgeleitet: `park` ist wahr, wenn die
      // source-layer `park` heißt oder die id auf
      // /wood|forest|park|grass|recreation|garden|pitch|cemetery|scrub/i passt.
      const parkGreen = <String>[
        'park', // source-layer `park`
        'landcover_wood', // "wood"
        'landcover_grass', // "grass"
        'landuse_pitch', // "pitch"
        'landuse_cemetery', // "cemetery"
      ];
      const baseGreen = <String>[
        'landuse_residential',
        'landcover_ice',
        'landcover_wetland',
        'landuse_track',
        'landuse_hospital',
        'landuse_school',
        'landcover_sand',
        'aeroway_fill',
      ];
      expect(parkGreen, isNotEmpty);
      expect(baseGreen, isNotEmpty);

      for (final id in parkGreen) {
        final paint = _paint(byId[id]!);
        expect(paint['fill-color'], '#6CB845', reason: id);
        expect(paint['fill-outline-color'], '#6CB845', reason: id);
        expect(paint['fill-opacity'], 1, reason: id);
      }
      for (final id in baseGreen) {
        final paint = _paint(byId[id]!);
        expect(paint['fill-color'], '#97D26E', reason: id);
        expect(paint['fill-outline-color'], '#97D26E', reason: id);
        expect(paint['fill-opacity'], 1, reason: id);
      }

      // Gegenprobe: das sind alle Flächen der vier Quell-Layer, es fehlt
      // keine. Sonst könnte eine unerkannte Fläche grau bleiben.
      final grounds = layers
          .where(
            (layer) =>
                layer['type'] == 'fill' &&
                const <String>{
                  'landcover',
                  'landuse',
                  'park',
                  'aeroway',
                }.contains(layer['source-layer']),
          )
          .map(_id)
          .toSet();
      expect(grounds, <String>{...parkGreen, ...baseGreen});
    });

    test('park_outline bleibt unangetastet, weil es keine Fläche ist', () {
      // screen-map.jsx:543 verlangt `layer.type === 'fill'`. Die Linie fällt
      // durch alle Fälle und behält Libertys Werte.
      expect(
        _paint(byId['park_outline']!),
        _paint(upstreamById['park_outline']!),
      );
    });
  });

  group('Häuser: die Falle dieses Schritts', () {
    test('die Gebäude-Layer sind sichtbar, nicht ausgeblendet', () {
      for (final id in const <String>['building', 'building-3d']) {
        expect(byId[id], isNotNull, reason: id);
        expect(
          _layout(byId[id]!)['visibility'],
          'visible',
          reason:
              '$id muss ausdrücklich sichtbar sein. screen-map.jsx:502 '
              'schaltet die in :370-375 ausgeblendeten Layer wieder ein.',
        );
        expect(_visible(byId[id]!), isTrue, reason: id);
      }
    });

    test('der 3D-Layer trägt Farbe, Höhe, Basis und Deckkraft', () {
      final paint = _paint(byId['building-3d']!);
      expect(paint['fill-extrusion-color'], '#F1EBDB');
      expect(paint['fill-extrusion-height'], 3);
      expect(paint['fill-extrusion-base'], 0);
      expect(paint['fill-extrusion-opacity'], 0.72);
      expect(paint['fill-extrusion-vertical-gradient'], false);
    });

    test('der 2D-Grundriss trägt dieselbe Hausfarbe und Deckkraft', () {
      final paint = _paint(byId['building']!);
      expect(paint['fill-color'], '#F1EBDB');
      expect(paint['fill-opacity'], 0.72);
    });

    test(
      'building-outline ist der oberste Layer und hängt an openmaptiles',
      () {
        final outline = byId['building-outline'];
        expect(outline, isNotNull);
        expect(_id(layers.last), 'building-outline');
        expect(outline!['type'], 'line');
        expect(outline['source'], 'openmaptiles');
        expect(outline['source-layer'], 'building');
        expect(outline['minzoom'], 14);
        final paint = _paint(outline);
        expect(paint['line-color'], '#D2C6AC');
        expect(paint['line-opacity'], 0.5);
        expect(paint['line-width'], <Object?>[
          'interpolate',
          <Object?>['linear'],
          <Object?>['zoom'],
          14,
          0.3,
          16,
          0.6,
          18,
          1.0,
        ]);
      },
    );
  });

  group('Grenzen', () {
    test('kein Grenz-Layer ist sichtbar', () {
      const boundaries = <String>[
        'boundary_3',
        'boundary_2',
        'boundary_disputed',
      ];
      for (final id in boundaries) {
        expect(byId[id], isNotNull, reason: id);
        expect(_visible(byId[id]!), isFalse, reason: id);
      }
      // Gegenprobe gegen den Ausgangsstil: es gibt genau diese drei.
      final fromUpstream = upstreamById.values
          .where((layer) => layer['source-layer'] == 'boundary')
          .map(_id)
          .toSet();
      expect(fromUpstream, boundaries.toSet());
    });
  });

  group('Straßen', () {
    test('ein Casing trägt PG_ROAD_EDGE, eine Fahrbahn PG_ROAD', () {
      expect(_paint(byId['road_motorway_casing']!)['line-color'], '#E3CD93');
      expect(_paint(byId['road_minor']!)['line-color'], '#FFFDF7');
    });

    test('jede sichtbare Verkehrslinie ist solide, rund und deckend', () {
      final visibleRoads = layers
          .where(
            (layer) =>
                layer['source-layer'] == 'transportation' &&
                layer['type'] == 'line' &&
                _visible(layer),
          )
          .toList();
      expect(visibleRoads, hasLength(36));
      for (final layer in visibleRoads) {
        final paint = _paint(layer);
        final layout = _layout(layer);
        expect(paint['line-opacity'], 1, reason: _id(layer));
        expect(paint['line-dasharray'], <Object?>[1, 0], reason: _id(layer));
        expect(layout['line-cap'], 'round', reason: _id(layer));
        expect(layout['line-join'], 'round', reason: _id(layer));
        final color = paint['line-color'];
        final expectedColor = _id(layer).contains('casing')
            ? '#E3CD93'
            : '#FFFDF7';
        expect(color, expectedColor, reason: _id(layer));
      }
    });

    test('Schienen, Servicewege und Fußwege sind ausgeblendet', () {
      const hidden = <String>[
        'road_major_rail',
        'road_transit_rail',
        'road_service_track',
        'road_path_pedestrian',
        'bridge_path_pedestrian_casing',
        'tunnel_service_track_casing',
      ];
      for (final id in hidden) {
        expect(byId[id], isNotNull, reason: id);
        expect(_visible(byId[id]!), isFalse, reason: id);
      }
    });

    test('die Schraffur der Fußgängerflächen ist entfernt', () {
      // screen-map.jsx:577 setzt `fill-pattern` auf null, was MapLibre als
      // "zurück auf Default" liest. Im gebackenen JSON heißt das: weg.
      final paint = _paint(byId['road_area_pattern']!);
      expect(paint.containsKey('fill-pattern'), isFalse);
      expect(paint['fill-color'], '#FFFDF7');
      // Gegenprobe: im Ausgangsstil war das Muster da.
      expect(
        _paint(upstreamById['road_area_pattern']!)['fill-pattern'],
        'pedestrian_polygon',
      );
    });
  });

  group('Verbreiterung am gebackenen Ergebnis', () {
    test('road_motorway_casing wird mit ROAD_CASE_F = 3.1 skaliert', () {
      // Vorher, aus tool/map_style/liberty_upstream.json:
      //   ["interpolate", ["exponential", 1.2], ["zoom"],
      //    5, 0.4,  6, 0.7,  7, 1.75,  20, 22]
      // Die Zoomstufen an den Indizes 3, 5, 7, 9 bleiben stehen, die Breiten
      // an 4, 6, 8, 10 werden mit 3.1 multipliziert. Von Hand nachgerechnet:
      //   0.4  x 3.1 = 1.24    (als IEEE-754-Double 1.2400000000000002)
      //   0.7  x 3.1 = 2.17
      //   1.75 x 3.1 = 5.425
      //   22   x 3.1 = 68.2
      // Der erste Wert ist der Beleg dafür, dass wirklich multipliziert und
      // nicht gerundet wird: 1.24 lässt sich binär nicht exakt darstellen.
      expect(
        _paint(upstreamById['road_motorway_casing']!)['line-width'],
        <Object?>[
          'interpolate',
          <Object?>['exponential', 1.2],
          <Object?>['zoom'],
          5,
          0.4,
          6,
          0.7,
          7,
          1.75,
          20,
          22,
        ],
      );

      expect(_paint(byId['road_motorway_casing']!)['line-width'], <Object?>[
        'interpolate',
        <Object?>['exponential', 1.2],
        <Object?>['zoom'],
        5,
        1.2400000000000002,
        6,
        2.17,
        7,
        5.425,
        20,
        68.2,
      ]);
    });

    test('road_secondary_tertiary wird mit ROAD_FILL_F = 2.7 skaliert', () {
      // Vorher: [..., 6.5, 0,  8, 0.5,  20, 13]
      // Nachgerechnet: 0 x 2.7 = 0, 0.5 x 2.7 = 1.35, 13 x 2.7 = 35.1
      expect(_paint(byId['road_secondary_tertiary']!)['line-width'], <Object?>[
        'interpolate',
        <Object?>['exponential', 1.2],
        <Object?>['zoom'],
        6.5,
        0.0,
        8,
        1.35,
        20,
        35.1,
      ]);
    });

    test('jede sichtbare Verkehrslinie trägt genau ihren Faktor', () {
      // Die beiden Tests darüber sind Stichproben. Dieser hier geht über alle
      // 36 sichtbaren Verkehrslinien und vergleicht jeden Ausgabe-Stop mit
      // dem des Ausgangsstils. Er fällt auch dann, wenn nur ein einzelner
      // Layer den falschen Faktor bekommt.
      final visibleRoads = layers
          .where(
            (layer) =>
                layer['source-layer'] == 'transportation' &&
                layer['type'] == 'line' &&
                _visible(layer),
          )
          .toList();
      expect(visibleRoads, hasLength(36));

      for (final layer in visibleRoads) {
        final id = _id(layer);
        final factor = id.contains('casing') ? 3.1 : 2.7;
        final before = _stops(_paint(upstreamById[id]!)['line-width']);
        final after = _stops(_paint(layer)['line-width']);
        expect(after, hasLength(before.length), reason: id);
        for (var i = 0; i < after.length; i++) {
          expect(
            after[i],
            closeTo(before[i] * factor, 1e-9),
            reason: '$id, Stop $i: ${before[i]} x $factor',
          );
        }
        // Die Zoomstufen dürfen sich nicht mitverschieben.
        expect(
          _zoomStops(_paint(layer)['line-width']),
          _zoomStops(_paint(upstreamById[id]!)['line-width']),
          reason: id,
        );
      }
    });

    test('das Casing bleibt breiter als seine Fahrbahn', () {
      // Der goldene Saum entsteht nur, weil das Casing breiter gezogen wird
      // als die Fahrbahn (3.1 gegen 2.7). Wären beide Faktoren vertauscht,
      // verschwände der Rand, ohne dass ein Farbtest das merkt.
      //
      // Verglichen werden die beiden Zoomstufen, die `road_motorway` und
      // `road_motorway_casing` gemeinsam haben. Ein Vergleich Stop für Stop
      // ginge nicht: Liberty gibt der Fahrbahn drei Stützstellen (5, 7, 20)
      // und dem Casing vier (5, 6, 7, 20).
      final casing = _widthAtZoom(byId['road_motorway_casing']!);
      final road = _widthAtZoom(byId['road_motorway']!);
      // Zoom 7:  1.75 x 3.1 = 5.425 gegen 1 x 2.7 = 2.7
      expect(casing[7], closeTo(5.425, 1e-9));
      expect(road[7], closeTo(2.7, 1e-9));
      // Zoom 20: 22 x 3.1 = 68.2 gegen 18 x 2.7 = 48.6
      expect(casing[20], closeTo(68.2, 1e-9));
      expect(road[20], closeTo(48.6, 1e-9));
      for (final zoom in const <num>[7, 20]) {
        expect(casing[zoom]!, greaterThan(road[zoom]!), reason: 'Zoom $zoom');
      }
    });
  });

  group('widenLineWidth als Einzelfunktion', () {
    test('eine Zahl wird multipliziert', () {
      expect(widenLineWidth(2, 2.7), 5.4);
      expect(widenLineWidth(0.5, 3.1), closeTo(1.55, 1e-12));
    });

    test('bei interpolate werden nur die Ausgabe-Stops skaliert', () {
      final result = widenLineWidth(<Object?>[
        'interpolate',
        <Object?>['linear'],
        <Object?>['zoom'],
        10,
        1,
        20,
        4,
      ], 2.0);
      expect(result, <Object?>[
        'interpolate',
        <Object?>['linear'],
        <Object?>['zoom'],
        10,
        2.0,
        20,
        8.0,
      ]);
    });

    test('die Eingabe wird nicht verändert', () {
      final input = <Object?>[
        'interpolate',
        <Object?>['linear'],
        <Object?>['zoom'],
        10,
        1,
      ];
      widenLineWidth(input, 5.0);
      expect(input[4], 1);
    });

    test('alles andere bleibt unverändert', () {
      // `['*', w, f]` geht laut screen-map.jsx:479 nicht, weil ein
      // Zoom-interpolate nicht geschachtelt werden darf. Ein Ausdruck, der
      // kein interpolate ist, muss deshalb unangetastet durchlaufen.
      final step = <Object?>[
        'step',
        <Object?>['zoom'],
        1,
        14,
        2,
      ];
      expect(widenLineWidth(step, 3.1), same(step));
      expect(widenLineWidth(null, 3.1), isNull);
      expect(widenLineWidth('breit', 3.1), 'breit');
      expect(widenLineWidth(<Object?>[], 3.1), isEmpty);
    });
  });

  group('--check', () {
    late Directory temp;

    setUpAll(() {
      temp = Directory.systemTemp.createTempSync('fact_map_style_check');
      _copyInto(temp, upstreamPath);
      _copyInto(temp, outputPath);
    });

    tearDownAll(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    test('ist grün gegen die eingecheckte Datei', () {
      final run = _runCheck(temp);
      expect(
        run.exitCode,
        0,
        reason: 'stdout: ${run.stdout}\nstderr: ${run.stderr}',
      );
      expect(run.stdout, contains('stimmt mit dem Ausgangsstil überein'));
    });

    test('ist rot und nennt den Layer, wenn die Datei verändert wurde', () {
      final copy = File('${temp.path}/$outputPath');
      final original = copy.readAsStringSync();
      addTearDown(() => copy.writeAsStringSync(original));

      copy.writeAsStringSync(
        original.replaceFirst(
          '"background-color":"#97D26E"',
          '"background-color":"#FF00FF"',
        ),
      );
      // Ohne diese Zusicherung liefe der Test grün, wenn das Muster nicht
      // greift: die Datei wäre dann unverändert und der Rest sinnlos.
      expect(copy.readAsStringSync(), isNot(original));

      final run = _runCheck(temp);
      expect(run.exitCode, isNot(0));
      expect(run.stderr, contains('weicht vom gebackenen Ergebnis ab'));
      expect(run.stderr, contains('Layer weicht ab: background (paint)'));
    });

    test('ist rot und nennt einen fehlenden Layer', () {
      final copy = File('${temp.path}/$outputPath');
      final original = copy.readAsStringSync();
      addTearDown(() => copy.writeAsStringSync(original));

      final lines = original.split('\n');
      final index = lines.indexWhere(
        (line) => line.contains('"id":"building-3d"'),
      );
      expect(index, greaterThan(-1));
      lines.removeAt(index);
      copy.writeAsStringSync(lines.join('\n'));

      final run = _runCheck(temp);
      expect(run.exitCode, isNot(0));
      expect(run.stderr, contains('Layer fehlt in der Datei: building-3d'));
    });
  });

  group('describeStyleDrift', () {
    test('meldet gleiche Dokumente als reinen Formatunterschied', () {
      const a = '{"version":8,"layers":[{"id":"x","type":"line"}]}';
      const b = '{"version": 8, "layers": [{"id": "x", "type": "line"}]}';
      final findings = describeStyleDrift(a, b);
      expect(findings, hasLength(1));
      expect(findings.single, startsWith('Inhaltlich gleich'));
      expect(findings.single, contains('Textform weicht ab'));
    });

    test('meldet Kopfänderungen getrennt von Layeränderungen', () {
      const a =
          '{"version":8,"glyphs":"a","layers":[{"id":"x","type":"line"}]}';
      const b =
          '{"version":8,"glyphs":"b","layers":[{"id":"x","type":"fill"}]}';
      final findings = describeStyleDrift(a, b);
      expect(findings, contains('Kopf: "glyphs" weicht ab.'));
      expect(findings, contains('Layer weicht ab: x (type)'));
    });
  });
}

// ---------------------------------------------------------------------------
// Hilfsmittel
// ---------------------------------------------------------------------------

Map<String, Object?> _readJson(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path fehlt.');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

List<Map<String, Object?>> _layers(Map<String, Object?> style) =>
    (style['layers']! as List<Object?>)
        .map((entry) => entry! as Map<String, Object?>)
        .toList();

String _id(Map<String, Object?> layer) => layer['id']! as String;

Map<String, Object?> _paint(Map<String, Object?> layer) =>
    (layer['paint'] as Map<String, Object?>?) ?? const <String, Object?>{};

Map<String, Object?> _layout(Map<String, Object?> layer) =>
    (layer['layout'] as Map<String, Object?>?) ?? const <String, Object?>{};

/// Ein Layer gilt als sichtbar, solange `layout.visibility` nicht `none` ist.
/// Das ist die Regel der Style-Spezifikation: fehlt der Wert, ist er `visible`.
bool _visible(Map<String, Object?> layer) =>
    _layout(layer)['visibility'] != 'none';

/// Die Ausgabe-Stops eines `interpolate`-Ausdrucks, also die Breiten.
List<num> _stops(Object? width) {
  final list = width! as List<Object?>;
  final out = <num>[];
  for (var i = 4; i < list.length; i += 2) {
    out.add(list[i]! as num);
  }
  return out;
}

/// Die Eingabe-Stops, also die Zoomstufen.
List<num> _zoomStops(Object? width) {
  final list = width! as List<Object?>;
  final out = <num>[];
  for (var i = 3; i < list.length; i += 2) {
    out.add(list[i]! as num);
  }
  return out;
}

/// Breite je Zoomstufe, aus den Stützstellen eines `interpolate`-Ausdrucks.
/// Zwischenwerte werden nicht interpoliert, geprüft wird nur an den Stufen.
Map<num, num> _widthAtZoom(Map<String, Object?> layer) {
  final width = _paint(layer)['line-width'];
  final zooms = _zoomStops(width);
  final values = _stops(width);
  return <num, num>{for (var i = 0; i < zooms.length; i++) zooms[i]: values[i]};
}

void _copyInto(Directory temp, String relativePath) {
  final target = File('${temp.path}/$relativePath');
  target.parent.createSync(recursive: true);
  File(relativePath).copySync(target.path);
}

class _Run {
  const _Run(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}

_Run _runCheck(Directory temp) {
  final result = Process.runSync(
    _dartPath(),
    <String>['${Directory.current.path}/tool/bake_map_style.dart', '--check'],
    workingDirectory: temp.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return _Run(
    result.exitCode,
    result.stdout as String,
    result.stderr as String,
  );
}

/// Findet die Dart-Kommandozeile. Unter `flutter test` ist
/// `Platform.resolvedExecutable` der flutter_tester, nicht Dart. Dasselbe
/// Vorgehen wie in `check_architecture_test.dart`.
String _dartPath() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final suffix = Platform.isWindows ? '.exe' : '';
    final candidate = File('$root/bin/cache/dart-sdk/bin/dart$suffix');
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }
  if (Platform.resolvedExecutable.contains('dart-sdk')) {
    return Platform.resolvedExecutable;
  }
  return Platform.isWindows ? 'dart.exe' : 'dart';
}
