import 'package:fact_app/features/facts/data/mappers/raw_record_reader.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:fact_app/kernel/puzzle_operand.dart';

/// Baut ein `FactPuzzle` aus einem Element von `facts.puzzle_fit`.
///
/// ## Das echte Schema der Rätselobjekte
///
/// Nicht geraten, sondern aus drei Quellen zusammengetragen:
///
/// 1. `04_Datenpipeline/prompts/puzzle_classifier.md`, Abschnitt
///    „Ausgabe-Format": `type`, `difficulty`, `why`, `question`, `expected`,
///    `hint`, `confidence`.
/// 2. Der ausgelieferte Bestand in `02_Frontend/app/*-data*.jsx`: zusätzlich
///    `explanation`, `hints`, `gpsRadius`, `source`, `choices`, `operandA`,
///    `operandB`, `formula`, `expectedResult`.
/// 3. Die Lesestellen der PWA: `puzzle-sheet.jsx` liest zusätzlich
///    `expectedCount` (:461), `tolerance` (:462) und `puzzle_photo` (:168),
///    `hunt-generator.jsx` liest `findability` (:185) und `quality` (:197).
///
/// Alle davon werden abgebildet. Der alte Flutter-Port bildete vier ab, und
/// deshalb fiel dort jedes Rätsel auf ein Textfeld zurück.
///
/// ## Was absichtlich passiert
///
/// Der Mapper **entfernt** ein Generierungs-Artefakt aus der Frage. Ein Teil
/// des Bestands endet auf `\n\n→ ANTWORT_KURZ: 18`, also mit der Lösung im
/// Aufgabentext. Das darf ein Spieler nie sehen. Der alte Port hatte diese
/// Bereinigung schon, sie ist übernommen und nicht neu erfunden
/// (`08_Flutter/lib/models/fact.dart:329`).
///
/// Der Mapper **bewertet nichts**: keine Antwortprüfung, keine Punkte, kein
/// Ersatzwert für eine fehlende Schwierigkeit, keine Zuordnung von `type` zu
/// einer Eingabemaske. Das ist Sache der Domäne `puzzles`.
class FactPuzzleMapper {
  /// Zustandslos.
  const FactPuzzleMapper();

  /// Marker des Generierungs-Artefakts in `question`.
  static const String answerLeakMarker = 'ANTWORT_KURZ';

  static final RegExp _trailingArrow = RegExp(r'[\s\u2192\r\n]+$');

  /// Baut ein Rätsel aus [raw].
  ///
  /// Gibt `null` zurück, wenn das Element unbrauchbar ist: kein Objekt, oder
  /// ohne Frage. Beides wird über [reader] gemeldet, [path] ist der Pfad für
  /// den Bericht, etwa `puzzle_fit[1]`.
  FactPuzzle? mapPuzzle(
    Object? raw, {
    required RawRecordReader reader,
    required String path,
  }) {
    final element = RawRecordReader(raw);
    if (!element.isRecord) {
      reader.recordDefect(path, RawRecordReader.typeNameOf(raw));
      return null;
    }

    final question = _cleanQuestion(element.optionalString('question'));
    if (question == null) {
      reader.recordDefect('$path.question', 'fehlt');
      _forward(element, reader, path);
      return null;
    }

    final puzzle = FactPuzzle(
      question: question,
      type: element.optionalString('type'),
      difficulty: _difficulty(element, reader, path),
      expectedAnswer: element.optionalString('expected'),
      hint: element.optionalString('hint'),
      hints: element.stringList('hints'),
      explanation: element.optionalString('explanation'),
      rationale: element.optionalString('why'),
      confidence: element.optionalString('confidence'),
      provenance: element.optionalString('source'),
      findability: element.optionalString('findability'),
      quality: element.optionalInt('quality'),
      gpsRadiusMeters: element.optionalInt('gpsRadius'),
      choices: element.stringList('choices'),
      expectedCount: element.optionalInt('expectedCount'),
      countTolerance: element.optionalInt('tolerance'),
      operandA: _operand(element, 'operandA'),
      operandB: _operand(element, 'operandB'),
      formula: element.optionalString('formula'),
      expectedResult: element.optionalNum('expectedResult'),
      photoUrl: element.optionalString('puzzle_photo'),
    );

    _forward(element, reader, path);
    return puzzle;
  }

  /// Schneidet das Artefakt ab, das die Lösung verrät.
  ///
  /// Abgeschnitten wird ab dem Marker, danach fallen der davor stehende Pfeil
  /// und alle Leerzeichen weg. Der übrige Beobachtungshinweis nach `→` bleibt
  /// stehen: er ist gewollter Inhalt und steht in der PWA genauso in der
  /// Aufgabe.
  static String? _cleanQuestion(String? raw) {
    if (raw == null) {
      return null;
    }
    final cut = raw.indexOf(answerLeakMarker);
    final text = cut < 0
        ? raw
        : raw.substring(0, cut).replaceAll(_trailingArrow, '');
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static PuzzleDifficulty? _difficulty(
    RawRecordReader element,
    RawRecordReader reader,
    String path,
  ) {
    final code = element.optionalString('difficulty');
    if (code == null) {
      return null;
    }
    final difficulty = PuzzleDifficulty.fromCode(code);
    if (difficulty == null) {
      reader.recordDefect('$path.difficulty', 'unbekannte Stufe');
    }
    return difficulty;
  }

  static PuzzleOperand? _operand(RawRecordReader element, String field) {
    final raw = element.optionalObject(field);
    if (raw == null) {
      return null;
    }
    final operandReader = RawRecordReader(raw);
    final operand = PuzzleOperand(
      label: operandReader.optionalString('hint'),
      description: operandReader.optionalString('description'),
    );
    return operand.isEmpty ? null : operand;
  }

  /// Übernimmt die Befunde des Elements in den Bericht des Fakts, mit Pfad.
  static void _forward(
    RawRecordReader element,
    RawRecordReader reader,
    String path,
  ) {
    for (final defect in element.defects) {
      reader.recordDefect('$path.${defect.field}', defect.encounteredType);
    }
  }
}
