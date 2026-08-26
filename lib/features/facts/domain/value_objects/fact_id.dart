/// Kennung eines Fakts.
///
/// Eigener Typ, weil im Umlauf zu viele nackte `int` unterwegs sind, die etwas
/// anderes bedeuten: `zone`, `bewertungen`, `quality_score`, dazu die
/// Nutzer-IDs. `docs/engineering/api-and-domain-design.md` nennt `FactId`
/// ausdrücklich als Beispiel.
///
/// Die Spalte `facts.id` ist in Postgres `bigint` und wird von der Datenbank
/// erzeugt (`generated always as identity`). Ein Dart-`int` ist auf den
/// Zielplattformen 64 Bit breit und deckt das ab.
class FactId {
  /// [value] muss positiv sein. Die Prüfung übernimmt der Mapper, weil nur er
  /// einen defekten Datensatz melden kann, statt zu werfen.
  const FactId(this.value);

  /// Der Zahlenwert, wie er in `facts.id` steht.
  final int value;

  @override
  bool operator ==(Object other) => other is FactId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FactId($value)';
}
