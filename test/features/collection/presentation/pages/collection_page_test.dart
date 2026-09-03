import 'dart:async';

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/collection/presentation/pages/collection_page.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_book_spine.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_cover_view.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_header_card.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_shelf_view.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_trophy_row.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Der Reiseführer als ganzer Bildschirm.
///
/// Überschrieben werden die **Blätter** und nicht `libraryShelfProvider`:
/// `allFactsProvider` und `collectedFactsStoreProvider`. Sonst prüfte dieser
/// Test nur, dass drei Widgets nebeneinander stehen, und nicht, dass die
/// Verdrahtung von den Fakten bis zum Buchrücken trägt.
void main() {
  setUpAll(loadAppFonts);

  Fact factWith({
    required int id,
    String? city,
    String category = 'Historisch',
  }) => Fact(
    id: FactId(id),
    content: FactText(title: 'Titel $id', category: category),
    city: city == null ? null : FactCity(city),
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    List<Fact> facts = const <Fact>[],
    List<int> collected = const <int>[],
    AppLanguage language = AppLanguage.de,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 1800) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
          allFactsProvider.overrideWith((ref) async => facts),
          collectedFactsStoreProvider.overrideWithValue(
            InMemoryCollectedFactsStore(collected.map(FactId.new).toList()),
          ),
        ],
        child: MaterialApp(
          theme: FactTheme.light(),
          home: const Scaffold(body: CollectionPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('während des Ladens steht nur der Ladekreis da', (tester) async {
    // **Ein `Completer`, der nie erfüllt wird**, und nicht `settle: false`:
    // ein `async`-Override ist nach dem ersten Mikrotask fertig, und
    // `pumpWidget` führt Mikrotasks aus. Der Ladezustand wäre schon im ersten
    // Bild vorbei. Dasselbe Vorgehen wie in `fact_page_test.dart`.
    tester.view
      ..physicalSize = const Size(390, 1800) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(AppLanguage.de),
          ),
          allFactsProvider.overrideWith(
            (ref) => Completer<List<Fact>>().future,
          ),
          collectedFactsStoreProvider.overrideWithValue(
            InMemoryCollectedFactsStore(),
          ),
        ],
        child: MaterialApp(
          theme: FactTheme.light(),
          home: const Scaffold(body: CollectionPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(CollectionPage.loadingKey), findsOneWidget);
    expect(find.byType(LibraryShelfView), findsNothing);
  });

  testWidgets('danach stehen Kopfkarte, Regal und Trophäenzeile', (
    tester,
  ) async {
    await pumpPage(
      tester,
      facts: <Fact>[
        factWith(id: 1, city: 'München'),
        factWith(id: 2, city: 'München'),
        factWith(id: 3, city: 'Rom'),
      ],
      collected: <int>[1],
    );

    expect(find.byKey(CollectionPage.loadingKey), findsNothing);
    expect(find.byKey(LibraryHeaderCard.cardKey), findsOneWidget);
    expect(find.byKey(LibraryShelfView.boxKey), findsOneWidget);
    expect(find.byType(LibraryTrophyRow), findsOneWidget);
  });

  testWidgets('die Zahlen der Kopfkarte kommen aus den Daten', (tester) async {
    await pumpPage(
      tester,
      facts: <Fact>[
        factWith(id: 1, city: 'München'),
        factWith(id: 2, city: 'München'),
        factWith(id: 3, city: 'Rom'),
      ],
      collected: <int>[1, 3],
    );

    expect(find.text('2 Geschichten\naus deinen Städten'), findsOneWidget);
    expect(find.text('2 Städte'), findsOneWidget);
  });

  testWidgets('jede Stadt mit Fakten bekommt einen Band, in Regalfolge', (
    tester,
  ) async {
    await pumpPage(
      tester,
      facts: <Fact>[
        factWith(id: 1, city: 'Rom'),
        factWith(id: 2, city: 'München'),
        factWith(id: 3, city: 'Bologna'),
      ],
    );

    expect(find.byType(LibraryBookSpine), findsNWidgets(3));
    // München steht in `WalletCityOrder` vorn, Rom hinten, Bologna hat keinen
    // Eintrag und wird angehängt.
    final double muenchen = tester
        .getTopLeft(find.byKey(LibraryBookSpine.spineKey('muenchen')))
        .dx;
    final double rom = tester
        .getTopLeft(find.byKey(LibraryBookSpine.spineKey('rom')))
        .dx;
    final double bologna = tester
        .getTopLeft(find.byKey(LibraryBookSpine.spineKey('bologna')))
        .dx;

    expect(muenchen, lessThan(rom));
    expect(rom, lessThan(bologna));
  });

  testWidgets('der Zähler auf dem Rücken zählt nur die eigene Stadt', (
    tester,
  ) async {
    await pumpPage(
      tester,
      facts: <Fact>[
        factWith(id: 1, city: 'München'),
        factWith(id: 2, city: 'München'),
        factWith(id: 3, city: 'Rom'),
      ],
      collected: <int>[1, 3],
    );

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('ein Fakt ohne Stadt steht in keinem Band, zählt aber mit', (
    tester,
  ) async {
    // Die Kopfzahl ist die Zahl der gesammelten Fakten, nicht die Summe der
    // Bände. Ein Fakt ohne Stadt ist gesammelt und hat trotzdem kein Regal.
    await pumpPage(
      tester,
      facts: <Fact>[
        factWith(id: 1, city: 'München'),
        factWith(id: 2),
      ],
      collected: <int>[1, 2],
    );

    expect(find.byType(LibraryBookSpine), findsOneWidget);
    expect(find.text('2 Geschichten\naus deinen Städten'), findsOneWidget);
    expect(find.text('1 Städte'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('ohne Fakten steht ein leeres Regal, kein Fehlertext', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.byKey(LibraryShelfView.boxKey), findsOneWidget);
    expect(find.byType(LibraryBookSpine), findsNothing);
    expect(find.byKey(LibraryShelfView.emptySlotKey(0, 0)), findsOneWidget);
    expect(find.text('0 Geschichten\naus deinen Städten'), findsOneWidget);
    expect(find.text('0 Städte'), findsOneWidget);
  });

  testWidgets('ein Fehlschlag zeigt dasselbe wie ein leeres Regal', (
    tester,
  ) async {
    // Parität: scheitert in der PWA das Laden, bleibt `window.FACTS` leer
    // (`app.jsx:227`) und das Regal zeigt Leerplätze.
    //
    // **Der Fehler ist bewusst ein `StateError` und keine `Exception`.**
    // `ProviderContainer.defaultRetry` wiederholt einen gescheiterten
    // `FutureProvider` zehnmal über rund 38 Sekunden und nimmt dabei nur
    // `Error` und `ProviderException` aus. Mit einer `Exception` stünde der
    // Zustand nicht still: er wechselte zwischen Fehler und Ladekreis, und
    // jeder Zeitgeber überlebte das Ende des Tests. Ein `Error` hält ihn
    // fest, und geprüft wird genau das, was der Bildschirm im Fehlerzustand
    // zeigt.
    //
    // Am Gerät gilt die andere Seite: `FactFailure implements Exception`,
    // dort flackert es eine halbe Minute. Das steht bei
    // `factOverlayProvider` und gilt hier genauso.
    tester.view
      ..physicalSize = const Size(390, 1800) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(AppLanguage.de),
          ),
          allFactsProvider.overrideWith(
            (ref) => Future<List<Fact>>.error(StateError('kaputt')),
          ),
          collectedFactsStoreProvider.overrideWithValue(
            InMemoryCollectedFactsStore(),
          ),
        ],
        child: MaterialApp(
          theme: FactTheme.light(),
          home: const Scaffold(body: CollectionPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(LibraryShelfView.boxKey), findsOneWidget);
    expect(find.byType(LibraryBookSpine), findsNothing);
  });

  testWidgets('ein Sammelvorgang setzt Kopfzahl und Zähler hoch', (
    tester,
  ) async {
    // **Die Wache über `watch` statt `read`.** Ohne sie bliebe das Regal auf
    // dem Stand des ersten Aufbaus stehen, und der Nutzer sähe seinen eben
    // gesammelten Fakt nicht.
    final ProviderContainer container = ProviderContainer(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(AppLanguage.de),
        ),
        allFactsProvider.overrideWith(
          (ref) async => <Fact>[
            factWith(id: 1, city: 'München'),
            factWith(id: 2, city: 'München'),
          ],
        ),
        collectedFactsStoreProvider.overrideWithValue(
          InMemoryCollectedFactsStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    tester.view
      ..physicalSize = const Size(390, 1800) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FactTheme.light(),
          home: const Scaffold(body: CollectionPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0/2'), findsOneWidget);
    expect(find.text('0 Geschichten\naus deinen Städten'), findsOneWidget);

    await container.read(collectedFactsProvider.notifier).collect(FactId(1));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('1 Geschichten\naus deinen Städten'), findsOneWidget);
  });

  group('Der Weg zum Cover, Schritt 46', () {
    testWidgets('ein Tipp auf einen Rücken schlägt den Band auf', (
      tester,
    ) async {
      await pumpPage(
        tester,
        facts: <Fact>[
          factWith(id: 1, city: 'München'),
          factWith(id: 2, city: 'Rom'),
        ],
      );

      expect(find.byKey(LibraryCoverView.coverKey), findsNothing);

      await tester.tap(find.byKey(LibraryBookSpine.spineKey('rom')));
      await tester.pumpAndSettle();

      expect(find.byKey(LibraryCoverView.coverKey), findsOneWidget);
      // Der aufgeschlagene Band ist der angetippte und nicht der erste.
      expect(find.text('Rom'), findsOneWidget);
      expect(find.byKey(LibraryShelfView.boxKey), findsNothing);
    });

    testWidgets('der Zurück-Weg führt in die Bibliothek', (tester) async {
      await pumpPage(tester, facts: <Fact>[factWith(id: 1, city: 'München')]);

      await tester.tap(find.byKey(LibraryBookSpine.spineKey('muenchen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LibraryCoverView.backKey));
      await tester.pumpAndSettle();

      expect(find.byKey(LibraryCoverView.coverKey), findsNothing);
      expect(find.byKey(LibraryShelfView.boxKey), findsOneWidget);
    });

    testWidgets('die Kapitelzahl des Covers kommt aus den Fakten', (
      tester,
    ) async {
      // Drei Kategorien in München, zwei davon angefangen. Gezählt wird, was
      // angefangen ist, nicht was existiert.
      await pumpPage(
        tester,
        facts: <Fact>[
          factWith(id: 1, city: 'München', category: 'Historisch'),
          factWith(id: 2, city: 'München', category: 'Architektur'),
          factWith(id: 3, city: 'München', category: 'Mythos'),
          factWith(id: 4, city: 'Rom', category: 'Fun-Fact'),
        ],
        collected: <int>[1, 2, 4],
      );

      await tester.tap(find.byKey(LibraryBookSpine.spineKey('muenchen')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(LibraryCoverView.statKey('chapters')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // Die Geschichten-Kachel zählt die Stadt und nicht die ganze Sammlung:
      // Rom hat einen dritten gesammelten Fakt, der hier nicht mitzählt.
      expect(
        find.descendant(
          of: find.byKey(LibraryCoverView.statKey('stories')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ein Band ohne Kapiteldaten zeigt eine Null und wartet nicht', (
      tester,
    ) async {
      // Die Kapitelzahl ist eine zweite Abfrage. Wartete das Cover auf sie,
      // flackerte der ganze Deckel für eine von drei Zahlen.
      await pumpPage(tester, facts: <Fact>[factWith(id: 1, city: 'München')]);

      await tester.tap(find.byKey(LibraryBookSpine.spineKey('muenchen')));
      await tester.pump();

      expect(find.byKey(LibraryCoverView.coverKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(LibraryCoverView.statKey('chapters')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    });
  });
}
