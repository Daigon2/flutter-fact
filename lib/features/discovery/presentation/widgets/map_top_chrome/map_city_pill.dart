part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Die Stadt-Pille links oben, `screen-map.jsx:3105-3116`.
@visibleForTesting
class MapCityPill extends StatelessWidget {
  /// Erzeugt die Stadt-Pille.
  const MapCityPill({
    required this.palette,
    required this.name,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Der angezeigte Stadtname.
  final String name;

  /// Beschriftung für die Sprachausgabe, `title` in der Quelle (`:3106`).
  final String tooltip;

  /// Tipp auf die Pille. `null` heißt: nicht antippbar.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = _Blurred(
      // `borderRadius: 12`, `:3109`.
      radius: 12,
      sigma: _blurStrong,
      background: palette.background,
      border: palette.border,
      shadow: _softShadow,
      // `padding: '8px 15px'`, `:3109`.
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Text(
        name,
        // `fontFamily: 'Nunito', fontWeight: 900, fontSize: 24`, `:3110`.
        style: FactTypography.emphasis.copyWith(
          fontSize: 24,
          color: palette.text,
        ),
        maxLines: 1,
        // Die Quelle kennt keinen Überlauf, weil ihre Schrift nicht mitwächst.
        // Hier schon: eine gekürzte Stadt ist besser als eine, die unter der
        // Coin-Pille verschwindet.
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );

    if (onTap == null) {
      return pill;
    }
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: pill,
      ),
    );
  }
}
