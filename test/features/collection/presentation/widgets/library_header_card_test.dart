import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_header_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Die Kopfkarte, `02_Frontend/app/screen-wallet.jsx:806-902`.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpCard(
    WidgetTester tester, {
    int collectedCount = 7,
    int cityCount = 2,
    int trophiesEarned = 0,
    int? rank,
    VoidCallback? onRankTap,
    AppLanguage language = AppLanguage.de,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
        ],
        child: MaterialApp(
          theme: FactTheme.light(),
          home: Scaffold(
            body: LibraryHeaderCard(
              collectedCount: collectedCount,
              cityCount: cityCount,
              trophiesEarned: trophiesEarned,
              rank: rank,
              onRankTap: onRankTap,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('die Karte zeigt Zahl, Städte und Trophäen', (tester) async {
    await pumpCard(tester, collectedCount: 7, cityCount: 2, trophiesEarned: 1);

    expect(find.text('MEINE REISEBIBLIOTHEK'), findsOneWidget);
    expect(find.text('7 Geschichten\naus deinen Städten'), findsOneWidget);
    expect(find.text('2 Städte'), findsOneWidget);
    expect(find.text('1 Trophäen'), findsOneWidget);
  });

  testWidgets('die Zahl zählt Fakten und nicht Einträge einer Menge', (
    tester,
  ) async {
    // **Die Wache zu E-74.** Die Quelle legt jede Kennung zweimal in eine
    // `Set` (`42` und `'42'`) und zeigt danach `collectedSet.size`, also das
    // Doppelte. Hier ist die Zahl der Parameter, und dieser Test hält fest,
    // dass sie unverändert auf dem Bildschirm landet.
    await pumpCard(tester, collectedCount: 3);

    expect(find.text('3 Geschichten\naus deinen Städten'), findsOneWidget);
    expect(find.text('6 Geschichten\naus deinen Städten'), findsNothing);
  });

  testWidgets('die Rang-Pille fehlt, solange es keinen Rang gibt', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.byKey(LibraryHeaderCard.rankKey), findsNothing);
  });

  testWidgets('mit Rang erscheint die Pille und ein Tipp kommt an', (
    tester,
  ) async {
    var taps = 0;
    await pumpCard(tester, rank: 12, onRankTap: () => taps++);

    expect(find.byKey(LibraryHeaderCard.rankKey), findsOneWidget);
    expect(find.text('#12'), findsOneWidget);

    await tester.tap(find.byKey(LibraryHeaderCard.rankKey));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('der Pfeil steht am Ende und ohne doppeltes Leerzeichen', (
    tester,
  ) async {
    // Die Quelle schreibt `t('wallet.rankSoon').replace('↗', '')` und hängt
    // danach ein goldenes `↗` an. Der Schlüssel trägt das Zeichen aber in der
    // **Mitte**: `Sammler-Rang ↗ bald verfügbar`. Übrig bleibt dort
    // `Sammler-Rang␣␣bald verfügbar` mit zwei Leerzeichen. Teil von E-76.
    await pumpCard(tester);

    expect(find.text('Sammler-Rang bald verfügbar ↗'), findsOneWidget);
    expect(find.textContaining('  '), findsNothing);
  });

  testWidgets('englisch dasselbe, und der Pfeil wandert genauso', (
    tester,
  ) async {
    await pumpCard(tester, language: AppLanguage.en, cityCount: 3);

    expect(find.text('MY TRAVEL LIBRARY'), findsOneWidget);
    expect(find.text('Collector rank coming soon ↗'), findsOneWidget);
    expect(find.text('3 Cities'), findsOneWidget);
    expect(find.text('0 Trophies'), findsOneWidget);
  });

  testWidgets('die Karte trägt den orangen Verlauf der Quelle', (tester) async {
    await pumpCard(tester);

    final Container card = tester.widget<Container>(
      find.byKey(LibraryHeaderCard.cardKey),
    );
    final LinearGradient gradient =
        (card.decoration! as BoxDecoration).gradient! as LinearGradient;

    expect(gradient.colors, <Color>[
      const Color(0xFFFF8A55),
      const Color(0xFFE8380D),
      const Color(0xFFB82707),
    ]);
    // `135deg` läuft von links oben nach rechts unten, und die mittlere
    // Stützstelle sitzt bei 55 Prozent.
    expect(gradient.stops, <double>[0, 0.55, 1]);
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
  });

  testWidgets('die Deko-Kreise werden an der runden Ecke abgeschnitten', (
    tester,
  ) async {
    // `overflow: 'hidden'` am Kasten. Ohne den Schnitt stünden zwei Kugeln
    // neben der Karte, weil sie mit negativem Abstand außen sitzen.
    await pumpCard(tester);

    expect(
      find.ancestor(
        of: find.byKey(LibraryHeaderCard.cardKey),
        matching: find.byType(ClipRRect),
      ),
      findsOneWidget,
    );
  });
}
