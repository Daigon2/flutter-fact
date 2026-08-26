/// Geografische Lage eines Fakts.
///
/// Quelle sind `facts.lat` und `facts.lng`, beide `numeric(9,6)`. Ein Fakt ohne
/// Koordinate ist für die Karte unbrauchbar, aber nicht ungültig: er bleibt in
/// der Liste und trägt hier `null`. Die Karte filtert selbst, genau wie
/// `_team_generate_orders` im Backend, das `lat is not null and lng is not null`
/// verlangt.
///
/// Warum das hier liegt und nicht in `core/geo/`: `project-structure.md` sieht
/// dort ein gemeinsames `GeoPoint` vor, aber Gate 6 verbietet der
/// Feature-Domäne jeden Import aus `core/`. Beides gleichzeitig geht nicht.
/// Dieses Wertobjekt heißt deshalb absichtlich [FactCoordinates] und nicht
/// `GeoPoint`: es beansprucht keine feature-übergreifende Gültigkeit. Wo der
/// gemeinsame Typ am Ende hingehört, ist eine offene Entscheidung und keine,
/// die dieser Schritt trifft.
class FactCoordinates {
  /// Erzeugt eine Lage ohne Prüfung. Für ungeprüfte Rohwerte gibt es
  /// [tryFrom].
  const FactCoordinates({required this.latitude, required this.longitude});

  /// Größter gültiger Breitengrad.
  static const double maxLatitude = 90;

  /// Größter gültiger Längengrad.
  static const double maxLongitude = 180;

  /// Baut eine Lage aus zwei Rohwerten oder gibt `null` zurück.
  ///
  /// `null` heißt: kein Punkt. Entweder fehlt ein Wert, oder er liegt außerhalb
  /// des gültigen Bereichs, oder er ist `NaN`. Der Aufrufer entscheidet, ob das
  /// eine Meldung wert ist; hier wird nicht geworfen.
  static FactCoordinates? tryFrom({double? latitude, double? longitude}) {
    if (latitude == null || longitude == null) {
      return null;
    }
    if (latitude.isNaN || longitude.isNaN) {
      return null;
    }
    if (latitude.abs() > maxLatitude || longitude.abs() > maxLongitude) {
      return null;
    }
    return FactCoordinates(latitude: latitude, longitude: longitude);
  }

  /// Breitengrad in Dezimalgrad.
  final double latitude;

  /// Längengrad in Dezimalgrad.
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is FactCoordinates &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  /// Bewusst ohne die Zahlen.
  ///
  /// `docs/engineering/security.md` §6 verbietet das Loggen genauer
  /// Koordinaten. Für Fakten ist die Lage öffentlicher Inhalt und keine
  /// Nutzerspur, aber `toString()` landet erfahrungsgemäß in denselben Logs wie
  /// Nutzerpositionen. Deshalb bleibt hier nichts stehen, das man mit einer
  /// Nutzerposition verwechseln könnte.
  @override
  String toString() => 'FactCoordinates(gesetzt)';
}
