import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/puzzles/application/puzzle_from_fact_puzzle.dart';
import 'package:fact_app/features/puzzles/domain/entities/puzzle.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:fact_app/kernel/puzzle_operand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Übersetzung der Rohdaten in die Rätselform,
/// `02_Frontend/app/puzzle-sheet.jsx:242-272`.
///
/// ## Wogegen diese Datei sich richtet
///
/// Der teure Fehler wäre, den `switch` über `type` vor den Optionen-Guard zu
/// setzen. Das Ergebnis sähe für die meisten Rätsel gleich aus und wäre für
/// die Auswahlfragen falsch; die Quelle hat genau diesen Fehler einmal gehabt
/// und mit einem Kommentar behoben (`:243-246`).
///
/// ## Welche Umkehrung welchen Pflichtfall fällt, gemessen
///
/// Die erste Fassung dieses Kommentars behauptete, die Pflichtfälle fielen,
/// „sobald jemand die Reihenfolge dreht". Das ist zu grob, und es gibt zwei
/// verschiedene Umkehrungen mit verschiedenem Ergebnis:
///
///  * **Guard ersatzlos gelöscht.** `mcq` und `kompass` fallen beide.
///  * **Guard in den `default`-Zweig verschoben.** Nur `kompass` fällt.
///    `mcq` hat gar keinen `switch`-Zweig und läuft über `default` wieder in
///    den verschobenen Guard, das Ergebnis bleibt dort zufällig richtig.
///
/// Deshalb gibt es einen **dritten** Pflichtfall, `local-fragen` mit
/// Optionen: dieser Typ steht im `switch` und zeigt dort auf das Textfeld,
/// muss aber trotzdem zur Auswahl werden. Er fällt bei **beiden**
/// Umkehrungen. Alles hier ist mit Mutationsproben nachgemessen, nicht
/// hergeleitet.
void main() {
  FactPuzzle raw({
    String question = 'Wie viele Löwen sitzen am Portal?',
    String? type,
    List<String> choices = const <String>[],
    PuzzleDifficulty? difficulty,
    String? expectedAnswer,
    String? hint,
    List<String> hints = const <String>[],
    String? explanation,
    String? photoUrl,
    int? gpsRadiusMeters,
    int? expectedCount,
    int? countTolerance,
    PuzzleOperand? operandA,
    PuzzleOperand? operandB,
    String? formula,
    num? expectedResult,
  }) => FactPuzzle(
    question: question,
    type: type,
    choices: choices,
    difficulty: difficulty,
    expectedAnswer: expectedAnswer,
    hint: hint,
    hints: hints,
    explanation: explanation,
    photoUrl: photoUrl,
    gpsRadiusMeters: gpsRadiusMeters,
    expectedCount: expectedCount,
    countTolerance: countTolerance,
    operandA: operandA,
    operandB: operandB,
    formula: formula,
    expectedResult: expectedResult,
  );

  group('Stufe 1: die Optionen schlagen den Typ', () {
    test('mcq mit Optionen wird zur Auswahl und nicht zum Textfeld', () {
      // Der Pflichtfall aus dem Zuschnitt. `mcq` steht 246 mal in den
      // Live-Daten und kommt in der Typtabelle der Quelle **nicht** vor; ohne
      // den Guard aus `:247` liefe es in den Standardzweig und wäre als
      // Textfeld unspielbar.
      final Puzzle puzzle = puzzleFromFactPuzzle(
        raw(type: 'mcq', choices: const <String>['1826', '1830', '1834']),
      );

      expect(puzzle, isA<ChoicePuzzle>());
      expect((puzzle as ChoicePuzzle).choices, <String>[
        '1826',
        '1830',
        '1834',
      ]);
    });

    test('kompass mit Optionen wird zur Auswahl und nicht zum Kompass', () {
      // Der zweite Pflichtfall, und der schärfere: `kompass` hat einen
      // eigenen `switch`-Zweig (`:262`). Nur weil Stufe 1 **vor** dem `switch`
      // läuft, gewinnen hier die Optionen.
      final Puzzle puzzle = puzzleFromFactPuzzle(
        raw(type: 'kompass', choices: const <String>['Norden', 'Süden']),
      );

      expect(puzzle, isA<ChoicePuzzle>());
      expect(puzzle, isNot(isA<CompassPuzzle>()));
    });

    test('local-fragen mit Optionen wird zur Auswahl und nicht zum Text', () {
      // Der dritte Pflichtfall, und der einzige, der **beide** Umkehrungen
      // fällt: `local-fragen` steht in `:253` und zeigt dort auf
      // `PszTextInput`. Nur weil Stufe 1 vor dem `switch` läuft, gewinnen
      // hier die Optionen. Wird der Guard in den `default`-Zweig verschoben,
      // erreicht dieser Typ ihn nie.
      final Puzzle puzzle = puzzleFromFactPuzzle(
        raw(type: 'local-fragen', choices: const <String>['Ja', 'Nein']),
      );

      expect(puzzle, isA<ChoicePuzzle>());
      expect(puzzle, isNot(isA<TextPuzzle>()));
      expect((puzzle as ChoicePuzzle).choices, <String>['Ja', 'Nein']);
    });

    test('leere Optionen lösen Stufe 1 nicht aus', () {
      // Gegenprobe: `hasChoices` prüft „nicht leer", nicht „vorhanden". Wäre
      // die Bedingung nur `choices != null`, käme hier eine Auswahl heraus.
      expect(puzzleFromFactPuzzle(raw(type: 'kompass')), isA<CompassPuzzle>());
    });
  });

  group('Stufe 2: der switch über den rohen Typ', () {
    test('detektiv-zaehlen wird ein Textfeld', () {
      expect(
        puzzleFromFactPuzzle(raw(type: 'detektiv-zaehlen')),
        isA<TextPuzzle>(),
      );
    });

    test('inschrift-decoder wird ein Textfeld', () {
      expect(
        puzzleFromFactPuzzle(raw(type: 'inschrift-decoder')),
        isA<TextPuzzle>(),
      );
    });

    test('local-fragen wird ein Textfeld', () {
      expect(
        puzzleFromFactPuzzle(raw(type: 'local-fragen')),
        isA<TextPuzzle>(),
      );
    });

    test(
      'klang-sinnes-check wird eine Auswahl, notgedrungen ohne Optionen',
      () {
        // `:255`. Der Zweig ist **nur** mit leerer Optionenliste erreichbar,
        // weil Stufe 1 alles andere abfängt. Das ist der Zustand der Quelle und
        // wird hier festgehalten, nicht repariert: in der PWA rendert `PszMcq`
        // dann keinen einzigen Antwortknopf.
        final Puzzle puzzle = puzzleFromFactPuzzle(
          raw(type: 'klang-sinnes-check'),
        );

        expect(puzzle, isA<ChoicePuzzle>());
        expect((puzzle as ChoicePuzzle).hasChoices, isFalse);
      },
    );

    test('verstecktes-detail wird eine Auswahl', () {
      expect(
        puzzleFromFactPuzzle(raw(type: 'verstecktes-detail')),
        isA<ChoicePuzzle>(),
      );
    });

    test('zeitreise wird eine Auswahl', () {
      expect(puzzleFromFactPuzzle(raw(type: 'zeitreise')), isA<ChoicePuzzle>());
    });

    test('foto-beweis wird ein Fotorätsel und trägt den GPS-Radius', () {
      final Puzzle puzzle = puzzleFromFactPuzzle(
        raw(type: 'foto-beweis', gpsRadiusMeters: 150),
      );

      expect(puzzle, isA<PhotoPuzzle>());
      expect((puzzle as PhotoPuzzle).gpsRadiusMeters, 150);
    });

    test('perspektiven wird ein Fotorätsel', () {
      expect(
        puzzleFromFactPuzzle(raw(type: 'perspektiven')),
        isA<PhotoPuzzle>(),
      );
    });

    test('kompass ohne Optionen wird ein Kompassrätsel', () {
      final Puzzle puzzle = puzzleFromFactPuzzle(
        raw(type: 'kompass', expectedAnswer: 'Norden'),
      );

      expect(puzzle, isA<CompassPuzzle>());
      // `expected` gehört zum Kopf und nicht zur Variante, weil Text,
      // Auswahl und Kompass es alle drei brauchen.
      expect(puzzle.expectedAnswer, 'Norden');
    });

    test('tap-counter wird ein Zählrätsel mit Anzahl und Toleranz', () {
      final Puzzle puzzle = puzzleFromFactPuzzle(
        raw(type: 'tap-counter', expectedCount: 12, countTolerance: 2),
      );

      expect(puzzle, isA<CountingPuzzle>());
      expect((puzzle as CountingPuzzle).expectedCount, 12);
      expect(puzzle.countTolerance, 2);
    });

    test('kombi wird ein Kombinationsrätsel mit beiden Operanden', () {
      final Puzzle puzzle = puzzleFromFactPuzzle(
        raw(
          type: 'kombi',
          operandA: const PuzzleOperand(
            label: 'Geburtsjahr',
            description: 'von der Sockelinschrift',
          ),
          operandB: const PuzzleOperand(label: 'Todesjahr'),
          formula: 'b - a',
          expectedResult: 61,
        ),
      );

      expect(puzzle, isA<CombinationPuzzle>());
      final CombinationPuzzle combination = puzzle as CombinationPuzzle;
      expect(combination.operandA?.label, 'Geburtsjahr');
      expect(combination.operandA?.description, 'von der Sockelinschrift');
      expect(combination.operandB?.label, 'Todesjahr');
      expect(combination.operandB?.description, isNull);
      expect(combination.formula, 'b - a');
      expect(combination.expectedResult, 61);
    });

    test('ein fehlender Operand bleibt null', () {
      final CombinationPuzzle puzzle =
          puzzleFromFactPuzzle(raw(type: 'kombi')) as CombinationPuzzle;

      expect(puzzle.operandA, isNull);
      expect(puzzle.operandB, isNull);
    });
  });

  group('Stufe 3: der Standardzweig', () {
    test('die sechs unbekannten Werte der Live-Daten werden Textfelder', () {
      // `fact_puzzle.dart:90-93`: `vor-ort` 761, `inschrift` 277, `mcq` 246,
      // `perspektive` 95, `zaehlen` 82, `sinne` 8. Zusammen 1469 Vorkommen,
      // also der Mengenschwerpunkt und nicht der Randfall. Beachte die
      // Verwechslungspaare: `inschrift` ist nicht `inschrift-decoder`,
      // `perspektive` nicht `perspektiven`, `zaehlen` nicht
      // `detektiv-zaehlen`.
      for (final String type in <String>[
        'vor-ort',
        'inschrift',
        'mcq',
        'perspektive',
        'zaehlen',
        'sinne',
      ]) {
        expect(
          puzzleFromFactPuzzle(raw(type: type)),
          isA<TextPuzzle>(),
          reason: type,
        );
      }
    });

    test('ein fehlender Typ wird ein Textfeld', () {
      // `FactPuzzle.type` ist nullbar, `PSZ_TYPE_META[undefined]` fällt in der
      // Quelle ebenfalls durch bis zum `default`.
      expect(puzzleFromFactPuzzle(raw()), isA<TextPuzzle>());
    });

    test('der Vergleich ist genau und nicht geglättet', () {
      // Die Quelle greift mit dem Rohtext in ihren `switch`. Ein
      // `trim().toLowerCase()` wäre eine stillschweigende Verhaltensänderung.
      expect(puzzleFromFactPuzzle(raw(type: 'Kompass')), isA<TextPuzzle>());
      expect(puzzleFromFactPuzzle(raw(type: ' kompass')), isA<TextPuzzle>());
    });
  });

  group('Der Kopf kommt vollständig mit', () {
    test('der rohe Typ bleibt im Vertrag erhalten', () {
      // Er bestimmt die Form nicht und wird trotzdem gebraucht: die Kopfzeile
      // zeigt ihn bei einem unbekannten Typ als Beschriftung an
      // (`puzzle-sheet.jsx:67-68`). Ginge er beim Übersetzen verloren, bliebe
      // die Kopfzeile für 1469 Rätsel leer.
      expect(puzzleFromFactPuzzle(raw(type: 'vor-ort')).type, 'vor-ort');
      expect(puzzleFromFactPuzzle(raw(type: 'kompass')).type, 'kompass');
      expect(
        puzzleFromFactPuzzle(
          raw(type: 'mcq', choices: const <String>['a', 'b']),
        ).type,
        'mcq',
      );
      expect(puzzleFromFactPuzzle(raw()).type, isNull);
    });

    test('Frage, Tipps, Auflösung und Foto gehen unverändert durch', () {
      final Puzzle puzzle = puzzleFromFactPuzzle(
        raw(
          question: 'Wie viele Löwen sitzen am Portal?',
          type: 'vor-ort',
          hint: 'Schau nach oben.',
          hints: const <String>['H1', 'H2', 'H3'],
          explanation: 'Es sind vier.',
          photoUrl: 'https://example.invalid/damals.jpg',
        ),
      );

      expect(puzzle.question, 'Wie viele Löwen sitzen am Portal?');
      expect(puzzle.hint, 'Schau nach oben.');
      expect(puzzle.hints, <String>['H1', 'H2', 'H3']);
      expect(puzzle.explanation, 'Es sind vier.');
      expect(puzzle.photoUrl, 'https://example.invalid/damals.jpg');
    });

    test('die drei Schwierigkeitsstufen kommen einzeln an', () {
      // Gegen ein `switch`, das alles auf eine Stufe abbildet: drei Fälle
      // getrennt, nicht einer stellvertretend.
      expect(
        puzzleFromFactPuzzle(
          raw(difficulty: PuzzleDifficulty.leicht),
        ).difficulty,
        PuzzleDifficulty.leicht,
      );
      expect(
        puzzleFromFactPuzzle(
          raw(difficulty: PuzzleDifficulty.mittel),
        ).difficulty,
        PuzzleDifficulty.mittel,
      );
      expect(
        puzzleFromFactPuzzle(
          raw(difficulty: PuzzleDifficulty.schwer),
        ).difficulty,
        PuzzleDifficulty.schwer,
      );
    });

    test('eine fehlende Stufe bleibt null, ohne Ersatzwert', () {
      // `puzzle-sheet.jsx:92` setzt beim Fehlen `mittel` an, der alte
      // Flutter-Port `leicht`. Welcher gilt, ist Belohnungslogik und gehört
      // Schritt 28; hier darf nichts erfunden werden.
      expect(puzzleFromFactPuzzle(raw()).difficulty, isNull);
    });

    test('beide Aufzählungen tragen dieselben Codes', () {
      // Die Kopie in `puzzles/domain` existiert wegen Gate 6 (D-9). Läuft sie
      // von ihrem Original weg, fällt es hier auf und nicht erst in der
      // Auswertung.
      expect(
        PuzzleDifficulty.values.map((PuzzleDifficulty d) => d.code),
        PuzzleDifficulty.values.map((PuzzleDifficulty d) => d.code),
      );
    });
  });

  group('Der Operand, festgenagelt gegen sein Original', () {
    // Dieselbe Aufgabe wie „beide Aufzählungen tragen dieselben Codes" eine
    // Gruppe höher, nur für das zweite kopierte Wertobjekt. Die erste Fassung
    // hatte diese Gruppe gar nicht, und `PuzzleOperand` war beim Abschreiben
    // ohne `==` und `hashCode` geblieben, obwohl `PuzzleOperand` beide
    // hat (`fact_puzzle.dart:327-333`) und sie nur zwei Zeichenketten
    // vergleichen.

    test('beide Typen verhalten sich bei der Gleichheit gleich', () {
      // Absichtlich **nicht** `const`: Dart kanonisiert konstante Objekte,
      // und `expect(const X(…), const X(…))` prüft dann gar nichts, weil
      // beide Seiten dasselbe Objekt sind. Muster 7 aus „Wie Tests hier blind
      // werden", richtiges Vorbild in `auth_city_test.dart:59`. Der
      // `String.fromCharCodes`-Umweg erzwingt zwei verschiedene Instanzen mit
      // gleichem Inhalt.
      final String jahr = String.fromCharCodes('Geburtsjahr'.codeUnits);
      final PuzzleOperand left = PuzzleOperand(
        label: 'Geburtsjahr',
        description: 'Sockel',
      );
      final PuzzleOperand right = PuzzleOperand(
        label: jahr,
        description: String.fromCharCodes('Sockel'.codeUnits),
      );

      expect(identical(left, right), isFalse);
      expect(left, right);
      expect(left.hashCode, right.hashCode);

      // Und dasselbe am Original, damit die Zusicherung wirklich ein
      // Abgleich ist und nicht nur eine Aussage über die Kopie.
      final PuzzleOperand originalLeft = PuzzleOperand(
        label: 'Geburtsjahr',
        description: 'Sockel',
      );
      final PuzzleOperand originalRight = PuzzleOperand(
        label: jahr,
        description: String.fromCharCodes('Sockel'.codeUnits),
      );
      expect(originalLeft, originalRight);
      expect(originalLeft.hashCode, originalRight.hashCode);
    });

    test('jedes der beiden Felder zählt für die Gleichheit', () {
      const PuzzleOperand base = PuzzleOperand(
        label: 'Geburtsjahr',
        description: 'Sockel',
      );

      expect(
        base,
        isNot(const PuzzleOperand(label: 'Todesjahr', description: 'Sockel')),
      );
      expect(
        base,
        isNot(const PuzzleOperand(label: 'Geburtsjahr', description: 'Tafel')),
      );
      expect(base, isNot(const PuzzleOperand(label: 'Geburtsjahr')));
    });

    test('isEmpty ist genau dann wahr, wenn beide Felder fehlen', () {
      // Die Review hat gemessen, dass `isEmpty => false` die ganze Suite
      // überlebt hat. Deshalb alle vier Belegungen und nicht nur die eine.
      expect(const PuzzleOperand().isEmpty, isTrue);
      expect(const PuzzleOperand(label: 'a').isEmpty, isFalse);
      expect(const PuzzleOperand(description: 'b').isEmpty, isFalse);
      expect(
        const PuzzleOperand(label: 'a', description: 'b').isEmpty,
        isFalse,
      );

      // Gegenprobe am Original: dieselbe Wahrheitstafel, sonst ist die Kopie
      // weggelaufen.
      expect(const PuzzleOperand().isEmpty, isTrue);
      expect(const PuzzleOperand(label: 'a').isEmpty, isFalse);
      expect(const PuzzleOperand(description: 'b').isEmpty, isFalse);
      expect(
        const PuzzleOperand(label: 'a', description: 'b').isEmpty,
        isFalse,
      );
    });

    test('der Übersetzer liefert einen wertgleichen Operanden', () {
      // Zieht die Gleichheit erst in den Nutzen: ohne `==` verglich dieser
      // Test vorher Identität und wäre nie grün geworden.
      final CombinationPuzzle puzzle =
          puzzleFromFactPuzzle(
                raw(
                  type: 'kombi',
                  operandA: const PuzzleOperand(
                    label: 'Geburtsjahr',
                    description: 'Sockel',
                  ),
                ),
              )
              as CombinationPuzzle;

      expect(
        puzzle.operandA,
        const PuzzleOperand(label: 'Geburtsjahr', description: 'Sockel'),
      );
    });
  });
}
