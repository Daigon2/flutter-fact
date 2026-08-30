import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/puzzles/domain/entities/puzzle.dart';
import 'package:fact_app/features/puzzles/presentation/puzzle_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_fonts.dart';

/// Der Rahmen des Rätsel-Sheets, `02_Frontend/app/puzzle-sheet.jsx:113-196`.
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

  AppStrings stringsOf([AppLanguage language = AppLanguage.de]) =>
      AppStrings.of(language);

  Puzzle puzzleFixture({
    String question = 'Wie viele Löwen sitzen am Portal?',
    String? type = 'kompass',
    String? photoUrl,
  }) => CompassPuzzle(question: question, type: type, photoUrl: photoUrl);

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

  Future<int> pumpSheet(
    WidgetTester tester, {
    required Puzzle puzzle,
    int stopIndex = 0,
    AppLanguage language = AppLanguage.de,
    ThemeData? theme,
    Size size = const Size(390, 844),
  }) async {
    useSurface(tester, size: size);
    int closed = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
        ],
        child: MaterialApp(
          theme: theme ?? FactTheme.light(),
          home: Scaffold(
            body: PuzzleSheet(
              puzzle: puzzle,
              stopIndex: stopIndex,
              onClose: () => closed++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return closed;
  }

  TextStyle styleOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).style!;

  /// Alle gezeichneten Absätze des Sheets mit ihrem Rechteck.
  ///
  /// Über den Renderbaum und nicht über einen Finder, wie in
  /// `fact_page_test.dart`: `SelectableText` und `EditableText` tauchen in
  /// `find.byType(RichText)` gar nicht auf (Muster 8). Heute gibt es hier
  /// keins von beiden, mit Schritt 28 kommen Eingabefelder dazu, und dann
  /// misst dieser Durchlauf sie mit, ohne dass ihn jemand anfassen muss.
  List<(RenderParagraph, Rect)> paragraphs(WidgetTester tester) {
    final List<(RenderParagraph, Rect)> found = <(RenderParagraph, Rect)>[];
    void visit(RenderObject object) {
      if (object is RenderParagraph && object.hasSize) {
        found.add((object, object.localToGlobal(Offset.zero) & object.size));
      }
      object.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(PuzzleSheet)));
    return found;
  }

  group('Der Inhalt steht', () {
    testWidgets('Station, Überschrift, Beschriftung und Aufgabe erscheinen', (
      tester,
    ) async {
      await pumpSheet(tester, puzzle: puzzleFixture(), stopIndex: 2);

      // `:150` und `:165` zählen beide `stopIdx + 1`, hier also 3.
      expect(find.text('STATION 3'), findsOneWidget);
      expect(find.text('Rätsel 3'), findsOneWidget);
      expect(find.text('AUFGABE'), findsOneWidget);
      expect(find.text('Wie viele Löwen sitzen am Portal?'), findsOneWidget);
    });

    testWidgets('die Zählung ist eins-basiert und nicht null-basiert', (
      tester,
    ) async {
      await pumpSheet(tester, puzzle: puzzleFixture());

      expect(find.text('STATION 1'), findsOneWidget);
      expect(find.text('Rätsel 1'), findsOneWidget);
      expect(find.text('STATION 0'), findsNothing);
    });

    testWidgets('auf Englisch heißt die Station weiter Station', (
      tester,
    ) async {
      // `:150`: der Ternär hat in beiden Zweigen dasselbe Wort. Das sieht nach
      // einem Fehler aus und ist der Zustand der Verhaltensquelle.
      await pumpSheet(
        tester,
        puzzle: puzzleFixture(),
        language: AppLanguage.en,
      );

      expect(find.text('STATION 1'), findsOneWidget);
      expect(find.text('Riddle 1'), findsOneWidget);
      // `Aufgabe` steht als nackter Textknoten in `:194`, ohne Ternär.
      expect(find.text('AUFGABE'), findsOneWidget);
    });

    testWidgets('Symbol und Beschriftung kommen aus der Typtabelle', (
      tester,
    ) async {
      await pumpSheet(tester, puzzle: puzzleFixture(type: 'tap-counter'));

      expect(
        tester.widget<Text>(find.byKey(PuzzleSheet.typeIconKey)).data,
        '👆',
      );
      expect(
        tester.widget<Text>(find.byKey(PuzzleSheet.typeLabelKey)).data,
        stringsOf().text('puzzle.type.tap'),
      );
    });

    testWidgets('ein unbekannter Typ zeigt ❓ und den rohen Typ', (
      tester,
    ) async {
      // `vor-ort` ist mit 761 Vorkommen der häufigste Wert der Live-Daten und
      // steht nicht in der Typtabelle.
      await pumpSheet(tester, puzzle: puzzleFixture(type: 'vor-ort'));

      expect(
        tester.widget<Text>(find.byKey(PuzzleSheet.typeIconKey)).data,
        '❓',
      );
      expect(
        tester.widget<Text>(find.byKey(PuzzleSheet.typeLabelKey)).data,
        'vor-ort',
      );
    });

    testWidgets('der Foto-Block erscheint nur mit Foto', (tester) async {
      await pumpSheet(tester, puzzle: puzzleFixture());
      expect(find.byKey(PuzzleSheet.photoKey), findsNothing);
      expect(find.byKey(PuzzleSheet.photoCaptionKey), findsNothing);

      await pumpSheet(
        tester,
        puzzle: puzzleFixture(photoUrl: 'https://example.invalid/damals.jpg'),
      );
      expect(find.byKey(PuzzleSheet.photoKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(PuzzleSheet.photoCaptionKey)).data,
        'Damals — was hat sich verändert?',
      );
    });

    testWidgets('der Rätselkörper wird nicht gebaut', (tester) async {
      // Schritt 27 baut den Rahmen, nicht die Eingabemasken. Fällt dieser
      // Test, ist Schritt 28 angefangen, und dann gehört E-08 mit dazu.
      await pumpSheet(tester, puzzle: puzzleFixture());

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('Schließen', () {
    testWidgets('der Knopf trägt × und meldet genau einmal', (tester) async {
      int closed = 0;
      useSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FactTheme.light(),
            home: Scaffold(
              body: PuzzleSheet(
                puzzle: puzzleFixture(),
                stopIndex: 0,
                onClose: () => closed++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // U+00D7 und nicht der Buchstabe x, `:147`.
      expect(
        find.descendant(
          of: find.byKey(PuzzleSheet.closeButtonKey),
          matching: find.text('×'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(PuzzleSheet.closeButtonKey));
      await tester.pump();

      expect(closed, 1);
    });

    testWidgets('ohne Tipp passiert nichts', (tester) async {
      // Gegenprobe zu einem Rückruf, der schon beim Bauen feuert.
      final int closed = await pumpSheet(tester, puzzle: puzzleFixture());

      expect(closed, 0);
    });
  });

  group('Maße', () {
    testWidgets('die Blase sitzt 16 von links und 44 plus 8 von oben', (
      tester,
    ) async {
      // `paddingTop: 44` am Blatt (`:117`) und `margin: '8px 16px 0'` an der
      // Blase (`:124`).
      await pumpSheet(tester, puzzle: puzzleFixture());

      final Rect header = tester.getRect(find.byKey(PuzzleSheet.headerKey));
      expect(header.left, 16);
      expect(header.right, 390 - 16);
      expect(header.top, 44 + 8);
    });

    testWidgets('der Schließknopf ist 32 mal 32', (tester) async {
      await pumpSheet(tester, puzzle: puzzleFixture());

      expect(
        tester.getSize(find.byKey(PuzzleSheet.closeButtonKey)),
        const Size(32, 32),
      );
    });

    testWidgets('der Inhalt hat 20 links und rechts', (tester) async {
      // `padding: '20px 20px 100px'`, `:159`.
      await pumpSheet(tester, puzzle: puzzleFixture());

      expect(tester.getRect(find.byKey(PuzzleSheet.headingKey)).left, 20);
      expect(
        tester.getRect(find.byKey(PuzzleSheet.taskCardKey)).right,
        390 - 20,
      );
    });

    testWidgets('die drei Zeilenhöhen der Quelle stehen', (tester) async {
      // 1.05 an der Typbeschriftung (`:152`), 1.3 an der Überschrift (`:164`)
      // und 1.5 an der Aufgaben-Karte (`:187`). Nach E-40 werden ausdrücklich
      // gesetzte Werte der Quelle übernommen, geerbte Material-Werte nicht.
      await pumpSheet(tester, puzzle: puzzleFixture());

      expect(styleOf(tester, PuzzleSheet.typeLabelKey).height, 1.05);
      expect(styleOf(tester, PuzzleSheet.headingKey).height, 1.3);
      expect(styleOf(tester, PuzzleSheet.questionKey).height, 1.5);
      expect(styleOf(tester, PuzzleSheet.taskLabelKey).height, 1.5);
    });

    testWidgets('Größen und Laufweiten kommen aus der Quelle', (tester) async {
      await pumpSheet(tester, puzzle: puzzleFixture());

      final TextStyle station = styleOf(tester, PuzzleSheet.stationLineKey);
      expect(station.fontSize, 9);
      expect(station.fontWeight, FontWeight.w600);
      expect(station.fontFamily, 'JetBrainsMono');
      // `letterSpacing: '0.22em'` bei 9 Pixeln, `:149`.
      expect(station.letterSpacing, closeTo(1.98, 1e-9));

      final TextStyle label = styleOf(tester, PuzzleSheet.typeLabelKey);
      expect(label.fontSize, 18);
      expect(label.fontFamily, 'Nunito');
      // `letterSpacing: '-0.015em'` bei 18 Pixeln, `:152`.
      expect(label.letterSpacing, closeTo(-0.27, 1e-9));
      // `textShadow: '0 2px 0 rgba(120,20,2,0.4)'`, `:152`.
      expect(label.shadows, hasLength(1));
      expect(label.shadows!.single.offset, const Offset(0, 2));

      final TextStyle heading = styleOf(tester, PuzzleSheet.headingKey);
      expect(heading.fontSize, 22);
      // `letterSpacing: '-0.01em'` bei 22 Pixeln, `:164`.
      expect(heading.letterSpacing, closeTo(-0.22, 1e-9));

      final TextStyle taskLabel = styleOf(tester, PuzzleSheet.taskLabelKey);
      expect(taskLabel.fontSize, 10);
      // `letterSpacing: 1.5`, `:192`: React hängt an eine Zahl ein `px` an,
      // der Wert ist absolut und wird nicht mit der Schriftgröße
      // multipliziert. Wäre er als `em` gelesen worden, stünde hier 15.
      expect(taskLabel.letterSpacing, 1.5);

      expect(styleOf(tester, PuzzleSheet.questionKey).fontSize, 16);

      // Die Farben der Kopfzeile. Sie stehen hier und nicht im Bildtest
      // darunter, weil sie am Stil ablesbar sind: eine Zusicherung am
      // Textstil ist billiger und schaerfer als eine an gezeichneten
      // Bildpunkten, wo Glyphen von Kantenglaettung leben.
      // **Gegen die Konstante zu prüfen, prüft nichts.** Die erste Fassung
      // schrieb hier `PuzzleSheet.stationLineColor` auf beide Seiten; eine
      // Mutationsprobe an genau dieser Konstante hat die Suite überlebt.
      // Deshalb steht rechts der Wert aus `puzzle-sheet.jsx:149` und nicht
      // der Name aus dem Prüfgegenstand.
      expect(station.color, const Color.fromRGBO(255, 255, 255, 0.78));
      expect(label.color, const Color(0xFFFFFFFF));
      // `textShadow: '0 2px 0 rgba(120,20,2,0.4)'`, `:152`, wieder als Wert
      // und nicht als Name.
      expect(
        label.shadows!.single.color,
        const Color.fromRGBO(120, 20, 2, 0.4),
      );
      expect(label.shadows!.single.blurRadius, 0);

      // `fontSize: 28` am Typsymbol, `:156`. Es traegt keine der Rollen aus
      // `FactTypography`, die Groesse ist alles, was es hat.
      expect(
        tester
            .widget<Text>(find.byKey(PuzzleSheet.typeIconKey))
            .style!
            .fontSize,
        28,
      );
    });
  });

  group('Farben', () {
    testWidgets('die Aufgaben-Karte trägt den roten Akzent links', (
      tester,
    ) async {
      await pumpSheet(tester, puzzle: puzzleFixture());

      final Container card = tester.widget<Container>(
        find.byKey(PuzzleSheet.taskCardKey),
      );
      final BoxDecoration decoration = card.decoration! as BoxDecoration;
      final Border border = decoration.border! as Border;
      // Nur links, `:183`. Ein `Border.all` sähe im Bild ähnlich aus und wäre
      // ringsum falsch.
      expect(border.top, BorderSide.none);
      expect(border.right, BorderSide.none);
      expect(border.bottom, BorderSide.none);
      expect(border.left.color, FactColors.light.red);
      expect(border.left.width, 3);
      expect(
        styleOf(tester, PuzzleSheet.taskLabelKey).color,
        FactColors.light.red,
      );
    });

    // Hell und dunkel stehen absichtlich in **zwei** Tests und nicht in einem
    // mit zwei `pumpWidget`-Aufrufen. `MaterialApp` legt ein `AnimatedTheme`
    // über seinen Inhalt; ein Themenwechsel im laufenden Baum blendet über
    // `kThemeAnimationDuration` hinüber, und nach einem einzelnen `pump()`
    // steht `Theme.of(context).brightness` noch auf dem alten Wert. Gemessen:
    // genau daran ist die erste Fassung dieses Tests gescheitert, und zwar
    // mit einer Fehlermeldung, die nach einem Fehler im Widget aussah.
    testWidgets('im hellen Zustand: helle Fläche und Schatten', (tester) async {
      // `:182` und `:188`.
      await pumpSheet(tester, puzzle: puzzleFixture());

      final BoxDecoration decoration =
          tester
                  .widget<Container>(find.byKey(PuzzleSheet.taskCardKey))
                  .decoration!
              as BoxDecoration;
      // `rgba(0,0,0,0.04)`, `:77`, als Wert und nicht als Name.
      expect(decoration.color, const Color.fromRGBO(0, 0, 0, 0.04));
      expect(decoration.boxShadow, hasLength(1));
    });

    testWidgets('im dunklen Zustand: dunkle Fläche und kein Schatten', (
      tester,
    ) async {
      // `boxShadow: isDark ? 'none' : …`, `:188`.
      await pumpSheet(tester, puzzle: puzzleFixture(), theme: FactTheme.dark());

      final BoxDecoration decoration =
          tester
                  .widget<Container>(find.byKey(PuzzleSheet.taskCardKey))
                  .decoration!
              as BoxDecoration;
      // `rgba(255,255,255,0.05)`, `:77`, als Wert und nicht als Name.
      expect(decoration.color, const Color.fromRGBO(255, 255, 255, 0.05));
      expect(decoration.boxShadow, isNull);
    });
  });

  group('Die gezeichnete Blase', () {
    // **Warum ein Farbtest und kein Maßtest.** Muster 4 aus „Wie Tests hier
    // blind werden": ein Bildtest, der die Fläche misst, sieht den Inhalt
    // nicht, und genau das ist hier dreimal in einer Woche passiert. Vor
    // dieser Gruppe haben elf Mutationen an der Optik der Marken-Blase die
    // ganze Suite überlebt, unter ihnen die Endfarbe des Verlaufs, für die es
    // gar keine Vorlage gibt: der CSS-Stop steht bei **110 Prozent**, also
    // außerhalb der Fläche, und `Color.lerp(red, redLight, 0.8)` ist eine
    // hergeleitete Zahl. Eine Herleitung ohne Gegenprobe ist Muster 9.
    //
    // **Warum keine Golden-Datei.** Sie wäre plattformabhängig und müsste auf
    // jedem Rechner neu erzeugt werden. Hier werden stattdessen einzelne
    // Bildpunkte gelesen und **gegeneinander** verglichen. Absolute Werte
    // stehen nur dort, wo genau sie die Aussage tragen.
    //
    // **Warum nur hell, nur Skalierung 1, nur 390x844.** Die Blase zieht ihre
    // Farben aus themeneutralen Tokens (`--stamp-deep`, `--stamp`,
    // `--primary-lt`, alle drei in beiden Themes gleich). Weitere
    // Kombinationen kosten Pflege und sagen über den Zeichencode nichts Neues.

    /// Pumpt das Sheet unter einer eigenen Zeichengrenze und liest sie aus.
    ///
    /// `toImage()` **muss** in `tester.runAsync` laufen. Im Rumpf von
    /// `testWidgets` läuft eine `FakeAsync`-Zone, in der das `Future` der
    /// Engine nie erfüllt wird; gemessen: der erste Versuch lief zehn Minuten
    /// in die Zeitüberschreitung, ohne eine einzige Meldung. Das ist
    /// Muster 14, nur mit einem dritten Helfer.
    Future<(Rect bubble, ByteData pixels, int width)> paintBubble(
      WidgetTester tester,
    ) async {
      const Key boundaryKey = Key('puzzle-sheet-paint-boundary');
      useSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FactTheme.light(),
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: PuzzleSheet(
                  puzzle: puzzleFixture(),
                  stopIndex: 0,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));

      // Ohne diese Zeile verschieben sich alle Abtastpunkte lautlos, sobald
      // jemand etwas über das Sheet legt: die Bildpunkte sind lokal zur
      // Zeichengrenze, die Rechtecke unten global.
      expect(boundary.localToGlobal(Offset.zero), Offset.zero);

      late ByteData pixels;
      await tester.runAsync(() async {
        // `pixelRatio: 1`, damit ein Bildpunkt genau einem logischen Pixel
        // entspricht und die Rechtecke direkt als Koordinaten taugen.
        final ui.Image image = await boundary.toImage();
        pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();
      });

      return (
        tester.getRect(find.byKey(PuzzleSheet.headerKey)),
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

    testWidgets('der Verlauf läuft von dunkel nach hell, und zwar schräg', (
      tester,
    ) async {
      // `linear-gradient(135deg, var(--stamp-deep) 0%, var(--stamp) 60%,
      // var(--primary-lt) 110%)`, `:125`. 135 Grad heißt in CSS: von links
      // oben nach rechts unten. Also **zwei** Vergleiche, waagerecht und
      // senkrecht. Ohne den senkrechten überlebt ein auf 90 Grad geänderter
      // Winkel, der genauso von links nach rechts läuft.
      final (Rect bubble, ByteData pixels, int width) = await paintBubble(
        tester,
      );

      final ({int r, int g, int b}) links = pixelAt(
        pixels,
        width,
        bubble.left + 3,
        bubble.center.dy,
      );
      final ({int r, int g, int b}) rechts = pixelAt(
        pixels,
        width,
        bubble.right - 3,
        bubble.center.dy,
      );
      expect(
        rechts.r,
        greaterThan(links.r + 40),
        reason: 'waagerecht kein Verlauf',
      );

      // x = 200 liegt zwischen dem Ende der Beschriftung und dem Symbol, dort
      // steht keine Glyphe im Weg. Die senkrechte Spanne ist klein, weil die
      // Blase nur 64 Pixel hoch ist: gemessen 216 gegen 230 im Rotkanal.
      final ({int r, int g, int b}) oben = pixelAt(
        pixels,
        width,
        200,
        bubble.top + 3,
      );
      final ({int r, int g, int b}) unten = pixelAt(
        pixels,
        width,
        200,
        bubble.bottom - 3,
      );
      expect(
        unten.r,
        greaterThan(oben.r + 5),
        reason: 'senkrecht kein Verlauf, der Winkel ist waagerecht geworden',
      );
    });

    testWidgets('das helle Ende geht über --stamp hinaus', (tester) async {
      // **Die Zusicherung, für die es diese Gruppe vor allem gibt.** Der
      // dritte Farbstop steht in CSS bei 110 Prozent, sichtbar ist nur der
      // Weg bis 100 Prozent, und der Code rechnet deshalb
      // `Color.lerp(--stamp, --primary-lt, 0.8)`. Wer den Stop stattdessen
      // auf 1,0 kürzt, bekommt am rechten Rand `--stamp` mit Grünwert 56; die
      // Rechnung liefert 97, gemessen kommen 104 an, weil der Schimmer dort
      // noch etwas beiträgt. Die Schwelle 85 trennt beide Fälle mit Abstand
      // nach oben und nach unten.
      final (Rect bubble, ByteData pixels, int width) = await paintBubble(
        tester,
      );

      final ({int r, int g, int b}) ende = pixelAt(
        pixels,
        width,
        bubble.right - 3,
        bubble.center.dy,
      );
      expect(ende.g, greaterThan(85));
      expect(ende.b, greaterThan(30));
    });

    testWidgets('die Lichtkante liegt auf der obersten Zeile', (tester) async {
      // `inset 0 1px 0 rgba(255,255,255,0.12)`, `:127`. `BoxShadow` kann kein
      // `inset`, deshalb ist es eine ein Pixel hohe Linie. Ob die
      // Ersatzlösung wirkt, sieht man nur am Bild: entfernt man sie, ändert
      // sich kein einziges Rechteck.
      final (Rect bubble, ByteData pixels, int width) = await paintBubble(
        tester,
      );

      final ({int r, int g, int b}) kante = pixelAt(
        pixels,
        width,
        200,
        bubble.top,
      );
      final ({int r, int g, int b}) darunter = pixelAt(
        pixels,
        width,
        200,
        bubble.top + 4,
      );
      expect(kante.b, greaterThan(darunter.b + 15));
      expect(kante.g, greaterThan(darunter.g + 12));
    });

    testWidgets('der Schimmer sitzt oben rechts und ist gelb', (tester) async {
      // `radial-gradient(circle, rgba(255,224,102,0.28), transparent 70%)` in
      // einem 110er Kreis mit `top: -30, right: -20`, `:138`.
      //
      // **Der Trick, ohne den diese Zusicherung nicht ginge.** Ein
      // Schimmerpunkt lässt sich nicht gegen einen absoluten Wert prüfen: er
      // liegt über dem Verlauf, und der ist an jeder Stelle ein anderer. Bei
      // einem Verlauf über 135 Grad ist die Farbe aber entlang der Geraden
      // `x + y = konstant` **überall gleich**. Beide Punkte unten haben
      // `x + y = 390`, ihr Untergrund ist also identisch, und was übrig
      // bleibt, ist genau der Schimmer.
      //
      // Gemessen: mit Schimmer 99 gegen 73 im Grünkanal, ohne Schimmer
      // 73 gegen 73, also **bitgleich**. Beide Punkte liegen zudem in einer
      // Lücke, in der weder das Typsymbol noch einer der drei Zierkreise
      // etwas beiträgt.
      final (Rect bubble, ByteData pixels, int width) = await paintBubble(
        tester,
      );

      final ({int r, int g, int b}) nah = pixelAt(pixels, width, 318, 72);
      final ({int r, int g, int b}) fern = pixelAt(pixels, width, 280, 110);

      expect(
        nah.g,
        greaterThan(fern.g + 12),
        reason: 'kein Schimmer, oder er ist nicht mehr gelb',
      );
      expect(nah.b, greaterThan(fern.b + 5));
    });

    testWidgets('die Zierkreise sind da und sind weißlich', (tester) async {
      // Der dritte Kreis, `[78, 88, 12]` in `:131`: 78 Prozent von links,
      // 88 Prozent von oben, 12 Pixel groß. Er ist der einzige der drei, den
      // weder das Typsymbol noch der Schimmer nennenswert überdeckt.
      //
      // Der Vergleichspunkt liegt **rechts** vom Kreis, also dort, wo der
      // Verlauf ohnehin heller ist. Die Zusicherung ist damit vorsichtig: der
      // Kreis muss den Verlauf überstimmen, nicht nur ergänzen.
      final (Rect bubble, ByteData pixels, int width) = await paintBubble(
        tester,
      );

      final double circleCenterX = bubble.left + 0.78 * bubble.width + 6;
      final double circleCenterY = bubble.top + 0.88 * bubble.height + 4;
      final ({int r, int g, int b}) innen = pixelAt(
        pixels,
        width,
        circleCenterX,
        circleCenterY,
      );
      final ({int r, int g, int b}) daneben = pixelAt(
        pixels,
        width,
        circleCenterX + 15,
        circleCenterY,
      );

      expect(
        innen.b,
        greaterThan(daneben.b + 15),
        reason: 'kein Zierkreis, oder er ist nicht weiß',
      );
    });

    testWidgets('die Ecke ist rund und der Schatten liegt darunter', (
      tester,
    ) async {
      // Zwei Werte, die zusammengehören und beide nur im Bild sichtbar sind:
      // `borderRadius: 22` (`:124`) und
      // `boxShadow: '0 12px 28px var(--stamp-glow)'` (`:127`).
      final (Rect bubble, ByteData pixels, int width) = await paintBubble(
        tester,
      );

      // Bei Radius 22 liegt dieser Punkt außerhalb der abgerundeten Ecke, es
      // steht also die Fläche des Blattes da. Mit Radius 0 stünde dort der
      // Verlauf.
      final ({int r, int g, int b}) ecke = pixelAt(
        pixels,
        width,
        bubble.left + 3,
        bubble.top + 3,
      );
      expect(ecke.r, greaterThan(250));
      expect(ecke.g, greaterThan(240));
      expect(
        ecke.b,
        greaterThan(230),
        reason: 'die Ecke ist nicht rund, dort steht der Verlauf',
      );

      // Der Schatten färbt die Fläche unter der Blase rot ein: der Abstand
      // zwischen Rot- und Grünkanal wächst von 7 auf 66. Ohne ihn wären beide
      // Punkte dieselbe Fläche.
      final ({int r, int g, int b}) nah = pixelAt(
        pixels,
        width,
        bubble.center.dx,
        bubble.bottom + 8,
      );
      final ({int r, int g, int b}) fern = pixelAt(
        pixels,
        width,
        bubble.center.dx,
        800,
      );
      expect(nah.r - nah.g, greaterThan(30), reason: 'kein Schatten');
      expect(fern.r - fern.g, lessThan(20), reason: 'sonst prüft nah nichts');
    });
  });

  group('Skalierung', () {
    // Heute ist hier nichts kaputt, gemessen. Die Gruppe steht trotzdem, weil
    // mit Schritt 28 Eingabemasken unter die Kopfzeile kommen und die
    // Rätselfrage länger wird; dann ist sie teurer nachzurüsten als jetzt.
    //
    // Geprüft wird gegen vier Muster aus „Wie Tests hier blind werden":
    // ein Umbruch ist kein Überlauf (1), ein `Stack` clippt lautlos (2),
    // `takeException()` sieht weder Umbruch noch Auslassungszeichen (6).
    // Muster 5, der Tipp ins Leere, trifft hier nicht: dieser Rahmen hat
    // genau einen Knopf, und `hitTestWarningShouldBeFatal` steht oben schon
    // auf `true`.
    for (final double scale in <double>[1, 2]) {
      for (final Size size in <Size>[
        const Size(390, 844),
        const Size(360, 640),
      ]) {
        final String label =
            'Skalierung $scale auf ${size.width.toInt()}x'
            '${size.height.toInt()}';

        testWidgets('$label schneidet nichts ab', (tester) async {
          useTextScale(tester, scale);
          await pumpSheet(
            tester,
            // `kombi` trägt mit „Kombinations-Rätsel" die längste deutsche
            // Typbeschriftung der elf. Mit `kompass` prüfte diese Schleife
            // die Kopfzeile praktisch nicht.
            puzzle: puzzleFixture(
              type: 'kombi',
              question:
                  'Lies das Geburtsjahr von der Sockelinschrift ab, dann das '
                  'Todesjahr, und bilde die Differenz der beiden Zahlen.',
            ),
            size: size,
          );

          expect(tester.takeException(), isNull, reason: label);

          // Kein Absatz ragt seitlich aus dem Bildschirm. Ein `ClipRRect`
          // schneidet lautlos, eine Ausnahme gibt es dabei nicht.
          for (final (RenderParagraph paragraph, Rect rect) in paragraphs(
            tester,
          )) {
            final String text = paragraph.text.toPlainText();
            expect(
              rect.left,
              greaterThanOrEqualTo(-0.01),
              reason: '$label: $text',
            );
            expect(
              rect.right,
              lessThanOrEqualTo(size.width + 0.01),
              reason: '$label: $text',
            );
          }

          // **Die eigentliche Zusicherung dieser Gruppe.** Die Marken-Blase
          // liegt in einem `ClipRRect`; wächst ihr Inhalt über sie hinaus,
          // wird er abgeschnitten, ohne dass irgendetwas meldet. Deshalb
          // müssen Stationszeile, Typbeschriftung und Symbol vollständig
          // innerhalb des Blasen-Rechtecks liegen.
          final Rect bubble = tester.getRect(find.byKey(PuzzleSheet.headerKey));
          for (final Key key in <Key>[
            PuzzleSheet.stationLineKey,
            PuzzleSheet.typeLabelKey,
            PuzzleSheet.typeIconKey,
            PuzzleSheet.closeButtonKey,
          ]) {
            final Rect rect = tester.getRect(find.byKey(key));
            expect(
              rect.top,
              greaterThanOrEqualTo(bubble.top - 0.01),
              reason: '$label: $key oben aus der Blase',
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(bubble.bottom + 0.01),
              reason: '$label: $key unten aus der Blase',
            );
            expect(
              rect.left,
              greaterThanOrEqualTo(bubble.left - 0.01),
              reason: '$label: $key links aus der Blase',
            );
            expect(
              rect.right,
              lessThanOrEqualTo(bubble.right + 0.01),
              reason: '$label: $key rechts aus der Blase',
            );
          }

          // Der Satzspiegel des Inhalts, `padding: '20px 20px 100px'`.
          for (final Key key in <Key>[
            PuzzleSheet.headingKey,
            PuzzleSheet.taskCardKey,
          ]) {
            final Rect rect = tester.getRect(find.byKey(key));
            expect(rect.left, greaterThanOrEqualTo(19.99), reason: label);
            expect(
              rect.right,
              lessThanOrEqualTo(size.width - 19.99),
              reason: label,
            );
          }

          // Die Blase drückt den Inhalt nicht vom Bildschirm. Ohne diese
          // Zeile könnte die Kopfzeile bei doppelter Systemschrift die ganze
          // Höhe belegen und `Expanded` bekäme null Pixel, ohne dass eine
          // Ausnahme fällt.
          expect(
            tester.getSize(find.byKey(PuzzleSheet.contentKey)).height,
            greaterThan(0),
            reason: '$label: kein Platz mehr für den Inhalt',
          );
        });
      }
    }

    testWidgets('die Typbeschriftung darf umbrechen statt abzuschneiden', (
      tester,
    ) async {
      // Gegenprobe zu einem `maxLines: 1` mit `TextOverflow.ellipsis`, das
      // jemand später „gegen den Überlauf" einbaut. Die Quelle setzt beides
      // nicht (`puzzle-sheet.jsx:152`), und ein Auslassungszeichen wäre keine
      // Ausnahme und kein Überlauf, es fiele also sonst niemandem auf
      // (Muster 6).
      useTextScale(tester, 2);
      await pumpSheet(
        tester,
        puzzle: puzzleFixture(type: 'kombi'),
        size: const Size(360, 640),
      );

      final RenderParagraph label = tester.renderObject<RenderParagraph>(
        find.byKey(PuzzleSheet.typeLabelKey),
      );
      expect(label.didExceedMaxLines, isFalse);
      expect(
        label
            .getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: label.text.toPlainText().length,
              ),
            )
            .map((TextBox box) => box.top)
            .toSet()
            .length,
        greaterThan(1),
        reason:
            'bei doppelter Systemschrift muss "Kombinations-Rätsel" '
            'umbrechen, sonst prüft die Zusicherung darüber nichts',
      );
    });
  });

  group('Kein Einstieg', () {
    test('niemand in lib/ baut das Sheet, und niemand öffnet ein Sheet', () {
      // **Warum es keinen Einstieg gibt:** der Öffner ist der Besitzer der
      // Rätsel-Sitzung, und die entsteht erst in Phase 5. Die Quelle hängt das
      // Sheet an eine laufende Schnitzeljagd (`screen-map.jsx:3909`); wer es
      // vorher aufmacht, muss sich Stopp, Stationsindex, Fortschritt und
      // Rückweg ausdenken. Fällt dieser Test, hat jemand einen Einstieg
      // gelegt, und die Frage ist dann, ob er die Sitzung mitgebracht hat.
      //
      // **Was dieser Test nicht kann**, vier Grenzen, jede einzeln:
      //
      //  1. Er ist eine Textsuche und fällt schon bei einer Umbenennung ohne
      //     echten Einstieg.
      //  2. Er sieht keinen Einstieg, der das Sheet über eine Zwischenschicht
      //     baut. Ein `Widget Function()`, das anderswo entsteht und hier nur
      //     aufgerufen wird, kommt an beiden Suchen vorbei.
      //  3. Die Öffner-Suche gilt nur unterhalb von
      //     `lib/features/puzzles/`. Ein `showModalBottomSheet` in einem
      //     fremden Feature fällt allein über die Konstruktorsuche auf, und
      //     die deckt dafür ganz `lib/` ab. Weiter gefasst wäre die
      //     Öffner-Suche nutzlos: `showModalBottomSheet` ist eine gewöhnliche
      //     Flutter-Funktion, die andere Features später zu Recht benutzen.
      //  4. Das Prüfskript hilft hier nicht.
      //     `dart run tool/check_architecture.dart` lief mit der Probe unten
      //     im Baum auf Exit-Code 0 durch, gemessen: `showModalBottomSheet`
      //     ist eine freie Funktion und kein `Navigator.`-Aufruf, und das
      //     Skript sieht ohnehin nur Importe, nie den Dateiinhalt.
      final Iterable<File> dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'));

      final List<String> constructors = <String>[];
      final List<String> openers = <String>[];
      for (final File file in dartFiles) {
        // **Der rohe Dateiinhalt, ohne jede Vorverarbeitung.** Die erste
        // Fassung schnitt Zeilenkommentare weg, damit der Kopfkommentar von
        // `puzzle_sheet.dart` die Suche nicht selbst auslöst. Genau das hat
        // die Wache aushebelbar gemacht, und die Review hat den Weg
        // vorgeführt:
        //
        // ```dart
        // '//r': (Puzzle p) => PuzzleSheet(puzzle: p, stopIndex: 0, …),
        // ```
        //
        // Ein `//` **innerhalb eines Zeichenketten-Literals**, und der
        // Konstruktoraufruf steht dahinter auf derselben Zeile. Die
        // Filterung hat die halbe Zeile verworfen, alle vier Gates standen
        // auf 0, und dieser Test blieb grün. Die alte Begründung, ein
        // Konstruktoraufruf stehe nicht in einer Zeichenkette, stellte die
        // falsche Frage: er muss nicht **in** ihr stehen, nur **hinter** ihr.
        //
        // Deshalb wird nichts mehr weggeschnitten. Der Preis ist ein
        // Fehlalarm, sobald jemand `PuzzleSheet(` in einen Kommentar
        // schreibt. Das ist die richtige Richtung: ein Fehlalarm kostet eine
        // umformulierte Zeile, ein übersehener Einstieg hebelt die
        // Vor-Ort-Mechanik aus.
        final String source = file.readAsStringSync();
        final String path = file.path.replaceAll(r'\', '/');

        // `PuzzleSheet\s*(` trifft auch die Konstruktordeklaration
        // `const PuzzleSheet({`, deshalb die eine Ausnahme.
        if (_constructorCall.hasMatch(source) &&
            !path.endsWith('features/puzzles/presentation/puzzle_sheet.dart')) {
          constructors.add(path);
        }

        // **Mit Klammer**, also der Aufruf und nicht die Erwähnung. Damit
        // braucht diese Suche keine Ausnahme für die Deklarationsdatei: ihr
        // Kopfkommentar nennt den Namen, ruft ihn aber nicht auf. Das
        // schließt zugleich die Lücke, die die Ausnahme oben aufreißt, ein
        // `static show()` **in** `puzzle_sheet.dart` selbst.
        if (path.contains('lib/features/puzzles/') &&
            _modalOpener.hasMatch(source)) {
          openers.add(path);
        }
      }

      expect(constructors, isEmpty);
      expect(openers, isEmpty);
    });
  });
}

/// Ein Aufruf des Konstruktors, `PuzzleSheet(` mit beliebigem Zwischenraum.
final RegExp _constructorCall = RegExp(r'PuzzleSheet\s*\(');

/// Ein **Aufruf** von `showModalBottomSheet`, nicht seine Erwähnung.
final RegExp _modalOpener = RegExp(r'showModalBottomSheet\s*[(<]');
