part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Der Modus-Umschalter, `screen-map.jsx:3203-3240`.
///
/// **Keine fünfte Tab-Leiste und auch nicht `ModeBar`**, siehe `map_mode.dart`.
@visibleForTesting
class MapModeToggle extends StatelessWidget {
  /// Erzeugt den Umschalter.
  const MapModeToggle({
    required this.palette,
    required this.mode,
    required this.tourReady,
    required this.onSelected,
    required this.labelFor,
    super.key,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Der gerade aktive Modus.
  final MapMode mode;

  /// Ob eine Tour vorbereitet ist.
  final bool tourReady;

  /// Wird beim Antippen eines Modus gerufen.
  final ValueChanged<MapMode> onSelected;

  /// Liefert die Beschriftung eines Modus.
  ///
  /// Eine Funktion und nicht zwei fertige Texte: der Umschalter kennt beide
  /// Modi selbst, und zwei Parameter für zwei Beschriftungen wären eine
  /// Aufzählung von Hand.
  final String Function(MapMode) labelFor;

  @override
  Widget build(BuildContext context) {
    return _Blurred(
      radius: _fullRadius,
      sigma: _blurStrong,
      background: palette.background,
      border: palette.border,
      // `padding: 4`, `screen-map.jsx:3208`.
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final entry in MapMode.values) ...<Widget>[
            // `gap: 3`, `:3206`. Vor jedem Eintrag außer dem ersten.
            if (entry != MapMode.values.first) const SizedBox(width: 3),
            // Ausdrücklich **kein** `Flexible`: zwei `Flexible` mit gleichem
            // `flex` deckeln beide Knöpfe auf die halbe Breite, und die
            // längere Beschriftung wird gekürzt, obwohl daneben Platz frei
            // ist. Gemessen, nicht vermutet: bei 360 Pixeln und Skalierung 1.0
            // bekam "🔍 Fact Finder" so 107,5 statt der benötigten 142.
            _MapModeButton(
              palette: palette,
              mapMode: entry,
              label: labelFor(entry),
              isActive: entry == mode,
              showDot: tourReady && entry == MapMode.tour && entry != mode,
              onTap: () => onSelected(entry),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ein Knopf des Umschalters, `screen-map.jsx:3216-3236`.
class _MapModeButton extends StatelessWidget {
  /// Erzeugt einen Knopf des Umschalters.
  const _MapModeButton({
    required this.palette,
    required this.mapMode,
    required this.label,
    required this.isActive,
    required this.showDot,
    required this.onTap,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Welchen Modus dieser Knopf wählt.
  final MapMode mapMode;

  /// Die sichtbare Beschriftung.
  final String label;

  /// Ob dieser Modus gerade aktiv ist.
  final bool isActive;

  /// Ob der rote Punkt sichtbar ist.
  final bool showDot;

  /// Tipp auf den Knopf.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnchorTarget(
      anchorId: mapMode.anchorId,
      child: Semantics(
        button: true,
        selected: isActive,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                // `padding: '7px 16px'`, `borderRadius: 999`, `:3219`.
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_fullRadius),
                  ),
                  color: isActive
                      ? palette.modeActiveBackground
                      : const Color(0x00000000),
                ),
                child: Text(
                  label,
                  // `fontWeight: 900, fontSize: 13`, `:3222`.
                  style: FactTypography.emphasis.copyWith(
                    fontSize: 13,
                    color: isActive ? palette.modeActiveText : palette.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              if (showDot)
                Positioned(
                  // `top: 3, right: 3`, 7x7, `:3229-3233`.
                  top: 3,
                  right: 3,
                  child: MapNotificationDot(
                    size: 7,
                    // `border: 1.5px solid pill.bg`, `:3232`. Ein CSS-Rahmen
                    // liegt innerhalb der 7 Pixel, weil `styles.css:109`
                    // global `box-sizing: border-box` setzt.
                    ringWidth: 1.5,
                    ringColor: palette.background,
                    ringInside: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
