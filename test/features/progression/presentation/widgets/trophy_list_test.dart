import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/progression/application/trophy_catalog.dart';
import 'package:fact_app/features/progression/domain/entities/trophy.dart';
import 'package:fact_app/features/progression/presentation/widgets/trophy_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Die Trophäenliste, `02_Frontend/app/screen-profil.jsx:438-468`.
void main() {
  setUpAll(loadAppFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Future<void> pumpList(
    WidgetTester tester, {
    Set<String> unlockedKeys = const <String>{},
    AppLanguage language = AppLanguage.de,
    ThemeData? theme,
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
          theme: theme ?? FactTheme.light(),
          home: Scaffold(body: TrophyList(unlockedKeys: unlockedKeys)),
        ),
      ),
    );
    await tester.pump();
  }

  group('Inhalt', () {
    testWidgets('eine offene Trophäe zeigt Titel, Beschreibung und Stufe', (
      tester,
    ) async {
      await pumpList(tester, unlockedKeys: <String>{'chronist'});

      expect(
        tester.widget<Text>(TrophyList.nameKey('chronist').asFinder).data,
        'Chronist',
      );
      expect(
        tester.widget<Text>(TrophyList.subKey('chronist').asFinder).data,
        '10 historische Fakten gesammelt',
      );
      // `threshold: 10` fällt in den Standardzweig unter 25: Bronze.
      expect(
        tester.widget<Text>(TrophyList.tierLabelKey('chronist').asFinder).data,
        'BRONZE',
      );
    });

    testWidgets('eine gesperrte Trophäe zeigt keine Stufenbeschriftung', (
      tester,
    ) async {
      await pumpList(tester);

      expect(
        tester.widget<Text>(TrophyList.nameKey('chronist').asFinder).data,
        'Chronist',
      );
      expect(TrophyList.tierLabelKey('chronist').asFinder, findsNothing);
    });

    testWidgets('auf Englisch stehen die englischen Felder', (tester) async {
      await pumpList(
        tester,
        unlockedKeys: <String>{'chronist'},
        language: AppLanguage.en,
      );

      expect(
        tester.widget<Text>(TrophyList.nameKey('chronist').asFinder).data,
        'Chronicler',
      );
      expect(
        tester.widget<Text>(TrophyList.subKey('chronist').asFinder).data,
        '10 historical facts collected',
      );
    });

    testWidgets('alle 36 Karten sind da', (tester) async {
      await pumpList(tester);

      for (final Trophy trophy in trophyCatalog) {
        expect(
          TrophyList.cardKey(trophy.key).asFinder,
          findsOneWidget,
          reason: trophy.key,
        );
      }
    });

    testWidgets('gold/silber/bronze zeigen ihre jeweilige Stufe', (
      tester,
    ) async {
      // `experte` (mile) ist Gold, `top3_weekly` (rank) ist Silber, `koop_first`
      // (group, kein threshold) ist immer Bronze.
      await pumpList(
        tester,
        unlockedKeys: <String>{'experte', 'top3_weekly', 'koop_first'},
      );

      expect(
        tester.widget<Text>(TrophyList.tierLabelKey('experte').asFinder).data,
        'GOLD',
      );
      expect(
        tester
            .widget<Text>(TrophyList.tierLabelKey('top3_weekly').asFinder)
            .data,
        'SILVER',
      );
      expect(
        tester
            .widget<Text>(TrophyList.tierLabelKey('koop_first').asFinder)
            .data,
        'BRONZE',
      );
    });
  });

  group('Reihenfolge', () {
    testWidgets('offene Karten stehen vor gesperrten, in Katalogreihenfolge', (
      tester,
    ) async {
      // `lacher` steht in der Quelle vor `grand_tour`, das wiederum vor
      // `legende` steht. Beide sind hier absichtlich in umgekehrter
      // Reihenfolge freigeschaltet, damit die Zusicherung nicht zufällig mit
      // der Freischalt-Reihenfolge übereinstimmt.
      await pumpList(
        tester,
        unlockedKeys: <String>{'legende', 'grand_tour', 'lacher'},
      );

      final double leftLacher = tester
          .getRect(TrophyList.cardKey('lacher').asFinder)
          .left;
      final double leftGrandTour = tester
          .getRect(TrophyList.cardKey('grand_tour').asFinder)
          .left;
      final double leftLegende = tester
          .getRect(TrophyList.cardKey('legende').asFinder)
          .left;
      final double leftChronist = tester
          .getRect(TrophyList.cardKey('chronist').asFinder)
          .left;

      expect(leftLacher, lessThan(leftGrandTour));
      expect(leftGrandTour, lessThan(leftLegende));
      // `chronist` ist gesperrt und muss hinter allen drei offenen liegen,
      // obwohl er in der Quelle als erster Eintrag vor allen dreien steht.
      expect(leftLegende, lessThan(leftChronist));
    });
  });

  group('Stufenfarben, screen-profil.jsx:218 (tierC)', () {
    // Eine eigene Gruppe, weil eine falsche Stufenfarbe sonst durch keinen
    // anderen Test hier auffällt: die übrigen Zusicherungen prüfen die
    // Stufen-**Zuordnung** (welches Wort steht da: GOLD/SILVER/BRONZE), nicht
    // den Farbwert dahinter. Gemessen bei einer Mutationsprobe: die
    // Silberfarbe auf ein beliebiges Grün geändert ließ jeden anderen Test in
    // dieser Datei grün. Die Werte stehen als Literal und nicht als
    // `trophyTierColors[...]`, aus demselben Grund wie in
    // `puzzle_sheet_test.dart`: eine Zusicherung gegen die Konstante prüft
    // nur, ob sie sich selbst gleicht.
    testWidgets('Gold ist #F5C518', (tester) async {
      await pumpList(tester, unlockedKeys: <String>{'experte'});
      expect(
        tester
            .widget<Text>(TrophyList.tierLabelKey('experte').asFinder)
            .style!
            .color,
        const Color(0xFFF5C518),
      );
    });

    testWidgets('Silber ist #B0BEC5', (tester) async {
      await pumpList(tester, unlockedKeys: <String>{'top3_weekly'});
      expect(
        tester
            .widget<Text>(TrophyList.tierLabelKey('top3_weekly').asFinder)
            .style!
            .color,
        const Color(0xFFB0BEC5),
      );
    });

    testWidgets('Bronze ist #CD7F32', (tester) async {
      await pumpList(tester, unlockedKeys: <String>{'koop_first'});
      expect(
        tester
            .widget<Text>(TrophyList.tierLabelKey('koop_first').asFinder)
            .style!
            .color,
        const Color(0xFFCD7F32),
      );
    });
  });

  group('Gesperrt: Farben und Deckkraft', () {
    testWidgets('eine gesperrte Karte hat 40% Deckkraft', (tester) async {
      await pumpList(tester);

      final Opacity opacity = tester.widget<Opacity>(
        find.ancestor(
          of: TrophyList.cardKey('chronist').asFinder,
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('eine offene Karte trägt keine Deckkraft-Hülle', (
      tester,
    ) async {
      await pumpList(tester, unlockedKeys: <String>{'chronist'});

      expect(
        find.ancestor(
          of: TrophyList.cardKey('chronist').asFinder,
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'eine gesperrte Karte trägt genau die Graustufe 0.6, gegen den Wert '
      'der Quelle geprüft und nicht gegen die Konstante',
      (tester) async {
        // Muster 18 aus „Wie Tests hier blind werden": eine Zusicherung
        // gegen `TrophyList.lockedGrayscaleAmount` würde jede Änderung
        // dieser Konstante mitziehen und nichts mehr festnageln. Hier steht
        // deshalb der Literalwert aus `screen-profil.jsx:451`
        // (`grayscale(0.6)`), nicht der Name aus dem Prüfgegenstand.
        //
        // **Warum eine Strukturprüfung und kein Bildpunkt.** Der Bildpunkt-
        // Vergleich in der Gruppe „Die gezeichnete Fläche" unten vergleicht
        // eine offene (bunte) mit einer gesperrten (ohnehin fast
        // farbneutralen) Karte; der Abstand zwischen beiden ist so groß,
        // dass ein auf 0 gesetzter Graustufenbetrag ihn nicht unterschreitet
        // und die Zusicherung trotzdem grün bleibt, gemessen bei einer
        // eigenen Mutationsprobe. `ColorFilter` hat eine echte
        // Werteagleichheit (`operator ==` vergleicht die Matrix), eine
        // Strukturprüfung trifft die Änderung deshalb direkt.
        await pumpList(tester);

        final ColorFiltered filtered = tester.widget<ColorFiltered>(
          find.ancestor(
            of: TrophyList.cardKey('chronist').asFinder,
            matching: find.byType(ColorFiltered),
          ),
        );

        expect(
          filtered.colorFilter,
          ColorFilter.matrix(<double>[
            0.2126 + 0.7874 * 0.4, 0.7152 - 0.7152 * 0.4, //
            0.0722 - 0.0722 * 0.4, 0, 0,
            0.2126 - 0.2126 * 0.4, 0.7152 + 0.2848 * 0.4,
            0.0722 - 0.0722 * 0.4, 0, 0,
            0.2126 - 0.2126 * 0.4, 0.7152 - 0.7152 * 0.4,
            0.0722 + 0.9278 * 0.4, 0, 0,
            0, 0, 0, 1, 0,
          ]),
        );
      },
    );

    testWidgets('eine offene Karte trägt keine ColorFiltered-Hülle', (
      tester,
    ) async {
      await pumpList(tester, unlockedKeys: <String>{'chronist'});

      expect(
        find.ancestor(
          of: TrophyList.cardKey('chronist').asFinder,
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
    });
  });

  group('Die gezeichnete Fläche: Muster 4 aus „Wie Tests hier blind werden"', () {
    // Ein reiner Struktur- oder Maßtest sähe eine entfernte Graustufe nicht:
    // `ColorFiltered` ändert kein einziges Rechteck. Deshalb wird hier
    // tatsächlich gezeichnet und es werden Bildpunkte verglichen, wie in
    // `puzzle_sheet_test.dart`.
    Future<(Rect icon, ByteData pixels, int width)> paintIcon(
      WidgetTester tester, {
      required String trophyKey,
      required Set<String> unlockedKeys,
    }) async {
      const Key boundaryKey = Key('trophy-list-paint-boundary');
      tester.view
        ..physicalSize = const Size(390, 844) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FactTheme.light(),
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: TrophyList(unlockedKeys: unlockedKeys),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      expect(boundary.localToGlobal(Offset.zero), Offset.zero);

      late ByteData pixels;
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage();
        pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();
      });

      return (
        tester.getRect(TrophyList.iconKey(trophyKey).asFinder),
        pixels,
        boundary.size.width.round(),
      );
    }

    ({int r, int g, int b}) pixelAt(
      ByteData pixels,
      int width,
      double x,
      double y,
    ) {
      final int index = ((y.round() * width) + x.round()) * 4;
      return (
        r: pixels.getUint8(index),
        g: pixels.getUint8(index + 1),
        b: pixels.getUint8(index + 2),
      );
    }

    testWidgets(
      'eine gesperrte Trophäe ist sichtbar entsättigt gegenüber derselben offenen',
      (tester) async {
        // `experte` ist Gold (`#F5C518`), ein stark gesättigter Ton: der
        // Rotkanal liegt weit über dem Blaukanal. Nach `grayscale(0.6)`
        // rücken alle drei Kanäle zusammen.
        final (
          Rect iconLocked,
          ByteData pixelsLocked,
          int widthLocked,
        ) = await paintIcon(
          tester,
          trophyKey: 'experte',
          unlockedKeys: const <String>{},
        );
        final ({int r, int g, int b}) locked = pixelAt(
          pixelsLocked,
          widthLocked,
          iconLocked.center.dx,
          iconLocked.center.dy,
        );

        final (
          Rect iconOpen,
          ByteData pixelsOpen,
          int widthOpen,
        ) = await paintIcon(
          tester,
          trophyKey: 'experte',
          unlockedKeys: const <String>{'experte'},
        );
        final ({int r, int g, int b}) open = pixelAt(
          pixelsOpen,
          widthOpen,
          iconOpen.center.dx,
          iconOpen.center.dy,
        );

        final int spreadLocked = locked.r - locked.b;
        final int spreadOpen = open.r - open.b;

        expect(
          spreadOpen,
          greaterThan(spreadLocked + 10),
          reason:
              'offen: $open, gesperrt: $locked – die gesperrte Fläche sollte '
              'deutlich entsättigter sein',
        );
      },
    );

    testWidgets('nur die offene Karte zeigt den farbigen Balken oben', (
      tester,
    ) async {
      final (
        Rect iconLocked,
        ByteData pixelsLocked,
        int widthLocked,
      ) = await paintIcon(
        tester,
        trophyKey: 'experte',
        unlockedKeys: const <String>{},
      );
      // Der Balken sitzt an der Kartenoberkante, deutlich über dem Symbol.
      // 12 (Kartenpadding oben) Pixel über der Karte reicht als Abtastpunkt.
      final Rect cardLocked = tester.getRect(
        TrophyList.cardKey('experte').asFinder,
      );
      final ({int r, int g, int b}) barLocked = pixelAt(
        pixelsLocked,
        widthLocked,
        cardLocked.center.dx,
        cardLocked.top + 1,
      );

      final (
        Rect iconOpen,
        ByteData pixelsOpen,
        int widthOpen,
      ) = await paintIcon(
        tester,
        trophyKey: 'experte',
        unlockedKeys: const <String>{'experte'},
      );
      final Rect cardOpen = tester.getRect(
        TrophyList.cardKey('experte').asFinder,
      );
      final ({int r, int g, int b}) barOpen = pixelAt(
        pixelsOpen,
        widthOpen,
        cardOpen.center.dx,
        cardOpen.top + 1,
      );

      // Gold ist gesättigt Gelb: hoher Rot- und Grünwert, niedriger Blauwert.
      // An der Balkenzeile muss das im offenen Fall deutlich zutreffen und im
      // gesperrten (entsättigt, grau) nicht.
      expect(
        barOpen.r - barOpen.b,
        greaterThan(barLocked.r - barLocked.b + 20),
      );
    });
  });

  group('Kein Einstieg', () {
    test('niemand außerhalb von progression baut diese Liste', () {
      // Dieselbe Textsuche wie in `puzzle_sheet_test.dart`, mit denselben
      // vier Grenzen: sie ist eine Textabschrift und fällt schon bei einer
      // Umbenennung; sie sieht keinen Einstieg über eine Zwischenschicht wie
      // `Widget Function()`; das Prüfskript `check_architecture.dart` hilft
      // hier nicht, weil ein Konstruktoraufruf kein Import ist.
      final Iterable<File> dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'));

      final List<String> constructors = <String>[];
      for (final File file in dartFiles) {
        final String source = file.readAsStringSync();
        final String path = file.path.replaceAll(r'\', '/');

        if (path.endsWith(
              'features/progression/presentation/widgets/trophy_list.dart',
            ) ||
            path.contains('features/progression/application/') ||
            path.contains('features/progression/domain/')) {
          continue;
        }

        if (_constructorCall.hasMatch(source)) {
          constructors.add(path);
        }
      }

      expect(constructors, isEmpty);
    });
  });
}

/// Ein Aufruf des Konstruktors, `TrophyList(` mit beliebigem Zwischenraum.
final RegExp _constructorCall = RegExp(r'TrophyList\s*\(');

extension on Key {
  Finder get asFinder => find.byKey(this);
}
