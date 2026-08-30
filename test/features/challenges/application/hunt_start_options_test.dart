import 'dart:math' as math;

import 'package:fact_app/features/challenges/application/hunt_hotspot.dart';
import 'package:fact_app/features/challenges/application/hunt_start_options.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Rechnungen des Startpunkt-Pickers,
/// `02_Frontend/app/screen-challenge.jsx:2979-3040`.
///
/// ## Warum das die wertvollste Testdatei dieses Schritts ist
///
/// Alles hier ist rein: Entfernungen, zwei verschiedene Dichten, eine
/// Sortierung, ein Schnitt und eine Umrechnung in Minuten. Kein Widget, keine
/// Uhr, kein Netz. Jede Zahl kommt aus der Quelle, und **keine Zusicherung
/// vergleicht gegen die Konstante, die sie festnageln soll** (Muster 18 in
/// `REBUILD_STATUS.md`): 600, 15, 5, 3, 4.5 und 1.3 stehen hier ausgeschrieben
/// und nicht als `huntLocalDensityRadiusInMeters`.
///
/// ## Die Fakten liegen auf einem Meterraster
///
/// [_factAt] legt einen Fakt eine gegebene Zahl Meter nördlich des Nullpunkts
/// ab, gerechnet mit demselben Erdradius wie [MapPosition]. Damit ist „ein
/// Fakt 599 Meter entfernt" eine Aussage über die Grenze und keine über die
/// Genauigkeit der Umrechnung.
void main() {
  group('Dichte um die Nutzerposition', () {
    test('zählt nur, was näher als 600 Meter liegt', () {
      // `<= radius_m`, `:2999`. 600 selbst zählt noch mit, 601 nicht mehr.
      expect(
        countFactsWithPuzzlesNear(<Fact>[_factAt(1, north: 599)], _origin),
        1,
      );
      expect(
        countFactsWithPuzzlesNear(<Fact>[_factAt(1, north: 601)], _origin),
        0,
      );
    });

    test('die Grenze selbst ist einschließend', () {
      // `<=` statt `<` auf `600` zu ändern überlebte die beiden Fälle oben,
      // weil 599 und 601 beide Seiten der Grenze prüfen, aber nie die Grenze
      // selbst. **Ein wörtliches `north: 600` beweist das trotzdem nicht**:
      // die Umrechnung Meter -> Grad in [_north] und die Haversine-Formel in
      // `distanceInMetersTo` runden unabhängig voneinander, und `north: 600`
      // misst real rund 599,9999999999262 Meter, klar auf der sicheren Seite
      // jeder Grenze; die Zusicherung wäre mit `<=` **und** mit `<` grün.
      //
      // Der Radius wird deshalb umgekehrt an die tatsächlich **gemessene**
      // Entfernung eines Fakts angepasst, mit derselben Funktion, die auch
      // der Code unter Test benutzt. Das trifft die Grenze bitgenau, ganz
      // unabhängig davon, wie nah der Fakt an 600 Metern wirklich liegt.
      final Fact fact = _factAt(1, north: 600);
      final double measured = _origin.distanceInMetersTo(
        MapPosition(
          latitude: fact.coordinates!.latitude,
          longitude: fact.coordinates!.longitude,
        ),
      );

      expect(
        countFactsWithPuzzlesNear(
          <Fact>[fact],
          _origin,
          radiusInMeters: measured,
        ),
        1,
        reason: 'genau auf der Grenze zählt der Fakt noch mit',
      );
      expect(
        countFactsWithPuzzlesNear(
          <Fact>[fact],
          _origin,
          radiusInMeters: measured - 0.0000001,
        ),
        0,
        reason: 'einen Hauch darunter fällt derselbe Fakt heraus',
      );
    });

    test('ein Fakt ohne Rätsel zählt nicht mit', () {
      // `Array.isArray(f.puzzle_fit) && f.puzzle_fit.length > 0`, `:2998`.
      expect(
        countFactsWithPuzzlesNear(<Fact>[
          _factAt(1, north: 10, puzzles: const <FactPuzzle>[]),
        ], _origin),
        0,
      );
    });

    test('ein Fakt ohne Koordinate zählt nicht mit', () {
      // `f.lat != null && f.lng != null`, `:2998`.
      expect(
        countFactsWithPuzzlesNear(<Fact>[_factWithoutCoordinates(1)], _origin),
        0,
      );
    });

    test('der Radius ist überschreibbar und wirkt', () {
      final List<Fact> facts = <Fact>[_factAt(1, north: 700)];
      expect(countFactsWithPuzzlesNear(facts, _origin), 0);
      expect(countFactsWithPuzzlesNear(facts, _origin, radiusInMeters: 800), 1);
    });
  });

  group('Beschriftung der gezählten Dichte', () {
    // `:3005-3007`. Die Grenzen sind einschließend, deshalb wird jede von
    // beiden Seiten geprüft.
    test('ab 15 Fakten ist die Dichte hoch', () {
      expect(localDensityLabelOf(15), HuntDensityLabel.localHigh);
      expect(localDensityLabelOf(14), HuntDensityLabel.localMedium);
    });

    test('ab 5 Fakten ist die Dichte mittel', () {
      expect(localDensityLabelOf(5), HuntDensityLabel.localMedium);
      expect(localDensityLabelOf(4), HuntDensityLabel.localLow);
    });

    test('ohne Fakten ist sie niedrig', () {
      expect(localDensityLabelOf(0), HuntDensityLabel.localLow);
    });
  });

  group('Beschriftung der gelesenen Dichte', () {
    // `:3015-3018`. Die vier Zweige der Kaskade, jeder einzeln.
    test('die drei Werte der Quelldatei', () {
      expect(
        hotspotDensityLabelOf('sehr hoch'),
        HuntDensityLabel.hotspotVeryHigh,
      );
      expect(hotspotDensityLabelOf('hoch'), HuntDensityLabel.hotspotHigh);
      expect(hotspotDensityLabelOf('mittel'), HuntDensityLabel.hotspotMedium);
    });

    test('alles andere fällt auf den Rückfall', () {
      for (final String value in <String>[
        '',
        'niedrig',
        'Hoch',
        ' hoch',
        'hoch ',
        'sehr  hoch',
      ]) {
        expect(
          hotspotDensityLabelOf(value),
          HuntDensityLabel.hotspotUnknown,
          reason: 'für "$value"',
        );
      }
    });

    test('die gezählte und die gelesene hohe Dichte sind nicht dasselbe', () {
      // Beide heißen in der Quelle „Hohe Faktendichte", die eine mit `✓`
      // (`:3005`), die andere mit `💎` (`:3016`). Wer sie zusammenlegt, ändert
      // sichtbares Verhalten, und ohne diese Zeile fiele das niemandem auf.
      expect(localDensityLabelOf(20), isNot(hotspotDensityLabelOf('hoch')));
    });
  });

  group('Fußweg', () {
    // `Math.max(1, Math.round((m / 1000) / 4.5 * 60 * 1.3))`, `:3020`.
    // Nachgerechnet: ein Kilometer sind 1/4.5*60*1.3 = 17,333 Minuten.
    test('ein Kilometer sind 17 Minuten', () {
      expect(walkingMinutesFor(1000), 17);
    });

    test('drei Kilometer sind 52 Minuten', () {
      // 3 / 4.5 * 60 * 1.3 = 52,0.
      expect(walkingMinutesFor(3000), 52);
    });

    test('die Untergrenze ist eine Minute', () {
      expect(walkingMinutesFor(0), 1);
      expect(walkingMinutesFor(10), 1);
    });

    test('gerundet wird und nicht abgeschnitten', () {
      // 100 m sind 1,733 Minuten, also 2 und nicht 1.
      expect(walkingMinutesFor(100), 2);
      // 60 m sind 1,04 Minuten, also 1.
      expect(walkingMinutesFor(60), 1);
    });

    test('der Umwegfaktor steckt wirklich drin', () {
      // Ohne die 1,3 wären 1000 Meter 13 Minuten statt 17.
      expect(walkingMinutesFor(1000), isNot(13));
    });
  });

  group('Die Zeilen der Auswahl', () {
    test('ohne Nutzerposition steht „Hier wo ich bin" nicht da', () {
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: <HuntHotspot>[_hotspot('A', north: 100)],
        facts: const <Fact>[],
      );

      expect(options, hasLength(1));
      expect(options.single.isCurrentLocation, isFalse);
      expect(options.single.hotspotName, 'A');
    });

    test('mit Nutzerposition steht sie an erster Stelle', () {
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: <HuntHotspot>[_hotspot('A', north: 100)],
        facts: const <Fact>[],
        userPosition: _origin,
      );

      expect(options.first.isCurrentLocation, isTrue);
      expect(options.first.point, _origin);
      expect(options.first.walkingMinutes, isNull);
    });

    test('sie trägt die gezählte Dichte und nicht die gelesene', () {
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: const <HuntHotspot>[],
        facts: <Fact>[
          for (int i = 0; i < 15; i++) _factAt(i, north: 100.0 + i),
        ],
        userPosition: _origin,
      );

      expect(options.single.density, HuntDensityLabel.localHigh);
    });

    test('höchstens drei Hotspots, also höchstens vier Zeilen', () {
      // `.slice(0, 3)`, `:3011` und `:3012`.
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: <HuntHotspot>[
          for (int i = 1; i <= 6; i++) _hotspot('H$i', north: 100.0 * i),
        ],
        facts: const <Fact>[],
        userPosition: _origin,
      );

      expect(options, hasLength(4));
      expect(
        options.map((HuntStartOption o) => o.hotspotName).toList(),
        <String?>[null, 'H1', 'H2', 'H3'],
      );
    });

    test('mit Nutzerposition sind die Hotspots nach Entfernung sortiert', () {
      // `.sort((a, b) => a.dist - b.dist)`, `:3011`. Die Eingabe steht
      // absichtlich in der falschen Reihenfolge.
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: <HuntHotspot>[
          _hotspot('fern', north: 900),
          _hotspot('nah', north: 100),
          _hotspot('mittel', north: 400),
        ],
        facts: const <Fact>[],
        userPosition: _origin,
      );

      expect(
        options.skip(1).map((HuntStartOption o) => o.hotspotName).toList(),
        <String>['nah', 'mittel', 'fern'],
      );
    });

    test('ohne Nutzerposition bleibt die Dateireihenfolge stehen', () {
      // `allHotspots.slice(0, 3)`, `:3012`: kein Sortieren ohne Bezugspunkt.
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: <HuntHotspot>[
          _hotspot('fern', north: 900),
          _hotspot('nah', north: 100),
          _hotspot('mittel', north: 400),
        ],
        facts: const <Fact>[],
      );

      expect(
        options.map((HuntStartOption o) => o.hotspotName).toList(),
        <String>['fern', 'nah', 'mittel'],
      );
    });

    test('bei gleicher Entfernung gilt die Dateireihenfolge', () {
      // `Array.prototype.sort` ist seit ES2019 stabil, `List.sort` nicht.
      // Ohne den Index als zweiten Schlüssel entschiede hier die Laufzeit.
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: <HuntHotspot>[
          _hotspot('erster', north: 500),
          _hotspot('zweiter', north: 500),
          _hotspot('dritter', north: 500),
          _hotspot('vierter', north: 500),
        ],
        facts: const <Fact>[],
        userPosition: _origin,
      );

      expect(
        options.skip(1).map((HuntStartOption o) => o.hotspotName).toList(),
        <String>['erster', 'zweiter', 'dritter'],
      );
    });

    test('ein Hotspot trägt seinen Punkt, seine Dichte und den Fußweg', () {
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: <HuntHotspot>[
          _hotspot('Marienplatz', north: 1000, density: 'sehr hoch'),
        ],
        facts: const <Fact>[],
        userPosition: _origin,
      );

      final HuntStartOption hotspot = options.last;
      expect(hotspot.hotspotName, 'Marienplatz');
      expect(hotspot.density, HuntDensityLabel.hotspotVeryHigh);
      expect(hotspot.walkingMinutes, 17);
      expect(hotspot.isCurrentLocation, isFalse);
    });

    test('ohne Nutzerposition trägt ein Hotspot keinen Fußweg', () {
      // `${userPosition ? ` · ~…` : ''}`, `:3034`.
      final List<HuntStartOption> options = huntStartOptions(
        hotspots: <HuntHotspot>[_hotspot('A', north: 1000)],
        facts: const <Fact>[],
      );

      expect(options.single.walkingMinutes, isNull);
    });

    test('ohne alles bleibt die Liste leer', () {
      // `options.length === 0`, `:3043`: weder Position noch Hotspot.
      expect(
        huntStartOptions(
          hotspots: const <HuntHotspot>[],
          facts: const <Fact>[],
        ),
        isEmpty,
      );
    });

    test(
      'die Dichte der Zeile zählt über alle Fakten, nicht über die Stadt',
      () {
        // `window.FACTS`, `:2997`: die Quelle zählt über den ganzen geladenen
        // Bestand. Ein Fakt ohne Stadt zählt deshalb mit.
        final List<HuntStartOption> options = huntStartOptions(
          hotspots: const <HuntHotspot>[],
          facts: <Fact>[
            for (int i = 0; i < 5; i++) _factAt(i, north: 50.0 + i),
          ],
          userPosition: _origin,
        );

        expect(options.single.density, HuntDensityLabel.localMedium);
      },
    );
  });
}

/// Nullpunkt der Testgeometrie, der Marienplatz.
const MapPosition _origin = MapPosition(latitude: 48.1374, longitude: 11.5755);

/// Ein Grad Breite in Metern, mit dem Erdradius von [MapPosition] (6371000).
const double _metersPerDegreeLatitude = 2 * math.pi * 6371000 / 360;

MapPosition _north(double meters) => MapPosition(
  latitude: _origin.latitude + meters / _metersPerDegreeLatitude,
  longitude: _origin.longitude,
);

HuntHotspot _hotspot(
  String name, {
  required double north,
  String density = 'hoch',
}) => HuntHotspot(name: name, position: _north(north), density: density);

Fact _factAt(int id, {required double north, List<FactPuzzle>? puzzles}) {
  final MapPosition position = _north(north);
  return Fact(
    id: FactId(id),
    content: FactText(title: 'Fakt $id'),
    coordinates: FactCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    ),
    puzzles:
        puzzles ??
        const <FactPuzzle>[
          FactPuzzle(question: 'Wie viele Löwen?', type: 'inschrift'),
        ],
  );
}

Fact _factWithoutCoordinates(int id) => Fact(
  id: FactId(id),
  content: FactText(title: 'Fakt $id'),
  puzzles: const <FactPuzzle>[
    FactPuzzle(question: 'Wie viele Löwen?', type: 'inschrift'),
  ],
);
