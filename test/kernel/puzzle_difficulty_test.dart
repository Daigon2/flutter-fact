import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Schwierigkeitsstufe eines Rätsels, geteilt zwischen `facts`, `puzzles`
/// und `challenges` (ADR-008).
void main() {
  test('die drei Stufen tragen die Rohwerte aus den Daten', () {
    expect(PuzzleDifficulty.leicht.code, 'leicht');
    expect(PuzzleDifficulty.mittel.code, 'mittel');
    expect(PuzzleDifficulty.schwer.code, 'schwer');
  });

  test('fromCode findet jede der drei Stufen über ihren Rohwert', () {
    expect(PuzzleDifficulty.fromCode('leicht'), PuzzleDifficulty.leicht);
    expect(PuzzleDifficulty.fromCode('mittel'), PuzzleDifficulty.mittel);
    expect(PuzzleDifficulty.fromCode('schwer'), PuzzleDifficulty.schwer);
  });

  test('fromCode(null) ist null', () {
    // Fehlt die Stufe an einem Rätsel, bleibt sie null statt eines
    // erfundenen Standards. Würde fromCode(null) auf eine Stufe fallen,
    // trüge jedes Rätsel ohne Angabe unbemerkt eine falsche Schwierigkeit.
    expect(PuzzleDifficulty.fromCode(null), isNull);
  });

  test('ein unbekannter Wert ist null', () {
    expect(PuzzleDifficulty.fromCode('unmoeglich'), isNull);
  });

  test('Groß- und Kleinschreibung wird geglättet', () {
    expect(PuzzleDifficulty.fromCode('LEICHT'), PuzzleDifficulty.leicht);
    expect(PuzzleDifficulty.fromCode('Mittel'), PuzzleDifficulty.mittel);
  });

  test('Rand-Leerzeichen werden geglättet', () {
    // Die Daten stammen von einem Sprachmodell und aus mehreren
    // Pipeline-Generationen, deshalb muss ein umschließendes Leerzeichen
    // die Zuordnung nicht kippen.
    expect(PuzzleDifficulty.fromCode('  schwer  '), PuzzleDifficulty.schwer);
  });

  test('values hat genau drei Einträge', () {
    // Kommt eine vierte Stufe dazu, hängt daran der switch in der
    // Auswertung: eine ungeprüfte vierte Stufe würde dort unbemerkt in
    // einen Default- oder Fehlerpfad fallen, statt bewusst behandelt zu
    // werden.
    expect(PuzzleDifficulty.values.length, 3);
  });
}
