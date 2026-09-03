import 'dart:async';

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/collection/application/library_reader.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_reader_look.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_reader_footer.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_reader_view.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/services/speech/speech_providers.dart';
import 'package:fact_app/services/speech/speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Die Buchseite, `02_Frontend/app/screen-wallet.jsx:1413-1824`.
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
    collected: 3,
    total: 20,
  );

  Fact factWith({
    required int id,
    String title = 'Der Alte Peter',
    String? body,
    String? bodyExtra,
    String? bodyBackground,
    String? bodyToday,
    String category = 'Historisch',
  }) => Fact(
    id: FactId(id),
    content: FactText(
      title: title,
      body: body,
      bodyExtra: bodyExtra,
      bodyBackground: bodyBackground,
      bodyToday: bodyToday,
      category: category,
    ),
    city: FactCity('München'),
  );

  late RecordingSpeechService speech;

  setUp(() => speech = RecordingSpeechService());
  tearDown(() => speech.close());

  Future<void> pumpReader(
    WidgetTester tester, {
    required LibraryReaderPage page,
    VoidCallback? onBack,
    void Function(FactId)? onOpenFact,
    AppLanguage language = AppLanguage.de,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 1200) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
          speechServiceProvider.overrideWithValue(speech),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? FactTheme.light()
              : FactTheme.dark(),
          home: Scaffold(
            body: LibraryReaderView(
              volume: munich,
              page: page,
              onBack: onBack,
              onOpenFact: onOpenFact ?? (FactId _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Eine Seite mit [fact] als einziger, also ohne Nachbarn.
  LibraryReaderPage single(Fact fact) =>
      LibraryReaderPage(fact: fact, number: 1, count: 1);

  group('Inhalt', () {
    testWidgets('der Titel steht da', (tester) async {
      await pumpReader(
        tester,
        page: single(factWith(id: 1, title: 'Der Alte Peter')),
      );

      expect(find.text('Der Alte Peter'), findsOneWidget);
    });

    testWidgets('die Initiale ist der erste Buchstabe in 64 Punkt', (
      tester,
    ) async {
      await pumpReader(
        tester,
        page: single(
          factWith(
            id: 1,
            body: 'Ein Turm stand hier seit dem zwölften Jahrhundert.',
          ),
        ),
      );

      final Text text = tester.widget<Text>(
        find.byKey(LibraryReaderView.bodyKey),
      );
      final TextSpan span = text.textSpan! as TextSpan;
      final TextSpan initial = span.children!.first as TextSpan;
      final TextSpan rest = span.children!.last as TextSpan;

      expect(initial.text, 'E');
      // Ausgeschrieben und nicht aus der Konstante gelesen: siehe den Kopf von
      // `library_reader_test.dart`.
      expect(initial.style!.fontSize, 64);
      expect(
        rest.text,
        'in Turm stand hier seit dem zwölften Jahrhundert.',
        reason: 'Der Rest fängt nach dem ersten Zeichen an.',
      );
    });

    testWidgets('die Zitat-Hochziffern fallen aus dem Fließtext', (
      tester,
    ) async {
      // Auf der Buchseite gibt es keine Quellenliste, auf die sie zeigen
      // könnten. Gemessener Defekt der Quelle, siehe `fact_prose.dart`.
      await pumpReader(
        tester,
        page: single(
          factWith(
            id: 1,
            body: 'Der Turm [3] wurde 1180 zum ersten Mal erwähnt [12].',
          ),
        ),
      );

      final Text text = tester.widget<Text>(
        find.byKey(LibraryReaderView.bodyKey),
      );
      final TextSpan span = text.textSpan! as TextSpan;
      final TextSpan rest = span.children!.last as TextSpan;

      expect(rest.text, 'er Turm wurde 1180 zum ersten Mal erwähnt.');
      expect(rest.text, isNot(contains('[')));
    });

    testWidgets('ein Fakt ohne Fließtext zeigt keinen ersten Absatz', (
      tester,
    ) async {
      await pumpReader(tester, page: single(factWith(id: 1)));

      expect(find.byKey(LibraryReaderView.bodyKey), findsNothing);
      expect(find.text('Der Alte Peter'), findsOneWidget);
    });

    testWidgets('der zweite Absatz braucht Fließtext und kein Emotion-Tag', (
      tester,
    ) async {
      // Der Anlass des Filters: `text2` trug in vielen Weimar-Fakten nur ein
      // internes Stichwort. `isRealProse` verlangt mehr als 25 Zeichen **und**
      // ein Leerzeichen.
      await pumpReader(
        tester,
        page: single(
          factWith(id: 1, body: 'Ein Satz.', bodyExtra: 'Nachdenklichkeit'),
        ),
      );

      expect(find.byKey(LibraryReaderView.paragraphKey(2)), findsNothing);
      expect(find.text('Nachdenklichkeit'), findsNothing);
    });

    testWidgets('der zweite Absatz steht da, wenn er echter Fließtext ist', (
      tester,
    ) async {
      await pumpReader(
        tester,
        page: single(
          factWith(
            id: 1,
            body: 'Ein Satz.',
            bodyExtra: 'Ein zweiter Absatz mit genug Text darin.',
          ),
        ),
      );

      expect(find.byKey(LibraryReaderView.paragraphKey(2)), findsOneWidget);
      expect(
        find.text('Ein zweiter Absatz mit genug Text darin.'),
        findsOneWidget,
      );
    });

    testWidgets('der dritte Absatz ist kursiv und leicht durchsichtig', (
      tester,
    ) async {
      await pumpReader(
        tester,
        page: single(
          factWith(id: 1, body: 'Ein Satz.', bodyBackground: 'Hintergrund.'),
        ),
      );

      final Finder paragraph = find.byKey(LibraryReaderView.paragraphKey(3));
      expect(paragraph, findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Hintergrund.')).style!.fontStyle,
        FontStyle.italic,
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: paragraph, matching: find.byType(Opacity)),
            )
            .opacity,
        0.88,
      );
    });

    testWidgets('der dritte Absatz nimmt jeden Text, nicht nur Fließtext', (
      tester,
    ) async {
      // Die Quelle prüft nur `text2` auf Fließtext (`:1653`) und `text3` bloß
      // auf Vorhandensein (`:1658`). Übernommen, weil der Anlass des Filters
      // für `text3` nicht gemessen ist.
      await pumpReader(
        tester,
        page: single(
          factWith(id: 1, body: 'Ein Satz.', bodyBackground: 'Kurz'),
        ),
      );

      expect(find.text('Kurz'), findsOneWidget);
    });

    testWidgets('der vierte Absatz bekommt einen Balken in der Stadtfarbe', (
      tester,
    ) async {
      await pumpReader(
        tester,
        page: single(
          factWith(id: 1, body: 'Ein Satz.', bodyToday: 'Heute steht hier.'),
        ),
      );

      final Finder paragraph = find.byKey(LibraryReaderView.paragraphKey(4));
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(of: paragraph, matching: find.byType(DecoratedBox)),
      );
      final Border border = (box.decoration as BoxDecoration).border! as Border;

      expect(border.left.color, const Color(0xFF1E5FAD));
      expect(border.left.width, 3);
    });

    testWidgets('die Kategorie-Pille zeigt Zeichen und Namen in Großschrift', (
      tester,
    ) async {
      await pumpReader(
        tester,
        page: single(factWith(id: 1, category: 'Historisch')),
      );

      // **Das Schriftzeichen und nicht das Emoji.** Die Karte nimmt
      // `CAT.emoji` (🏛), der Reiseführer `WalletCats.glyph` (§). Zwei
      // Zeichensätze für dieselben Kategorien, und die Quelle benutzt sie
      // getrennt: das Emoji auf dem Ballon, das Schriftzeichen im Buch.
      expect(find.byKey(LibraryReaderView.categoryKey), findsOneWidget);
      expect(find.text('§ HISTORISCH'), findsOneWidget);
    });

    testWidgets('auf Englisch steht der englische Kategoriename da', (
      tester,
    ) async {
      await pumpReader(
        tester,
        page: single(factWith(id: 1)),
        language: AppLanguage.en,
      );

      expect(find.text('§ HISTORICAL'), findsOneWidget);
    });
  });

  group('Blättern', () {
    LibraryReaderPage middle() => LibraryReaderPage(
      fact: factWith(id: 20, title: 'Mitte'),
      previous: factWith(id: 10),
      next: factWith(id: 30),
      number: 2,
      count: 3,
    );

    testWidgets('die Seitenzahl nennt Stand und Umfang', (tester) async {
      await pumpReader(tester, page: middle());

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('der Weiter-Knopf öffnet den Nachfolger', (tester) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.tap(find.byKey(LibraryReaderFooter.nextKey));
      await tester.pump();

      expect(geoeffnet, <int>[30]);
    });

    testWidgets('der Zurück-Knopf öffnet den Vorgänger', (tester) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.tap(find.byKey(LibraryReaderFooter.previousKey));
      await tester.pump();

      expect(geoeffnet, <int>[10]);
    });

    testWidgets('am Anfang der Folge ist der Zurück-Knopf blass und stumm', (
      tester,
    ) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: LibraryReaderPage(
          fact: factWith(id: 10),
          next: factWith(id: 20),
          number: 1,
          count: 2,
        ),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.tap(find.byKey(LibraryReaderFooter.previousKey));
      await tester.pump();

      expect(geoeffnet, isEmpty);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.byKey(LibraryReaderFooter.previousKey),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0.25,
        reason: 'Der Knopf verschwindet nicht, er wird blass.',
      );
    });

    testWidgets('am Ende der Folge ist der Weiter-Knopf blass und stumm', (
      tester,
    ) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: LibraryReaderPage(
          fact: factWith(id: 20),
          previous: factWith(id: 10),
          number: 2,
          count: 2,
        ),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.tap(find.byKey(LibraryReaderFooter.nextKey));
      await tester.pump();

      expect(geoeffnet, isEmpty);
    });

    testWidgets('Wischen nach links blättert vorwärts', (tester) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.fling(
        find.byKey(LibraryReaderView.titleKey),
        const Offset(-200, 0),
        800,
      );
      await tester.pump();

      expect(geoeffnet, <int>[30]);
    });

    testWidgets('Wischen nach rechts blättert zurück', (tester) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.fling(
        find.byKey(LibraryReaderView.titleKey),
        const Offset(200, 0),
        800,
      );
      await tester.pump();

      expect(geoeffnet, <int>[10]);
    });

    testWidgets('ein Tipp auf das linke Seitendrittel blättert zurück', (
      tester,
    ) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      // 390 Pixel breit, 20 Prozent davon sind 78. Die Grenze liegt bei 28
      // Prozent.
      await tester.tapAt(const Offset(78, 600));
      await tester.pump();

      expect(geoeffnet, <int>[10]);
    });

    testWidgets('ein Tipp auf das rechte Seitendrittel blättert vorwärts', (
      tester,
    ) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      // 90 Prozent von 390 sind 351, die Grenze liegt bei 72 Prozent.
      await tester.tapAt(const Offset(351, 600));
      await tester.pump();

      expect(geoeffnet, <int>[30]);
    });

    testWidgets('ein Tipp in die Mitte blättert nicht', (tester) async {
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      // 50 Prozent von 390 sind 195, also zwischen beiden Grenzen.
      await tester.tapAt(const Offset(195, 600));
      await tester.pump();

      expect(geoeffnet, isEmpty);
    });

    testWidgets('knapp rechts der linken Grenze blättert nicht', (
      tester,
    ) async {
      // 35 Prozent von 390 sind 136,5. Die Grenze liegt bei 28 Prozent, also
      // bei 109. Ohne diesen Test bliebe eine Grenze bei 50 Prozent
      // unentdeckt.
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.tapAt(const Offset(137, 600));
      await tester.pump();

      expect(geoeffnet, isEmpty);
    });

    testWidgets('knapp links der rechten Grenze blättert nicht', (
      tester,
    ) async {
      // 65 Prozent von 390 sind 253,5. Die Grenze liegt bei 72 Prozent, also
      // bei 281.
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.tapAt(const Offset(253, 600));
      await tester.pump();

      expect(geoeffnet, isEmpty);
    });

    testWidgets('ein kurzer Zug ist kein Blättern', (tester) async {
      // Die Quelle verwirft unter 50 Pixeln (`:1537`). 30 sind zu wenig.
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.drag(
        find.byKey(LibraryReaderView.titleKey),
        const Offset(-30, 0),
      );
      await tester.pump();

      expect(geoeffnet, isEmpty);
    });

    testWidgets('ein langsamer, langer Zug blättert trotzdem', (tester) async {
      // Entschieden wird über die **Strecke** und nicht über die
      // Geschwindigkeit: `drag` legt die Strecke ohne Schwung zurück.
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: middle(),
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.drag(
        find.byKey(LibraryReaderView.titleKey),
        const Offset(-80, 0),
      );
      await tester.pump();

      expect(geoeffnet, <int>[30]);
    });

    testWidgets('der Fortschrittsbalken zeigt den Anteil der Seite', (
      tester,
    ) async {
      await pumpReader(tester, page: middle());

      expect(
        tester
            .widget<FractionallySizedBox>(
              find.descendant(
                of: find.byKey(LibraryReaderFooter.progressKey),
                matching: find.byType(FractionallySizedBox),
              ),
            )
            .widthFactor,
        closeTo(0.6667, 0.0001),
        reason: 'Seite 2 von 3.',
      );
    });
  });

  group('Kopfreihe', () {
    testWidgets('der Zurück-Weg meldet sich', (tester) async {
      var zurueck = 0;
      await pumpReader(
        tester,
        page: single(factWith(id: 1)),
        onBack: () => zurueck++,
      );

      await tester.tap(find.byKey(LibraryReaderView.backKey));
      await tester.pump();

      expect(zurueck, 1);
    });

    testWidgets('der Zurück-Weg blättert nicht mit', (tester) async {
      // Der Knopf sitzt im linken Seitendrittel. Ohne die Gesten-Arena wäre
      // ein Tipp darauf gleichzeitig ein Zurückblättern.
      final List<int> geoeffnet = <int>[];
      await pumpReader(
        tester,
        page: LibraryReaderPage(
          fact: factWith(id: 20),
          previous: factWith(id: 10),
          number: 2,
          count: 2,
        ),
        onBack: () {},
        onOpenFact: (FactId id) => geoeffnet.add(id.value),
      );

      await tester.tap(find.byKey(LibraryReaderView.backKey));
      await tester.pump();

      expect(geoeffnet, isEmpty);
    });

    testWidgets('der Vorlese-Knopf schickt den Text ohne Hochziffern', (
      tester,
    ) async {
      await pumpReader(
        tester,
        page: single(
          factWith(
            id: 1,
            title: 'Der Alte Peter',
            body: 'Der Turm [3] wurde 1180 erwähnt.',
          ),
        ),
      );

      await tester.tap(find.byKey(LibraryReaderView.listenKey));
      await tester.pump();

      expect(speech.spoken, <String>[
        'Der Alte Peter. Der Turm wurde 1180 erwähnt.|de-DE',
      ]);
    });
  });

  group('Papier', () {
    testWidgets('hell ist Buchpapier und nicht die Flächenfarbe des Themes', (
      tester,
    ) async {
      await pumpReader(tester, page: single(factWith(id: 1)));

      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(
                    of: find.byType(LibraryReaderView),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .color,
        const Color(0xFFF7F1E6),
      );
    });

    testWidgets('dunkel ist die Seite dunkelbraun und die Schrift hell', (
      tester,
    ) async {
      await pumpReader(
        tester,
        page: single(factWith(id: 1, body: 'Ein Satz über den Turm hier.')),
        brightness: Brightness.dark,
      );

      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(
                    of: find.byType(LibraryReaderView),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .color,
        const Color(0xFF1C1712),
      );
      expect(
        tester.widget<Text>(find.byKey(LibraryReaderView.bodyKey)).style!.color,
        const Color(0xFFC8B898),
      );
    });

    testWidgets('die Palette kennt genau zwei Fassungen', (tester) async {
      expect(
        LibraryReaderPalette.of(Brightness.light),
        same(LibraryReaderPalette.light),
      );
      expect(
        LibraryReaderPalette.of(Brightness.dark),
        same(LibraryReaderPalette.dark),
      );
    });
  });
}

/// Ein Sprachdienst, der nur mitschreibt.
class RecordingSpeechService implements SpeechService {
  final StreamController<SpeechState> _states =
      StreamController<SpeechState>.broadcast();

  /// Jeder Vortrag als `Text|Sprache`.
  final List<String> spoken = <String>[];

  /// Schließt den Strom.
  void close() => _states.close();

  @override
  Stream<SpeechState> stateUpdates() => _states.stream;

  @override
  Future<void> speak({
    required String text,
    required String languageTag,
    double rate = defaultSpeechRate,
  }) async => spoken.add('$text|$languageTag');

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}
}
