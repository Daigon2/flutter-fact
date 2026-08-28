import 'dart:math' show max;
import 'dart:ui' show ImageFilter;

import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:fact_app/app/shell/shell_tab_icon.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die schwebende Tab-Leiste, Pendant zu `TabBar` aus
/// `02_Frontend/app/chrome.jsx:52-125`.
///
/// Alle Maße stammen aus dieser Funktion und sind an der jeweiligen Zeile
/// belegt. Was die Quelle als CSS-Variable setzt (`--stamp`, `--stamp-soft`),
/// kommt aus `context.factColors`. Was sie inline als `rgba(...)` setzt, steht
/// weiter unten als private Konstante: `FactColors` nimmt bewusst nur die
/// Tokens aus `styles.css` auf, Inline-Werte bleiben beim Bauteil, das sie
/// benutzt (siehe Abschnitt "Keine Schatten-Tokens" in `fact_colors.dart`).
///
/// ## Nicht enthalten: der Challenge-Punkt
///
/// `chrome.jsx:58` hängt einen Punkt an den Challenge-Tab, sobald eine Jagd
/// läuft (`window.__huntActive`, `chrome.jsx:42-50`). Diesen Zustand gibt es
/// im Rebuild noch nicht, und ihn hier zu erfinden hieße, einen Sitzungszustand
/// zu bauen, den keine Quelle deckt. Die Werte für den Nachbau stehen in
/// `chrome.jsx:104-111`: 8x8, Kreis, `top: 2`, `right: 6`, Farbe `--stamp`,
/// 2px Ring in der Farbe des Leistenhintergrunds.
class FloatingTabBar extends ConsumerWidget {
  /// [onSelected] bekommt den angetippten Tab, auch wenn er bereits aktiv ist.
  /// Der Aufrufer entscheidet, was ein erneuter Tipp auf den aktiven Tab tut.
  const FloatingTabBar({
    required this.current,
    required this.onSelected,
    super.key,
  });

  /// Mindestabstand der Leiste zum unteren Bildschirmrand.
  ///
  /// `chrome.jsx:70`: `bottom: max(14px, env(safe-area-inset-bottom, 0px))`.
  /// Also **Maximum**, keine Summe: auf einem Gerät mit Home-Indicator liegt
  /// die Leiste auf der sicheren Kante, nicht 14px darüber.
  ///
  /// **Nachgetragen am 28.08.2026, weil die Rechnung der Quelle anders lautet
  /// als dieser Vergleich vermuten lässt.** Das `bottom` der Quelle misst
  /// nicht ab der Bildschirmkante, sondern ab der Unterkante der
  /// `.app-frame`, und die ist auf dem Telefon schon um die Safe Area
  /// eingerückt: `index.html:101-107` legt `padding-bottom:
  /// env(safe-area-inset-bottom)` an den `body` und deckelt `#root` auf
  /// `100dvh` minus beide Einzüge, `chrome.jsx:137` gibt dem Rahmen darin
  /// `height: 100%` und `position: relative`. Die PWA zählt die Safe Area
  /// damit **zweimal**: auf einem Gerät mit 34 Pixel Home-Indicator schwebt
  /// ihre Leiste 68 statt 48 Pixel über der Kante.
  ///
  /// Übernommen ist deshalb die Absicht und nicht die Arithmetik. Das
  /// Maximum ab der Bildschirmkante ergibt genau das, was die Quelle sagen
  /// will. Wer beim nächsten Paritätsabgleich `max(14px, env(...))` liest und
  /// nachrechnet, findet hier den Grund für die Abweichung.
  static const double minBottomInset = 14;

  /// Höhe der Pille bei Systemschriftgröße 1.0.
  ///
  /// 2x1 Rahmen, 2x8 Innenabstand und die Spalte aus 2 + 30 + 2 + 10 + 2
  /// (`chrome.jsx:81`, `:91`, `:92`, `:96`, `:114-117`).
  ///
  /// **Kein verlässliches Maß für andere Schriftgrößen.** Die Beschriftung
  /// wächst mit der Systemschrift und bricht dabei um: gemessen am 28.08.2026
  /// sind es bei Skalierung 2.0 auf 360, 375 und 390 Pixeln Breite jeweils 94
  /// statt 64, weil "Challenge" dort zweizeilig wird. Wer die Oberkante der
  /// Leiste genau braucht, misst sie über `ShellAnchors.bottomBar`. Diese
  /// Konstante taugt als Ersatzwert, solange noch nichts gemessen ist, und als
  /// Beleg dafür, woraus sich die 64 zusammensetzen.
  static const double nominalPillHeight = 64;

  /// Seitenabstand der Leiste, `chrome.jsx:71`.
  static const double sideInset = 12;

  /// Der gerade aktive Tab.
  final ShellTab current;

  /// Wird beim Antippen eines Tabs gerufen.
  final ValueChanged<ShellTab> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(appStringsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: sideInset,
        right: sideInset,
        // `paddingOf` und nicht `viewPaddingOf`, obwohl `env(safe-area-inset-
        // bottom)` dem zweiten entspricht: bei offener Tastatur schiebt der
        // `Scaffold` die Leiste über die Tastatur, und dort gibt es keinen
        // Home-Indicator, dem man ausweichen müsste. `paddingOf` ist in dieser
        // Lage 0, `viewPaddingOf` bliebe bei der vollen Gerätekante stehen und
        // ließe eine Lücke. Ohne Tastatur sind beide gleich.
        bottom: max(minBottomInset, MediaQuery.paddingOf(context).bottom),
      ),
      child: DecoratedBox(
        // Der Schatten liegt außerhalb des Clips, sonst schneidet ihn das
        // ClipRRect für den Weichzeichner weg.
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(_pillRadius)),
          boxShadow: <BoxShadow>[_pillShadow],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(_pillRadius)),
          child: BackdropFilter(
            // `backdropFilter: blur(24px)`, chrome.jsx:78. Der Parameter von
            // CSS `blur()` ist laut Filter Effects Level 1 die
            // Standardabweichung der Gaußfunktion, also derselbe Wert, den
            // `ImageFilter.blur` als Sigma erwartet. Keine Umrechnung nötig.
            //
            // Bei 96 bis 97 Prozent Deckkraft der Fläche darüber trägt der
            // Weichzeichner optisch fast nichts bei, kostet aber eine
            // Save-Layer-Runde pro Frame. Er bleibt trotzdem drin, weil die
            // Fläche stadtabhängig transparenter werden kann und die Leiste
            // dann ohne ihn hart wirkt.
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            // `Container` und nicht `DecoratedBox` plus `Padding`: nur
            // `Container` schlägt die Rahmenstärke als zusätzlichen
            // Innenabstand auf. Ohne das läge der 1px-Rahmen über dem Inhalt
            // und die Pille wäre 62 statt 64 hoch. CSS rechnet mit
            // `box-sizing: content-box`, der Rahmen kommt dort außen dazu.
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? _backgroundDark : _backgroundLight,
                borderRadius: const BorderRadius.all(
                  Radius.circular(_pillRadius),
                ),
                border: Border.all(color: isDark ? _borderDark : _borderLight),
              ),
              // `padding: '8px 6px'`, chrome.jsx:81.
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: <Widget>[
                  for (final tab in ShellTab.values)
                    Expanded(
                      child: _TabButton(
                        tab: tab,
                        label: strings.text(tab.labelKey),
                        isActive: tab == current,
                        isDark: isDark,
                        onTap: () => onSelected(tab),
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

/// Ein einzelner Eintrag, `chrome.jsx:87-119`.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  final ShellTab tab;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    // `color: isActive ? 'var(--stamp)' : inact`, chrome.jsx:93 und :117.
    // `--stamp` und `--red` tragen in beiden Themes denselben Wert.
    final foreground = isActive
        ? colors.red
        : (isDark ? _inactiveDark : _inactiveLight);

    // Der Anker sitzt ganz außen, damit sein Rechteck dem `<button>` der Quelle
    // entspricht: `chrome.jsx:88` hängt `data-tour-anchor` an den Knopf selbst,
    // und der hat `flex: 1`, füllt also die volle Spaltenbreite. Weiter innen
    // gesetzt, käme nur die Höhe des Inhalts heraus und der Leuchtring säße zu
    // schmal.
    return AnchorTarget(
      anchorId: tab.anchorId,
      child: Semantics(
        button: true,
        selected: isActive,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            // `padding: '2px 0'`, chrome.jsx:92.
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  // 42x30, Radius 12, chrome.jsx:96.
                  width: 42,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // `--stamp-soft`, chrome.jsx:97. In `FactColors` heißt das
                    // Feld `redSoft` und trägt genau diesen Wert.
                    color: isActive ? colors.redSoft : const Color(0x00000000),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: ShellTabIcon(
                    tab: tab,
                    isActive: isActive,
                    color: foreground,
                  ),
                ),
                // `gap: 2`, chrome.jsx:91.
                const SizedBox(height: 2),
                Text(
                  label,
                  // `fontFamily: 'Nunito'`, Gewicht 800 aktiv und 600 inaktiv,
                  // `fontSize: 10`, `lineHeight: 1` (chrome.jsx:114-117).
                  // Gewicht 600 hat in `FactTypography` keine eigene Rolle, weil
                  // `styles.css` dafür keine Klasse führt: die PWA setzt es
                  // inline. Deshalb die Ableitung aus `heading` (Nunito 800).
                  style: FactTypography.heading.copyWith(
                    fontSize: 10,
                    height: 1,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `borderRadius: 30`, chrome.jsx:80.
const double _pillRadius = 30;

/// `background: 'rgba(18,14,10,0.96)'`, chrome.jsx:63. 0.96 * 255 = 244.8.
const Color _backgroundDark = Color(0xF5120E0A);

/// `background: 'rgba(255,255,255,0.97)'`, chrome.jsx:63. 0.97 * 255 = 247.35.
const Color _backgroundLight = Color(0xF7FFFFFF);

/// `border: 'rgba(255,255,255,0.08)'`, chrome.jsx:64.
const Color _borderDark = Color(0x14FFFFFF);

/// `border: 'rgba(0,0,0,0.08)'`, chrome.jsx:64.
const Color _borderLight = Color(0x14000000);

/// `inact: 'rgba(255,255,255,0.35)'`, chrome.jsx:65.
const Color _inactiveDark = Color(0x59FFFFFF);

/// `inact: 'rgba(0,0,0,0.35)'`, chrome.jsx:65.
const Color _inactiveLight = Color(0x59000000);

/// `boxShadow: '0 8px 28px rgba(0,0,0,0.22)'`, chrome.jsx:82.
///
/// Der Radius wird unverändert als `blurRadius` übernommen. Flutter rechnet
/// ihn intern in ein Sigma um, CSS tut dasselbe mit einer anderen Konstante.
/// Ohne einen Referenzscreenshot ist jede Feinjustierung geraten, deshalb der
/// direkte Wert.
///
/// Der zweite Teil der Quelle, `0 1px 0 rgba(255,255,255,0.5) inset`, fehlt:
/// `BoxShadow` kennt keine Inset-Schatten. Ein nachgebauter 1px-Streifen wäre
/// eine sichtbare Kante statt eines Verlaufs. Das ist eine bewusste optische
/// Abweichung, kein Versehen.
const BoxShadow _pillShadow = BoxShadow(
  color: Color(0x38000000),
  offset: Offset(0, 8),
  blurRadius: 28,
);
