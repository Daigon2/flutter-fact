import 'package:fact_app/features/facts/data/mappers/fact_mapper.dart';
import 'package:fact_app/features/facts/data/mappers/fact_puzzle_mapper.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_defect.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_puzzle_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fact_row_fixtures.dart';

/// Prüft, dass **jedes** Feld eines Rätselobjekts ankommt.
///
/// Der Grund für die Genauigkeit: `PuzzleConfig.fromFactPuzzle` im alten Port
/// bildete nur `type`, `question` und `expected` ab. Alle Spezialfelder blieben
/// leer, und damit fiel jedes Rätsel der App auf ein Textfeld zurück, ohne dass
/// ein Fehler sichtbar wurde. Ein Test, der nur „ein Rätsel kam an" prüft,
/// hätte diesen Ausfall nicht bemerkt.
void main() {
  const mapper = FactMapper();

  /// Bildet ein einzelnes Rätselobjekt über den vollen Weg ab.
  FactPuzzle onlyPuzzle(Map<String, dynamic> puzzle) {
    final result = mapper.mapRecords(<Object?>[
      factRow(
        overrides: <String, Object?>{
          'puzzle_fit': <Object?>[puzzle],
        },
      ),
    ]);
    return result.facts.single.puzzles.single;
  }

  group('Kombi-Rätsel, der Fall mit den meisten Feldern', () {
    test('alle Rechenfelder kommen an', () {
      final puzzle = onlyPuzzle(puzzleRowKombi());

      expect(puzzle.type, 'kombi');
      expect(puzzle.difficulty, FactPuzzleDifficulty.mittel);
      expect(puzzle.question, startsWith('Am Sockel der Statue'));
      expect(puzzle.expectedAnswer, '78 Jahre');
      expect(puzzle.explanation, startsWith('Tartini wurde 1692'));
      expect(puzzle.gpsRadiusMeters, 150);
      expect(puzzle.confidence, 'curated');
      expect(puzzle.provenance, 'cowork');
      expect(puzzle.formula, 'b - a');
      expect(puzzle.expectedResult, 78);
      expect(puzzle.operandA?.label, 'Geburtsjahr');
      expect(puzzle.operandA?.description, contains('Sockelinschrift'));
      expect(puzzle.operandB?.label, 'Sterbejahr');
      expect(puzzle.operandB?.description, contains('Sockelinschrift'));
    });

    test('expectedResult darf eine Kommazahl sein', () {
      final puzzle = onlyPuzzle(
        puzzleRowKombi(
          overrides: <String, Object?>{
            'formula': 'a / b',
            'expectedResult': 2.5,
          },
        ),
      );

      expect(puzzle.formula, 'a / b');
      expect(puzzle.expectedResult, 2.5);
    });

    test('ein Operand ohne Inhalt bleibt null statt leer', () {
      final puzzle = onlyPuzzle(
        puzzleRowKombi(
          overrides: <String, Object?>{'operandA': <String, dynamic>{}},
        ),
      );

      expect(puzzle.operandA, isNull);
      expect(puzzle.operandB, isNotNull);
    });
  });

  group('Auswahlrätsel', () {
    test('choices kommen als Liste an', () {
      final puzzle = onlyPuzzle(puzzleRowMcq());

      expect(puzzle.choices, hasLength(3));
      expect(puzzle.hasChoices, isTrue);
      expect(puzzle.choices[1], puzzle.expectedAnswer);
      expect(puzzle.difficulty, FactPuzzleDifficulty.schwer);
      expect(puzzle.hints, hasLength(2));
      expect(puzzle.hint, startsWith('Vergleiche die schlichte Fassade'));
    });

    test('ein unbrauchbarer Eintrag in choices fällt weg', () {
      final puzzle = onlyPuzzle(<String, dynamic>{
        'question': 'Welches Wappen ist nicht erzbischöflich?',
        'choices': <dynamic>['Doppeladler', 42, null, 'Löwenwappen'],
      });

      expect(
        puzzle.choices,
        orderedEquals(<String>['Doppeladler', 'Löwenwappen']),
      );
    });

    test('ohne choices ist hasChoices falsch, nicht null', () {
      final puzzle = onlyPuzzle(puzzleRow());

      expect(puzzle.choices, isEmpty);
      expect(puzzle.hasChoices, isFalse);
    });
  });

  group('Abzähl- und Zeitreise-Felder', () {
    test('expectedCount, tolerance und puzzle_photo kommen an', () {
      final puzzle = onlyPuzzle(<String, dynamic>{
        'type': 'tap-counter',
        'question': 'Zähle die Bögen auf dem Weg zum Tor.',
        'expectedCount': 24,
        'tolerance': 2,
        'puzzle_photo': 'https://beispiel.test/damals.jpg',
      });

      expect(puzzle.expectedCount, 24);
      expect(puzzle.countTolerance, 2);
      expect(puzzle.photoUrl, 'https://beispiel.test/damals.jpg');
    });

    test('findability und quality kommen an', () {
      final puzzle = onlyPuzzle(
        puzzleRow(
          overrides: <String, Object?>{
            'findability': 'mittel',
            'quality': 3,
            'why': 'Sockelinschrift gut belegt',
          },
        ),
      );

      expect(puzzle.findability, 'mittel');
      expect(puzzle.isFindable, isTrue);
      expect(puzzle.quality, 3);
      expect(puzzle.rationale, 'Sockelinschrift gut belegt');
    });

    test('nicht-findbar wird erkannt', () {
      final puzzle = onlyPuzzle(
        puzzleRow(
          overrides: <String, Object?>{'findability': FactPuzzle.notFindable},
        ),
      );

      expect(puzzle.isFindable, isFalse);
    });
  });

  group('Frage-Bereinigung', () {
    test('das ANTWORT_KURZ-Artefakt wird abgeschnitten', () {
      final puzzle = onlyPuzzle(puzzleRow());

      expect(puzzle.question, isNot(contains('ANTWORT_KURZ')));
      expect(puzzle.question, isNot(contains('→')));
      expect(puzzle.question, endsWith('hinauf zum Eingang?'));
      // Die Antwort bleibt erhalten, nur eben nicht in der Frage.
      expect(puzzle.expectedAnswer, '18');
    });

    test('ein echter Beobachtungshinweis nach dem Pfeil bleibt stehen', () {
      final puzzle = onlyPuzzle(
        puzzleRow(
          overrides: <String, Object?>{
            'question':
                'Was hält die Bronzefigur in der Hand?\n\n'
                '→ Schau nach oben zur rechten Hand der Statue.',
          },
        ),
      );

      expect(puzzle.question, contains('Schau nach oben'));
      expect(puzzle.question, contains('→'));
    });

    test('eine Frage, die nur aus dem Artefakt besteht, ist unbrauchbar', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            'puzzle_fit': <Object?>[
              puzzleRow(
                overrides: <String, Object?>{'question': 'ANTWORT_KURZ: 18'},
              ),
              puzzleRowKombi(),
            ],
          },
        ),
      ]);

      expect(result.facts.single.puzzles, hasLength(1));
      expect(
        result.defects.map((FactDefect d) => d.field),
        contains('puzzle_fit[0].question'),
      );
    });
  });

  group('Toleranzen', () {
    test('der Literaltext null in hint gilt als nicht gesetzt', () {
      final puzzle = onlyPuzzle(
        puzzleRow(overrides: <String, Object?>{'hint': 'null'}),
      );

      expect(puzzle.hint, isNull);
    });

    test('hints als null ergibt eine leere Liste, nicht null', () {
      final puzzle = onlyPuzzle(puzzleRow());

      expect(puzzle.hints, isEmpty);
    });

    test('gpsRadius als String wird gelesen', () {
      final puzzle = onlyPuzzle(
        puzzleRow(overrides: <String, Object?>{'gpsRadius': '150'}),
      );

      expect(puzzle.gpsRadiusMeters, 150);
    });

    test(
      'eine unbekannte Schwierigkeitsstufe wird gemeldet, nicht ersetzt',
      () {
        final result = mapper.mapRecords(<Object?>[
          factRow(
            overrides: <String, Object?>{
              'puzzle_fit': <Object?>[
                puzzleRow(overrides: <String, Object?>{'difficulty': 'brutal'}),
              ],
            },
          ),
        ]);

        expect(result.facts.single.puzzles.single.difficulty, isNull);
        expect(
          result.defects.map((FactDefect d) => d.field),
          contains('puzzle_fit[0].difficulty'),
        );
      },
    );

    test('Schwierigkeit wird unabhängig von Schreibweise erkannt', () {
      final puzzle = onlyPuzzle(
        puzzleRow(overrides: <String, Object?>{'difficulty': ' Leicht '}),
      );

      expect(puzzle.difficulty, FactPuzzleDifficulty.leicht);
    });

    test('ein Typ, den die PWA-Tabelle nicht kennt, bleibt erhalten', () {
      // Belegt aus dem Bestand: `vor-ort` kommt 761 mal vor und fehlt in
      // PSZ_TYPE_META (puzzle-sheet.jsx:36). Ein Enum würde den Wert verlieren.
      for (final type in <String>[
        'vor-ort',
        'inschrift',
        'mcq',
        'perspektive',
        'zaehlen',
        'sinne',
      ]) {
        final puzzle = onlyPuzzle(
          puzzleRow(overrides: <String, Object?>{'type': type}),
        );
        expect(
          puzzle.type,
          type,
          reason: 'Typ $type darf nicht verloren gehen',
        );
      }
    });

    test('ein Rätsel ohne expected bleibt spielbar', () {
      // Foto- und Perspektiven-Rätsel haben keine geschriebene Antwort.
      final puzzle = onlyPuzzle(<String, dynamic>{
        'type': 'foto-beweis',
        'question': 'Fotografiere die Treppenfassade frontal.',
        'gpsRadius': 150,
      });

      expect(puzzle.expectedAnswer, isNull);
      expect(puzzle.question, isNotEmpty);
    });
  });

  group('Gleichheit', () {
    test('zwei gleich abgebildete Rätsel sind gleich', () {
      expect(onlyPuzzle(puzzleRowKombi()), onlyPuzzle(puzzleRowKombi()));
      expect(
        onlyPuzzle(puzzleRowKombi()).hashCode,
        onlyPuzzle(puzzleRowKombi()).hashCode,
      );
    });

    test('ein abweichendes Spezialfeld macht sie ungleich', () {
      final a = onlyPuzzle(puzzleRowKombi());
      final b = onlyPuzzle(
        puzzleRowKombi(overrides: <String, Object?>{'formula': 'a + b'}),
      );

      expect(a, isNot(b));
    });

    test('ein abweichender Eintrag in choices macht sie ungleich', () {
      final a = onlyPuzzle(puzzleRowMcq());
      final b = a.copyWith(choices: <String>['nur eine Option']);

      expect(a, isNot(b));
      expect(b.choices, hasLength(1));
      // copyWith lässt alles andere unangetastet.
      expect(b.formula, a.formula);
      expect(b.question, a.question);
    });
  });

  group('Marker als Konstante', () {
    test('der Marker steht als Konstante bereit', () {
      expect(FactPuzzleMapper.answerLeakMarker, 'ANTWORT_KURZ');
    });
  });
}
