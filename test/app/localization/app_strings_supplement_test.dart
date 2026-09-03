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

    test('die Ergänzung trägt genau die neunundsechzig belegten Schlüssel', () {
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
      // Die sechs `challenge.huntPill.`-Schlüssel kamen am 02.09.2026 mit
      // Schritt 37 dazu, `screen-map.jsx:1036-1130`. Die zweiundzwanzig
      // `challenge.huntPause.`- und `challenge.huntResult.`-Schlüssel kamen
      // mit Schritt 39 dazu, `screen-challenge.jsx:2797-2980`.
      // **`wallet.shelfVolumeLabel` kam am 03.09.2026 mit Schritt 45 dazu**,
      // `screen-wallet.jsx:968`. Die Vorlesehilfe eines Buchrückens steht
      // dort als hartcodierter deutscher Satz im `aria-label`, ohne `t()`,
      // und trifft damit genau die Nutzer, die sie am wenigsten umgehen
      // können. Der englische Wert ist deshalb nach E-61 übersetzt.
      // Mit dem Cover kamen am selben Tag `wallet.coverBrand`
      // (`screen-wallet.jsx:531`, ein hartcodiertes „FACT
      // Reiseführer") und `wallet.statSincePlaceholder`
      // (`:551`) dazu.
      //
      // **`audio.dialog.volumeHint` kam am 02.09.2026 dazu und ist von allen
      // anderen verschieden** (E-28, `screen-auth.jsx:251`). Alle übrigen
      // schreiben ab, was die PWA sichtbar anzeigt, ohne es als Schlüssel zu
      // führen. Dieser trägt einen Text, den die Quelle **überhaupt nicht
      // hat**: sie zeigt dort den Schlüsselnamen. Und er war lange der
      // einzige mit zwei wirklich verschiedenen Sprachwerten, weil alle
      // anderen Blöcke aus demselben deutschen Wert in beiden Karten
      // bestanden.
      //
      // **Das ist seit dem 02.09.2026 nicht mehr so.** Bis dahin trugen die
      // sechs `challenge.huntPill.`- und die zweiundzwanzig
      // `challenge.huntPause.`-/`challenge.huntResult.`-Schlüssel in beiden
      // Karten denselben deutschen Wert, mit der Begründung, die Quelle zeige
      // diese Texte auch im englischen Modus deutsch (E-61). Der Eigentümer
      // hat diese Begründung als Regel grundsätzlich aufgehoben: sie war ein
      // gemessener Defekt der Quelle und keine Parität. Die englische Karte
      // trägt jetzt für fast alle diese Schlüssel einen eigenen Wortlaut;
      // welche wenigen weiterhin denselben Wert tragen und warum, steht
      // begründet in der Ausnahmeliste des Tests „kein englischer Wert
      // bleibt versehentlich deutsch" gleich im Anschluss. Die vierzehn
      // englisch hergeleiteten `challenge.hotspot.`-Werte aus E-46 warten
      // weiterhin auf Freigabe; diese Zählprobe prüft ohnehin nur den
      // Bestand und keine Werte.
      //
      // **`map.teaser.locationUnknown` kam am 02.09.2026 mit Schritt 20 dazu**,
      // `screen-map.jsx:3856-3858`. Er gehört zur ersten Gruppe und nicht zu
      // `audio.dialog.volumeHint`: beide Sprachen stehen wörtlich in der
      // Quelle, sie führt den Text nur nicht als Schlüssel.
      expect(supplementTextsFor(AppLanguage.de).keys.toSet(), {
        'audio.dialog.volumeHint',
        'tour.stepCounter',
        'tour.step1.meta',
        'tour.step9.meta',
        'fact.fileNumber',
        'fact.sourceMissing',
        'map.teaser.locationUnknown',
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
        'challenge.huntPill.stationCounter',
        'challenge.huntPill.hintsLabel',
        'challenge.huntPill.hintLocked',
        'challenge.huntPill.close',
        'challenge.huntPill.hintFallback',
        'challenge.huntPill.missingTitle',
        'challenge.huntPause.stopsLabel',
        'challenge.huntPause.pointsLabel',
        'challenge.huntPause.timeLabel',
        'challenge.huntPause.timePlaceholder',
        'challenge.huntPause.stationsHeading',
        'challenge.huntPause.backToMap',
        'challenge.huntPause.abort',
        'challenge.huntPause.abortConfirmMessage',
        'challenge.huntPause.abortConfirmYes',
        'challenge.huntPause.abortConfirmNo',
        'challenge.huntPause.stopSkipped',
        'challenge.huntPause.stopCurrent',
        'challenge.huntPause.stopPending',
        'challenge.huntPause.difficulty.leicht',
        'challenge.huntPause.difficulty.mittel',
        'challenge.huntPause.difficulty.schwer',
        'challenge.huntResult.title',
        'challenge.huntResult.pointsLabel',
        'challenge.huntResult.solvedCount',
        'challenge.huntResult.timeLine',
        'challenge.huntResult.timePlaceholder',
        'challenge.huntResult.close',
        'wallet.shelfVolumeLabel',
        'wallet.coverBrand',
        'wallet.statSincePlaceholder',
      });
    });

    test('kein englischer Wert bleibt versehentlich deutsch', () {
      // **Die Wache zu E-61, seit dem 02.09.2026.** Vorher trugen die Blöcke
      // `challenge.huntPill.`, `challenge.huntPause.` und
      // `challenge.huntResult.` in **beiden** Sprachkarten denselben deutschen
      // Wert, mit der Begründung, die Quelle halte diese Texte hartcodiert
      // deutsch. Der Eigentümer hat das grundsätzlich aufgehoben:
      // englischsprachige Nutzer sehen Englisch, ein hartcodierter deutscher
      // Text in der Quelle ist ein Defekt und keine Parität.
      //
      // Der teure Fehler ist ab jetzt nicht der falsche Wortlaut, sondern der
      // **vergessene**: ein neuer Schlüssel, den jemand in beide Karten mit
      // demselben deutschen Satz schreibt, fällt sonst niemandem auf. Dieser
      // Test macht daraus einen roten Lauf.
      //
      // Die Ausnahmen stehen namentlich da, jede mit ihrem Grund. Eine
      // Ausnahmeliste ohne Begründung wird beim ersten Fehlalarm um einen
      // Eintrag länger, und dann bewacht sie nichts mehr.
      const Map<String, String> gleichMitGrund = <String, String>{
        'challenge.bubbleTitle': 'das Wort "Challenge" ist englisch',
        'challenge.setup.durationCard':
            '"{minutes} min" gilt in beiden Sprachen',
        'challenge.huntPause.stopsLabel': 'das Wort "Stops" ist englisch',
        'challenge.huntPause.stopPending':
            '"Station {station}" gilt in beiden Sprachen',
        'challenge.huntPill.stationCounter':
            '"Station {station} / {total}" gilt in beiden Sprachen',
        'puzzle.stationCounter': '"Station {station}" gilt in beiden Sprachen',
        'challenge.huntPause.timePlaceholder': 'ein Gedankenstrich, sprachfrei',
        'challenge.huntPill.missingTitle': 'ein Gedankenstrich, sprachfrei',
        'challenge.huntResult.timePlaceholder':
            'ein Gedankenstrich, sprachfrei',
        'wallet.statSincePlaceholder': 'ein Gedankenstrich, sprachfrei',
        'tour.step1.meta': 'eine Namensnennung, Goethe heißt in beiden so',
      };

      final Map<String, String> deutsch = supplementTextsFor(AppLanguage.de);
      final Map<String, String> englisch = supplementTextsFor(AppLanguage.en);

      final List<String> unuebersetzt = <String>[];
      for (final MapEntry<String, String> eintrag in englisch.entries) {
        final String? de = deutsch[eintrag.key];
        if (de == eintrag.value && !gleichMitGrund.containsKey(eintrag.key)) {
          unuebersetzt.add('${eintrag.key} = "${eintrag.value}"');
        }
      }

      expect(
        unuebersetzt,
        isEmpty,
        reason:
            'Diese Schlüssel tragen in beiden Sprachen denselben Wert und '
            'stehen nicht auf der begründeten Ausnahmeliste. Entweder '
            'übersetzen oder mit Grund eintragen.',
      );

      // **Die Gegenprobe, ohne die die Liste verrottet.** Ein Eintrag, dessen
      // Werte inzwischen auseinanderlaufen, ist tot und gehört raus, sonst
      // deckt die Liste irgendwann echte Versäumnisse.
      final List<String> toteAusnahmen = <String>[];
      for (final String key in gleichMitGrund.keys) {
        if (!englisch.containsKey(key)) {
          toteAusnahmen.add('$key steht nicht mehr in der Ergänzung');
        } else if (deutsch[key] != englisch[key]) {
          toteAusnahmen.add('$key ist inzwischen übersetzt');
        }
      }

      expect(
        toteAusnahmen,
        isEmpty,
        reason: 'Ausnahmen, die keine mehr sind, gehören aus der Liste',
      );
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
    test('die Aktennummer ist je Sprache übersetzt', () {
      // `screen-fact.jsx:367`: `Akte #{fact.nr || fact.id}` steht wörtlich
      // im JSX und wurde bis zum 02.09.2026 auch im englischen Modus so
      // gezeigt, mit der Begründung, die Quelle habe keine zweite Fassung.
      // Der Eigentümer hat diese Begründung mit E-61 grundsätzlich
      // aufgehoben: hartcodiertes Deutsch in der Quelle ist ein Defekt und
      // keine Parität. Die englische Karte trägt jetzt einen eigenen
      // Wortlaut. Die Zusicherung gilt der Karte selbst und nicht nur dem
      // Ergebnis von `text()`, damit ein versehentlich zurückgebauter
      // englischer Eintrag hier auffällt und nicht erst über den Rückfall
      // verschwindet.
      expect(
        supplementTextsFor(AppLanguage.de)['fact.fileNumber'],
        'Akte #{nr}',
      );
      expect(
        supplementTextsFor(AppLanguage.en)['fact.fileNumber'],
        'File #{nr}',
      );
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('fact.fileNumber', params: {'nr': 'MUC_004'}),
        'Akte #MUC_004',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('fact.fileNumber', params: {'nr': 'MUC_004'}),
        'File #MUC_004',
      );
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

    test('Aufgaben-Beschriftung und Foto-Leiste sind je Sprache übersetzt', () {
      // `:194` und `:176` sind nackte Textknoten ohne Ternär; die Quelle
      // zeigte sie bis zum 02.09.2026 auch im englischen Modus deutsch. Der
      // Eigentümer hat das mit E-61 als gemessenen Defekt der Quelle
      // eingestuft und aufgehoben: die englische Karte trägt jetzt einen
      // eigenen Wortlaut.
      expect(AppStrings.of(AppLanguage.de).text('puzzle.taskLabel'), 'Aufgabe');
      expect(AppStrings.of(AppLanguage.en).text('puzzle.taskLabel'), 'Task');
      expect(
        AppStrings.of(AppLanguage.de).text('puzzle.photoCaption'),
        // Der Gedankenstrich steht so in der Verhaltensquelle und wird für
        // die deutsche Abschrift wortgleich übernommen.
        'Damals — was hat sich verändert?',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('puzzle.photoCaption'),
        'Back then: what has changed?',
      );
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

  group('Die Jagd-Pille', () {
    // Sechs Schlüssel. Die Quelle zeigt jeden davon in beiden Sprachen
    // deutsch, das galt bis zum 02.09.2026 als Begründung dafür, auch hier
    // in beiden Karten denselben deutschen Wert zu tragen (E-61). Der
    // Eigentümer hat diese Begründung aufgehoben: hartcodiertes Deutsch in
    // der Quelle ist ein Defekt und keine Parität. Geprüft wird deshalb der
    // Wortlaut je Sprache, mit `challenge.huntPill.stationCounter` als
    // begründeter Ausnahme (siehe die Ausnahmeliste weiter oben), und dass
    // keiner der sechs Schlüssel zur PWA-Fläche gehört.

    test('die Stationszeile füllt beide Platzhalter', () {
      // `screen-map.jsx:1086`.
      for (final language in AppLanguage.values) {
        expect(
          AppStrings.of(language).text(
            'challenge.huntPill.stationCounter',
            params: {'station': '3', 'total': '7'},
          ),
          'Station 3 / 7',
          reason: language.code,
        );
      }
    });

    test('Tipp-Knopf, gesperrter Hinweis und Einklapp-Text sind je Sprache '
        'übersetzt', () {
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntPill.hintsLabel'),
        'Tipps',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntPill.hintsLabel'),
        'Hints',
      );
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.huntPill.hintLocked', params: {'cost': '20'}),
        // U+2212 (Minuszeichen), keine Ziffer und kein Gedankenstrich.
        'Tipp freischalten (−20 🪙 vom Fakt-Lohn)',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.huntPill.hintLocked', params: {'cost': '20'}),
        'Unlock hint (−20 🪙 off the fact reward)',
      );
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntPill.close'),
        'Schließen',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntPill.close'),
        'Close',
      );
    });

    test('Rückfalltext ist je Sprache übersetzt, Platzhaltertitel bleibt '
        'sprachfrei', () {
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntPill.hintFallback'),
        'Schau dich in der Umgebung aufmerksam um.',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntPill.hintFallback'),
        'Take a careful look around you.',
      );
      // `missingTitle` trägt in beiden Sprachen denselben Gedankenstrich,
      // siehe die begründete Ausnahmeliste in „kein englischer Wert bleibt
      // versehentlich deutsch": ein Zeichen ohne Sprache braucht keine
      // Übersetzung.
      for (final language in AppLanguage.values) {
        expect(
          AppStrings.of(language).text('challenge.huntPill.missingTitle'),
          '—',
          reason: language.code,
        );
      }
    });

    test('die sechs Schlüssel bleiben aus der PWA-Fläche heraus', () {
      for (final language in AppLanguage.values) {
        for (final key in supplementTextsFor(
          language,
        ).keys.where((String key) => key.startsWith('challenge.huntPill.'))) {
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

  group('Der Pause- und der Ergebnisbildschirm', () {
    // Zweiundzwanzig Schlüssel, Schritt 39, dieselbe Lage wie bei der
    // Jagd-Pille: die Quelle zeigt jeden davon in beiden Sprachen deutsch,
    // und bis zum 02.09.2026 trugen deshalb beide Karten hier denselben
    // deutschen Wert (E-61). Der Eigentümer hat diese Begründung
    // aufgehoben: hartcodiertes Deutsch in der Quelle ist ein Defekt und
    // keine Parität, die englische Karte trägt jetzt für fast alle diese
    // Schlüssel einen eigenen Wortlaut. Die begründeten Ausnahmen
    // (`stopsLabel`, `stopPending` und die Zeitplatzhalter) stehen in der
    // Ausnahmeliste des Tests „kein englischer Wert bleibt versehentlich
    // deutsch" weiter oben.

    test('die drei Kachel-Beschriftungen', () {
      // `stopsLabel` bleibt in beiden Sprachen „Stops": das Wort ist im
      // Englischen selbst schon zu Hause, siehe die Ausnahmeliste weiter
      // oben. `pointsLabel` und `timeLabel` tragen dagegen seit dem
      // 02.09.2026 einen eigenen englischen Wortlaut (E-61).
      for (final language in AppLanguage.values) {
        expect(
          AppStrings.of(language).text('challenge.huntPause.stopsLabel'),
          'Stops',
          reason: language.code,
        );
      }
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntPause.pointsLabel'),
        'Punkte',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntPause.pointsLabel'),
        'Points',
      );
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntPause.timeLabel'),
        'Zeit',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntPause.timeLabel'),
        'Time',
      );
    });

    test('der Zeit-Platzhalter ist ein eigener Schlüssel und kein Rohzeichen '
        'im Widget (E-19)', () {
      for (final language in AppLanguage.values) {
        expect(
          AppStrings.of(language).text('challenge.huntPause.timePlaceholder'),
          '—',
          reason: language.code,
        );
      }
    });

    test('die drei Ersatztexte einer Station füllen die Stationsnummer', () {
      // `stopSkipped` und `stopCurrent` tragen seit dem 02.09.2026 einen
      // eigenen englischen Wortlaut (E-61). `stopPending` bleibt in beiden
      // Sprachen „Station {station}": das ist die Ausnahme, die auch
      // `puzzle.stationCounter` trägt, siehe die Ausnahmeliste weiter oben.
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.huntPause.stopSkipped', params: {'station': '2'}),
        'Station 2 · übersprungen',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.huntPause.stopSkipped', params: {'station': '2'}),
        'Station 2 · skipped',
      );
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.huntPause.stopCurrent', params: {'station': '3'}),
        'Station 3 · aktuell',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.huntPause.stopCurrent', params: {'station': '3'}),
        'Station 3 · current',
      );
      for (final language in AppLanguage.values) {
        expect(
          AppStrings.of(
            language,
          ).text('challenge.huntPause.stopPending', params: {'station': '5'}),
          'Station 5',
          reason: language.code,
        );
      }
    });

    test('die drei Schwierigkeitsstufen sind Datenwerte, keine Übersetzung '
        '(Entscheidung 3)', () {
      // Entscheidung 3 aus Schritt 39 hatte zwei Teile, und nur der eine ist
      // seit dem 02.09.2026 überholt. Überholt: die Quelle zeigt
      // `hunt.difficulty` roh an (`leicht`/`mittel`/`schwer`), das galt
      // vorher als Begründung dafür, auch die englische Karte mit denselben
      // deutschen Rohwerten zu füllen. Diese Begründung ist mit E-61
      // aufgehoben; die englische Karte trägt jetzt eine echte Übersetzung.
      //
      // Bewährt: `puzzle_difficulty.dart` verlangt ausdrücklich, dass eine
      // Anzeige über `AppStrings` läuft und nicht über
      // `PuzzleDifficulty.code`. Genau dieser Umweg zahlt sich hier aus:
      // die Umstellung auf englische Wörter kostet zwei geänderte Werte in
      // `app_strings_supplement.dart` und keine einzige Zeile Code.
      //
      // Deutsch bleibt deshalb der rohe Datenwert, weil er zugleich das
      // deutsche Wort ist; Englisch ist jetzt eine eigene Übersetzung.
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.huntPause.difficulty.leicht'),
        'leicht',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.huntPause.difficulty.leicht'),
        'easy',
      );
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.huntPause.difficulty.mittel'),
        'mittel',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.huntPause.difficulty.mittel'),
        'medium',
      );
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.huntPause.difficulty.schwer'),
        'schwer',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.huntPause.difficulty.schwer'),
        'hard',
      );
    });

    test('Rückfrage und Knöpfe des Pausebildschirms sind je Sprache '
        'übersetzt', () {
      // Alle drei trugen bis zum 02.09.2026 in beiden Karten denselben
      // deutschen Wert (E-61), jetzt je einen eigenen Wortlaut.
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.huntPause.abortConfirmMessage'),
        'Punkte gehen verloren. Wirklich abbrechen?',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.huntPause.abortConfirmMessage'),
        'You will lose your points. Abandon the hunt?',
      );
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntPause.backToMap'),
        'Zurück zur Karte',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntPause.backToMap'),
        'Back to the map',
      );
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntPause.abort'),
        'Hunt abbrechen',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntPause.abort'),
        'Abandon hunt',
      );
    });

    test('Überschrift, Punkte-Beschriftung und Zeitzeile des Ergebnisses sind '
        'je Sprache übersetzt', () {
      // Alle außer `timePlaceholder` trugen bis zum 02.09.2026 in beiden
      // Karten denselben deutschen Wert (E-61), jetzt je einen eigenen
      // Wortlaut. `timePlaceholder` bleibt der sprachfreie Gedankenstrich,
      // siehe die Ausnahmeliste weiter oben und E-19.
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntResult.title'),
        'Hunt beendet!',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntResult.title'),
        'Hunt complete!',
      );
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntResult.pointsLabel'),
        'Punkte erspielt',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntResult.pointsLabel'),
        'Points earned',
      );
      expect(
        AppStrings.of(AppLanguage.de).text(
          'challenge.huntResult.solvedCount',
          params: {'solved': '2', 'total': '5'},
        ),
        '2 von 5 Stationen gelöst',
      );
      expect(
        AppStrings.of(AppLanguage.en).text(
          'challenge.huntResult.solvedCount',
          params: {'solved': '2', 'total': '5'},
        ),
        '2 of 5 stations solved',
      );
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('challenge.huntResult.timeLine', params: {'time': '—'}),
        'Zeit: —',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('challenge.huntResult.timeLine', params: {'time': '—'}),
        'Time: —',
      );
      for (final language in AppLanguage.values) {
        expect(
          AppStrings.of(language).text('challenge.huntResult.timePlaceholder'),
          '—',
          reason: language.code,
        );
      }
      expect(
        AppStrings.of(AppLanguage.de).text('challenge.huntResult.close'),
        'Fertig',
      );
      expect(
        AppStrings.of(AppLanguage.en).text('challenge.huntResult.close'),
        'Done',
      );
    });

    test('die zweiundzwanzig Schlüssel bleiben aus der PWA-Fläche heraus', () {
      for (final language in AppLanguage.values) {
        for (final key in supplementTextsFor(language).keys.where(
          (String key) =>
              key.startsWith('challenge.huntPause.') ||
              key.startsWith('challenge.huntResult.'),
        )) {
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
