import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_chapters_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Das Inhaltsverzeichnis, `02_Frontend/app/screen-wallet.jsx:617-780`.
void main() {
  setUpAll(loadAppFonts);

  final LibraryVolume munich = LibraryVolume(
    cityKey: 'muenchen',
    name: 'München',
    palette: (
      key: 'münchen',
      name: 'München',
      initial: 'M',
      bandNo: 1,
      region: 'Bayern · Hauptstadt',
      color: '#1E5FAD',
      colorDk: '#0D3A6B',
      colorLt: '#3B82F6',
      accent: '#3B82F6',
    ),
    hasOwnPalette: true,
    collected: 5,
    total: 20,
  );

  /// Sechs Kapitel aus zwei Listen: gesammelt und gesamt, je Kapitel.
  List<LibraryChapter> chaptersOf(List<int> collected, List<int> total) =>
      <LibraryChapter>[
        for (int i = 0; i < libraryCategoryOrder.length; i++)
          LibraryChapter(
            categoryKey: libraryCategoryOrder[i],
            collected: collected[i],
            total: total[i],
          ),
      ];

  Future<void> pumpChapters(
    WidgetTester tester, {
    required List<LibraryChapter> chapters,
    VoidCallback? onBack,
    void Function(String)? onOpenChapter,
    AppLanguage language = AppLanguage.de,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 1400) * 3
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
            body: LibraryChaptersView(
              volume: munich,
              chapters: chapters,
              onBack: onBack,
              onOpenChapter: onOpenChapter,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'die Kopfkarte zeigt Stadt, Geschichten, Kapitel und Gesamtzahl',
    (tester) async {
      await pumpChapters(
        tester,
        chapters: chaptersOf(<int>[3, 2, 0, 0, 0, 0], <int>[10, 5, 4, 0, 0, 0]),
      );

      expect(find.text('München'), findsOneWidget);
      expect(find.text('5 Geschichten'), findsOneWidget);
      expect(find.text('2 Kapitel'), findsOneWidget);
      // `~{total} gesamt` mit der Tilde der Quelle.
      expect(find.text('~19 gesamt'), findsOneWidget);
    },
  );

  testWidgets('der Fortschrittsbalken erscheint erst mit dem ersten Fakt', (
    tester,
  ) async {
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[0, 0, 0, 0, 0, 0], <int>[10, 5, 0, 0, 0, 0]),
    );
    expect(find.byKey(LibraryChaptersView.progressKey), findsNothing);

    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[1, 0, 0, 0, 0, 0], <int>[10, 5, 0, 0, 0, 0]),
    );
    expect(find.byKey(LibraryChaptersView.progressKey), findsOneWidget);
  });

  testWidgets('ein Kapitel ohne Fakten der Stadt fehlt ganz', (tester) async {
    // Der Unterschied, auf den es ankommt: „gibt es hier nicht" ist nicht
    // dasselbe wie „hast du noch nicht".
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[1, 0, 0, 0, 0, 0], <int>[3, 2, 0, 0, 0, 0]),
    );

    expect(find.byKey(LibraryChaptersView.chapterKey('hist')), findsOneWidget);
    expect(find.byKey(LibraryChaptersView.chapterKey('arch')), findsOneWidget);
    expect(find.byKey(LibraryChaptersView.chapterKey('myth')), findsNothing);
    expect(find.byKey(LibraryChaptersView.chapterKey('heute')), findsNothing);
  });

  testWidgets('ein verschlossenes Kapitel steht da, trägt aber keinen Namen', (
    tester,
  ) async {
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[1, 0, 0, 0, 0, 0], <int>[3, 2, 0, 0, 0, 0]),
    );

    // Das offene Kapitel trägt seinen Namen und seine Seitenzahl.
    expect(find.text('Historisch'), findsOneWidget);
    expect(find.text('1 Geschichten · S.1'), findsOneWidget);
    // Das verschlossene trägt „noch nicht entdeckt" statt „Architektur".
    expect(find.text('Architektur'), findsNothing);
    expect(find.text('noch nicht entdeckt'), findsOneWidget);
  });

  testWidgets('ein verschlossenes Kapitel ist auf 45 Prozent abgeblendet', (
    tester,
  ) async {
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[1, 0, 0, 0, 0, 0], <int>[3, 2, 0, 0, 0, 0]),
    );

    final Finder locked = find.ancestor(
      of: find.byKey(LibraryChaptersView.chapterKey('arch')),
      matching: find.byType(Opacity),
    );

    expect(tester.widget<Opacity>(locked).opacity, 0.45);
    // Und das offene ist nicht abgeblendet.
    expect(
      find.ancestor(
        of: find.byKey(LibraryChaptersView.chapterKey('hist')),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('die römische Zahl zählt über alle sechs, nicht über sichtbare', (
    tester,
  ) async {
    // Eine Stadt mit ausschließlich Mythos-Fakten zeigt genau ein Kapitel,
    // und das heißt **III** und nicht I. Die Zahl ist die Kennung des
    // Kapitels im Band und keine laufende Nummer der Liste.
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[0, 0, 2, 0, 0, 0], <int>[0, 0, 4, 0, 0, 0]),
    );

    expect(find.byKey(LibraryChaptersView.chapterKey('myth')), findsOneWidget);
    expect(find.text('III'), findsOneWidget);
    expect(find.text('I'), findsNothing);
  });

  testWidgets('die Seitenzahlen laufen über die gesammelten Fakten', (
    tester,
  ) async {
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[3, 2, 4, 0, 0, 0], <int>[5, 5, 5, 0, 0, 0]),
    );

    expect(find.text('3 Geschichten · S.1'), findsOneWidget);
    expect(find.text('2 Geschichten · S.4'), findsOneWidget);
    expect(find.text('4 Geschichten · S.6'), findsOneWidget);
  });

  testWidgets('ein Tipp auf ein offenes Kapitel meldet seinen Schlüssel', (
    tester,
  ) async {
    final List<String> opened = <String>[];
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[1, 1, 0, 0, 0, 0], <int>[3, 2, 0, 0, 0, 0]),
      onOpenChapter: opened.add,
    );

    await tester.tap(find.byKey(LibraryChaptersView.chapterKey('arch')));
    await tester.pump();

    expect(opened, <String>['arch']);
  });

  testWidgets('ein verschlossenes Kapitel nimmt keinen Tipp an', (
    tester,
  ) async {
    final List<String> opened = <String>[];
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[1, 0, 0, 0, 0, 0], <int>[3, 2, 0, 0, 0, 0]),
      onOpenChapter: opened.add,
    );

    await tester.tap(
      find.byKey(LibraryChaptersView.chapterKey('arch')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(opened, isEmpty);
  });

  testWidgets('der Zurück-Weg trägt die Überschrift der Bibliothek', (
    tester,
  ) async {
    var backs = 0;
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[1, 0, 0, 0, 0, 0], <int>[3, 0, 0, 0, 0, 0]),
      onBack: () => backs++,
    );

    expect(find.text('‹ Meine Reisebibliothek'), findsOneWidget);

    await tester.tap(find.byKey(LibraryChaptersView.backKey));
    await tester.pump();

    expect(backs, 1);
  });

  testWidgets('die Kopfkarte trägt den Verlauf der Stadt', (tester) async {
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[1, 0, 0, 0, 0, 0], <int>[3, 0, 0, 0, 0, 0]),
    );

    final Container header = tester.widget<Container>(
      find.byKey(LibraryChaptersView.headerKey),
    );
    final LinearGradient gradient =
        (header.decoration! as BoxDecoration).gradient! as LinearGradient;

    // `linear-gradient(135deg, ${city.color} 0%, ${city.colorDk} 100%)`, und
    // nicht der Orange-Verlauf der Bibliothek: der Deckel und die Kapitel
    // gehören der Stadt.
    expect(gradient.colors, <Color>[
      const Color(0xFF1E5FAD),
      const Color(0xFF0D3A6B),
    ]);
  });

  testWidgets('englisch stehen Kapitelnamen und Chips übersetzt da', (
    tester,
  ) async {
    await pumpChapters(
      tester,
      chapters: chaptersOf(<int>[2, 0, 0, 0, 0, 0], <int>[4, 3, 0, 0, 0, 0]),
      language: AppLanguage.en,
    );

    expect(find.text('Historical'), findsOneWidget);
    expect(find.text('2 Stories'), findsOneWidget);
    expect(find.text('~7 total'), findsOneWidget);
    expect(find.text('‹ My Travel Library'), findsOneWidget);
  });
}
