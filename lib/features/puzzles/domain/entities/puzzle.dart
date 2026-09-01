/// Der typisierte Rätselvertrag der Domäne `puzzles`.
///
/// ## Was das hier ist, und was es nicht ist
///
/// `FactPuzzle` in `features/facts/domain/` trägt die Rohdaten aus
/// `facts.puzzle_fit`, vollständig und unverändert, mit 21 Feldern und einem
/// **rohen** `type`-String. Diese Datei ist das Gegenstück: die **Form**, in
/// der ein Rätsel gespielt wird. Sechs Varianten, jede mit genau den Feldern,
/// die ihre Eingabemaske und ihre Auswertung brauchen.
///
/// Die Zuordnung von Rohdaten zu Form ist **nicht** hier, sondern in
/// `puzzles/application/`. Diese Domäne kennt `FactPuzzle` nicht und darf es
/// auch nicht: Gate 6 in `tool/check_architecture.dart` lässt eine
/// Feature-Domäne nicht in die Domäne eines fremden Features greifen, gemessen
/// am 30.08.2026. Wer hier einen `facts`-Import einträgt, bekommt Exit-Code 1
/// mit der Meldung „[domain] Domain-Erlaubnisliste".
///
/// ## Warum nicht alle 21 Felder mitkommen
///
/// Eine Variante, die alle Rohfelder trägt, wäre ein Duplikat einer
/// kanonischen Entität, und `docs/architecture/domain-map.md` §5 führt
/// „Duplicating canonical entities under multiple features" unter den
/// verbotenen Mechanismen. Draußen bleiben deshalb die Redaktionsfelder
/// `rationale` (`why`), `confidence`, `provenance` (`source`), `findability`
/// und `quality`. Sie steuern die Auswahl eines Rätsels in
/// `hunt-generator.jsx`, nicht sein Spielen; wer sie braucht, liest sie am
/// Fakt.
///
/// ## Warum der rohe [type] trotzdem bleibt
///
/// Er bestimmt die Form **nicht**, siehe unten. Die Kopfzeile des Sheets zeigt
/// ihn aber an: `puzzle-sheet.jsx:67-68` fällt bei einem unbekannten Typ auf
/// das Symbol `❓` und **den rohen Typ-String als Beschriftung** zurück, nicht
/// auf einen Ersatztext. Ohne dieses Feld wäre die Kopfzeile für die sechs
/// häufigsten Werte der Live-Daten leer.
///
/// ## Die Form kommt nicht aus [type]
///
/// `puzzle-sheet.jsx:242-272` entscheidet in drei Stufen, und die erste
/// gewinnt bedingungslos: sind Antwortoptionen da, wird als Auswahl gespielt,
/// **bevor** `type` überhaupt gelesen wird. Der Kommentar der Quelle
/// (`:243-246`) nennt den Grund: der Typ wird im Konverter aus einem Verb
/// geraten. Erst danach kommt der `switch`, und dessen Standardzweig ist in
/// den Live-Daten der Mengenschwerpunkt: sechs der elf vorkommenden Werte
/// kennt die Typtabelle gar nicht, zusammen 1469 Vorkommen
/// (`fact_puzzle.dart:90-93`). Die ganze Reihenfolge steht in
/// `puzzles/application/puzzle_from_fact_puzzle.dart`, dort und nur dort.
///
/// ## Warum [expectedAnswer] im Kopf steht und nicht in einer Variante
///
/// Weil drei Varianten es brauchen: Text (`:323`), Auswahl (`:350`) und
/// Kompass (`:450`). Ein Feld, das in drei von sechs Varianten wortgleich
/// stünde, gehört in den gemeinsamen Kopf.
///
/// ## Kein `==`, und das ist eine Entscheidung
///
/// Anders als `FactPuzzle` und die Wertobjekte in `facts` hat dieser Vertrag
/// keine Wertgleichheit. Sie wäre hier nicht billig: `listsEqual` und
/// `hashList` liegen in `facts/domain/structural_equality.dart`, und dieselbe
/// Sperre, die schon zwei Typkopien erzwingt, würde eine **dritte** erzwingen,
/// diesmal für einen Helfer, den in diesem Schritt niemand braucht. Wer
/// Wertgleichheit später doch braucht, hat mit ihr auch einen Grund; bis
/// dahin vergleichen die Tests Felder statt Objekte.
///
/// ## Was hier bewusst fehlt
///
/// Keine Prüfung einer Antwort, keine Hinweisstufen, keine Punkte, keine
/// Münzen. Das ist Schritt 28 bis 32 und hängt an E-08 und E-06.
library;

import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:fact_app/kernel/puzzle_operand.dart';

/// Ein Rätsel in der Form, in der es gespielt wird.
///
/// Versiegelt: die sechs Varianten unten sind vollständig, ein `switch` über
/// sie ist erschöpfend, und eine siebte Variante bricht jeden bestehenden
/// `switch` beim Analysieren ab statt still in einen `default`-Zweig zu
/// fallen.
sealed class Puzzle {
  /// Für die Varianten.
  const Puzzle({
    required this.question,
    required this.type,
    this.difficulty,
    this.expectedAnswer,
    this.hint,
    this.hints = const <String>[],
    this.explanation,
    this.photoUrl,
  });

  /// Die Aufgabe, wie sie dem Spieler gezeigt wird, `puzzle-sheet.jsx:195`.
  ///
  /// Das einzige Pflichtfeld. Ein Rätsel ohne Frage ist nicht spielbar, und
  /// `FactPuzzleMapper` verwirft solche Einträge schon beim Einlesen.
  final String question;

  /// Der rohe Typ aus den Daten, `null` wenn er fehlt.
  ///
  /// **Bestimmt die Form nicht.** Er steht hier für die Kopfzeile des Sheets,
  /// siehe den Kopf dieser Datei. Absichtlich `String?` und kein Enum: in den
  /// Live-Daten stehen elf Werte, sechs davon kennt die Typtabelle der Quelle
  /// nicht.
  final String? type;

  /// Schwierigkeitsstufe, `null` wenn sie fehlt oder unbekannt ist.
  ///
  /// Ohne Ersatzwert. Welcher gilt, entscheidet die Auswertung, siehe
  /// `PuzzleDifficulty`.
  final PuzzleDifficulty? difficulty;

  /// Die kanonische Antwort, `null` wo keine geschrieben wird.
  ///
  /// Foto-Rätsel prüfen nur Entfernung und Vorhandensein eines Fotos
  /// (`puzzle-sheet.jsx:372`), Zähl- und Kombinations-Rätsel rechnen mit
  /// eigenen Feldern.
  final String? expectedAnswer;

  /// Einzelner Tipp, `puzzle-sheet.jsx:210`. Kostet in der PWA Punkte.
  final String? hint;

  /// Gestufte Tipps, in den Daten meist drei.
  final List<String> hints;

  /// Auflösungstext, der nach dem Lösen gezeigt wird.
  final String? explanation;

  /// Historisches Foto (`puzzle_photo`), `puzzle-sheet.jsx:168`.
  ///
  /// Im Kopf und nicht in einer Variante: die Quelle zeigt den Foto-Block
  /// allein an diesem Feld, unabhängig von Typ und Form (`:168`, „Historisches
  /// Foto für Zeitreise-Rätsel", der Zweig fragt aber nur `puzzle.puzzle_photo`
  /// ab).
  final String? photoUrl;
}

/// Freies Textfeld, `PszTextInput`.
///
/// Über den Kopf hinaus keine eigenen Felder. Erreicht über die Typen
/// `detektiv-zaehlen`, `inschrift-decoder` und `local-fragen` **und über den
/// Standardzweig**, und der ist in den Live-Daten der häufigere Weg.
final class TextPuzzle extends Puzzle {
  /// Erzeugt ein Texträtsel.
  const TextPuzzle({
    required super.question,
    required super.type,
    super.difficulty,
    super.expectedAnswer,
    super.hint,
    super.hints,
    super.explanation,
    super.photoUrl,
  });
}

/// Antwortoptionen zum Antippen, `PszMcq`.
final class ChoicePuzzle extends Puzzle {
  /// Erzeugt ein Auswahlrätsel.
  const ChoicePuzzle({
    required super.question,
    required super.type,
    this.choices = const <String>[],
    super.difficulty,
    super.expectedAnswer,
    super.hint,
    super.hints,
    super.explanation,
    super.photoUrl,
  });

  /// Die Antwortoptionen, `puzzle-sheet.jsx:343`.
  ///
  /// **Darf leer sein, und das ist Parität, kein Versehen.** Der erste Guard
  /// der Quelle (`:247`) fängt jedes Rätsel mit gefüllten Optionen ab; die
  /// drei `switch`-Zweige, die trotzdem auf `PszMcq` zeigen
  /// (`klang-sinnes-check`, `verstecktes-detail`, `zeitreise`), sind deshalb
  /// **nur mit leerer Liste erreichbar**. Näheres am Übersetzer.
  final List<String> choices;

  /// Gibt es überhaupt etwas zum Auswählen?
  bool get hasChoices => choices.isNotEmpty;
}

/// Foto vor Ort, `PszPhoto`.
final class PhotoPuzzle extends Puzzle {
  /// Erzeugt ein Fotorätsel.
  const PhotoPuzzle({
    required super.question,
    required super.type,
    this.gpsRadiusMeters,
    super.difficulty,
    super.expectedAnswer,
    super.hint,
    super.hints,
    super.explanation,
    super.photoUrl,
  });

  /// Erlaubter Abstand zum Ort in Metern, `puzzle-sheet.jsx:372`.
  ///
  /// In den Daten durchgehend `150`. `null` heißt „steht nicht in den Daten";
  /// der Ersatzwert ist Auswertung und gehört Schritt 28.
  final int? gpsRadiusMeters;
}

/// Himmelsrichtung wählen, `PszKompass`.
///
/// Über den Kopf hinaus keine eigenen Felder: die acht Richtungen sind fest
/// (`puzzle-sheet.jsx:426`), und die erwartete Richtung steht als
/// [Puzzle.expectedAnswer] im Kopf.
///
/// **Achtung bei Schritt 28:** die Quelle vergleicht dort den **angezeigten**
/// Text (`t('puzzle.compass.N')` und so weiter) gegen `puzzle.expected` aus
/// den Fakt-Daten, das deutsch ist. Auf Englisch ist das Rätsel damit
/// unlösbar. Das ist E-08, der Fehler wird nicht nachgebaut, und
/// `app_strings.dart` sagt an seiner Stelle dasselbe.
final class CompassPuzzle extends Puzzle {
  /// Erzeugt ein Kompassrätsel.
  const CompassPuzzle({
    required super.question,
    required super.type,
    super.difficulty,
    super.expectedAnswer,
    super.hint,
    super.hints,
    super.explanation,
    super.photoUrl,
  });
}

/// Abzählen mit einem Zähler, `PszTapCounter`.
final class CountingPuzzle extends Puzzle {
  /// Erzeugt ein Zählrätsel.
  const CountingPuzzle({
    required super.question,
    required super.type,
    this.expectedCount,
    this.countTolerance,
    super.difficulty,
    super.expectedAnswer,
    super.hint,
    super.hints,
    super.explanation,
    super.photoUrl,
  });

  /// Erwartete Anzahl, `puzzle-sheet.jsx:461`.
  final int? expectedCount;

  /// Erlaubte Abweichung zu [expectedCount], `puzzle-sheet.jsx:462`.
  ///
  /// In der Quelle die Grenze für halbe Punkte. Was daraus folgt, entscheidet
  /// Schritt 28.
  final int? countTolerance;
}

/// Zwei Werte eingeben und verrechnen, `PszKombi`.
final class CombinationPuzzle extends Puzzle {
  /// Erzeugt ein Kombinationsrätsel.
  const CombinationPuzzle({
    required super.question,
    required super.type,
    this.operandA,
    this.operandB,
    this.formula,
    this.expectedResult,
    super.difficulty,
    super.expectedAnswer,
    super.hint,
    super.hints,
    super.explanation,
    super.photoUrl,
  });

  /// Erster Eingabewert, `puzzle-sheet.jsx:506`.
  final PuzzleOperand? operandA;

  /// Zweiter Eingabewert, `puzzle-sheet.jsx:506`.
  final PuzzleOperand? operandB;

  /// Rechenvorschrift, etwa `b - a` oder `a * b`, `puzzle-sheet.jsx:508`.
  ///
  /// Roh weitergegeben. Wer das auswertet, darf **nicht** wie die PWA
  /// (`:512`) einen `new Function`-Ausdruck daraus bauen. In Dart geht das
  /// ohnehin nicht; der Hinweis steht hier, damit niemand nach einem Ersatz
  /// dafür sucht.
  final String? formula;

  /// Erwartetes Ergebnis, `puzzle-sheet.jsx:509`.
  ///
  /// `num`, weil eine Formel auch dividieren kann. Das Verbot von
  /// Gleitkommazahlen in `data-flow.md` gilt für Münzen und XP, nicht für ein
  /// Rechenergebnis.
  final num? expectedResult;
}
