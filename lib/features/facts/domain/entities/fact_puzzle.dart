import 'package:fact_app/features/facts/domain/structural_equality.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:fact_app/kernel/puzzle_operand.dart';

/// Ein Rätsel, das an einem Fakt hängt.
///
/// ## Wo die Grenze zu `puzzles` liegt
///
/// Die Rätseldaten kommen als Spalte am Fakt an (`facts.puzzle_fit`, `jsonb`,
/// inhaltlich ein Array von zwei bis vier Objekten). Die Domäne `facts` **trägt**
/// sie, sie **wertet sie nicht aus**. Das heißt konkret:
///
/// * Hier steht jedes Feld, das die Daten mitbringen, vollständig und
///   unverändert.
/// * Hier steht **keine** Prüfung einer Nutzerantwort, keine Punkte- oder
///   Münzrechnung, kein Standardwert für eine fehlende Schwierigkeit, keine
///   Zuordnung von [type] zu einer Eingabemaske. Das gehört `puzzles` und
///   `progression` (`docs/architecture/domain-map.md`).
///
/// ## Warum das Modell alles trägt
///
/// Der alte Flutter-Port bildete aus jedem Rätselobjekt nur `type`, `question`,
/// `difficulty` und `expected` ab (`08_Flutter/lib/models/fact.dart:311`).
/// Alle Spezialfelder blieben leer, und damit fiel **jedes** Rätsel der App auf
/// ein einfaches Textfeld zurück, ohne dass ein Fehler sichtbar wurde. Die
/// gesamte Rätselmechanik war faktisch nicht vorhanden. Deshalb ist die
/// Feldliste hier vollständig belegt und nicht geraten.
///
/// ## Belege je Feld
///
/// | Schlüssel | Feld | Beleg |
/// |---|---|---|
/// | `type` | [type] | `puzzle_classifier.md` Ausgabeformat, `puzzle-sheet.jsx:250` |
/// | `difficulty` | [difficulty] | `puzzle_classifier.md` Regel 2, `puzzle-sheet.jsx:92` |
/// | `question` | [question] | `puzzle-sheet.jsx:195` |
/// | `expected` | [expectedAnswer] | `puzzle-sheet.jsx:323`, `:350`, `:450` |
/// | `hint` | [hint] | `puzzle-sheet.jsx:210` |
/// | `hints` | [hints] | Live-Daten, etwa `salzburg-data.jsx` |
/// | `explanation` | [explanation] | Live-Daten |
/// | `why` | [rationale] | `puzzle_classifier.md` Ausgabeformat |
/// | `confidence` | [confidence] | `puzzle_classifier.md` Regel 4, `hunt-generator.jsx:207` |
/// | `source` | [provenance] | Live-Daten (`"cowork"`) |
/// | `findability` | [findability] | `hunt-generator.jsx:185` |
/// | `quality` | [quality] | `hunt-generator.jsx:197` |
/// | `gpsRadius` | [gpsRadiusMeters] | `puzzle-sheet.jsx:372` |
/// | `choices` | [choices] | `puzzle-sheet.jsx:247`, `:343` |
/// | `expectedCount` | [expectedCount] | `puzzle-sheet.jsx:461` |
/// | `tolerance` | [countTolerance] | `puzzle-sheet.jsx:462` |
/// | `operandA` / `operandB` | [operandA] / [operandB] | `puzzle-sheet.jsx:506` |
/// | `formula` | [formula] | `puzzle-sheet.jsx:508` |
/// | `expectedResult` | [expectedResult] | `puzzle-sheet.jsx:509` |
/// | `puzzle_photo` | [photoUrl] | `puzzle-sheet.jsx:168` |
class FactPuzzle {
  /// [question] ist das einzige Pflichtfeld: ein Rätsel ohne Frage ist nicht
  /// spielbar. Der Mapper verwirft solche Einträge und meldet sie.
  const FactPuzzle({
    required this.question,
    this.type,
    this.difficulty,
    this.expectedAnswer,
    this.hint,
    this.hints = const <String>[],
    this.explanation,
    this.rationale,
    this.confidence,
    this.provenance,
    this.findability,
    this.quality,
    this.gpsRadiusMeters,
    this.choices = const <String>[],
    this.expectedCount,
    this.countTolerance,
    this.operandA,
    this.operandB,
    this.formula,
    this.expectedResult,
    this.photoUrl,
  });

  /// Wert von [findability], der einen Fakt für die Schnitzeljagd sperrt.
  ///
  /// `hunt-generator.jsx:186` schließt solche Fakten immer aus, unabhängig von
  /// der gewählten Stufe. Der Wert steht hier als Konstante, damit `puzzles`
  /// ihn nicht als Zeichenkette abschreiben muss.
  static const String notFindable = 'nicht-findbar';

  /// Art des Rätsels, roh.
  ///
  /// Absichtlich `String` und kein Enum. In den Live-Daten stehen elf
  /// verschiedene Werte, und sechs davon kennt die Tabelle `PSZ_TYPE_META` in
  /// `puzzle-sheet.jsx:36` nicht: `vor-ort` (761 Vorkommen), `inschrift` (277),
  /// `mcq` (246), `perspektive` (95), `zaehlen` (82), `sinne` (8). Ein Enum
  /// müsste diese Werte verwerfen oder umbenennen, und beides wäre eine
  /// Entscheidung über Rätselmechanik, die dieser Domäne nicht gehört.
  final String? type;

  /// Schwierigkeitsstufe, `null` wenn sie fehlt oder unbekannt ist.
  final PuzzleDifficulty? difficulty;

  /// Die Aufgabe, wie sie dem Spieler gezeigt wird.
  ///
  /// Der Mapper entfernt zuvor ein Generierungs-Artefakt, das die Lösung
  /// verrät. Siehe `FactPuzzleMapper`.
  final String question;

  /// Kanonische Antwort.
  ///
  /// Nullbar, weil Foto- und Perspektiven-Rätsel keine geschriebene Antwort
  /// brauchen: `puzzle-sheet.jsx` prüft dort nur die Entfernung und dass ein
  /// Foto vorliegt.
  final String? expectedAnswer;

  /// Einzelner Tipp. Kostet in der PWA Punkte.
  final String? hint;

  /// Gestufte Tipps, in den Daten meist drei.
  final List<String> hints;

  /// Auflösungstext, der nach dem Lösen gezeigt wird.
  final String? explanation;

  /// Warum der Klassifikator dieses Rätsel für passend hielt (`why`).
  ///
  /// Redaktionelle Begründung, kein Spielinhalt.
  final String? rationale;

  /// Wie sicher der Klassifikator war: `verified`, `uncertain`, `curated`.
  ///
  /// Zur Kenntnis: im gesamten ausgelieferten Bestand steht ausschließlich
  /// `curated`. Der Filter `confidence === 'verified'` in
  /// `hunt-generator.jsx:207` trifft damit nie und fällt immer auf die
  /// gelockerte Auswahl zurück.
  final String? confidence;

  /// Woher das Rätsel kommt (`source`), in den Live-Daten `cowork`.
  final String? provenance;

  /// Wie leicht der Ort zu finden ist: `leicht`, `mittel`, `schwer` oder
  /// [notFindable].
  ///
  /// Steht in keinem ausgelieferten Datensatz, wird von
  /// `hunt-generator.jsx:185` aber gelesen. Wird hier abgebildet, damit der
  /// Feldwert nicht verloren geht, sobald die Pipeline ihn setzt.
  final String? findability;

  /// Redaktionelle Güte des Rätsels.
  ///
  /// `hunt-generator.jsx:197` bevorzugt `quality >= 2`. Im ausgelieferten
  /// Bestand kommt das Feld nicht vor, der Vorzugsfilter greift also nie.
  final int? quality;

  /// Erlaubter Abstand zum Ort in Metern, für Foto-Rätsel.
  ///
  /// In den Daten durchgehend `150`. Der Ersatzwert, wenn das Feld fehlt,
  /// gehört zur Rätselmechanik und steht deshalb nicht hier.
  final int? gpsRadiusMeters;

  /// Antwortoptionen. Nicht leer heißt: als Auswahlfrage spielen.
  ///
  /// `puzzle-sheet.jsx:247` entscheidet ausdrücklich über dieses Feld und
  /// nicht über [type], weil der Typ im Konverter geraten wird.
  final List<String> choices;

  /// Erwartete Anzahl beim Abzählen (`tap-counter`).
  final int? expectedCount;

  /// Erlaubte Abweichung zu [expectedCount] für halbe Punkte.
  final int? countTolerance;

  /// Erster Eingabewert eines Kombi-Rätsels.
  final PuzzleOperand? operandA;

  /// Zweiter Eingabewert eines Kombi-Rätsels.
  final PuzzleOperand? operandB;

  /// Rechenvorschrift eines Kombi-Rätsels, etwa `b - a` oder `a * b`.
  ///
  /// Roh weitergegeben. Wer das auswertet, darf **nicht** wie die PWA
  /// (`puzzle-sheet.jsx:512`) einen `new Function`-Ausdruck daraus bauen. In
  /// Dart geht das ohnehin nicht, aber der Hinweis steht hier, damit niemand
  /// nach einem Ersatz dafür sucht.
  final String? formula;

  /// Erwartetes Ergebnis eines Kombi-Rätsels.
  ///
  /// `num`, weil eine Formel auch dividieren kann. Das Verbot von
  /// Gleitkommazahlen in `data-flow.md` gilt für Münzen und XP, nicht für ein
  /// Rechenergebnis.
  final num? expectedResult;

  /// Historisches Foto für ein Zeitreise-Rätsel (`puzzle_photo`).
  final String? photoUrl;

  /// Ist der Ort laut Daten überhaupt findbar?
  bool get isFindable => findability != notFindable;

  /// Soll das Rätsel als Auswahlfrage gespielt werden?
  ///
  /// Reine Aussage über die Daten, keine Mechanik: es gibt Antwortoptionen.
  bool get hasChoices => choices.isNotEmpty;

  /// Kopie mit einzelnen geänderten Feldern.
  FactPuzzle copyWith({
    String? question,
    String? type,
    PuzzleDifficulty? difficulty,
    String? expectedAnswer,
    String? hint,
    List<String>? hints,
    String? explanation,
    String? rationale,
    String? confidence,
    String? provenance,
    String? findability,
    int? quality,
    int? gpsRadiusMeters,
    List<String>? choices,
    int? expectedCount,
    int? countTolerance,
    PuzzleOperand? operandA,
    PuzzleOperand? operandB,
    String? formula,
    num? expectedResult,
    String? photoUrl,
  }) {
    return FactPuzzle(
      question: question ?? this.question,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      expectedAnswer: expectedAnswer ?? this.expectedAnswer,
      hint: hint ?? this.hint,
      hints: hints ?? this.hints,
      explanation: explanation ?? this.explanation,
      rationale: rationale ?? this.rationale,
      confidence: confidence ?? this.confidence,
      provenance: provenance ?? this.provenance,
      findability: findability ?? this.findability,
      quality: quality ?? this.quality,
      gpsRadiusMeters: gpsRadiusMeters ?? this.gpsRadiusMeters,
      choices: choices ?? this.choices,
      expectedCount: expectedCount ?? this.expectedCount,
      countTolerance: countTolerance ?? this.countTolerance,
      operandA: operandA ?? this.operandA,
      operandB: operandB ?? this.operandB,
      formula: formula ?? this.formula,
      expectedResult: expectedResult ?? this.expectedResult,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FactPuzzle &&
      other.question == question &&
      other.type == type &&
      other.difficulty == difficulty &&
      other.expectedAnswer == expectedAnswer &&
      other.hint == hint &&
      listsEqual(other.hints, hints) &&
      other.explanation == explanation &&
      other.rationale == rationale &&
      other.confidence == confidence &&
      other.provenance == provenance &&
      other.findability == findability &&
      other.quality == quality &&
      other.gpsRadiusMeters == gpsRadiusMeters &&
      listsEqual(other.choices, choices) &&
      other.expectedCount == expectedCount &&
      other.countTolerance == countTolerance &&
      other.operandA == operandA &&
      other.operandB == operandB &&
      other.formula == formula &&
      other.expectedResult == expectedResult &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    question,
    type,
    difficulty,
    expectedAnswer,
    hint,
    hashList(hints),
    explanation,
    rationale,
    confidence,
    provenance,
    findability,
    quality,
    gpsRadiusMeters,
    hashList(choices),
    expectedCount,
    countTolerance,
    operandA,
    operandB,
    formula,
    expectedResult,
    photoUrl,
  ]);

  @override
  String toString() =>
      'FactPuzzle(type: $type, difficulty: ${difficulty?.code}, '
      'choices: ${choices.length})';
}
