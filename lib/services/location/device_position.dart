/// Eine Ortung des Geräts, so wie der Ortungsdienst sie liefert.
///
/// ## Warum es diesen Typ ein drittes Mal gibt
///
/// Er beschreibt dasselbe Konzept wie `FactCoordinates` in `features/facts` und
/// wie `MapPosition` in `map/domain`, und er ist die **dritte** Instanz
/// derselben Sperre. Die beiden anderen tragen sie im Kopfkommentar:
/// `lib/features/facts/domain/value_objects/fact_coordinates.dart` und
/// `lib/map/domain/map_position.dart`. Gate 6 des Prüfskripts
/// (`tool/check_architecture.dart`, `_isAllowedDomainImport`) lässt in einer
/// Domäne nur `dart:`-Importe und Dateien der eigenen Domäne zu; ein
/// gemeinsamer Typ in `core/geo/`, den `project-structure.md` vorsieht, ist
/// damit für jede Domäne unerreichbar.
///
/// **Dieser Typ hier steht nicht in einer Domäne, sondern in `services/`, und
/// trotzdem entsteht er neu.** Der Grund ist der umgekehrte: ein Dienst, der
/// `MapPosition` liefert, gäbe dem Karten-Host den Aufenthaltsort des Nutzers
/// als Vertragsfläche, und ein Dienst, der `FactCoordinates` liefert, machte
/// die Nutzerposition zu einer Fakt-Koordinate. Der Ortungsdienst ist laut
/// `docs/architecture/domain-map.md:153-156` („The following are **not**
/// business domains", `geolocation provider`) keine Fachdomäne und darf
/// deshalb keine fremde Fachsprache erben.
///
/// **Offen und ausdrücklich nicht hier entschieden (D-9):** ob es künftig
/// **einen** geteilten Geo-Typ gibt oder weiter je einen lokalen. Fällt die
/// Antwort auf „einen gemeinsamen", wird diese Datei **ersatzlos gelöscht** und
/// nicht umgebaut: sie ist absichtlich so klein, dass ein „ja" eine Datei
/// kostet und keinen Umbau. Die Umrechnung nach `MapPosition` passiert deshalb
/// beim Verbraucher (`features/discovery`) und nicht hier.
///
/// ## Warum die Genauigkeit dazugehört
///
/// Ohne sie wäre der 35-Meter-Filter der Verhaltensquelle nicht baubar:
/// `02_Frontend/app/screen-map.jsx:2744` verwirft jede Ortung mit
/// `p.coords.accuracy > 35`, und der Kommentar darüber (`:2740-2741`) nennt den
/// Grund: sonst springt der Marker während der Aufwärmfolge Funkzelle → WLAN →
/// GPS beim Kaltstart. Die Genauigkeit ist damit kein Beiwerk, sondern der
/// einzige Grund, warum eine Ortung überhaupt verworfen wird.
///
/// `final class`, weil der Typ Wertgleichheit hat: eine Unterklasse mit einem
/// vierten Feld wäre nach diesem `==` gleich einer [DevicePosition], umgekehrt
/// aber nicht, und `a == b` hinge an der Reihenfolge der Operanden.
final class DevicePosition {
  /// Erzeugt eine Ortung ohne Prüfung.
  const DevicePosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyInMeters,
  });

  /// Breitengrad in Dezimalgrad.
  final double latitude;

  /// Längengrad in Dezimalgrad.
  final double longitude;

  /// Radius des 68-Prozent-Vertrauensbereichs in Metern.
  ///
  /// Dieselbe Größe wie `GeolocationCoordinates.accuracy` im Browser und
  /// `Position.accuracy` in `geolocator`. Kleiner ist besser.
  final double accuracyInMeters;

  @override
  bool operator ==(Object other) =>
      other is DevicePosition &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyInMeters == accuracyInMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyInMeters);

  /// Bewusst ohne die Zahlen.
  ///
  /// `docs/engineering/security.md` §6 verbietet genaue Koordinaten im Log, und
  /// hier wiegt das schwerer als bei einem Fakt: eine [DevicePosition] ist
  /// immer der Aufenthaltsort des Nutzers. Die Genauigkeit bleibt sichtbar, sie
  /// ist keine Ortsangabe und ohne sie wäre eine Diagnose der Filterschwelle
  /// wertlos.
  @override
  String toString() => 'DevicePosition(accuracyInMeters: $accuracyInMeters)';
}
