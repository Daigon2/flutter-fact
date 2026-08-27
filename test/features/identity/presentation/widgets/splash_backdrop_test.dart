import 'package:fact_app/features/identity/presentation/widgets/splash_backdrop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Maße der vier Hintergrundschichten.
///
/// Diese Zahlen sind vorher durch kein Gate gedeckt gewesen: `veilHeight` von
/// 520 auf 52 und `gridSpacing` von 40 auf 400 ließ die ganze Suite grün. Ein
/// Kommentar mit der Quellzeile hilft nur dem, der ihn liest.
void main() {
  group('Gitter', () {
    test('eine Linie bei jedem Vielfachen von 40, beginnend bei 0', () {
      expect(SplashBackdrop.gridSpacing, 40);
      expect(SplashBackdrop.gridLines(100), <double>[0, 40, 80]);
      expect(SplashBackdrop.gridLines(120), <double>[0, 40, 80]);
      expect(SplashBackdrop.gridLines(121), <double>[0, 40, 80, 120]);
    });

    test('eine Fläche ohne Ausdehnung bekommt keine Linie', () {
      // Die Randbedingung der Schleife: `< extent`, nicht `<=`. Sonst zeichnet
      // eine 40 Pixel hohe Fläche zwei Linien, eine davon außerhalb.
      expect(SplashBackdrop.gridLines(0), isEmpty);
      expect(SplashBackdrop.gridLines(40), <double>[0]);
    });
  });

  group('Unterer Schleier', () {
    testWidgets('ist 520 Pixel hoch und sitzt unten über die volle Breite', (
      tester,
    ) async {
      expect(SplashBackdrop.veilHeight, 520);

      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SplashBackdrop(),
        ),
      );

      final veil = tester.getRect(find.byType(SplashBottomVeil));
      expect(veil.height, SplashBackdrop.veilHeight);
      expect(veil.width, 390);
      expect(veil.bottom, 844);
    });
  });

  group('Lichtkegel', () {
    test('sitzt bei 50 Prozent Breite und 38 Prozent Höhe', () {
      // `radial-gradient(ellipse at 50% 38%, …)`. In Alignment-Einheiten ist
      // die Mitte 0 und 38 Prozent sind 2 * 0.38 - 1.
      expect(SplashBackdrop.glowCenter.x, 0);
      expect(SplashBackdrop.glowCenter.y, closeTo(-0.24, 1e-9));
    });
  });
}
