/// Riverpod-Komposition der eingesammelten Fakten (ADR-005: Riverpod ist der
/// einzige DI-Mechanismus). Handgeschriebene Provider, weil
/// `riverpod_generator` mit diesem Abhängigkeitsstand nicht neben
/// `go_router_builder` auflösbar ist (ADR-003).
///
/// ## Warum in `application/` und nicht in `presentation/notifiers/`
///
/// Genau aus dem Grund, den `fact_providers.dart` daneben ausführlich
/// aufschreibt: der Verbraucher ist `features/discovery`, und Regel 8
/// verbietet jedem Feature den Import aus dem `presentation` eines anderen.
/// `features/facts/domain/` darf Riverpod nicht kennen (Regel 2), und Regel 10
/// nennt „a public domain/application contract" als den erlaubten Weg über die
/// Feature-Grenze. Bleibt `application/`.
///
/// Und der Verbraucherkreis wächst: der Reiseführer aus Schritt 45 und die
/// Trophäen aus Schritt 49 lesen dieselbe Liste. Ein Provider in
/// `discovery/presentation/notifiers/` wäre für beide unerreichbar.
library;

import 'package:fact_app/features/facts/domain/collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Speicher der eingesammelten Fakten.
///
/// Der Standard ist flüchtig. `bootstrap()` überschreibt ihn mit
/// `KeyValueCollectedFactsStore`, und ohne diesen Override sammelt die App,
/// sieht heil aus und hat nach dem Neustart nichts gesammelt. Genau deshalb
/// steht der Eintrag auch in `test/app/bootstrap_test.dart`.
final collectedFactsStoreProvider = Provider<CollectedFactsStore>(
  (ref) => InMemoryCollectedFactsStore(),
);

/// Die eingesammelten Fakten dieses Nutzers, in der Reihenfolge des
/// Einsammelns.
///
/// Die Reihenfolge trägt Bedeutung, siehe [CollectedFactsStore]. Wer nur
/// wissen will, ob ein einzelner Fakt dabei ist, nimmt
/// [isFactCollectedProvider] und baut nicht bei jedem fremden Sammelvorgang
/// neu.
final collectedFactsProvider =
    NotifierProvider<CollectedFactsNotifier, List<FactId>>(
      CollectedFactsNotifier.new,
    );

/// Ob [factId] eingesammelt ist.
///
/// **Ein `Provider.family` und keine Hilfsfunktion auf dem Zustand**, weil der
/// Unterschied ein Neuaufbau ist: `ref.watch(collectedFactsProvider)` weckt
/// jeden Leser, sobald **irgendein** Fakt dazukommt. Ein Ballon, der nur
/// wissen will, ob **er** gesammelt ist, hängt hier und bleibt sonst stehen.
/// Riverpod vergleicht das Ergebnis mit `!=`, und `false != false` weckt
/// niemanden.
///
/// Der Scan der Kartenüberlagerung nimmt trotzdem [collectedFactsProvider]:
/// er fragt bei jeder Ortung nach dem nächsten **noch nicht** gesammelten
/// Fakt und braucht dafür die ganze Liste.
final isFactCollectedProvider = Provider.family<bool, FactId>(
  (ref, FactId factId) => ref.watch(collectedFactsProvider).contains(factId),
);

/// Besitzer der eingesammelten Fakten.
class CollectedFactsNotifier extends Notifier<List<FactId>> {
  @override
  List<FactId> build() =>
      ref.watch(collectedFactsStoreProvider).readCollectedFacts();

  /// Nimmt [factId] in die Sammlung auf.
  ///
  /// Die Oberfläche folgt sofort, der Schreibvorgang läuft hinterher, wie in
  /// `AudioModeNotifier.enable`: ein fehlgeschlagenes Speichern soll den
  /// gerade gefundenen Fakt nicht wieder wegnehmen.
  ///
  /// **Der frühe Ausstieg steht hier und nicht nur im Speicher**, obwohl
  /// [CollectedFactsStore.collectFact] ohnehin idempotent ist. Ohne ihn
  /// bekäme jeder Leser bei einem zweiten Sammelvorgang eine neue
  /// Listeninstanz, und weil eine `List` keine Wertgleichheit hat, vergleicht
  /// Riverpods `defaultUpdateShouldNotify` sie mit `!=` und weckt alle. Ein
  /// Neuaufbau der ganzen Karte, weil nichts passiert ist.
  ///
  /// **Es gibt hier absichtlich kein Entfernen.** Sammeln ist in der Quelle
  /// einseitig (`Storage.collectFact` kennt kein Gegenstück, im Unterschied zu
  /// `Storage.toggleSaved` daneben), und ein Gegenstück im Client wäre die
  /// Bauform, die E-49 ausdrücklich verwirft: der Server ist die Wahrheit
  /// darüber, was gesammelt ist.
  Future<void> collect(FactId factId) async {
    if (state.contains(factId)) {
      return;
    }
    state = List<FactId>.unmodifiable(<FactId>[...state, factId]);
    await ref.read(collectedFactsStoreProvider).collectFact(factId);
  }
}
