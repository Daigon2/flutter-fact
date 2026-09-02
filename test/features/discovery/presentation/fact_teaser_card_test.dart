import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_teaser_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Mini-Vorschau als reines Widget, ohne Provider.
///
/// Was aus einem Tipp überhaupt eine Vorschau macht, prüft
/// `fact_collect_overlay_test.dart`. Hier stehen die Maße, die Texte und die
/// eine Produktregel: **nichts ist anklickbar außer dem Schließen.**
void main() {
  Future<List<int>> pumpCard(
    WidgetTester tester, {
    String title = 'Alter Peter',
    String distanceLine = '🔒 320 m entfernt',
    String hint = 'Hingehen zum Einsammeln',
  }) async {
    final List<int> closes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              left: FactTeaserCard.horizontalInset,
              right: FactTeaserCard.horizontalInset,
              bottom: FactTeaserCard.bottomOffset,
              child: FactTeaserCard(
                style: factCategoryStylesByKey['hist']!,
                title: title,
                distanceLine: distanceLine,
                hint: hint,
                onClose: () => closes.add(1),
              ),
            ),
          ],
        ),
      ),
    );
    // Über die Einblendung hinweg, sonst steht die Karte auf Deckkraft 0 und
    // ein Tipp ginge daneben.
    await tester.pump(FactTeaserCard.fadeIn);
    return closes;
  }

  group('Die Entfernung', () {
    test('unter einem Kilometer in gerundeten Metern, mit Leerzeichen', () {
      // `screen-map.jsx:305-307`. **Mit Leerzeichen vor der Einheit**, anders
      // als `formatHuntPillDistance` in `challenges` (`:1098`). Zwei
      // Schreibweisen derselben Quelle, und sie zusammenzulegen hieße, eine
      // von beiden stillschweigend zu ändern.
      expect(formatFactTeaserDistance(0), '0 m');
      expect(formatFactTeaserDistance(320.4), '320 m');
      expect(formatFactTeaserDistance(999.4), '999 m');
    });

    test('ab einem Kilometer mit einer Nachkommastelle', () {
      expect(formatFactTeaserDistance(1000), '1.0 km');
      expect(formatFactTeaserDistance(1234), '1.2 km');
    });

    test('die Schwelle liegt bei 1000 und ist einschließend nach unten', () {
      // `m < 1000` in der Quelle: 999,5 rundet auf 1000 Meter und bleibt
      // trotzdem in Metern. Das ist die Quelle und kein Versehen.
      expect(formatFactTeaserDistance(999.5), '1000 m');
      expect(formatFactTeaserDistance(1000), '1.0 km');
    });
  });

  group('Was auf der Karte steht', () {
    testWidgets('Zeichen, Entfernungszeile, Titel und Hinweis', (tester) async {
      await pumpCard(tester);

      // Das Zeichen kommt aus der Kategorietabelle und steht hier nicht als
      // abgeschriebene Zeichenkette: sonst prüfte der Test die Tabelle gegen
      // sich selbst.
      expect(find.text(factCategoryStylesByKey['hist']!.emoji), findsOneWidget);
      // `textTransform: 'uppercase'` am Element, `:3887`.
      expect(find.text('🔒 320 M ENTFERNT'), findsOneWidget);
      expect(find.text('Alter Peter'), findsOneWidget);
      expect(find.text('Hingehen zum Einsammeln'), findsOneWidget);
      expect(find.text('×'), findsOneWidget);
    });

    testWidgets('der Titel wird abgeschnitten und bricht nicht um', (
      tester,
    ) async {
      // `whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'`,
      // `:3890`. Ohne das wächst die Karte mit einem langen Titel in die Höhe
      // und schiebt sich über die Tab-Leiste.
      await pumpCard(
        tester,
        title:
            'Ein sehr langer Fakt-Titel, der auf keinen Fall in eine Zeile '
            'passt und deshalb abgeschnitten werden muss',
      );

      final Text title = tester.widget<Text>(find.textContaining('sehr lang'));
      expect(title.maxLines, 1);
      expect(title.softWrap, isFalse);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bei Schrift 2.0 auf 320 Pixeln läuft nichts über', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320 * 3, 640 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpCard(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('Die Produktregel: nur das Schließen ist anklickbar', () {
    testWidgets('das × schließt', (tester) async {
      final List<int> closes = await pumpCard(tester);

      await tester.tap(find.text('×'));
      await tester.pump();

      expect(closes, hasLength(1));
    });

    testWidgets('auch die Fläche neben dem × schließt', (tester) async {
      // **`HitTestBehavior.opaque`**, eine bezahlte Lehre aus der Jagd-Pille:
      // ohne sie reagiert nur das Zeichen selbst und nicht die 32 Pixel
      // Fläche, obwohl in der Quelle das ganze `div` klickbar ist.
      final List<int> closes = await pumpCard(tester);

      final Rect box = tester.getRect(
        find.ancestor(
          of: find.text('×'),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.tapAt(Offset(box.left + 2, box.top + 2));
      await tester.pump();

      expect(closes, hasLength(1));
    });

    testWidgets('ein Tipp auf den Titel schließt nichts und öffnet nichts', (
      tester,
    ) async {
      // Der Kommentar der Quelle, `:3882-3885`: „KEIN onClick mehr. Die
      // Vorschau IST das Erlebnis fuer entfernte Fakten; der Detail-Screen
      // darf nur vor Ort geoeffnet werden, sonst kann man die Stadt vom Sofa
      // aus durchlesen."
      final List<int> closes = await pumpCard(tester);

      await tester.tap(find.text('Alter Peter'), warnIfMissed: false);
      await tester.pump();

      expect(closes, isEmpty);
      expect(find.byType(FactTeaserCard), findsOneWidget);
    });

    testWidgets('es gibt genau einen Gesten-Empfänger in der Karte', (
      tester,
    ) async {
      // Die Gegenprobe zur Regel: ein zweiter wäre der Einstieg in die Akte,
      // den es hier nicht geben darf.
      await pumpCard(tester);

      expect(
        find.descendant(
          of: find.byType(FactTeaserCard),
          matching: find.byType(GestureDetector),
        ),
        findsOneWidget,
      );
    });
  });
}
