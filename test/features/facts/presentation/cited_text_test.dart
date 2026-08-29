import 'package:fact_app/features/facts/presentation/cited_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Zerlegen des Fakttexts, `02_Frontend/app/screen-fact.jsx:3-48`.
///
/// Diese Datei prüft die einzige Stelle des Bildschirms, an der aus Text
/// Struktur wird. Sie ist bewusst ohne Widget-Baum: dass `[12]` die zwölfte
/// Quelle meint und nicht die Ziffern 1 und 2, sieht man einer gerenderten
/// Fläche nicht an.
void main() {
  group('parseCitedText', () {
    test('leerer und fehlender Text ergeben nichts', () {
      expect(parseCitedText(null), isEmpty);
      expect(parseCitedText(''), isEmpty);
    });

    test('Text ohne Referenz bleibt ein Stück', () {
      expect(parseCitedText('Ein Satz ohne Quelle.'), <CitedSegment>[
        const CitedRun('Ein Satz ohne Quelle.'),
      ]);
    });

    test('eine Referenz am Satzende trennt Text und Ziffer', () {
      expect(parseCitedText('Napoleon gehört.[1]'), <CitedSegment>[
        const CitedRun('Napoleon gehört.'),
        const CitedReference(1),
      ]);
    });

    test('mehrere Referenzen bleiben in der Reihenfolge des Texts', () {
      expect(parseCitedText('a[1]b[3]c'), <CitedSegment>[
        const CitedRun('a'),
        const CitedReference(1),
        const CitedRun('b'),
        const CitedReference(3),
        const CitedRun('c'),
      ]);
    });

    test('zwei Referenzen nebeneinander erzeugen kein leeres Stück', () {
      // Die Quelle liefert an dieser Stelle einen leeren String mit, weil
      // `split` mit Fanggruppe das tut. React zeigt ihn nicht an, ein leerer
      // `TextSpan` hier hätte ebenfalls keinen Zweck.
      expect(parseCitedText('[1][2]'), <CitedSegment>[
        const CitedReference(1),
        const CitedReference(2),
      ]);
    });

    test('eine zweistellige Referenz ist eine Zahl und nicht zwei Ziffern', () {
      // Der Fund, für den es diesen Test gibt: `[12]` zeigt auf die zwölfte
      // Quelle. Eine ziffernweise Auswertung ergäbe zwei Hochziffern und
      // träfe die erste und die zweite Quelle.
      final List<CitedSegment> segments = parseCitedText('x[12]');

      expect(segments, hasLength(2));
      expect(segments.last, const CitedReference(12));
      expect((segments.last as CitedReference).sourceIndex, 11);
      expect((segments.last as CitedReference).label, '[12]');
    });

    test(
      'die Referenz ist eins-basiert, der Platz in der Liste null-basiert',
      () {
        // `screen-fact.jsx:9`: `parseInt(m[1], 10) - 1`.
        expect(const CitedReference(1).sourceIndex, 0);
        expect(const CitedReference(4).sourceIndex, 3);
      },
    );

    test('Klammern ohne Ziffern sind keine Referenz', () {
      for (final String text in <String>['[a]', '[]', '[ 1 ]', '[1', '1]']) {
        expect(parseCitedText(text), <CitedSegment>[
          CitedRun(text),
        ], reason: text);
      }
    });

    test('der Text um die Referenz bleibt zeichengenau erhalten', () {
      // Eine Mutation, die den Text trimmt oder die Klammern mitnimmt, fiele
      // in den Tests oben nicht auf.
      expect(parseCitedText('vor [1] nach'), <CitedSegment>[
        const CitedRun('vor '),
        const CitedReference(1),
        const CitedRun(' nach'),
      ]);
    });
  });

  group('highestSourceReference', () {
    test('ohne Text und ohne Referenz ist es null', () {
      expect(highestSourceReference(<String?>[]), 0);
      expect(highestSourceReference(<String?>[null, null]), 0);
      expect(highestSourceReference(<String?>['Ein Satz ohne Beleg.']), 0);
    });

    test('eine einzelne Referenz zählt sich selbst', () {
      expect(highestSourceReference(<String?>['Mit Beleg.[1]']), 1);
    });

    test('gezählt wird die höchste, nicht die letzte und nicht die Anzahl', () {
      // Gegenprobe gleich in zwei Richtungen: eine Umsetzung, die die letzte
      // Referenz nimmt, käme auf 2, eine, die zählt, auf 3.
      expect(highestSourceReference(<String?>['[1] dann [3] dann [2]']), 3);
    });

    test('mehrstellige Referenzen zählen als eine Zahl', () {
      // `[12]` ist die zwölfte Quelle und nicht die Ziffern 1 und 2.
      expect(highestSourceReference(<String?>['Beleg[12]']), 12);
    });

    test('gesucht wird über alle Textfelder, nicht nur über das erste', () {
      // `:52`: `[fact.text, fact.text2, fact.text3, fact.text4]`. Steht die
      // höchste Referenz in `text4`, muss die Liste trotzdem so weit reichen.
      expect(
        highestSourceReference(<String?>['[1]', null, '[2]', 'zuletzt [7]']),
        7,
      );
    });

    test('ein Feld ohne Fließtext zählt trotzdem mit', () {
      // Die Quelle prüft weder `showMore` noch `isRealProse`. Ein noch
      // eingeklappter Absatz darf die Liste nicht wachsen lassen, sobald der
      // Nutzer aufklappt.
      const String eingeklappt = 'Nachdenklichkeit[4]';
      expect(isRealProse(eingeklappt), isFalse);
      expect(
        highestSourceReference(<String?>['Erster Absatz.[1]', eingeklappt]),
        4,
      );
    });

    test('was keine Referenz ist, zählt nicht', () {
      expect(
        highestSourceReference(<String?>['[a] [ 1 ] [] [-2] Hinweis [1]']),
        1,
      );
    });
  });

  group('isRealProse', () {
    test('das Emotion-Tag zählt nicht als Absatz', () {
      // Der Anlass des Filters, `screen-fact.jsx:39-43`: `text2` trug in
      // vielen Weimar-Fakten nur ein einzelnes Wort.
      for (final String tag in <String>[
        'Nachdenklichkeit',
        'Staunen',
        'Trauer',
      ]) {
        expect(isRealProse(tag), isFalse, reason: tag);
      }
    });

    test('lang genug, aber ein einziges Wort: kein Absatz', () {
      // 30 Zeichen ohne Leerraum. Prüft die zweite Hälfte der Bedingung
      // getrennt von der ersten.
      expect(isRealProse('a' * 30), isFalse);
    });

    test('mehrere Wörter, aber zu kurz: kein Absatz', () {
      expect('kurz und knapp'.length, lessThan(26));
      expect(isRealProse('kurz und knapp'), isFalse);
    });

    test('die Grenze liegt bei mehr als 25 Zeichen, nicht bei 25', () {
      final String exactly25 = '${'a' * 23} b';
      expect(exactly25.length, 25);
      expect(isRealProse(exactly25), isFalse);
      expect(isRealProse('${exactly25}c'), isTrue);
    });

    test('gemessen wird am getrimmten Text', () {
      // 25 Zeichen plus Leerraum außen: die Quelle trimmt vor beiden
      // Prüfungen (`:46-47`), der Leerraum außen macht daraus also keinen
      // Absatz.
      expect(isRealProse('   ${'a' * 23} b   '), isFalse);
    });

    test('null und leer sind kein Absatz', () {
      expect(isRealProse(null), isFalse);
      expect(isRealProse(''), isFalse);
      expect(isRealProse('   '), isFalse);
    });

    test('ein echter Absatz zählt', () {
      expect(
        isRealProse('Caesar starb, weil einer von ihnen genau zielte.'),
        isTrue,
      );
    });
  });
}
