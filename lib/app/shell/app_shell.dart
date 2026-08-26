import 'package:fact_app/app/shell/floating_tab_bar.dart';
import 'package:fact_app/app/shell/mini_player_slot.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Der Rahmen, in dem jede Tab-Seite läuft: Inhalt, Mini-Player-Platz und die
/// schwebende Tab-Leiste.
///
/// Pendant zum Zusammenspiel von `ScreenFrame`, `TabBar` und `MiniPlayer` in
/// `02_Frontend/app/chrome.jsx` und `app.jsx:1292`. Die Gerätekulisse aus
/// `ScreenFrame` (Statusleiste, Home-Indicator, 390x844-Rahmen) fehlt hier
/// absichtlich: sie existiert nur, damit die PWA im Desktop-Browser wie ein
/// Telefon aussieht (`chrome.jsx:143` und `:145` zeigen sie nur, wenn
/// `window.innerWidth > 500`). Auf einem echten Gerät liefert das
/// Betriebssystem beides.
///
/// ## Freiraum unter dem Inhalt
///
/// Die Leiste schwebt über dem Inhalt. Ohne Gegenmaßnahme endet jede Liste
/// unter ihr. Gelöst über `Scaffold.extendBody`: der `Scaffold` misst die Höhe
/// von [bottomNavigationBar] und erhöht das untere `MediaQuery`-Padding des
/// Rumpfes auf genau diesen Wert (`_BodyBuilder` in `material/scaffold.dart`).
///
/// Damit muss keine Seite die Leiste kennen:
///
/// - `ListView`, `GridView` und `CustomScrollView` ohne eigenes `padding`
///   übernehmen das untere `MediaQuery`-Padding von selbst
///   (`BoxScrollView.build`);
/// - `SafeArea` am Seitenende liefert denselben Abstand;
/// - eine Seite mit eigenem `Scaffold` reicht das Padding weiter, weil sie
///   keine eigene `bottomNavigationBar` hat.
///
/// Eine Seite, die trotzdem `padding: EdgeInsets.zero` setzt, hebelt das aus.
/// Das ist die einzige verbleibende Stelle, an der jemand aktiv etwas falsch
/// machen kann, und sie fällt in der Prüfung auf.
class AppShell extends StatelessWidget {
  /// [navigationShell] kommt von `StatefulShellRoute` und hält je Tab einen
  /// eigenen `Navigator`.
  const AppShell({required this.navigationShell, super.key});

  /// Der Zweig-Umschalter von go_router.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    assert(
      navigationShell.route.branches.length == ShellTab.values.length,
      'Die Zweige in app/routing/app_routes.dart und die Werte von ShellTab '
      'müssen sich eins zu eins entsprechen. Gefunden: '
      '${navigationShell.route.branches.length} Zweige, '
      '${ShellTab.values.length} Tabs.',
    );

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MiniPlayerSlot(),
          FloatingTabBar(
            current: ShellTab.values[navigationShell.currentIndex],
            onSelected: _select,
          ),
        ],
      ),
    );
  }

  void _select(ShellTab tab) {
    // `initialLocation: true` nur beim erneuten Tipp auf den aktiven Tab: dann
    // fällt dessen Stapel auf die Wurzel zurück. Bei einem Wechsel bleibt der
    // Stapel des Ziels stehen, wo der Nutzer ihn verlassen hat. Das ist die
    // Bedingung aus `architecture-overview.md` §11.
    navigationShell.goBranch(
      tab.index,
      initialLocation: tab.index == navigationShell.currentIndex,
    );
  }
}
