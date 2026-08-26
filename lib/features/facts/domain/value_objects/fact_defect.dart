/// Ein einzelner Datenmangel, den das Einlesen überlebt hat.
///
/// Der Zweck: verworfene oder beschnittene Fakten dürfen nicht schweigend
/// verschwinden. Ein Mangel ist kein Fehler im Sinne von
/// `docs/architecture/cross-cutting-concerns.md`, er bricht nichts ab. Er ist
/// ein zählbarer Befund, den Tests prüfen und eine Diagnose-Senke melden kann.
library;

/// Wie schwer ein Mangel wirkt.
enum FactDefectKind {
  /// Die Antwort war überhaupt keine Liste. Es kommt kein einziger Fakt an.
  responseNotAList,

  /// Ein Element der Liste war kein Objekt. Dieser eine Datensatz fällt aus.
  recordNotAnObject,

  /// Ein Pflichtfeld fehlt oder ist unbrauchbar. Dieser Fakt fällt aus der
  /// Liste, die übrigen bleiben.
  requiredFieldUnusable,

  /// Ein optionales Feld ist unbrauchbar. Der Fakt bleibt, das Feld fällt weg
  /// oder erhält seinen Standardwert.
  optionalFieldUnusable,

  /// Das Feld trägt eine veraltete Form, die es früher einmal hatte. Der Fakt
  /// bleibt, das Feld wird ignoriert. Signalisiert alte Daten, nicht Bruch.
  obsoleteFieldShape,

  /// Beim Einlesen dieses Datensatzes ist etwas geflogen, das hier nicht
  /// vorgesehen war. Der Datensatz fällt aus, die Liste bleibt. Tritt dieser
  /// Fall auf, ist der Mapper zu eng gebaut.
  unexpectedMappingError,
}

/// Ein Befund zu genau einem Feld eines Datensatzes.
class FactDefect {
  /// [factReference] identifiziert den Datensatz für einen Menschen, der ihn in
  /// der Datenbank suchen muss.
  const FactDefect({
    required this.kind,
    required this.field,
    required this.factReference,
    this.encounteredType,
  });

  /// Wird gesetzt, wenn kein Bezug ermittelbar war.
  static const String unknownReference = '?';

  /// Steht als [field], wenn der Mangel nicht an einem einzelnen Feld hängt.
  static const String wholeRecord = '*';

  /// Wie schwer der Mangel wirkt.
  final FactDefectKind kind;

  /// Herkunftsfeld in den Rohdaten.
  ///
  /// Bewusst der **Spaltenname** des Backends (`hero`, `puzzle_fit`, `_i18n`)
  /// und nicht der Domänenname. `api-and-domain-design.md` verlangt, dass DTOs
  /// keine Backend-Namen in die Domäne tragen, und diese eine Ausnahme ist
  /// begründet: der Bericht existiert genau dafür, den defekten Datensatz in
  /// Supabase zu finden. Ein übersetzter Feldname wäre dort wertlos.
  final String field;

  /// `nr` des Fakts, sonst die `id`, sonst [unknownReference].
  ///
  /// Trägt nie Inhalt: kein Titel, kein Text, keine Koordinate. Der Bericht
  /// darf in einer Diagnose-Senke landen, und dort gilt
  /// `cross-cutting-concerns.md`.
  final String factReference;

  /// Der Laufzeittyp, der stattdessen dastand, etwa `String` statt `List`.
  ///
  /// Nur der Typname, nie der Wert.
  final String? encounteredType;

  /// Fällt der ganze Fakt weg?
  bool get discardsFact =>
      kind == FactDefectKind.responseNotAList ||
      kind == FactDefectKind.recordNotAnObject ||
      kind == FactDefectKind.requiredFieldUnusable ||
      kind == FactDefectKind.unexpectedMappingError;

  @override
  bool operator ==(Object other) =>
      other is FactDefect &&
      other.kind == kind &&
      other.field == field &&
      other.factReference == factReference &&
      other.encounteredType == encounteredType;

  @override
  int get hashCode => Object.hash(kind, field, factReference, encounteredType);

  @override
  String toString() =>
      'FactDefect(${kind.name}, Feld: $field, Fakt: $factReference'
      '${encounteredType == null ? '' : ', vorgefunden: $encounteredType'})';
}
