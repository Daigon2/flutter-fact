import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/structural_equality.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_import_report.dart';

/// Das Ergebnis eines Lesevorgangs: die heil gebliebenen Fakten und der
/// Bericht über alles, was dabei ausgefallen ist.
///
/// ## Warum das Ergebnis zwei Teile hat
///
/// Ein einzelner defekter Wert in den Live-Daten darf höchstens einen Fakt
/// kosten und niemals die ganze Liste. Ein reines `List<Fact>` könnte das zwar
/// leisten, aber dann verschwinden die Ausfälle lautlos, und niemand merkt, dass
/// von 600 Fakten nur 480 ankommen. Der Bericht macht das zählbar, ohne dass
/// dafür eine Ausgabe im Produktionscode nötig wäre.
///
/// ## Warum es kein `Result` ist
///
/// `docs/architecture/data-flow.md` §5 nennt `Future<Result<T, Failure>>` als
/// Zielform und lässt die Umsetzung offen. Ein gemeinsamer `Result`-Typ könnte
/// nur in `core/` liegen, und Gate 6 verbietet der Feature-Domäne jeden Import
/// aus `core/`. Ein `Result` pro Feature wäre die dritte Kopie derselben Idee.
/// Deshalb gilt hier die Aufteilung: **erwartete Datenmängel** stecken in
/// diesem Wert, **Infrastrukturfehler** werden als typisierte `FactFailure`
/// geworfen. Wenn das Projekt sich auf einen `Result`-Typ festlegt, ändert sich
/// die Signatur des Vertrags, aber weder Mapper noch Bericht.
///
/// Dieselbe Form dient dem Einzelabruf. Dann enthält [facts] höchstens einen
/// Eintrag, siehe [singleOrNull].
class FactBatch {
  /// Beide Listen werden kopiert und unveränderlich gemacht.
  FactBatch({required List<Fact> facts, required this.report})
    : facts = List<Fact>.unmodifiable(facts);

  /// Nichts gelesen, nichts zu melden.
  static final FactBatch empty = FactBatch(
    facts: const <Fact>[],
    report: FactImportReport.clean,
  );

  /// Die Fakten, die vollständig genug für die Domäne sind.
  final List<Fact> facts;

  /// Was dabei ausgefallen oder degradiert ist.
  final FactImportReport report;

  /// Ist nichts angekommen?
  bool get isEmpty => facts.isEmpty;

  /// Der einzige Fakt, oder `null` bei keinem oder mehreren.
  ///
  /// Für den Einzelabruf gedacht. Bewusst nicht `first`: „ich wollte einen und
  /// habe drei bekommen" ist ein anderer Fall als „ich nehme den ersten".
  Fact? get singleOrNull => facts.length == 1 ? facts.first : null;

  /// Verbindet zwei Ergebnisse. Gebraucht beim seitenweisen Laden.
  FactBatch merge(FactBatch other) => FactBatch(
    facts: <Fact>[...facts, ...other.facts],
    report: report.merge(other.report),
  );

  @override
  bool operator ==(Object other) =>
      other is FactBatch &&
      listsEqual(other.facts, facts) &&
      other.report == report;

  @override
  int get hashCode => Object.hash(hashList(facts), report);

  @override
  String toString() => 'FactBatch(${facts.length} Fakten, $report)';
}
