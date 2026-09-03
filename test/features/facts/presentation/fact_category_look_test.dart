import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/facts/presentation/fact_category_look.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Kategoriefassung der Akte.
///
/// Diese Datei hat zwei Aufgaben, und die zweite ist die wichtigere:
///
/// 1. Die Zuordnung Kategorietext auf Fassung gegen
///    `02_Frontend/app/screen-fact.jsx:245-250` festnageln.
/// 2. **Die Doppelung zur Ballon-Tabelle in `discovery` bewachen.** Beide
///    Tabellen schreiben `CAT` aus `screen-map.jsx:195-208` ab, und Regel 8
///    der `dependency-rules.md` lässt die eine die andere nicht lesen. Ein
///    `lib`-Test könnte diesen Vergleich gar nicht anstellen, ein Test darf
///    es: die Prüfung fremder Feature-Schichten greift laut
///    `tool/check_architecture.dart:1136` nur unterhalb von `lib/`.
void main() {
  group('Zuordnung, screen-fact.jsx:245-250', () {
    test('die neun Einträge der Quelle treffen ihre Fassung', () {
      const Map<String, String> expected = <String, String>{
        'Historisch': 'hist',
        'Architektur': 'arch',
        'Fun-Fact': 'fun',
        'Geographie': 'geo',
        'Geografie': 'geo',
        'Mythos': 'myth',
        'Natur': 'nat',
        'Kulinarik': 'kul',
        'Stadt heute': 'heute',
      };

      expect(factCategoryLookAliases, expected);
      expected.forEach((String label, String key) {
        expect(factCategoryLookOf(label).key, key, reason: label);
      });
    });

    test('ein unbekannter Text fällt auf hist', () {
      // `CAT[…] || CAT.hist` in `:249-250`. Der Fakt verschwindet nicht, er
      // wird rot.
      for (final String label in <String>[
        '',
        'Persönlichkeiten',
        'Kunst & Kultur',
        'Dunkel & Kriminell',
        'Kirche & Glaube',
        'historisch',
        'Historisch ',
      ]) {
        expect(factCategoryLookOf(label).key, 'hist', reason: label);
      }
    });

    test('die Fassung trägt Zeichen und beide Farben', () {
      final FactCategoryLook hist = factCategoryLookOf('Historisch');

      expect(hist.emoji, '🏛');
      expect(hist.color.toARGB32(), 0xFFE8380D);
      expect(hist.darkColor.toARGB32(), 0xFFA82508);
    });
  });

  group('Die Doppelung zur Ballon-Tabelle', () {
    test('jede Fassung der Akte ist Zeichen für Zeichen die des Ballons', () {
      // Läuft diese Zusicherung, ist bewiesen, dass zwei unabhängige
      // Abschriften derselben Quelle übereinstimmen. Ohne sie könnte ein Fakt
      // auf der Karte pink und in der Akte rot sein, ohne dass etwas anschlägt.
      expect(factCategoryLooks, isNotEmpty);
      for (final FactCategoryLook look in factCategoryLooks) {
        final FactCategoryStyle? style = factCategoryStylesByKey[look.key];
        expect(style, isNotNull, reason: look.key);
        expect(look.emoji, style!.emoji, reason: look.key);
        expect(look.color, style.color, reason: look.key);
        expect(look.darkColor, style.darkColor, reason: look.key);
      }
    });

    test('die Akte kennt genau die acht Kategorien mit i18n-Schlüssel', () {
      // Der Grund für die kleinere Tabelle, und er ist messbar: `pers`,
      // `kult`, `dark` und `kirche` haben keinen `cat.`-Schlüssel. Wer sie
      // hier aufnimmt, zeigt dem Nutzer den nackten Schlüssel.
      expect(
        factCategoryLooks.map((FactCategoryLook l) => l.key).toList(),
        <String>['hist', 'myth', 'fun', 'geo', 'arch', 'nat', 'kul', 'heute'],
      );

      for (final AppLanguage language in AppLanguage.values) {
        final AppStrings strings = AppStrings.of(language);
        for (final FactCategoryLook look in factCategoryLooks) {
          expect(
            strings.hasText('cat.${look.key}'),
            isTrue,
            reason: 'cat.${look.key} in ${language.code}',
          );
        }
      }
    });

    test('von den vier Lücken sind seit dem 03.09.2026 zwei geschlossen', () {
      // **Dieser Test war ein Stolperdraht und hat ausgelöst.** Er stand hier
      // mit der Ansage: „Bekommt die PWA die Schlüssel nachträglich, fällt
      // dieser Test und die Tabelle darf wachsen."
      //
      // Ausgelöst hat ihn nicht die PWA, sondern die Entscheidung zu E-78:
      // der Reiseführer bekam eigene Kapitel für Kultur und Dunkel &
      // Kriminell, und weil die PWA für beide den nackten Schlüssel anzeigt,
      // sind sie in `app_strings_supplement.dart` gelandet. Damit haben sie
      // Text, nur nicht aus den erzeugten Tabellen.
      final AppStrings strings = AppStrings.of(AppLanguage.de);

      expect(strings.hasText('cat.kult'), isTrue);
      expect(strings.hasText('cat.dark'), isTrue);

      // **`kirche` bleibt die Lücke**, und zwar aus einem anderen Grund als
      // vorher: das Wörterbuch führt „Kirche & Glaube" unter `cat.chr`,
      // während die Kategorietabelle den Schlüssel `kirche` benutzt. Es fehlt
      // kein Text, es fehlt die Abbildung. Der Reiseführer hat sie in
      // `libraryChapterNameKey`; die Akte hätte sie noch nicht.
      expect(strings.hasText('cat.kirche'), isFalse);
      expect(strings.hasText('cat.chr'), isTrue);

      // `pers` war schon immer der Sonderfall: den Schlüssel gibt es, die
      // Akte erreicht ihn trotzdem nicht, weil ihre eigene Zuordnungstabelle
      // "Persönlichkeiten" nicht kennt.
      expect(strings.hasText('cat.pers'), isTrue);
      expect(factCategoryLookAliases.containsKey('Persönlichkeiten'), isFalse);
    });

    test('die Akte zeigt für Kultur weiter Historisch, der Führer nicht', () {
      // **Die Folge, die dieser Test sichtbar hält, und sie ist unschön.**
      // Derselbe Fakt heißt jetzt an drei Stellen dreierlei: der Ballon auf
      // der Karte trägt die Kultur-Farbe, die Akte sagt „Historisch", und der
      // Reiseführer sagt „Kunst & Kultur".
      //
      // Die Akte **könnte** das jetzt richtig zeigen, ihre Tabelle darf laut
      // dem Test darüber wachsen. Sie tut es bewusst noch nicht: das ist eine
      // sichtbare Verhaltensänderung in einem fertigen Bildschirm und gehört
      // als eigener Schritt entschieden, nicht als Nebenwirkung der
      // Kapitel-Arbeit. Steht als E-81 im Register.
      expect(factCategoryLookOf('Kunst & Kultur').key, 'hist');
      expect(factCategoryLookAliases.containsKey('Kunst & Kultur'), isFalse);
    });
  });
}
