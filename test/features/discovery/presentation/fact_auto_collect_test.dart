import 'package:fact_app/features/discovery/presentation/fact_auto_collect.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Regel des automatischen Sammelns, `screen-map.jsx:1471-1489`.
///
/// **Warum diese Tests mit Metern statt mit Koordinaten arbeiten, wo es
/// möglich ist:** weil `fact_proximity_test.dart` beim Rand der 150 genau
/// daran gescheitert ist. Der Rand einer Entfernungsregel ist über zwei
/// Koordinaten nicht ansteuerbar, `2 * R * asin(sqrt(a))` hat dort keine
/// feinere Auflösung. Hier ist der Rand deshalb über eine gesuchte Distanz
/// angefahren, siehe [_positionAtDistance].
void main() {
  /// Ein Punkt in der Innenstadt von München.
  const MapPosition user = MapPosition(latitude: 48.1372, longitude: 11.5756);

  MapOverlayPoint pointAt(String id, MapPosition position) => MapOverlayPoint(
    id: id,
    position: position,
    styleId: 'hist-uncollected',
    state: 'uncollected',
  );

  group('pickAutomaticCollect', () {
    test('nimmt nichts, wenn kein Fakt in Reichweite ist', () {
      expect(
        pickAutomaticCollect(
          user: user,
          candidates: <MapOverlayPoint>[
            pointAt('1', _positionAtDistance(user, 25)),
            pointAt('2', _positionAtDistance(user, 140)),
          ],
          isEligible: (_) => true,
        ),
        isNull,
      );
    });

    test('nimmt den Fakt in Reichweite', () {
      final MapOverlayPoint? picked = pickAutomaticCollect(
        user: user,
        candidates: <MapOverlayPoint>[
          pointAt('1', _positionAtDistance(user, 25)),
          pointAt('2', _positionAtDistance(user, 10)),
        ],
        isEligible: (_) => true,
      );

      expect(picked?.id, '2');
    });

    test('nimmt den nächsten und nicht den ersten in Reichweite', () {
      // `d <= 18 && d < nearestD` (`:1483`): die Quelle sucht weiter, auch
      // wenn sie schon einen Treffer hat. Ohne den zweiten Vergleich stünde
      // hier '1'.
      final MapOverlayPoint? picked = pickAutomaticCollect(
        user: user,
        candidates: <MapOverlayPoint>[
          pointAt('1', _positionAtDistance(user, 17)),
          pointAt('2', _positionAtDistance(user, 4)),
          pointAt('3', _positionAtDistance(user, 12)),
        ],
        isEligible: (_) => true,
      );

      expect(picked?.id, '2');
    });

    test('bei gleicher Entfernung gewinnt der frühere in der Liste', () {
      // Die Folge von `<` statt `<=` im zweiten Vergleich. Zwei Fakten an
      // derselben Stelle sind der einzige Fall, in dem die Reihenfolge der
      // Überlagerung durchschlägt, und er ist im Bestand echt: mehrere
      // Fakten an einem Gebäude teilen sich die Koordinate.
      final MapPosition shared = _positionAtDistance(user, 9);

      expect(
        pickAutomaticCollect(
          user: user,
          candidates: <MapOverlayPoint>[
            pointAt('erster', shared),
            pointAt('zweiter', shared),
          ],
          isEligible: (_) => true,
        )?.id,
        'erster',
      );
    });

    test('überspringt, was nicht in Frage kommt, auch wenn es näher ist', () {
      final MapOverlayPoint? picked = pickAutomaticCollect(
        user: user,
        candidates: <MapOverlayPoint>[
          pointAt('gesammelt', _positionAtDistance(user, 2)),
          pointAt('offen', _positionAtDistance(user, 15)),
        ],
        isEligible: (String factId) => factId != 'gesammelt',
      );

      expect(picked?.id, 'offen');
    });

    test('fragt die Eignung, bevor es rechnet', () {
      // Nicht Kosmetik: die Prüfung steht in der Quelle vor dem `haversine`
      // (`:1479-1482`), und dieser Scan läuft bei jeder Ortung über alle
      // Fakten. Umgekehrt wäre er eine Wurzelberechnung je Fakt und
      // Ortungssignal, für Fakten, die ohnehin ausgeschlossen sind.
      final List<String> asked = <String>[];

      pickAutomaticCollect(
        user: user,
        candidates: <MapOverlayPoint>[
          pointAt('1', _positionAtDistance(user, 5)),
          pointAt('2', _positionAtDistance(user, 5)),
        ],
        isEligible: (String factId) {
          asked.add(factId);
          return false;
        },
      );

      expect(asked, <String>['1', '2']);
    });

    test('nimmt nichts aus einer leeren Überlagerung', () {
      expect(
        pickAutomaticCollect(
          user: user,
          candidates: const <MapOverlayPoint>[],
          isEligible: (_) => true,
        ),
        isNull,
      );
    });

    test('ein Fakt einen halben Meter dahinter bleibt liegen', () {
      // Der Rand über Koordinaten, und **hier ist er absichtlich grob**. Ein
      // Test, der ihn hier auf den Zentimeter anfährt, sähe aus wie eine
      // Randprüfung und wäre keine: genau 18,0 Meter sind über zwei
      // Koordinaten nicht erreichbar, deshalb nehmen `<=` und `<` beide den
      // erreichbaren Wert an. Der exakte Rand steht bei [factAutoCollectsAt].
      expect(
        pickAutomaticCollect(
          user: user,
          candidates: <MapOverlayPoint>[
            pointAt(
              'knapp draußen',
              _positionAtDistance(user, factAutoCollectRadiusInMeters + 0.5),
            ),
          ],
          isEligible: (_) => true,
        ),
        isNull,
      );
    });
  });

  group('factAutoCollectsAt, der Rand exakt', () {
    // Die Quelle prüft `d <= 18` und nimmt genau 18,0 also **an**. Das ist
    // die andere Wahl als beim Tipp, wo E-67 auf `<` festgelegt hat, und sie
    // steht bei [factAutoCollectRadiusInMeters] begründet: diese Zahl hat nur
    // eine Fundstelle, und die ist einschließend.
    //
    // Diese vier Fälle sind der Grund, warum der Vergleich eine eigene
    // Funktion ist. Über Koordinaten wäre der erste von ihnen nicht
    // ansteuerbar.
    test('genau am Radius wird gesammelt', () {
      expect(factAutoCollectsAt(18), isTrue);
    });

    test('der kleinste darstellbare Schritt dahinter nicht mehr', () {
      // `18.000000000000004`, der nächste `double` über 18. Wer `<=` zu `<`
      // macht, bricht den Test darüber; wer den Radius anhebt, bricht diesen.
      expect(factAutoCollectsAt(18 + 4e-15), isFalse);
    });

    test('davor wird gesammelt', () {
      expect(factAutoCollectsAt(17.9), isTrue);
      expect(factAutoCollectsAt(0), isTrue);
    });

    test('weit dahinter nicht', () {
      expect(factAutoCollectsAt(19), isFalse);
      expect(factAutoCollectsAt(150), isFalse);
    });
  });

  group('die Zahlen selbst', () {
    test('der Radius ist 18 und nicht die 30 aus dem Kommentar', () {
      // `d <= 18` in `screen-map.jsx:1483`, gegen „when entering 30m" drei
      // Zeilen darüber (`:1470`). Das Verhalten ist die Referenz. Dieser Test
      // ist die Stelle, an der jemand, der die 30 „korrigieren" will, hängen
      // bleibt.
      expect(factAutoCollectRadiusInMeters, 18);
    });

    test('die zweite Suche wartet 600 Millisekunden', () {
      // `setTimeout(..., 600)` in `screen-map.jsx:1544`.
      expect(factAutoCollectRescanDelay, const Duration(milliseconds: 600));
    });
  });
}

/// Ein Punkt genau [distanceInMeters] nördlich von [from].
///
/// Über eine Bisektion der Breitendifferenz und **nicht** über eine gerechnete
/// Umkehrung: die Prüfung soll dieselbe Funktion benutzen, die im Code
/// entscheidet, sonst prüft sie zwei Formeln gegeneinander. Der Abbruch bei
/// 60 Schritten ist reichlich, die Halbierung erreicht die Auflösung eines
/// `double` viel früher.
MapPosition _positionAtDistance(MapPosition from, double distanceInMeters) {
  double low = 0;
  double high = 0.01;
  for (int i = 0; i < 60; i++) {
    final double middle = (low + high) / 2;
    final MapPosition candidate = MapPosition(
      latitude: from.latitude + middle,
      longitude: from.longitude,
    );
    if (from.distanceInMetersTo(candidate) < distanceInMeters) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return MapPosition(latitude: from.latitude + high, longitude: from.longitude);
}
