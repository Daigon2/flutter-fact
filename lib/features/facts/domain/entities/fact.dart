import 'package:fact_app/features/facts/domain/entities/fact_media.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/structural_equality.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_city.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';

/// Ein Fakt: der kanonische Inhalt, sein Ort und alles, was am Datensatz hängt.
///
/// Besitz laut `docs/architecture/domain-map.md`: Identität und kanonischer
/// Inhalt, Ort und geografische Eignung, Kategorien, Veröffentlichungszustand,
/// Medienverweise und Provenienz-Metadaten. **Nicht** dabei: ob ein Nutzer
/// gesammelt hat (`collection`), Belohnungen (`progression`), Rätselmechanik
/// (`puzzles`), Stadt-Identität (`city`).
///
/// ## Quelle
///
/// Tabelle `public.facts` nach allen Migrationen. Die Zuordnung Spalte zu Feld
/// steht an den Feldern. Zwei Spalten stehen **nicht** in
/// `03_Backend/supabase-schema.sql`, existieren aber nachweislich, weil die
/// Pipeline sie über PostgREST schreibt und die PWA sie liest: `hint_media` und
/// `next_hints` (`04_Datenpipeline/scripts/import_facts.py:274` und `:275`).
/// `text3` und `text4` gehören ebenfalls zum gelesenen Vertrag
/// (`02_Frontend/app/api.jsx:25`, `screen-fact.jsx:411`), tauchen im
/// eingecheckten Schema aber nicht auf.
///
/// ## Keine Serialisierung
///
/// Absichtlich kein `fromJson` und kein `toJson`. `data-flow.md` §4: „Domain
/// entities do not implement Supabase serialization by default." Das Einlesen
/// macht `FactMapper` in der Datenschicht, und nur dort kann ein defektes Feld
/// gemeldet werden, statt zu werfen.
class Fact {
  /// Alle Pflichtangaben sind das, was ein Fakt ohne Rest braucht: eine
  /// Kennung und einen Inhalt. Der Rest hat einen sinnvollen Ausfallwert.
  const Fact({
    required this.id,
    required this.content,
    this.number,
    this.translations = const <String, FactText>{},
    this.coordinates,
    this.city,
    this.zone,
    this.genre,
    this.qualityScore,
    this.heroColors = defaultHeroColors,
    this.rating = 0,
    this.ratingCount = 0,
    this.isUserCreated = false,
    this.isApproved = false,
    this.createdBy,
    this.createdAtUtc,
    this.media,
    this.stationHints = const <String>[],
    this.nextStationHint,
    this.puzzles = const <FactPuzzle>[],
  });

  /// Der Vorgabewert der Spalte `hero`:
  /// `text[] default array['#2C3E50','#4A6741']`.
  ///
  /// Steht hier, damit ein unbrauchbarer Wert auf genau denselben Verlauf
  /// zurückfällt, den die Datenbank ohnehin geliefert hätte.
  static const List<String> defaultHeroColors = <String>['#2C3E50', '#4A6741'];

  /// `id`
  final FactId id;

  /// Die Textfelder der Standardsprache, also die flachen Spalten.
  ///
  /// Deutsch ist laut `2026-06-06_i18n_facts.sql` die „default-language source
  /// of truth". [translations] überschreibt hier hinein, siehe [contentFor].
  final FactText content;

  /// `nr`, die redaktionelle Nummer mit Stadt-Präfix, etwa `MUC_004`.
  ///
  /// Kein Ersatz für [id]: das Präfix ist gleichzeitig der Notnagel, mit dem
  /// der Trigger `handle_fact_collected` die Stadt errät, wenn [city] leer ist.
  final String? number;

  /// `_i18n`, Sprachkürzel auf Textbündel.
  ///
  /// Nur Überschreibungen, üblicherweise unvollständig. Der einzige erlaubte
  /// Zugriffsweg ist [contentFor]; die Migration sagt dazu ausdrücklich
  /// „DO NOT reach into `_i18n` directly anywhere else".
  final Map<String, FactText> translations;

  /// `lat` und `lng`, `null` wenn der Fakt keine brauchbare Koordinate hat.
  final FactCoordinates? coordinates;

  /// `city`, der Anzeigename. `null` ist erlaubt und kommt vor.
  final FactCity? city;

  /// `zone`: 1 Altstadt-Ring, 2 innerer Ring, 3 Außenring
  /// (`2026-05-14_add_zone_and_next_station_hint.sql`).
  final int? zone;

  /// `genre`, eine von acht redaktionellen Klassen.
  ///
  /// Als `String` und nicht als Enum: die erlaubten Werte stehen als
  /// `CHECK`-Bedingung in der Datenbank (`facts_genre_check`), und die gehört
  /// einem anderen Repository. Ein Enum hier würde einen neunten Wert stumm
  /// verwerfen.
  final String? genre;

  /// `quality_score`: 1 bis 3, `null` heißt nicht klassifiziert.
  final int? qualityScore;

  /// `hero`, zwei Hex-Farben für den Verlauf.
  ///
  /// Bleibt `String`, weil die Domäne kein `Color` kennen darf (Regel 1). Der
  /// Mapper lässt nur Werte in Hex-Form durch.
  final List<String> heroColors;

  /// `rating`, `numeric(3,1)`.
  final double rating;

  /// `bewertungen`, Anzahl der Bewertungen.
  ///
  /// Heißt hier nicht `bewertungen`, weil ein deutscher Spaltenname in der
  /// Domäne nichts erklärt.
  final int ratingCount;

  /// `is_user_created`
  final bool isUserCreated;

  /// `is_approved`, der Veröffentlichungszustand.
  ///
  /// Der Standard ist `false`, wie in der Datenbank. Ein Standard von `true`
  /// wäre gefährlich: die RLS-Policy „read facts" gibt unveröffentlichte
  /// Fakten nur dem Ersteller, und ein Modell, das sie stillschweigend als
  /// veröffentlicht führt, würde diesen Unterschied verwischen.
  final bool isApproved;

  /// `created_by`, die Kennung des Erstellers bei Nutzer-Fakten.
  final String? createdBy;

  /// `created_at`, immer in UTC.
  ///
  /// `data-flow.md` §4: Zeit wird in UTC transportiert und erst in der
  /// Präsentation umgerechnet.
  final DateTime? createdAtUtc;

  /// `hint_media`, das Bild zum Fakt.
  final FactMedia? media;

  /// `next_hints`, gestufte Hinweise auf den Ort dieses Fakts.
  ///
  /// In den Daten drei Stück, von vage zu deutlich
  /// (`import_facts.py:225` verlangt genau drei nicht leere Einträge, sonst
  /// schreibt die Pipeline `null`).
  ///
  /// Achtung beim Lesen alter Pläne: der REBUILD_PLAN nennt diese Spalte als
  /// Ersatz für `next_station_hint`. Das ist falsch, es sind zwei Spalten mit
  /// zwei Bedeutungen, und beide existieren.
  final List<String> stationHints;

  /// `next_station_hint`, ein Satz Vorfreude auf die **nächste** Station.
  final String? nextStationHint;

  /// `puzzle_fit`, die Rätsel an diesem Fakt.
  ///
  /// Leer heißt: keine Rätsel. Der Name ist bewusst nicht `puzzleFit`, siehe
  /// [PuzzleDifficulty].
  final List<FactPuzzle> puzzles;

  /// Titel in der Standardsprache.
  ///
  /// Der Mapper verwirft Fakten ohne Titel, dieser Wert ist also in der Praxis
  /// nie leer. Der Ausfallwert steht trotzdem hier, weil ein leerer Titel eine
  /// leere Zeile ist und kein Absturz sein soll.
  String get canonicalTitle => content.title ?? '';

  /// Kategorie in der Standardsprache.
  ///
  /// Das ist der **logische** Wert, nicht der Anzeigetext: an ihm hängen die
  /// Kategoriefarbe und die Trophäen-Auswertung im Backend, die mit
  /// `lower(f.kategorie) LIKE 'hist%'` arbeitet. Der übersetzte Anzeigetext
  /// steht in `contentFor(...).category`, weil `kategorie` in `_i18n`
  /// mitübersetzt wird (`api.jsx:25`).
  String get canonicalCategory => content.category ?? '';

  /// Liegt der Fakt auf der Karte?
  bool get hasLocation => coordinates != null;

  /// Hat der Fakt spielbare Rätsel?
  bool get hasPuzzles => puzzles.isNotEmpty;

  /// Die leichteste vorhandene Rätselstufe, `null` wenn keine Stufe bekannt ist.
  ///
  /// Ersetzt den alten, doppelt belegten `puzzleFit`-String. Rein abgeleitet:
  /// hier wird nichts gespeichert, was nicht in [puzzles] steht.
  PuzzleDifficulty? get easiestPuzzleDifficulty {
    PuzzleDifficulty? easiest;
    for (final puzzle in puzzles) {
      final difficulty = puzzle.difficulty;
      if (difficulty == null) {
        continue;
      }
      if (easiest == null || difficulty.index < easiest.index) {
        easiest = difficulty;
      }
    }
    return easiest;
  }

  /// Sprachkürzel, für die eine Übersetzung vorliegt, alphabetisch.
  ///
  /// Pendant zu `public.fact_i18n_langs` aus der i18n-Migration.
  List<String> get translatedLanguageCodes {
    final codes = translations.keys.toList()..sort();
    return List<String>.unmodifiable(codes);
  }

  /// Der Text in [languageCode], mit Rückfall.
  ///
  /// Reihenfolge, exakt wie `window.pickFact` in `02_Frontend/app/api.jsx:23`:
  ///
  /// 1. `_i18n[languageCode]`
  /// 2. `_i18n[fallbackLanguageCode]`
  /// 3. die flachen Spalten, also [content]
  ///
  /// Feldweise, nicht bündelweise: fehlt in der englischen Übersetzung nur
  /// `text4`, kommt genau dieses eine Feld aus der Ebene darunter. Ein leerer
  /// String zählt als „nicht übersetzt", siehe `FactText.overriddenBy`.
  ///
  /// ## Warum die Sprachauswahl hier greift und nicht im Mapper
  ///
  /// Der Mapper könnte die Sprache anwenden und einen einsprachigen Fakt
  /// liefern. Dagegen sprechen vier Dinge:
  ///
  /// * Ein Sprachwechsel würde ein Neuladen aus dem Netz erzwingen, obwohl
  ///   beide Sprachen längst im Speicher liegen. Bei rund 600 Fakten pro Stadt
  ///   ist das ein sichtbarer Aussetzer für nichts.
  /// * Das Repository bräuchte einen Sprachparameter. Damit wanderte eine
  ///   Oberflächen-Einstellung in einen Datenvertrag, und
  ///   `cross-cutting-concerns.md` trennt Inhaltssprache und
  ///   Oberflächensprache ausdrücklich.
  /// * Der Rückfall pro Feld ist eine Regel über den Inhalt, also
  ///   Domänenwissen. Er gehört nicht in die Datenschicht, wo er beim nächsten
  ///   Wechsel des Backends mitwandern würde.
  /// * `_i18n` ist auf weitere Sprachen ausgelegt („Adding a new language =
  ///   just populate `_i18n.<code>`; no screen change needed"). Ein Modell, das
  ///   alle mitträgt, hält das ein.
  ///
  /// Deshalb ist der Parameter ein nackter Sprachcode und kein `AppLanguage`:
  /// die Domäne darf `lib/app/` nicht kennen. Die Präsentation gibt
  /// `AppLanguage.code` und `AppLanguage.fallback.code` hinein.
  FactText contentFor(String languageCode, {String? fallbackLanguageCode}) {
    var resolved = content;
    if (fallbackLanguageCode != null &&
        fallbackLanguageCode != languageCode &&
        translations.containsKey(fallbackLanguageCode)) {
      resolved = resolved.overriddenBy(translations[fallbackLanguageCode]);
    }
    return resolved.overriddenBy(translations[languageCode]);
  }

  /// Kopie mit einzelnen geänderten Feldern.
  Fact copyWith({
    FactId? id,
    FactText? content,
    String? number,
    Map<String, FactText>? translations,
    FactCoordinates? coordinates,
    FactCity? city,
    int? zone,
    String? genre,
    int? qualityScore,
    List<String>? heroColors,
    double? rating,
    int? ratingCount,
    bool? isUserCreated,
    bool? isApproved,
    String? createdBy,
    DateTime? createdAtUtc,
    FactMedia? media,
    List<String>? stationHints,
    String? nextStationHint,
    List<FactPuzzle>? puzzles,
  }) {
    return Fact(
      id: id ?? this.id,
      content: content ?? this.content,
      number: number ?? this.number,
      translations: translations ?? this.translations,
      coordinates: coordinates ?? this.coordinates,
      city: city ?? this.city,
      zone: zone ?? this.zone,
      genre: genre ?? this.genre,
      qualityScore: qualityScore ?? this.qualityScore,
      heroColors: heroColors ?? this.heroColors,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      isApproved: isApproved ?? this.isApproved,
      createdBy: createdBy ?? this.createdBy,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      media: media ?? this.media,
      stationHints: stationHints ?? this.stationHints,
      nextStationHint: nextStationHint ?? this.nextStationHint,
      puzzles: puzzles ?? this.puzzles,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Fact &&
      other.id == id &&
      other.content == content &&
      other.number == number &&
      mapsEqual(other.translations, translations) &&
      other.coordinates == coordinates &&
      other.city == city &&
      other.zone == zone &&
      other.genre == genre &&
      other.qualityScore == qualityScore &&
      listsEqual(other.heroColors, heroColors) &&
      other.rating == rating &&
      other.ratingCount == ratingCount &&
      other.isUserCreated == isUserCreated &&
      other.isApproved == isApproved &&
      other.createdBy == createdBy &&
      other.createdAtUtc == createdAtUtc &&
      other.media == media &&
      listsEqual(other.stationHints, stationHints) &&
      other.nextStationHint == nextStationHint &&
      listsEqual(other.puzzles, puzzles);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    content,
    number,
    hashMap(translations),
    coordinates,
    city,
    zone,
    genre,
    qualityScore,
    hashList(heroColors),
    rating,
    ratingCount,
    isUserCreated,
    isApproved,
    createdBy,
    createdAtUtc,
    media,
    hashList(stationHints),
    nextStationHint,
    hashList(puzzles),
  ]);

  /// Bewusst ohne Inhalt und ohne Koordinate.
  ///
  /// `toString()` landet in Logs. Titel und Text sind zwar öffentlicher
  /// Inhalt, aber eine Log-Zeile pro Fakt bei 600 Fakten ist nur Lärm, und die
  /// Koordinate hat dort nach `security.md` §6 nichts zu suchen.
  @override
  String toString() =>
      'Fact(${id.value}, nr: $number, Rätsel: ${puzzles.length})';
}
