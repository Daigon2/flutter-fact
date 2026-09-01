import 'package:fact_app/features/challenges/domain/hunt_hints.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die gestuften Hinweise einer Jagd-Station: Kosten und Gratis-Regel.
void main() {
  test('die drei Kosten der Quelle, in ihrer Reihenfolge', () {
    // `screen-map.jsx:1031`: `HINT_COSTS = [0, 20, 30]`.
    expect(huntHintCosts, <int>[0, 20, 30]);
  });

  test('huntHintCount passt zur Länge der Kostenliste', () {
    // Diese Zusicherung schlägt an, wenn jemand eine vierte Stufe in
    // [huntHintCosts] einträgt und [huntHintCount] dabei vergisst, oder
    // umgekehrt. Absichtlich gegen `huntHintCosts.length` und nicht gegen
    // die Zahl 3, sonst prüfte der Test nur sich selbst gegen ein zweites
    // Literal.
    expect(huntHintCount, huntHintCosts.length);
  });

  group('isHuntHintFree', () {
    test('Index 0 ist gratis', () {
      // „H1 is always free" (`screen-map.jsx:1013-1014`).
      expect(isHuntHintFree(0), isTrue);
    });

    test('Index 1 und 2 sind nicht gratis', () {
      expect(isHuntHintFree(1), isFalse);
      expect(isHuntHintFree(2), isFalse);
    });

    test('ein Index außerhalb des gültigen Bereichs wirft', () {
      // Ein Fehler des Aufrufers, keine ungeprüfte Eingabe von außen, siehe
      // die Begründung am Bibliothekskopf. `false` wäre hier gefährlicher als
      // eine Ausnahme: es sähe wie ein gültiger, aber teurer Hinweis aus.
      expect(() => isHuntHintFree(-1), throwsRangeError);
      expect(() => isHuntHintFree(3), throwsRangeError);
      expect(() => isHuntHintFree(99), throwsRangeError);
    });
  });
}
