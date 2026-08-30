import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Dauer der Schnitzeljagd.
void main() {
  test('die drei Dauern der Quelle, in ihrer Reihenfolge', () {
    // `screen-challenge.jsx:1899-1902`.
    expect(
      HuntDuration.values.map((HuntDuration value) => value.minutes),
      <int>[30, 60, 90],
    );
  });

  test('jede Dauer trägt die Stationszahl der Quelle', () {
    // `screen-challenge.jsx:4332`: `{ 30: 5, 60: 7, 90: 9 }`. Die Zahlen
    // stehen hier als Literale und nicht als Ausdruck über die Aufzählung:
    // eine Zusicherung gegen die Konstante, die sie festnageln soll, ist immer
    // wahr.
    expect(HuntDuration.thirty.stopCount, 5);
    expect(HuntDuration.sixty.stopCount, 7);
    expect(HuntDuration.ninety.stopCount, 9);
  });

  test('die Zuordnung ist eindeutig in beide Richtungen', () {
    expect(
      HuntDuration.values.map((HuntDuration value) => value.stopCount).toSet(),
      hasLength(HuntDuration.values.length),
    );
  });
}
