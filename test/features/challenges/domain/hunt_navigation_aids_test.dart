import 'package:fact_app/features/challenges/domain/hunt_navigation_aids.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Navigations-Gating nach Schwierigkeit, `screen-map.jsx:1044-1051`.
void main() {
  group('forDifficulty', () {
    test('leicht zeigt Pfeil und Distanz', () {
      final HuntNavigationAids aids = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.leicht,
      );

      expect(aids.showsArrow, isTrue);
      expect(aids.showsDistance, isTrue);
    });

    test('mittel zeigt nur Distanz, keinen Pfeil', () {
      final HuntNavigationAids aids = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.mittel,
      );

      expect(aids.showsArrow, isFalse);
      expect(aids.showsDistance, isTrue);
    });

    test('schwer zeigt weder Pfeil noch Distanz', () {
      final HuntNavigationAids aids = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.schwer,
      );

      expect(aids.showsArrow, isFalse);
      expect(aids.showsDistance, isFalse);
    });

    test('eine fehlende Stufe verhält sich wie mittel', () {
      // Die Quelle: `const diff = (activeHunt && activeHunt.difficulty) ||
      // 'mittel';` (`:1049`). Das gilt nur für dieses Gating, siehe die
      // Begründung am Bibliothekskopf, nicht für eine Belohnungsfrage.
      final HuntNavigationAids fromNull = HuntNavigationAids.forDifficulty(
        null,
      );
      final HuntNavigationAids fromMittel = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.mittel,
      );

      expect(fromNull, fromMittel);
      expect(fromNull.showsArrow, isFalse);
      expect(fromNull.showsDistance, isTrue);
    });
  });

  group('Gleichheit', () {
    test('gleiche Stufen ergeben gleiche Navigationshilfen', () {
      final HuntNavigationAids one = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.leicht,
      );
      final HuntNavigationAids two = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.leicht,
      );

      expect(one, two);
      expect(one.hashCode, two.hashCode);
    });

    test('unterschiedliche Stufen ergeben unterschiedliche Ergebnisse', () {
      final HuntNavigationAids leicht = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.leicht,
      );
      final HuntNavigationAids mittel = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.mittel,
      );
      final HuntNavigationAids schwer = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.schwer,
      );

      expect(leicht, isNot(mittel));
      expect(mittel, isNot(schwer));
      expect(leicht, isNot(schwer));
    });

    test('ein anderer Typ ist nicht gleich', () {
      final HuntNavigationAids aids = HuntNavigationAids.forDifficulty(
        PuzzleDifficulty.leicht,
      );

      expect(aids, isNot('leicht'));
    });
  });

  test('toString nennt beide Felder', () {
    final String text = HuntNavigationAids.forDifficulty(
      PuzzleDifficulty.leicht,
    ).toString();

    expect(text, contains('true'));
  });
}
