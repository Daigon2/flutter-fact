import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/features/identity/presentation/widgets/bubble_pin.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pin_field.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die abgetippten Zahlen des Pin-Feldes, festgenagelt gegen
/// `02_Frontend/app/screen-auth.jsx:285-291`.
///
/// Warum gerade diese Werte einen Test bekommen: fünf Zeilen mal sechs Werte
/// sind der größte Block reiner Zahlen auf diesem Bildschirm, und keiner davon
/// fällt beim Ansehen auf. Ein vertauschtes `top` von 90 und 110 oder eine
/// Dauer von 1,65 statt 1,85 Sekunden sieht auf dem Gerät genauso richtig aus
/// wie der korrekte Wert. Alle anderen Zahlen des Bildschirms stehen zumindest
/// in Sichtweite eines Kommentars mit der Quellzeile.
void main() {
  test('die fünf Pins stehen wie in der Quelle', () {
    expect(splashPins, hasLength(5));

    expect(
      splashPins
          .map(
            (pin) => <Object>[
              pin.left,
              pin.top,
              pin.category,
              pin.size,
              pin.duration.inMilliseconds,
              pin.delay.inMilliseconds,
            ],
          )
          .toList(),
      <List<Object>>[
        <Object>[0.12, 110.0, BubblePinCategory.hist, 36.0, 1600, 0],
        <Object>[0.74, 90.0, BubblePinCategory.myth, 32.0, 1850, 300],
        <Object>[0.40, 70.0, BubblePinCategory.fun, 28.0, 2100, 600],
        <Object>[0.82, 170.0, BubblePinCategory.geo, 26.0, 1950, 900],
        <Object>[0.20, 185.0, BubblePinCategory.arch, 24.0, 2200, 1200],
      ],
    );
  });

  test('die Amplitude ist die aus authFloat', () {
    // `@keyframes authFloat { 50% { transform: translateY(-10px) } }`,
    // index.html:35.
    expect(SplashPinField.floatAmplitude, -10);
  });

  test('die Kategorie-Farben sind dieselben wie in FactColors', () {
    // Die Farben stehen in `BubblePinCategory` als Literale, weil die Quelle sie
    // auf diesem Bildschirm als Literale schreibt. Dieser Test macht aus der
    // Dopplung eine geprüfte Dopplung: liefe eine der beiden Seiten weg, wäre
    // es hier rot.
    //
    // Nebenbefund, deshalb doppelt geprüft: die fünf Kategorie-Farben sind in
    // beiden Themes identisch. Ein Theme-Zugriff wäre hier also ohnehin
    // wirkungslos.
    for (final colors in <FactColors>[FactColors.light, FactColors.dark]) {
      expect(BubblePinCategory.hist.color, colors.catHist);
      expect(BubblePinCategory.myth.color, colors.catMyth);
      expect(BubblePinCategory.fun.color, colors.catFun);
      expect(BubblePinCategory.geo.color, colors.catGeo);
      expect(BubblePinCategory.arch.color, colors.catArch);
    }
  });

  testWidgets('die Verzögerungen setzen die fünf Pins außer Gleichtakt', (
    tester,
  ) async {
    // Die Verzögerungen stehen in der Tabelle oben, aber eine Tabelle sagt
    // nichts über Wirkung. Ohne diesen Test durfte der Phasenversatz
    // ersatzlos wegfallen: fünf Pins im Gleichtakt, alle Gates grün.
    //
    // Gemessen wird im **ersten** Frame. Später ist die Aussage wertlos, weil
    // die fünf Controller unterschiedlich lange Perioden haben und sich damit
    // ohnehin auseinanderlaufen.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SplashPinField(),
      ),
    );

    final displacements = <double>[
      for (var i = 0; i < splashPins.length; i++)
        tester.getTopLeft(find.byType(BubblePin).at(i)).dy - splashPins[i].top,
    ];

    // Der erste Pin hat keine Verzögerung und steht deshalb im Ausgangspunkt.
    expect(displacements.first, closeTo(0, 0.5));
    // Alle anderen sind ausgelenkt, und zwar unterschiedlich weit.
    expect(displacements.toSet(), hasLength(splashPins.length));
    expect(
      (displacements[3] - displacements[0]).abs(),
      greaterThan(5),
      reason: 'Pin 4 steht bei Phase 0,92 nahe der Vollauslenkung von 10',
    );
    for (final displacement in displacements) {
      // Ausgelenkt wird nach oben, niemals nach unten.
      expect(displacement, lessThanOrEqualTo(0.5));
      expect(displacement, greaterThanOrEqualTo(SplashPinField.floatAmplitude));
    }
  });

  testWidgets('bei reduzierter Bewegung stehen alle fünf im Ausgangspunkt', (
    tester,
  ) async {
    // Über den `PlatformDispatcher` und nicht über eine eigene `MediaQuery`:
    // eine `MediaQuery` unterhalb des `View` verdeckt die aus
    // `MediaQuery.fromView` samt `size` und `padding`. Für dieses Widget wäre
    // das harmlos, aber zwei Wege für dieselbe Einstellung sind einer zu viel.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SplashPinField(),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < splashPins.length; i++) {
      expect(
        tester.getTopLeft(find.byType(BubblePin).at(i)).dy,
        splashPins[i].top,
        reason: 'Pin ${i + 1}',
      );
    }
  });

  test('die Blasenhöhe zählt Stiel und Bodenschatten mit', () {
    // `size` in der Tabelle ist der Durchmesser der Blase, nicht die Höhe des
    // ganzen Pins. Wer das verwechselt, verschiebt alle fünf um elf Pixel.
    const pin = BubblePin(category: BubblePinCategory.hist, size: 36);

    expect(pin.totalHeight, 36 + BubblePin.stemHeight + 4);
    expect(BubblePin.stemHeight, 7);
    expect(BubblePin.groundShadowHeight, 4);
  });
}
