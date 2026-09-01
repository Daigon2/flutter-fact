import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/core/widgets/primary_button.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/challenges/presentation/challenge_genre.dart';
import 'package:fact_app/features/challenges/presentation/pages/challenges_page.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_bubble.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_genre_filter.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_player_badge.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_setup_view.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_start_point_view.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Der Schnitzeljagd-Assistent, `02_Frontend/app/screen-challenge.jsx:1584`.
///
/// ## Der Rahmen bildet die Kette der App nach
///
/// `MaterialApp` mit `FactTheme`, darunter ein `Scaffold`, wie in
/// `fact_page_test.dart`. Ohne beides erben die Texte Flutters
/// `_errorTextStyle` statt `theme.textTheme.bodyMedium`, und jede Maßzahl wäre
/// belegt, grün und trotzdem nicht das, was der Nutzer sieht (E-40).
void main() {
  setUpAll(loadAppFonts);

  // Ein `tap()`, das danebengeht, schreibt sonst nur eine Warnung und lässt
  // den Test grün weiterlaufen.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  /// Das Rahmenmaß der PWA, `chrome.jsx:134-135`.
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    AppLanguage language = AppLanguage.de,
    List<Fact> facts = const <Fact>[],
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
          // **Pflicht, kein Beiwerk.** Ohne Override liefert
          // `unavailableFactRepository` eine `FactBackendUnreachable`, und
          // Riverpod wiederholt einen gescheiterten Provider zehnmal über rund
          // 38 Sekunden. Der erste dieser Zeitgeber überlebt den Widget-Baum
          // und der Test endet mit „A Timer is still pending". Derselbe Grund,
          // aus dem `map_page_test.dart` `factOverlayProvider` überschreibt.
          allFactsProvider.overrideWith((ref) async => facts),
        ],
        child: MaterialApp(
          theme: FactTheme.light(),
          home: const Scaffold(body: ChallengesPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppStrings stringsOf([AppLanguage language = AppLanguage.de]) =>
      AppStrings.of(language);

  /// Tippt und scrollt vorher hin.
  ///
  /// Bei Systemschrift 2.0 rutschen die unteren Karten aus dem Sichtfeld, und
  /// `tap()` warnt dort nur, statt zu scheitern.
  Future<void> tapAt(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> goToStepTwo(WidgetTester tester) =>
      tapAt(tester, find.byKey(ChallengeSetupView.soloKey));

  /// Bedient den Assistenten bis zum Startpunkt-Picker.
  Future<void> goToPicker(WidgetTester tester) async {
    await goToStepTwo(tester);
    await tapAt(
      tester,
      find.byKey(ChallengeSetupView.difficultyKey(PuzzleDifficulty.leicht)),
    );
    await tapAt(
      tester,
      find.byKey(ChallengeSetupView.durationKey(HuntDuration.thirty)),
    );
    await tapAt(tester, find.byKey(ChallengeSetupView.startKey));
  }

  group('Schritt 1', () {
    testWidgets('zeigt den Hero, beide Abzeichen und den Beitritt', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      // `:1686-1690`, der dunkle Kasten.
      expect(
        find.text(stringsOf().text('challenge.hero.city').toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(stringsOf().text('challenge.hero.desc')),
        findsOneWidget,
      );
      // `:1696-1701`, die vier Pillen.
      for (final String key in <String>[
        'challenge.pills.routes',
        'challenge.pills.stops',
        'challenge.pills.modes',
        'challenge.pills.photo',
      ]) {
        expect(find.text(stringsOf().text(key)), findsOneWidget, reason: key);
      }
      // `:1719-1721`, die beiden Kacheln mit ihren gezeichneten Abzeichen.
      expect(find.byType(ChallengePlayerBadge), findsNWidgets(2));
      expect(
        find.text(stringsOf().text('challenge.select.solo')),
        findsOneWidget,
      );
      expect(
        find.text(stringsOf().text('challenge.select.group')),
        findsOneWidget,
      );
      // `:1749`.
      expect(find.text(stringsOf().text('group.join.cta')), findsOneWidget);
    });

    testWidgets('der Zähler steht auf 1/3 und hat keinen Zurück-Knopf', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      // `stepTotal = 3` auch im Solo-Pfad, `:1631-1634`.
      expect(find.byKey(ChallengeBubble.counterKey), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      // `showBack={step > 1}`, `:1664`.
      expect(find.byKey(ChallengeBubble.backButtonKey), findsNothing);
    });

    testWidgets('die Unterzeile fragt nach der Gesellschaft', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      // `subForStep()`, `:1645`.
      expect(
        find.text(stringsOf().text('challenge.step.friends')),
        findsOneWidget,
      );
    });

    testWidgets('nichts vom Solo-Setup ist schon sichtbar', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(find.byKey(ChallengeSetupView.startKey), findsNothing);
      expect(
        find.byKey(ChallengeSetupView.difficultyKey(PuzzleDifficulty.leicht)),
        findsNothing,
      );
      expect(find.byType(ChallengeGenreFilter), findsNothing);
    });
  });

  group('Schritt 2, Solo', () {
    testWidgets('Solo führt zu Schwierigkeit, Dauer, Route und Themen', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      expect(find.text('2/3'), findsOneWidget);
      expect(
        find.text(stringsOf().text('challenge.step.time')),
        findsOneWidget,
      );
      expect(
        find.text(stringsOf().text('challenge.difficulty').toUpperCase()),
        findsOneWidget,
      );
      for (final PuzzleDifficulty difficulty in PuzzleDifficulty.values) {
        expect(
          find.byKey(ChallengeSetupView.difficultyKey(difficulty)),
          findsOneWidget,
          reason: difficulty.code,
        );
      }
      for (final HuntDuration duration in HuntDuration.values) {
        expect(
          find.byKey(ChallengeSetupView.durationKey(duration)),
          findsOneWidget,
          reason: '${duration.minutes}',
        );
      }
      expect(find.byKey(ChallengeSetupView.randomRouteKey), findsOneWidget);
      expect(find.byType(ChallengeGenreFilter), findsOneWidget);
    });

    testWidgets('die Karten zeigen die langen Beschreibungen der Quelle', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      // `:1851-1853`. Die kürzere `challenge.easyDesc` gehört zum alten
      // Demo-Pfad und darf hier gerade nicht stehen.
      expect(
        find.text(stringsOf().text('challenge.setup.easyDesc')),
        findsOneWidget,
      );
      expect(find.text(stringsOf().text('challenge.easyDesc')), findsNothing);
    });

    testWidgets('jede Dauer nennt ihre Stationszahl', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      // `:1910-1913`. Die erwarteten Zahlen stehen hier ausgeschrieben, damit
      // die Zusicherung nicht über dieselbe Aufzählung läuft wie der Code.
      final String suffix = stringsOf()
          .text('challenge.setup.stopsSuffix')
          .toUpperCase();
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('5 $suffix'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('7 $suffix'), findsOneWidget);
      expect(find.text('90 min'), findsOneWidget);
      expect(find.text('9 $suffix'), findsOneWidget);
    });

    testWidgets('der Zurück-Knopf führt zurück und setzt die Auswahl zurück', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);
      await tapAt(
        tester,
        find.byKey(ChallengeSetupView.difficultyKey(PuzzleDifficulty.leicht)),
      );
      await tapAt(
        tester,
        find.byKey(ChallengeSetupView.durationKey(HuntDuration.thirty)),
      );
      expect(_startEnabled(tester), isTrue);

      await tapAt(tester, find.byKey(ChallengeBubble.backButtonKey));
      expect(find.text('1/3'), findsOneWidget);

      // `goBack()` löscht `diff` und `duration`, `:1624`. Ohne das stünde der
      // Startknopf beim Wiedereintritt scharf, ohne dass etwas gewählt ist.
      await goToStepTwo(tester);
      expect(_startEnabled(tester), isFalse);
    });
  });

  group('Der Startknopf', () {
    testWidgets('bleibt gesperrt, bis Stufe und Dauer gewählt sind', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);
      expect(_startEnabled(tester), isFalse);

      await tapAt(
        tester,
        find.byKey(ChallengeSetupView.difficultyKey(PuzzleDifficulty.schwer)),
      );
      // `:1615`: **beides** wird verlangt, nicht eines von beiden.
      expect(_startEnabled(tester), isFalse);

      await tapAt(
        tester,
        find.byKey(ChallengeSetupView.durationKey(HuntDuration.ninety)),
      );
      expect(_startEnabled(tester), isTrue);
    });

    testWidgets('ist im gesperrten Zustand halb durchsichtig', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      // `opacity: (!diff || !duration) ? 0.4 : 1`, `:1982`.
      expect(_startOpacity(tester), 0.4);

      await tapAt(
        tester,
        find.byKey(ChallengeSetupView.difficultyKey(PuzzleDifficulty.leicht)),
      );
      await tapAt(
        tester,
        find.byKey(ChallengeSetupView.durationKey(HuntDuration.sixty)),
      );
      expect(_startOpacity(tester), 1);
    });

    testWidgets('führt in den Startpunkt-Picker', (WidgetTester tester) async {
      // `setView('hotspot')`, `:4325`. Seit Schritt 35 tut der Knopf etwas;
      // der Teil von E-47, der ihn betraf, ist damit erledigt.
      await pump(tester);
      await goToPicker(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(HuntStartPointView), findsOneWidget);
      expect(find.byKey(ChallengeSetupView.startKey), findsNothing);
      expect(find.text('SCHRITT 3 VON 3'), findsOneWidget);
    });

    testWidgets('Gruppe und Beitritt führen heute nirgendwohin', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await tapAt(tester, find.byKey(ChallengeSetupView.groupKey));
      expect(find.text('1/3'), findsOneWidget);

      await tapAt(tester, find.byKey(ChallengeSetupView.joinKey));
      expect(find.text('1/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Themen-Filter', () {
    testWidgets('zeigt alle acht Themen mit den Beschriftungen der Tour', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      expect(ChallengeGenre.values, hasLength(8));
      for (final ChallengeGenre genre in ChallengeGenre.values) {
        expect(
          find.byKey(ChallengeGenreFilter.tileKey(genre)),
          findsOneWidget,
          reason: genre.code,
        );
        expect(
          find.text(stringsOf().text(genre.labelKey)),
          findsOneWidget,
          reason: genre.labelKey,
        );
      }
    });

    testWidgets('ohne Auswahl gibt es weder Hinweis noch Alle-Knopf', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      // `allClear`, `:1540`.
      expect(find.byKey(ChallengeGenreFilter.hintKey), findsNothing);
      expect(find.byKey(ChallengeGenreFilter.clearKey), findsNothing);
    });

    testWidgets('der Hinweis unterscheidet Einzahl und Mehrzahl', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      await tapAt(
        tester,
        find.byKey(ChallengeGenreFilter.tileKey(ChallengeGenre.history)),
      );
      // `:1576`: `${n} Thema${n > 1 ? 'en' : ''} ausgewählt …`.
      expect(
        find.text('1 Thema ausgewählt — weniger Fakten verfügbar'),
        findsOneWidget,
      );

      await tapAt(
        tester,
        find.byKey(ChallengeGenreFilter.tileKey(ChallengeGenre.myth)),
      );
      expect(
        find.text('2 Themen ausgewählt — weniger Fakten verfügbar'),
        findsOneWidget,
      );
    });

    testWidgets('ein zweiter Tipp nimmt das Thema wieder heraus', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      final Finder tile = find.byKey(
        ChallengeGenreFilter.tileKey(ChallengeGenre.nature),
      );
      await tapAt(tester, tile);
      await tapAt(tester, tile);

      expect(find.byKey(ChallengeGenreFilter.hintKey), findsNothing);
    });

    testWidgets('der Alle-Knopf leert die Auswahl', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await goToStepTwo(tester);

      await tapAt(
        tester,
        find.byKey(ChallengeGenreFilter.tileKey(ChallengeGenre.arts)),
      );
      await tapAt(
        tester,
        find.byKey(ChallengeGenreFilter.tileKey(ChallengeGenre.science)),
      );
      await tapAt(tester, find.byKey(ChallengeGenreFilter.clearKey));

      expect(find.byKey(ChallengeGenreFilter.hintKey), findsNothing);
      expect(find.byKey(ChallengeGenreFilter.clearKey), findsNothing);
    });
  });

  group('Englisch', () {
    testWidgets('der Assistent spricht die eingestellte Sprache', (
      WidgetTester tester,
    ) async {
      await pump(tester, language: AppLanguage.en);

      expect(find.text('Solo or with friends?'), findsOneWidget);
      expect(find.text('Play together with friends'), findsOneWidget);
      expect(find.text('Join with code'), findsOneWidget);
    });

    testWidgets('auch die Beschriftungen aus der Ergänzung', (
      WidgetTester tester,
    ) async {
      await pump(tester, language: AppLanguage.en);
      await goToStepTwo(tester);

      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('5 STOPS'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });
  });

  group('Was nur das Bild zeigt', () {
    // Muster 4 aus „Wie Tests hier blind werden": ein Test, der Rechtecke
    // misst, sieht den Inhalt nicht. In Schritt 27 haben elf Mutationen an der
    // Optik der Marken-Blase die ganze Suite überlebt. Hier steht deshalb
    // dieselbe Bauform: einzelne Bildpunkte, vor allem **gegeneinander**
    // verglichen; absolute Werte nur, wo genau sie die Aussage tragen.
    //
    // Keine Golden-Datei: die wäre plattformabhängig und müsste auf jedem
    // Rechner neu erzeugt werden.

    /// Pumpt die Seite unter einer eigenen Zeichengrenze und liest sie aus.
    ///
    /// `toImage()` **muss** in `tester.runAsync` laufen, sonst hängt es bis
    /// zur Zeitüberschreitung (Muster 19).
    Future<(ByteData pixels, int width)> paintPage(
      WidgetTester tester, {
      bool stepTwo = false,
    }) async {
      const Key boundaryKey = Key('challenge-paint-boundary');
      tester.view
        ..physicalSize = const Size(390 * 3, 844 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languagePreferenceStoreProvider.overrideWithValue(
              InMemoryLanguagePreferenceStore(AppLanguage.de),
            ),
          ],
          child: MaterialApp(
            theme: FactTheme.light(),
            home: const Scaffold(
              body: RepaintBoundary(key: boundaryKey, child: ChallengesPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (stepTwo) {
        await goToStepTwo(tester);
      }

      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      // Ohne diese Zeile verschieben sich alle Abtastpunkte lautlos, sobald
      // jemand etwas über die Seite legt: die Bildpunkte sind lokal zur
      // Zeichengrenze, die Rechtecke global.
      expect(boundary.localToGlobal(Offset.zero), Offset.zero);

      late ByteData pixels;
      await tester.runAsync(() async {
        // `pixelRatio: 1`, damit ein Bildpunkt einem logischen Pixel
        // entspricht.
        final ui.Image image = await boundary.toImage();
        pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();
      });
      return (pixels, boundary.size.width.round());
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

    /// Die Mitte des [index]-ten von drei Fortschrittsbalken.
    ({int r, int g, int b}) progressSegment(
      WidgetTester tester,
      ByteData pixels,
      int width,
      int index,
    ) {
      final Rect bar = tester.getRect(find.byKey(ChallengeBubble.progressKey));
      return pixelAt(
        pixels,
        width,
        bar.left + bar.width * (index * 2 + 1) / 6,
        // Der Balken ist 3 Pixel hoch und sitzt am unteren Rand des
        // Innenabstands von 14.
        bar.bottom - 1.5,
      );
    }

    testWidgets('der Fortschrittsbalken füllt genau die erledigten Schritte', (
      WidgetTester tester,
    ) async {
      // `:1030-1035`: `background: i < step ? '#FFE066' : rgba(…,0.25)`. Kein
      // Rechteck ändert sich, wenn hier `<=` statt `<` steht.
      final (ByteData pixels, int width) = await paintPage(tester);

      expect(progressSegment(tester, pixels, width, 0), (
        r: 255,
        g: 224,
        b: 102,
      ));
      expect(
        progressSegment(tester, pixels, width, 1).g,
        lessThan(150),
        reason: 'der zweite Balken ist auf Schritt 1 schon voll',
      );
      expect(progressSegment(tester, pixels, width, 2).g, lessThan(150));
    });

    testWidgets('auf Schritt 2 sind zwei von drei Balken voll', (
      WidgetTester tester,
    ) async {
      final (ByteData pixels, int width) = await paintPage(
        tester,
        stepTwo: true,
      );

      expect(progressSegment(tester, pixels, width, 0).g, greaterThan(200));
      expect(progressSegment(tester, pixels, width, 1), (
        r: 255,
        g: 224,
        b: 102,
      ));
      // Der dritte bleibt grau, obwohl der Solo-Pfad hier endet, `:1633`.
      expect(progressSegment(tester, pixels, width, 2).g, lessThan(150));
    });

    testWidgets('der Verlauf der Blase läuft schräg', (
      WidgetTester tester,
    ) async {
      // `linear-gradient(135deg, …)`, `:969`: von links oben nach rechts
      // unten. Ohne den senkrechten Vergleich überlebt ein auf 90 Grad
      // geänderter Winkel.
      final (ByteData pixels, int width) = await paintPage(tester);
      final Rect card = tester
          .getRect(find.byType(ChallengeBubble))
          .deflate(16)
          .translate(0, 8);

      final ({int r, int g, int b}) links = pixelAt(
        pixels,
        width,
        card.left + 4,
        card.center.dy,
      );
      final ({int r, int g, int b}) rechts = pixelAt(
        pixels,
        width,
        card.right - 4,
        card.center.dy,
      );
      expect(rechts.r, greaterThan(links.r + 40), reason: 'waagerecht flach');

      // x = 300 liegt rechts vom Text und links von den Zierkreisen.
      final ({int r, int g, int b}) oben = pixelAt(pixels, width, 300, 11);
      final ({int r, int g, int b}) unten = pixelAt(pixels, width, 300, 106);
      expect(unten.g, greaterThan(oben.g + 15), reason: 'senkrecht flach');
    });

    testWidgets('die Lichtkante liegt auf der obersten Zeile der Blase', (
      WidgetTester tester,
    ) async {
      // `inset 0 1px 0 rgba(255,255,255,0.12)`, `:971`. `BoxShadow` kann kein
      // `inset`, deshalb ist es eine ein Pixel hohe Linie. Entfernt man sie,
      // ändert sich kein einziges Rechteck.
      final (ByteData pixels, int width) = await paintPage(tester);

      final ({int r, int g, int b}) kante = pixelAt(pixels, width, 300, 8);
      final ({int r, int g, int b}) darunter = pixelAt(pixels, width, 300, 9);
      expect(kante.g, greaterThan(darunter.g + 10));
    });

    testWidgets('die beiden Abzeichen sind rot und violett', (
      WidgetTester tester,
    ) async {
      // `:1139` gegen `:1171`. Der Verlauf ist der einzige Farbunterschied,
      // den man ohne die Figur sieht.
      final (ByteData pixels, int width) = await paintPage(tester);
      final List<Rect> badges = tester
          .widgetList(find.byType(ChallengePlayerBadge))
          .map((Widget widget) => tester.getRect(find.byWidget(widget)))
          .toList();
      expect(badges, hasLength(2));

      // Vier Pixel unter der Oberkante, mittig: dort liegt der Verlauf frei.
      final ({int r, int g, int b}) solo = pixelAt(
        pixels,
        width,
        badges.first.left + 32,
        badges.first.top + 8,
      );
      final ({int r, int g, int b}) gruppe = pixelAt(
        pixels,
        width,
        badges.last.left + 32,
        badges.last.top + 8,
      );
      expect(solo.b, lessThan(100));
      expect(solo.r, greaterThan(200));
      expect(gruppe.b, greaterThan(150));
      expect(gruppe.r, lessThan(200));
    });

    /// Ein Punkt im `viewBox` des Abzeichens, umgerechnet in Bildpunkte.
    ///
    /// Die Umrechnung steht in `_BadgePainter`: das Solo-Feld ist 52 mal 60
    /// groß, wird mit dem Faktor 49,92/60 = 0,832 skaliert und sitzt unten
    /// bündig (Ursprung (10,368 | 14,08) in der Kachel), das Gruppenfeld ist
    /// 60 mal 60 und mittig (Ursprung (7,04 | 7,04)). Sie steht hier noch
    /// einmal, weil eine falsche Abtaststelle einen grünen Test über die
    /// falsche Stelle ergibt.
    Offset inBadge(Rect badge, double vx, double vy, {required bool group}) {
      const double skala = 0.832;
      final double x0 = group ? 7.04 : 10.368;
      final double y0 = group ? 7.04 : 14.08;
      return Offset(badge.left + x0 + vx * skala, badge.top + y0 + vy * skala);
    }

    List<Rect> badgeRects(WidgetTester tester) => tester
        .widgetList(find.byType(ChallengePlayerBadge))
        .map((Widget widget) => tester.getRect(find.byWidget(widget)))
        .toList();

    testWidgets('das Solo-Abzeichen zeichnet Gesicht, Mützenpunkt und Arm', (
      WidgetTester tester,
    ) async {
      // Drei Formen aus `:1148`, `:1152` und `:1156`, jede an ihrer eigenen
      // Stelle. Ein Test, der nur den Rumpf abtastet, lässt ein Abzeichen
      // ohne Kopf durchgehen; und weil alle drei Punkte an der Skalierung
      // hängen, fällt mit ihnen auch ein geändertes `figureScale` auf.
      final (ByteData pixels, int width) = await paintPage(tester);
      final Rect solo = badgeRects(tester).first;

      ({int r, int g, int b}) probe(double vx, double vy) {
        final Offset at = inBadge(solo, vx, vy, group: false);
        return pixelAt(pixels, width, at.dx, at.dy);
      }

      // Gesicht, `circle cx="26" cy="14" r="9" fill="#f5c9a0"`. Abgetastet
      // unterhalb der Mütze, die den oberen Teil des Kreises verdeckt.
      expect(probe(26, 20), (r: 245, g: 201, b: 160), reason: 'Gesicht');
      // Der goldene Punkt auf der Mütze,
      // `circle cx="26" cy="10" r="2" fill="#F5C518"`.
      expect(probe(26, 10), (r: 245, g: 197, b: 24), reason: 'Mützenpunkt');
      // Der linke Arm, `rect x="5" y="26" width="9" height="16" fill="#FF6B3D"`.
      expect(probe(9.5, 34), (r: 255, g: 107, b: 61), reason: 'Arm');
    });

    testWidgets('das Gruppen-Abzeichen zeichnet beide Figuren', (
      WidgetTester tester,
    ) async {
      // Das Abzeichen zeigt zwei Personen (`:1180-1192`). Ein Test, der nur
      // einen Rumpf abtastet, lässt die zweite Figur ersatzlos verschwinden.
      final (ByteData pixels, int width) = await paintPage(tester);
      final Rect gruppe = badgeRects(tester).last;

      ({int r, int g, int b}) probe(double vx, double vy) {
        final Offset at = inBadge(gruppe, vx, vy, group: true);
        return pixelAt(pixels, width, at.dx, at.dy);
      }

      // Erste Figur: roter Rumpf `:1183` und dunkle Mütze `:1181`.
      expect(probe(39.6, 37.2), (r: 232, g: 56, b: 13), reason: 'Rumpf 1');
      expect(probe(39.6, 14.4), (r: 26, g: 18, b: 8), reason: 'Mütze 1');
      // Zweite Figur: gelber Rumpf `:1189` und heller Latz `:1192`.
      expect(probe(22.8, 51.6), (r: 245, g: 197, b: 24), reason: 'Rumpf 2');
      expect(probe(20, 39), (r: 255, g: 224, b: 102), reason: 'Latz');
    });

    testWidgets('die Zierkreise der Blase bleiben hauchdünn', (
      WidgetTester tester,
    ) async {
      // `background: 'rgba(255,255,255,0.14)'`, `:978`. Weder Rechteck noch
      // Finder sehen die Deckkraft; auf 0,45 gesetzt fällt es nur am Bild
      // auf. Deshalb der Vergleich mit zwei Nachbarn auf derselben Höhe: der
      // Verlauf läuft dort waagerecht fast linear, ihr Mittel ist also der
      // Untergrund ohne Kreis.
      //
      // Der dritte Kreis liegt bei 78 Prozent Breite und 88 Prozent Höhe der
      // Blase und ist 14 Pixel groß, `:974`.
      final (ByteData pixels, int width) = await paintPage(tester);
      final Rect card = tester
          .getRect(find.byType(ChallengeBubble))
          .deflate(16)
          .translate(0, 8);
      final double mitteX = card.left + card.width * 0.78 + 7;
      final double mitteY = card.top + card.height * 0.88 + 7;

      final ({int r, int g, int b}) kreis = pixelAt(
        pixels,
        width,
        mitteX,
        mitteY,
      );
      final ({int r, int g, int b}) links = pixelAt(
        pixels,
        width,
        mitteX - 17,
        mitteY,
      );
      final ({int r, int g, int b}) rechts = pixelAt(
        pixels,
        width,
        mitteX + 17,
        mitteY,
      );
      final double untergrund = (links.g + rechts.g) / 2;

      expect(
        kreis.g - untergrund,
        greaterThan(10),
        reason: 'kein Zierkreis sichtbar',
      );
      expect(
        kreis.g - untergrund,
        lessThan(45),
        reason: 'der Zierkreis ist viel zu deckend',
      );
    });

    testWidgets('der Schimmer der Blase ist gelb', (WidgetTester tester) async {
      // `radial-gradient(circle, rgba(255,224,102,0.30), transparent 70%)`,
      // `:984`, gesetzt mit `top: -40`, `right: -30`, 140 mal 140, `:982`.
      // Sein Mittelpunkt liegt damit 30 Pixel rechts der rechten Blasenkante
      // minus 70, also innerhalb der Blase.
      //
      // Verglichen wird mit einem Punkt 100 Pixel weiter links auf derselben
      // Höhe. Der Verlauf allein hebt Grün dort um wenige Zähler; der
      // Schimmer hebt es um Dutzende. **Und er hebt Grün stärker als Blau**,
      // sonst wäre er nicht gelb: ein blauer Schimmer dreht genau dieses
      // Verhältnis um.
      final (ByteData pixels, int width) = await paintPage(tester);
      final Rect card = tester
          .getRect(find.byType(ChallengeBubble))
          .deflate(16)
          .translate(0, 8);
      final double mitteX = card.right + 30 - 70;
      final double mitteY = card.top - 40 + 70;

      final ({int r, int g, int b}) schimmer = pixelAt(
        pixels,
        width,
        mitteX,
        mitteY,
      );
      final ({int r, int g, int b}) daneben = pixelAt(
        pixels,
        width,
        mitteX - 100,
        mitteY,
      );

      expect(schimmer.g - daneben.g, greaterThan(40), reason: 'kein Schimmer');
      expect(
        schimmer.g - daneben.g,
        greaterThan(schimmer.b - daneben.b),
        reason: 'der Schimmer ist nicht gelb',
      );
    });
  });

  group('Startpunkt-Picker', () {
    testWidgets('ohne Ortung stehen die drei Münchner Hotspots da', (
      WidgetTester tester,
    ) async {
      // Der Ortungsdienst ist im Test der untätige Standard, also gibt es
      // keine Position: „Hier wo ich bin" entfällt, und die Hotspots stehen in
      // Dateireihenfolge, auf drei geschnitten (`:3012`).
      await pump(tester);
      await goToPicker(tester);

      expect(find.text('Hier wo ich bin'), findsNothing);
      expect(find.text('Marienplatz'), findsOneWidget);
      expect(find.text('Viktualienmarkt'), findsOneWidget);
      expect(find.text('Odeonsplatz'), findsOneWidget);
      // Der vierte Münchner Hotspot fällt weg.
      expect(find.text('Englischer Garten / Chinesischer Turm'), findsNothing);
    });

    testWidgets('„Zurück" führt in den Assistenten und setzt ihn zurück', (
      WidgetTester tester,
    ) async {
      // `onBack={() => setView('setup')}`, `:4444`. Der Assistent wird dabei
      // neu aufgebaut und steht wieder auf Schritt 1, wie in der Quelle.
      await pump(tester);
      await goToPicker(tester);
      await tapAt(tester, find.byKey(HuntStartPointView.backKey));

      expect(find.byType(HuntStartPointView), findsNothing);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('ohne Fakten meldet der Picker und schickt zurück', (
      WidgetTester tester,
    ) async {
      // `:4347-4352`: liefert der Generator nichts, zeigt die Quelle eine
      // kurze Meldung und stellt den Assistenten wieder her.
      await pump(tester);
      await goToPicker(tester);
      await tapAt(tester, find.byKey(HuntStartPointView.startKey));

      expect(find.byKey(ChallengesPage.toastKey), findsOneWidget);
      expect(
        find.text(stringsOf().text('challenge.hotspot.noFacts')),
        findsOneWidget,
      );
      expect(find.byType(HuntStartPointView), findsNothing);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('die Meldung verschwindet nach 2800 Millisekunden', (
      WidgetTester tester,
    ) async {
      // `setTimeout(() => setChalToast(null), 2800)`, `:4166`.
      //
      // **Ohne `pumpAndSettle` nach dem Tipp.** Das würde die Uhr um die
      // Einblendung weiterdrehen, und die 2800 wären danach nicht mehr von
      // diesem Zeitpunkt aus gemessen. Die Zahl steht hier ausgeschrieben und
      // nicht als `ChallengeToast.visibleFor`: eine Zusicherung gegen die
      // Konstante, die sie festnageln soll, prüft nichts (Muster 18).
      await pump(tester);
      await goToPicker(tester);
      await tester.ensureVisible(find.byKey(HuntStartPointView.startKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HuntStartPointView.startKey));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 2799));
      expect(find.byKey(ChallengesPage.toastKey), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byKey(ChallengesPage.toastKey), findsNothing);
    });

    testWidgets('die Meldung sitzt 64 Pixel unter der Oberkante, nicht 300', (
      WidgetTester tester,
    ) async {
      // `top: 64`, `:4410`. Farbe und Einblendezeit prüft
      // `challenge_toast_test.dart` isoliert; die Position ist Sache dieser
      // Seite, die den Toast dort platziert.
      await pump(tester);
      await goToPicker(tester);
      await tapAt(tester, find.byKey(HuntStartPointView.startKey));

      final Rect page = tester.getRect(find.byType(ChallengesPage));
      final Rect toast = tester.getRect(find.byKey(ChallengesPage.toastKey));

      expect(toast.top - page.top, closeTo(64, 0.5));
    });

    testWidgets('mit genug Fakten erscheint keine Meldung', (
      WidgetTester tester,
    ) async {
      // Der Gegenbeweis zur Meldung: derselbe Weg mit einem Bestand, aus dem
      // der Generator eine Jagd bauen kann. Sichtbar passiert danach
      // **nichts**, und das ist kein Versehen: wohin die fertige Jagd geht,
      // ist D-16 und liegt bei Dairen. Diese Zusicherung ist die Stelle, die
      // auffällt, sobald jemand den Empfänger einhängt.
      await pump(tester, facts: _munichFacts());
      await goToPicker(tester);
      await tapAt(tester, find.byKey(HuntStartPointView.startKey));

      expect(find.byKey(ChallengesPage.toastKey), findsNothing);
      expect(find.byType(HuntStartPointView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ein Fakt ohne Stadt landet nicht im Kandidatenpool', (
      WidgetTester tester,
    ) async {
      // `facts.city` darf `NULL` sein, und die Quelle rät dann mit
      // `detectCity` die nächste Pilotstadt (`hunt-generator.jsx:110-121`).
      // Dieses Raten ist E-11 und wird hier nicht nachgebaut: derselbe
      // Bestand ohne Stadt ergibt keine Jagd.
      await pump(tester, facts: _munichFacts(withCity: false));
      await goToPicker(tester);
      await tapAt(tester, find.byKey(HuntStartPointView.startKey));

      expect(find.byKey(ChallengesPage.toastKey), findsOneWidget);
    });

    for (final String spelling in <String>['münchen', 'muenchen', 'MÜNCHEN']) {
      testWidgets(
        'ein Kandidatenpool mit der Schreibweise "$spelling" fällt nicht weg '
        '(E-11)',
        (WidgetTester tester) async {
          // `_factsOfCity` vergleicht über `FactCity.matchesSlug` und nicht
          // über einen reinen Anzeigenamen-Vergleich. Dreht man das zurück,
          // bleibt der Kandidatenpool für jede Schreibweise außer der exakten
          // `München` leer, und der Nutzer sieht nur die Meldung, obwohl
          // Fakten da wären. Dieselben drei Schreibweisen prüft
          // `hunt_hotspot_test.dart` schon für die Hotspots.
          await pump(tester, facts: _munichFacts(citySpelling: spelling));
          await goToPicker(tester);
          await tapAt(tester, find.byKey(HuntStartPointView.startKey));

          expect(find.byKey(ChallengesPage.toastKey), findsNothing);
          expect(find.byType(HuntStartPointView), findsOneWidget);
        },
      );
    }
  });

  group('Maße', () {
    // Muster 1 und 2 aus `REBUILD_STATUS.md`: ein Umbruch ist kein Überlauf,
    // und ein `Stack` beschneidet lautlos. Deshalb wird hier beides geprüft,
    // die Ausnahme **und** die Rechtecke der gezeichneten Absätze.
    for (final Size size in <Size>[
      const Size(390, 844),
      const Size(360, 640),
      const Size(320, 568),
    ]) {
      for (final double scale in <double>[1, 2]) {
        testWidgets(
          'Schritt 1 auf ${size.width.toInt()} bei Schrift $scale läuft nicht '
          'über',
          (WidgetTester tester) async {
            await pump(tester, size: size, textScale: scale);
            expect(tester.takeException(), isNull);
            _expectInsideScreen(tester, size);
          },
        );

        testWidgets(
          'Schritt 2 auf ${size.width.toInt()} bei Schrift $scale läuft nicht '
          'über',
          (WidgetTester tester) async {
            await pump(tester, size: size, textScale: scale);
            await goToStepTwo(tester);
            expect(tester.takeException(), isNull);
            _expectInsideScreen(tester, size);
          },
        );
      }
    }
  });
}

/// Ist der Startknopf bedienbar?
bool _startEnabled(WidgetTester tester) {
  final PrimaryButton button = tester.widget<PrimaryButton>(
    find.byKey(ChallengeSetupView.startKey),
  );
  return button.onPressed != null;
}

double _startOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.ancestor(
          of: find.byKey(ChallengeSetupView.startKey),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;
}

/// Kein gezeichneter Absatz ragt waagerecht aus dem Bildschirm.
///
/// Senkrecht darf er das, der Bildschirm scrollt. Waagerecht nicht: dort gibt
/// es keinen Ausweg, und genau dort schneidet ein `Stack` lautlos ab.
void _expectInsideScreen(WidgetTester tester, Size size) {
  void walk(RenderObject object) {
    if (object is RenderParagraph) {
      final Offset topLeft = object.localToGlobal(Offset.zero);
      expect(
        topLeft.dx,
        greaterThanOrEqualTo(-0.5),
        reason: 'links draußen: "${object.text.toPlainText()}"',
      );
      expect(
        topLeft.dx + object.size.width,
        lessThanOrEqualTo(size.width + 0.5),
        reason: 'rechts draußen: "${object.text.toPlainText()}"',
      );
    }
    object.visitChildren(walk);
  }

  walk(tester.renderObject(find.byType(ChallengesPage)));
}

/// Ein Bestand, aus dem der Generator eine Jagd über fünf Stationen bauen kann.
///
/// Fünf mal fünf Fakten im Abstand von 300 Metern um den Marienplatz, also
/// diagonal 424 und damit fast genau der bevorzugte Abstand des Generators
/// (`hunt-generator.jsx:126`). Dieselbe Anlage wie in
/// `hunt_route_generator_test.dart`.
List<Fact> _munichFacts({
  bool withCity = true,
  String citySpelling = 'München',
}) {
  const double metersPerDegreeLatitude = 2 * 3.141592653589793 * 6371000 / 360;
  final List<Fact> facts = <Fact>[];
  int id = 1;
  for (int row = -2; row <= 2; row++) {
    for (int column = -2; column <= 2; column++) {
      facts.add(
        Fact(
          id: FactId(id),
          content: FactText(title: 'Fakt $id'),
          city: withCity ? FactCity(citySpelling) : null,
          coordinates: FactCoordinates(
            latitude: 48.1374 + row * 300 / metersPerDegreeLatitude,
            longitude:
                11.5755 + column * 300 / (metersPerDegreeLatitude * 0.6675),
          ),
          puzzles: const <FactPuzzle>[
            FactPuzzle(
              question: 'Wie viele Löwen bewachen das Tor?',
              type: 'inschrift',
              confidence: 'curated',
            ),
          ],
        ),
      );
      id++;
    }
  }
  return facts;
}
