import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nagelt die Kartenanker fest.
///
/// Zwei Dinge stehen hier auf dem Spiel. Erstens die **Namen**: sie müssen
/// Zeichen für Zeichen den `data-tour-anchor`-Werten der PWA entsprechen, sonst
/// löst das Tutorial später nichts auf und degradiert lautlos zu einem Schritt
/// ohne Pfeil. Zweitens die **Liste der bekannt fehlenden Anker**: sie ist die
/// einzige Stelle, an der ein Tippfehler von einem noch nicht gebauten Widget
/// unterschieden wird. Wächst sie unbemerkt, verliert der `assert` in
/// `AnchorRegistry.rectOf` seine Wirkung.
void main() {
  group('Namen der Kartenanker', () {
    test('entsprechen den data-tour-anchor-Werten der PWA', () {
      // Belegt an `screen-tour.jsx:140-169` (`balloon`, `user-marker`,
      // `coins`, `mode-tour`, `compass`), `screen-map.jsx:708` (`coins`),
      // `:3154` (`compass`) und `:3217` (`'mode-' + modeBtn.id`).
      expect(
        DiscoveryAnchors.values.map((anchor) => anchor.value).toList(),
        <String>['balloon', 'user-marker', 'coins', 'mode-tour', 'compass'],
      );
    });

    test('coins gehört der Karte, obwohl Coins fachlich zu progression '
        'gehören', () {
      // Die Regel, die hier festgehalten wird: eine Ankerkennung gehört der
      // Oberfläche, die das Widget zeichnet, nicht der Domäne der Daten darin.
      // `screen-map.jsx:708` setzt das Attribut auf dem Kartenbildschirm.
      // Anders herum bräuchte ein Leuchtring einen feature-übergreifenden
      // Vertrag.
      expect(DiscoveryAnchors.coins, const AnchorId('coins'));
      expect(DiscoveryAnchors.values, contains(DiscoveryAnchors.coins));
    });
  });

  group('Bekannt fehlende Anker', () {
    test('sind heute genau die fünf Kartenanker', () {
      // Wer in Phase 2 einen dieser Anker baut, streicht ihn hier **und** in
      // `DiscoveryAnchors.knownMissing`. Schlägt dieser Test an, ohne dass
      // jemand einen Anker gebaut hat, ist die Liste gewachsen und der `assert`
      // in `AnchorRegistry.rectOf` deckt mehr zu als er soll.
      expect(DiscoveryAnchors.knownMissing, <AnchorId>{
        const AnchorId('balloon'),
        const AnchorId('user-marker'),
        const AnchorId('coins'),
        const AnchorId('mode-tour'),
        const AnchorId('compass'),
      });
    });

    test('enthalten keinen Tab-Anker', () {
      // Die vier Tab-Anker sind gebaut. Stünden sie in der Liste, würde ein
      // vertippter Tab-Anker still durchgehen.
      for (final name in <String>[
        'tab-modus',
        'tab-wallet',
        'tab-challenge',
        'tab-profil',
      ]) {
        expect(
          DiscoveryAnchors.knownMissing,
          isNot(contains(AnchorId(name))),
          reason: name,
        );
      }
    });

    test('sind unveränderlich', () {
      // `Set.unmodifiable` ersetzt das `const`, das an dieser Stelle nicht
      // möglich ist: eine konstante Menge darf keine Elemente enthalten, die
      // `==` überschreiben.
      expect(
        () => DiscoveryAnchors.knownMissing.add(const AnchorId('x')),
        throwsUnsupportedError,
      );
    });
  });
}
