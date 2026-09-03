import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings_supplement.dart';
import 'package:fact_app/app/localization/generated/app_strings_de.g.dart';
import 'package:fact_app/app/localization/generated/app_strings_en.g.dart';
import 'package:fact_app/features/collection/application/generated/wallet_categories.g.dart';
import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/collection/presentation/library_chapter_look.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Farben eines Kapitels, seine römische Zahl und seine Seitenzahl.
void main() {
  group('Kapitelfassung', () {
    test('alle elf Kapitel haben eine Fassung', () {
      expect(libraryChapterLooks.keys.toSet(), libraryCategoryOrder.toSet());
      expect(libraryChapterLooks.length, 11);
    });

    test('die Farben der sechs kommen aus der Reiseführer-Tabelle', () {
      final LibraryChapterLook hist = libraryChapterLookOf('hist');

      expect(hist.glyph, '§');
      expect(hist.color, const Color(0xFFE8380D));
      expect(hist.darkColor, const Color(0xFFA82508));
    });

    test(
      'die Zeichen der sechs sind die des Reiseführers, nicht der Karte',
      () {
        // Der Kommentar der Quelle sagt, warum es die Tabelle gibt: „die
        // Reiseführer-Optik will andere Glyphen als das normale `window.CAT`".
        // Auf der Karte trägt ein Geo-Ballon ein Emoji, hier steht ein Dreieck.
        expect(libraryChapterLookOf('geo').glyph, '△');
        expect(libraryChapterLookOf('heute').glyph, '◉');
        expect(libraryChapterLookOf('myth').glyph, '☾');
      },
    );

    test('die fünf neuen tragen Farbe und Zeichen der Karte', () {
      // Aus `screen-map.jsx:195-208`, weil `WalletCats` sie nicht kennt: der
      // Reiseführer der Quelle hat nur sechs Kapitel, für die fünf neuen gibt
      // es dort keine Optik, die man abschreiben könnte.
      expect(libraryChapterLookOf('kul').color, const Color(0xFFF97316));
      expect(libraryChapterLookOf('pers').glyph, '👤');
      expect(libraryChapterLookOf('kult').color, const Color(0xFFF59E0B));
      expect(libraryChapterLookOf('dark').darkColor, const Color(0xFF1E293B));
      expect(libraryChapterLookOf('kirche').glyph, '⛪');
    });

    test('die sechs der Quelle stehen nicht in der Zusatztabelle', () {
      // Sichtbare Folge der Entscheidung zu E-78: sechs Kapitel tragen
      // Schriftzeichen, fünf ein Emoji. Festgehalten, damit es eine
      // Feststellung bleibt und keine Überraschung am Gerät.
      for (final String key in walletCategoryOrder) {
        expect(
          libraryExtraChapterLooks.containsKey(key),
          isFalse,
          reason: '$key gehört der Quelle und nicht den fünf neuen',
        );
      }
      expect(libraryExtraChapterLooks.length, 5);
      expect(
        libraryExtraChapterLooks.keys.toSet(),
        libraryExtraCategories.toSet(),
      );
    });

    test('Fassungen haben Wertgleichheit', () {
      expect(libraryChapterLookOf('hist'), libraryChapterLookOf('hist'));
      expect(
        libraryChapterLookOf('hist').hashCode,
        libraryChapterLookOf('hist').hashCode,
      );
      expect(libraryChapterLookOf('hist'), isNot(libraryChapterLookOf('arch')));
    });
  });

  group('Die Namen der Kapitel', () {
    test('jedes der elf hat einen Namen in beiden Sprachen', () {
      // **Der Unterschied zu E-63 und E-73.** Die Quelle schreibt
      // `t('cat.' + catKey) || c.kategorie`, und das `||` kann nie feuern. Bei
      // den sechs der Quelle richtet das keinen Schaden an, weil ihre
      // Schlüssel existieren. **Bei den fünf neuen wäre genau das der Fehler
      // geworden**, deshalb läuft der Name über `libraryChapterNameKey` und
      // nicht über `'cat.$key'`: `kirche` heißt im Wörterbuch `cat.chr`, und
      // `kult` und `dark` stehen in der handgepflegten Ergänzung.
      for (final String key in libraryCategoryOrder) {
        final String nameKey = libraryChapterNameKey(key);
        for (final AppLanguage language in AppLanguage.values) {
          final Map<String, String> generated = language == AppLanguage.de
              ? appTextsDe
              : appTextsEn;
          expect(
            generated.containsKey(nameKey) ||
                supplementTextsFor(language).containsKey(nameKey),
            isTrue,
            reason: '$nameKey fehlt in ${language.code}',
          );
        }
      }
    });

    test('kirche wird auf cat.chr abgebildet, alle anderen direkt', () {
      expect(libraryChapterNameKey('kirche'), 'cat.chr');
      expect(libraryChapterNameKey('hist'), 'cat.hist');
      expect(libraryChapterNameKey('kult'), 'cat.kult');
      // Und der Beleg, dass die Abbildung nötig ist: die Kartentabelle nennt
      // den Schlüssel `kirche`, das Wörterbuch führt ihn als `chr`.
      expect(appTextsDe.containsKey('cat.kirche'), isFalse);
      expect(appTextsDe.containsKey('cat.chr'), isTrue);
    });

    test('drei Namen kamen aus der Quelle, zwei aus der Ergänzung', () {
      // Das war beim Fragen zu E-78 das Argument, das die Entscheidung billig
      // gemacht hat: drei der fünf Namen lagen schon zweisprachig vor. Für
      // `kult` und `dark` liefert die Aliastabelle der Karte beide Sprachen
      // als Paar, deshalb stehen sie in der Ergänzung und **nicht** in den
      // erzeugten Tabellen.
      for (final String key in <String>['kul', 'pers', 'chr']) {
        expect(appTextsDe.containsKey('cat.$key'), isTrue, reason: key);
        expect(appTextsEn.containsKey('cat.$key'), isTrue, reason: key);
      }
      for (final String key in <String>['kult', 'dark']) {
        expect(appTextsDe.containsKey('cat.$key'), isFalse, reason: key);
        expect(
          supplementTextsFor(AppLanguage.de).containsKey('cat.$key'),
          isTrue,
          reason: key,
        );
      }
      expect(supplementTextsFor(AppLanguage.de)['cat.kult'], 'Kunst & Kultur');
      expect(supplementTextsFor(AppLanguage.en)['cat.kult'], 'Art & Culture');
    });

    test('die Kapitelnamen sind in beiden Sprachen verschieden', () {
      expect(appTextsDe['cat.hist'], 'Historisch');
      expect(appTextsEn['cat.hist'], isNot('Historisch'));
      expect(AppLanguage.values.length, 2);
    });
  });

  group('Römische Zahlen', () {
    test('die elf, die der Reiseführer braucht', () {
      expect(
        List<int>.generate(
          11,
          (int i) => i + 1,
        ).map(libraryRomanNumeral).toList(),
        <String>[
          'I',
          'II',
          'III',
          'IV',
          'V',
          'VI',
          'VII',
          'VIII',
          'IX',
          'X',
          'XI',
        ],
      );
    });

    test('die Subtraktionsregeln der Tabelle', () {
      // Die vollständige Tabelle der Quelle ist übernommen, obwohl elf Kapitel
      // nur bis XI zählen. Diese Zusicherungen prüfen genau die Einträge, die
      // eine gekürzte Tabelle verlieren würde.
      expect(libraryRomanNumeral(4), 'IV');
      expect(libraryRomanNumeral(9), 'IX');
      expect(libraryRomanNumeral(40), 'XL');
      expect(libraryRomanNumeral(90), 'XC');
      expect(libraryRomanNumeral(400), 'CD');
      expect(libraryRomanNumeral(900), 'CM');
      expect(libraryRomanNumeral(1994), 'MCMXCIV');
      expect(libraryRomanNumeral(2026), 'MMXXVI');
    });

    test('null und darunter ergeben nichts, wie in der Quelle', () {
      expect(libraryRomanNumeral(0), '');
      expect(libraryRomanNumeral(-3), '');
    });
  });

  group('Seitenzahlen', () {
    List<LibraryChapter> chaptersWith(List<int> collected) => <LibraryChapter>[
      for (int i = 0; i < collected.length; i++)
        LibraryChapter(
          categoryKey: libraryCategoryOrder[i],
          collected: collected[i],
          total: collected[i] + 1,
        ),
    ];

    test('das erste Kapitel fängt auf Seite eins an', () {
      expect(libraryChapterStartPages(chaptersWith(<int>[3])), <int>[1]);
    });

    test('gezählt werden nur die gesammelten Fakten', () {
      // 3 gesammelte im ersten Kapitel, also fängt das zweite auf Seite 4 an,
      // obwohl das erste vier Fakten **hat**. Das Buch enthält nur, was
      // gelesen ist.
      expect(libraryChapterStartPages(chaptersWith(<int>[3, 2, 5])), <int>[
        1,
        4,
        6,
      ]);
    });

    test('ein Kapitel ohne gesammelten Fakt verbraucht keine Seite', () {
      expect(libraryChapterStartPages(chaptersWith(<int>[2, 0, 0, 3])), <int>[
        1,
        3,
        3,
        3,
      ]);
    });

    test('ohne alles bleibt jede Seite die erste', () {
      expect(libraryChapterStartPages(chaptersWith(<int>[0, 0, 0])), <int>[
        1,
        1,
        1,
      ]);
    });

    test('eine leere Liste ergibt keine Seiten', () {
      expect(libraryChapterStartPages(<LibraryChapter>[]), isEmpty);
    });

    test('über alle elf Kapitel läuft die Zählung durch', () {
      expect(
        libraryChapterStartPages(
          chaptersWith(<int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
        ),
        <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
      );
    });
  });
}
