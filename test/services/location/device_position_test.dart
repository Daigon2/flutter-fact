import 'package:fact_app/services/location/device_position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Wertobjekt des Ortungsdienstes.
///
/// Klein, und trotzdem geprüft: `MapCameraChange` durfte am 28.08.2026 zwei
/// seiner vier Felder aus der Gleichheit fallen lassen, ohne dass ein Test
/// anschlug. Zwei Typen, gleiches Muster, nur einer geprüft, ist in diesem
/// Repository die Stelle, an der man suchen muss.
void main() {
  /// **Zur Laufzeit erzeugt und nicht `const`.** Dart kanonisiert konstante
  /// Ausdrücke: zwei gleich geschriebene `const DevicePosition(...)` sind
  /// dasselbe Objekt, und ein Gleichheitstest darauf prüft nichts. Genau diese
  /// Falle hat in Schritt 9 einen echten Fehler durchgelassen.
  DevicePosition position({
    double latitude = 48.1351,
    double longitude = 11.582,
    double accuracy = 8,
  }) => DevicePosition(
    latitude: latitude,
    longitude: longitude,
    accuracyInMeters: accuracy,
  );

  test('gleiche Werte sind gleich, ohne dasselbe Objekt zu sein', () {
    final a = position();
    final b = position();

    expect(
      identical(a, b),
      isFalse,
      reason: 'sonst prüft der Vergleich nichts',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('jedes der drei Felder trägt zur Gleichheit bei', () {
    final reference = position();

    expect(reference, isNot(position(latitude: 48.1352)));
    expect(reference, isNot(position(longitude: 11.5821)));
    expect(
      reference,
      isNot(position(accuracy: 9)),
      reason:
          'die Genauigkeit ist der einzige Grund, eine Ortung zu verwerfen; '
          'fiele sie aus der Gleichheit, wäre eine gute Ortung von einer '
          'schlechten an derselben Stelle nicht zu unterscheiden',
    );
  });

  test('ungleiche Ortungen streuen ungleich', () {
    // **Der Vertrag „gleich streut gleich" allein lässt einen konstanten
    // `hashCode` durch**, und der ist formal richtig und praktisch wertlos:
    // jede `Map` und jedes `Set` mit Ortungen darin würde zur linearen Liste.
    // Nachgemessen am 29.08.2026: `Object.hash` durch eine feste Zahl zu
    // ersetzen, überlebte alle 1177 Tests, weil nur der gleiche Fall geprüft
    // war. Drei Felder, drei Vergleiche, wie oben bei der Gleichheit.
    final reference = position();

    expect(reference.hashCode, isNot(position(latitude: 48.1352).hashCode));
    expect(reference.hashCode, isNot(position(longitude: 11.5821).hashCode));
    expect(reference.hashCode, isNot(position(accuracy: 9).hashCode));
  });

  test('toString nennt keine Koordinaten', () {
    // `docs/engineering/security.md` §6 verbietet genaue Standortangaben im
    // Log, und dieser Typ ist immer der Aufenthaltsort des Nutzers.
    final text = position(latitude: 48.1351, longitude: 11.582).toString();

    expect(text, isNot(contains('48.1351')));
    expect(text, isNot(contains('11.582')));
    expect(
      text,
      contains('8'),
      reason: 'ohne die Genauigkeit wäre eine Diagnose des Filters wertlos',
    );
  });
}
