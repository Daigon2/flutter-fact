import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/core/anchors/anchor_registry.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometrie: der Scope ist die Bezugsfläche, nicht der Bildschirm.
void main() {
  const wallet = AnchorId('tab-wallet');

  AnchorRegistry registryOf(WidgetTester tester, {int index = 0}) {
    final scope = tester.element(find.byType(AnchorScope).at(index));
    late AnchorRegistry found;
    scope.visitChildElements((element) {
      found = AnchorScope.maybeOf(element)!;
    });
    return found;
  }

  /// Ein 200x100 großer Scope mit einem 42x30 großen Anker in seiner linken
  /// oberen Ecke, den ganzen Aufbau um [offset] auf dem Bildschirm verschoben.
  Widget shiftedFrame(Offset offset) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: offset.dx,
            top: offset.dy,
            child: const SizedBox(
              width: 200,
              height: 100,
              child: AnchorScope(
                child: Padding(
                  padding: EdgeInsets.only(left: 15, top: 25),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: AnchorTarget(
                      anchorId: wallet,
                      child: SizedBox(width: 42, height: 30),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  testWidgets('das Rechteck ist relativ zum Scope, nicht zum Bildschirm', (
    tester,
  ) async {
    // Prüfpunkt "frame-relativ". Die PWA zieht `frect.left` und `frect.top` der
    // `.app-frame` von jeder Messung ab (`screen-tour.jsx:247-252`). Wer statt
    // dessen `localToGlobal` nimmt, bekommt dasselbe Ergebnis, solange der
    // Rahmen in der Ecke sitzt, und ein um den Versatz falsches, sobald er das
    // nicht tut. Genau das misst dieser Test.
    await tester.pumpWidget(shiftedFrame(Offset.zero));
    final inDerEcke = registryOf(tester).rectOf(wallet);

    await tester.pumpWidget(shiftedFrame(const Offset(90, 130)));
    final verschoben = registryOf(tester).rectOf(wallet);

    expect(inDerEcke, const Rect.fromLTWH(15, 25, 42, 30));
    expect(verschoben, inDerEcke);
  });

  testWidgets('frameSize ist die Größe des Scopes', (tester) async {
    // Pendant zu `frameSize` in `screen-tour.jsx:185-186`. Ein Overlay legt
    // seine Blase relativ dazu ab, nicht relativ zum Bildschirm.
    await tester.pumpWidget(shiftedFrame(const Offset(90, 130)));

    expect(registryOf(tester).frameSize, const Size(200, 100));
  });

  testWidgets('ein innerer Scope fängt die Anmeldung ab', (tester) async {
    // Die Registry gehört dem nächstgelegenen Scope. Das ist die Eigenschaft,
    // die einen Dialog mit eigenen Ankern später möglich macht, ohne dass er
    // die Anker der App überschreibt.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AnchorScope(
          knownMissingAnchors: <AnchorId>{},
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              height: 100,
              child: AnchorScope(
                child: AnchorTarget(
                  anchorId: wallet,
                  child: SizedBox(width: 42, height: 30),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final aussen = registryOf(tester);
    final innen = registryOf(tester, index: 1);

    expect(innen.debugRegisteredIds, <AnchorId>{wallet});
    expect(aussen.debugRegisteredIds, isEmpty);
  });
}
