import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/failures/fact_failure.dart';
import 'package:fact_app/features/facts/domain/repositories/fact_repository.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
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
}
