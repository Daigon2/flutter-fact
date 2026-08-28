part of 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';

/// Die beiden Farbfassungen des Top-Chrome.
///
/// Die Quelle führt **zwei** Paletten, die nicht dieselben sind: `pill` in
/// `screen-map.jsx:3019-3021` für Stadt, Kompass und Umschalter, und ein
/// eigenes `pill` in `:687-689` für die Coin-Pille. Im hellen Zustand ist die
/// zweite grünlich (`rgba(240,255,248,0.92)`) statt cremefarben. Wer beide
/// zusammenlegt, verliert diesen Unterschied.
@immutable
@visibleForTesting
class MapChromePalette {
  /// Erzeugt eine Fassung.
  const MapChromePalette({
    required this.background,
    required this.border,
    required this.text,
    required this.muted,
    required this.coinPillBackground,
    required this.coinPillBorder,
    required this.levelTrack,
    required this.levelInnerBackground,
    required this.levelText,
    required this.modeActiveBackground,
    required this.modeActiveText,
  });

  /// `mapDark === false`, der einzige Zustand, den die PWA erreicht.
  static const MapChromePalette light = MapChromePalette(
    // `rgba(255,248,238,0.92)`, `:3021`. 0.92 * 255 = 234.6.
    background: Color(0xEBFFF8EE),
    // `rgba(140,100,40,0.2)`, `:3021`.
    border: Color(0x338C6428),
    // `#1A1208`, `:3021`.
    text: Color(0xFF1A1208),
    // `rgba(26,18,8,0.5)`, `:3021`.
    muted: Color(0x801A1208),
    // `rgba(240,255,248,0.92)`, `:689`. Grünlich, nicht cremefarben.
    coinPillBackground: Color(0xEBF0FFF8),
    // `rgba(80,160,80,0.25)`, `:689`.
    coinPillBorder: Color(0x4050A050),
    // `rgba(0,0,0,0.08)`, `:733`.
    levelTrack: Color(0x14000000),
    // `#FDF7E8`, `:739`.
    levelInnerBackground: Color(0xFFFDF7E8),
    // `#7A5C00`, `:741`.
    levelText: Color(0xFF7A5C00),
    // `actBg`, `:3220`.
    modeActiveBackground: Color(0xFF1A1208),
    // `actText`, `:3221`.
    modeActiveText: Color(0xFFFDF5E8),
  );

  /// `mapDark === true`. Vollständig in der Quelle, dort aber unerreichbar,
  /// siehe [MapTopChrome.isDark].
  static const MapChromePalette dark = MapChromePalette(
    // `rgba(18,14,10,0.86)`, `:3020`. 0.86 * 255 = 219.3.
    background: Color(0xDB120E0A),
    // `rgba(255,200,120,0.12)`, `:3020`.
    border: Color(0x1FFFC878),
    // `#F5F0E8`, `:3020`.
    text: Color(0xFFF5F0E8),
    // `rgba(245,240,232,0.45)`, `:3020`.
    muted: Color(0x73F5F0E8),
    // `rgba(18,14,10,0.86)`, `:688`.
    coinPillBackground: Color(0xDB120E0A),
    // `rgba(255,200,120,0.12)`, `:688`.
    coinPillBorder: Color(0x1FFFC878),
    // `rgba(255,255,255,0.10)`, `:733`.
    levelTrack: Color(0x1AFFFFFF),
    // `#1A1410`, `:739`.
    levelInnerBackground: Color(0xFF1A1410),
    // `#F5C518`, `:741`.
    levelText: Color(0xFFF5C518),
    // `actBg`, `:3220`.
    modeActiveBackground: Color(0xFFFFFFFF),
    // `actText`, `:3221`.
    modeActiveText: Color(0xFF111111),
  );

  /// Hintergrund von Stadt-Pille, Kompass und Umschalter, `pill.bg`.
  final Color background;

  /// Rahmen derselben drei, `pill.border`.
  final Color border;

  /// Textfarbe der Stadt-Pille, `pill.text`.
  final Color text;

  /// Textfarbe eines inaktiven Modus, `pill.muted`.
  final Color muted;

  /// Hintergrund der Coin-Pille, eigene Palette in `screen-map.jsx:687-689`.
  final Color coinPillBackground;

  /// Rahmen der Coin-Pille, dieselbe eigene Palette.
  final Color coinPillBorder;

  /// Ungefüllter Teil des Level-Rings.
  final Color levelTrack;

  /// Innenfläche des Level-Rings.
  final Color levelInnerBackground;

  /// Ziffer im Level-Ring.
  final Color levelText;

  /// Fläche des aktiven Modus-Knopfes, `actBg`.
  final Color modeActiveBackground;

  /// Schrift des aktiven Modus-Knopfes, `actText`.
  final Color modeActiveText;
}
