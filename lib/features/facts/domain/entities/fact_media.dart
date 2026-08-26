/// Das Bild zu einem Fakt.
///
/// Quelle ist `facts.hint_media`, ein `jsonb`-Objekt. Die Spalte steht **nicht**
/// in `03_Backend/supabase-schema.sql`, existiert aber: die Pipeline schreibt
/// sie über PostgREST (`04_Datenpipeline/scripts/import_facts.py:274` und
/// `enrich_hint_media.py`), und die PWA liest sie
/// (`02_Frontend/app/screen-fact.jsx:229`). Die eingecheckte Schemadatei ist
/// also unvollständig.
///
/// Die Feldnamen kommen aus `enrich_hint_media.py:406`, wo das Objekt gebaut
/// wird. Zwei Felder aus der Fundstelle werden vor dem Schreiben entfernt
/// (`_description_full`, `license_lower`) und tauchen deshalb hier nicht auf.
///
/// | Schlüssel | Feld hier |
/// |---|---|
/// | `url` | [imageUrl] |
/// | `thumb_url` | [thumbnailUrl] |
/// | `width` | [width] |
/// | `height` | [height] |
/// | `caption` | [caption] |
/// | `source_url` | [sourceUrl] |
/// | `license` | [license] |
/// | `attribution` | [attribution] |
/// | `year` | [year] |
/// | `source` | [provenance] |
class FactMedia {
  /// Alle Felder optional: die Pipeline füllt je nach Fundlage nur einen Teil.
  const FactMedia({
    this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.caption,
    this.sourceUrl,
    this.license,
    this.attribution,
    this.year,
    this.provenance,
  });

  /// Volle Auflösung, `url`.
  final String? imageUrl;

  /// Vorschau, `thumb_url`.
  final String? thumbnailUrl;

  /// Breite der vollen Auflösung in Pixeln.
  final int? width;

  /// Höhe der vollen Auflösung in Pixeln.
  final int? height;

  /// Bildbeschreibung aus den Commons-Metadaten.
  final String? caption;

  /// Seite, auf der das Bild samt Lizenz steht.
  final String? sourceUrl;

  /// Kurzname der Lizenz, etwa `CC BY-SA 4.0` oder `unknown`.
  final String? license;

  /// Urheber. Die Pipeline setzt ersatzweise `Wikimedia Commons`.
  final String? attribution;

  /// Aufnahmejahr, falls aus den Metadaten ableitbar. Trägt „Damals/Heute".
  final int? year;

  /// Wie das Bild gefunden wurde, etwa `wikipedia-source`.
  ///
  /// Heißt hier nicht `source`, weil das mit der Quellenangabe des Fakttexts
  /// (`facts.quelle`) verwechselbar wäre. `domain-map.md` zählt
  /// Provenienz-Metadaten ausdrücklich zum Besitz dieser Domäne.
  final String? provenance;

  /// Was in der Fakt-Akte oben stehen soll.
  ///
  /// Vorschau bevorzugt, weil `screen-fact.jsx:230` es so macht:
  /// `hintMedia?.thumb_url || hintMedia?.url`.
  String? get previewUrl => _firstUsable(thumbnailUrl, imageUrl);

  /// Was die Lightbox anzeigt: die volle Auflösung, ersatzweise die Vorschau
  /// (`screen-fact.jsx:274`).
  String? get fullUrl => _firstUsable(imageUrl, thumbnailUrl);

  /// Gibt es überhaupt ein Bild?
  bool get hasImage => previewUrl != null;

  /// Ist nichts gesetzt?
  bool get isEmpty =>
      imageUrl == null &&
      thumbnailUrl == null &&
      width == null &&
      height == null &&
      caption == null &&
      sourceUrl == null &&
      license == null &&
      attribution == null &&
      year == null &&
      provenance == null;

  static String? _firstUsable(String? first, String? second) {
    if (first != null && first.isNotEmpty) {
      return first;
    }
    if (second != null && second.isNotEmpty) {
      return second;
    }
    return null;
  }

  /// Kopie mit einzelnen geänderten Feldern.
  FactMedia copyWith({
    String? imageUrl,
    String? thumbnailUrl,
    int? width,
    int? height,
    String? caption,
    String? sourceUrl,
    String? license,
    String? attribution,
    int? year,
    String? provenance,
  }) {
    return FactMedia(
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      caption: caption ?? this.caption,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      license: license ?? this.license,
      attribution: attribution ?? this.attribution,
      year: year ?? this.year,
      provenance: provenance ?? this.provenance,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FactMedia &&
      other.imageUrl == imageUrl &&
      other.thumbnailUrl == thumbnailUrl &&
      other.width == width &&
      other.height == height &&
      other.caption == caption &&
      other.sourceUrl == sourceUrl &&
      other.license == license &&
      other.attribution == attribution &&
      other.year == year &&
      other.provenance == provenance;

  @override
  int get hashCode => Object.hash(
    imageUrl,
    thumbnailUrl,
    width,
    height,
    caption,
    sourceUrl,
    license,
    attribution,
    year,
    provenance,
  );

  @override
  String toString() => 'FactMedia(hasImage: $hasImage, year: $year)';
}
