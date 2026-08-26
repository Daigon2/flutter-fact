import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/features/facts/data/datasources/remote/supabase_fact_remote_data_source.dart';
import 'package:fact_app/features/facts/data/repositories/supabase_fact_repository.dart';
import 'package:fact_app/features/facts/domain/repositories/fact_repository.dart';
import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:fact_app/services/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'supabase_fact_repository_test.dart'
    show FakeFactDataSource, RecordingDiagnosticSink, rowsFor;

/// Die Riverpod-Komposition der Datenschicht.
///
/// Regel 7 und ADR-005: höhere Schichten bekommen das Repository über einen
/// Provider und bauen es nicht selbst. Diese Tests belegen zwei Dinge: der
/// Provider liefert den Domänenvertrag und nicht die Implementierung, und jede
/// Abhängigkeit ist für einen Test austauschbar, ohne dass Supabase gestartet
/// werden muss.
void main() {
  group('factRepositoryProvider', () {
    test('liefert den Domänenvertrag', () {
      final container = ProviderContainer(
        overrides: [
          factRemoteDataSourceProvider.overrideWithValue(
            FakeFactDataSource(rowsFor(<int>[1])),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(factRepositoryProvider);

      expect(repository, isA<FactRepository>());
      expect(repository, isA<SupabaseFactRepository>());
    });

    test('arbeitet mit einer ausgetauschten Datenquelle', () async {
      final container = ProviderContainer(
        overrides: [
          factRemoteDataSourceProvider.overrideWithValue(
            FakeFactDataSource(rowsFor(<int>[1, 2, 3])),
          ),
        ],
      );
      addTearDown(container.dispose);

      final batch = await container.read(factRepositoryProvider).fetchFacts();

      expect(batch.facts, hasLength(3));
    });

    test('nimmt die Diagnose-Senke aus core', () async {
      final rows = rowsFor(<int>[1]);
      rows[0]['hero'] = 'kaputt';
      final sink = RecordingDiagnosticSink();
      final container = ProviderContainer(
        overrides: [
          factRemoteDataSourceProvider.overrideWithValue(
            FakeFactDataSource(rows),
          ),
          diagnosticSinkProvider.overrideWithValue(sink),
        ],
      );
      addTearDown(container.dispose);

      await container.read(factRepositoryProvider).fetchFacts();

      expect(sink.events, hasLength(1));
    });

    test('die Standardsenke ist still', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(diagnosticSinkProvider),
        isA<SilentDiagnosticSink>(),
      );
    });
  });

  group('supabaseClientProvider', () {
    test('scheitert verständlich, wenn die Konfiguration fehlt', () {
      // Ohne --dart-define ist die Konfiguration unbrauchbar. Der Provider soll
      // daran scheitern und nicht erst später an einem Netzwerkfehler, dessen
      // Ursache niemand sieht.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod 3 verpackt einen Fehler aus dem Provider-Aufbau in eine
      // ProviderException, die nur über den Nebeneingang
      // `package:flutter_riverpod/misc.dart` sichtbar ist. Geprüft wird deshalb
      // die Meldung und nicht der Hüllentyp: das bleibt richtig, wenn Riverpod
      // intern umbenennt, und es prüft genau das, was einem Entwickler beim
      // Start hilft.
      expect(
        () => container.read(supabaseClientProvider),
        throwsA(
          predicate<Object>((error) {
            final message = error.toString();
            return message.contains('--dart-define') &&
                message.contains(SupabaseConfig.urlVariable) &&
                message.contains(SupabaseConfig.publishableKeyVariable);
          }, 'nennt beide --dart-define-Werte'),
        ),
      );
    });

    test('die Konfiguration ist für Tests überschreibbar', () {
      final container = ProviderContainer(
        overrides: [
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(
              url: 'https://beispiel.supabase.co',
              publishableKey: 'abc',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(supabaseConfigProvider).isUsable, isTrue);
      // Der Client selbst wird hier nicht gelesen: er verlangt einen
      // gestarteten Supabase, und dieser Test soll kein Netz brauchen.
    });
  });
}
