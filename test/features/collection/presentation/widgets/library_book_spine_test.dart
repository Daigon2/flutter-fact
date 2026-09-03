import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/collection/application/generated/wallet_cities.g.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_geometry.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_book_spine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Ein Buchrücken, `02_Frontend/app/screen-wallet.jsx:958-1010`.
void main() {
  setUpAll(loadAppFonts);

  LibraryVolume volumeWith({
    String cityKey = 'muenchen',
    String name = 'München',
    int collected = 3,
    int total = 12,
    WalletCityRecord? palette,
  }) => LibraryVolume(
    cityKey: cityKey,
    name: name,
    palette:
        palette ??
        (
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
    hasOwnPalette: palette == null,
    collected: collected,
    total: total,
  );

  Future<void> pumpSpine(
    WidgetTester tester, {
    required LibraryVolume volume,
    int volumeNumber = 1,
    VoidCallback? onTap,
    AppLanguage language = AppLanguage.de,
  }) async {
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
            body: Center(
              child: SizedBox(
                width: 90,
                child: LibraryBookSpine(
                  volume: volume,
                  volumeNumber: volumeNumber,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('der Rücken zeigt Namen, Zähler und Bandnummer', (tester) async {
    await pumpSpine(tester, volume: volumeWith(), volumeNumber: 1);

    expect(find.text('MÜNCHEN'), findsOneWidget);
    expect(find.text('№ 1'), findsOneWidget);
    // Zähler und Gesamtzahl stehen in einem `Text.rich`, weil die Gesamtzahl
    // blasser ist. `find.text` findet den zusammengesetzten Wert.
    expect(find.text('3/12'), findsOneWidget);
  });

  testWidgets('der Name steht in Großbuchstaben, wie in der Quelle', (
    tester,
  ) async {
    await pumpSpine(tester, volume: volumeWith(name: 'Nürnberg'));

    expect(find.text('NÜRNBERG'), findsOneWidget);
    expect(find.text('Nürnberg'), findsNothing);
  });

  testWidgets('die Höhe folgt dem Sammelfortschritt', (tester) async {
    await pumpSpine(tester, volume: volumeWith(collected: 0, total: 12));
    final double empty = tester
        .getSize(find.byKey(LibraryBookSpine.spineKey('muenchen')))
        .height;

    await pumpSpine(tester, volume: volumeWith(collected: 12, total: 12));
    final double full = tester
        .getSize(find.byKey(LibraryBookSpine.spineKey('muenchen')))
        .height;

    expect(empty, libraryBookMinHeight);
    expect(full, libraryBookMaxHeight);
  });

  testWidgets('ein Tipp erreicht den Rückruf', (tester) async {
    var taps = 0;
    await pumpSpine(tester, volume: volumeWith(), onTap: () => taps++);

    await tester.tap(find.byKey(LibraryBookSpine.spineKey('muenchen')));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('ohne Rückruf tut ein Tipp nichts und wirft nicht', (
    tester,
  ) async {
    // Solange das Stadt-Cover fehlt (Schritt 46), hat der Rücken kein Ziel.
    // Ein `GestureDetector` mit `onTap: null` darf deswegen nicht werfen.
    await pumpSpine(tester, volume: volumeWith());

    await tester.tap(find.byKey(LibraryBookSpine.spineKey('muenchen')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('die Vorlesehilfe ist ein Satz und folgt der Sprache', (
    tester,
  ) async {
    // **Der Kern von E-61 an dieser Stelle.** Die Quelle schreibt das
    // `aria-label` als hartcodierten deutschen Satz hin
    // (`screen-wallet.jsx:968`), auch für englischsprachige Nutzer.
    await pumpSpine(tester, volume: volumeWith(), language: AppLanguage.de);
    expect(
      tester
          .getSemantics(find.byKey(LibraryBookSpine.spineKey('muenchen')))
          .label,
      'München öffnen, 3 von 12',
    );

    await pumpSpine(tester, volume: volumeWith(), language: AppLanguage.en);
    expect(
      tester
          .getSemantics(find.byKey(LibraryBookSpine.spineKey('muenchen')))
          .label,
      'Open München, 3 of 12',
    );
  });

  testWidgets('der Rücken trägt die Farben seiner Palette', (tester) async {
    await pumpSpine(tester, volume: volumeWith());

    final Container container = tester.widget<Container>(
      find.byKey(LibraryBookSpine.spineKey('muenchen')),
    );
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;

    // Dunkel am Falz, hell an der Schnittkante, und die mittleren beiden
    // Stützstellen tragen dieselbe Farbe: `colorDk, color 14%, color 86%,
    // colorLt`.
    expect(gradient.colors, <Color>[
      const Color(0xFF0D3A6B),
      const Color(0xFF1E5FAD),
      const Color(0xFF1E5FAD),
      const Color(0xFF3B82F6),
    ]);
    expect(gradient.stops, <double>[0, 0.14, 0.86, 1]);
  });

  testWidgets('eine Stadt ohne Palette trägt die Vorgabefarben', (
    tester,
  ) async {
    await pumpSpine(
      tester,
      volume: volumeWith(
        cityKey: 'bologna',
        name: 'Bologna',
        palette: walletCityDefault,
      ),
    );

    final Container container = tester.widget<Container>(
      find.byKey(LibraryBookSpine.spineKey('bologna')),
    );
    final LinearGradient gradient =
        (container.decoration! as BoxDecoration).gradient! as LinearGradient;

    expect(gradient.colors.first, const Color(0xFF3D3020));
    expect(gradient.colors.last, const Color(0xFFA08860));
  });

  testWidgets('der Titel läuft von unten nach oben', (tester) async {
    // `writing-mode: vertical-rl` plus `rotate(180deg)`. Drei Vierteldrehungen
    // sind genau das; eine wäre die andere Leserichtung, und auf einem
    // Buchrücken ist das der Unterschied zwischen lesbar und kopfstehend.
    await pumpSpine(tester, volume: volumeWith());

    final RotatedBox box = tester.widget<RotatedBox>(
      find.ancestor(
        of: find.text('MÜNCHEN'),
        matching: find.byType(RotatedBox),
      ),
    );

    expect(box.quarterTurns, 3);
  });
}
