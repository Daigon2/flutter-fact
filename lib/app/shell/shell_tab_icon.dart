import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Kantenlänge eines Tab-Icons.
///
/// `chrome.jsx:102` ruft `t.icon(22, 'currentColor', isActive)`, das erste
/// Argument ist die Größe.
const double shellTabIconSize = 22;

/// Ein Tab-Icon der schwebenden Leiste.
///
/// Das Markup ist 1:1 aus `02_Frontend/app/icons.jsx` übernommen
/// (`tabModus:31`, `tabWallet:44`, `tabProfil:60`, `tabChallenge:183`),
/// einschließlich der `filled`-Variante für den aktiven Tab.
///
/// Warum SVG und kein `CustomPainter`: die Pfaddaten sind die Verhaltensquelle.
/// Wer sie abtippt, kann sie falsch abtippen, und niemand sieht es im Diff.
/// `flutter_svg` ist bereits Abhängigkeit, ein neues Paket entsteht nicht.
///
/// `currentColor` löst `SvgTheme` auf. Explizite Farben im Markup (`white`,
/// `#fff`, `rgba(...)`) bleiben stehen: die gefüllten Varianten zeichnen ihre
/// Innendetails bewusst hell auf der Füllfläche. Ein `ColorFilter` mit
/// `BlendMode.srcIn` wäre der naheliegende Weg und der falsche: er würde diese
/// Details mit einfärben und das aktive Icon zu einem Klecks machen.
class ShellTabIcon extends StatelessWidget {
  /// [color] wird für `currentColor` eingesetzt, inklusive Alphawert.
  const ShellTabIcon({
    required this.tab,
    required this.isActive,
    required this.color,
    super.key,
  });

  /// Welches Icon.
  final ShellTab tab;

  /// Aktiver Tab: gefüllte Variante.
  final bool isActive;

  /// Farbe für `currentColor`.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _markup(tab, filled: isActive),
      width: shellTabIconSize,
      height: shellTabIconSize,
      theme: SvgTheme(currentColor: color),
    );
  }
}

/// SVG-Quelltext eines Tab-Icons.
String _markup(ShellTab tab, {required bool filled}) {
  final fill = filled ? 'currentColor' : 'none';
  final inner = filled ? 'white' : 'currentColor';
  switch (tab) {
    // Icon.tabModus (icons.jsx:31): Karten-Pin.
    case ShellTab.map:
      return '''
<svg width="22" height="22" viewBox="0 0 24 24" fill="$fill" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round">
  <path d="M12 2.5c-3.8 0-7 3.1-7 7 0 5.2 7 12 7 12s7-6.8 7-12c0-3.9-3.2-7-7-7z"/>
  <circle cx="12" cy="9.5" r="2.6" fill="${filled ? 'white' : 'none'}"/>
</svg>''';
    // Icon.tabWallet (icons.jsx:44): Brieftasche.
    case ShellTab.collection:
      return '''
<svg width="22" height="22" viewBox="0 0 24 24" fill="none">
  <rect x="2" y="7" width="20" height="14" rx="3.5" fill="$fill" stroke="currentColor" stroke-width="1.8"/>
  <path d="M2 11h20" stroke="${filled ? 'rgba(255,255,255,0.5)' : 'currentColor'}" stroke-width="1.5"/>
  <path d="M6 4h12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" opacity="0.55"/>
  <circle cx="17" cy="15.5" r="1.8" fill="${filled ? '#fff' : 'currentColor'}" opacity="${filled ? '0.85' : '0.8'}"/>
</svg>''';
    // Icon.tabChallenge (icons.jsx:183): Pokal.
    case ShellTab.challenges:
      return '''
<svg width="22" height="22" viewBox="0 0 24 24" fill="none">
  <path d="M7 3h10v7a5 5 0 01-10 0V3z" fill="$fill" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>
  <path d="M5 5.5H3a2 2 0 000 4h2" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M19 5.5h2a2 2 0 010 4h-2" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12 15v3" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M9 21h6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>''';
    // Icon.tabProfil (icons.jsx:60): Reisepass.
    case ShellTab.profile:
      return '''
<svg width="22" height="22" viewBox="0 0 24 24" fill="$fill" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round">
  <path d="M5 4.5A1.5 1.5 0 016.5 3H18v18H6.5A1.5 1.5 0 015 19.5v-15z"/>
  <path d="M5 19.5A1.5 1.5 0 016.5 18H18" stroke="$inner"/>
  <circle cx="11.5" cy="9" r="2" fill="${filled ? 'white' : 'none'}"/>
  <path d="M8 14c0-1.5 1.5-2.5 3.5-2.5s3.5 1 3.5 2.5" stroke="$inner"/>
</svg>''';
  }
}
