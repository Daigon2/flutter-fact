import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die zwei Modi des Kartenbildschirms.
///
/// Der teuerste Fehler an dieser Stelle wäre lautlos: benennt jemand einen
/// Modus um und lässt die Ankerkennung stehen, zeigt das Tutorial danach auf
/// nichts, und kein Test der Oberfläche würde es merken.
void main() {
  group('Kennungen', () {
    test('sind die der PWA', () {
      // `screen-map.jsx:3216`, die beiden Einträge des `map`-Aufrufs.
      expect(MapMode.values.map((mode) => mode.id).toList(), <String>[
        'fact-finder',
        'tour',
      ]);
    });

    test('tragen den Anker "mode-" plus Kennung', () {
      // `data-tour-anchor={'mode-' + modeBtn.id}`, `screen-map.jsx:3217`.
      for (final mode in MapMode.values) {
        expect(mode.anchorId.value, 'mode-${mode.id}', reason: mode.name);
      }
    });

    test('nehmen die Konstanten aus DiscoveryAnchors und keine eigenen', () {
      // Ein hier neu getipptes 'mode-tour' wäre genau der Fehler, gegen den es
      // sonst keine Absicherung gibt: er sähe aus wie ein noch nicht gebauter
      // Anker.
      expect(MapMode.factFinder.anchorId, DiscoveryAnchors.modeFactFinder);
      expect(MapMode.tour.anchorId, DiscoveryAnchors.modeTour);
      expect(DiscoveryAnchors.values, contains(MapMode.tour.anchorId));
      expect(DiscoveryAnchors.values, contains(MapMode.factFinder.anchorId));
    });

    test('zeigen auf die Schlüssel der PWA', () {
      expect(MapMode.factFinder.labelKey, 'map.factFinder');
      expect(MapMode.tour.labelKey, 'map.tour');
    });
  });

  group('Der gewählte Modus', () {
    test('beginnt beim Fact Finder', () {
      // `React.useState('fact-finder')`, `screen-map.jsx:1354`.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(MapMode.initial, MapMode.factFinder);
      expect(container.read(mapModeProvider), MapMode.factFinder);
    });

    test('folgt der Auswahl und wieder zurück', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapModeProvider.notifier).select(MapMode.tour);
      expect(container.read(mapModeProvider), MapMode.tour);

      container.read(mapModeProvider.notifier).select(MapMode.factFinder);
      expect(container.read(mapModeProvider), MapMode.factFinder);
    });

    test('überlebt einen neuen Container nicht', () {
      // Nicht gespeichert, und das ist Absicht: die Quelle legt den Modus
      // nicht in `localStorage` ab.
      final first = ProviderContainer();
      addTearDown(first.dispose);
      first.read(mapModeProvider.notifier).select(MapMode.tour);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(second.read(mapModeProvider), MapMode.factFinder);
    });
  });
}
