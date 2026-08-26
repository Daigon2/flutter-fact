/// Womit die Faktenliste eingeschränkt wird.
///
/// Absichtlich klein und ohne Transportbegriffe: keine Seitengröße, kein
/// Offset, kein `select`. Wie oft und in welchen Häppchen die Datenschicht
/// liest, ist deren Sache und darf sich ändern, ohne dass ein Aufrufer
/// nachzieht.
///
/// Der Stadtfilter greift **im Client**, nicht in der Abfrage. Grund: die
/// Datenbank speichert `facts.city` als Anzeigename, der Client rechnet mit
/// Slugs, und die Normalisierung liegt in der SQL-Funktion `_slugify`, die über
/// PostgREST nicht als Filter verfügbar ist. Die PWA löst das genauso: sie
/// lädt alle veröffentlichten Fakten und filtert danach
/// (`02_Frontend/app/api.jsx:119`). Siehe `FactCity` und E-11.
class FactQuery {
  /// Ohne Argumente: alle veröffentlichten Fakten.
  const FactQuery({this.citySlug});

  /// Alles.
  static const FactQuery all = FactQuery();

  /// Slug oder Anzeigename der Stadt, `null` für alle Städte.
  ///
  /// Wird über `FactCity.matchesSlug` verglichen, es darf also beides
  /// hineingegeben werden.
  final String? citySlug;

  /// Kopie mit anderem Stadtfilter. `null` löscht ihn nicht, dafür gibt es
  /// [all].
  FactQuery copyWith({String? citySlug}) =>
      FactQuery(citySlug: citySlug ?? this.citySlug);

  @override
  bool operator ==(Object other) =>
      other is FactQuery && other.citySlug == citySlug;

  @override
  int get hashCode => citySlug.hashCode;

  @override
  String toString() => 'FactQuery(citySlug: $citySlug)';
}
