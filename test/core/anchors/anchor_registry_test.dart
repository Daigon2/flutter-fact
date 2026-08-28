import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Vertrag der Registry selbst, ohne `AnchorScope` und ohne
/// `AnchorTarget`.
///
/// Die Tests laufen als Widget-Tests, weil `register` einen echten
/// [BuildContext] braucht. Ein Attrappen-Kontext wäre hier mehr Aufwand als
/// zwei `Builder`.
void main() {
  const wallet = AnchorId('tab-wallet');
  const challenge = AnchorId('tab-challenge');

  /// Liefert zwei voneinander unabhängige, echte Kontexte.
  Future<(BuildContext, BuildContext)> pumpTwoContexts(
    WidgetTester tester,
  ) async {
    late BuildContext first;
    late BuildContext second;
    await tester.pumpWidget(
      Column(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          Builder(
            builder: (context) {
              first = context;
              return const SizedBox(width: 10, height: 10);
            },
          ),
          Builder(
            builder: (context) {
              second = context;
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ],
      ),
    );
    return (first, second);
  }

  AnchorRegistry registryWithoutFrame({
    Set<AnchorId> knownMissing = const <AnchorId>{},
  }) => AnchorRegistry(frameOf: () => null, knownMissingAnchors: knownMissing);

  group('Anmelden und Abmelden', () {
    testWidgets('kennt eine Kennung erst nach dem Anmelden', (tester) async {
      final (context, _) = await pumpTwoContexts(tester);
      final registry = registryWithoutFrame(knownMissing: <AnchorId>{wallet});

      expect(registry.debugRegisteredIds, isEmpty);
      expect(registry.rectOf(wallet), isNull);

      registry.register(wallet, context);

      expect(registry.debugRegisteredIds, <AnchorId>{wallet});
    });

    testWidgets('abmelden entfernt den Eintrag vollständig', (tester) async {
      final (context, _) = await pumpTwoContexts(tester);
      final registry = registryWithoutFrame(knownMissing: <AnchorId>{wallet});
      registry.register(wallet, context);

      expect(registry.unregister(wallet, context), isTrue);
      // `rectOf` allein würde auch bei einer toten Anmeldung `null` liefern.
      // Erst diese Zusicherung schließt aus, dass die Registry den Kontext
      // eines abgebauten Elements weiter festhält.
      expect(registry.debugRegisteredIds, isEmpty);
    });

    testWidgets('abmelden mit fremdem Pfand tut nichts', (tester) async {
      // Der Fall, um den es geht: A und B tragen dieselbe Kennung und hängen
      // während eines Bildschirmwechsels kurz beide im Baum. Im Verzeichnis
      // steht dann B, und das spätere `dispose` von A meldet mit dem Kontext
      // von A ab. Ohne die Pfandprüfung verschwände dabei ein Anker, der
      // sichtbar auf dem Schirm steht.
      final (alt, neu) = await pumpTwoContexts(tester);
      final registry = registryWithoutFrame();
      registry.register(wallet, neu);

      expect(registry.unregister(wallet, alt), isFalse);
      expect(registry.debugRegisteredIds, <AnchorId>{wallet});
    });

    testWidgets('abmelden einer unbekannten Kennung meldet false', (
      tester,
    ) async {
      final (context, _) = await pumpTwoContexts(tester);
      final registry = registryWithoutFrame();

      expect(registry.unregister(challenge, context), isFalse);
    });
  });

  group('Doppelte Anmeldung', () {
    testWidgets('schlägt in Debug per assert an', (tester) async {
      final (erst, zweit) = await pumpTwoContexts(tester);
      final registry = registryWithoutFrame();
      registry.register(wallet, erst);

      expect(
        () => registry.register(wallet, zweit),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message.toString(),
            'Meldung',
            contains('tab-wallet'),
          ),
        ),
      );
    });

    testWidgets('der letzte gewinnt, auch in Debug', (tester) async {
      // Festgenagelt, damit die Entscheidung nicht dem Zufall überlassen
      // bleibt: im Release gibt es den `assert` nicht, und dann muss klar sein,
      // wessen Anmeldung gilt. Weil die Zuweisung in `register` vor dem
      // `assert` steht, gilt in Debug dasselbe, und dieser Test misst genau
      // das. Stünde der `assert` zuerst, wären Debug und Release zwei
      // verschiedene Programme und dieser Test unmöglich.
      final (erst, zweit) = await pumpTwoContexts(tester);
      final registry = registryWithoutFrame();
      registry.register(wallet, erst);
      try {
        registry.register(wallet, zweit);
      } on AssertionError {
        // In Debug erwartet, siehe der Test darüber.
      }

      expect(registry.unregister(wallet, erst), isFalse);
      expect(registry.unregister(wallet, zweit), isTrue);
    });

    testWidgets('dieselbe Anmeldung zweimal ist kein Verstoß', (tester) async {
      // `didChangeDependencies` kann mehrfach laufen. Ein `assert` darauf wäre
      // ein Fehlalarm.
      final (context, _) = await pumpTwoContexts(tester);
      final registry = registryWithoutFrame();
      registry.register(wallet, context);

      expect(() => registry.register(wallet, context), returnsNormally);
    });
  });

  group('Degradationsvertrag', () {
    testWidgets('ein bekannt fehlender Anker liefert still null', (
      tester,
    ) async {
      await pumpTwoContexts(tester);
      final registry = registryWithoutFrame(knownMissing: <AnchorId>{wallet});

      expect(registry.rectOf(wallet), isNull);
    });

    testWidgets('ein unbekannter Anker schlägt in Debug per assert an', (
      tester,
    ) async {
      // Das ist der Tippfehler-Fall. Ohne diesen `assert` sieht er genauso aus
      // wie ein noch nicht gebauter Anker, nämlich als `null`.
      await pumpTwoContexts(tester);
      final registry = registryWithoutFrame(knownMissing: <AnchorId>{wallet});

      expect(
        () => registry.rectOf(challenge),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message.toString(),
            'Meldung',
            contains('tab-challenge'),
          ),
        ),
      );
    });

    testWidgets('ohne Bezugsfläche gibt es kein Rechteck', (tester) async {
      final (context, _) = await pumpTwoContexts(tester);
      final registry = registryWithoutFrame();
      registry.register(wallet, context);

      expect(registry.rectOf(wallet), isNull);
      expect(registry.frameSize, isNull);
    });

    testWidgets('ein Anker außerhalb der Bezugsfläche liefert null', (
      tester,
    ) async {
      // Beide sind ausgelegt, aber der eine liegt nicht unter dem anderen.
      // `getTransformTo` ist in dieser Lage laut eigener Dokumentation
      // undefiniert, deshalb der Lauf nach oben statt eines blinden Aufrufs.
      final (erst, zweit) = await pumpTwoContexts(tester);
      final registry = AnchorRegistry(
        frameOf: () => zweit.findRenderObject()! as RenderBox,
      );
      registry.register(wallet, erst);

      expect(registry.rectOf(wallet), isNull);
    });
  });
}
