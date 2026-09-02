import 'package:fact_app/services/orientation/orientation_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der untätige Standard des Orientierungsdienstes.
void main() {
  group('Der untätige Standard', () {
    test('liefert nichts und endet', () async {
      // Nicht „liefert nichts und bleibt offen": ein offener Strom hielte in
      // jedem Test eine Zeitüberschreitung auf, die niemand sucht. Dieselbe
      // Zusicherung wie bei `unavailableLocationService`.
      final headings = await unavailableOrientationService
          .headingUpdates()
          .toList();

      expect(headings, isEmpty);
    });

    test('erfüllt den Vertrag und ist keine eigene Sorte', () {
      expect(unavailableOrientationService, isA<OrientationService>());
    });
  });
}
