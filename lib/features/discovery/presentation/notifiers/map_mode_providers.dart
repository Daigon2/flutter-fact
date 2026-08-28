import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der gewählte Modus des Kartenbildschirms, `screen-map.jsx:1354`.
///
/// ## Warum ein Provider und nicht der Zustand eines `StatefulWidget`
///
/// In der Quelle ist `mode` lokaler Zustand von `MapScreen`, und dort ist das
/// dieselbe Sache: die Komponente umfasst den ganzen Bildschirm. Im Neubau ist
/// das Top-Chrome nur eines von mehreren Bauteilen über derselben Karte, und
/// den Modus lesen später auch das Tour-Blatt (`:3243`), das Ballon-Filter und
/// die Beschriftung der Fakt-Karte (`:3024`). Ein Zustand im Umschalter-Widget
/// wäre spätestens dann in der falschen Ebene.
///
/// Er bleibt trotzdem **Oberflächenzustand** und wird nicht gespeichert: die
/// Quelle legt ihn nicht in `localStorage` ab, ein Neustart beginnt wieder bei
/// [MapMode.factFinder].
final mapModeProvider = NotifierProvider<MapModeNotifier, MapMode>(
  MapModeNotifier.new,
);

/// Besitzer des Kartenmodus.
class MapModeNotifier extends Notifier<MapMode> {
  @override
  MapMode build() => MapMode.initial;

  /// Wechselt den Modus.
  ///
  /// Ein erneuter Tipp auf den aktiven Modus ist erlaubt und ändert nichts.
  /// Die Quelle ruft `handleModeChange` ebenfalls ohne Gleichheitsprüfung
  /// (`screen-map.jsx:3218`); dort räumt sie dabei zusätzlich zwei Vorschauen
  /// weg (`:3048-3055`), die es hier noch nicht gibt.
  void select(MapMode mode) {
    state = mode;
  }
}
