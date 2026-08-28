import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lebenszyklus der Anmeldung: `AnchorTarget` im Zusammenspiel mit
/// `AnchorScope`.
void main() {
  const wallet = AnchorId('tab-wallet');
  const challenge = AnchorId('tab-challenge');

  /// Greift die Registry des Scopes ab, um sie direkt befragen zu können.
  AnchorRegistry registryOf(WidgetTester tester) {
    final scope = tester.element(find.byType(AnchorScope));
    late AnchorRegistry found;
    scope.visitChildElements((element) {
      found = AnchorScope.maybeOf(element)!;
    });
    return found;
  }

  Widget frame({required Widget child, Set<AnchorId>? knownMissing}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnchorScope(
        knownMissingAnchors: knownMissing ?? const <AnchorId>{},
        child: child,
      ),
    );
  }

  testWidgets('meldet sein Kind beim Einbau an', (tester) async {
    await tester.pumpWidget(
      frame(
        child: const AnchorTarget(
          anchorId: wallet,
          child: SizedBox(width: 42, height: 30),
        ),
      ),
    );

    expect(registryOf(tester).debugRegisteredIds, <AnchorId>{wallet});
    expect(registryOf(tester).rectOf(wallet), isNotNull);
  });

  testWidgets('ohne Scope darüber passiert nichts, statt zu werfen', (
    tester,
  ) async {
    // Ein Widget mit Anker muss nicht wissen, ob gerade jemand Anker abfragt.
    // Sonst bräuchte jeder Widget-Test der Tab-Leiste einen Scope.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AnchorTarget(
          anchorId: wallet,
          child: SizedBox(width: 42, height: 30),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('nach dem Ausbau kennt die Registry die Kennung nicht mehr', (
    tester,
  ) async {
    // Prüfpunkt "Abmelden ohne Leck". `rectOf` allein wäre kein Nachweis: es
    // liefert auch dann `null`, wenn der Kontext eines toten Elements im
    // Verzeichnis stehen bliebe. Erst `debugRegisteredIds` schließt das aus.
    // `knownMissing` ist in beiden Durchgängen gleich. Der Scope lässt eine
    // Änderung zur Laufzeit nicht zu, weil die Registry die Menge einmal beim
    // Erzeugen übernimmt.
    await tester.pumpWidget(
      frame(
        knownMissing: <AnchorId>{wallet},
        child: const AnchorTarget(
          anchorId: wallet,
          child: SizedBox(width: 42, height: 30),
        ),
      ),
    );
    final registry = registryOf(tester);
    expect(registry.debugRegisteredIds, <AnchorId>{wallet});

    await tester.pumpWidget(
      frame(
        knownMissing: <AnchorId>{wallet},
        child: const SizedBox(width: 42, height: 30),
      ),
    );

    expect(registry.debugRegisteredIds, isEmpty);
    expect(registry.rectOf(wallet), isNull);
    // Ein `AnchorScope.maybeOf(context)` in `dispose` würde hier werfen. Dass
    // nichts geworfen wurde, ist der Nachweis, dass die Registry gemerkt und
    // nicht nachgeschlagen wird.
    expect(tester.takeException(), isNull);
  });

  testWidgets('ein Rebuild des Elternwidgets verliert die Anmeldung nicht', (
    tester,
  ) async {
    // Prüfpunkt "Der Anker überlebt einen Rebuild": nicht abgemeldet und auch
    // nicht doppelt angemeldet. Der zweite Teil ist der interessantere, weil
    // eine zweite Anmeldung den `assert` in `register` auslösen würde.
    Widget build(Color color) {
      return frame(
        child: ColoredBox(
          color: color,
          child: const AnchorTarget(
            anchorId: wallet,
            child: SizedBox(width: 42, height: 30),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(const Color(0xFF000000)));
    final registry = registryOf(tester);
    final before = registry.rectOf(wallet);

    await tester.pumpWidget(build(const Color(0xFFFFFFFF)));

    expect(tester.takeException(), isNull);
    expect(registry.debugRegisteredIds, <AnchorId>{wallet});
    expect(registry.rectOf(wallet), before);
  });

  testWidgets('eine geänderte Kennung meldet die alte ab', (tester) async {
    Widget build(AnchorId id) {
      return frame(
        knownMissing: <AnchorId>{wallet, challenge},
        child: AnchorTarget(
          anchorId: id,
          child: const SizedBox(width: 42, height: 30),
        ),
      );
    }

    await tester.pumpWidget(build(wallet));
    final registry = registryOf(tester);

    await tester.pumpWidget(build(challenge));

    expect(registry.debugRegisteredIds, <AnchorId>{challenge});
    expect(registry.rectOf(wallet), isNull);
  });

  testWidgets('zwei Anker im selben Scope stören einander nicht', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        child: Column(
          children: const <Widget>[
            AnchorTarget(
              anchorId: wallet,
              child: SizedBox(width: 42, height: 30),
            ),
            AnchorTarget(
              anchorId: challenge,
              child: SizedBox(width: 60, height: 20),
            ),
          ],
        ),
      ),
    );

    final registry = registryOf(tester);

    expect(registry.debugRegisteredIds, <AnchorId>{wallet, challenge});
    expect(registry.rectOf(wallet)!.size, const Size(42, 30));
    expect(registry.rectOf(challenge)!.size, const Size(60, 20));
  });
}
