import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/generated/app_strings_de.g.dart';
import 'package:fact_app/app/localization/generated/app_strings_en.g.dart';
import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/collection/presentation/library_chapter_look.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Farben eines Kapitels und die römische Zahl.
void main() {
  group('Kapitelfassung', () {
    test('alle sechs Kapitel haben eine Fassung', () {
      expect(libraryChapterLooks.keys.toSet(), libraryCategoryOrder.toSet());
      expect(libraryChapterLooks.length, 6);
    });

    test('die Farben kommen aus der Quelle', () {
      final LibraryChapterLook hist = libraryChapterLookOf('hist');

      expect(hist.glyph, '§');
      expect(hist.color, const Color(0xFFE8380D));
      expect(hist.darkColor, const Color(0xFFA82508));
    });

    test('die Zeichen sind die des Reiseführers und nicht die der Karte', () {
      // Der Kommentar der Quelle sagt, warum es die Tabelle gibt: „die
      // Reiseführer-Optik will andere Glyphen als das normale `window.CAT`".
      // Auf der Karte trägt ein Geo-Ballon 🌍, hier steht ein Dreieck.
      expect(libraryChapterLookOf('geo').glyph, '△');
      expect(libraryChapterLookOf('heute').glyph, '◉');
      expect(libraryChapterLookOf('myth').glyph, '☾');
    });

    test('jedes Kapitel hat einen i18n-Namen, der Rückfall ist unnötig', () {
      // **Der Unterschied zu E-63 und E-73.** Die Quelle schreibt
      // `t('cat.' + catKey) || c.kategorie`, und das `||` kann nie feuern.
      // Hier richtet das keinen Schaden an, weil alle sechs Schlüssel
      // existieren. Ohne diesen Test wäre das eine Behauptung.
      for (final String key in libraryCategoryOrder) {
        expect(
          appTextsDe.containsKey('cat.$key'),
          isTrue,
          reason: 'cat.$key fehlt auf Deutsch',
        );
        expect(
          appTextsEn.containsKey('cat.$key'),
          isTrue,
          reason: 'cat.$key fehlt auf Englisch',
        );
      }
    });

    test('drei Namen für E-78 liegen schon übersetzt vor, zwei nicht', () {
      // Das Argument, das E-78 für den Eigentümer billiger macht: von den
      // fünf Kategorien, die im Reiseführer in „Historisch" fallen, haben
      // drei bereits einen übersetzten Namen und zwei nicht.
      for (final String key in <String>['kul', 'pers', 'chr']) {
        expect(appTextsDe.containsKey('cat.$key'), isTrue, reason: key);
        expect(appTextsEn.containsKey('cat.$key'), isTrue, reason: key);
      }
      for (final String key in <String>['kult', 'dark', 'kirche']) {
        expect(appTextsDe.containsKey('cat.$key'), isFalse, reason: key);
      }
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

  group('Römische Zahlen', () {
    test('die sechs, die der Reiseführer braucht', () {
      expect(
        <int>[1, 2, 3, 4, 5, 6].map(libraryRomanNumeral).toList(),
        <String>['I', 'II', 'III', 'IV', 'V', 'VI'],
      );
    });

    test('die Subtraktionsregeln der Tabelle', () {
      // Die vollständige Tabelle der Quelle ist übernommen, obwohl sechs
      // Kapitel nur bis VI zählen. Diese Zusicherungen prüfen genau die
      // Einträge, die eine gekürzte Tabelle verlieren würde.
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
  });

  group('Sprachen', () {
    test('die Kapitelnamen sind beide Sprachen und nicht dieselben', () {
      expect(appTextsDe['cat.hist'], 'Historisch');
      expect(appTextsEn['cat.hist'], isNot('Historisch'));
      expect(AppLanguage.values.length, 2);
    });
  });
}
