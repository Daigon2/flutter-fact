import 'dart:math' as math;

import 'package:fact_app/features/discovery/presentation/fact_collect_burst.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Münzflug beim Sammeln.
///
/// **Keine echte Zeit.** Gepumpt wird mit ausdrücklichen Dauern, wie
/// `.claude/rules/tests.md` es verlangt; der Zufall der Fluglängen kommt aus
/// einer eingespeisten Quelle, sonst wäre jede Zusicherung über die Strecke
/// entweder blind oder flatterhaft.
void main() {
  /// Eine Zufallsquelle, die vorhersagbar zählt.
  ///
  /// Zehn Werte in `[0, 1)`, gleichmäßig verteilt: 0,0 bis 0,9. Damit ist
  /// jede der zehn Fluglängen einzeln nachrechenbar.
  double Function() countingRandom() {
    int index = 0;
    return () => (index++ % 10) / 10;
  }

  Future<void> pumpBurst(
    WidgetTester tester, {
    Offset origin = const Offset(200, 400),
    int coinAmount = 10,
    double Function()? nextDouble,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          FactCollectBurst(
            origin: origin,
            coinAmount: coinAmount,
            nextDouble: nextDouble ?? countingRandom(),
          ),
        ],
      ),
    ),
  );

  List<FactCollectBurstCoin> coinsOf(WidgetTester tester) => tester
      .widgetList<FactCollectBurstCoin>(find.byType(FactCollectBurstCoin))
      .toList();

  group('Die Maße aus der Quelle', () {
    test('zehn Winkel, in der Reihenfolge der Quelle', () {
      // `screen-map.jsx:1161`. **Die Reihenfolge ist Teil der Aussage**: sie
      // entscheidet zusammen mit dem Versatz, welche Münze wann losfliegt.
      // Eine sortierte Liste wäre ein anderes Bild.
      expect(factCollectBurstAngles, <double>[
        200,
        225,
        250,
        270,
        290,
        310,
        330,
        170,
        190,
        155,
      ]);
    });

    test('Versatz, Dauer und Kurve', () {
      expect(factCollectBurstStagger, const Duration(milliseconds: 40));
      expect(factCollectBurstCoinDuration, const Duration(milliseconds: 700));
      expect(factCollectBurstCurve, const Cubic(0.25, 0.8, 0.25, 1));
    });

    test('die ganze Überlagerung läuft 1250 Millisekunden', () {
      // Das Maximum aus 150 + 1100 (die Zahl) und 9 × 40 + 700 (die letzte
      // Münze). **Nicht 1400**: das ist die Wartezeit des Ablaufs, nicht die
      // der Animation.
      expect(factCollectBurstDuration, const Duration(milliseconds: 1250));
    });
  });

  group('Die Fluglänge', () {
    test('liegt bei eingespeistem Zufall im Bereich [32, 54)', () {
      final List<double> distances = factCollectBurstDistances(
        countingRandom(),
      );

      expect(distances, hasLength(10));
      for (final double distance in distances) {
        expect(distance, greaterThanOrEqualTo(32));
        expect(distance, lessThan(54));
      }
    });

    test('die Ränder sind ausschließend nach oben und einschließend nach '
        'unten', () {
      // `32 + Math.random() * 22`, und `Math.random()` liefert `[0, 1)`. Die
      // 54 ist damit nie zu erreichen, die 32 immer.
      expect(factCollectBurstDistances(() => 0).first, 32);
      expect(factCollectBurstDistances(() => 0.9999999).first, lessThan(54));
    });

    test('jede Münze zieht genau einmal', () {
      // Zöge der Zeichner je Bild neu, zappelten die Münzen. Der Zähler unten
      // zeigt, wie oft die Quelle befragt wurde.
      int calls = 0;
      factCollectBurstDistances(() {
        calls++;
        return 0.5;
      });

      expect(calls, 10);
    });

    test('der Zielversatz rechnet cos, sin und die 20 Pixel nach unten', () {
      // `ex = cos(rad) * d`, `ey = sin(rad) * d + 20` (`:1177-1179`).
      final Offset target = factCollectBurstTarget(
        angleInDegrees: 270,
        distance: 40,
      );

      expect(target.dx, closeTo(0, 1e-9));
      // sin(270°) = -1, also 40 Pixel nach oben, plus die 20 zurück.
      expect(target.dy, closeTo(-20, 1e-9));
    });

    test('bei der kürzesten Strecke kippen fünf der zehn Münzen nach '
        'unten weg', () {
      // **Gemessen, und die naheliegende Annahme war falsch.** Ich hatte
      // erwartet, dass alle zehn nach oben fliegen, weil die Winkel zwischen
      // 155 und 330 Grad liegen. In CSS wächst y nach unten, und `sin` ist
      // erst ab 180 Grad negativ; dazu kommen die 20 Pixel. Bei 32 Pixeln
      // Flugstrecke landen 155, 170, 190, 200 und 330 Grad **unter** dem
      // Ballon.
      //
      // Dieser Test hält die Messung fest, damit die Zahl 20 nicht bei der
      // nächsten Durchsicht als Vorzeichenfehler gelesen wird.
      final List<double> downward = <double>[
        for (final double angle in factCollectBurstAngles)
          if (factCollectBurstTarget(angleInDegrees: angle, distance: 32).dy >
              0)
            angle,
      ];

      expect(downward, <double>[200, 330, 170, 190, 155]);
    });

    test('bei der längsten Strecke kippt nur eine der fünf zurück nach '
        'oben', () {
      // **Die Gegenprobe, und sie fiel anders aus als erwartet.** Ich hatte
      // angenommen, die 20 Pixel verlören mit wachsender Strecke an Gewicht
      // und am Ende gingen fast alle nach oben. Gemessen: von den fünf
      // bleiben vier auch bei 53,9 Pixeln unten, nur 330 Grad dreht. Bei 200
      // Grad ist `sin` nur -0,342, das reicht selbst über die volle Strecke
      // nicht gegen die 20.
      //
      // Vier von zehn Münzen fliegen also **immer** nach unten weg, in jeder
      // Ziehung. Das ist das Bild der PWA und keine Nebenwirkung des
      // Nachbaus.
      final List<double> downward = <double>[
        for (final double angle in factCollectBurstAngles)
          if (factCollectBurstTarget(angleInDegrees: angle, distance: 53.9).dy >
              0)
            angle,
      ];

      expect(downward, <double>[200, 170, 190, 155]);
    });
  });

  group('Der Stand einer Münze', () {
    test('vor ihrem Versatz ist sie unsichtbar', () {
      // Das steht nicht in den Keyframes, sondern im Inline-Stil
      // (`opacity:0`, `:1169`). Ohne diese Zeile blitzten alle zehn Münzen im
      // ersten Bild gemeinsam auf.
      final FactCollectCoinFrame frame = factCollectCoinFrameAt(
        index: 5,
        elapsed: const Duration(milliseconds: 100),
      );

      expect(frame.opacity, 0);
      expect(frame.progress, 0);
    });

    test('am Anfang ihres Fluges ist sie voll da und ungedreht', () {
      final FactCollectCoinFrame frame = factCollectCoinFrameAt(
        index: 5,
        elapsed: const Duration(milliseconds: 200),
      );

      expect(frame.opacity, 1);
      expect(frame.scale, 1);
      expect(frame.rotationInDegrees, 0);
    });

    test('am Ende ist sie weg, halb so groß und um 540 Grad gedreht', () {
      final FactCollectCoinFrame frame = factCollectCoinFrameAt(
        index: 0,
        elapsed: const Duration(milliseconds: 700),
      );

      expect(frame.progress, 1);
      expect(frame.opacity, 0);
      expect(frame.scale, 0.5);
      expect(frame.rotationInDegrees, 540);
    });

    test('die letzte Münze ist 360 Millisekunden nach der ersten dran', () {
      // 9 × 40. Zu diesem Zeitpunkt ist die erste längst unterwegs.
      expect(
        factCollectCoinFrameAt(
          index: 9,
          elapsed: const Duration(milliseconds: 359),
        ).opacity,
        0,
      );
      expect(
        factCollectCoinFrameAt(
          index: 9,
          elapsed: const Duration(milliseconds: 360),
        ).opacity,
        1,
      );
    });
  });

  group('Der Stand der Zahl', () {
    test('vor der Verzögerung ist sie unsichtbar', () {
      final FactCollectLabelFrame frame = factCollectLabelFrameAt(
        const Duration(milliseconds: 149),
      );

      expect(frame.opacity, 0);
      expect(frame.scale, 0.8);
    });

    test('bei 15 Prozent ist sie voll da, auf Maßstab 1 und um 70 Prozent '
        'nach oben', () {
      // 150 + 0,15 × 1100 = 315 Millisekunden.
      final FactCollectLabelFrame frame = factCollectLabelFrameAt(
        const Duration(milliseconds: 315),
      );

      expect(frame.opacity, closeTo(1, 1e-9));
      expect(frame.scale, closeTo(1, 1e-9));
      expect(frame.yFraction, closeTo(-0.7, 1e-9));
      expect(frame.xFraction, closeTo(-0.5, 1e-9));
      expect(frame.xInPixels, closeTo(0, 1e-9));
    });

    test('am Ende ist sie weg und um 210 Prozent nach oben', () {
      final FactCollectLabelFrame frame = factCollectLabelFrameAt(
        const Duration(milliseconds: 1250),
      );

      expect(frame.opacity, closeTo(0, 1e-9));
      expect(frame.yFraction, closeTo(-2.10, 1e-9));
      // Die 60 Pixel aus `var(--coin-float-x, 60px)`, siehe die Begründung
      // an `factCollectLabelFrameAt`: die Variable setzt niemand.
      expect(frame.xInPixels, closeTo(60, 1e-9));
    });

    test('sie bleibt zwischen 15 und 80 Prozent voll sichtbar', () {
      // Ohne diese Prüfung wäre eine einzelne Kurve über die ganzen 1,1
      // Sekunden nicht von der abschnittsweisen zu unterscheiden: die
      // Deckkraft liefe dann durchgehend hoch statt bei 15 Prozent
      // anzukommen und dort zu bleiben.
      for (final int ms in <int>[400, 600, 800, 1000]) {
        expect(
          factCollectLabelFrameAt(Duration(milliseconds: ms)).opacity,
          closeTo(1, 1e-9),
          reason: '$ms ms',
        );
      }
    });
  });

  group('Was auf dem Bildschirm steht', () {
    testWidgets('zehn Münzen mit den Winkeln und dem Versatz der Quelle', (
      tester,
    ) async {
      await pumpBurst(tester);

      final List<FactCollectBurstCoin> coins = coinsOf(tester);
      expect(coins, hasLength(10));
      expect(
        coins.map((FactCollectBurstCoin coin) => coin.angleInDegrees).toList(),
        factCollectBurstAngles,
      );
      expect(
        coins.map((FactCollectBurstCoin coin) => coin.delay).toList(),
        <Duration>[for (int i = 0; i < 10; i++) Duration(milliseconds: i * 40)],
      );
    });

    testWidgets('jede Münze trägt eine eigene Strecke aus dem Zufall', (
      tester,
    ) async {
      await pumpBurst(tester);

      expect(
        coinsOf(
          tester,
        ).map((FactCollectBurstCoin coin) => coin.distance).toList(),
        <double>[for (int i = 0; i < 10; i++) 32 + (i / 10) * 22],
      );
    });

    testWidgets('die Strecke bleibt über die Bilder dieselbe', (tester) async {
      await pumpBurst(tester);
      final List<double> first = coinsOf(
        tester,
      ).map((FactCollectBurstCoin coin) => coin.distance).toList();

      await tester.pump(const Duration(milliseconds: 300));

      expect(
        coinsOf(
          tester,
        ).map((FactCollectBurstCoin coin) => coin.distance).toList(),
        first,
      );
    });

    testWidgets('die Zahl ist die übergebene und keine hartcodierte', (
      tester,
    ) async {
      await pumpBurst(tester, coinAmount: 10);
      // Über die Verzögerung hinaus, damit die Zahl auch sichtbar ist.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('+10 🪙'), findsOneWidget);
      // **Die Gegenprobe gegen die 12 der Quelle.** Sie ist der Defekt, den
      // dieser Nachbau ausdrücklich nicht erbt (E-06, Anzeigehälfte).
      expect(find.text('+12 🪙'), findsNothing);
    });

    testWidgets('eine andere Zahl steht auch anders da', (tester) async {
      // Ohne diesen zweiten Fall wäre „die übergebene Zahl" auch dann grün,
      // wenn irgendwo eine 10 hartcodiert stünde.
      await pumpBurst(tester, coinAmount: 50);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('+50 🪙'), findsOneWidget);
      expect(find.text('+10 🪙'), findsNothing);
    });

    testWidgets('die Fläche verschluckt keine Geste', (tester) async {
      // `pointerEvents:'none'`, `:1183`. Ohne das gehörte die Karte für 1,25
      // Sekunden niemandem.
      await pumpBurst(tester);

      expect(
        tester.widget<IgnorePointer>(find.byType(IgnorePointer)).ignoring,
        isTrue,
      );
    });

    testWidgets('die Münzen sitzen zu Beginn auf der übergebenen Lage', (
      tester,
    ) async {
      await pumpBurst(tester, origin: const Offset(200, 400));

      // Erste Münze, noch bei Fortschritt 0: `left`/`top` sind die Lage
      // selbst, die halbe Eigengröße zieht die `FractionalTranslation` ab.
      final Positioned first = tester.widget<Positioned>(
        find
            .descendant(
              of: find.byType(FactCollectBurstCoin).first,
              matching: find.byType(Positioned),
            )
            .first,
      );
      expect(first.left, closeTo(200, 1e-9));
      expect(first.top, closeTo(400, 1e-9));
    });

    testWidgets('nach 300 Millisekunden ist die erste Münze unterwegs', (
      tester,
    ) async {
      await pumpBurst(tester, origin: const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 300));

      final Positioned first = tester.widget<Positioned>(
        find
            .descendant(
              of: find.byType(FactCollectBurstCoin).first,
              matching: find.byType(Positioned),
            )
            .first,
      );
      // Winkel 200 Grad: cos ist negativ, die Münze fliegt nach links. Nach
      // **unten** allerdings, denn `sin(200°) * 32 + 20` ist positiv, siehe
      // `factCollectBurstDownwardOffset`. Die erste Strecke ist bei
      // eingespeistem Zufall genau 32.
      expect(first.left, lessThan(200));
      expect(first.top, greaterThan(400));
    });

    testWidgets('ohne eingespeisten Zufall läuft es trotzdem', (tester) async {
      // Der echte Betriebsfall: `nextDouble` bleibt `null`, dann greift
      // `math.Random`. Geprüft wird nur, dass zehn Münzen entstehen und ihre
      // Strecken im Bereich liegen, nichts über die Werte selbst.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              FactCollectBurst(origin: Offset(10, 10), coinAmount: 10),
            ],
          ),
        ),
      );

      final List<FactCollectBurstCoin> coins = coinsOf(tester);
      expect(coins, hasLength(10));
      for (final FactCollectBurstCoin coin in coins) {
        expect(coin.distance, greaterThanOrEqualTo(32));
        expect(coin.distance, lessThan(54));
      }
    });
  });

  group('Randfälle', () {
    testWidgets('eine Lage von 0/0 zeichnet ganz normal', (tester) async {
      // Der Rückfall des Ablaufs, wenn die Projektion nichts liefert
      // (`screenX ?? 0`, `:3068`). Er ist ein Normalfall dieses Widgets und
      // kein Sonderweg.
      await pumpBurst(tester, origin: Offset.zero);

      expect(coinsOf(tester), hasLength(10));
    });

    test('die Kurve ist die der Quelle und nicht Curves.easeOut', () {
      // Zwei Kurven sehen im Standbild gleich aus. Der Wert bei der Hälfte
      // unterscheidet sie: `cubic-bezier(0.25,0.8,0.25,1)` ist dort deutlich
      // weiter als die Hälfte.
      expect(factCollectBurstCurve.transform(0.5), closeTo(0.9348, 0.001));
      expect(Curves.easeOut.transform(0.5), lessThan(0.9));
    });

    test('die Winkel decken keinen Kreis ab, sondern einen Ausschnitt', () {
      // Alle zehn liegen zwischen 155 und 330 Grad, also im Halbkreis nach
      // oben plus zwei Ausläufer. Wer einen Winkel zwischen 0 und 155
      // einfügt, schickt eine Münze nach unten weg, und der Schwarm sieht
      // aus wie ein Ausrutscher. **Ohne die Prüfung auf `sin`**, siehe die
      // Messung weiter oben: die ist bei 155 und 170 Grad positiv.
      for (final double angle in factCollectBurstAngles) {
        expect(angle, greaterThanOrEqualTo(155));
        expect(angle, lessThanOrEqualTo(330));
      }
      expect(math.sin(155 * math.pi / 180), greaterThan(0));
    });
  });
}
