/// Schwierigkeitsstufe eines Rätsels an einem Fakt.
///
/// Die Werte stehen so in den Rätselobjekten von `facts.puzzle_fit`
/// (`04_Datenpipeline/prompts/puzzle_classifier.md`, Regel 2 und
/// Ausgabeformat). Sie sind Daten aus dem geteilten Backend und deshalb
/// deutsch, nicht Oberflächentext.
///
/// ## Nicht zu verwechseln mit dem alten `puzzle_fit`
///
/// Früher **war** `facts.puzzle_fit` selbst ein solcher String. Heute ist die
/// Spalte ein Array von Rätselobjekten, und die Stufe steht in jedem einzelnen
/// Objekt. Der alte Flutter-Port trug beide Bedeutungen im gleichen Feldnamen
/// (`08_Flutter/lib/models/fact.dart:39`) und hat sich damit die gesamte
/// Rätselmechanik weggeschnitten. Deshalb trägt hier die Liste den Namen
/// `Fact.puzzles`, und eine abgeleitete Stufe heißt
/// `Fact.easiestPuzzleDifficulty`. Der Name `puzzleFit` kommt nicht mehr vor.
///
/// ## Kein Standardwert
///
/// Fehlt die Stufe an einem Rätsel, bleibt sie `null`. Ein erfundener Standard
/// wäre hier gefährlich: `puzzle-sheet.jsx:92` setzt beim Fehlen `mittel` an,
/// und daran hängt die Münz-Berechnung. Der alte Port setzte an derselben
/// Stelle `leicht` (`fact.dart:337`). Wer welchen Ersatzwert nimmt, ist eine
/// Frage der Belohnungslogik und gehört den Domänen `puzzles` und
/// `progression`, nicht dem Datenmodell.
enum FactPuzzleDifficulty {
  /// Muss jeder Tourist lösen können.
  leicht('leicht'),

  /// Mittel.
  mittel('mittel'),

  /// Schwer.
  schwer('schwer');

  const FactPuzzleDifficulty(this.code);

  /// Der Wert, wie er in den Daten steht.
  final String code;

  /// Stufe zu [code] oder `null`, wenn der Wert unbekannt ist.
  ///
  /// Groß- und Kleinschreibung sowie Rand-Leerzeichen werden geglättet, weil
  /// die Daten von einem Sprachmodell und aus mehreren
  /// Pipeline-Generationen stammen.
  static FactPuzzleDifficulty? fromCode(String? code) {
    if (code == null) {
      return null;
    }
    final normalized = code.trim().toLowerCase();
    for (final value in values) {
      if (value.code == normalized) {
        return value;
      }
    }
    return null;
  }
}
