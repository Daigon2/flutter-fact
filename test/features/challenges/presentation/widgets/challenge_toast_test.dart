import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/features/challenges/presentation/widgets/challenge_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Die kurze Meldung über dem Challenge-Reiter, `chalToast` in
/// `02_Frontend/app/screen-challenge.jsx:4408-4421`.
///
/// ## Was diese Datei prüft und was nicht
///
/// Bis Schritt 35 gab es für dieses Widget **keine eigene Testdatei**;
/// `challenges_page_test.dart` prüfte nur, dass die Meldung erscheint und
/// nach 2800 Millisekunden wieder verschwindet (`ChallengeToast.visibleFor`).
/// Frei änderbar blieben Hintergrundfarbe, Textfarbe und die Dauer der
/// Einblendung (`ChallengeToast.fadeIn`); keine dieser drei Zahlen hatte
/// einen Test, der rot wird. Wo genau die Meldung auf dem Bildschirm sitzt
/// (`ChallengeToast.topOffset`), ist Sache von `ChallengesPage`, das sie dort
/// platziert, und steht deshalb in dessen eigener Testdatei.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpToast(WidgetTester tester, {String message = 'Fehler'}) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            // Ein heller Rand um die Meldung, damit ihr dunkler Hintergrund
            // im Bild einen klaren Kontrast hat.
            color: const Color(0xFFFFFFFF),
            child: Center(child: ChallengeToast(message: message)),
          ),
        ),
      );

  group('Die Einblendung', () {
    testWidgets('startet unsichtbar', (WidgetTester tester) async {
      await pumpToast(tester);

      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byType(ChallengeToast),
                matching: find.byType(Opacity),
              ),
            )
            .first
            .opacity,
        0,
      );
    });

    testWidgets(
      'ist nach 250 Millisekunden voll da, wie `fadeIn` es festlegt',
      (WidgetTester tester) async {
        // `animation: 'factToastIn 0.25s ease-out'`, `:4417`. Stünde hier
        // `1500` statt `250`, wäre die Einblendung nach dieser Wartezeit erst
        // zu einem Bruchteil fertig, siehe unten.
        await pumpToast(tester);

        await tester.pump(const Duration(milliseconds: 250));

        expect(
          tester
              .widgetList<Opacity>(
                find.descendant(
                  of: find.byType(ChallengeToast),
                  matching: find.byType(Opacity),
                ),
              )
              .first
              .opacity,
          1,
        );
      },
    );
  });

  group('Was nur das Bild zeigt', () {
    // Dieselbe Bauform wie in `challenges_page_test.dart`: einzelne
    // Bildpunkte, `toImage()` in `tester.runAsync` (Muster 19).
    Future<(ByteData pixels, int width)> paintToast(
      WidgetTester tester,
      String message,
    ) async {
      const Key boundaryKey = Key('toast-paint-boundary');
      tester.view
        ..physicalSize = const Size(390 * 3, 200 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ChallengeToast(message: message),
              ),
            ),
          ),
        ),
      );
      // Voll eingeblendet, siehe oben.
      await tester.pump(const Duration(milliseconds: 250));

      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      expect(boundary.localToGlobal(Offset.zero), Offset.zero);

      late ByteData pixels;
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage();
        pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();
      });
      return (pixels, boundary.size.width.round());
    }

    ({int r, int g, int b}) pixelAt(
      ByteData pixels,
      int width,
      double x,
      double y,
    ) {
      final int index = ((y.round() * width) + x.round()) * 4;
      return (
        r: pixels.getUint8(index),
        g: pixels.getUint8(index + 1),
        b: pixels.getUint8(index + 2),
      );
    }

    testWidgets('der Hintergrund ist dunkel und der Text hell darüber', (
      WidgetTester tester,
    ) async {
      // `background: 'rgba(20,8,6,0.92)'` gegen `color: '#FDF5E8'`, `:4411`.
      // Ohne diesen Test lässt sich beides frei ändern, und keine Zusicherung
      // fällt.
      const String message = 'Für diese Stadt reicht es noch nicht.';
      final (ByteData pixels, int width) = await paintToast(tester, message);
      final Rect toast = tester.getRect(find.byType(ChallengeToast));
      final Rect text = tester.getRect(find.text(message));

      // Randnaher Innenpunkt: klar innerhalb des Rahmens, weit vom Text.
      final ({int r, int g, int b}) background = pixelAt(
        pixels,
        width,
        toast.left + 5,
        toast.center.dy,
      );
      final ({int r, int g, int b}) textPixel = pixelAt(
        pixels,
        width,
        text.center.dx,
        text.center.dy,
      );

      expect(
        background.r + background.g + background.b,
        lessThan(150),
        reason: 'kein dunkler Hintergrund',
      );
      expect(
        textPixel.r + textPixel.g + textPixel.b,
        greaterThan(background.r + background.g + background.b + 200),
        reason: 'kein heller Text über dem dunklen Hintergrund',
      );
    });
  });
}
