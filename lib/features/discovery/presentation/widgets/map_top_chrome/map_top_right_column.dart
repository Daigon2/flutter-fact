part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Coin-Pille, Level-Ring und Kompass in einer Spalte.
///
/// ## Warum eine Spalte und nicht drei absolute Kästen
///
/// Die Quelle setzt `top: 60` für den XP-Streifen (`:705`) und `top: 148` für
/// den Kompass (`:3152`). Beide Zahlen passen nur zueinander, solange die
/// Schrift nicht mitwächst: bei Systemschrift 2.0 ist der Streifen hoch genug,
/// um unter dem Kompass zu liegen, und ein `Stack` meldet das nicht, er
/// zeichnet einfach übereinander.
///
/// In einer Spalte **ergibt** sich die Kompassposition. Bei Skalierung 1.0
/// kommt exakt die 148 der Quelle heraus, nachgerechnet und per Test
/// zugesichert: 60 + 32 (Coin-Pille) + 6 (`gap`, `:705`) + 42 (Level-Ring,
/// `:731`) + 8. Die Höhe 32 der Coin-Pille ist 4 + 22 + 4 plus zwei mal ein
/// Pixel Rahmen; `box-sizing: border-box` aus `styles.css:109` ändert daran
/// nichts, weil die Pille keine gesetzte Höhe hat. Die letzten 8 sind der
/// Rest, und sie sind zugleich der `gap: 8`, den die Quelle der
/// Kompass-Spalte selbst gibt (`:3152`).
@visibleForTesting
class MapTopRightColumn extends StatelessWidget {
  /// Erzeugt die rechte Spalte.
  const MapTopRightColumn({
    required this.palette,
    required this.coins,
    required this.level,
    required this.levelPercent,
    required this.bearingDegrees,
    required this.isCompassDead,
    required this.compassTooltip,
    required this.onCompassTap,
    required this.onCompassLongPress,
    super.key,
  });

  /// `gap: 6` zwischen Coin-Pille und Level-Ring, `screen-map.jsx:705`.
  static const double coinToLevelGap = 6;

  /// Abstand zwischen Level-Ring und Kompass, siehe Klassenkommentar.
  static const double levelToCompassGap = 8;

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Der Münzstand.
  final int coins;

  /// Die Levelnummer.
  final int level;

  /// Fortschritt im Level in Prozent.
  final double levelPercent;

  /// Blickrichtung der Karte in Grad.
  final double bearingDegrees;

  /// Ob der Gerätekompass stumm ist.
  final bool isCompassDead;

  /// Beschriftung des Kompass-Knopfes für die Sprachausgabe.
  final String compassTooltip;

  /// Kurzer Tipp auf den Kompass.
  final VoidCallback? onCompassTap;

  /// Langer Druck auf den Kompass.
  final VoidCallback? onCompassLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      // `alignItems: 'flex-end'`, `screen-map.jsx:705`.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        MapCoinPill(palette: palette, coins: coins),
        const SizedBox(height: coinToLevelGap),
        MapLevelBadge(palette: palette, level: level, percent: levelPercent),
        const SizedBox(height: levelToCompassGap),
        MapCompassButton(
          palette: palette,
          bearingDegrees: bearingDegrees,
          isDead: isCompassDead,
          tooltip: compassTooltip,
          onTap: onCompassTap,
          onLongPress: onCompassLongPress,
        ),
      ],
    );
  }
}
