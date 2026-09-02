import 'package:fact_app/kernel/puzzle_operand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ein Eingabewert eines Kombinations-Rätsels, geteilt zwischen `facts` und
/// `puzzles` (ADR-008).
void main() {
  test('beide Felder dürfen null sein', () {
    const PuzzleOperand operand = PuzzleOperand();

    expect(operand.label, isNull);
    expect(operand.description, isNull);
  });

  test('isEmpty ist wahr, wenn beide Felder null sind', () {
    const PuzzleOperand operand = PuzzleOperand();

    expect(operand.isEmpty, isTrue);
  });

  test('isEmpty ist falsch, sobald nur label gesetzt ist', () {
    const PuzzleOperand operand = PuzzleOperand(label: 'Geburtsjahr');

    expect(operand.isEmpty, isFalse);
  });

  test('isEmpty ist falsch, sobald nur description gesetzt ist', () {
    // Beide Richtungen einzeln geprüft: eine Implementierung, die nur eines
    // der beiden Felder abfragt, würde genau eine dieser Prüfungen
    // unbemerkt bestehen.
    const PuzzleOperand operand = PuzzleOperand(
      description: 'Geburtsjahr von der Sockelinschrift',
    );

    expect(operand.isEmpty, isFalse);
  });

  test('zwei gleich gefüllte Operanden sind gleich und teilen den Hash', () {
    const PuzzleOperand a = PuzzleOperand(
      label: 'Geburtsjahr',
      description: 'von der Sockelinschrift',
    );
    const PuzzleOperand b = PuzzleOperand(
      label: 'Geburtsjahr',
      description: 'von der Sockelinschrift',
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('ein Unterschied in label macht zwei Operanden ungleich', () {
    const PuzzleOperand a = PuzzleOperand(
      label: 'Geburtsjahr',
      description: 'von der Sockelinschrift',
    );
    const PuzzleOperand b = PuzzleOperand(
      label: 'Sterbejahr',
      description: 'von der Sockelinschrift',
    );

    expect(a == b, isFalse);
  });

  test('ein Unterschied in description macht zwei Operanden ungleich', () {
    const PuzzleOperand a = PuzzleOperand(
      label: 'Geburtsjahr',
      description: 'von der Sockelinschrift',
    );
    const PuzzleOperand b = PuzzleOperand(
      label: 'Geburtsjahr',
      description: 'aus dem Museumskatalog',
    );

    expect(a == b, isFalse);
  });
}
