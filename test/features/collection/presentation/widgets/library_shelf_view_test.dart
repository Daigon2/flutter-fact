import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/core/widgets/dashed_border_painter.dart';
import 'package:fact_app/features/collection/application/generated/wallet_cities.g.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_geometry.dart';
import 'package:fact_app/features/collection/presentation/library_look.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_book_spine.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_shelf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Das Bücherregal, `02_Frontend/app/screen-wallet.jsx:914-1031`.
void main() {
  setUpAll(loadAppFonts);

  LibraryVolume volumeWith({
    required String cityKey,
    String? name,
    int collected = 1,
    int total = 10,
    bool ownPalette = true,
  }) => LibraryVolume(
    cityKey: cityKey,
    name: name ?? cityKey,
    palette: ownPalette
        ? (
            key: cityKey,
            name: name ?? cityKey,
            initial: 'X',
            bandNo: 7,
            region: '',
            color: '#1E5FAD',
            colorDk: '#0D3A6B',
            colorLt: '#3B82F6',
            accent: '#3B82F6',
          )
        : walletCityDefault,
    hasOwnPalette: ownPalette,
    collected: collected,
    total: total,
  );

  Future<void> pumpShelf(
    WidgetTester tester, {
    required List<LibraryVolume> volumes,
    void Function(LibraryVolume)? onOpenVolume,
    AppLanguage language = AppLanguage.de,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 1600) * 3
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
            body: SingleChildScrollView(
              child: LibraryShelfView(
                volumes: volumes,
                onOpenVolume: onOpenVolume,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('die Überschrift zählt die Bände und nicht die Leerplätze', (
    tester,
  ) async {
    await pumpShelf(
      tester,
      volumes: <LibraryVolume>[
        volumeWith(cityKey: 'muenchen'),
        volumeWith(cityKey: 'rom'),
      ],
    );

    expect(find.text('BÜCHERREGAL'), findsOneWidget);
    // Zwei Bände, obwohl acht Plätze auf dem Regal stehen.
    expect(find.text('2 BÄNDE'), findsOneWidget);
  });

  testWidgets('jeder Band bekommt einen Rücken', (tester) async {
    await pumpShelf(
      tester,
      volumes: <LibraryVolume>[
        volumeWith(cityKey: 'muenchen', name: 'München'),
        volumeWith(cityKey: 'rom', name: 'Rom'),
      ],
    );

    expect(find.byType(LibraryBookSpine), findsNWidgets(2));
    expect(find.byKey(LibraryBookSpine.spineKey('muenchen')), findsOneWidget);
    expect(find.byKey(LibraryBookSpine.spineKey('rom')), findsOneWidget);
  });

  testWidgets('ein leeres Regal zeigt zwei Reihen mit acht Leerplätzen', (
    tester,
  ) async {
    await pumpShelf(tester, volumes: <LibraryVolume>[]);

    expect(find.byType(LibraryBookSpine), findsNothing);
    for (var row = 0; row < libraryMinimumRows; row++) {
      for (var column = 0; column < libraryBooksPerRow; column++) {
        expect(
          find.byKey(LibraryShelfView.emptySlotKey(row, column)),
          findsOneWidget,
          reason: 'Leerplatz $row/$column fehlt',
        );
      }
    }
  });

  testWidgets('ein Band lässt sieben Leerplätze stehen', (tester) async {
    await pumpShelf(
      tester,
      volumes: <LibraryVolume>[volumeWith(cityKey: 'muenchen')],
    );

    expect(find.byType(LibraryBookSpine), findsOneWidget);
    // Der erste Platz der ersten Reihe trägt das Buch, die anderen sieben
    // sind leer.
    expect(find.byKey(LibraryShelfView.emptySlotKey(0, 0)), findsNothing);
    expect(find.byKey(LibraryShelfView.emptySlotKey(0, 3)), findsOneWidget);
    expect(find.byKey(LibraryShelfView.emptySlotKey(1, 0)), findsOneWidget);
  });

  testWidgets('ein Leerplatz trägt den gestrichelten Rahmen der Quelle', (
    tester,
  ) async {
    await pumpShelf(tester, volumes: <LibraryVolume>[]);

    final CustomPaint paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(LibraryShelfView.emptySlotKey(0, 0)),
        matching: find.byType(CustomPaint),
      ),
    );
    final DashedBorderPainter painter = paint.painter! as DashedBorderPainter;

    // `2px dashed rgba(255,200,120,0.18)`, `screen-wallet.jsx:948`.
    expect(painter.strokeWidth, 2);
    expect(painter.color, const Color(0x2EFFC878));
    // Dieselben ungleichen Ecken wie ein Buchrücken.
    expect(painter.borderRadius, libraryBookRadius);
  });

  testWidgets('unter jeder Reihe liegt ein Holzbrett', (tester) async {
    await pumpShelf(
      tester,
      volumes: <LibraryVolume>[
        for (var i = 0; i < 5; i++) volumeWith(cityKey: 'stadt$i'),
      ],
    );

    // Fünf Bände sind zwei Reihen, also zwei Bretter.
    final Iterable<Positioned> boards = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .where((Positioned p) => p.height == libraryShelfBoardHeight);

    expect(boards.length, 2);
    for (final Positioned board in boards) {
      // Links und rechts über die Bücher hinaus, `left: -8, right: -8`.
      expect(board.left, -libraryShelfBoardOverhang);
      expect(board.right, -libraryShelfBoardOverhang);
      expect(board.bottom, 0);
    }
  });

  testWidgets('ein Tipp auf einen Rücken meldet den richtigen Band', (
    tester,
  ) async {
    final List<String> opened = <String>[];
    await pumpShelf(
      tester,
      volumes: <LibraryVolume>[
        volumeWith(cityKey: 'muenchen'),
        volumeWith(cityKey: 'rom'),
      ],
      onOpenVolume: (LibraryVolume volume) => opened.add(volume.cityKey),
    );

    await tester.tap(find.byKey(LibraryBookSpine.spineKey('rom')));
    await tester.pump();

    expect(opened, <String>['rom']);
  });

  testWidgets('die Bandnummer einer Stadt ohne Palette folgt der Position', (
    tester,
  ) async {
    // Der Fund aus E-75, hier im Widget nachgeprüft: derselbe Band bekommt
    // eine andere Nummer, sobald eine Stadt vor ihm steht.
    await pumpShelf(
      tester,
      volumes: <LibraryVolume>[
        volumeWith(cityKey: 'bologna', ownPalette: false),
      ],
    );
    expect(find.text('№ 1'), findsOneWidget);

    await pumpShelf(
      tester,
      volumes: <LibraryVolume>[
        volumeWith(cityKey: 'muenchen'),
        volumeWith(cityKey: 'bologna', ownPalette: false),
      ],
    );
    // München trägt die 7 aus seiner Palette, Bologna die Position 2.
    expect(find.text('№ 7'), findsOneWidget);
    expect(find.text('№ 2'), findsOneWidget);
  });

  testWidgets('der Hinweis zum Antippen folgt der Sprache', (tester) async {
    await pumpShelf(
      tester,
      volumes: <LibraryVolume>[],
      language: AppLanguage.en,
    );

    expect(find.text('· tap a spine to browse ·'), findsOneWidget);
    expect(find.text('0 VOLS'), findsOneWidget);
    expect(find.text('NEXT CITY …'), findsWidgets);
  });
}
