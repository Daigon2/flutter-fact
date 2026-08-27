/// Die Städte, die der Stadt-Picker der Registrierung anbietet,
/// `02_Frontend/app/screen-auth.jsx:562-567` (`AUTH_CITIES`).
///
/// ## Die Liste ist hartcodiert, und zwar in der Quelle
///
/// Kein Abruf, keine Ableitung aus den Faktdaten, kein Bezug zur Tabelle
/// `cities`. Die Zahlen sind der Stand des Tages, an dem jemand sie
/// hingeschrieben hat: München hatte 593 Fakten, Rom 100, Passau 73,
/// Regensburg 200. Sie veralten, ohne dass es auffällt, und sie können den
/// Faktdaten widersprechen.
///
/// Nachgebaut wie sie ist. Ein Abruf wäre neues Verhalten und bräuchte eine
/// Entscheidung: welche Tabelle, welcher Filter, was passiert offline, und wie
/// verhält sich der Picker, während die Liste lädt.
///
/// ## Warum das hier liegt und nicht in `features/city`
///
/// `lib/features/README.md:13` gibt `city` die Stadt-Identität, und dort
/// gehörte eine echte Städteliste hin. Diese hier ist keine: sie ist eine
/// hartcodierte Auswahl von vier Namen für ein Formularfeld, das die Heimatstadt
/// des Nutzers setzt. Sie in ein Feature zu legen, das noch nicht existiert,
/// hieße dessen Domäne zu erfinden, bevor jemand sie geschnitten hat.
///
/// **Wenn `features/city` gebaut wird, zieht die Liste dorthin.** Der Weg dahin
/// ist vorgezeichnet: der Picker bekommt seine Einträge dann von außen, statt
/// diese Konstante zu lesen. Deshalb nimmt `CityPicker` seine Liste als
/// Parameter und liest sie nicht selbst.
///
/// ## Und was das mit dem Mehrstadt-Versprechen zu tun hat
///
/// Nichts, was hier zu lösen wäre. Die Liste ist mehrstädtisch, München ist nur
/// die erste Zeile und die Vorbelegung. Kein Code hier setzt München als
/// Annahme.
library;

/// Eine Stadt im Picker.
///
/// Ein Wertobjekt mit Wertgleichheit, damit die Auswahl vergleichbar ist, ohne
/// über den Namen zu gehen. Die Quelle vergleicht `selectedCity?.name === c.name`
/// und braucht das, weil ein JavaScript-Objektvergleich Identität wäre.
final class AuthCity {
  /// Erzeugt eine Stadt.
  ///
  /// [active] ist in der Quelle nur bei München gesetzt und fehlt bei den
  /// anderen drei (`undefined`, also falsch). Hier hat es einen Standardwert,
  /// damit es kein `bool?` sein muss.
  const AuthCity({
    required this.name,
    required this.country,
    required this.facts,
    this.active = false,
  });

  /// Anzeigename, `München`.
  final String name;

  /// Ländercode, `DE`.
  final String country;

  /// Zahl der Fakten, wie in der Quelle hingeschrieben.
  final int facts;

  /// Ob die Stadt als "aktiv" beworben wird.
  ///
  /// Steuert nur den Untertitel der Karte: `signup.cityActiveBonus` statt
  /// `signup.cityFactsCount`. Es gibt keine Wirkung dahinter, der beworbene
  /// Bonus wird nirgends vergeben.
  final bool active;

  @override
  bool operator ==(Object other) =>
      other is AuthCity &&
      other.name == name &&
      other.country == country &&
      other.facts == facts &&
      other.active == active;

  @override
  int get hashCode => Object.hash(name, country, facts, active);

  @override
  String toString() => 'AuthCity($name, $country, $facts, active: $active)';
}

/// Die vier Städte der Quelle, in ihrer Reihenfolge.
///
/// Die Reihenfolge ist Verhalten: der Picker belegt mit dem **ersten** Eintrag
/// vor.
const List<AuthCity> authCities = <AuthCity>[
  AuthCity(name: 'München', country: 'DE', facts: 593, active: true),
  AuthCity(name: 'Rom', country: 'IT', facts: 100),
  AuthCity(name: 'Passau', country: 'DE', facts: 73),
  AuthCity(name: 'Regensburg', country: 'DE', facts: 200),
];

/// Die Städte, die zu [query] passen, `screen-auth.jsx:606-608`.
///
/// ## Drei Eigenheiten der Quelle, alle übernommen
///
/// 1. **Der Vergleich läuft auf dem ungetrimmten [query].** Ob überhaupt
///    gefiltert wird, entscheidet `query.trim()`; gesucht wird dann mit dem
///    rohen Wert. Eine Eingabe von `" m "` filtert also und findet nichts.
/// 2. **Keine Normalisierung.** Nur `toLowerCase`. `muenchen` findet München
///    nicht, `Munich` auch nicht. Es gibt in `FactCity.slug` eine passende
///    Normalisierung, aber die gehört zu `facts` und zu den Faktdaten, nicht zu
///    diesem Formularfeld; sie hier zu benutzen hieße, zwei Bedeutungen von
///    "Stadt" zu vermischen.
/// 3. **Nur der Name.** Der Ländercode wird nicht durchsucht, `DE` findet
///    nichts.
List<AuthCity> filterAuthCities(List<AuthCity> cities, String query) {
  if (query.trim().isEmpty) {
    return cities;
  }
  final needle = query.toLowerCase();
  return cities
      .where((city) => city.name.toLowerCase().contains(needle))
      .toList();
}
