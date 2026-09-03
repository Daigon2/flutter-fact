/// Der Zugang zum Bücherregal des Reiseführers.
///
/// Handgeschriebene Provider, wie überall in diesem Projekt (Riverpod ist der
/// einzige DI-Mechanismus, ohne Codegenerierung).
library;

import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Bände des Regals, fertig gezählt.
///
/// ## Warum ein [FutureProvider]
///
/// Dieselbe Begründung wie bei `factOverlayProvider`: die Fakten werden
/// einmal geladen und danach nur gelesen, geführt wird hier nichts. Der
/// Sammelzustand kommt aus einem Notifier, und der weckt diesen Provider von
/// selbst.
///
/// ## `watch` auf den Sammelzustand, nicht `read`
///
/// Ein Sammelvorgang muss den Zähler auf dem Buchrücken hochsetzen. Der Preis
/// ist ein Neuaufbau der Liste je gesammeltem Fakt, also eine Schleife über
/// alle Fakten; bei rund tausend Datensätzen ist das eine Rechnung im
/// Mikrosekundenbereich und keine Abfrage.
///
/// **Kein Stadtfilter.** Das Regal ist der Ort, an dem die Mehrstädtigkeit
/// sichtbar wird: jede Stadt mit Fakten bekommt einen Band. Ein Filter auf die
/// aktive Stadt wäre hier genau falsch.
final FutureProvider<List<LibraryVolume>> libraryShelfProvider =
    FutureProvider<List<LibraryVolume>>((ref) async {
      // Vor dem `await` gelesen, damit die Abhängigkeit an diesem Provider
      // hängt und nicht an der Reihenfolge der Mikrotasks.
      final Future<List<Fact>> facts = ref.watch(allFactsProvider.future);
      final Set<int> collected = ref
          .watch(collectedFactsProvider)
          .map((FactId id) => id.value)
          .toSet();
      return libraryShelfOf(facts: await facts, collected: collected);
    });

/// Wie viele Fakten insgesamt gesammelt sind.
///
/// ## Warum diese Zahl einen eigenen Provider bekommt
///
/// Weil die Quelle sie **falsch** ausrechnet, und zwar an der Stelle, an der
/// sie am größten auf dem Bildschirm steht. `WalletScreen`
/// (`02_Frontend/app/screen-wallet.jsx:1811-1816`) baut die Sammelmenge so:
///
/// ```js
/// (collectedFacts || []).forEach(id => { s.add(id); s.add(String(id)); });
/// ```
///
/// Der Grund ist echt: die Kennungen sind gemischt, Supabase liefert Zahlen,
/// selbst angelegte Fakten tragen `'local-…'`. Beide Formen in die Menge zu
/// legen macht die Suche robust. Zwei Zeilen später steht aber
/// `const totalCollected = collectedSet.size` (`:1864`), und für eine
/// Zahlkennung enthält die Menge **zwei** Einträge, `42` und `'42'`. Die
/// Schlagzeile „N Geschichten aus deinen Städten" zeigt damit das **Doppelte**
/// für jeden aus der Datenbank gesammelten Fakt.
///
/// Nachgesehen und nicht angenommen: dieselbe App rechnet an anderer Stelle
/// richtig, `app.jsx:706` nimmt `collectedFacts.length` für die
/// Erfahrungspunkte. Zwei Zahlen für dieselbe Sache, eine davon doppelt.
/// Registriert als E-74, hier nicht nachgebaut.
///
/// Uns kann das nicht passieren: `FactId` ist ein Wertobjekt mit
/// Wertgleichheit, und die Liste kennt jeden Fakt genau einmal
/// (`CollectedFactsNotifier.collect` prüft auf `contains`).
final Provider<int> collectedFactCountProvider = Provider<int>(
  (ref) => ref.watch(collectedFactsProvider).length,
);
