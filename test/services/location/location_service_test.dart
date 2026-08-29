import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Genauigkeitsfilter und der untätige Standard.
///
/// Der Filter ist die eine Entscheidung, die der Ortungsdienst überhaupt
/// trifft, und er ist Parität: `02_Frontend/app/screen-map.jsx:2744` verwirft
/// jede Ortung mit `accuracy > 35`.
void main() {
  DevicePosition withAccuracy(double accuracy) => DevicePosition(
    latitude: 48.1351,
    longitude: 11.582,
    accuracyInMeters: accuracy,
  );

  group('Der 35-Meter-Filter', () {
    test('die Schwelle steht auf 35 und nicht auf einer anderen Zahl', () {
      expect(locationAccuracyLimitInMeters, 35);
    });

    test('genau 35 Meter werden durchgelassen', () {
      // **Die Grenze selbst, und sie liegt auf dieser Seite.** Die Quelle
      // schreibt `> 35`, also ist 35 noch gut. Ein `>=` im Nachbau wäre die
      // naheliegende Verwechslung und hier die einzige Stelle, die sie fängt.
      expect(isAccurateEnough(withAccuracy(35)), isTrue);
    });

    test('alles darüber wird verworfen', () {
      expect(isAccurateEnough(withAccuracy(35.000001)), isFalse);
      expect(isAccurateEnough(withAccuracy(36)), isFalse);
      expect(
        isAccurateEnough(withAccuracy(2000)),
        isFalse,
        reason: 'die grobe Funkzellen-Ortung des Kaltstarts',
      );
    });

    test('bessere Ortungen sind gut', () {
      expect(isAccurateEnough(withAccuracy(0)), isTrue);
      expect(isAccurateEnough(withAccuracy(4.5)), isTrue);
      expect(isAccurateEnough(withAccuracy(34.999999)), isTrue);
    });
  });

  group('Der untätige Standard', () {
    test('liefert nichts und endet', () async {
      // Nicht „liefert nichts und bleibt offen": ein offener Strom hielte in
      // jedem Test eine Zeitüberschreitung auf, die niemand sucht.
      final positions = await unavailableLocationService
          .positionUpdates()
          .toList();

      expect(positions, isEmpty);
    });

    test('erfüllt den Vertrag und ist keine eigene Sorte', () {
      expect(unavailableLocationService, isA<LocationService>());
    });
  });
}
