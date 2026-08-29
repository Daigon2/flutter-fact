part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Der Level-Ring, `screen-map.jsx:730-742`.
@visibleForTesting
class MapLevelBadge extends StatelessWidget {
  /// Erzeugt den Level-Ring.
  const MapLevelBadge({
    required this.palette,
    required this.level,
    required this.percent,
    super.key,
  });

  /// Außenmaß, `screen-map.jsx:731`. Die Quelle setzt dort ausdrücklich
  /// `boxSizing: 'border-box'`, der Innenabstand liegt also innerhalb der 42.
  static const double size = 42;

  /// `padding: 3`, `screen-map.jsx:733`.
  static const double ringWidth = 3;

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Die angezeigte Levelnummer.
  final int level;

  /// Fortschritt im Level in Prozent, 0 bis 100.
  final double percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // `conic-gradient(#F5C518 ${levelPct * 3.6}deg, <track> 0deg)`,
          // `:732`. Zwei harte Stopps an derselben Stelle ergeben die Kante.
          // CSS beginnt oben und dreht im Uhrzeigersinn, `SweepGradient`
          // beginnt rechts, daher die Vierteldrehung zurück.
          gradient: SweepGradient(
            colors: <Color>[const Color(0xFFF5C518), palette.levelTrack],
            stops: <double>[percent / 100, percent / 100],
            transform: const GradientRotation(-math.pi / 2),
          ),
          // `boxShadow: '0 2px 8px rgba(0,0,0,0.18)'`, `:734`.
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x2E000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(ringWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.levelInnerBackground,
            ),
            child: Center(
              child: Text(
                '$level',
                // `fontWeight: 900, fontSize: 15`, `:740`.
                style: FactTypography.emphasis.copyWith(
                  fontSize: 15,
                  color: palette.levelText,
                ),
                // Wie die Münzprägung: feste Scheibe, feste Ziffer.
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
