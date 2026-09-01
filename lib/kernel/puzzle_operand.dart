/// Ein Eingabewert eines Kombinations-Rätsels.
///
/// ## Warum dieser Typ im geteilten Kern liegt
///
/// Zwei Feature-Domänen brauchen ihn, nachgewiesen und nicht vorhergesehen
/// (ADR-008, Aufnahmeregel 1): `facts` liest ihn aus den Rätselobjekten von
/// `facts.puzzle_fit`, `puzzles` zeigt und wertet ihn aus.
///
/// Vor ADR-008 gab es ihn zweimal, als `FactPuzzleOperand` in
/// `facts/domain/entities/fact_puzzle.dart` und als Kopie `PuzzleOperand` in
/// `puzzles/domain`. Die beiden waren **verhaltensgleich bis auf das letzte
/// Zeichen**: dieselben zwei Felder, dasselbe `isEmpty`, dasselbe `==`,
/// dasselbe `hashCode`. Ein Typ mit zwei Zeichenketten und ohne eigene Regel
/// ist der einfachste denkbare Fall für den Kern.
///
/// **Regel 3 aus ADR-008 ist hier trivial erfüllt:** dieser Typ hat kein
/// rollengebundenes Verhalten, weil er überhaupt keines hat außer
/// Wertgleichheit.
///
/// ## Der Inhalt
///
/// Steht in den Daten als `{"hint": "Geburtsjahr", "description": "Geburtsjahr
/// von der Sockelinschrift"}`. Die PWA zeigt nur [label]
/// (`puzzle-sheet.jsx:506`, Feld `hint`), [description] ist redaktionell und
/// wird trotzdem mitgeführt: die Eingabemaske aus Schritt 28 ist die erste
/// Stelle, an der jemand entscheiden kann, ob sie als Hilfstext unter das Feld
/// gehört.
library;

/// Ein Eingabewert eines Kombinations-Rätsels.
final class PuzzleOperand {
  /// Beide Felder optional, die Daten füllen nicht immer beide.
  const PuzzleOperand({this.label, this.description});

  /// Beschriftung des Eingabefelds (`hint` in den Daten).
  ///
  /// Heißt hier nicht `hint`, weil das mit dem Tipp zum Rätsel verwechselbar
  /// wäre. Es sind zwei verschiedene Dinge, und sowohl `FactPuzzle.hint` als
  /// auch `Puzzle.hint` gibt es daneben.
  final String? label;

  /// Ausführlichere Erklärung, woher der Wert kommt (`description`).
  final String? description;

  /// Ist nichts gesetzt?
  bool get isEmpty => label == null && description == null;

  @override
  bool operator ==(Object other) =>
      other is PuzzleOperand &&
      other.label == label &&
      other.description == description;

  @override
  int get hashCode => Object.hash(label, description);

  @override
  String toString() => 'PuzzleOperand($label)';
}
