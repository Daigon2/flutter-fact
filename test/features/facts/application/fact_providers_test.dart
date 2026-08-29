import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_batch.dart';
import 'package:fact_app/features/facts/domain/failures/fact_failure.dart';
import 'package:fact_app/features/facts/domain/repositories/fact_repository.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_import_report.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_query.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Zugang zu Fakten, wie höhere Schichten ihn sehen.
///
/// Dieser Provider ist die Behebung eines Fundes, den `dependency-rules.md`
/// seit E-32 führt: `factRepositoryProvider` lag neben der Supabase-Fassung in
/// `data/` und war für `presentation` unerreichbar (Regel 17), obwohl sein
/// Kommentar das Gegenteil behauptete. Er heißt jetzt
/// `supabaseFactRepositoryProvider`, und der hier ist der erreichbare.
void main() {
  test('ohne Override antwortet der untätige Standard', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      identical(
        container.read(factRepositoryProvider),
        unavailableFactRepository,
      ),
      isTrue,
    );
  });

  test('der Standard wirft, statt eine leere Liste zu liefern', () async {
    // **Der Unterschied zu `unavailableAuthRepository` ist Absicht.** Eine
    // leere Faktenliste ist eine plausible Antwort: eine Stadt ohne Fakten
    // sieht genauso aus. Fehlte der Override in `bootstrap.dart`, zeigte die
    // App eine leere Karte, und niemand könnte sie von einer richtigen
    // unterscheiden.
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final FactRepository repository = container.read(factRepositoryProvider);

    await expectLater(
      repository.fetchFacts(),
      throwsA(
        isA<FactBackendUnreachable>().having(
          (FactFailure failure) => failure.code,
          'code',
          'fact_repository_not_configured',
        ),
      ),
    );
  });

  test('auch der Einzelabruf und der Strom scheitern sichtbar', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final FactRepository repository = container.read(factRepositoryProvider);

    await expectLater(
      repository.fetchFactById(const FactId(1)),
      throwsA(isA<FactBackendUnreachable>()),
    );
    expect(repository.watchFacts, throwsA(isA<FactBackendUnreachable>()));
  });

  group('factByIdProvider', () {
    Fact factWith(FactId id) => Fact(
      id: id,
      content: const FactText(title: 'Die Glyptothek'),
    );

    test('liefert den Fakt zur angefragten Kennung', () async {
      final _RecordingFactRepository repository = _RecordingFactRepository(
        <FactId, Fact>{const FactId(7): factWith(const FactId(7))},
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [factRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final Fact? fact = await container.read(
        factByIdProvider(const FactId(7)).future,
      );

      expect(fact, factWith(const FactId(7)));
      // Die Kennung wird durchgereicht und nicht verworfen: ein Provider, der
      // immer den ersten Fakt liefert, käme sonst durch.
      expect(repository.requested, <FactId>[const FactId(7)]);
    });

    test('zwei Kennungen sind zwei Zustände, nicht einer', () async {
      final _RecordingFactRepository repository =
          _RecordingFactRepository(<FactId, Fact>{
            const FactId(1): factWith(const FactId(1)),
            const FactId(2): factWith(const FactId(2)),
          });
      final ProviderContainer container = ProviderContainer(
        overrides: [factRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(
        (await container.read(factByIdProvider(const FactId(1)).future))!.id,
        const FactId(1),
      );
      expect(
        (await container.read(factByIdProvider(const FactId(2)).future))!.id,
        const FactId(2),
      );
      expect(repository.requested, hasLength(2));
    });

    test('ein leeres Ergebnis ist null und kein Fehlschlag', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          factRepositoryProvider.overrideWithValue(
            _RecordingFactRepository(const <FactId, Fact>{}),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(factByIdProvider(const FactId(9)).future),
        isNull,
      );
    });
  });
}

/// Ein Repository, das sich merkt, wonach gefragt wurde.
class _RecordingFactRepository implements FactRepository {
  _RecordingFactRepository(this._facts);

  final Map<FactId, Fact> _facts;

  /// Jede Kennung, die [fetchFactById] gesehen hat, in Aufrufreihenfolge.
  final List<FactId> requested = <FactId>[];

  @override
  Future<FactBatch> fetchFactById(FactId id) async {
    requested.add(id);
    final Fact? fact = _facts[id];
    return FactBatch(facts: <Fact>[?fact], report: FactImportReport.clean);
  }

  @override
  Future<FactBatch> fetchFacts({FactQuery query = FactQuery.all}) async =>
      FactBatch(facts: _facts.values.toList(), report: FactImportReport.clean);

  @override
  Stream<FactBatch> watchFacts({FactQuery query = FactQuery.all}) =>
      throw UnsupportedError('nicht gebraucht');
}
