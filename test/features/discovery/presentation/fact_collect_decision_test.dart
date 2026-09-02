import 'dart:math' as math;

import 'package:fact_app/features/discovery/presentation/fact_collect_decision.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Regel hinter einem Tipp auf einen Fakt-Ballon.
///
/// **Reine Funktion, ohne Widget und ohne Karte.** Das ist ihr Zweck: die
/// Anti-Sofa-Regel ist die Vor-Ort-Mechanik der ganzen App, und sie darf nicht
/// nur mittelbar über einen Widget-Baum geprüft sein.
void main() {
  const MapPosition user = MapPosition(latitude: 48.1351, longitude: 11.582);

  /// Ein Punkt in [meters] Metern nördlich von [user].
  ///
  /// Dieselbe Umrechnung wie in `fact_proximity_test.dart`: ein Grad Breite
  /// misst `π / 180 * 6371000 = 111194,93` Meter, der Erdradius ist der der
  /// Quelle (`screen-map.jsx:297`).
  MapPosition northOf(double meters) => MapPosition(
    latitude: user.latitude + meters * 180 / (math.pi * 6371000),
    longitude: user.longitude,
  );

  group('Der Hilfsaufbau', () {
    test('trifft die gemeinte Entfernung', () {
      // **Ohne diese Prüfung misst jeder Test darunter etwas anderes, als er
      // behauptet.** Träfe die Umrechnung daneben, wären „149 Meter" in
      // Wahrheit 160, und der Kantenfall wäre keiner.
      expect(user.distanceInMetersTo(northOf(100)), closeTo(100, 0.001));
      expect(user.distanceInMetersTo(northOf(149)), closeTo(149, 0.001));
    });
  });

  group('Die Anti-Sofa-Regel', () {
    test('ohne Ortung wird nicht gesammelt, sondern die Vorschau gezeigt', () {
      // **Der Kern der Regel und kein Randfall.** `screen-map.jsx:2137-2142`
      // hält den Fix wörtlich fest: „ohne GPS NIE die Fakt-Detail-Seite
      // direkt oeffnen". Vorher gab es dort ein `!dist || dist <= 50`, und
      // ein Nutzer in Italien bekam damit einen Münchner Fakt vollständig
      // angezeigt.
      final FactTapDecision decision = decideFactTap(
        user: null,
        // Direkt auf dem Fakt: **die Entfernung ist nicht das Argument**,
        // sondern die fehlende Ortung. Ein Aufbau mit einem weit entfernten
        // Fakt wäre aus dem falschen Grund grün.
        fact: user,
      );

      expect(decision.action, FactTapAction.teaser);
      expect(decision.collects, isFalse);
      expect(
        decision.distanceInMeters,
        isNull,
        reason: 'ohne Ortung gibt es keine Entfernung, auch nicht null Meter',
      );
    });

    test('innerhalb des Radius wird gesammelt', () {
      final FactTapDecision decision = decideFactTap(
        user: user,
        fact: northOf(149),
      );

      expect(decision.action, FactTapAction.collect);
      expect(decision.distanceInMeters, closeTo(149, 0.001));
    });

    test('außerhalb des Radius wird nicht gesammelt', () {
      final FactTapDecision decision = decideFactTap(
        user: user,
        fact: northOf(151),
      );

      expect(decision.action, FactTapAction.teaser);
      expect(
        decision.distanceInMeters,
        closeTo(151, 0.001),
        reason: 'die Entfernung geht in die Vorschau und muss echt sein',
      );
    });

    test('weit weg wird nicht gesammelt', () {
      // Der Fall aus dem Kommentar der Quelle: 1000 Kilometer entfernt.
      final FactTapDecision decision = decideFactTap(
        user: user,
        fact: northOf(1000000),
      );

      expect(decision.action, FactTapAction.teaser);
    });

    test('auf dem Fakt selbst wird gesammelt', () {
      // Null Meter: der naheliegendste übersehene Rückgabe-Zweig, weil 0 der
      // Nullwert vieler Typen ist.
      expect(decideFactTap(user: user, fact: user).collects, isTrue);
    });
  });

  group('Der Rand, E-67', () {
    test('genau am Radius wird nicht gesammelt', () {
      // **Das ist der Test, ohne den `<` von `<=` nicht unterscheidbar
      // ist**, und er geht bewusst nicht über Koordinaten: dort ist genau
      // 150,0 nicht erreichbar, gemessen mit einer Bisektion, siehe
      // `factTapCollectsAt`. Die Entscheidung aus E-67 hängt an genau diesem
      // einen Zeichen.
      expect(factProximityRadiusInMeters, 150);
      expect(factTapCollectsAt(150), isFalse);
    });

    test('einen Millimeter davor wird gesammelt', () {
      // Die Gegenprobe: ohne sie wäre auch ein `false` für alles grün.
      expect(factTapCollectsAt(149.999), isTrue);
    });

    test('einen Millimeter dahinter nicht', () {
      expect(factTapCollectsAt(150.001), isFalse);
    });

    test('der Rand über Koordinaten liegt zwischen den beiden Millimetern', () {
      // Der Weg, den `decideFactTap` wirklich nimmt. Genau 150,0 fehlt hier,
      // und das ist der Grund für die drei Prüfungen darüber.
      expect(
        decideFactTap(user: user, fact: northOf(149.999)).collects,
        isTrue,
      );
      expect(
        decideFactTap(user: user, fact: northOf(150.001)).collects,
        isFalse,
      );
    });

    test('die Regel benutzt denselben Radius wie die Näherungsrechnung', () {
      // **Keine vierte Wahrheit**, E-67. Fällt dieser Test, hat jemand einen
      // eigenen Radius für den Tipp eingeführt, und dann gibt es Ballons, die
      // leuchten, aber nicht sammeln.
      expect(factTapCollectsAt(factProximityRadiusInMeters - 0.001), isTrue);
      expect(factTapCollectsAt(factProximityRadiusInMeters), isFalse);
    });
  });

  group('toString', () {
    test('nennt keine Entfernung', () {
      // `security.md` §6: die Entfernung legt zusammen mit der öffentlich
      // bekannten Fakt-Koordinate den Aufenthaltsort auf einen Kreis fest.
      final FactTapDecision decision = decideFactTap(
        user: user,
        fact: northOf(37),
      );

      expect(decision.toString(), isNot(contains('37')));
      expect(decision.toString(), contains('collect'));
    });
  });
}
