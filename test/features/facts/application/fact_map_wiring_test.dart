import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_batch.dart';
import 'package:fact_app/features/facts/domain/repositories/fact_repository.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_import_report.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_query.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Durchreichung von den Fakten bis auf die Karte, wirklich ausgeführt.
///
/// ## Warum es diese Datei gibt
///
/// Beide Rümpfe waren bis Schritt 35 in jeder Testdatei überschrieben:
/// `allFactsProvider` in `challenges_page_test.dart` und `factOverlayProvider`
/// in `fact_proximity_test.dart` sowie `map_page_test.dart`. Setzt man in
/// `allFactsProvider` den Stadtfilter auf „nur Berlin" oder ersetzt man in
/// `factOverlayProvider` die geladene Liste durch eine leere, schlägt keiner
/// dieser Tests an, weil sie den Provider gar nicht laufen lassen. Diese Datei
/// überschreibt **nur** `factRepositoryProvider`, den einen Rand des Systems,
/// und lässt beide echten Rümpfe rechnen.
void main() {
  Fact factAt(
    FactId id, {
    required double latitude,
    required double longitude,
  }) => Fact(
    id: id,
    content: FactText(title: 'Fakt ${id.value}'),
    coordinates: FactCoordinates(latitude: latitude, longitude: longitude),
  );

  test('allFactsProvider fragt das Repository über alle Fakten und reicht das '
      'Ergebnis unverändert durch', () async {
    final _RecordingFactRepository repository = _RecordingFactRepository(<Fact>[
      factAt(const FactId(1), latitude: 52.52, longitude: 13.405),
      factAt(const FactId(2), latitude: 48.1374, longitude: 11.5755),
    ]);
    final ProviderContainer container = ProviderContainer(
      overrides: [factRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final List<Fact> facts = await container.read(allFactsProvider.future);

    // Der teure Mutant: die Abfrage auf einen Stadtfilter umzustellen. Ohne
    // diese Zusicherung fiele das niemandem auf, weil kein Test diesen
    // Rumpf sonst ausführt.
    expect(repository.lastQuery, FactQuery.all);
    expect(facts.map((Fact fact) => fact.id).toList(), <FactId>[
      const FactId(1),
      const FactId(2),
    ]);
  });

  test(
    'factOverlayProvider legt die geladenen Fakten wirklich in die '
    'Überlagerung, ohne dass ein Test allFactsProvider überschreibt',
    () async {
      final _RecordingFactRepository repository =
          _RecordingFactRepository(<Fact>[
            factAt(const FactId(11), latitude: 52.52, longitude: 13.405),
            factAt(const FactId(12), latitude: 48.1374, longitude: 11.5755),
          ]);
      final ProviderContainer container = ProviderContainer(
        overrides: [factRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final MapOverlay overlay = await container.read(
        factOverlayProvider.future,
      );

      // Der teure Mutant: die Liste hinter `factOverlayProvider` auf leer zu
      // setzen. 1792 Tests blieben grün, weil jeder von ihnen diesen Provider
      // überschrieben hatte, bevor sein Rumpf je lief.
      expect(
        overlay.points.map((MapOverlayPoint point) => point.id).toSet(),
        <String>{'11', '12'},
      );
    },
  );
}

/// Ein Repository, das sich die zuletzt gestellte Abfrage merkt.
class _RecordingFactRepository implements FactRepository {
  _RecordingFactRepository(this._facts);

  final List<Fact> _facts;

  /// Die Abfrage des letzten Aufrufs von [fetchFacts].
  FactQuery? lastQuery;

  @override
  Future<FactBatch> fetchFacts({FactQuery query = FactQuery.all}) async {
    lastQuery = query;
    return FactBatch(facts: _facts, report: FactImportReport.clean);
  }

  @override
  Future<FactBatch> fetchFactById(FactId id) async =>
      FactBatch(facts: const <Fact>[], report: FactImportReport.clean);

  @override
  Stream<FactBatch> watchFacts({FactQuery query = FactQuery.all}) =>
      throw UnsupportedError('nicht gebraucht');
}
