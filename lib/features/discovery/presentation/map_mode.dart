/// Die zwei Modi des Kartenbildschirms, `02_Frontend/app/screen-map.jsx:3216`.
///
/// ## Das ist **nicht** `ModeBar` aus `chrome.jsx:150-207`
///
/// Die Verwechslung liegt nahe und ist teuer, deshalb steht sie hier fest:
///
/// | | `ModeBar` (`chrome.jsx:150`) | dieser Umschalter (`screen-map.jsx:3205`) |
/// |---|---|---|
/// | Ort | unten, `bottom: 0` | oben, `top: 136` |
/// | Einträge | `entdecken`, `challenge` | `fact-finder`, `tour` |
/// | Anker | keiner | `data-tour-anchor={'mode-' + id}` |
/// | Benutzt von | `screen-entdecken.jsx:399` | dem Kartenbildschirm |
///
/// `mode-tour`, das Ziel von Tutorial-Schritt 6, gehört zum **oberen**
/// Umschalter. `ModeBar` trägt überhaupt keinen Anker und kommt auf dem
/// Kartenbildschirm nicht vor. Der Kopfkommentar von `app/shell/shell_tab.dart`
/// warnt bereits davor, `ModeBar` für eine fünfte Tab-Leiste zu halten; hier
/// steht die zweite Hälfte derselben Falle.
library;

import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';

/// Ein Eintrag des Modus-Umschalters über der Karte.
enum MapMode {
  /// `fact-finder`, der Startwert (`screen-map.jsx:1354`).
  factFinder('fact-finder', 'map.factFinder', DiscoveryAnchors.modeFactFinder),

  /// `tour`, Ziel von Tutorial-Schritt 6.
  tour('tour', 'map.tour', DiscoveryAnchors.modeTour);

  const MapMode(this.id, this.labelKey, this.anchorId);

  /// Die Kennung aus der PWA, `screen-map.jsx:3216`.
  ///
  /// Sie steht hier, weil [anchorId] aus ihr entsteht: die Quelle setzt
  /// `data-tour-anchor={'mode-' + modeBtn.id}` (`:3217`). Ein Test hält
  /// beides zusammen, damit ein umbenannter Modus nicht still einen anderen
  /// Anker bekommt.
  final String id;

  /// Schlüssel der Beschriftung in `AppStrings`, `screen-map.jsx:3216`.
  ///
  /// Der Schlüssel und nicht der fertige Text, aus demselben Grund wie bei
  /// `ShellTab.labelKey`: der Umschalter muss einem Sprachwechsel folgen.
  final String labelKey;

  /// Kennung dieses Knopfes als Anker.
  final AnchorId anchorId;

  /// Der Startmodus, `screen-map.jsx:1354`: `useState('fact-finder')`.
  static const MapMode initial = factFinder;
}
