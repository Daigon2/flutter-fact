import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/shell/floating_tab_bar.dart';
import 'package:fact_app/app/shell/shell_tab.dart';
import 'package:fact_app/app/shell/shell_tab_icon.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/features/discovery/presentation/pages/map_page.dart';
import 'package:fact_app/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Die App-Shell: schwebende Tab-Leiste, ein Navigationsstapel je Tab und
/// unterer Freiraum für scrollende Seiten.
///
/// Ersetzt den früheren `test/app_smoke_test.dart`, der auf den Platzhalter mit
/// dem Text `Splash` geprüft hat. Der Pfad hier spiegelt den Produktionspfad,
/// wie `docs/engineering/naming-and-files.md` es verlangt.
void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.de,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
        ],
        child: const FactApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tabLabel(String text) => find.descendant(
    of: find.byType(FloatingTabBar),
    matching: find.text(text),
  );

  int currentBranchIndex(WidgetTester tester) => tester
      .widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell))
      .currentIndex;

  group('Tab-Leiste', () {
    testWidgets('zeigt die vier Beschriftungen aus chrome.jsx', (tester) async {
      await pumpApp(tester);

      expect(find.byType(FloatingTabBar), findsOneWidget);
      for (final label in <String>['Karte', 'Fakten', 'Challenge', 'Profil']) {
        expect(tabLabel(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('folgt der gewählten Sprache statt fester Texte', (
      tester,
    ) async {
      await pumpApp(tester, language: AppLanguage.en);

      expect(tabLabel('Map'), findsOneWidget);
      expect(tabLabel('Facts'), findsOneWidget);
      expect(tabLabel('Profile'), findsOneWidget);
      expect(tabLabel('Karte'), findsNothing);
    });

    testWidgets('setzt den aktiven Eintrag auf Gewicht 800 und die übrigen '
        'auf 600', (tester) async {
      await pumpApp(tester);

      TextStyle styleOf(String label) =>
          tester.widget<Text>(tabLabel(label)).style!;

      expect(styleOf('Karte').fontWeight, FontWeight.w800);
      expect(styleOf('Karte').color, FactColors.light.red);
      expect(styleOf('Karte').fontFamily, 'Nunito');
      expect(styleOf('Karte').fontSize, 10);

      for (final label in <String>['Fakten', 'Challenge', 'Profil']) {
        expect(styleOf(label).fontWeight, FontWeight.w600, reason: label);
        expect(styleOf(label).color, const Color(0x59000000), reason: label);
      }
    });

    testWidgets('markiert genau das Icon des aktiven Tabs als gefüllt', (
      tester,
    ) async {
      await pumpApp(tester);

      final active = tester
          .widgetList<ShellTabIcon>(find.byType(ShellTabIcon))
          .map((icon) => icon.isActive)
          .toList();

      expect(active, <bool>[true, false, false, false]);
    });

    testWidgets('hält die Höhe aus chrome.jsx ein', (tester) async {
      await pumpApp(tester);

      // 8 + (2 + 30 + 2 + 10 + 2) + 8 Innenabstand, dazu 2x1 Rahmen ergibt die
      // Pille mit 64. Der Abstand nach unten ist max(14, Safe Area), in der
      // Testumgebung ohne Safe Area also 14.
      expect(tester.getSize(find.byType(FloatingTabBar)).height, 78);
    });
  });

  group('Zweige', () {
    testWidgets('ein Tipp wechselt den Zweig und die gezeigte Seite', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(currentBranchIndex(tester), ShellTab.map.index);
      // Ein nie besuchter Zweig ist noch gar nicht aufgebaut.
      expect(find.byType(ProfilePage), findsNothing);

      await tester.tap(tabLabel('Profil'));
      await tester.pumpAndSettle();

      expect(currentBranchIndex(tester), ShellTab.profile.index);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(
        tester.widget<Text>(tabLabel('Profil')).style!.fontWeight,
        FontWeight.w800,
      );
    });

    testWidgets('der Navigator eines Tabs überlebt den Wechsel', (
      tester,
    ) async {
      await pumpApp(tester);

      // Der nächstliegende Navigator über der Seite ist der des Zweigs. Bleibt
      // sein State über einen Tabwechsel derselbe, ist auch sein Routenstapel
      // derselbe: `StatefulShellRoute` hält die Zweige im IndexedStack am
      // Leben, statt sie neu aufzubauen.
      NavigatorState mapNavigator() => tester.state<NavigatorState>(
        find
            .ancestor(
              of: find.byType(MapPage),
              matching: find.byType(Navigator),
            )
            .first,
      );

      final before = mapNavigator();

      await tester.tap(tabLabel('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(tabLabel('Karte'));
      await tester.pumpAndSettle();

      expect(mapNavigator(), same(before));
      expect(currentBranchIndex(tester), ShellTab.map.index);
    });
  });

  group('Freiraum unter dem Inhalt', () {
    testWidgets('der Rumpf bekommt unten so viel Platz wie die Leiste hoch '
        'ist', (tester) async {
      await pumpApp(tester);

      final barHeight = tester.getSize(find.byType(FloatingTabBar)).height;
      final pageContext = tester.element(find.byType(MapPage));

      // Damit reicht eine ListView ohne eigenes `padding` von selbst bis über
      // die Leiste hinaus, ohne dass die Seite die Leiste kennen muss.
      expect(MediaQuery.paddingOf(pageContext).bottom, barHeight);
    });
  });
}
