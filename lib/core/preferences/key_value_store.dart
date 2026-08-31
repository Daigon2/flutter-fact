/// Vertrag für den kleinen Gerätespeicher, auf dem die fünf Präferenz- und
/// Zustandsspeicher der App liegen.
///
/// ## Warum es diesen Vertrag gibt und nicht fünfmal `shared_preferences`
///
/// Fünf Speicher wollen dasselbe: beim Start einen Wert **synchron** lesen und
/// danach schreiben, ohne dass ein gescheiterter Schreibvorgang den Aufrufer
/// mitnimmt. `ADR-007` benennt für den Jagd-Speicher `challenges/data` als Ort
/// der persistenten Umsetzung, und die vier bestehenden Verträge sagen
/// wortgleich, wer sie später füllt. Fünf Umsetzungen an fünf Orten, die alle
/// dasselbe Vendor-Paket holen, wären fünf Stellen, an denen die Speichertechnik
/// bekannt ist.
///
/// Dieser Vertrag ist genau ein Ort weniger. Das Vorbild steht im Projekt:
/// `core/diagnostics/diagnostic_sink.dart` hält den Vertrag, die Umsetzung
/// steht in `services/diagnostics/`, und die Aufrufer kennen nur den Vertrag.
///
/// Die praktische Folge trägt drei Dinge, die eine direkte Paketnutzung nicht
/// hätte:
///
///  1. **Ein Heimatverzeichnis für das Vendor-Paket**, `lib/services/preferences/`,
///     durchgesetzt als Regel 22 in `dependency-rules.md`. Die Regeln 19 bis 21
///     tun dasselbe für WebView, Karten- und Geo-SDK.
///     `tool/check_architecture.dart` hat bis heute ausdrücklich **keine** Regel
///     für `shared_preferences` geführt, mit der Begründung, das Paket stehe
///     nicht in `pubspec.yaml` und es gebe keine Entscheidung, die ein
///     Heimatverzeichnis benennt. Beides gilt ab jetzt nicht mehr.
///  2. **Testbarkeit ohne Plattformkanal.** Ein Test der fünf Speicher braucht
///     weder `SharedPreferences.setMockInitialValues` noch eine initialisierte
///     Bindung, sondern [InMemoryKeyValueStore].
///  3. **Regel 11 bleibt gewahrt.** Unter `core/` steht kein Fachbegriff:
///     dieser Vertrag kennt weder Jagd noch Sprache noch Audio, nur Schlüssel
///     und Werte.
///
/// **Was er ausdrücklich nicht ist:** die Antwort auf OD-002, die lokale
/// Datenbank für Offline-Sammlung und Abgleich. `ADR-007` grenzt das ab, und die
/// Grenze steht hier noch einmal, weil sie an diesem Typ verlockend ist: hier
/// liegen wenige kleine Werte, die bei einer Formänderung verworfen werden
/// dürfen. Wer Abfragen, Migrationen oder Konfliktauflösung braucht, ist bei
/// OD-002 und nicht hier.
///
/// ## Lesen ist synchron, und das ist die tragende Eigenschaft
///
/// Alle fünf Verträge darüber begründen ausführlich, warum ihr Lesezugriff
/// synchron ist: die Entscheidung fällt beim ersten Bild, und ein `Future`
/// würde jeden Leser in einen Ladezustand zwingen. Dieser Vertrag hält das
/// durch. Der Preis steht in [KeyValueStore]: eine Umsetzung muss ihre Werte
/// **vor** dem ersten Lesezugriff geladen haben, und deshalb lädt `bootstrap()`
/// sie einmal und übergibt das Ergebnis an `productionProviderScope`.
///
/// ## Schreiben scheitert still
///
/// Kein Schreibvorgang wirft. Die Quelle macht es genauso und sagt auch, warum:
/// „localStorage voll oder geblockt — ignorieren" (`app.jsx:200`). Für die Jagd
/// verlangt `ADR-007` es ausdrücklich, denn ein verlorener Speichervorgang darf
/// keinen Spielzug zurücknehmen. Für die vier anderen kostet ein verlorener
/// Schreibvorgang eine Unbequemlichkeit beim nächsten Start.
///
/// Still heißt **nicht** unsichtbar: die Umsetzung meldet den Fehlschlag an
/// `DiagnosticSink`. Wer das nicht tut, baut den stillen Ausfall, vor dem
/// `test/app/bootstrap_test.dart` das ganze Projekt schützt.
library;

/// Kleiner Schlüssel-Wert-Speicher des Geräts.
///
/// Die Schlüssel sind Zeichenketten und gehören dem Aufrufer. Wer einen
/// Schlüssel vergibt, legt ihn als Konstante neben seine Umsetzung, damit es
/// keine zweite Stelle gibt, an der derselbe Name getippt wird.
abstract interface class KeyValueStore {
  /// Der Wahrheitswert zu [key], oder `null`, wenn nichts gespeichert ist.
  ///
  /// `null` bedeutet ausdrücklich „nichts gespeichert" und nicht `false`. Die
  /// Unterscheidung ist bei der Sprachwahl tragend (`null` heißt „noch nie
  /// gewählt", und nur so zeigt der Splash die Auswahl), und ein Vertrag, der
  /// sie an einer Stelle einzieht, verliert sie überall.
  ///
  /// Liegt unter [key] ein Wert anderen Typs, ist das Ergebnis `null`. Ein
  /// falsch typisierter Wert ist derselbe Fall wie ein fehlender: der Aufrufer
  /// kann in beiden nichts anderes tun.
  bool? readBool(String key);

  /// Die Zeichenkette zu [key], oder `null`, wenn nichts gespeichert ist.
  ///
  /// Gleiche Regel wie [readBool] für einen falsch typisierten Wert.
  String? readString(String key);

  /// Speichert [value] unter [key].
  ///
  /// Wirft nicht. Scheitert der Gerätespeicher, bleibt der alte Wert stehen und
  /// die Umsetzung meldet es an ihre Diagnosesenke.
  Future<void> writeBool(String key, bool value);

  /// Speichert [value] unter [key].
  ///
  /// Wirft nicht, wie [writeBool].
  Future<void> writeString(String key, String value);

  /// Löscht den Wert unter [key].
  ///
  /// Idempotent: ohne gespeicherten Wert passiert nichts. Wirft nicht.
  Future<void> remove(String key);
}

/// Flüchtige Umsetzung für Tests und als Rückfall, wenn der Gerätespeicher
/// nicht zu laden ist.
///
/// Sie ist bewusst **kein** stiller Standard eines Providers: es gibt keinen
/// `keyValueStoreProvider`. Der Weg führt über `bootstrap()`, das den geladenen
/// Speicher an `productionProviderScope` übergibt. Ein Provider mit flüchtigem
/// Standard wäre genau der Ausfall, den das Projekt an vier anderen Stellen
/// schon einmal gebaut und dann mit Tests abgesichert hat: die App startet,
/// sieht heil aus, und merkt sich nichts.
final class InMemoryKeyValueStore implements KeyValueStore {
  /// [values] setzt einen bereits gefüllten Speicher, etwa in einem Test.
  ///
  /// Die Abbildung wird kopiert. Ein Test, der sein Literal nach dem Bau noch
  /// ändert, soll den Speicher nicht mitverändern.
  InMemoryKeyValueStore([Map<String, Object> values = const {}])
    : _values = Map<String, Object>.of(values);

  final Map<String, Object> _values;

  @override
  bool? readBool(String key) {
    final Object? value = _values[key];
    return value is bool ? value : null;
  }

  @override
  String? readString(String key) {
    final Object? value = _values[key];
    return value is String ? value : null;
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
