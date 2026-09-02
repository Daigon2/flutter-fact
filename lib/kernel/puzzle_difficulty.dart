/// Schwierigkeitsstufe eines Rätsels.
///
/// ## Warum dieser Typ im geteilten Kern liegt
///
/// Er wird von **drei** Feature-Domänen gebraucht, und das ist nachgewiesen und
/// nicht vorhergesehen (ADR-008, Aufnahmeregel 1):
///
/// | Domäne | Bedarf |
/// |---|---|
/// | `facts` | Die Stufe steht in den Rätselobjekten von `facts.puzzle_fit`. |
/// | `puzzles` | Die Auswertung staffelt die Belohnung danach. |
/// | `challenges` | Die laufende Jagd trägt ihre Stufe (D-18). |
///
/// Vor ADR-008 gab es ihn deshalb zweimal: `FactPuzzleDifficulty` in
/// `facts/domain` und eine wortgleiche Kopie `PuzzleDifficulty` in
/// `puzzles/domain`. Die Kopie hat sich selbst als solche gemeldet und die
/// Bedingung genannt, unter der sie verschwindet. Der dritte Bedarf,
/// `challenges`, war nicht mehr durch eine Kopie zu decken: `challenges/domain`
/// hätte eine vierte gebraucht, und eine Aufzählung mit Bedeutung kann
/// auseinanderlaufen, ohne dass ein Test es merkt.
///
/// ## Warum er die Aufnahmeregeln erfüllt
///
/// **Reines Dart** (Regel 2): kein Flutter, kein Riverpod, kein Vendor-SDK,
/// kein `core`, kein Feature.
///
/// **Kein rollengebundenes Verhalten** (Regel 3): [fromCode] gilt für jeden
/// Nutzer dieses Typs, denn der Rohwert kommt in allen drei Domänen aus
/// derselben Quelle. Das ist der Unterschied zu den drei Geo-Typen aus D-9,
/// die **nicht** in den Kern gehören: dort trägt `FactCoordinates` eine Prüfung
/// ungeprüfter Rohwerte und `MapPosition` eine Haversine-Rechnung, also zwei
/// rollengebundene Verhalten, die ein geteilter Typ beide auf sich vereinen
/// müsste.
///
/// ## Die Werte sind Daten, nicht Oberflächentext
///
/// Sie stehen so in den Rätselobjekten von `facts.puzzle_fit`
/// (`04_Datenpipeline/prompts/puzzle_classifier.md`, Regel 2 und
/// Ausgabeformat) und sind deshalb deutsch. Wer sie anzeigt, übersetzt über
/// `AppStrings` und nicht über [code].
///
/// ## Nicht zu verwechseln mit dem alten `puzzle_fit`
///
/// Früher **war** `facts.puzzle_fit` selbst ein solcher String. Heute ist die
/// Spalte ein Array von Rätselobjekten, und die Stufe steht in jedem einzelnen
/// Objekt. Der alte Flutter-Port trug beide Bedeutungen im gleichen Feldnamen
/// (`08_Flutter/lib/models/fact.dart:39`) und hat sich damit die gesamte
/// Rätselmechanik weggeschnitten. Deshalb heißt die Liste `Fact.puzzles` und
/// eine abgeleitete Stufe `Fact.easiestPuzzleDifficulty`. Der Name `puzzleFit`
/// kommt nicht mehr vor.
///
/// ## Kein Standardwert
///
/// Fehlt die Stufe an einem Rätsel, bleibt sie `null`. Ein erfundener Standard
/// wäre gefährlich: `puzzle-sheet.jsx:92` setzt beim Fehlen `mittel` an, und
/// daran hängt die Münz-Berechnung; der alte Port setzte an derselben Stelle
/// `leicht` (`fact.dart:337`). Wer welchen Ersatzwert nimmt, ist eine Frage der
/// Belohnungslogik und gehört `puzzles` und `progression`, nicht diesem Typ.
/// **Genau deshalb steht hier auch kein Ersatzwert**, obwohl der Kern der
/// bequemste Ort dafür wäre: er würde die Entscheidung vor allen drei Domänen
/// verstecken.
library;

/// Die drei Stufen, wie sie in den Daten stehen.
enum PuzzleDifficulty {
  /// Muss jeder Tourist lösen können.
  leicht('leicht'),

  /// Mittel.
  mittel('mittel'),

  /// Schwer.
  schwer('schwer');

  const PuzzleDifficulty(this.code);

  /// Der Wert, wie er in den Daten steht.
  final String code;

  /// Stufe zu [code] oder `null`, wenn der Wert unbekannt ist.
  ///
  /// Groß- und Kleinschreibung sowie Rand-Leerzeichen werden geglättet, weil
  /// die Daten von einem Sprachmodell und aus mehreren Pipeline-Generationen
  /// stammen.
  static PuzzleDifficulty? fromCode(String? code) {
    if (code == null) {
      return null;
    }
    final String normalized = code.trim().toLowerCase();
    for (final PuzzleDifficulty value in values) {
      if (value.code == normalized) {
        return value;
      }
    }
    return null;
  }
}
