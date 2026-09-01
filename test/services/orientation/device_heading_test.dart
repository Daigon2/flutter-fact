import 'package:fact_app/services/orientation/device_heading.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die geprüfte, normalisierte Blickrichtung: was verworfen wird, was
/// unverändert bleibt, und was auf sein kanonisches Element in `[0, 360)`
/// abgebildet wird.
void main() {
  group('nicht-endliche Werte werden verworfen', () {
    test('NaN ist keine Richtung', () {
      // `NaN` ist die Abwesenheit einer Antwort, und keine Normalisierung
      // macht daraus eine, siehe den Kopfkommentar von `device_heading.dart`.
      expect(DeviceHeading.tryFrom(double.nan), isNull);
    });

    test('+Infinity ist keine Richtung', () {
      expect(DeviceHeading.tryFrom(double.infinity), isNull);
    });

    test('-Infinity ist keine Richtung', () {
      expect(DeviceHeading.tryFrom(double.negativeInfinity), isNull);
    });
  });

  group('Werte innerhalb von [0, 360) bleiben unverändert', () {
    test('0 bleibt 0', () {
      expect(DeviceHeading.tryFrom(0)!.degrees, 0);
    });

    test('359.9 bleibt 359.9', () {
      expect(DeviceHeading.tryFrom(359.9)!.degrees, 359.9);
    });
  });

  group(
    'Werte außerhalb von [0, 360) werden normalisiert, nicht abgelehnt',
    () {
      // Ein Winkel ist eine Restklasse modulo 360: `-90` und `270` bezeichnen
      // dieselbe Richtung. Normalisieren ist deshalb keine Reparatur einer
      // falschen Eingabe, siehe den Kopfkommentar von `device_heading.dart`.
      test('360 wird 0', () {
        expect(DeviceHeading.tryFrom(360)!.degrees, 0);
      });

      test('-90 wird 270', () {
        expect(DeviceHeading.tryFrom(-90)!.degrees, 270);
      });

      test('450 wird 90', () {
        expect(DeviceHeading.tryFrom(450)!.degrees, 90);
      });

      test('-450 wird 270', () {
        expect(DeviceHeading.tryFrom(-450)!.degrees, 270);
      });
    },
  );

  group('Wertgleichheit', () {
    test('zwei gleiche Richtungen sind gleich, mit gleichem hashCode', () {
      final DeviceHeading a = DeviceHeading.tryFrom(90)!;
      final DeviceHeading b = DeviceHeading.tryFrom(90)!;

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('zwei verschiedene Richtungen sind nicht gleich', () {
      final DeviceHeading a = DeviceHeading.tryFrom(90)!;
      final DeviceHeading b = DeviceHeading.tryFrom(91)!;

      expect(a, isNot(b));
    });

    test('eine normalisierte und ihre kanonische Form sind gleich', () {
      // `-90` und `270` sind dieselbe Richtung, und das muss sich auch in der
      // Wertgleichheit zeigen, nicht nur im gespeicherten Feld.
      final DeviceHeading a = DeviceHeading.tryFrom(-90)!;
      final DeviceHeading b = DeviceHeading.tryFrom(270)!;

      expect(a, b);
    });
  });
}
