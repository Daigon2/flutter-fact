part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Der Kompass-Knopf, `screen-map.jsx:3152-3199`. Trägt den Anker `compass`.
@visibleForTesting
class MapCompassButton extends StatelessWidget {
  /// Erzeugt den Kompass-Knopf.
  const MapCompassButton({
    required this.palette,
    required this.bearingDegrees,
    required this.isDead,
    required this.tooltip,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Blickrichtung der Karte in Grad; die Nadel dreht dagegen.
  final double bearingDegrees;

  /// Ob der Gerätekompass stumm ist.
  final bool isDead;

  /// Beschriftung für die Sprachausgabe, `title` in der Quelle (`:3189`).
  final String tooltip;

  /// Kurzer Tipp.
  final VoidCallback? onTap;

  /// Langer Druck.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    Widget needle = Transform.rotate(
      // `rotate(${-map.getBearing()}deg)`, `:1792`.
      angle: -bearingDegrees * math.pi / 180,
      child: Text(
        // Ein Piktogramm, kein Text: die Quelle schreibt es hart (`:3192`) und
        // führt dafür keinen Schlüssel.
        '🧭',
        // `fontSize: 20` aus `btnStyle` (`:3031`), `lineHeight: 1` (`:3192`).
        style: const TextStyle(fontSize: 20, height: 1),
        // Feste 44er Kachel: eine mitwachsende Nadel würde beschnitten.
        textScaler: TextScaler.noScaling,
      ),
    );
    if (isDead) {
      // `filter: grayscale(1)`, `:3192`. Die Koeffizienten sind die der
      // CSS-Filter-Spezifikation (Rec. 709).
      needle = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
        child: needle,
      );
    }

    return AnchorTarget(
      anchorId: DiscoveryAnchors.compass,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Opacity(
          // `opacity: compassDead ? 0.55 : 1`, `:3190`.
          opacity: isDead ? 0.55 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPress: onLongPress,
            child: _Blurred(
              // 44x44, `borderRadius: 14`, `btnStyle` in `:3027`.
              radius: 14,
              sigma: _blurStrong,
              background: palette.background,
              border: palette.border,
              size: const Size.square(MapTopChrome.compassSize),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  needle,
                  if (isDead)
                    Positioned(
                      // `top: 3, right: 5`, 8x8, `:3195`.
                      top: 3,
                      right: 5,
                      child: MapNotificationDot(
                        size: 8,
                        // `boxShadow: '0 0 0 2px ' + pill.bg`, `:3197`.
                        ringWidth: 2,
                        ringColor: palette.background,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
