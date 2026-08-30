import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/app_strings_supplement.dart';
import 'package:fact_app/app/localization/generated/app_strings_index.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verhalten der handgepflegten Ergänzung (E-39).
///
/// Die Gegenprüfung gegen die PWA gehört bewusst **nicht** hierher, sondern in
/// `tool/generate_i18n.dart`. Ein Test, der die PWA braucht, würde `flutter
/// test` auf jedem Rechner ohne Lese-Repo rot machen, und der Generator ist
/// die Stelle, an der die Quelle ohnehin schon offen liegt.
void main() {
  group('Bestand', () {
    test('jede ausgelieferte Sprache hat eine Ergänzung', () {
      for (final language in AppLanguage.values) {
        expect(
          supplementTextsByLanguage.containsKey(language),
          isTrue,
          reason: 'keine Ergänzung für ${language.code}',
        );
      }
    });

    test('alle Sprachen tragen denselben Schlüsselsatz', () {
      final reference = supplementTextsFor(
        AppLanguage.values.first,
      ).keys.toSet();
      for (final language in AppLanguage.values) {
        expect(
          supplementTextsFor(language).keys.toSet(),
          reference,
          reason: 'Ergänzung von ${language.code} weicht ab',
        );
      }
    });

    test('die Ergänzung trägt genau die sechsunddreißig belegten Schlüssel', () {
      // Wächst diese Menge, gehört jeder neue Eintrag zu einem Text, den die
      // PWA sichtbar anzeigt, ohne ihn als Schlüssel zu führen. Alles andere
      // gehört in die Quelle. Die beiden Meta-Zeilen kamen am 28.08.2026 mit
      // dem Tutorial-Overlay dazu, `tour_steps.dart`. Die beiden
      // `fact.`-Schlüssel am 29.08.2026 mit der Fakt-Akte,
      // `screen-fact.jsx:367` und `:474`. Die vier `puzzle.`-Schlüssel am
      // 30.08.2026 mit dem Rätsel-Sheet, `puzzle-sheet.jsx:150`, `:165`,
      // `:176` und `:194`. Die zwölf `challenge.`-Schlüssel mit dem
      // Schnitzeljagd-Assistenten, `screen-challenge.jsx:1545`, `:1551`,
      // `:1574-1576`, `:1660`, `:1851-1867`, `:1896`, `:1900-1902`, `:1912`
      // und `:1986`. Die fünfzehn `challenge.hotspot.`-Schlüssel am
      // 30.08.2026 mit dem Startpunkt-Picker, `screen-challenge.jsx:3005-3007`,
      // `:3015-3018`, `:3025`, `:3034`, `:3046`, `:3055`, `:3057`, `:3059`,
      // `:3093` und `:4348-4350`. **Vierzehn davon sind auf Englisch
      // hergeleitet und warten auf Freigabe (E-46)**, nur
      // `challenge.hotspot.noFacts` steht in beiden Sprachen in der Quelle.
      expect(supplementTextsFor(AppLanguage.de).keys.toSet(), {
        'tour.stepCounter',
        'tour.step1.meta',
        'tour.step9.meta',
        'fact.fileNumber',
        'fact.sourceMissing',
        'puzzle.stationCounter',
        'puzzle.riddleCounter',
        'puzzle.taskLabel',
        'puzzle.photoCaption',
        'challenge.bubbleTitle',
        'challenge.setup.easyDesc',
        'challenge.setup.mediumDesc',
        'challenge.setup.hardDesc',
        'challenge.setup.durationLabel',
        'challenge.setup.durationCard',
        'challenge.setup.stopsSuffix',
        'challenge.setup.topicsLabel',
        'challenge.setup.topicsClear',
        'challenge.setup.topicsHintOne',
        'challenge.setup.topicsHintMany',
        'challenge.setup.startCta',
        'challenge.hotspot.here',
        'challenge.hotspot.densityLocalHigh',
        'challenge.hotspot.densityLocalMedium',
        'challenge.hotspot.densityLocalLow',
        'challenge.hotspot.densityVeryHigh',
        'challenge.hotspot.densityHigh',
        'challenge.hotspot.densityMedium',
        'challenge.hotspot.density',
        'challenge.hotspot.walkMinutes',
        'challenge.hotspot.stepCounter',
        'challenge.hotspot.title',
        'challenge.hotspot.subtitle',
        'challenge.hotspot.startCta',
        'challenge.hotspot.empty',
        'challenge.hotspot.noFacts',
      });
    });

    test('kein Ergänzungs-Schlüssel steht in den erzeugten Tabellen', () {
      // Zweite Verteidigungslinie zur Prüfung im Generator: die greift nur,
      // wenn jemand den Generator startet, dieser Test bei jedem `flutter
      // test`. Er sieht allerdings nur den erzeugten Stand, nicht die PWA.
      for (final language in AppLanguage.values) {
        final generated = generatedTextsByLanguage[language.code]!;
        for (final key in supplementTextsFor(language).keys) {
          expect(
            generated.containsKey(key),
            isFalse,
            reason: '"$key" kommt in ${language.code} schon aus der Quelle',
          );
        }
      }
    });

    test('kein Ergänzungs-Wert ist leer', () {
      for (final language in AppLanguage.values) {
        for (final entry in supplementTextsFor(language).entries) {
          expect(entry.value, isNotEmpty, reason: entry.key);
        }
      }
    });
  });

  group('Schrittanzeige des Tutorials', () {
    test('liefert den Wortlaut der Quelle in beiden Sprachen', () {
      // `screen-tour.jsx:483`, hartcodierter Ternär, Großschreibung wie dort.
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('tour.stepCounter', params: {'step': '3', 'total': '9'}),
        'SCHRITT 3 VON 9',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('tour.stepCounter', params: {'step': '3', 'total': '9'}),
        'STEP 3 OF 9',
      );
    });

    test('ein vergessener Platzhalter fällt im Debug-Lauf auf', () {
      // Dieselbe Zusicherung wie für erzeugte Texte: `_interpolate` prüft am
      // Ende, dass keine Klammer stehen geblieben ist.
      expect(
        () => AppStrings.of(
          AppLanguage.de,
        ).text('tour.stepCounter', params: {'step': '3'}),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => AppStrings.of(AppLanguage.de).text('tour.stepCounter'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('hasText kennt den Ergänzungs-Schlüssel', () {
      for (final language in AppLanguage.values) {
        expect(AppStrings.of(language).hasText('tour.stepCounter'), isTrue);
      }
    });

    test('textKeys bleibt die reine PWA-Fläche', () {
      // Die Ergänzung darf die Paritätszahlen nicht verschieben, sonst
      // verliert `app_strings_parity_test.dart` seine Aussage.
      expect(
        AppStrings.of(AppLanguage.de).textKeys.contains('tour.stepCounter'),
        isFalse,
      );
    });
  });

  group('Die Fakt-Akte', () {
    test('die Aktennummer steht in beiden Sprachen deutsch da', () {
      // `screen-fact.jsx:367`: `Akte #{fact.nr || fact.id}` steht wörtlich
      // im JSX und wird auch im englischen Modus so gezeigt. Derselbe Fall
      // wie `tour.step9.meta`. Fiele der englische Eintrag weg, käme über
      // den Rückfall zwar derselbe Text heraus; die Zusicherung gilt
      // deshalb der Karte selbst und nicht nur dem Ergebnis von `text()`.
      for (final language in AppLanguage.values) {
        expect(
          supplementTextsFor(language)['fact.fileNumber'],
          'Akte #{nr}',
          reason: language.code,
        );
        expect(
          AppStrings.of(
            language,
          ).text('fact.fileNumber', params: {'nr': 'MUC_004'}),
          'Akte #MUC_004',
          reason: language.code,
        );
      }
    });

    test('die Platzhalterzeile ist je Sprache eine andere', () {
      // `screen-fact.jsx:474`, beide Wortlaute stehen dort. Gegenprobe zu
      // einer Abschrift, die beide Karten gleich füllt wie bei der
      // Aktennummer.
      expect(
        supplementTextsFor(AppLanguage.de)['fact.sourceMissing'],
        'Quelle fehlt',
      );
      expect(
        supplementTextsFor(AppLanguage.en)['fact.sourceMissing'],
        'Source missing',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('fact.sourceMissing'),
        'Source missing',
      );
    });

    test('beide Schlüssel bleiben aus der PWA-Fläche heraus', () {
      for (final language in AppLanguage.values) {
        for (final key in <String>['fact.fileNumber', 'fact.sourceMissing']) {
          expect(AppStrings.of(language).hasText(key), isTrue, reason: key);
          expect(
            AppStrings.of(language).textKeys.contains(key),
            isFalse,
            reason: key,
          );
        }
      }
    });
  });

  group('Das Rätsel-Sheet', () {
    test('die Stationszeile ist in beiden Sprachen dieselbe', () {
      // `puzzle-sheet.jsx:150`:
      // `(lang === 'de' ? 'Station ' : 'Station ') + (stopIdx + 1)`. Der
      // Ternär hat in beiden Zweigen dasselbe Wort. Derselbe Fall wie
      // `fact.fileNumber`; die Zusicherung gilt der Karte selbst, weil über
      // den Rückfall sonst zufällig dasselbe herauskäme.
      for (final language in AppLanguage.values) {
        expect(
          supplementTextsFor(language)['puzzle.stationCounter'],
          'Station {station}',
          reason: language.code,
        );
        expect(
          AppStrings.of(
            language,
          ).text('puzzle.stationCounter', params: {'station': '3'}),
          'Station 3',
          reason: language.code,
        );
      }
    });

    test('die Überschrift ist je Sprache eine andere', () {
      // `:165`, beide Wortlaute stehen dort. Gegenprobe zu einer Abschrift,
      // die beide Karten gleich füllt wie bei der Stationszeile.
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('puzzle.riddleCounter', params: {'number': '3'}),
        'Rätsel 3',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('puzzle.riddleCounter', params: {'number': '3'}),
        'Riddle 3',
      );
    });

    test('Aufgaben-Beschriftung und Foto-Leiste bleiben deutsch', () {
      // `:194` und `:176` sind nackte Textknoten ohne Ternär; die Quelle
      // zeigt sie auch im englischen Modus deutsch.
      for (final language in AppLanguage.values) {
        expect(
          AppStrings.of(language).text('puzzle.taskLabel'),
          'Aufgabe',
          reason: language.code,
        );
        expect(
          AppStrings.of(language).text('puzzle.photoCaption'),
          // Der Gedankenstrich steht so in der Verhaltensquelle und wird
          // wortgleich übernommen.
          'Damals — was hat sich verändert?',
          reason: language.code,
        );
      }
    });

    test('die vier Schlüssel bleiben aus der PWA-Fläche heraus', () {
      for (final language in AppLanguage.values) {
        for (final key in <String>[
          'puzzle.stationCounter',
          'puzzle.riddleCounter',
          'puzzle.taskLabel',
          'puzzle.photoCaption',
        ]) {
          expect(AppStrings.of(language).hasText(key), isTrue, reason: key);
          expect(
            AppStrings.of(language).textKeys.contains(key),
            isFalse,
            reason: key,
          );
        }
      }
    });
  });

  group('Der Schnitzeljagd-Assistent', () {
    // Zwölf Schlüssel, und für elf davon hat die Quelle **zwei**
    // Wortlaute. Geprüft wird deshalb jeder einzeln und in beiden Sprachen:
    // die beiden teuersten Verwechslungen dieses Bildschirms sind Schlüssel,
    // die es schon gibt und die etwas anderes sagen.

    test('der Titel der Blase ist in beiden Sprachen derselbe', () {
      // `screen-challenge.jsx:964` als Vorgabewert und `:1660` beim Aufruf,
      // beide Male wörtlich `'Challenge'`. Die Zusicherung gilt der Karte
      // selbst, weil über den Rückfall sonst zufällig dasselbe
      // herauskäme.
      for (final language in AppLanguage.values) {
        expect(
          supplementTextsFor(language)['challenge.bubbleTitle'],
          'Challenge',
          reason: language.code,
        );
      }
    });

    test('der Titel ist nicht die Beschriftung des Reiters', () {
      // `tab.challenge` trägt dasselbe Wort für ein anderes Element. Fällt
      // der Ergänzungs-Schlüssel weg und jemand nimmt den Reiter, ist das
      // heute unsichtbar und beim ersten Umbenennen ein Fehler.
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).textKeys.contains('challenge.bubbleTitle'),
        isFalse,
      );
      expect(AppStrings.of(AppLanguage.de).hasText('tab.challenge'), isTrue);
    });

    test('die drei Schwierigkeitsbeschreibungen im Wortlaut der Quelle', () {
      // `:1851-1853`, `:1858-1860`, `:1865-1867`.
      const Map<String, String> de = <String, String>{
        'challenge.setup.easyDesc':
            'Pfeil und Distanz weisen dir den Weg. Ideal für die erste '
            'Erkundung.',
        'challenge.setup.mediumDesc':
            'Nur Distanz, kein Pfeil. Für neugierige Stadtkenner.',
        'challenge.setup.hardDesc':
            'Nur das Rätsel, keine Navi. Pro Station kannst du Hinweise '
            'kaufen. Nur für echte Locals.',
      };
      const Map<String, String> en = <String, String>{
        'challenge.setup.easyDesc':
            'Arrow and distance guide you. Perfect for a first exploration.',
        'challenge.setup.mediumDesc':
            'Distance only, no arrow. For the curious city-savvy.',
        'challenge.setup.hardDesc':
            'Riddles only, no navigation. Buy hints per stop if stuck. Only '
            'for true locals.',
      };
      de.forEach((String key, String value) {
        expect(AppStrings.of(AppLanguage.de).text(key), value, reason: key);
      });
      en.forEach((String key, String value) {
        expect(AppStrings.of(AppLanguage.en).text(key), value, reason: key);
      });
    });

    test('die langen Beschreibungen sind nicht die kurzen aus der Quelle', () {
      // `challenge.easyDesc` und Geschwister gehören zur Tabelle `SNJD_DIFF`
      // (`:153-169`), also zum alten Demo-Pfad, und tragen kürzere Sätze.
      // Beide Fassungen stehen gleichzeitig in der PWA.
      for (final String stamm in <String>['easy', 'medium', 'hard']) {
        expect(
          AppStrings.of(AppLanguage.de).text('challenge.setup.${stamm}Desc'),
          isNot(AppStrings.of(AppLanguage.de).text('challenge.${stamm}Desc')),
          reason: stamm,
        );
      }
    });

    test('Dauer-Überschrift und Dauer-Karte', () {
      // `:1896` und `:1900-1902`. Die Karte trägt in beiden Sprachen `min`.
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.setup.durationLabel'),
        'Dauer',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.setup.durationLabel'),
        'Duration',
      );
      for (final language in AppLanguage.values) {
        expect(
          AppStrings.of(
            language,
          ).text('challenge.setup.durationCard', params: {'minutes': '60'}),
          '60 min',
          reason: language.code,
        );
      }
    });

    test('die Schnitzeljagd zählt Stationen, nicht Stopps', () {
      // `:1912` gegen `tour.stopsSuffix`. Die beiden Wörter zu vertauschen
      // ändert kein Layout und keine Zahl, nur den Text.
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.setup.stopsSuffix'),
        'Stationen',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.setup.stopsSuffix'),
        'stops',
      );
      expect(AppStrings.of(AppLanguage.de).text('tour.stopsSuffix'), 'Stopps');
    });

    test('der Kopf des Themen-Filters und der Alle-Knopf', () {
      // `:1545` und `:1551`.
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.setup.topicsLabel'),
        'Themen (optional)',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.setup.topicsLabel'),
        'Topics (optional)',
      );
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.setup.topicsClear'),
        'Alle',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.setup.topicsClear'),
        'All',
      );
    });

    test('Einzahl und Mehrzahl der Hinweiszeile', () {
      // `:1574-1576`. Der Gedankenstrich steht so in der Quelle.
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.setup.topicsHintOne', params: {'count': '1'}),
        '1 Thema ausgewählt — weniger Fakten verfügbar',
      );
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.setup.topicsHintMany', params: {'count': '3'}),
        '3 Themen ausgewählt — weniger Fakten verfügbar',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.setup.topicsHintOne', params: {'count': '1'}),
        'Filtering by 1 topic — fewer facts available',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.setup.topicsHintMany', params: {'count': '3'}),
        'Filtering by 3 topics — fewer facts available',
      );
    });

    test('der Startknopf sagt Starten und nicht Schnitzeljagd starten', () {
      // `:1986` gegen `challenge.cta.start`, das die lange Fassung mit Pfeil
      // trägt und zum alten Setup-Bildschirm gehört.
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.setup.startCta'),
        'Starten',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.setup.startCta'),
        'Start',
      );
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.cta.start'),
        'Schnitzeljagd starten →',
      );
    });

    test('ein vergessener Platzhalter fällt im Debug-Lauf auf', () {
      expect(
        () =>
            AppStrings.of(AppLanguage.de).text('challenge.setup.durationCard'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => AppStrings.of(
          AppLanguage.de,
        ).text('challenge.setup.topicsHintMany'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('die zwölf Schlüssel bleiben aus der PWA-Fläche heraus', () {
      for (final language in AppLanguage.values) {
        for (final key in supplementTextsFor(
          language,
        ).keys.where((String key) => key.startsWith('challenge.'))) {
          expect(AppStrings.of(language).hasText(key), isTrue, reason: key);
          expect(
            AppStrings.of(language).textKeys.contains(key),
            isFalse,
            reason: key,
          );
        }
      }
    });
  });

  group('Suchreihenfolge', () {
    // An echten Daten nicht nachweisbar: die Ergänzung trägt per Konstruktion
    // nur Schlüssel, die in keiner erzeugten Tabelle stehen. Deshalb hier mit
    // gestellten Tabellen gegen `AppStrings.debugResolve`, also gegen genau
    // die Funktion, die `text()` benutzt.
    const key = 'demo.key';

    test('der erzeugte Wert schlägt den gleichnamigen Ergänzungs-Wert', () {
      expect(
        AppStrings.debugResolve(
          key,
          texts: const {key: 'aus der Quelle'},
          supplement: const {key: 'handgepflegt'},
          fallbackTexts: const {},
          fallbackSupplement: const {},
        ),
        'aus der Quelle',
      );
    });

    test(
      'die Ergänzung der gewählten Sprache kommt vor der Fallback-Sprache',
      () {
        expect(
          AppStrings.debugResolve(
            key,
            texts: const {},
            supplement: const {key: 'gewählte Sprache, handgepflegt'},
            fallbackTexts: const {key: 'Fallback, erzeugt'},
            fallbackSupplement: const {key: 'Fallback, handgepflegt'},
          ),
          'gewählte Sprache, handgepflegt',
        );
      },
    );

    test('die Fallback-Ergänzung ist die letzte Station', () {
      expect(
        AppStrings.debugResolve(
          key,
          texts: const {},
          supplement: const {},
          fallbackTexts: const {},
          fallbackSupplement: const {key: 'Fallback, handgepflegt'},
        ),
        'Fallback, handgepflegt',
      );
    });

    test('ohne Treffer bleibt es null, und darauf schlägt der assert an', () {
      expect(
        AppStrings.debugResolve(
          key,
          texts: const {},
          supplement: const {},
          fallbackTexts: const {},
          fallbackSupplement: const {},
        ),
        isNull,
      );
      expect(
        () => AppStrings.of(AppLanguage.de).text('gibt.es.wirklich.nicht'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
