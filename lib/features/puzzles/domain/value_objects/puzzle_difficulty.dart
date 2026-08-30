/// Schwierigkeitsstufe eines Rätsels, in der Domäne `puzzles`.
///
/// ## Diese Datei ist eine Kopie, und sie ist als solche gemeldet
///
/// Wortgleich zu `features/facts/domain/value_objects/fact_puzzle_difficulty.dart`.
/// Der Grund ist nicht Bequemlichkeit, sondern eine gemessene Sperre: Gate 6
/// in `tool/check_architecture.dart` lässt eine Feature-Domäne nur das
/// Dart-SDK, die eigene Feature-Domäne und geprüfte reine Dart-Pakete
/// importieren. Ein
/// `import 'package:fact_app/features/facts/domain/value_objects/fact_puzzle_difficulty.dart'`
/// aus `lib/features/puzzles/domain/` bricht mit Exit-Code 1 ab, gemessen am
/// 30.08.2026 mit einer Wegwerf-Probe. Der Übersetzer in
/// `puzzles/application/` darf es, die Domäne nicht.
///
/// **Das ist dieselbe Sperre wie bei D-9** (`REBUILD_STATUS.md`, Abschnitt
/// „Fragen an Dairen"): dort stehen drei identische Koordinatentypen
/// nebeneinander, weil Gate 6 einen gemeinsamen Typ in `core/geo` verbietet.
/// Hier ist es **die zweite Wiederholung desselben Musters**, jetzt nicht mehr
/// mit Koordinaten, sondern mit einem Wertobjekt einer fremden
/// Feature-Domäne. Die Kopie ist der Preis dafür, dass die Frage offen ist,
/// nicht eine Entscheidung gegen sie.
///
/// **Eine Antwort auf D-9, die über Koordinaten hinaus für Wertobjekte einer
/// fremden Feature-Domäne verallgemeinert, löscht diese Datei ersatzlos.**
/// Dann kommt die Stufe wieder aus `facts`, und in `puzzles` bleibt nichts
/// zurück, was umgestellt werden müsste: der einzige Ort, der beide Typen
/// gleichzeitig sieht, ist der Übersetzer.
///
/// ## Was bewusst **nicht** mitkopiert wurde
///
/// `FactPuzzleDifficulty` trägt einen langen Abschnitt über das alte
/// `puzzle_fit` und darüber, warum es keinen Standardwert gibt. Der Teil
/// gehört zur Datenherkunft und bleibt dort. Hier gilt nur die Folge daraus:
/// **kein Standardwert.** `puzzle-sheet.jsx:92` setzt beim Fehlen `mittel` an,
/// der alte Flutter-Port `leicht`. Welcher Ersatzwert gilt, entscheidet die
/// Auswertung in Schritt 28 zusammen mit E-08 und E-06, nicht dieser Vertrag.
enum PuzzleDifficulty {
  /// Muss jeder Tourist lösen können.
  leicht('leicht'),

  /// Mittel.
  mittel('mittel'),

  /// Schwer.
  schwer('schwer');

  const PuzzleDifficulty(this.code);

  /// Der Wert, wie er in den Daten steht.
  final String code;
}
