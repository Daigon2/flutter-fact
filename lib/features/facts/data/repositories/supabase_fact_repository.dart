import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/features/facts/data/datasources/remote/fact_remote_data_source.dart';
import 'package:fact_app/features/facts/data/datasources/remote/supabase_fact_remote_data_source.dart';
import 'package:fact_app/features/facts/data/mappers/fact_mapper.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_batch.dart';
import 'package:fact_app/features/facts/domain/repositories/fact_repository.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_defect.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_import_report.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Liest Fakten über Supabase und macht Domänenobjekte daraus.
///
/// Der Name trägt die Technik und nicht `Impl`, wie
/// `docs/engineering/naming-and-files.md` es verlangt.
///
/// Drei Aufgaben, und nur diese drei:
///
/// 1. seitenweise lesen, bis alles da ist;
/// 2. den Mapper anwenden und die Teilergebnisse zusammenlegen;
/// 3. den Stadtfilter anwenden und den Bericht melden.
class SupabaseFactRepository implements FactRepository {
  /// [dataSource] liest, [mapper] übersetzt, [diagnostics] nimmt den Bericht.
  SupabaseFactRepository({
    required this._dataSource,
    this._mapper = const FactMapper(),
    this._diagnostics = const SilentDiagnosticSink(),
  });

  /// Zeilen pro Anfrage.
  ///
  /// PostgREST liefert ohne `Range` höchstens 1000 Zeilen, und München hat rund
  /// 600 Fakten. Ohne Seitenbildung wäre die Grenze also schon in Sicht und
  /// würde ohne Fehlermeldung zuschlagen: die Liste wäre einfach kürzer. Die
  /// PWA nimmt aus demselben Grund dieselbe Seitengröße
  /// (`02_Frontend/app/api.jsx:120`).
  static const int pageSize = 1000;

  /// Notbremse gegen eine Endlosschleife.
  ///
  /// Sollte das Backend je eine volle Seite liefern, ohne dass der Offset
  /// wirkt, bricht der Lauf nach dieser Zahl von Seiten ab und meldet es,
  /// statt Speicher zu füllen, bis die App stirbt.
  static const int maxPages = 50;

  /// Name des Ereignisses, unter dem Datenmängel gemeldet werden.
  static const String defectEventName = 'facts.mapping_defects';

  final FactRemoteDataSource _dataSource;
  final FactMapper _mapper;
  final DiagnosticSink _diagnostics;

  @override
  Future<FactBatch> fetchFacts({FactQuery query = FactQuery.all}) async {
    final facts = <Fact>[];
    final defects = <FactDefect>[];

    for (var page = 0; page < maxPages; page++) {
      final raw = await _dataSource.fetchPublishedFactPage(
        offset: page * pageSize,
        pageSize: pageSize,
      );
      final result = _mapper.mapRecords(raw);
      facts.addAll(result.facts);
      defects.addAll(result.defects);

      // Weniger Zeilen als angefragt heißt: das war die letzte Seite. Der Fall
      // "gar keine Liste" liefert -1 und beendet die Schleife ebenfalls, denn
      // eine weitere Seite anzufragen hätte dann keinen Sinn.
      if (result.recordCount < pageSize) {
        return _finish(facts: facts, defects: defects, query: query);
      }
    }

    defects.add(
      const FactDefect(
        kind: FactDefectKind.unexpectedMappingError,
        field: FactDefect.wholeRecord,
        factReference: FactDefect.unknownReference,
        encounteredType: 'Seitengrenze erreicht',
      ),
    );
    return _finish(facts: facts, defects: defects, query: query);
  }

  @override
  Future<FactBatch> fetchFactById(FactId id) async {
    final raw = await _dataSource.fetchFactById(id.value);
    final result = _mapper.mapRecords(raw);
    return _finish(
      facts: result.facts,
      defects: result.defects,
      query: FactQuery.all,
    );
  }

  @override
  Stream<FactBatch> watchFacts({FactQuery query = FactQuery.all}) {
    throw UnsupportedError(
      'Live-Aktualisierung ist noch nicht umgesetzt. Ob Supabase-Realtime '
      'überhaupt kommt, ist die offene Entscheidung E-09 aus '
      'REBUILD_STATUS.md, Stufe 3, fällig in Phase 5. Bis dahin fetchFacts '
      'verwenden. Ein stiller Einmal-Strom stünde hier nicht: er sähe live '
      'aus und wäre es nicht.',
    );
  }

  /// Filtert, baut den Bericht und meldet ihn.
  FactBatch _finish({
    required List<Fact> facts,
    required List<FactDefect> defects,
    required FactQuery query,
  }) {
    final report = FactImportReport(defects);
    _reportDefects(report);
    return FactBatch(facts: _applyQuery(facts, query), report: report);
  }

  /// Wendet den Stadtfilter an.
  ///
  /// Im Client und nicht in der Abfrage, weil `facts.city` einen Anzeigenamen
  /// trägt und der Client mit Slugs rechnet. Die Brücke ist die SQL-Funktion
  /// `_slugify`, und die steht über PostgREST nicht als Filter zur Verfügung.
  /// `FactCity.slug` baut sie nach. Ein Fakt ohne Stadt fällt bei gesetztem
  /// Filter heraus, weil sich nicht entscheiden lässt, wohin er gehört, und
  /// weil die Notlösung des Backends (Stadt aus dem `nr`-Präfix erraten)
  /// bewusst nicht verdoppelt wird. Siehe E-11.
  static List<Fact> _applyQuery(List<Fact> facts, FactQuery query) {
    final citySlug = query.citySlug;
    if (citySlug == null) {
      return facts;
    }
    return facts
        .where((fact) => fact.city?.matchesSlug(citySlug) ?? false)
        .toList();
  }

  /// Schiebt eine Zusammenfassung in die Diagnose-Senke.
  ///
  /// Nur Zähler, Arten und Feldnamen. Kein Titel, kein Text, keine Koordinate,
  /// keine Rohantwort: `cross-cutting-concerns.md` verbietet ganze
  /// Backend-Antworten im Log, und `security.md` §6 genaue Koordinaten. Die
  /// Fakt-Bezüge (`nr`) bleiben draußen, weil bei einem systematischen
  /// Datenfehler sonst 600 Nummern in einer Zeile stehen; wer sie braucht,
  /// liest `FactBatch.report`, der vollständig ist.
  void _reportDefects(FactImportReport report) {
    if (report.isClean) {
      return;
    }
    final attributes = <String, String>{
      'discarded': report.discardedFactCount.toString(),
      'degraded': report.degradedFieldCount.toString(),
    };
    for (final entry in report.countsByKind.entries) {
      attributes[entry.key.name] = entry.value.toString();
    }
    final fields = report.defects.map((defect) => defect.field).toSet().toList()
      ..sort();
    attributes['fields'] = fields.join(',');
    _diagnostics.report(DiagnosticEvent(defectEventName, attributes));
  }
}

/// Baut die Supabase-Fassung. **Nur `lib/app/` liest diesen Provider.**
///
/// ## Der Name hat sich am 29.08.2026 geändert, und der Grund steht hier
///
/// Er hieß `factRepositoryProvider`, und sein Kommentar behauptete, „Widgets
/// und Notifier lesen diesen Provider". **Das konnten sie nie:** Regel 17
/// verbietet `presentation` jeden Import aus `data`, auch aus dem eigenen
/// Feature, und Regel 9 verbietet ihn jedem anderen Feature. Der Satz war
/// keine Kleinigkeit, sondern eine Falle für den nächsten Aufrufer;
/// `dependency-rules.md` führt ihn seit E-32 als offenen Punkt und weist die
/// Behebung dem Schritt zu, der `facts` an die Karte hängt.
///
/// Der Name sagt jetzt, was der Provider ist: die Baustelle der Supabase-
/// Fassung. Wer ein `FactRepository` **benutzen** will, liest
/// `features/facts/application/fact_providers.dart`, der auf dem Vertrag
/// typisiert ist und die Implementierung nicht kennt.
///
/// Regel 7 und ADR-005 gelten unverändert: niemand instanziiert ein Repository
/// selbst, es entsteht genau hier.
final supabaseFactRepositoryProvider = Provider<FactRepository>(
  (ref) => SupabaseFactRepository(
    dataSource: ref.watch(factRemoteDataSourceProvider),
    diagnostics: ref.watch(diagnosticSinkProvider),
  ),
);
