/// Die drei Sammelstufen einer Trophäe.
///
/// `wallet-colors.jsx` trägt kein Datenfeld dafür. Die Stufe entsteht erst in
/// `screen-profil.jsx:184-203` (`trophyTier`), aus Kategorie, Schlüssel und
/// Schwelle einer Trophäe. [trophyTierOf] baut genau diese Funktion nach.
enum TrophyTier {
  /// `'bronze'` in `tierC`, `:218`.
  bronze,

  /// `'silver'` in `tierC`, `:218`.
  silver,

  /// `'gold'` in `tierC`, `:218`.
  gold,
}

/// Leitet die Stufe einer Trophäe ab, wörtlich `screen-profil.jsx:184-203`.
///
/// Die Reihenfolge der Zweige **ist** die Regel und entscheidet über den
/// Vorrang: `mile`, `rank` und `city` schauen zuerst auf den `key`, `secret`
/// ist danach immer Gold, und erst der Standardzweig sieht auf [threshold].
/// Eine Trophäe ohne Schwelle zählt dort wie eine Schwelle von `0`
/// (`def.threshold || 0` in der Quelle) und landet auf Bronze; das betrifft
/// nicht nur die Stadt-, Rang- und Meilenstein-Trophäen (die vorher schon
/// zurückkehren), sondern auch `time`, `create` und `group`, die **immer**
/// Bronze sind, weil sie kein `threshold`-Feld haben und keinen der drei
/// benannten Zweige treffen.
///
/// Reine Funktion über drei Primitiv-Werte, keine Domäne kennt sie: [key] und
/// [category] sind die rohen Zeichenketten aus `wallet-colors.jsx`, nicht
/// etwa ein Enum. Ein Enum für elf verschiedene `cat`-Werte wäre hier eine
/// Kategorisierung, die die Quelle selbst nicht kennt: `trophyTier` vergleicht
/// mit dem Rohtext, nicht mit einem geschlossenen Aufzählungstyp.
TrophyTier trophyTierOf({
  required String category,
  required String key,
  required int? threshold,
}) {
  switch (category) {
    case 'mile':
      if (key == 'experte' || key == 'legende') {
        return TrophyTier.gold;
      }
      if (key == 'kenner' || key == 'sammler') {
        return TrophyTier.silver;
      }
      return TrophyTier.bronze;
    case 'rank':
      if (key == 'wochensieger') {
        return TrophyTier.gold;
      }
      if (key == 'top3_weekly') {
        return TrophyTier.silver;
      }
      return TrophyTier.bronze;
    case 'city':
      if (key == 'grand_tour') {
        return TrophyTier.gold;
      }
      if (key == 'stadtkenner' || key == 'weltenbummler') {
        return TrophyTier.silver;
      }
      return TrophyTier.bronze;
    case 'secret':
      return TrophyTier.gold;
    default:
      return (threshold ?? 0) >= 25 ? TrophyTier.silver : TrophyTier.bronze;
  }
}
