/// Die Farbfassung der Fakt-Akte, `02_Frontend/app/screen-fact.jsx:236-242`.
///
/// ## Warum eine eigene Palette und nicht `FactColors`
///
/// Weil die Quelle hier nicht die CSS-Variablen benutzt, sondern sich sechs
/// eigene Werte hinschreibt. Im hellen Zustand sind sie deckungsgleich mit
/// `styles.css`, im dunklen **nicht**: `--ink` ist `#F5F0E8`, die Akte nimmt
/// `#F2EEE8`; `--ink-2` ist `#B0A898`, die Akte nimmt `rgba(255,255,255,0.75)`;
/// `--ink-3` ist `#706860`, die Akte nimmt `rgba(255,255,255,0.35)`; `--border`
/// ist `rgba(255,200,120,0.12)`, die Akte nimmt `rgba(255,255,255,0.07)`.
/// Diese Datei hält den Zustand der Quelle fest, statt vier sichtbare
/// Abweichungen unter einem gemeinsamen Namen zu verstecken. Dieselbe Bauform
/// und dieselbe Begründung wie `MapChromePalette`.
///
/// Die einzige Farbe, die die Akte doch aus den Variablen zieht, ist
/// `var(--stamp)` an der Zitat-Hochziffer (`:13`). Sie steht als [citation]
/// hier, mit dem Wert aus `FactColors.red`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Die sechs Flächen- und Textfarben der Akte plus die Zitatfarbe.
@immutable
class FactDetailPalette {
  /// Erzeugt eine Fassung.
  const FactDetailPalette({
    required this.background,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
  });

  /// `theme === 'light'`.
  static const FactDetailPalette light = FactDetailPalette(
    // `#FDF5E8`, `:237`.
    background: Color(0xFFFDF5E8),
    // `#F5EDD8`, `:238`.
    card: Color(0xFFF5EDD8),
    // `#1A1208`, `:239`.
    ink: Color(0xFF1A1208),
    // `#5C4A30`, `:240`.
    ink2: Color(0xFF5C4A30),
    // `#A08860`, `:241`.
    ink3: Color(0xFFA08860),
    // `rgba(140,100,40,0.12)`, `:242`. 0.12 * 255 = 30.6.
    border: Color(0x1F8C6428),
  );

  /// Der dunkle Zustand.
  static const FactDetailPalette dark = FactDetailPalette(
    // `#13100E`, `:237`.
    background: Color(0xFF13100E),
    // `#251F17`, `:238`.
    card: Color(0xFF251F17),
    // `#F2EEE8`, `:239`. **Nicht** `--ink`.
    ink: Color(0xFFF2EEE8),
    // `rgba(255,255,255,0.75)`, `:240`. 0.75 * 255 = 191.25.
    ink2: Color(0xBFFFFFFF),
    // `rgba(255,255,255,0.35)`, `:241`. 0.35 * 255 = 89.25.
    ink3: Color(0x59FFFFFF),
    // `rgba(255,255,255,0.07)`, `:242`. 0.07 * 255 = 17.85.
    border: Color(0x12FFFFFF),
  );

  /// `var(--stamp)` an der Zitat-Hochziffer, `:13`. In beiden Fassungen
  /// derselbe Wert, siehe `FactColors.red`.
  static const Color citation = Color(0xFFE8380D);

  /// Die Fassung zu einer Helligkeit.
  static FactDetailPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// `bg`, die Fläche hinter allem.
  final Color background;

  /// `card2`, die Fläche der Pillen, der Quellenliste und der Kommentare.
  final Color card;

  /// `ink`, Titel und kräftiger Text.
  final Color ink;

  /// `ink2`, der Lesetext.
  final Color ink2;

  /// `ink3`, Beiwerk und Marginalien.
  final Color ink3;

  /// `border`, der Rahmen um Pillen und Kästen.
  final Color border;

  @override
  bool operator ==(Object other) =>
      other is FactDetailPalette &&
      other.background == background &&
      other.card == card &&
      other.ink == ink &&
      other.ink2 == ink2 &&
      other.ink3 == ink3 &&
      other.border == border;

  @override
  int get hashCode => Object.hash(background, card, ink, ink2, ink3, border);
}
