part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Ein roter Meldepunkt mit Ring, in zwei Ausprägungen.
@visibleForTesting
class MapNotificationDot extends StatelessWidget {
  /// Erzeugt einen Meldepunkt.
  const MapNotificationDot({
    required this.size,
    required this.ringWidth,
    required this.ringColor,
    this.ringInside = false,
    super.key,
  });

  /// Durchmesser des Punktes.
  final double size;

  /// Stärke des Rings um den Punkt.
  final double ringWidth;

  /// Farbe des Rings, in der Quelle jeweils die Hintergrundfarbe der Pille.
  final Color ringColor;

  /// `true` für einen CSS-`border` (liegt innerhalb der Größe), `false` für
  /// einen `box-shadow`-Ring (liegt außerhalb).
  final bool ringInside;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _accentRed,
        border: ringInside
            ? Border.all(color: ringColor, width: ringWidth)
            : null,
        boxShadow: ringInside
            ? null
            : <BoxShadow>[BoxShadow(color: ringColor, spreadRadius: ringWidth)],
      ),
    );
  }
}

/// `#E8380D`, `screen-map.jsx:3196` und `:3231`.
///
/// Wertgleich mit `--red` aus `styles.css`, aber **nicht** von dort geholt: die
/// Quelle schreibt an diesen beiden Stellen die Zahl hin und nicht
/// `var(--stamp)`. Ein stadtabhängiges Theme dürfte diesen Punkt also nicht
/// mitfärben.
const Color _accentRed = Color(0xFFE8380D);
