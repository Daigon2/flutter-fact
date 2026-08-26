import 'package:fact_app/features/facts/data/mappers/fact_puzzle_mapper.dart';
import 'package:fact_app/features/facts/data/mappers/raw_record_reader.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_media.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_defect.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';

/// Was beim Einlesen einer Antwort herausgekommen ist.
///
/// Datenschicht-Typ, kein Domänentyp: er trägt [recordCount], und das ist eine
/// Transportgröße. Das Repository braucht sie, um zu erkennen, ob noch eine
/// weitere Seite kommt, und macht daraus danach einen `FactBatch`. Diese Zahl
/// hat in der Domäne nichts zu suchen und verlässt die Datenschicht nicht
/// (`project-structure.md`: DTOs bleiben in `data`).
class FactMappingResult {
  /// Beide Listen werden unveränderlich übernommen.
  FactMappingResult({
    required List<Fact> facts,
    required List<FactDefect> defects,
    required this.recordCount,
  }) : facts = List<Fact>.unmodifiable(facts),
       defects = List<FactDefect>.unmodifiable(defects);

  /// Die brauchbaren Fakten.
  final List<Fact> facts;

  /// Alles, was ausgefallen oder degradiert ist.
  final List<FactDefect> defects;

  /// Wie viele Elemente die Antwort hatte, unabhängig davon, wie viele davon
  /// brauchbar waren. `-1`, wenn die Antwort gar keine Liste war.
  final int recordCount;
}

/// Wandelt Rohantworten der `facts`-Tabelle in Fakten um.
///
/// ## Der eine Zweck
///
/// Ein einzelner defekter Wert in den Live-Daten darf höchstens einen Fakt
/// kosten und niemals die ganze Liste. Das gilt hier nicht durch Sorgfalt,
/// sondern durch drei bauliche Vorkehrungen:
///
/// 1. Jeder Rohzugriff läuft über `RawRecordReader`. Dort gibt es keinen
///    `as`-Cast auf einen Rohwert, also kann keiner scheitern.
/// 2. Jeder Datensatz wird einzeln in einem `try` abgebildet. Selbst ein Fehler
///    **in diesem Mapper** kostet dann nur diesen Datensatz. Ein pauschales
///    `catch` ist normalerweise eine schlechte Angewohnheit; hier ist es die
///    Anforderung, und der Fall wird als
///    `FactDefectKind.unexpectedMappingError` gemeldet, statt zu verschwinden.
/// 3. Es gibt keinen statischen Ersatzdatensatz und soll keinen geben. Kommt
///    nichts an, ist die Liste leer, und der Bericht sagt warum.
///
/// ## Warum es keine DTO-Klasse gibt
///
/// `project-structure.md` sieht `data/dto/` vor. Eine `FactDto` mit typisierten
/// Feldern bräuchte für jedes Feld genau die Casts, die dieser Schritt
/// abschaffen soll, und würde die Cast-Falle nur eine Ebene tiefer verstecken.
/// Die Rohzeile bleibt deshalb ein `Object?`, das ausschließlich über den
/// tolerant lesenden Leser angefasst wird. [FactMappingResult] ist der
/// Datenschicht-Typ, der die Grenze markiert; er verlässt `data` nicht.
class FactMapper {
  /// Zustandslos, [puzzleMapper] ist austauschbar.
  const FactMapper({this.puzzleMapper = const FactPuzzleMapper()});

  /// Vorgabewert der Spalte `kategorie`: `text not null default 'Fun-Fact'`.
  ///
  /// Nur Ausfallwert, kein Ersatz für fehlende Redaktionsarbeit.
  static const String defaultCategory = 'Fun-Fact';

  /// Baut die Rätsel eines Fakts.
  final FactPuzzleMapper puzzleMapper;

  static final RegExp _hexColor = RegExp(
    r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
  );

  /// Bildet eine ganze Antwort ab.
  ///
  /// [raw] ist das, was das Backend geliefert hat, ungeprüft. Ist es keine
  /// Liste, kommt ein leeres Ergebnis mit einem
  /// `FactDefectKind.responseNotAList` zurück. Geworfen wird nicht: ob daraus
  /// ein Fehlschlag wird, entscheidet das Repository.
  FactMappingResult mapRecords(Object? raw) {
    if (raw is! List) {
      return FactMappingResult(
        facts: const <Fact>[],
        defects: <FactDefect>[
          FactDefect(
            kind: FactDefectKind.responseNotAList,
            field: FactDefect.wholeRecord,
            factReference: FactDefect.unknownReference,
            encounteredType: RawRecordReader.typeNameOf(raw),
          ),
        ],
        recordCount: -1,
      );
    }

    final facts = <Fact>[];
    final defects = <FactDefect>[];
    for (final element in raw) {
      final Object? record = element;
      try {
        final fact = mapRecord(record, defects: defects);
        if (fact != null) {
          facts.add(fact);
        }
      } catch (error) {
        defects.add(
          FactDefect(
            kind: FactDefectKind.unexpectedMappingError,
            field: FactDefect.wholeRecord,
            factReference: FactDefect.unknownReference,
            encounteredType: error.runtimeType.toString(),
          ),
        );
      }
    }
    return FactMappingResult(
      facts: facts,
      defects: defects,
      recordCount: raw.length,
    );
  }

  /// Bildet einen einzelnen Datensatz ab.
  ///
  /// Gibt `null` zurück, wenn der Datensatz nicht brauchbar ist, und legt in
  /// [defects] ab, warum. Ein degradierter, aber brauchbarer Fakt kommt zurück
  /// **und** hinterlässt Befunde.
  ///
  /// Pflichtfelder sind genau zwei: eine positive `id` und ein nicht leerer
  /// `titel`. Beides ist in der Datenbank `not null` beziehungsweise erzeugt.
  /// Alles andere hat einen sinnvollen Ausfallwert, und deshalb degradiert
  /// alles andere nur.
  Fact? mapRecord(Object? raw, {required List<FactDefect> defects}) {
    final reader = RawRecordReader(raw);

    if (!reader.isRecord) {
      defects.add(
        FactDefect(
          kind: FactDefectKind.recordNotAnObject,
          field: FactDefect.wholeRecord,
          factReference: FactDefect.unknownReference,
          encounteredType: RawRecordReader.typeNameOf(raw),
        ),
      );
      return null;
    }

    final number = reader.optionalString('nr');
    final idValue = reader.optionalInt('id');
    final reference =
        number ?? idValue?.toString() ?? FactDefect.unknownReference;

    if (idValue == null || idValue <= 0) {
      defects.add(
        FactDefect(
          kind: FactDefectKind.requiredFieldUnusable,
          field: 'id',
          factReference: reference,
          encounteredType: RawRecordReader.typeNameOf(reader.rawValue('id')),
        ),
      );
      return null;
    }

    final title = reader.optionalString('titel');
    if (title == null) {
      defects.add(
        FactDefect(
          kind: FactDefectKind.requiredFieldUnusable,
          field: 'titel',
          factReference: reference,
          encounteredType: RawRecordReader.typeNameOf(reader.rawValue('titel')),
        ),
      );
      return null;
    }

    final content = FactText(
      title: title,
      body: reader.optionalString('text'),
      bodyExtra: reader.optionalString('text2'),
      bodyBackground: reader.optionalString('text3'),
      bodyToday: reader.optionalString('text4'),
      place: reader.optionalString('ort'),
      category: reader.optionalString('kategorie') ?? defaultCategory,
      source: reader.optionalString('quelle'),
      caption: reader.optionalString('caption'),
    );

    final puzzles = _readPuzzles(
      reader,
      defects: defects,
      factReference: reference,
    );

    final fact = Fact(
      id: FactId(idValue),
      content: content,
      number: number,
      translations: _readTranslations(reader),
      coordinates: _readCoordinates(reader),
      city: _readCity(reader),
      zone: reader.optionalInt('zone'),
      genre: reader.optionalString('genre'),
      qualityScore: reader.optionalIntInRange('quality_score', min: 1, max: 3),
      heroColors: _readHeroColors(reader),
      rating: reader.optionalDouble('rating') ?? 0,
      ratingCount: reader.optionalInt('bewertungen') ?? 0,
      isUserCreated: reader.boolOr('is_user_created', orElse: false),
      isApproved: reader.boolOr('is_approved', orElse: false),
      createdBy: reader.optionalString('created_by'),
      createdAtUtc: reader.optionalUtcTimestamp('created_at'),
      media: _readMedia(reader),
      stationHints: reader.stringList('next_hints'),
      nextStationHint: reader.optionalString('next_station_hint'),
      puzzles: puzzles,
    );

    for (final defect in reader.defects) {
      defects.add(
        FactDefect(
          kind: FactDefectKind.optionalFieldUnusable,
          field: defect.field,
          factReference: reference,
          encounteredType: defect.encounteredType,
        ),
      );
    }
    return fact;
  }

  /// `lat` und `lng`.
  ///
  /// Beide fehlen: kein Mangel, ein Fakt ohne Koordinate ist erlaubt. Beide da,
  /// aber außerhalb des gültigen Bereichs: Mangel, und der Fakt bleibt ohne
  /// Punkt in der Liste.
  static FactCoordinates? _readCoordinates(RawRecordReader reader) {
    final latitude = reader.optionalDouble('lat');
    final longitude = reader.optionalDouble('lng');
    final coordinates = FactCoordinates.tryFrom(
      latitude: latitude,
      longitude: longitude,
    );
    if (coordinates == null && latitude != null && longitude != null) {
      reader.recordDefect('lat/lng', 'außerhalb des Wertebereichs');
    }
    return coordinates;
  }

  /// `city`.
  ///
  /// `null` ist kein Mangel. Die Spalte kam erst mit der Migration vom
  /// 2026-06-07 dazu und ist für neue Datensätze leer, bis der Backfill läuft.
  /// Der Trigger `handle_fact_collected` errät die Stadt dann aus dem
  /// `nr`-Präfix. Diese Notlösung wird hier **nicht** nachgebaut: sie steckt
  /// mit fest verdrahteten Stadtnamen im Backend, und sie im Client zu
  /// verdoppeln würde eine zweite Fassung derselben Liste erzeugen, die
  /// auseinanderlaufen kann. Ein Fakt ohne Stadt trägt hier `null` und fällt
  /// bei einem Stadtfilter heraus.
  static FactCity? _readCity(RawRecordReader reader) {
    final name = reader.optionalString('city');
    return name == null ? null : FactCity(name);
  }

  /// `hero`.
  ///
  /// Die Spalte ist `text[]` mit Vorgabe `array['#2C3E50','#4A6741']` und kommt
  /// als JSON-Liste an. Ein `as String` bricht dort, genau das war eine der
  /// bekannten Fallen. Hier degradiert der Fall auf denselben Verlauf, den die
  /// Datenbank ohnehin vorgibt.
  static List<String> _readHeroColors(RawRecordReader reader) {
    if (reader.rawValue('hero') == null) {
      return Fact.defaultHeroColors;
    }
    final entries = reader.stringList('hero');
    final valid = entries.where(_hexColor.hasMatch).toList();
    if (valid.length != entries.length) {
      reader.recordDefect('hero', 'keine Hex-Farbe');
    }
    if (valid.isEmpty) {
      return Fact.defaultHeroColors;
    }
    return List<String>.unmodifiable(valid);
  }

  /// `hint_media`.
  ///
  /// Drei Formen sind erlaubt, und alle drei kommen vor: das Objekt, das die
  /// Pipeline schreibt, eine nackte URL als Text, und `null`. Die Toleranz für
  /// die nackte URL ist übernommen, nicht erfunden: der alte Port hat sie
  /// begründet (`08_Flutter/lib/models/fact.dart:98`).
  static FactMedia? _readMedia(RawRecordReader reader) {
    final Object? raw = reader.rawValue('hint_media');
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      final url = raw.trim();
      if (url.startsWith('http')) {
        return FactMedia(imageUrl: url);
      }
      if (url.isEmpty || url == 'null') {
        return null;
      }
      reader.recordDefect('hint_media', 'String ohne URL');
      return null;
    }
    final object = reader.optionalObject('hint_media');
    if (object == null) {
      return null;
    }
    final media = RawRecordReader(object);
    final result = FactMedia(
      imageUrl: media.optionalString('url'),
      thumbnailUrl: media.optionalString('thumb_url'),
      width: media.optionalInt('width'),
      height: media.optionalInt('height'),
      caption: media.optionalString('caption'),
      sourceUrl: media.optionalString('source_url'),
      license: media.optionalString('license'),
      attribution: media.optionalString('attribution'),
      year: media.optionalInt('year'),
      provenance: media.optionalString('source'),
    );
    for (final defect in media.defects) {
      reader.recordDefect('hint_media.${defect.field}', defect.encounteredType);
    }
    return result.isEmpty ? null : result;
  }

  /// `_i18n`.
  ///
  /// Form laut `2026-06-06_i18n_facts.sql`: Sprachkürzel auf ein Objekt mit
  /// denselben Textschlüsseln wie die flachen Spalten. Ein Eintrag, der gar
  /// keine Textfelder trägt, wird weggelassen, damit
  /// `Fact.translatedLanguageCodes` keine Sprache behauptet, die es nicht gibt.
  ///
  /// Der Zugriff geht ausschließlich hierüber. Die Migration sagt dazu
  /// „DO NOT reach into `_i18n` directly anywhere else", und das gilt in diesem
  /// Client genauso: außer diesem Mapper und `Fact.contentFor` kennt niemand
  /// die Spalte.
  static Map<String, FactText> _readTranslations(RawRecordReader reader) {
    if (reader.rawValue('_i18n') == null) {
      return const <String, FactText>{};
    }
    final object = reader.optionalObject('_i18n');
    if (object == null) {
      return const <String, FactText>{};
    }
    final translations = <String, FactText>{};
    for (final entry in object.entries) {
      final Object? key = entry.key;
      final Object? value = entry.value;
      if (key is! String || key.trim().isEmpty) {
        reader.recordDefect('_i18n', 'Schlüssel ist kein Sprachkürzel');
        continue;
      }
      final code = key.trim();
      if (value == null) {
        continue;
      }
      if (value is! Map<Object?, Object?>) {
        reader.recordDefect('_i18n.$code', RawRecordReader.typeNameOf(value));
        continue;
      }
      final language = RawRecordReader(value);
      final text = FactText(
        title: language.optionalString('titel'),
        body: language.optionalString('text'),
        bodyExtra: language.optionalString('text2'),
        bodyBackground: language.optionalString('text3'),
        bodyToday: language.optionalString('text4'),
        place: language.optionalString('ort'),
        category: language.optionalString('kategorie'),
        source: language.optionalString('quelle'),
        caption: language.optionalString('caption'),
      );
      for (final defect in language.defects) {
        reader.recordDefect(
          '_i18n.$code.${defect.field}',
          defect.encounteredType,
        );
      }
      if (!text.isEmpty) {
        translations[code] = text;
      }
    }
    return Map<String, FactText>.unmodifiable(translations);
  }

  /// `puzzle_fit`.
  ///
  /// Drei Formen, und die Unterscheidung ist der Kern des alten Fehlers:
  ///
  /// * `null`: keine Rätsel, kein Mangel. Der Klassifikator lief für diesen
  ///   Fakt noch nicht.
  /// * Liste: der heutige Vertrag, zwei bis vier Rätselobjekte.
  /// * Text: die **alte** Bedeutung, ein Schwierigkeitsstring
  ///   `leicht|mittel|schwer`. Wird als `obsoleteFieldShape` gemeldet und
  ///   ignoriert. Eine Schwierigkeit ohne Rätsel ist für diese App wertlos,
  ///   deshalb wird daraus nichts gerettet; wer eine Stufe braucht, nimmt
  ///   `Fact.easiestPuzzleDifficulty`.
  ///
  /// Ein unbrauchbares Element der Liste kostet genau dieses Rätsel, nicht die
  /// übrigen und erst recht nicht den Fakt.
  List<FactPuzzle> _readPuzzles(
    RawRecordReader reader, {
    required List<FactDefect> defects,
    required String factReference,
  }) {
    final Object? raw = reader.rawValue('puzzle_fit');
    if (raw == null) {
      return const <FactPuzzle>[];
    }
    if (raw is String) {
      // Nicht über den Leser gemeldet: der kennt nur eine Befundart, und die
      // veraltete Form ist ausdrücklich etwas anderes als ein kaputtes Feld.
      defects.add(
        FactDefect(
          kind: FactDefectKind.obsoleteFieldShape,
          field: 'puzzle_fit',
          factReference: factReference,
          encounteredType: 'String (alte Schwierigkeitsform)',
        ),
      );
      return const <FactPuzzle>[];
    }
    final elements = reader.rawList('puzzle_fit');
    if (elements == null) {
      reader.recordDefect('puzzle_fit', RawRecordReader.typeNameOf(raw));
      return const <FactPuzzle>[];
    }
    final puzzles = <FactPuzzle>[];
    for (var index = 0; index < elements.length; index++) {
      final puzzle = puzzleMapper.mapPuzzle(
        elements[index],
        reader: reader,
        path: 'puzzle_fit[$index]',
      );
      if (puzzle != null) {
        puzzles.add(puzzle);
      }
    }
    return List<FactPuzzle>.unmodifiable(puzzles);
  }
}
