/// Die Stadt, in der ein Fakt liegt, so wie der Fakt sie trägt.
///
/// **Das ist nicht die Stadt-Identität.** Die gehört laut
/// `docs/architecture/domain-map.md` der Domäne `city`, und ein `CityId` als
/// gemeinsames Wertobjekt ist dort vorgesehen. Dieses Objekt kapselt nur, was
/// an einem Fakt wirklich dransteht, und genau dort steckt das Problem:
///
/// * `facts.city` ist `text` und trägt einen **Anzeigenamen**: `München`,
///   `Nürnberg`, `Rome`. Nachträglich ergänzt und per `nr`-Präfix gefüllt
///   (`03_Backend/migrations/2026-06-07_city_backfill_and_slug_match.sql`).
///   Für neue Datensätze kann die Spalte `NULL` sein.
/// * Das Frontend rechnet mit **Slugs**: `muenchen`, `nuernberg`.
/// * Die Brücke ist die SQL-Funktion `public._slugify`, die die
///   JavaScript-Normalisierung nachbaut. Dieser Bruch hat schon einmal
///   `create_team_session` mit `not_enough_facts_in_city` scheitern lassen,
///   obwohl München rund 600 Fakten hat.
///
/// Dieser Typ **kapselt** das und löst es nicht: er trägt beide Formen und
/// nennt die Quelle. Ob am Ende ein `CityId` in der Domäne `city` steht und wer
/// die Normalisierung besitzt, ist die offene Entscheidung E-11 aus
/// `REBUILD_STATUS.md`, Stufe 3.
class FactCity {
  /// [displayName] ist der Wert der Spalte, unverändert.
  const FactCity(this.displayName);

  /// Anzeigename, genau wie in `facts.city`.
  final String displayName;

  /// Vergleichsschlüssel, identisch zu `public._slugify`.
  ///
  /// Die SQL-Fassung lautet:
  ///
  /// ```sql
  /// regexp_replace(
  ///   replace(replace(replace(replace(lower(coalesce(p, '')),
  ///     'ü','ue'),'ö','oe'),'ä','ae'),'ß','ss'),
  ///   '[^a-z]', '', 'g')
  /// ```
  ///
  /// Reihenfolge und Umfang sind hier absichtlich gleich: erst kleinschreiben,
  /// dann die vier Ersetzungen in genau dieser Folge, dann alles außer `a`
  /// bis `z` entfernen. Wer das ändert, muss die SQL-Funktion mitändern, und
  /// die liegt in einem anderen Repository.
  ///
  /// Nebenwirkung, die man kennen muss: Ziffern und Akzente fallen weg.
  /// `Sant'Angelo 2` wird zu `santangelo`, `Piran` bleibt `piran`. Das ist
  /// nicht schön, aber es ist das Verhalten des Backends.
  String get slug {
    final lowered = displayName
        .toLowerCase()
        .replaceAll('ü', 'ue')
        .replaceAll('ö', 'oe')
        .replaceAll('ä', 'ae')
        .replaceAll('ß', 'ss');
    return lowered.replaceAll(_nonLatinLetters, '');
  }

  static final RegExp _nonLatinLetters = RegExp('[^a-z]');

  /// Passt dieser Fakt zu [otherSlug]?
  ///
  /// [otherSlug] wird ebenfalls normalisiert, damit ein Aufrufer sich nicht
  /// merken muss, ob er schon einen Slug oder noch einen Anzeigenamen hält.
  bool matchesSlug(String otherSlug) => slug == FactCity(otherSlug).slug;

  @override
  bool operator ==(Object other) =>
      other is FactCity && other.displayName == displayName;

  @override
  int get hashCode => displayName.hashCode;

  @override
  String toString() => 'FactCity($displayName -> $slug)';
}
