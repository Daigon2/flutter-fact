import 'dart:math' as math;

/// Ein Punkt auf der Karte, in Dezimalgrad.
///
/// ## Warum es diesen Typ ein zweites Mal gibt
///
/// `features/facts` hat mit `FactCoordinates` bereits ein Wertobjekt für
/// genau dasselbe Konzept, und dieser Typ ist **keine** Nachlässigkeit: Gate 6
/// des Prüfskripts (`tool/check_architecture.dart`, `_isAllowedDomainImport`)
/// lässt in `lib/map/domain/` nur `dart:`-Importe und Dateien aus
/// `package:fact_app/map/.../domain/...` zu. `FactCoordinates` liegt in einem
/// anderen Modul und ist damit unerreichbar.
///
/// Das ist die **zweite** Instanz derselben Sperre. Die erste steht im
/// Kopfkommentar von
/// `lib/features/facts/domain/value_objects/fact_coordinates.dart:9-15`: dort
/// verhindert dieselbe Regel den Griff nach einem gemeinsamen `GeoPoint` in
/// `core/geo/`, das `project-structure.md` vorsieht.
///
/// [MapPosition] heißt deshalb bewusst nicht `GeoPoint` und **beansprucht
/// keine modulübergreifende Gültigkeit**. Wo der gemeinsame Geo-Typ am Ende
/// hingehört, ob nach `core/geo/` mit einer Ausnahme in der Erlaubnisliste,
/// in ein eigenes Dart-Paket oder gar nicht, ist eine offene Entscheidung.
/// Dieser Schritt trifft sie nicht, er hält nur fest, dass es jetzt zwei
/// Stellen sind, die auf sie warten.
///
/// ## Bewusst ohne Fabrik
///
/// `FactCoordinates` hat ein `tryFrom`, weil dort ungeprüfte Rohwerte aus der
/// Datenbank ankommen. Hier kommt nichts an: eine [MapPosition] entsteht aus
/// einem GPS-Fix oder aus einer bereits geprüften Fakt-Koordinate. Nach ADR-002
/// wächst die Struktur mit der Komplexität, also gibt es hier keine Prüfung,
/// solange es keinen ungeprüften Aufrufer gibt.
///
/// `final class`, weil der Typ Wertgleichheit hat. Eine Unterklasse mit einem
/// dritten Feld wäre nach diesem `==` gleich einer [MapPosition], umgekehrt
/// aber nicht, und damit hinge `a == b` an der Reihenfolge der Operanden.
final class MapPosition {
  /// Erzeugt einen Punkt ohne Prüfung.
  const MapPosition({required this.latitude, required this.longitude});

  /// Erdradius in Metern, wie ihn die Verhaltensquelle rechnet.
  ///
  /// `02_Frontend/app/screen-map.jsx:297` setzt in `haversine` `const R =
  /// 6371000`. Der Wert ist hier **übernommen und nicht selbst gewählt**: die
  /// Totzone von 12 Metern (`screen-map.jsx:2668`) ist gegen genau diese
  /// Rechnung geeicht, und ein anderer Radius, etwa der äquatoriale von
  /// 6378137 m aus WGS 84, würde dieselbe Schwelle bei einer anderen Strecke
  /// auslösen. Dass 6371000 zufällig auch der übliche mittlere Erdradius ist,
  /// ändert an der Begründung nichts: maßgeblich ist die Quelle.
  static const double earthRadiusInMeters = 6371000;

  /// Breitengrad in Dezimalgrad.
  final double latitude;

  /// Längengrad in Dezimalgrad.
  final double longitude;

  /// Abstand zu [other] in Metern, Großkreis über die Haversine-Formel.
  ///
  /// Gleiche Rechnung wie `screen-map.jsx:296-302`, inklusive der Form
  /// `2 * R * asin(sqrt(a))`. Sie existiert hier nicht auf Vorrat, sondern
  /// weil die Totzone der GPS-Folgeabsicht sie braucht: `movedSinceCamera > 12`
  /// in `screen-map.jsx:2668` ist genau dieser Abstand.
  ///
  /// Die Höhe bleibt außen vor, wie in der Quelle. Für Strecken im Bereich
  /// weniger Meter bis weniger Kilometer ist das ohne Bedeutung.
  double distanceInMetersTo(MapPosition other) {
    final double deltaLatitude = _toRadians(other.latitude - latitude);
    final double deltaLongitude = _toRadians(other.longitude - longitude);
    final double a =
        math.sin(deltaLatitude / 2) * math.sin(deltaLatitude / 2) +
        math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.sin(deltaLongitude / 2) *
            math.sin(deltaLongitude / 2);
    return 2 * earthRadiusInMeters * math.asin(math.sqrt(a));
  }

  /// Anfangs-Peilung nach [other] in Grad, 0 ist Norden, im Uhrzeigersinn.
  ///
  /// Gleiche Rechnung wie `mapBearing` in `screen-map.jsx:647-653`, inklusive
  /// des abschließenden `+ 360) % 360`, das negative Werte von `atan2` in
  /// `[0, 360)` faltet.
  ///
  /// **Anfangs-Peilung, nicht konstante Richtung.** Auf einem Großkreis ändert
  /// sich die Peilung unterwegs; dieser Wert gilt am Startpunkt. Für die
  /// Entfernungen einer Stadtjagd ist der Unterschied bedeutungslos, und die
  /// Quelle rechnet genauso.
  ///
  /// Sie existiert nicht auf Vorrat: die Jagd-Pille zeigt bei Schwierigkeit
  /// `leicht` einen Richtungspfeil (`screen-map.jsx:1052`), und
  /// `huntArrowIndexFor` braucht dafür eine Gradzahl. Ohne diese Methode wäre
  /// der Pfeil strukturell da und stünde dauerhaft still.
  ///
  /// **Der Rückgabewert auf demselben Punkt ist 0.** `atan2(0, 0)` ist in Dart
  /// `0`, und daraus folgt „Norden". Das ist keine Aussage über die Richtung,
  /// sondern die einzige, die eine Peilung ohne Strecke haben kann; wer sie
  /// anzeigt, prüft vorher den Abstand.
  double bearingInDegreesTo(MapPosition other) {
    final double deltaLongitude = _toRadians(other.longitude - longitude);
    final double y =
        math.sin(deltaLongitude) * math.cos(_toRadians(other.latitude));
    final double x =
        math.cos(_toRadians(latitude)) * math.sin(_toRadians(other.latitude)) -
        math.sin(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is MapPosition &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  /// Bewusst ohne die Zahlen.
  ///
  /// Aus demselben Grund wie bei `FactCoordinates.toString()`
  /// (`fact_coordinates.dart:60-68`): `docs/engineering/security.md` §6
  /// verbietet das Loggen genauer Koordinaten. Hier wiegt das schwerer als
  /// dort, denn eine [MapPosition] ist regelmäßig die **Nutzerposition** und
  /// nicht die öffentliche Lage eines Fakts.
  @override
  String toString() => 'MapPosition(gesetzt)';
}
