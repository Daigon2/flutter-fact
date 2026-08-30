import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/features/puzzles/presentation/puzzle_type_look.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Typtabelle der Kopfzeile, `02_Frontend/app/puzzle-sheet.jsx:36-48` und
/// `:67-68`.
void main() {
  AppStrings stringsOf([AppLanguage language = AppLanguage.de]) =>
      AppStrings.of(language);

  group('Die Tabelle', () {
    test('trägt genau die elf Einträge der Quelle, in ihrer Reihenfolge', () {
      expect(puzzleTypeLooks.map((PuzzleTypeLook look) => look.type), <String>[
        'detektiv-zaehlen',
        'inschrift-decoder',
        'foto-beweis',
        'local-fragen',
        'perspektiven',
        'kombi',
        'kompass',
        'verstecktes-detail',
        'klang-sinnes-check',
        'tap-counter',
        'zeitreise',
      ]);
    });

    test('Symbol und Schlüssel stehen paarweise wie in der Quelle', () {
      // Einzeln festgenagelt und nicht über eine Schleife: ein vertauschtes
      // Paar wäre sonst unsichtbar, und die Kopfzeile zeigte zum Kompass ein
      // Ohr.
      expect(
        <String, (String, String)>{
          for (final PuzzleTypeLook look in puzzleTypeLooks)
            look.type: (look.icon, look.labelKey),
        },
        <String, (String, String)>{
          'detektiv-zaehlen': ('🔍', 'puzzle.type.detektiv'),
          'inschrift-decoder': ('📜', 'puzzle.type.inschrift'),
          'foto-beweis': ('📷', 'puzzle.type.foto'),
          'local-fragen': ('💬', 'puzzle.type.local'),
          'perspektiven': ('👁', 'puzzle.type.perspektive'),
          'kombi': ('🧮', 'puzzle.type.kombi'),
          'kompass': ('🧭', 'puzzle.type.kompass'),
          'verstecktes-detail': ('🔎', 'puzzle.type.detail'),
          'klang-sinnes-check': ('👂', 'puzzle.type.sinnes'),
          'tap-counter': ('👆', 'puzzle.type.tap'),
          'zeitreise': ('🕰', 'puzzle.type.zeitreise'),
        },
      );
    });

    test('jeder Schlüssel steht in beiden erzeugten Sprachtabellen', () {
      // Ohne diese Zusicherung landet ein umbenannter Schlüssel als nackter
      // Schlüsseltext in der Kopfzeile, derselbe Fehler wie bei
      // `audio.dialog.volumeHint` (E-28). `hasText` und nicht `text()`, weil
      // `text()` im Debug-Lauf mit einem `assert` abbricht und die Meldung
      // dann nicht sagt, welcher Schlüssel fehlt.
      for (final AppLanguage language in AppLanguage.values) {
        for (final PuzzleTypeLook look in puzzleTypeLooks) {
          expect(
            AppStrings.of(language).hasText(look.labelKey),
            isTrue,
            reason: '${look.labelKey} fehlt in ${language.code}',
          );
        }
      }
    });
  });

  group('Wertgleichheit eines Eintrags', () {
    // Ohne diese Gruppe überlebt `==` auf `identical` reduziert die ganze
    // Rätsel-Suite, gemessen von der Review: die Tabellentests oben
    // vergleichen `(String, String)`-Tupel und nie zwei `PuzzleTypeLook`
    // gegeneinander.

    test('gleicher Inhalt, verschiedene Instanzen, gleich', () {
      // Absichtlich **nicht** `const`: Dart kanonisiert konstante Objekte,
      // und `expect(const X(…), const X(…))` prüft dann nichts, weil beide
      // Seiten dasselbe Objekt sind. Muster 7 aus „Wie Tests hier blind
      // werden", Vorbild `auth_city_test.dart:59`.
      final PuzzleTypeLook left = PuzzleTypeLook(
        type: 'kompass',
        icon: '🧭',
        labelKey: 'puzzle.type.kompass',
      );
      final PuzzleTypeLook right = PuzzleTypeLook(
        type: String.fromCharCodes('kompass'.codeUnits),
        icon: String.fromCharCodes('🧭'.runes),
        labelKey: String.fromCharCodes('puzzle.type.kompass'.codeUnits),
      );

      expect(identical(left, right), isFalse);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('jedes der drei Felder zählt', () {
      const PuzzleTypeLook base = PuzzleTypeLook(
        type: 'kompass',
        icon: '🧭',
        labelKey: 'puzzle.type.kompass',
      );

      expect(
        base,
        isNot(
          const PuzzleTypeLook(
            type: 'kombi',
            icon: '🧭',
            labelKey: 'puzzle.type.kompass',
          ),
        ),
      );
      expect(
        base,
        isNot(
          const PuzzleTypeLook(
            type: 'kompass',
            icon: '🧮',
            labelKey: 'puzzle.type.kompass',
          ),
        ),
      );
      expect(
        base,
        isNot(
          const PuzzleTypeLook(
            type: 'kompass',
            icon: '🧭',
            labelKey: 'puzzle.type.kombi',
          ),
        ),
      );
    });
  });

  group('Auflösung mit Rückfall', () {
    test('ein bekannter Typ bekommt Symbol und übersetzte Beschriftung', () {
      final ({String icon, String label}) meta = puzzleTypeMetaOf(
        'kompass',
        stringsOf(),
      );

      expect(meta.icon, '🧭');
      expect(meta.label, stringsOf().text('puzzle.type.kompass'));
      // Gegenprobe zu einer Abschrift, die den Schlüssel statt des Textes
      // zurückgibt.
      expect(meta.label, isNot('puzzle.type.kompass'));
    });

    test('die Beschriftung folgt der Sprache', () {
      expect(
        puzzleTypeMetaOf('zeitreise', stringsOf(AppLanguage.de)).label,
        'Zeitreise',
      );
      expect(
        puzzleTypeMetaOf('zeitreise', stringsOf(AppLanguage.en)).label,
        'Time Travel',
      );
    });

    test('ein unbekannter Typ bekommt ❓ und den rohen Typ als Text', () {
      // `:67-68`. Für die sechs häufigsten Werte der Live-Daten ist das der
      // Normalfall: zusammen 1469 Vorkommen.
      for (final String type in <String>[
        'vor-ort',
        'inschrift',
        'mcq',
        'perspektive',
        'zaehlen',
        'sinne',
      ]) {
        final ({String icon, String label}) meta = puzzleTypeMetaOf(
          type,
          stringsOf(),
        );
        expect(meta.icon, '❓', reason: type);
        expect(meta.label, type, reason: type);
      }
    });

    test('ein fehlender Typ bekommt ❓ und eine leere Beschriftung', () {
      // In der Quelle liefert der Ausdruck `undefined`, und React zeichnet
      // nichts. Ein Ersatztext wäre erfunden.
      final ({String icon, String label}) meta = puzzleTypeMetaOf(
        null,
        stringsOf(),
      );

      expect(meta.icon, '❓');
      expect(meta.label, '');
    });

    test('der Vergleich ist genau und nicht geglättet', () {
      expect(puzzleTypeMetaOf('Kompass', stringsOf()).icon, '❓');
      expect(puzzleTypeMetaOf(' kompass', stringsOf()).icon, '❓');
    });
  });
}
