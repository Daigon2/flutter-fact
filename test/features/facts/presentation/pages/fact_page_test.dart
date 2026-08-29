import 'dart:async';

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_media.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/features/facts/presentation/fact_category_look.dart';
import 'package:fact_app/features/facts/presentation/fact_detail_palette.dart';
import 'package:fact_app/features/facts/presentation/pages/fact_page.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../support/app_fonts.dart';

/// Die Fakt-Akte, `02_Frontend/app/screen-fact.jsx`.
///
/// ## Der Rahmen bildet die Kette der App nach
///
/// `MaterialApp` mit `FactTheme`, darunter ein `Scaffold`, und das ist Teil
/// des Prüfgegenstands (E-40): ohne beides erben die Texte Flutters
/// `_errorTextStyle` statt `theme.textTheme.bodyMedium`, und jede Maßzahl wäre
/// belegt, grün und trotzdem nicht das, was der Nutzer sieht. In der App liegt
/// das `Scaffold` in `app/shell/app_shell.dart`.
///
/// ## Der Provider wird überschrieben und nicht werfen gelassen
///
/// `factByIdProvider` ist ein `FutureProvider`, und Riverpod 3 wiederholt
/// einen Fehlschlag zehnmal über rund 38 Sekunden. Der erste dieser Zeitgeber
/// überlebt den Widget-Baum, der Test endete dann mit „A Timer is still
/// pending". Deshalb liefert der Override hier immer ein fertiges Ergebnis.
void main() {
  setUpAll(loadAppFonts);

  // Ein `tap()`, das danebengeht, schreibt sonst nur eine Warnung und lässt
  // den Test grün weiterlaufen. Genau so hat die Skalierungsschleife lange
  // nur die eingeklappte Akte vermessen. Hier ist der Fehlgriff ein Fehler.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  /// Das Rahmenmaß der PWA, `chrome.jsx:134-135`.
  void useSurface(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  void useTextScale(WidgetTester tester, double scale) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// Eine Systemleiste wie auf einem echten Gerät.
  ///
  /// Ohne sie hat der Testrahmen gar keine, und dass etwas unter der Uhr
  /// liegt, fiele nie auf.
  void useStatusBar(WidgetTester tester, {double top = 47}) {
    tester.view.padding = FakeViewPadding(
      top: top * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.reset);
  }

  const FactId factId = FactId(1);

  Fact factFixture({
    String title = 'Die Glyptothek',
    // `null` wie in der Datenbank erlaubt: `facts.nr` ist nullbar. Die
    // Aktennummer fällt dann auf die Kennung zurück, `:367`.
    String? number,
    String? body = 'Die Aegineten haetten eigentlich Napoleon gehoert.[1]',
    String? bodyExtra,
    String? bodyBackground,
    String? bodyToday,
    String category = 'Architektur',
    String? place = 'Glyptothek · Koenigsplatz',
    String? source = 'Wikipedia · Stadtarchiv Muenchen',
    String? caption,
    FactCoordinates? coordinates,
    List<String> heroColors = const <String>['#2C1810', '#0E0A06'],
    FactMedia? media,
  }) {
    return Fact(
      id: factId,
      number: number,
      content: FactText(
        title: title,
        body: body,
        bodyExtra: bodyExtra,
        bodyBackground: bodyBackground,
        bodyToday: bodyToday,
        place: place,
        category: category,
        source: source,
        caption: caption,
      ),
      coordinates: coordinates,
      heroColors: heroColors,
      media: media,
    );
  }

  /// Baut die Seite in einem Router, der dem echten Baum entspricht: die Akte
  /// liegt **unter** `/map`, damit `context.pop()` ein Ziel hat.
  Future<GoRouter> pumpFact(
    WidgetTester tester, {
    Fact? fact,
    bool loading = false,
    DevicePosition? userPosition,
    Size size = const Size(390, 844),
    AppLanguage language = AppLanguage.de,
    bool settle = true,
  }) async {
    useSurface(tester, size: size);
    final GoRouter router = GoRouter(
      initialLocation: '/map/fact/1',
      routes: <RouteBase>[
        GoRoute(
          path: '/map',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('KARTE'))),
          routes: <RouteBase>[
            GoRoute(
              path: 'fact/:factId',
              builder: (BuildContext context, GoRouterState state) => Scaffold(
                body: FactPage(factId: factId, userPosition: userPosition),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
          factByIdProvider(factId).overrideWith(
            (Ref ref) => loading ? Completer<Fact?>().future : fact,
          ),
        ],
        child: MaterialApp.router(
          theme: FactTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    // Der Ladekreis dreht sich endlos, `pumpAndSettle` käme dort nie zur Ruhe.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return router;
  }

  AppStrings stringsOf([AppLanguage language = AppLanguage.de]) =>
      AppStrings.of(language);

  Finder inBody(Finder matching) =>
      find.descendant(of: find.byKey(FactPage.bodyKey), matching: matching);

  /// Klappt die Akte auf.
  ///
  /// Der Knopf rutscht mit wachsender Systemschrift unter das Sichtfeld, und
  /// `tap()` warnt dann nur in die Ausgabe statt zu scheitern. Deshalb erst
  /// scrollen, dann tippen.
  Future<void> tapShowMore(WidgetTester tester) async {
    final Finder finder = find.text(stringsOf().text('fact.showMore'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Alle gezeichneten Absätze der Seite mit ihrem Rechteck.
  ///
  /// Über den Renderbaum und nicht über einen Finder: `SelectableText` und
  /// `EditableText` tauchen in `find.byType(RichText)` gar nicht auf, und wer
  /// Texte über Finder einsammelt, übersieht sie (E-40, zweiter Fund).
  ///
  /// Der Durchlauf beginnt an der Seite und nicht an der Wurzel: der Navigator
  /// hält die Karte darunter im Overlay, deren Absätze sind nicht vermessen,
  /// und `size` würde dort mit "RenderBox was not laid out" scheitern.
  List<(RenderParagraph, Rect)> paragraphs(WidgetTester tester) {
    final List<(RenderParagraph, Rect)> found = <(RenderParagraph, Rect)>[];
    void visit(RenderObject object) {
      if (object is RenderParagraph && object.hasSize) {
        found.add((object, object.localToGlobal(Offset.zero) & object.size));
      }
      object.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(FactPage)));
    return found;
  }

  group('Der Lesekern steht', () {
    testWidgets('Titel, Kategorie, Ort und Fakttext erscheinen', (
      tester,
    ) async {
      await pumpFact(tester, fact: factFixture());

      expect(find.text('Die Glyptothek'), findsOneWidget);
      // `t('cat.' + catKey)`, `:365`. "Architektur" wird auf `arch` abgebildet.
      expect(find.text(stringsOf().text('cat.arch')), findsOneWidget);
      expect(find.text('Glyptothek · Koenigsplatz'), findsWidgets);
      expect(inBody(find.textContaining('Napoleon gehoert.')), findsOneWidget);
    });

    testWidgets('das Kategorie-Zeichen und seine Farbe kommen vom Fakt', (
      tester,
    ) async {
      // Gegenprobe zu einer fest verdrahteten Kategorie: "Natur" ist grün mit
      // Blatt, "Architektur" blau mit Turm.
      await pumpFact(tester, fact: factFixture(category: 'Natur'));

      expect(find.text('🌿'), findsOneWidget);
      final Text label = tester.widget<Text>(
        find.text(stringsOf().text('cat.nat')),
      );
      expect(label.style!.color, factCategoryLookOf('Natur').color);
    });

    testWidgets('der Hero trägt die Hero-Farben des Fakts', (tester) async {
      await pumpFact(
        tester,
        fact: factFixture(heroColors: const <String>['#4A3728', '#1E160E']),
      );

      final Iterable<DecoratedBox> boxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(FactPage.heroKey),
              matching: find.byType(DecoratedBox),
            ),
          )
          .where((DecoratedBox box) {
            final BoxDecoration decoration = box.decoration as BoxDecoration;
            final Gradient? gradient = decoration.gradient;
            return gradient is LinearGradient &&
                gradient.colors.length == 2 &&
                gradient.colors.first.toARGB32() == 0xFF4A3728;
          });

      expect(boxes, hasLength(1));
      final LinearGradient gradient =
          ((boxes.single.decoration as BoxDecoration).gradient)!
              as LinearGradient;
      expect(gradient.colors.last.toARGB32(), 0xFF1E160E);
    });

    testWidgets('ein unbrauchbarer Hero-Wert fällt auf den Datenbankwert', (
      tester,
    ) async {
      // `hero text[] default array['#2C3E50','#4A6741']`. Ein einzelner Wert
      // ließe `LinearGradient` werfen.
      await pumpFact(
        tester,
        fact: factFixture(heroColors: const <String>['nicht-hex']),
      );

      expect(tester.takeException(), isNull);
      final bool hasDefault = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .any((DecoratedBox box) {
            final Gradient? gradient =
                (box.decoration as BoxDecoration).gradient;
            return gradient is LinearGradient &&
                gradient.colors.length == 2 &&
                gradient.colors.first.toARGB32() == 0xFF2C3E50 &&
                gradient.colors.last.toARGB32() == 0xFF4A6741;
          });
      expect(hasDefault, isTrue);
    });
  });

  group('Die Aktennummer', () {
    testWidgets('steht mit der redaktionellen Nummer in der Kopfzeile', (
      tester,
    ) async {
      // `Akte #{fact.nr || fact.id}`, `:367`. `fact.nr` ist die Nummer mit
      // Stadt-Präfix.
      await pumpFact(tester, fact: factFixture(number: 'MUC_004'));

      expect(find.text('Akte #MUC_004'), findsOneWidget);
    });

    testWidgets('ohne nr springt die Kennung ein, statt zu fehlen', (
      tester,
    ) async {
      // Der Notnagel `|| fact.id` der Quelle. `facts.nr` ist nullbar, die
      // Zeile steht in der PWA trotzdem immer da. Gegenprobe zu einer
      // Umsetzung, die die Zeile ohne `nr` weglässt.
      await pumpFact(tester, fact: factFixture());

      expect(find.text('Akte #1'), findsOneWidget);
    });

    testWidgets('sie steht zwischen Kategorie-Chip und Ort', (tester) async {
      // `:365`, `:367`, `:368` in dieser Reihenfolge. Eine Umsetzung, die
      // die Zeile ans Ende hängt, sähe im Text-Finder gleich aus.
      await pumpFact(tester, fact: factFixture(number: 'MUC_004'));

      final Rect chip = tester.getRect(find.text(stringsOf().text('cat.arch')));
      final Rect number = tester.getRect(find.text('Akte #MUC_004'));
      final Rect place = tester.getRect(
        find
            .descendant(
              of: find.byKey(FactPage.sheetKey),
              matching: find.text('Glyptothek · Koenigsplatz'),
            )
            .first,
      );

      expect(number.left, greaterThanOrEqualTo(chip.right));
      expect(place.left, greaterThanOrEqualTo(number.right));
      // Auf derselben Zeile und nicht darunter.
      expect(number.center.dy, closeTo(chip.center.dy, 4));
      expect(place.center.dy, closeTo(chip.center.dy, 4));
    });

    testWidgets('sie trägt die Maße der Quelle', (tester) async {
      // `fontFamily: JetBrains Mono, fontSize: 9, color: ink3,
      // letterSpacing: 0.1`, `:367`. Der Ort daneben hat dieselbe Größe,
      // aber **keine** Laufweite; wer beide gleich baut, hat eine davon
      // geraten.
      await pumpFact(tester, fact: factFixture(number: 'MUC_004'));

      final Text number = tester.widget<Text>(find.text('Akte #MUC_004'));
      expect(number.style!.fontFamily, 'JetBrainsMono');
      expect(number.style!.fontSize, 9);
      expect(number.style!.color, FactDetailPalette.light.ink3);
      expect(number.style!.letterSpacing, 0.1);
    });

    testWidgets('sie verdraengt den Ort nicht aus dem Rahmenmass', (
      tester,
    ) async {
      // Das Flex-Verhaeltnis 1 zu 2 aus `_fileNumber` ist damit belegt und
      // nicht behauptet: bei 390 Pixeln und Skalierung 1 stehen Nummer und
      // Ort **beide vollstaendig** da. Bei gleichen Anteilen bekaeme der Ort
      // 113,6 Pixel bei 135,0 Pixeln Bedarf und traege ein
      // Auslassungszeichen, ohne dass eine Ausnahme faellt.
      await pumpFact(tester, fact: factFixture(number: 'MUC_004'));

      for (final Finder finder in <Finder>[
        find.text('Akte #MUC_004'),
        find
            .descendant(
              of: find.byKey(FactPage.sheetKey),
              matching: find.text('Glyptothek · Koenigsplatz'),
            )
            .first,
      ]) {
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
          reason: tester.widget<Text>(finder).data,
        );
      }
    });

    testWidgets('sie bleibt im englischen Modus deutsch', (tester) async {
      // Der Text steht wörtlich im JSX und nicht in `translations.jsx`,
      // die PWA zeigt ihn auch auf Englisch so. Exakte Parität.
      await pumpFact(
        tester,
        fact: factFixture(number: 'MUC_004'),
        language: AppLanguage.en,
      );

      expect(find.text('Akte #MUC_004'), findsOneWidget);
      expect(find.textContaining('File'), findsNothing);
    });
  });

  group('Die Zitat-Hochziffer', () {
    testWidgets('steht im Text und ist kleiner und rot', (tester) async {
      await pumpFact(tester, fact: factFixture());

      final Text citation = tester.widget<Text>(inBody(find.text('[1]')));
      expect(citation.style!.fontSize, 10);
      expect(citation.style!.color, FactDetailPalette.citation);
      expect(citation.style!.fontFamily, 'JetBrainsMono');
    });

    testWidgets('sie steht am Kopf der Zeile, nicht auf der Grundlinie', (
      tester,
    ) async {
      // `<sup>`. Der Absatz ist bewusst einzeilig, damit die Oberkante der
      // Ziffer mit der Oberkante des Absatzes vergleichbar ist. Säße sie auf
      // der Grundlinie, läge sie um Zeilenhöhe minus Zifferhöhe tiefer, bei
      // 15 Pixeln Schrift und Zeilenhöhe 1.65 also rund 15 Pixel.
      await pumpFact(tester, fact: factFixture(body: 'Kurz.[1]'));

      final Rect citation = tester.getRect(inBody(find.text('[1]')));
      final Rect paragraph = tester.getRect(
        inBody(find.textContaining('Kurz.')),
      );
      expect(paragraph.height, lessThan(30), reason: 'muss einzeilig sein');
      expect(citation.height, lessThan(paragraph.height));
      // Die Ziffer sitzt im oberen Drittel der Zeile. Auf der Grundlinie läge
      // ihre Oberkante um Zeilenhöhe minus Zifferhöhe tiefer, also unterhalb
      // dieser Schranke; gemessen sind es dort rund 15 Pixel gegen 3.
      expect(citation.top - paragraph.top, greaterThanOrEqualTo(0));
      expect(citation.top - paragraph.top, lessThan(paragraph.height / 3));
    });

    testWidgets('ein Tipp springt zur Quellenliste', (tester) async {
      await pumpFact(
        tester,
        fact: factFixture(
          // Die Hochziffer steht früh, damit sie antippbar ist; der Rest
          // schiebt die Quellenliste unter die Bildschirmkante.
          body:
              'Ein Satz mit Beleg.[1] '
              '${'Und danach noch viel Text, damit die Quellenliste weit '
                      'unterhalb der sichtbaren Flaeche zu liegen kommt. ' * 8}',
        ),
      );

      final Finder sources = find.byKey(FactPage.sourcesKey);
      final double viewportHeight = tester.view.physicalSize.height / 3;
      expect(
        tester.getRect(sources).top,
        greaterThan(viewportHeight),
        reason:
            'Die Liste muss vorher außerhalb liegen, sonst prüft der '
            'Sprung nichts.',
      );

      await tester.tap(inBody(find.text('[1]')));
      await tester.pumpAndSettle();

      final Rect after = tester.getRect(sources);
      // Vollständig sichtbar, nicht nur angeschnitten.
      expect(after.top, greaterThanOrEqualTo(-0.01));
      expect(after.bottom, lessThanOrEqualTo(viewportHeight + 0.01));
      // Dass die Liste **nicht** in der Mitte landet, ist kein Fehler: sie ist
      // das letzte Bauteil der Seite, weiter als bis zum Ende lässt sich nicht
      // scrollen, und `ensureVisible` klemmt dort. Die Zusicherung ist deshalb
      // "vollständig sichtbar" und nicht "zentriert".
    });

    testWidgets('eine Ziffer über den Quellen hinaus ist jetzt ein Ziel', (
      tester,
    ) async {
      // **Diese Zusicherung hat sich am 29.08.2026 umgedreht.** Vorher galt
      // hier "eine Ziffer ohne passende Zeile ist kein Ziel": es fehlte der
      // Text für die Platzhalterzeilen, `[5]` neben zwei Quellen zeigte auf
      // eine fünfte Zeile, die es nicht gab, und war deshalb bewusst nicht
      // antippbar. Mit `fact.sourceMissing` füllt die Liste bis zur
      // höchsten Referenz auf (`:472-475`), die fünfte Zeile gibt es, und
      // damit ist die Ziffer wieder ein Ziel.
      await pumpFact(
        tester,
        fact: factFixture(
          body: 'Erst ein Beleg[1] und dann ein Beleg ins Leere.[5]',
        ),
      );

      for (final String label in <String>['[1]', '[5]']) {
        expect(inBody(find.text(label)), findsOneWidget, reason: label);
        expect(
          find.ancestor(
            of: inBody(find.text(label)),
            matching: find.byType(GestureDetector),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      // Und das Ziel ist wirklich da: fünf Zeilen, davon drei Platzhalter.
      final Finder card = find.byKey(FactPage.sourcesKey);
      expect(
        find.descendant(
          of: card,
          matching: find.text(stringsOf().text('fact.sourceMissing')),
        ),
        findsNWidgets(3),
      );
      expect(
        find.descendant(of: card, matching: find.text('[5]')),
        findsOneWidget,
      );
    });

    testWidgets('ohne Quellenangabe steht die Ziffer auf einem Platzhalter', (
      tester,
    ) async {
      // `:459` greift nicht, `:473` füllt trotzdem, `:476` zeigt den Kasten,
      // weil die Liste eine Zeile hat. Auch das ist gegenüber dem Stand vom
      // Vormittag umgedreht: dort fehlte der Kasten ganz.
      await pumpFact(tester, fact: factFixture(source: null));

      final Finder card = find.byKey(FactPage.sourcesKey);
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text(stringsOf().text('fact.sourceMissing')),
        ),
        findsOneWidget,
      );
      await tester.tap(inBody(find.text('[1]')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Die Quellenliste', () {
    testWidgets('zeigt jede Quelle genau einmal und in ihrer Reihenfolge', (
      tester,
    ) async {
      await pumpFact(tester, fact: factFixture());

      final Finder card = find.byKey(FactPage.sourcesKey);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Wikipedia')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Stadtarchiv Muenchen')),
        findsOneWidget,
      );
      // Die Nummern gehören zur Zeile und nicht zur Zierde: `[1]` steht über
      // `[2]`, und beide zeigen auf die Quelle daneben.
      expect(
        tester
            .getRect(find.descendant(of: card, matching: find.text('[1]')))
            .top,
        lessThan(
          tester
              .getRect(find.descendant(of: card, matching: find.text('[2]')))
              .top,
        ),
      );
      expect(
        tester
            .getRect(find.descendant(of: card, matching: find.text('[1]')))
            .top,
        closeTo(tester.getRect(find.text('Wikipedia')).top, 6),
      );
    });

    testWidgets('der Kasten trägt Kartenfläche und Rahmen', (tester) async {
      // `background: card2`, `border: 1px solid ${border}`, `:478`.
      await pumpFact(tester, fact: factFixture());

      final Container card = tester.widget<Container>(
        find.byKey(FactPage.sourcesKey),
      );
      final BoxDecoration decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, FactDetailPalette.light.card);
      expect(decoration.border!.top.color, FactDetailPalette.light.border);
    });

    testWidgets('die Überschrift steht in Großbuchstaben', (tester) async {
      await pumpFact(tester, fact: factFixture());

      expect(
        find.text(stringsOf().text('fact.sources').toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('ohne Angabe und ohne Referenz fehlt der Kasten ganz', (
      tester,
    ) async {
      // `:476`: `if (list.length === 0) return null`. Der Fakttext muss
      // dafür seit der Auffüllung ohne Hochziffer sein, sonst entstünden
      // Platzhalterzeilen und der Kasten stünde da.
      await pumpFact(
        tester,
        fact: factFixture(source: '   ', body: 'Ein Satz ohne Beleg.'),
      );

      expect(find.byKey(FactPage.sourcesKey), findsNothing);
      expect(
        find.text(stringsOf().text('fact.sources').toUpperCase()),
        findsNothing,
      );
    });
  });

  group('Die Platzhalterzeilen', () {
    testWidgets('es entstehen genau so viele, wie zur Ziffer fehlen', (
      tester,
    ) async {
      // Zwei Angaben, höchste Referenz 4: zwei Platzhalter, nicht vier.
      await pumpFact(
        tester,
        fact: factFixture(body: 'Ein Satz[1] mit zwei Belegen.[4]'),
      );

      final Finder card = find.byKey(FactPage.sourcesKey);
      expect(
        find.descendant(
          of: card,
          matching: find.text(stringsOf().text('fact.sourceMissing')),
        ),
        findsNWidgets(2),
      );
      // Vier Zeilen, nicht mehr: `[5]` gibt es nicht.
      expect(
        find.descendant(of: card, matching: find.text('[4]')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('[5]')),
        findsNothing,
      );
    });

    testWidgets('sie stehen hinter den echten Angaben', (tester) async {
      // `:473` hängt an, es schiebt nicht dazwischen. Sonst zeigte `[1]`
      // auf einen Platzhalter statt auf Wikipedia.
      await pumpFact(
        tester,
        fact: factFixture(body: 'Ein Satz mit drei Belegen.[3]'),
      );

      final Finder card = find.byKey(FactPage.sourcesKey);
      expect(
        tester
            .getRect(
              find.descendant(of: card, matching: find.text('Wikipedia')),
            )
            .top,
        lessThan(
          tester
              .getRect(
                find.descendant(
                  of: card,
                  matching: find.text(stringsOf().text('fact.sourceMissing')),
                ),
              )
              .top,
        ),
      );
    });

    testWidgets('eine Auffüllzeile sieht anders aus als eine Angabe', (
      tester,
    ) async {
      // `color: q.missing ? ink3 : ink2` und `fontStyle: italic`, `:490`.
      // Ohne den Unterschied gäbe sich eine leere Zeile als Beleg aus.
      await pumpFact(
        tester,
        fact: factFixture(body: 'Ein Satz mit drei Belegen.[3]'),
      );

      final Text placeholder = tester.widget<Text>(
        find.descendant(
          of: find.byKey(FactPage.sourcesKey),
          matching: find.text(stringsOf().text('fact.sourceMissing')),
        ),
      );
      final Text real = tester.widget<Text>(
        find.descendant(
          of: find.byKey(FactPage.sourcesKey),
          matching: find.text('Wikipedia'),
        ),
      );

      expect(placeholder.style!.color, FactDetailPalette.light.ink3);
      expect(real.style!.color, FactDetailPalette.light.ink2);
      expect(placeholder.style!.fontStyle, FontStyle.italic);
      expect(real.style!.fontStyle, FontStyle.normal);
    });

    testWidgets('auf Englisch steht der englische Wortlaut da', (tester) async {
      // `:474` führt beide Sprachen wörtlich, anders als die Aktennummer.
      await pumpFact(
        tester,
        fact: factFixture(body: 'Ein Satz mit drei Belegen.[3]'),
        language: AppLanguage.en,
      );

      expect(find.text('Source missing'), findsOneWidget);
      expect(find.text('Quelle fehlt'), findsNothing);
    });

    testWidgets('ein eingeklappter Absatz zählt schon mit', (tester) async {
      // `highestSourceRef` liest alle vier Textfelder und prüft weder
      // `showMore` noch `isRealProse`. Ohne das wüchse die Liste unter dem
      // Finger, sobald der Nutzer aufklappt.
      await pumpFact(
        tester,
        fact: factFixture(
          body: 'Erster Absatz mit einem Beleg.[1]',
          bodyExtra: 'Der zweite Absatz ist lang genug fuer den Filter.[3]',
        ),
      );

      final Finder card = find.byKey(FactPage.sourcesKey);
      expect(find.text(stringsOf().text('fact.showMore')), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('[3]')),
        findsOneWidget,
      );

      await tester.tap(find.text(stringsOf().text('fact.showMore')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: card, matching: find.text('[3]')),
        findsOneWidget,
        reason: 'die Liste darf beim Aufklappen nicht wachsen',
      );
    });
  });

  group('Das Aufklappen', () {
    testWidgets('ohne zweiten Absatz gibt es keinen Knopf', (tester) async {
      await pumpFact(tester, fact: factFixture(bodyExtra: null));

      expect(find.text(stringsOf().text('fact.showMore')), findsNothing);
    });

    testWidgets('ein Emotion-Tag in text2 ist kein zweiter Absatz', (
      tester,
    ) async {
      // `isRealProse`, `:44-48`.
      await pumpFact(tester, fact: factFixture(bodyExtra: 'Nachdenklichkeit'));

      expect(find.text(stringsOf().text('fact.showMore')), findsNothing);
      expect(find.text('Nachdenklichkeit'), findsNothing);
    });

    testWidgets('der Knopf zeigt mehr Text und verschwindet danach', (
      tester,
    ) async {
      const String extra =
          'Der zweite Absatz mit genug Text, um als Fließtext zu gelten.';
      await pumpFact(tester, fact: factFixture(bodyExtra: extra));

      final Finder button = find.text(stringsOf().text('fact.showMore'));
      expect(button, findsOneWidget);
      expect(find.textContaining(extra), findsNothing);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.textContaining(extra), findsOneWidget);
      expect(find.text(stringsOf().text('fact.showMore')), findsNothing);
    });

    testWidgets('text3 und text4 kommen nur mit, wenn sie Fließtext sind', (
      tester,
    ) async {
      const String extra = 'Der zweite Absatz ist lang genug fuer den Filter.';
      const String today = 'Der vierte Absatz ist ebenfalls lang genug dafuer.';
      await pumpFact(
        tester,
        fact: factFixture(
          bodyExtra: extra,
          // Zu kurz und ein Wort: fällt aus.
          bodyBackground: 'Staunen',
          bodyToday: today,
        ),
      );

      await tester.tap(find.text(stringsOf().text('fact.showMore')));
      await tester.pumpAndSettle();

      expect(find.textContaining(extra), findsOneWidget);
      expect(find.text('Staunen'), findsNothing);
      expect(find.textContaining(today), findsOneWidget);
    });

    testWidgets('der Knopf trägt die Kategoriefarbe', (tester) async {
      await pumpFact(
        tester,
        fact: factFixture(
          category: 'Natur',
          bodyExtra: 'Der zweite Absatz mit genug Text fuer den Filter.',
        ),
      );

      final Text button = tester.widget<Text>(
        find.text(stringsOf().text('fact.showMore')),
      );
      expect(button.style!.color, factCategoryLookOf('Natur').color);
    });
  });

  group('Die Entfernungszeile', () {
    const FactCoordinates glyptothek = FactCoordinates(
      latitude: 48,
      longitude: 11,
    );

    DevicePosition fixAt(double latitude, double longitude) => DevicePosition(
      latitude: latitude,
      longitude: longitude,
      accuracyInMeters: 5,
    );

    testWidgets('mit Ortung steht die gerundete Entfernung in Metern da', (
      tester,
    ) async {
      // Unabhängig hergeleitet: ein Tausendstel Grad auf demselben Längengrad
      // ist eine Meridianstrecke, also `R · 0.001° in rad` =
      // 6371000 · 1.745329e-5 = 111.19 Meter. Gerundet 111.
      await pumpFact(
        tester,
        fact: factFixture(coordinates: glyptothek),
        userPosition: fixAt(48.001, 11),
      );

      expect(
        find.text('111m ${stringsOf().text('fact.away')}'),
        findsOneWidget,
      );
    });

    testWidgets('gerundet wird und nicht abgeschnitten', (tester) async {
      // 0.0015° ergeben 166.8 Meter. Abschneiden ergäbe 166.
      await pumpFact(
        tester,
        fact: factFixture(coordinates: glyptothek),
        userPosition: fixAt(48.0015, 11),
      );

      expect(
        find.text('167m ${stringsOf().text('fact.away')}'),
        findsOneWidget,
      );
    });

    testWidgets('Breite und Länge sind nicht vertauscht', (tester) async {
      // Vertauschte Werte ergäben aus 111 Metern rund 4000 Kilometer, und in
      // der Pille stünde eine siebenstellige Zahl.
      await pumpFact(
        tester,
        fact: factFixture(coordinates: glyptothek),
        userPosition: fixAt(48.001, 11),
      );

      expect(find.textContaining('4'), findsNothing);
    });

    testWidgets('ohne Ortung steht der GPS-Text da, nicht "null entfernt"', (
      tester,
    ) async {
      await pumpFact(tester, fact: factFixture(coordinates: glyptothek));

      expect(find.text(stringsOf().text('fact.gpsRequired')), findsOneWidget);
      expect(find.textContaining(stringsOf().text('fact.away')), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('ohne Koordinate am Fakt ebenso', (tester) async {
      // `:143`, der Grund für die Prüfung: vorher stand "NaNm" in der Pille.
      await pumpFact(
        tester,
        fact: factFixture(),
        userPosition: fixAt(48.001, 11),
      );

      expect(find.text(stringsOf().text('fact.gpsRequired')), findsOneWidget);
      expect(find.textContaining('NaN'), findsNothing);
    });

    testWidgets('die Ortspille trägt Nadel und Ortsangabe', (tester) async {
      await pumpFact(tester, fact: factFixture());

      final Finder pin = find.text('📍');
      expect(pin, findsOneWidget);
      // In derselben Pille und nicht irgendwo auf der Seite: die Ortsangabe
      // steht rechts neben der Nadel und auf derselben Höhe.
      final Rect pinRect = tester.getRect(pin);
      final Rect placeRect = tester.getRect(
        find
            .descendant(
              of: find.byKey(FactPage.sheetKey),
              matching: find.text('Glyptothek · Koenigsplatz'),
            )
            .last,
      );
      expect(placeRect.left, greaterThan(pinRect.right));
      expect(placeRect.center.dy, closeTo(pinRect.center.dy, 4));
    });

    testWidgets('der Ort der Kategoriezeile steht rechts am Satzspiegel', (
      tester,
    ) async {
      // `marginLeft: 'auto'`, `:368`. Ohne die Verteilung klebte er am Chip.
      await pumpFact(tester, fact: factFixture());

      final Rect place = tester.getRect(
        find
            .descendant(
              of: find.byKey(FactPage.sheetKey),
              matching: find.text('Glyptothek · Koenigsplatz'),
            )
            .first,
      );
      expect(place.right, closeTo(390 - 20, 0.01));
    });

    testWidgets('ohne Ort entfällt die Ortspille statt "Passau" zu zeigen', (
      tester,
    ) async {
      await pumpFact(tester, fact: factFixture(place: null));

      expect(find.text('Passau'), findsNothing);
      expect(find.text('📍'), findsNothing);
    });
  });

  group('Das Medienbild', () {
    testWidgets('ohne hint_media gibt es kein Bild', (tester) async {
      await pumpFact(tester, fact: factFixture());

      expect(find.byKey(FactPage.heroImageKey), findsNothing);
    });

    testWidgets('mit hint_media steht die Vorschau-Adresse im Bild', (
      tester,
    ) async {
      // `hintMedia?.thumb_url || hintMedia?.url`, `:230`.
      await pumpFact(
        tester,
        fact: factFixture(
          media: const FactMedia(
            imageUrl: 'https://example.invalid/voll.jpg',
            thumbnailUrl: 'https://example.invalid/klein.jpg',
            caption: 'Glyptothek um 1900',
            sourceUrl: 'https://example.invalid/seite',
            attribution: 'Wikimedia Commons',
          ),
        ),
      );

      final Image image = tester.widget<Image>(
        find.byKey(FactPage.heroImageKey),
      );
      expect(
        (image.image as NetworkImage).url,
        'https://example.invalid/klein.jpg',
      );
      expect(image.fit, BoxFit.cover);
      // `objectPosition: 'center 25%'`.
      expect(image.alignment, const Alignment(0, -0.5));
    });

    testWidgets('die Bildbeschreibung steht in Klammern und in Versalien', (
      tester,
    ) async {
      await pumpFact(
        tester,
        fact: factFixture(
          media: const FactMedia(
            thumbnailUrl: 'https://example.invalid/klein.jpg',
            caption: 'Glyptothek um 1900',
          ),
        ),
      );

      expect(find.text('[ GLYPTOTHEK UM 1900 ]'), findsOneWidget);
    });

    testWidgets('ohne Bildbeschreibung stehen Ort und Bildunterschrift da', (
      tester,
    ) async {
      await pumpFact(tester, fact: factFixture(caption: 'Am Koenigsplatz'));

      expect(
        find.text('[ GLYPTOTHEK · KOENIGSPLATZ · AM KOENIGSPLATZ ]'),
        findsOneWidget,
      );
    });

    testWidgets('ohne beides springt "Historisches Foto" ein', (tester) async {
      await pumpFact(tester, fact: factFixture());

      expect(
        find.text(
          '[ GLYPTOTHEK · KOENIGSPLATZ · '
          '${stringsOf().text('fact.historicalPhoto').toUpperCase()} ]',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ohne Quellseite fehlt die Urheberangabe', (tester) async {
      // `:292`: die Bedingung ist `hint_media.source_url`, nicht die
      // Urheberangabe selbst.
      await pumpFact(
        tester,
        fact: factFixture(
          media: const FactMedia(
            thumbnailUrl: 'https://example.invalid/klein.jpg',
            attribution: 'Wikimedia Commons',
          ),
        ),
      );

      expect(find.textContaining('©'), findsNothing);
    });

    testWidgets('mit Quellseite steht die Urheberangabe da', (tester) async {
      await pumpFact(
        tester,
        fact: factFixture(
          media: const FactMedia(
            thumbnailUrl: 'https://example.invalid/klein.jpg',
            attribution: 'Wikimedia Commons',
            sourceUrl: 'https://example.invalid/seite',
          ),
        ),
      );

      expect(find.text('© Wikimedia Commons'), findsOneWidget);
    });
  });

  group('Die drei Zustände', () {
    testWidgets('ohne Fakt erscheint die Nicht-gefunden-Meldung', (
      tester,
    ) async {
      await pumpFact(tester);

      expect(find.text(stringsOf().text('fact.notFound')), findsOneWidget);
      expect(find.byKey(FactPage.heroKey), findsNothing);
      expect(find.byKey(FactPage.sheetKey), findsNothing);
    });

    testWidgets('während des Ladens steht dort nichts Falsches', (
      tester,
    ) async {
      await pumpFact(tester, loading: true, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(stringsOf().text('fact.notFound')), findsNothing);
    });

    testWidgets('der Zurück-Knopf führt auf die Karte', (tester) async {
      final GoRouter router = await pumpFact(tester, fact: factFixture());
      expect(router.state.uri.toString(), '/map/fact/1');

      await tester.tap(find.byKey(FactPage.backButtonKey));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), '/map');
      expect(find.text('KARTE'), findsOneWidget);
    });
  });

  group('Der Wechsel des Fakts', () {
    testWidgets('klappt den Text wieder ein', (tester) async {
      // `React.useEffect(..., [factId])`, `:90-100`. Ohne den Rücksetzer
      // stünde die Akte des nächsten Fakts sofort aufgeklappt da, wenn
      // dieselbe Seite mit einer anderen Kennung neu gebaut wird.
      useSurface(tester);
      const String extra = 'Der zweite Absatz mit genug Text fuer den Filter.';
      Widget page(FactId id) => ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(AppLanguage.de),
          ),
          factByIdProvider(const FactId(1)).overrideWith(
            (Ref ref) => Fact(
              id: const FactId(1),
              content: const FactText(
                title: 'Erster',
                body: 'Erster Text.',
                bodyExtra: extra,
              ),
            ),
          ),
          factByIdProvider(const FactId(2)).overrideWith(
            (Ref ref) => Fact(
              id: const FactId(2),
              content: const FactText(
                title: 'Zweiter',
                body: 'Zweiter Text.',
                bodyExtra: extra,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: FactTheme.light(),
          home: Scaffold(
            // Derselbe Schlüssel: nur so behält der State seinen Platz und
            // `didUpdateWidget` läuft überhaupt.
            body: FactPage(key: const ValueKey<String>('akte'), factId: id),
          ),
        ),
      );

      await tester.pumpWidget(page(const FactId(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(stringsOf().text('fact.showMore')));
      await tester.pumpAndSettle();
      expect(find.textContaining(extra), findsOneWidget);

      await tester.pumpWidget(page(const FactId(2)));
      await tester.pumpAndSettle();

      expect(find.text('Zweiter'), findsOneWidget);
      expect(find.textContaining(extra), findsNothing);
      expect(find.text(stringsOf().text('fact.showMore')), findsOneWidget);
    });
  });

  group('Was hier nicht steht', () {
    testWidgets('kein Sammeln, kein Audio, keine Kommentare, kein Teilen', (
      tester,
    ) async {
      await pumpFact(
        tester,
        fact: factFixture(
          coordinates: const FactCoordinates(latitude: 48, longitude: 11),
        ),
        userPosition: DevicePosition(
          latitude: 48,
          longitude: 11,
          accuracyInMeters: 5,
        ),
      );

      final AppStrings strings = stringsOf();
      // Auch bei null Metern Entfernung: der Sammeln-Knopf gehört zu Schritt
      // 20 und ist an E-06 blockiert.
      for (final String key in <String>[
        'fact.collect',
        'fact.discovered',
        'fact.xpCoins',
        'fact.comments',
        'fact.addComment',
      ]) {
        expect(
          find.textContaining(strings.text(key)),
          findsNothing,
          reason: key,
        );
      }
      // `fact.tooFar` trägt einen Platzhalter; geprüft wird der feste Teil
      // davor. Er gehört zum Sammeln-Knopf und darf hier nirgends stehen.
      expect(
        find.textContaining(
          strings
              .text('fact.tooFar', params: const <String, String>{'dist': ''})
              .split('{')
              .first
              .trim(),
        ),
        findsNothing,
      );
      expect(find.text('🎧'), findsNothing);
      expect(find.text('📤'), findsNothing);
      expect(find.text('🔖'), findsNothing);
      expect(find.text('🏷️'), findsNothing);
    });
  });

  group('Maße', () {
    testWidgets('der Hero ist die halbe Bildschirmhöhe, gedeckelt bei 480', (
      tester,
    ) async {
      await pumpFact(tester, fact: factFixture());

      // 844 / 2 = 422, unter der Deckelung.
      expect(tester.getSize(find.byKey(FactPage.heroKey)).height, 422);
    });

    testWidgets('auf einem hohen Bildschirm greift die Deckelung', (
      tester,
    ) async {
      await pumpFact(tester, fact: factFixture(), size: const Size(390, 1000));

      expect(tester.getSize(find.byKey(FactPage.heroKey)).height, 480);
    });

    testWidgets('auf einem kurzen Bildschirm greift die Mindesthöhe', (
      tester,
    ) async {
      await pumpFact(tester, fact: factFixture(), size: const Size(360, 480));

      expect(tester.getSize(find.byKey(FactPage.heroKey)).height, 280);
    });

    testWidgets('das Blatt überlappt den Hero um 40 Pixel', (tester) async {
      await pumpFact(tester, fact: factFixture());

      final Rect hero = tester.getRect(find.byKey(FactPage.heroKey));
      final Rect sheet = tester.getRect(find.byKey(FactPage.sheetKey));
      expect(sheet.top, closeTo(hero.bottom - FactPage.sheetOverlap, 0.01));
      expect(sheet.left, hero.left);
      expect(sheet.width, hero.width);
    });

    testWidgets('ein kurzer Fakt schneidet den Hero nicht ab', (tester) async {
      // Der `Stack` bekommt seine Höhe von der Spalte darin und schneidet
      // lautlos: wäre das Blatt kürzer als die 40 Pixel Überlappung, fehlte
      // unten ein Stück Hero.
      await pumpFact(
        tester,
        fact: factFixture(body: null, source: null, place: null),
      );

      final Rect hero = tester.getRect(find.byKey(FactPage.heroKey));
      final Rect sheet = tester.getRect(find.byKey(FactPage.sheetKey));
      expect(sheet.bottom, greaterThanOrEqualTo(hero.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('das Blatt rechnet den Freiraum der Tab-Leiste dazu', (
      tester,
    ) async {
      // `Scaffold.extendBody` meldet die Höhe der schwebenden Leiste als
      // unteres `MediaQuery`-Padding. Ein eigenes `padding`, das die Zahl
      // nicht dazurechnet, lässt den letzten Absatz darunter verschwinden.
      await pumpFact(tester, fact: factFixture());
      final Rect withoutBar = tester.getRect(find.byKey(FactPage.sheetKey));

      tester.view.padding = FakeViewPadding(
        bottom: 90 * tester.view.devicePixelRatio,
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(FactPage.sheetKey)).height,
        closeTo(withoutBar.height + 90, 0.01),
      );
    });

    testWidgets('der Zurück-Knopf sitzt 54 unter der sicheren Kante', (
      tester,
    ) async {
      useStatusBar(tester);
      await pumpFact(tester, fact: factFixture());

      final Rect back = tester.getRect(find.byKey(FactPage.backButtonKey));
      final double safeTop = tester.view.padding.top / 3;
      expect(safeTop, greaterThan(0), reason: 'sonst prüft der Test nichts');
      expect(back.top, closeTo(safeTop + FactPage.navigationRowTop, 0.01));
      expect(back.left, closeTo(FactPage.navigationRowInset, 0.01));
      expect(back.size, const Size(40, 40));
    });
  });

  group('Skalierung', () {
    for (final double scale in <double>[1, 2]) {
      for (final Size size in <Size>[
        const Size(390, 844),
        const Size(360, 640),
      ]) {
        final String label =
            'Skalierung $scale auf ${size.width.toInt()}x'
            '${size.height.toInt()}';

        testWidgets('$label bricht nichts um und schneidet nichts ab', (
          tester,
        ) async {
          useTextScale(tester, scale);
          useStatusBar(tester);
          await pumpFact(
            tester,
            fact: factFixture(
              // Mit echter Aktennummer: "Akte #MUC_004" ist bei doppelter
              // Systemschrift 141,7 Pixel breit und damit zusammen mit dem
              // Chip breiter als der Satzspiegel eines 360er Geräts. Mit
              // "Akte #1" prüfte diese Schleife die Kopfzeile nicht.
              number: 'MUC_004',
              bodyExtra:
                  'Der zweite Absatz mit genug Text, um als Fließtext zu '
                  'gelten.',
            ),
            size: size,
          );
          // Bei doppelter Systemschrift liegt der Knopf unterhalb des
          // Sichtfelds. `tap()` warnt dort nur und trifft nichts, der Test
          // liefe grün weiter und vermäße die eingeklappte Seite.
          await tapShowMore(tester);

          // Erst diese Zusicherung macht den Fehlgriff sichtbar: geprüft wird
          // die aufgeklappte Akte, nicht die eingeklappte.
          expect(
            find.textContaining('Der zweite Absatz'),
            findsOneWidget,
            reason: '$label: nicht aufgeklappt',
          );

          expect(tester.takeException(), isNull, reason: label);

          // Kein Absatz ragt seitlich aus dem Bildschirm. Ein `Stack` und ein
          // `ClipRect` schneiden lautlos, eine Ausnahme gibt es dabei nicht.
          for (final (RenderParagraph paragraph, Rect rect) in paragraphs(
            tester,
          )) {
            expect(
              rect.left,
              greaterThanOrEqualTo(-0.01),
              reason: '$label: ${paragraph.text.toPlainText()}',
            );
            expect(
              rect.right,
              lessThanOrEqualTo(size.width + 0.01),
              reason: '$label: ${paragraph.text.toPlainText()}',
            );
          }

          // Der Kategorie-Chip passt in die Zeile, ohne den Ort daneben zu
          // verdrängen. Er steht ohne `Flexible` in der Zeile, diese Messung
          // ist also die Bedingung dafür.
          expect(
            tester.getSize(find.text(stringsOf().text('cat.arch'))).width,
            lessThan(size.width - 120),
            reason: label,
          );

          // Der Kategorie-Chip und die Pillen bleiben im Satzspiegel des
          // Blattes, `padding: '8px 20px'`.
          for (final Finder finder in <Finder>[
            find.text(stringsOf().text('cat.arch')),
            find.byKey(FactPage.sourcesKey),
          ]) {
            final Rect rect = tester.getRect(finder);
            expect(rect.left, greaterThanOrEqualTo(19.99), reason: label);
            expect(
              rect.right,
              lessThanOrEqualTo(size.width - 19.99),
              reason: label,
            );
          }
        });
      }
    }

    testWidgets('die Bildunterschrift bleibt einzeilig', (tester) async {
      // `whiteSpace: 'nowrap'` mit `textOverflow: 'ellipsis'`, `:286`. Ein
      // Umbruch wäre kein Überlauf und keine Ausnahme.
      useTextScale(tester, 2);
      await pumpFact(
        tester,
        fact: factFixture(caption: 'Eine sehr lange Bildunterschrift dazu'),
        size: const Size(360, 640),
      );

      final RenderParagraph caption = paragraphs(tester)
          .map(((RenderParagraph, Rect) entry) => entry.$1)
          .firstWhere(
            (RenderParagraph paragraph) =>
                paragraph.text.toPlainText().startsWith('[ GLYPTOTHEK'),
          );
      expect(
        caption
            .getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: caption.text.toPlainText().length,
              ),
            )
            .map((TextBox box) => box.top)
            .toSet(),
        hasLength(1),
      );
    });
  });
}
