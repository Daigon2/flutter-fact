import 'dart:math' as math;

import 'package:fact_app/features/discovery/presentation/fact_audio_beacon.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Regel des Audio-Beacons, `screen-map.jsx:2690-2718`.
///
/// **Die Hysterese ist der Kern dieser Datei.** Zwischen 150 und 200 Metern
/// passiert nichts, und ohne diese Spanne bekäme jemand, der an der Grenze
/// steht, alle fünf Sekunden denselben Ton.
void main() {
  const MapPosition user = MapPosition(latitude: 48.1372, longitude: 11.5756);

  MapOverlayPoint pointAt(String id, MapPosition position) => MapOverlayPoint(
    id: id,
    position: position,
    styleId: 'hist-uncollected',
    state: 'uncollected',
  );

  FactBeaconScan scan({
    required List<MapOverlayPoint> candidates,
    Map<String, FactBeaconState> states = const <String, FactBeaconState>{},
    Set<String> collected = const <String>{},
  }) => scanForFactBeacon(
    user: user,
    candidates: candidates,
    isCollected: collected.contains,
    states: states,
  );

  group('die Zahlen', () {
    test('höchstens alle fünf Sekunden', () {
      expect(factBeaconInterval, const Duration(seconds: 5));
    });

    test('der Merkzustand fällt erst über 200 Metern', () {
      expect(factBeaconResetInMeters, 200);
    });

    test('zwischen Ton und Ansage liegen 300 Millisekunden', () {
      expect(factBeaconSpeechDelay, const Duration(milliseconds: 300));
    });

    test('der Ton kommt innerhalb desselben Radius wie das Sammeln', () {
      // E-67: die 150 hat im Neubau **eine** Wahrheit.
      expect(factProximityRadiusInMeters, 150);
    });
  });

  group('die beiden Ränder, exakt', () {
    // Über Koordinaten wären beide nicht ansteuerbar, siehe die Begründung
    // an `factTapCollectsAt`. Als Funktionen auf einer Zahl sind sie es.
    test('genau 150 löst nicht mehr aus', () {
      expect(factBeaconFiresAt(150), isFalse);
      expect(factBeaconFiresAt(149.9), isTrue);
    });

    test('genau 200 setzt den Merkzustand nicht zurück', () {
      expect(factBeaconResetsAt(200), isFalse);
      expect(factBeaconResetsAt(200.1), isTrue);
    });

    test('zwischen 150 und 200 gilt beides nicht', () {
      // Das ist die Hysterese, in zwei Zeilen.
      expect(factBeaconFiresAt(175), isFalse);
      expect(factBeaconResetsAt(175), isFalse);
    });
  });

  group('das Zifferblatt, bearingToClockKey', () {
    test('Norden ist zwölf und nicht null', () {
      // Der Sonderfall der Quelle. Ohne ihn stünde in der Ansage „auf 0".
      expect(factBeaconClockOf(0), 12);
    });

    test('Osten ist drei, Süden sechs, Westen neun', () {
      expect(factBeaconClockOf(90), 3);
      expect(factBeaconClockOf(180), 6);
      expect(factBeaconClockOf(270), 9);
    });

    test('gerundet wird auf die nächste halbe Stunde', () {
      // `Math.round(normalized / 30)`: jede Stunde ist 30 Grad breit und
      // liegt um ihren Mittelpunkt.
      expect(factBeaconClockOf(14), 12);
      expect(factBeaconClockOf(16), 1);
      expect(factBeaconClockOf(44), 1);
      expect(factBeaconClockOf(46), 2);
    });

    test('kurz vor Norden ist wieder zwölf', () {
      // `round(11.5) = 12`, der Sonderfall greift hier gar nicht.
      expect(factBeaconClockOf(350), 12);
      expect(factBeaconClockOf(344), 11);
    });

    test('negative und übergroße Peilungen werden normalisiert', () {
      expect(factBeaconClockOf(-90), 9);
      expect(factBeaconClockOf(450), 3);
    });
  });

  group('die Stereo-Verteilung, bearingToPan', () {
    test('Norden mittig, Osten rechts, Westen links', () {
      expect(factBeaconBalanceOf(0), closeTo(0, 1e-12));
      expect(factBeaconBalanceOf(90), closeTo(1, 1e-12));
      expect(factBeaconBalanceOf(270), closeTo(-1, 1e-12));
    });

    test('Süden klingt wie Norden, und das ist die Grenze von Stereo', () {
      // Zwei Kanäle können eine Richtung auf einem Kreis nicht eindeutig
      // abbilden. Deshalb sagt die Ansage zusätzlich die Uhrzeit.
      expect(factBeaconBalanceOf(180), closeTo(0, 1e-12));
    });

    test('es ist der Sinus und keine lineare Rampe', () {
      // Bei 45 Grad wäre eine Rampe bei 0,5; der Sinus ist 0,707.
      expect(factBeaconBalanceOf(45), closeTo(math.sqrt1_2, 1e-12));
    });
  });

  group('die Suche', () {
    test('ohne Fakten in Reichweite gibt es kein Ziel', () {
      final FactBeaconScan result = scan(
        candidates: <MapOverlayPoint>[
          pointAt('1', _northOf(user, 400)),
          pointAt('2', _northOf(user, 160)),
        ],
      );

      expect(result.target, isNull);
      expect(result.bearing, isNull);
    });

    test('nimmt den nächsten in Reichweite', () {
      final FactBeaconScan result = scan(
        candidates: <MapOverlayPoint>[
          pointAt('fern', _northOf(user, 140)),
          pointAt('nah', _northOf(user, 40)),
        ],
      );

      expect(result.target?.id, 'nah');
    });

    test('liefert die Peilung zum Ziel mit', () {
      final FactBeaconScan result = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 40))],
      );

      // Genau nördlich, also 0 Grad, also zwölf Uhr.
      expect(result.bearing, closeTo(0, 0.001));
      expect(factBeaconClockOf(result.bearing!), 12);
    });

    test('überspringt gesammelte Fakten', () {
      final FactBeaconScan result = scan(
        candidates: <MapOverlayPoint>[
          pointAt('gesammelt', _northOf(user, 20)),
          pointAt('offen', _northOf(user, 100)),
        ],
        collected: <String>{'gesammelt'},
      );

      expect(result.target?.id, 'offen');
    });
  });

  group('die Hysterese', () {
    test('ein Ziel wird als „drinnen" vermerkt', () {
      final FactBeaconScan result = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 40))],
      );

      expect(result.states['1'], FactBeaconState.inRange);
    });

    test('derselbe Fakt kommt beim zweiten Mal nicht wieder dran', () {
      // Ohne den Merkzustand bekäme jemand, der stehen bleibt, denselben Ton
      // alle fünf Sekunden.
      final List<MapOverlayPoint> candidates = <MapOverlayPoint>[
        pointAt('1', _northOf(user, 40)),
      ];
      final FactBeaconScan first = scan(candidates: candidates);

      final FactBeaconScan second = scan(
        candidates: candidates,
        states: first.states,
      );

      expect(second.target, isNull);
    });

    test('zwischen 150 und 200 Metern bleibt der Vermerk stehen', () {
      // **Der Kern der Hysterese.** Wer sich auf 175 Meter entfernt und
      // zurückkommt, bekommt keinen zweiten Ton.
      final FactBeaconScan first = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 40))],
      );

      final FactBeaconScan awayABit = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 175))],
        states: first.states,
      );
      expect(awayABit.states['1'], FactBeaconState.inRange);

      final FactBeaconScan back = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 40))],
        states: awayABit.states,
      );

      expect(back.target, isNull);
    });

    test('über 200 Metern fällt der Vermerk, und danach tönt es wieder', () {
      final FactBeaconScan first = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 40))],
      );

      final FactBeaconScan away = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 400))],
        states: first.states,
      );
      expect(away.states['1'], FactBeaconState.outside);

      final FactBeaconScan back = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 40))],
        states: away.states,
      );

      expect(back.target?.id, '1');
    });

    test('ein zweiter Fakt kommt dran, während der erste vermerkt ist', () {
      final List<MapOverlayPoint> candidates = <MapOverlayPoint>[
        pointAt('erster', _northOf(user, 40)),
        pointAt('zweiter', _northOf(user, 90)),
      ];
      final FactBeaconScan first = scan(candidates: candidates);
      expect(first.target?.id, 'erster');

      final FactBeaconScan second = scan(
        candidates: candidates,
        states: first.states,
      );

      expect(second.target?.id, 'zweiter');
    });

    test('die Merkzustände kommen neu heraus und werden nicht verändert', () {
      // Sonst gäbe es zwei Wahrheiten: die Abbildung des Aufrufers und die
      // hier fortgeschriebene.
      final Map<String, FactBeaconState> given = <String, FactBeaconState>{};
      final FactBeaconScan result = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 40))],
        states: given,
      );

      expect(given, isEmpty);
      expect(result.states, hasLength(1));
    });

    test('ein gesammelter Fakt ändert seinen Vermerk nicht', () {
      // Das `continue` der Quelle steht **vor** der Entfernungsrechnung.
      // Praktisch folgenlos, aber so steht es dort.
      final FactBeaconScan result = scan(
        candidates: <MapOverlayPoint>[pointAt('1', _northOf(user, 400))],
        states: const <String, FactBeaconState>{'1': FactBeaconState.inRange},
        collected: <String>{'1'},
      );

      expect(result.states['1'], FactBeaconState.inRange);
    });
  });
}

/// Ein Punkt in [meters] Metern nördlich von [from].
///
/// Dieselbe Umrechnung wie in `fact_proximity_test.dart` und
/// `fact_collect_overlay_test.dart`.
MapPosition _northOf(MapPosition from, double meters) => MapPosition(
  latitude: from.latitude + meters * 180 / (math.pi * 6371000),
  longitude: from.longitude,
);
