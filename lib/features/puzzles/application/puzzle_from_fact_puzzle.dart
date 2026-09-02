/// Übersetzung der Rohdaten eines Rätsels in den typisierten Vertrag.
///
/// ## Die einzige Datei im Feature, die `FactPuzzle` kennt
///
/// Und das ist keine Stilfrage, sondern gemessen: ein
/// `import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart'`
/// aus `lib/features/puzzles/domain/` lässt
/// `dart run tool/check_architecture.dart` mit **Exit-Code 1** abbrechen, mit
/// genau einer Meldung („[domain] Domain-Erlaubnisliste"). Derselbe Import aus
/// `lib/features/puzzles/application/` läuft mit **Exit-Code 0** durch. Beides
/// am 30.08.2026 mit Wegwerf-Proben nachgemessen, angelegt, ausgeführt,
/// gelöscht.
///
/// Daraus folgt der Zuschnitt: `puzzles/domain` kennt `facts` nicht, diese
/// Datei kennt beide Seiten, und `puzzles/presentation` arbeitet nur noch mit
/// [Puzzle]. Wer die Übersetzung an einen zweiten Ort kopiert, hat zwei
/// Wahrheiten über die Rätselform.
///
/// ## Zwei Umrechnungen sind mit ADR-008 verschwunden
///
/// Bis zum 31.08.2026 standen hier `_difficulty` und `_operand`, zwei
/// Funktionen, die eine Aufzählung und ein Wertobjekt aus `facts` in die
/// wortgleichen Gegenstücke in `puzzles/domain` übersetzten. Seit der geteilte
/// Kern beide Typen hält, sind die Gegenstücke gelöscht, und die Umrechnung ist
/// eine Zuweisung. **Das ist der ganze Gewinn von ADR-008 an dieser Stelle:**
/// vorher konnten die beiden Aufzählungen auseinanderlaufen, und der `switch`
/// dazwischen war die einzige Stelle, an der es aufgefallen wäre.
///
/// Was **nicht** verschwunden ist, ist diese Datei. `FactPuzzle` selbst bleibt
/// in `facts/domain`, und `puzzles/domain` darf es weiterhin nicht sehen: der
/// Kern hält Wertobjekte, keine Entitäten fremder Domänen.
///
/// ## Die Reihenfolge ist die Falle
///
/// **Der Rätseltyp wird nicht am Feld `type` entschieden.**
/// `02_Frontend/app/puzzle-sheet.jsx:242-272` prüft in drei Stufen, und die
/// erste gewinnt bedingungslos. Wer den `switch` zuerst laufen lässt, baut ein
/// anderes Programm, und zwar eines, das die Quelle ausdrücklich repariert
/// hat. Der Kommentar dort (`:243-246`) im Wortlaut:
///
/// > Antwort-Optionen vorhanden → IMMER als MCQ rendern, egal welcher type.
/// > Der type wird im Converter aus dem AKTION-Verb geraten und trägt das
/// > mcq-Signal nicht zuverlässig; ohne diesen Guard landete ein MCQ-Rätsel
/// > im default-Zweig (Textfeld) und wäre unspielbar.
///
/// ## Der Standardzweig ist der Mengenschwerpunkt, keine Ausnahme
///
/// In den Live-Daten stehen elf verschiedene Werte in `type`, und **sechs
/// davon kennt die Typtabelle der Quelle gar nicht**: `vor-ort` mit 761
/// Vorkommen, `inschrift` 277, `mcq` 246, `perspektive` 95, `zaehlen` 82,
/// `sinne` 8, zusammen 1469 (`fact_puzzle.dart:90-93`). Eine Aufzählung über
/// `type` wäre deshalb falsch, und der `default`-Zweig ist der häufigste Weg
/// durch diese Funktion, nicht der Notausgang.
library;

import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/puzzles/domain/entities/puzzle.dart';

/// Die Rätselform, die [source] laut Verhaltensquelle bekommt.
///
/// Reine Funktion, kein Zustand, keine Ein- und Ausgabe. Die drei Stufen
/// stehen unten in genau der Reihenfolge der Quelle; die Kommentare an den
/// Zweigen nennen jeweils die Zeile.
Puzzle puzzleFromFactPuzzle(FactPuzzle source) {
  // Stufe 1, `puzzle-sheet.jsx:247`:
  // `if (Array.isArray(puzzle.choices) && puzzle.choices.length > 0)`.
  //
  // `FactPuzzle.hasChoices` ist genau diese Prüfung und ist dort als „Reine
  // Aussage über die Daten, keine Mechanik" dokumentiert. Deshalb wird sie
  // benutzt statt nachgebaut: die Liste ist in `FactPuzzle` nie `null`, der
  // `Array.isArray`-Teil des Ausdrucks ist in Dart schon durch den Typ
  // erledigt.
  if (source.hasChoices) {
    return _choice(source);
  }

  // Stufe 2, `puzzle-sheet.jsx:250-269`. Ein `switch` über einen `String?`
  // ohne `default` wäre in Dart nicht erschöpfend; der `default`-Zweig unten
  // ist Stufe 3 und keine Bequemlichkeit.
  switch (source.type) {
    // `:251-253`
    case 'detektiv-zaehlen':
    case 'inschrift-decoder':
    case 'local-fragen':
      return _text(source);

    // `:255-256`. **Hier ist [ChoicePuzzle.choices] immer leer**, denn alles
    // mit Optionen hat schon Stufe 1 abgefangen. In der Quelle bekommt
    // `PszMcq` dann eine leere Optionenliste und rendert keinen einzigen
    // Antwortknopf, das Rätsel ist unspielbar. Das ist ein Defekt der Quelle
    // und **wird hier nicht still repariert**: welche Form ein solches Rätsel
    // stattdessen bekommt, ist eine Produktentscheidung und gehört zu
    // Schritt 28. Die Form bleibt deshalb dieselbe wie dort, der Zustand ist
    // an `ChoicePuzzle.choices` ablesbar.
    case 'klang-sinnes-check':
    case 'verstecktes-detail':
      return _choice(source);

    // `:258-259`
    case 'foto-beweis':
    case 'perspektiven':
      return PhotoPuzzle(
        question: source.question,
        type: source.type,
        gpsRadiusMeters: source.gpsRadiusMeters,
        difficulty: source.difficulty,
        expectedAnswer: source.expectedAnswer,
        hint: source.hint,
        hints: source.hints,
        explanation: source.explanation,
        photoUrl: source.photoUrl,
      );

    // `:262`
    case 'kompass':
      return CompassPuzzle(
        question: source.question,
        type: source.type,
        difficulty: source.difficulty,
        expectedAnswer: source.expectedAnswer,
        hint: source.hint,
        hints: source.hints,
        explanation: source.explanation,
        photoUrl: source.photoUrl,
      );

    // `:264`
    case 'tap-counter':
      return CountingPuzzle(
        question: source.question,
        type: source.type,
        expectedCount: source.expectedCount,
        countTolerance: source.countTolerance,
        difficulty: source.difficulty,
        expectedAnswer: source.expectedAnswer,
        hint: source.hint,
        hints: source.hints,
        explanation: source.explanation,
        photoUrl: source.photoUrl,
      );

    // `:266`
    case 'kombi':
      return CombinationPuzzle(
        question: source.question,
        type: source.type,
        operandA: source.operandA,
        operandB: source.operandB,
        formula: source.formula,
        expectedResult: source.expectedResult,
        difficulty: source.difficulty,
        expectedAnswer: source.expectedAnswer,
        hint: source.hint,
        hints: source.hints,
        explanation: source.explanation,
        photoUrl: source.photoUrl,
      );

    // `:268`. Zweiter Zweig, der ohne Optionen auf die Auswahlform zeigt,
    // siehe die Anmerkung bei `klang-sinnes-check`.
    case 'zeitreise':
      return _choice(source);

    // Stufe 3, `:270-271`: `default: return <PszTextInput …>`.
    default:
      return _text(source);
  }
}

/// Die Auswahlform, an drei Stellen gebraucht.
ChoicePuzzle _choice(FactPuzzle source) => ChoicePuzzle(
  question: source.question,
  type: source.type,
  choices: source.choices,
  difficulty: source.difficulty,
  expectedAnswer: source.expectedAnswer,
  hint: source.hint,
  hints: source.hints,
  explanation: source.explanation,
  photoUrl: source.photoUrl,
);

/// Die Textform, an zwei Stellen gebraucht.
TextPuzzle _text(FactPuzzle source) => TextPuzzle(
  question: source.question,
  type: source.type,
  difficulty: source.difficulty,
  expectedAnswer: source.expectedAnswer,
  hint: source.hint,
  hints: source.hints,
  explanation: source.explanation,
  photoUrl: source.photoUrl,
);
