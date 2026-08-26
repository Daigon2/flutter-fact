import 'package:fact_app/features/facts/domain/structural_equality.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_defect.dart';

/// Was beim Einlesen einer Faktenmenge schiefgegangen ist, ohne dass die Menge
/// verloren war.
///
/// Der Bericht reist mit dem Ergebnis, weil das der einzige Weg ist, „ein
/// Fakt ist ausgefallen" **zählbar** zu machen, ohne dafür eine Ausgabe im
/// Produktionscode zu brauchen. Tests prüfen den Bericht, die Datenschicht gibt
/// eine Zusammenfassung an die Diagnose-Senke, und die Präsentation kann ihn
/// ignorieren.
class FactImportReport {
  /// [defects] wird kopiert und unveränderlich gemacht.
  FactImportReport(List<FactDefect> defects)
    : defects = List<FactDefect>.unmodifiable(defects);

  /// Nichts zu melden.
  static final FactImportReport clean = FactImportReport(const <FactDefect>[]);

  /// Alle Befunde in Lesereihenfolge der Antwort.
  final List<FactDefect> defects;

  /// Ist nichts zu melden?
  bool get isClean => defects.isEmpty;

  /// Wie viele Fakten es nicht in die Liste geschafft haben.
  ///
  /// Gezählt werden Datensätze, nicht Befunde: mehrere Pflichtfeld-Befunde am
  /// gleichen Datensatz sind ein Ausfall. Deshalb über [FactDefect.factReference]
  /// entdoppelt.
  int get discardedFactCount => defects
      .where((defect) => defect.discardsFact)
      .map((defect) => defect.factReference)
      .toSet()
      .length;

  /// Wie viele einzelne Felder degradiert sind, über alle Fakten.
  int get degradedFieldCount =>
      defects.where((defect) => !defect.discardsFact).length;

  /// Zähler je [FactDefectKind], nur die Arten, die vorkommen.
  Map<FactDefectKind, int> get countsByKind {
    final counts = <FactDefectKind, int>{};
    for (final defect in defects) {
      counts[defect.kind] = (counts[defect.kind] ?? 0) + 1;
    }
    return Map<FactDefectKind, int>.unmodifiable(counts);
  }

  /// Alle Befunde zu einem Feld, etwa `puzzle_fit`.
  List<FactDefect> forField(String field) => List<FactDefect>.unmodifiable(
    defects.where((defect) => defect.field == field),
  );

  /// Verbindet zwei Berichte. Gebraucht beim seitenweisen Laden.
  FactImportReport merge(FactImportReport other) =>
      FactImportReport(<FactDefect>[...defects, ...other.defects]);

  @override
  bool operator ==(Object other) =>
      other is FactImportReport && listsEqual(other.defects, defects);

  @override
  int get hashCode => hashList(defects);

  @override
  String toString() =>
      'FactImportReport(verworfen: $discardedFactCount, '
      'degradierte Felder: $degradedFieldCount)';
}
