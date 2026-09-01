import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_batch.dart';
import 'package:fact_app/features/facts/domain/entities/fact_media.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_defect.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_import_report.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verhalten der Entität selbst, ohne Datenschicht.
///
/// Handgeschriebene Wertsemantik braucht Tests: ohne `freezed` gibt es keinen
/// Erzeuger, der ein vergessenes Feld in `==`, `hashCode` oder `copyWith`
/// verhindert. Genau das prüfen die Gleichheits-Tests unten, Feld für Feld.
void main() {
  Fact factWith({
    FactText content = const FactText(
      title: 'Die Glyptothek',
      category: 'Architektur',
    ),
    Map<String, FactText> translations = const <String, FactText>{},
    List<FactPuzzle> puzzles = const <FactPuzzle>[],
  }) {
    return Fact(
      id: const FactId(1004),
      content: content,
      number: 'MUC_004',
      translations: translations,
      coordinates: FactCoordinates.tryFrom(
        latitude: 48.14682,
        longitude: 11.56476,
      ),
      city: const FactCity('München'),
      puzzles: puzzles,
    );
  }

  group('kanonische Werte', () {
    test('Titel und Kategorie kommen aus der Standardsprache', () {
      final fact = factWith();

      expect(fact.canonicalTitle, 'Die Glyptothek');
      expect(fact.canonicalCategory, 'Architektur');
    });

    test('eine Übersetzung verschiebt den kanonischen Wert nicht', () {
      final fact = factWith(
        translations: const <String, FactText>{
          'en': FactText(title: 'The Glyptothek', category: 'Architecture'),
        },
      );

      // An canonicalCategory hängen Kategoriefarbe und die Trophäen-Regeln des
      // Backends (`lower(f.kategorie) LIKE 'hist%'`). Würde hier die Übersetzung
      // gewinnen, wären beide auf Englisch kaputt.
      expect(fact.canonicalCategory, 'Architektur');
      expect(fact.canonicalTitle, 'Die Glyptothek');
      expect(fact.contentFor('en').category, 'Architecture');
    });

    test('ein leerer Titel ergibt einen leeren String, keinen Absturz', () {
      final fact = factWith(content: const FactText(category: 'Architektur'));

      expect(fact.canonicalTitle, '');
    });
  });

  group('contentFor', () {
    final fact = factWith(
      content: const FactText(
        title: 'Die Glyptothek',
        body: 'Deutscher Haupttext',
        bodyExtra: 'Deutscher zweiter Absatz',
        category: 'Architektur',
        place: 'Königsplatz',
      ),
      translations: const <String, FactText>{
        'en': FactText(title: 'The Glyptothek', body: 'English body'),
        'it': FactText(title: 'La Gliptoteca'),
      },
    );

    test('die angefragte Sprache gewinnt Feld für Feld', () {
      final english = fact.contentFor('en', fallbackLanguageCode: 'de');

      expect(english.title, 'The Glyptothek');
      expect(english.body, 'English body');
      // Nicht übersetzt, kommt aus den flachen Spalten.
      expect(english.bodyExtra, 'Deutscher zweiter Absatz');
      expect(english.place, 'Königsplatz');
    });

    test('die Rückfallsprache greift vor den flachen Spalten', () {
      // Italienisch hat nur den Titel. Der Rückfall ist Englisch, also gewinnt
      // dort der englische Text, und erst danach das Deutsche.
      final italian = fact.contentFor('it', fallbackLanguageCode: 'en');

      expect(italian.title, 'La Gliptoteca');
      expect(italian.body, 'English body');
      expect(italian.bodyExtra, 'Deutscher zweiter Absatz');
    });

    test('ohne Rückfallsprache gilt direkt die Standardsprache', () {
      final italian = fact.contentFor('it');

      expect(italian.title, 'La Gliptoteca');
      expect(italian.body, 'Deutscher Haupttext');
    });

    test('eine unbekannte Sprache liefert die Standardsprache', () {
      final french = fact.contentFor('fr');

      expect(french.title, 'Die Glyptothek');
      expect(french.body, 'Deutscher Haupttext');
    });

    test('die Standardsprache selbst als Rückfall ändert nichts', () {
      expect(
        fact.contentFor('de', fallbackLanguageCode: 'de'),
        fact.contentFor('de'),
      );
    });

    test('vorhandene Sprachen kommen sortiert', () {
      expect(fact.translatedLanguageCodes, orderedEquals(<String>['en', 'it']));
    });

    test('die Liste der Sprachen ist unveränderlich', () {
      expect(
        () => fact.translatedLanguageCodes.add('fr'),
        throwsUnsupportedError,
      );
    });
  });

  group('FactText.overriddenBy', () {
    test('ein leerer String zählt als nicht übersetzt', () {
      // pickFact (api.jsx:33) prüft ausdrücklich auf `!== ''`. Ohne diese Regel
      // würde ein abgebrochener Übersetzungslauf deutschen Text löschen.
      const base = FactText(title: 'Deutsch', body: 'Deutscher Text');
      const override = FactText(title: '', body: 'English');

      final merged = base.overriddenBy(override);
      expect(merged.title, 'Deutsch');
      expect(merged.body, 'English');
    });

    test('ein leeres Bündel ändert nichts', () {
      const base = FactText(title: 'Deutsch');

      expect(base.overriddenBy(FactText.empty), base);
      expect(base.overriddenBy(null), base);
    });

    test('isEmpty erkennt das leere Bündel', () {
      expect(FactText.empty.isEmpty, isTrue);
      expect(const FactText(caption: '[ x ]').isEmpty, isFalse);
    });

    test('die Schlüsselliste deckt alle neun Felder ab', () {
      // Hält die Liste und die Felder zusammen: wer ein Feld ergänzt, ohne den
      // Schlüssel nachzutragen, fällt hier durch.
      expect(FactText.sourceKeys, hasLength(9));
      expect(
        FactText.sourceKeys,
        orderedEquals(<String>[
          'titel',
          'text',
          'text2',
          'text3',
          'text4',
          'ort',
          'kategorie',
          'quelle',
          'caption',
        ]),
      );
      const full = FactText(
        title: 'a',
        body: 'b',
        bodyExtra: 'c',
        bodyBackground: 'd',
        bodyToday: 'e',
        place: 'f',
        category: 'g',
        source: 'h',
        caption: 'i',
      );
      expect(full.toString(), contains('caption'));
      expect(full.toString(), contains('text4'));
    });

    test('copyWith ändert genau ein Feld', () {
      const base = FactText(title: 'Deutsch', body: 'Text');
      final changed = base.copyWith(body: 'Anders');

      expect(changed.title, 'Deutsch');
      expect(changed.body, 'Anders');
      expect(base.body, 'Text');
    });
  });

  group('abgeleitete Rätselstufe', () {
    test('ohne Rätsel ist sie null', () {
      expect(factWith().easiestPuzzleDifficulty, isNull);
      expect(factWith().hasPuzzles, isFalse);
    });

    test('sie nimmt die leichteste vorhandene Stufe', () {
      final fact = factWith(
        puzzles: const <FactPuzzle>[
          FactPuzzle(question: 'a', difficulty: PuzzleDifficulty.schwer),
          FactPuzzle(question: 'b', difficulty: PuzzleDifficulty.mittel),
        ],
      );

      expect(fact.easiestPuzzleDifficulty, PuzzleDifficulty.mittel);
    });

    test('Rätsel ohne Stufe werden übersprungen', () {
      final fact = factWith(
        puzzles: const <FactPuzzle>[
          FactPuzzle(question: 'a'),
          FactPuzzle(question: 'b', difficulty: PuzzleDifficulty.schwer),
        ],
      );

      expect(fact.easiestPuzzleDifficulty, PuzzleDifficulty.schwer);
    });
  });

  group('Wertsemantik', () {
    test('zwei strukturell gleiche Fakten sind gleich', () {
      expect(factWith(), factWith());
      expect(factWith().hashCode, factWith().hashCode);
    });

    test('jedes einzelne Feld bricht die Gleichheit', () {
      final base = Fact(
        id: const FactId(1),
        content: const FactText(title: 't', category: 'k'),
        number: 'MUC_001',
        translations: const <String, FactText>{'en': FactText(title: 'T')},
        coordinates: FactCoordinates.tryFrom(latitude: 1, longitude: 2),
        city: const FactCity('München'),
        zone: 1,
        genre: 'Architektur',
        qualityScore: 2,
        heroColors: const <String>['#000000'],
        rating: 4.5,
        ratingCount: 12,
        isUserCreated: true,
        isApproved: true,
        createdBy: 'abc',
        createdAtUtc: DateTime.utc(2026),
        media: const FactMedia(imageUrl: 'https://a.test/b.jpg'),
        stationHints: const <String>['a'],
        nextStationHint: 'weiter',
        puzzles: const <FactPuzzle>[FactPuzzle(question: 'q')],
      );

      final variants = <String, Fact>{
        'id': base.copyWith(id: const FactId(2)),
        'content': base.copyWith(content: const FactText(title: 'anders')),
        'number': base.copyWith(number: 'MUC_999'),
        'translations': base.copyWith(
          translations: const <String, FactText>{'it': FactText(title: 'T')},
        ),
        'coordinates': base.copyWith(
          coordinates: FactCoordinates.tryFrom(latitude: 9, longitude: 9),
        ),
        'city': base.copyWith(city: const FactCity('Passau')),
        'zone': base.copyWith(zone: 3),
        'genre': base.copyWith(genre: 'Mythos'),
        'qualityScore': base.copyWith(qualityScore: 3),
        'heroColors': base.copyWith(heroColors: const <String>['#ffffff']),
        'rating': base.copyWith(rating: 1),
        'ratingCount': base.copyWith(ratingCount: 1),
        'isUserCreated': base.copyWith(isUserCreated: false),
        'isApproved': base.copyWith(isApproved: false),
        'createdBy': base.copyWith(createdBy: 'xyz'),
        'createdAtUtc': base.copyWith(createdAtUtc: DateTime.utc(2027)),
        'media': base.copyWith(
          media: const FactMedia(imageUrl: 'https://c.test/d.jpg'),
        ),
        'stationHints': base.copyWith(stationHints: const <String>['b']),
        'nextStationHint': base.copyWith(nextStationHint: 'anders'),
        'puzzles': base.copyWith(
          puzzles: const <FactPuzzle>[FactPuzzle(question: 'anders')],
        ),
      };

      expect(variants, hasLength(20));
      variants.forEach((field, variant) {
        expect(
          variant,
          isNot(base),
          reason: 'Feld $field fehlt in == oder copyWith',
        );
      });
    });

    test('copyWith ohne Argumente liefert einen gleichen Fakt', () {
      final fact = factWith();

      expect(fact.copyWith(), fact);
    });

    test('toString trägt weder Inhalt noch Koordinate', () {
      final text = factWith().toString();

      expect(text, contains('1004'));
      expect(text, isNot(contains('Glyptothek')));
      expect(text, isNot(contains('48.1')));
    });
  });

  group('FactBatch', () {
    test('singleOrNull liefert nur bei genau einem Fakt', () {
      final one = FactBatch(
        facts: <Fact>[factWith()],
        report: FactImportReport.clean,
      );
      final two = FactBatch(
        facts: <Fact>[factWith(), factWith()],
        report: FactImportReport.clean,
      );

      expect(one.singleOrNull, isNotNull);
      expect(two.singleOrNull, isNull);
      expect(FactBatch.empty.singleOrNull, isNull);
      expect(FactBatch.empty.isEmpty, isTrue);
    });

    test('die Faktenliste ist unveränderlich', () {
      final batch = FactBatch(
        facts: <Fact>[factWith()],
        report: FactImportReport.clean,
      );

      expect(() => batch.facts.add(factWith()), throwsUnsupportedError);
    });

    test('merge legt Fakten und Berichte zusammen', () {
      final first = FactBatch(
        facts: <Fact>[factWith()],
        report: FactImportReport(const <FactDefect>[
          FactDefect(
            kind: FactDefectKind.optionalFieldUnusable,
            field: 'hero',
            factReference: 'MUC_001',
          ),
        ]),
      );
      final second = FactBatch(
        facts: <Fact>[factWith()],
        report: FactImportReport(const <FactDefect>[
          FactDefect(
            kind: FactDefectKind.requiredFieldUnusable,
            field: 'id',
            factReference: 'MUC_002',
          ),
        ]),
      );

      final merged = first.merge(second);
      expect(merged.facts, hasLength(2));
      expect(merged.report.defects, hasLength(2));
      expect(merged.report.discardedFactCount, 1);
      expect(merged.report.degradedFieldCount, 1);
    });
  });

  group('FactImportReport', () {
    test('mehrere Befunde am gleichen Fakt zählen als ein Ausfall', () {
      final report = FactImportReport(const <FactDefect>[
        FactDefect(
          kind: FactDefectKind.requiredFieldUnusable,
          field: 'id',
          factReference: 'MUC_001',
        ),
        FactDefect(
          kind: FactDefectKind.requiredFieldUnusable,
          field: 'titel',
          factReference: 'MUC_001',
        ),
      ]);

      expect(report.discardedFactCount, 1);
      expect(report.defects, hasLength(2));
    });

    test('countsByKind zählt je Art', () {
      final report = FactImportReport(const <FactDefect>[
        FactDefect(
          kind: FactDefectKind.optionalFieldUnusable,
          field: 'hero',
          factReference: 'a',
        ),
        FactDefect(
          kind: FactDefectKind.optionalFieldUnusable,
          field: '_i18n',
          factReference: 'b',
        ),
        FactDefect(
          kind: FactDefectKind.obsoleteFieldShape,
          field: 'puzzle_fit',
          factReference: 'c',
        ),
      ]);

      expect(report.countsByKind[FactDefectKind.optionalFieldUnusable], 2);
      expect(report.countsByKind[FactDefectKind.obsoleteFieldShape], 1);
      expect(report.forField('hero'), hasLength(1));
      expect(report.isClean, isFalse);
      expect(FactImportReport.clean.isClean, isTrue);
    });
  });

  group('FactMedia', () {
    test('previewUrl und fullUrl folgen dem Lesepfad der PWA', () {
      const both = FactMedia(
        imageUrl: 'https://a.test/voll.jpg',
        thumbnailUrl: 'https://a.test/klein.jpg',
      );
      const onlyFull = FactMedia(imageUrl: 'https://a.test/voll.jpg');
      const onlyThumb = FactMedia(thumbnailUrl: 'https://a.test/klein.jpg');

      expect(both.previewUrl, 'https://a.test/klein.jpg');
      expect(both.fullUrl, 'https://a.test/voll.jpg');
      expect(onlyFull.previewUrl, 'https://a.test/voll.jpg');
      expect(onlyThumb.fullUrl, 'https://a.test/klein.jpg');
      expect(const FactMedia().hasImage, isFalse);
      expect(const FactMedia().isEmpty, isTrue);
    });
  });

  group('FactCoordinates', () {
    test('gültige Werte kommen durch', () {
      final point = FactCoordinates.tryFrom(latitude: 48.1, longitude: 11.5);

      expect(point?.latitude, 48.1);
      expect(point?.longitude, 11.5);
    });

    test('ein fehlender Wert ergibt keinen Punkt', () {
      expect(FactCoordinates.tryFrom(latitude: 48.1), isNull);
      expect(FactCoordinates.tryFrom(longitude: 11.5), isNull);
      expect(FactCoordinates.tryFrom(), isNull);
    });

    test('Werte außerhalb des Bereichs ergeben keinen Punkt', () {
      expect(FactCoordinates.tryFrom(latitude: 90.1, longitude: 0), isNull);
      expect(FactCoordinates.tryFrom(latitude: 0, longitude: 180.1), isNull);
      expect(
        FactCoordinates.tryFrom(latitude: double.nan, longitude: 0),
        isNull,
      );
      expect(
        FactCoordinates.tryFrom(latitude: 90, longitude: 180),
        isNotNull,
        reason: 'die Grenzen selbst sind gültig',
      );
    });

    test('toString nennt keine Zahlen', () {
      final point = FactCoordinates.tryFrom(latitude: 48.1, longitude: 11.5);

      expect(point.toString(), isNot(contains('48')));
    });
  });

  group('FactId', () {
    test('gleiche Zahl heißt gleiche Kennung', () {
      // Zur Laufzeit gebaut und mit `identical` gegengeprüft, wie in
      // `auth_city_test.dart`. Zwei gleich geschriebene `const FactId(7)` sind
      // in Dart **dasselbe Objekt**; ein Gleichheitstest darauf prüfte nichts.
      // Nachgemessen: `==` auf `identical(this, other)` zu reduzieren überlebte
      // damit die Suite. Aus Supabase geparste Kennungen sind nicht
      // kanonisiert, ein solcher Regress bräche jeden Vergleich nach Kennung.
      final row = <String, Object?>{'id': 7};
      final left = FactId(row['id']! as int);
      final right = FactId(int.parse('7'));

      expect(identical(left, right), isFalse);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
      expect(left, isNot(FactId(int.parse('8'))));
      expect(left.value, 7);
    });
  });

  group('PuzzleDifficulty', () {
    test('bekannte Codes werden erkannt', () {
      expect(PuzzleDifficulty.fromCode('leicht'), PuzzleDifficulty.leicht);
      expect(PuzzleDifficulty.fromCode('MITTEL'), PuzzleDifficulty.mittel);
      expect(PuzzleDifficulty.fromCode(' schwer '), PuzzleDifficulty.schwer);
    });

    test('unbekannte und fehlende Codes ergeben null', () {
      expect(PuzzleDifficulty.fromCode('brutal'), isNull);
      expect(PuzzleDifficulty.fromCode(null), isNull);
      expect(PuzzleDifficulty.fromCode(''), isNull);
    });

    test('die Reihenfolge geht von leicht nach schwer', () {
      // Darauf verlässt sich Fact.easiestPuzzleDifficulty.
      expect(
        PuzzleDifficulty.leicht.index,
        lessThan(PuzzleDifficulty.mittel.index),
      );
      expect(
        PuzzleDifficulty.mittel.index,
        lessThan(PuzzleDifficulty.schwer.index),
      );
    });
  });
}
