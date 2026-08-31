import 'package:fact_app/features/progression/domain/value_objects/trophy_tier.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Stufenherleitung, wörtlich `screen-profil.jsx:184-203`.
///
/// Diese Funktion ist der wertvollste Testgegenstand des ganzen Blocks: sie
/// ist rein, hängt an nichts außer ihren drei Argumenten, und jede der 36
/// Trophäen durchläuft sie. Jeder Zweig bekommt hier mindestens einen Fall,
/// einschließlich des Standardzweigs und seiner Schwelle.
void main() {
  group('cat == mile', () {
    test('experte und legende sind Gold', () {
      expect(
        trophyTierOf(category: 'mile', key: 'experte', threshold: null),
        TrophyTier.gold,
      );
      expect(
        trophyTierOf(category: 'mile', key: 'legende', threshold: null),
        TrophyTier.gold,
      );
    });

    test('kenner und sammler sind Silber', () {
      expect(
        trophyTierOf(category: 'mile', key: 'kenner', threshold: null),
        TrophyTier.silver,
      );
      expect(
        trophyTierOf(category: 'mile', key: 'sammler', threshold: null),
        TrophyTier.silver,
      );
    });

    test('erster und entdecker sind Bronze', () {
      expect(
        trophyTierOf(category: 'mile', key: 'erster', threshold: null),
        TrophyTier.bronze,
      );
      expect(
        trophyTierOf(category: 'mile', key: 'entdecker', threshold: null),
        TrophyTier.bronze,
      );
    });
  });

  group('cat == rank', () {
    test('wochensieger ist Gold', () {
      expect(
        trophyTierOf(category: 'rank', key: 'wochensieger', threshold: null),
        TrophyTier.gold,
      );
    });

    test('top3_weekly ist Silber', () {
      expect(
        trophyTierOf(category: 'rank', key: 'top3_weekly', threshold: null),
        TrophyTier.silver,
      );
    });

    test('top10_weekly ist Bronze', () {
      expect(
        trophyTierOf(category: 'rank', key: 'top10_weekly', threshold: null),
        TrophyTier.bronze,
      );
    });
  });

  group('cat == city', () {
    test('grand_tour ist Gold', () {
      expect(
        trophyTierOf(category: 'city', key: 'grand_tour', threshold: null),
        TrophyTier.gold,
      );
    });

    test('stadtkenner und weltenbummler sind Silber', () {
      expect(
        trophyTierOf(category: 'city', key: 'stadtkenner', threshold: null),
        TrophyTier.silver,
      );
      expect(
        trophyTierOf(category: 'city', key: 'weltenbummler', threshold: null),
        TrophyTier.silver,
      );
    });

    test('ein Stadt-Erster ist Bronze', () {
      expect(
        trophyTierOf(category: 'city', key: 'münchen_first', threshold: null),
        TrophyTier.bronze,
      );
    });
  });

  test('cat == secret ist immer Gold, unabhängig von key und threshold', () {
    expect(
      trophyTierOf(category: 'secret', key: 'geheimtipp', threshold: null),
      TrophyTier.gold,
    );
    expect(
      trophyTierOf(category: 'secret', key: 'irgendwas', threshold: 999),
      TrophyTier.gold,
    );
  });

  group('Standardzweig: threshold entscheidet, ab 25 Silber', () {
    test('threshold 10 ist Bronze', () {
      expect(
        trophyTierOf(category: 'hist', key: 'chronist', threshold: 10),
        TrophyTier.bronze,
      );
    });

    test('threshold genau 25 ist schon Silber', () {
      expect(
        trophyTierOf(category: 'hist', key: 'meister_hist', threshold: 25),
        TrophyTier.silver,
      );
    });

    test('threshold 24 ist noch Bronze, die Grenze liegt bei 25', () {
      expect(
        trophyTierOf(category: 'hist', key: 'x', threshold: 24),
        TrophyTier.bronze,
      );
    });

    test('ohne threshold (null) zählt wie 0 und ist Bronze', () {
      // `def.threshold || 0` in der Quelle: `time`, `create` und `group`
      // haben kein `threshold`-Feld und sind deshalb immer Bronze.
      expect(
        trophyTierOf(category: 'time', key: 'fruehaufsteher', threshold: null),
        TrophyTier.bronze,
      );
      expect(
        trophyTierOf(category: 'create', key: 'autor', threshold: null),
        TrophyTier.bronze,
      );
      expect(
        trophyTierOf(category: 'group', key: 'koop_first', threshold: null),
        TrophyTier.bronze,
      );
    });
  });
}
