part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Die Coin-Pille, `screen-map.jsx:707-728`. Trägt den Anker `coins`.
@visibleForTesting
class MapCoinPill extends StatelessWidget {
  /// Erzeugt die Coin-Pille.
  const MapCoinPill({required this.palette, required this.coins, super.key});

  /// Durchmesser der Münze, `screen-map.jsx:720`.
  static const double discSize = 22;

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Der angezeigte Münzstand.
  final int coins;

  @override
  Widget build(BuildContext context) {
    // Der Anker sitzt außen an der Pille, wie `data-tour-anchor` in der Quelle
    // (`:708`). Weiter innen gesetzt, umschlösse der Leuchtring nur die Zahl.
    return AnchorTarget(
      anchorId: DiscoveryAnchors.coins,
      child: _Blurred(
        // `borderRadius: 999`, `:714`.
        radius: _fullRadius,
        sigma: _blurLight,
        background: palette.coinPillBackground,
        border: palette.coinPillBorder,
        shadow: _softShadow,
        // `padding: '4px 10px 4px 4px'`, `:714`.
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: discSize,
              height: discSize,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                // `linear-gradient(145deg,#FFE066,#F5C518)`, `:721`. CSS misst
                // 0 Grad nach oben und dreht im Uhrzeigersinn; die beiden
                // Ausrichtungen unten sind derselbe Vektor. Die
                // Gradientenlänge weicht bei CSS geringfügig ab, auf 22 Pixeln
                // ist das nicht sichtbar.
                gradient: LinearGradient(
                  begin: Alignment(-0.574, -0.819),
                  end: Alignment(0.574, 0.819),
                  colors: <Color>[Color(0xFFFFE066), Color(0xFFF5C518)],
                ),
                // `boxShadow: '0 2px 0 #C49A0A'`, `:722`.
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0xFFC49A0A), offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                // Kein Fall für `AppStrings`: das "F" ist die Prägung der
                // Münze, kein Text. Die Quelle schreibt es in beiden Sprachen
                // hart (`:726`).
                'F',
                style: FactTypography.emphasis.copyWith(
                  // `fontWeight: 900, fontSize: 11, color: '#7A5C00'`, `:724`.
                  fontSize: 11,
                  color: const Color(0xFF7A5C00),
                ),
                // Die Prägung wächst nicht mit der Systemschrift: sie sitzt in
                // einer 22 Pixel großen Scheibe mit fester Größe, und eine
                // mitwachsende Glyphe darin wäre abgeschnitten statt größer.
                textScaler: TextScaler.noScaling,
              ),
            ),
            // `gap: 5`, `:712`.
            const SizedBox(width: 5),
            Text(
              '$coins',
              // `fontWeight: 900, fontSize: 13, color: '#F5C518'`, `:727`.
              style: FactTypography.emphasis.copyWith(
                fontSize: 13,
                color: const Color(0xFFF5C518),
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
