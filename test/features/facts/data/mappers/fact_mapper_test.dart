import 'package:fact_app/features/facts/data/mappers/fact_mapper.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_defect.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fact_row_fixtures.dart';

/// Der Kern dieses Schritts, negativ geprüft.
///
/// Jeder Fehlerfall steht in einer Liste mit zwei heilen Nachbarn. Die
/// Behauptung „ein defektes Feld kostet höchstens einen Fakt" ist erst dann
/// belegt, wenn in jedem einzelnen Fall nachgewiesen ist, dass die **übrigen**
/// Fakten ankommen. Ein Test, der nur den defekten Fakt betrachtet, würde
/// grün bleiben, während die Liste stillschweigend leer wäre.
void main() {
  const mapper = FactMapper();

  /// Baut `[1001, defekt, 1003]` und bildet die Liste ab.
  FactMappingResult mapWithNeighbours(Object? broken) {
    return mapper.mapRecords(<Object?>[
      factRow(overrides: <String, Object?>{'id': 1001, 'nr': 'MUC_001'}),
      broken,
      factRow(overrides: <String, Object?>{'id': 1003, 'nr': 'MUC_003'}),
    ]);
  }

  /// Die Kennungen der angekommenen Fakten.
  List<int> idsOf(FactMappingResult result) =>
      result.facts.map((fact) => fact.id.value).toList();

  group('heiler Datensatz', () {
    test('bildet alle Spalten ab, die der Vertrag nennt', () {
      final result = mapper.mapRecords(<Object?>[factRow()]);

      expect(result.defects, isEmpty);
      expect(result.recordCount, 1);
      final fact = result.facts.single;
      expect(fact.id.value, 1004);
      expect(fact.number, 'MUC_004');
      expect(fact.canonicalTitle, startsWith('Die Glyptothek'));
      expect(fact.canonicalCategory, 'Architektur');
      expect(fact.genre, 'Architektur');
      expect(fact.qualityScore, 2);
      expect(fact.zone, 1);
      expect(fact.city?.displayName, 'München');
      expect(fact.coordinates?.latitude, 48.14682);
      expect(fact.coordinates?.longitude, 11.56476);
      expect(fact.heroColors, orderedEquals(<String>['#1A2030', '#0D1018']));
      expect(fact.rating, 0);
      expect(fact.ratingCount, 0);
      expect(fact.isUserCreated, isFalse);
      expect(fact.isApproved, isTrue);
      expect(fact.createdAtUtc, DateTime.utc(2026, 5, 12, 8, 14));
      expect(fact.stationHints, hasLength(3));
      expect(fact.nextStationHint, isNull);
      expect(fact.puzzles, hasLength(2));
      expect(fact.content.place, 'Glyptothek · Königsplatz');
      expect(fact.content.source, 'Wikipedia · Stadtarchiv München');
      expect(fact.content.caption, '[ Glyptothek · Königsplatz ]');
    });

    test('fehlende Kategorie fällt auf den Vorgabewert der Spalte', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(without: <String>{'kategorie'}),
      ]);

      expect(result.facts.single.canonicalCategory, FactMapper.defaultCategory);
      expect(result.defects, isEmpty);
    });

    test('ein leerer Datensatz ohne Rätsel ist kein Mangel', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(overrides: <String, Object?>{'puzzle_fit': null}),
      ]);

      expect(result.facts.single.puzzles, isEmpty);
      expect(result.facts.single.hasPuzzles, isFalse);
      expect(result.defects, isEmpty);
    });
  });

  group('hero', () {
    test('ein String statt einer Liste kostet nur das Feld', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'hero': '#2C3E50',
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      final broken = result.facts[1];
      expect(broken.heroColors, orderedEquals(Fact.defaultHeroColors));
      expect(broken.canonicalTitle, isNotEmpty);
      final defect = result.defects.single;
      expect(defect.kind, FactDefectKind.optionalFieldUnusable);
      expect(defect.field, 'hero');
      expect(defect.encounteredType, 'String');
      expect(defect.factReference, 'MUC_002');
      expect(defect.discardsFact, isFalse);
    });

    test('ein unbrauchbarer Eintrag fällt, die gültigen bleiben', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            'hero': <dynamic>['#1A2030', 'blau', 42],
          },
        ),
      ]);

      expect(
        result.facts.single.heroColors,
        orderedEquals(<String>['#1A2030']),
      );
      expect(result.defects.map((d) => d.field), everyElement('hero'));
    });

    test('eine Liste ohne jede Hex-Farbe fällt auf die Vorgabe', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            'hero': <dynamic>['blau', 'grün'],
          },
        ),
      ]);

      expect(
        result.facts.single.heroColors,
        orderedEquals(Fact.defaultHeroColors),
      );
      expect(result.defects, isNotEmpty);
    });
  });

  group('puzzle_fit', () {
    test('die alte Schwierigkeitsform wird gemeldet und ignoriert', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'puzzle_fit': 'mittel',
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].puzzles, isEmpty);
      expect(result.facts[1].easiestPuzzleDifficulty, isNull);
      final defect = result.defects.single;
      expect(defect.kind, FactDefectKind.obsoleteFieldShape);
      expect(defect.field, 'puzzle_fit');
      expect(defect.discardsFact, isFalse);
      expect(idsOf(result), contains(1002));
      // Die Nachbarn behalten ihre Rätsel.
      expect(result.facts.first.puzzles, hasLength(2));
      expect(result.facts.last.puzzles, hasLength(2));
    });

    test('ein unbrauchbares Element kostet nur dieses Rätsel', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'puzzle_fit': <Object?>[
              puzzleRow(),
              'kaputt',
              puzzleRowKombi(),
              null,
            ],
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      final puzzles = result.facts[1].puzzles;
      expect(puzzles, hasLength(2));
      expect(puzzles.first.type, 'vor-ort');
      expect(puzzles.last.type, 'kombi');
      final fields = result.defects.map((d) => d.field).toList();
      expect(fields, contains('puzzle_fit[1]'));
      expect(fields, contains('puzzle_fit[3]'));
      expect(
        result.defects.every(
          (d) => d.kind == FactDefectKind.optionalFieldUnusable,
        ),
        isTrue,
      );
    });

    test('ein Rätsel ohne Frage fällt weg, die übrigen bleiben', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            'puzzle_fit': <Object?>[
              puzzleRow(without: <String>{'question'}),
              puzzleRowKombi(),
            ],
          },
        ),
      ]);

      expect(result.facts.single.puzzles, hasLength(1));
      expect(
        result.defects.map((d) => d.field),
        contains('puzzle_fit[0].question'),
      );
    });

    test('eine Zahl statt einer Liste kostet nur das Feld', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'puzzle_fit': 7,
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].puzzles, isEmpty);
      expect(result.defects.single.encounteredType, 'int');
    });
  });

  group('hint_media', () {
    test('als Objekt kommen alle Felder an', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(overrides: <String, Object?>{'hint_media': hintMediaRow()}),
      ]);

      expect(result.defects, isEmpty);
      final media = result.facts.single.media;
      expect(media, isNotNull);
      expect(media!.imageUrl, 'https://upload.wikimedia.org/glyptothek.jpg');
      expect(
        media.thumbnailUrl,
        'https://upload.wikimedia.org/glyptothek_800.jpg',
      );
      expect(media.width, 3000);
      expect(media.height, 2000);
      expect(media.caption, startsWith('Glyptothek am Königsplatz'));
      expect(media.sourceUrl, contains('commons.wikimedia.org'));
      expect(media.license, 'PD-old-70');
      expect(media.attribution, 'Unbekannter Fotograf');
      expect(media.year, 1900);
      expect(media.provenance, 'wikipedia-source');
      // Vorschau bevorzugt thumb_url, die Lightbox die volle Auflösung.
      expect(media.previewUrl, media.thumbnailUrl);
      expect(media.fullUrl, media.imageUrl);
    });

    test('als reiner URL-String wird toleriert', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'hint_media': 'https://upload.wikimedia.org/nur-eine-url.jpg',
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.defects, isEmpty);
      final media = result.facts[1].media;
      expect(media?.imageUrl, 'https://upload.wikimedia.org/nur-eine-url.jpg');
      expect(
        media?.previewUrl,
        'https://upload.wikimedia.org/nur-eine-url.jpg',
      );
    });

    test('als null bleibt es leer, ohne Mangel', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'hint_media': null,
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].media, isNull);
      expect(result.defects, isEmpty);
    });

    test('ein String ohne URL wird gemeldet, der Fakt bleibt', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'hint_media': 'siehe Archiv',
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].media, isNull);
      expect(result.defects.single.field, 'hint_media');
    });

    test('eine Liste statt eines Objekts wird gemeldet, der Fakt bleibt', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'hint_media': <dynamic>['https://beispiel.test/a.jpg'],
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].media, isNull);
      expect(result.defects.single.encounteredType, 'List');
    });
  });

  group('city', () {
    test('ohne city bleibt der Fakt in der Liste, ohne Mangel', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'city': null,
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].city, isNull);
      expect(result.defects, isEmpty);
    });

    test('fehlt die Spalte ganz, gilt dasselbe', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(without: <String>{'city'}),
      ]);

      expect(result.facts.single.city, isNull);
      expect(result.defects, isEmpty);
    });
  });

  group('Zahlenspalten', () {
    test('lat und lng als String werden gelesen', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'lat': '48.137154',
            'lng': '11.576124',
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.defects, isEmpty);
      expect(result.facts[1].coordinates?.latitude, 48.137154);
      expect(result.facts[1].coordinates?.longitude, 11.576124);
      expect(result.facts[1].hasLocation, isTrue);
    });

    test('lat als ganze Zahl und rating als String werden gelesen', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{'lat': 48, 'lng': 11, 'rating': '4.8'},
        ),
      ]);

      expect(result.defects, isEmpty);
      expect(result.facts.single.coordinates?.latitude, 48.0);
      expect(result.facts.single.rating, 4.8);
    });

    test('lat ohne Zahl kostet nur die Koordinate', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            'lat': 'Innenstadt',
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].coordinates, isNull);
      expect(result.facts[1].hasLocation, isFalse);
      expect(result.defects.single.field, 'lat');
    });

    test('eine Koordinate außerhalb des Wertebereichs wird gemeldet', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(overrides: <String, Object?>{'lat': 148.5, 'lng': 11.5}),
      ]);

      expect(result.facts.single.coordinates, isNull);
      expect(result.defects.single.field, 'lat/lng');
    });

    test('ein quality_score außerhalb von 1 bis 3 wird verworfen', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(overrides: <String, Object?>{'quality_score': 7}),
      ]);

      expect(result.facts.single.qualityScore, isNull);
      expect(result.defects.single.field, 'quality_score');
    });

    test('fehlendes rating und bewertungen werden null-sicher zu 0', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{'rating': null, 'bewertungen': null},
        ),
      ]);

      expect(result.facts.single.rating, 0);
      expect(result.facts.single.ratingCount, 0);
      expect(result.defects, isEmpty);
    });
  });

  group('unbrauchbare Datensätze', () {
    test('ohne id fällt genau dieser Fakt aus der Liste', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{'nr': 'MUC_002'},
          without: <String>{'id'},
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1003]));
      final defect = result.defects.single;
      expect(defect.kind, FactDefectKind.requiredFieldUnusable);
      expect(defect.field, 'id');
      expect(defect.factReference, 'MUC_002');
      expect(defect.discardsFact, isTrue);
    });

    test('eine id, die keine Zahl ist, fällt aus', () {
      final result = mapWithNeighbours(
        factRow(overrides: <String, Object?>{'id': 'MUC_002'}),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1003]));
      expect(result.defects.single.field, 'id');
    });

    test('ohne titel fällt genau dieser Fakt aus der Liste', () {
      final result = mapWithNeighbours(
        factRow(overrides: <String, Object?>{'id': 1002, 'titel': '   '}),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1003]));
      final defect = result.defects.single;
      expect(defect.kind, FactDefectKind.requiredFieldUnusable);
      expect(defect.field, 'titel');
    });

    test('ein Datensatz, der gar kein Objekt ist, fällt aus', () {
      final result = mapWithNeighbours('kaputte Zeile');

      expect(idsOf(result), orderedEquals(<int>[1001, 1003]));
      final defect = result.defects.single;
      expect(defect.kind, FactDefectKind.recordNotAnObject);
      expect(defect.encounteredType, 'String');
      expect(defect.factReference, FactDefect.unknownReference);
    });

    test('ein komplett unbrauchbarer Datensatz fällt aus', () {
      final result = mapWithNeighbours(<String, dynamic>{
        'id': null,
        'titel': null,
        'hero': 3,
        'puzzle_fit': <Object?>[42],
        '_i18n': 'englisch',
      });

      expect(idsOf(result), orderedEquals(<int>[1001, 1003]));
      expect(result.facts, hasLength(2));
      expect(result.defects.single.kind, FactDefectKind.requiredFieldUnusable);
      expect(result.defects.single.factReference, FactDefect.unknownReference);
    });

    test('null als Listenelement fällt aus', () {
      final result = mapWithNeighbours(null);

      expect(idsOf(result), orderedEquals(<int>[1001, 1003]));
      expect(result.defects.single.encounteredType, 'null');
    });
  });

  group('die Antwort selbst', () {
    test('gar keine Liste ergibt kein Fakt und einen Befund', () {
      final result = mapper.mapRecords(<String, dynamic>{'message': 'kaputt'});

      expect(result.facts, isEmpty);
      expect(result.recordCount, -1);
      final defect = result.defects.single;
      expect(defect.kind, FactDefectKind.responseNotAList);
      expect(defect.encounteredType, 'Map');
      expect(defect.discardsFact, isTrue);
    });

    test('null ergibt kein Fakt und einen Befund', () {
      final result = mapper.mapRecords(null);

      expect(result.facts, isEmpty);
      expect(result.recordCount, -1);
      expect(result.defects.single.kind, FactDefectKind.responseNotAList);
    });

    test('eine leere Liste ist kein Mangel', () {
      final result = mapper.mapRecords(<Object?>[]);

      expect(result.facts, isEmpty);
      expect(result.recordCount, 0);
      expect(result.defects, isEmpty);
    });

    test('recordCount zählt Zeilen, nicht brauchbare Fakten', () {
      final result = mapWithNeighbours('kaputte Zeile');

      expect(result.recordCount, 3);
      expect(result.facts, hasLength(2));
    });
  });

  group('_i18n', () {
    test('leer heißt: alles kommt aus den flachen Spalten', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(overrides: <String, Object?>{'_i18n': <String, dynamic>{}}),
      ]);

      final fact = result.facts.single;
      expect(fact.translations, isEmpty);
      expect(fact.translatedLanguageCodes, isEmpty);
      expect(fact.contentFor('en').title, fact.canonicalTitle);
      expect(result.defects, isEmpty);
    });

    test('mit en gewinnt Englisch feldweise', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            '_i18n': <String, dynamic>{
              'en': <String, dynamic>{
                'titel': 'The Glyptothek',
                'text': 'When King Ludwig I decided in 1816 …',
                'ort': 'Glyptothek · Koenigsplatz',
                'kategorie': 'Architecture',
              },
            },
          },
        ),
      ]);

      final fact = result.facts.single;
      expect(result.defects, isEmpty);
      expect(fact.translatedLanguageCodes, orderedEquals(<String>['en']));

      final english = fact.contentFor('en', fallbackLanguageCode: 'de');
      expect(english.title, 'The Glyptothek');
      expect(english.body, 'When King Ludwig I decided in 1816 …');
      expect(english.category, 'Architecture');

      // Der kanonische Wert bleibt deutsch: an ihm hängen Farbe und Trophäen.
      expect(fact.canonicalCategory, 'Architektur');
      expect(fact.canonicalTitle, startsWith('Die Glyptothek'));

      // Deutsch bleibt unberührt.
      final german = fact.contentFor('de', fallbackLanguageCode: 'de');
      expect(german.title, startsWith('Die Glyptothek'));
      expect(german.category, 'Architektur');
    });

    test('fehlt ein Feld in en, kommt genau dieses aus dem Rückfall', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            'text2': 'Deutscher zweiter Absatz',
            'caption': '[ deutsche Bildzeile ]',
            '_i18n': <String, dynamic>{
              'en': <String, dynamic>{
                'titel': 'The Glyptothek',
                // text2 fehlt, caption ist leer: beides gilt als nicht übersetzt
                'caption': '',
              },
            },
          },
        ),
      ]);

      final english = result.facts.single.contentFor(
        'en',
        fallbackLanguageCode: 'de',
      );
      expect(english.title, 'The Glyptothek');
      expect(english.bodyExtra, 'Deutscher zweiter Absatz');
      expect(english.caption, '[ deutsche Bildzeile ]');
      expect(result.defects, isEmpty);
    });

    test('eine unbekannte Sprache fällt auf den Rückfall zurück', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            '_i18n': <String, dynamic>{
              'en': <String, dynamic>{'titel': 'The Glyptothek'},
            },
          },
        ),
      ]);

      final italian = result.facts.single.contentFor(
        'it',
        fallbackLanguageCode: 'en',
      );
      expect(italian.title, 'The Glyptothek');
    });

    test('ein Sprachblock, der kein Objekt ist, wird gemeldet', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            '_i18n': <String, dynamic>{'en': 'The Glyptothek'},
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].translations, isEmpty);
      final defect = result.defects.single;
      expect(defect.field, '_i18n.en');
      expect(defect.encounteredType, 'String');
    });

    test('_i18n als String kostet nur die Übersetzungen', () {
      final result = mapWithNeighbours(
        factRow(
          overrides: <String, Object?>{
            'id': 1002,
            'nr': 'MUC_002',
            '_i18n': 'englisch',
          },
        ),
      );

      expect(idsOf(result), orderedEquals(<int>[1001, 1002, 1003]));
      expect(result.facts[1].translations, isEmpty);
      expect(result.facts[1].canonicalTitle, isNotEmpty);
      expect(result.defects.single.field, '_i18n');
    });

    test('ein leerer Sprachblock wird nicht als Sprache geführt', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            '_i18n': <String, dynamic>{
              'en': <String, dynamic>{'titel': '', 'text': null},
            },
          },
        ),
      ]);

      expect(result.facts.single.translatedLanguageCodes, isEmpty);
    });
  });

  group('mehrere Mängel auf einmal', () {
    test('drei kaputte Nachbarn kosten drei Fakten, nicht die Liste', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(overrides: <String, Object?>{'id': 1001, 'nr': 'MUC_001'}),
        'kaputt',
        factRow(overrides: <String, Object?>{'id': 1003, 'nr': 'MUC_003'}),
        42,
        factRow(overrides: <String, Object?>{'id': 1005, 'nr': 'MUC_005'}),
        <String, dynamic>{'id': 0, 'titel': 'Nummer null'},
        factRow(
          overrides: <String, Object?>{
            'id': 1007,
            'nr': 'MUC_007',
            'hero': 'kaputt',
            'puzzle_fit': 'schwer',
          },
        ),
      ]);

      expect(idsOf(result), orderedEquals(<int>[1001, 1003, 1005, 1007]));
      expect(result.recordCount, 7);

      const forbiddenKinds = <FactDefectKind>[FactDefectKind.responseNotAList];
      expect(
        result.defects.map((d) => d.kind),
        isNot(anyElement(isIn(forbiddenKinds))),
      );
      expect(
        result.defects
            .where((d) => d.kind == FactDefectKind.recordNotAnObject)
            .length,
        2,
      );
      expect(
        result.defects
            .where((d) => d.kind == FactDefectKind.requiredFieldUnusable)
            .length,
        1,
      );
      expect(
        result.defects
            .where((d) => d.kind == FactDefectKind.obsoleteFieldShape)
            .length,
        1,
      );
      expect(
        result.defects
            .where((d) => d.kind == FactDefectKind.optionalFieldUnusable)
            .length,
        1,
      );
    });
  });

  group('abgeleitete Schwierigkeit', () {
    test('nimmt die leichteste vorhandene Stufe', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            'puzzle_fit': <Object?>[
              puzzleRowKombi(),
              puzzleRow(overrides: <String, Object?>{'difficulty': 'schwer'}),
              puzzleRow(overrides: <String, Object?>{'difficulty': 'leicht'}),
            ],
          },
        ),
      ]);

      expect(
        result.facts.single.easiestPuzzleDifficulty,
        PuzzleDifficulty.leicht,
      );
    });

    test('ohne bekannte Stufe bleibt sie null, ohne erfundenen Ersatz', () {
      final result = mapper.mapRecords(<Object?>[
        factRow(
          overrides: <String, Object?>{
            'puzzle_fit': <Object?>[
              puzzleRow(without: <String>{'difficulty'}),
            ],
          },
        ),
      ]);

      expect(result.facts.single.puzzles.single.difficulty, isNull);
      expect(result.facts.single.easiestPuzzleDifficulty, isNull);
    });
  });
}
