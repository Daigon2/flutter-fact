import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/collection/application/generated/wallet_cities.g.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_illustrations.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_cover_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Das Stadt-Cover, `02_Frontend/app/screen-wallet.jsx:460-616`.
void main() {
  setUpAll(loadAppFonts);

  const WalletCityRecord munich = (
    key: 'münchen',
    name: 'München',
    initial: 'M',
    bandNo: 1,
    region: 'Bayern · Hauptstadt',
    color: '#1E5FAD',
    colorDk: '#0D3A6B',
    colorLt: '#3B82F6',
    accent: '#3B82F6',
  );

  LibraryVolume volumeWith({
    String cityKey = 'muenchen',
    String name = 'München',
    int collected = 7,
    int total = 40,
    WalletCityRecord palette = munich,
  }) => LibraryVolume(
    cityKey: cityKey,
    name: name,
    palette: palette,
    hasOwnPalette: palette != walletCityDefault,
    collected: collected,
    total: total,
  );

  Future<void> pumpCover(
    WidgetTester tester, {
    required LibraryVolume volume,
    int startedChapters = 3,
    VoidCallback? onBack,
    VoidCallback? onOpenChapters,
    int? year = 2026,
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
            body: LibraryCoverView(
              volume: volume,
              startedChapters: startedChapters,
              onBack: onBack,
              onOpenChapters: onOpenChapters,
              year: year,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('der Deckel zeigt Marke, Band, Titel und Untertitel', (
    tester,
  ) async {
    await pumpCover(tester, volume: volumeWith());

    expect(find.text('FACT REISEFÜHRER'), findsOneWidget);
    expect(find.text('BAND 1 · BAYERN · HAUPTSTADT'), findsOneWidget);
    expect(find.text('München'), findsOneWidget);
    expect(find.text('MEINE REISE · 2026'), findsOneWidget);
  });

  testWidgets('das Jahr kommt von außen und nicht von der Systemuhr', (
    tester,
  ) async {
    // `docs/engineering/testing.md`: Zeit kontrollieren. Ohne den Parameter
    // wäre dieser Test am 1. Januar rot.
    await pumpCover(tester, volume: volumeWith(), year: 1999);

    expect(find.text('MEINE REISE · 1999'), findsOneWidget);
  });

  testWidgets('die drei Kennzahlen stehen da, „seit" als Gedankenstrich', (
    tester,
  ) async {
    // Es gibt keinen Leseverlauf mit Zeitstempeln, und die Quelle zeigt bei
    // leerem Verlauf dasselbe Zeichen.
    await pumpCover(
      tester,
      volume: volumeWith(collected: 7),
      startedChapters: 4,
    );

    expect(
      find.descendant(
        of: find.byKey(LibraryCoverView.statKey('stories')),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(LibraryCoverView.statKey('chapters')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(LibraryCoverView.statKey('since')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ohne Bandnummer bleibt die Zeile beim Gebiet', (tester) async {
    // Die Quelle schriebe hier „BAND 0 · ", weil `bandNo` in der Vorgabe `0`
    // ist und `wltSimpleFormat` die Null einsetzt. Eine Bandnummer null gibt
    // es nicht.
    await pumpCover(
      tester,
      volume: volumeWith(
        cityKey: 'bologna',
        name: 'Bologna',
        palette: (
          key: '',
          name: '–',
          initial: '?',
          bandNo: 0,
          region: 'Emilia-Romagna',
          color: '#5C4A30',
          colorDk: '#3D3020',
          colorLt: '#A08860',
          accent: '#A08860',
        ),
      ),
    );

    expect(find.text('EMILIA-ROMAGNA'), findsOneWidget);
    expect(find.textContaining('BAND 0'), findsNothing);
  });

  testWidgets('ohne Nummer und ohne Gebiet ist die Zeile leer', (tester) async {
    await pumpCover(
      tester,
      volume: volumeWith(
        cityKey: 'bologna',
        name: 'Bologna',
        palette: walletCityDefault,
      ),
    );

    expect(find.textContaining('BAND'), findsNothing);
    expect(find.text('Bologna'), findsOneWidget);
  });

  testWidgets('der Name kommt vom Band und nicht aus der Palette', (
    tester,
  ) async {
    // Bei einer Stadt ohne Palette hieße der Titel sonst „–", der Vorgabewert
    // von `WalletCityDefault.name`.
    await pumpCover(
      tester,
      volume: volumeWith(
        cityKey: 'goettingen',
        name: 'Göttingen',
        palette: walletCityDefault,
      ),
    );

    expect(find.text('Göttingen'), findsOneWidget);
    expect(find.text('–'), findsNothing);
  });

  testWidgets('der Zurück-Weg trägt die Überschrift der Bibliothek', (
    tester,
  ) async {
    var backs = 0;
    await pumpCover(tester, volume: volumeWith(), onBack: () => backs++);

    expect(find.text('‹ Meine Reisebibliothek'), findsOneWidget);

    await tester.tap(find.byKey(LibraryCoverView.backKey));
    await tester.pump();

    expect(backs, 1);
  });

  testWidgets('ein Tipp auf den Zurück-Weg öffnet nicht die Kapitel', (
    tester,
  ) async {
    // In der Quelle braucht das `data-cover-interactive="1"` plus
    // `stopPropagation`. In Flutter gewinnt der innerste Erkenner von selbst,
    // und genau das prüft dieser Test: die Zusicherung hängt nicht an einer
    // Umsetzung, sondern am Verhalten.
    var backs = 0;
    var chapters = 0;
    await pumpCover(
      tester,
      volume: volumeWith(),
      onBack: () => backs++,
      onOpenChapters: () => chapters++,
    );

    await tester.tap(find.byKey(LibraryCoverView.backKey));
    await tester.pump();

    expect(backs, 1);
    expect(chapters, 0);
  });

  testWidgets('der ganze Deckel führt in die Kapitel', (tester) async {
    var chapters = 0;
    await pumpCover(
      tester,
      volume: volumeWith(),
      onOpenChapters: () => chapters++,
    );

    // Auf den Titel, also mitten in den Textblock und auf kein eigenes
    // Bedienelement.
    await tester.tap(find.text('München'));
    await tester.pump();
    expect(chapters, 1);

    // Und über den Knopf.
    await tester.tap(find.byKey(LibraryCoverView.chaptersKey));
    await tester.pump();
    expect(chapters, 2);
  });

  testWidgets('ohne Ziel tut ein Tipp nichts und wirft nicht', (tester) async {
    // Solange die Kapitelliste fehlt (Schritt 47).
    await pumpCover(tester, volume: volumeWith());

    await tester.tap(find.byKey(LibraryCoverView.chaptersKey));
    await tester.tap(find.byKey(LibraryCoverView.backKey));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('die Illustration steht auf 58 Prozent der Höhe', (tester) async {
    // **Gegen die Zahl der Quelle und nicht gegen die eigene Konstante.**
    // Erst stand hier `844 * LibraryCoverView.illustrationHeightFactor`, und
    // die Pflichtmutation von 0,58 auf 0,50 hat das **überlebt**: beide Seiten
    // der Zusicherung lasen dieselbe Konstante. Genau Muster 18 des
    // Blindheits-Katalogs. Die 489,52 sind `height: '58%'`
    // (`screen-wallet.jsx:481`) mal den 844 Pixeln der Testfläche.
    await pumpCover(tester, volume: volumeWith());

    expect(LibraryCoverView.illustrationHeightFactor, 0.58);
    expect(
      tester.getSize(find.byType(LibraryCityIllustration)).height,
      closeTo(489.52, 0.01),
    );
  });

  testWidgets('die Illustration folgt dem Bandschlüssel', (tester) async {
    await pumpCover(
      tester,
      volume: volumeWith(cityKey: 'rom', name: 'Rom'),
    );

    expect(
      tester
          .widget<LibraryCityIllustration>(find.byType(LibraryCityIllustration))
          .cityKey,
      'rom',
    );
  });

  testWidgets('englisch stehen Marke, Band und Untertitel übersetzt da', (
    tester,
  ) async {
    await pumpCover(tester, volume: volumeWith(), language: AppLanguage.en);

    expect(find.text('FACT TRAVEL GUIDE'), findsOneWidget);
    expect(find.text('VOL. 1 · BAYERN · HAUPTSTADT'), findsOneWidget);
    expect(find.text('MY JOURNEY · 2026'), findsOneWidget);
    expect(find.text('All Chapters'), findsOneWidget);
    expect(find.text('‹ My Travel Library'), findsOneWidget);
  });

  testWidgets('die Vorlesehilfe des Deckels benennt sein Ziel', (tester) async {
    await pumpCover(tester, volume: volumeWith());

    expect(
      tester.getSemantics(find.byKey(LibraryCoverView.coverKey)).label,
      contains('Kapitel öffnen'),
    );
  });
}
