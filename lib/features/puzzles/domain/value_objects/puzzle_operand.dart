/// Ein Eingabewert eines Kombinations-Rätsels, in der Domäne `puzzles`.
///
/// ## Diese Datei ist eine Kopie, und sie ist als solche gemeldet
///
/// Wortgleich zu `FactPuzzleOperand` aus
/// `features/facts/domain/entities/fact_puzzle.dart`. Der Grund ist derselbe
/// wie bei `PuzzleDifficulty` nebenan und ebenso gemessen: Gate 6 in
/// `tool/check_architecture.dart` lässt eine Feature-Domäne nicht in die
/// Domäne eines fremden Features greifen. Ein solcher Import aus
/// `lib/features/puzzles/domain/` bricht mit Exit-Code 1 ab, derselbe Import
/// aus `lib/features/puzzles/application/` läuft durch.
///
/// **Das ist dieselbe Sperre wie bei D-9** (`REBUILD_STATUS.md`, Abschnitt
/// „Fragen an Dairen", drei identische Koordinatentypen) und **die zweite
/// Wiederholung desselben Musters**, hier an einem Wertobjekt statt an
/// Koordinaten. **Eine Antwort auf D-9, die für Wertobjekte einer fremden
/// Feature-Domäne verallgemeinert, löscht diese Datei ersatzlos**; umgestellt
/// werden müsste dann nur der Übersetzer in `puzzles/application/`, weil er
/// der einzige Ort ist, der beide Typen zugleich sieht.
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
  /// wäre. Es sind zwei verschiedene Dinge, und `Puzzle.hint` gibt es
  /// daneben.
  final String? label;

  /// Ausführlichere Erklärung, woher der Wert kommt (`description`).
  final String? description;

  /// Ist nichts gesetzt?
  bool get isEmpty => label == null && description == null;

  /// Wertgleichheit, wörtlich wie `FactPuzzleOperand.==`
  /// (`fact_puzzle.dart:327-333`).
  ///
  /// Sie fehlte in der ersten Fassung, und die Begründung dafür war falsch:
  /// im Kopf von `puzzle.dart` steht, Wertgleichheit koste hier eine dritte
  /// Kopie von `listsEqual` und `hashList`. Für **diesen** Typ stimmt das
  /// nicht, er hat nur zwei Zeichenketten und braucht nur `Object.hash`. Für
  /// `Puzzle` selbst trägt die Begründung weiter, dort stehen `hints` und
  /// `choices` im Weg.
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
