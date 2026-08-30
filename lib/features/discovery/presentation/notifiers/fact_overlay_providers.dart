/// Die Fakten des Kartenbildschirms, fertig als Überlagerung.
///
/// ## Warum ein [FutureProvider] und kein Notifier
///
/// Hier gibt es nichts zu **führen**: die Liste wird einmal geladen und
/// danach nur noch gelesen. Ein Notifier ist der richtige Typ, wenn ein
/// Zustand von außen verändert wird (`UserLocationNotifier` bekommt
/// fortlaufend Ortungen), und der falsche für eine einmalige Abfrage. Sobald
/// der Sammelzustand dazukommt, ändert sich das, und dann ist der Wechsel eine
/// Zeile hier und keine im Bildschirm.
///
/// ## Warum das Laden nicht im Bildschirm steht
///
/// Regel 17 lässt `presentation` nicht in ein `data`-Verzeichnis greifen, auch
/// nicht in das eigene. Der Weg führt über
/// `features/facts/application/fact_providers.dart`, der auf dem Vertrag
/// `FactRepository` typisiert ist; die Supabase-Fassung setzt
/// `lib/app/bootstrap.dart` per Override ein und dieses Feature erfährt nie,
/// dass es sie gibt.
///
/// ## Mehrstädtigkeit
///
/// Geladen wird **ohne Stadtfilter**, siehe [allFactsProvider]. Das ist kein
/// Versäumnis: die Stadtauswahl gehört `features/city`, die es noch nicht
/// gibt, und eine hier fest verdrahtete Stadt wäre genau die Annahme, die die
/// globale Invariante verbietet. Die Quelle lädt aus demselben Grund alle
/// veröffentlichten Fakten und filtert erst danach
/// (`02_Frontend/app/api.jsx:119`, siehe auch `FactQuery`).
library;

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Fakten dieser Karte als Überlagerung.
///
/// `FactRepository` wirft bei Infrastrukturproblemen, und `AsyncValue.error`
/// ist genau die Form, in der ein Bildschirm daraus etwas Sichtbares machen
/// kann. **Eine leere Liste wäre hier die schlechteste Antwort**, weil sie von
/// einer Stadt ohne Fakten nicht zu unterscheiden ist.
///
/// ## Ein Fehlschlag bleibt nicht einfach stehen, Riverpod wiederholt ihn
///
/// Hier stand früher „ein Fehlschlag bleibt ein Fehlschlag". Das ist falsch:
/// `ProviderContainer.defaultRetry` wiederholt einen gescheiterten Provider
/// **zehnmal** mit wachsender Pause, 200 ms verdoppelnd bis zur Deckelung bei
/// 6400 ms, in Summe also rund 38 Sekunden
/// (`riverpod-3.4.2/lib/src/core/provider_container.dart:982-996`).
/// Ausgenommen sind allein `Error` und `ProviderException` (`:990`);
/// `FactFailure implements Exception`
/// (`features/facts/domain/failures/fact_failure.dart:22`) und wird deshalb
/// wiederholt.
///
/// Das ist für diesen Provider die richtige Voreinstellung, ein Netzfehler
/// beim Start ist oft nach Sekunden weg. Wissen muss man es trotzdem an zwei
/// Stellen: der Zustand steht rund eine halbe Minute auf `AsyncError`, bevor er
/// endgültig ist, und in einem Test überlebt der erste dieser Zeitgeber den
/// Widget-Baum. Deshalb überschreibt `map_page_test.dart` diesen Provider,
/// statt das Repository werfen zu lassen.
final FutureProvider<MapOverlay> factOverlayProvider =
    FutureProvider<MapOverlay>((ref) async {
      // Vor dem `await` gelesen: nach einer Unterbrechung ist ein `ref.watch`
      // nicht mehr das, was es vorher war, und die Abhängigkeit soll an diesem
      // Provider hängen und nicht an der Reihenfolge der Mikrotasks.
      //
      // **Seit Schritt 35 wird nicht mehr selbst geladen.** Der zweite
      // Verbraucher der vollständigen Faktenliste ist der Startpunkt-Picker
      // in `challenges`, und Regel 8 lässt ihn nicht an diesen Provider
      // heran. Das Laden ist deshalb nach
      // `features/facts/application/fact_providers.dart` gewandert; hier
      // bleibt allein die Umformung zur Überlagerung. Sichtbar ändert das
      // nichts: dieselbe Abfrage, dasselbe Ergebnis, ein Abruf statt zweien.
      final Future<List<Fact>> facts = ref.watch(allFactsProvider.future);
      final DiagnosticSink diagnostics = ref.watch(diagnosticSinkProvider);
      return factOverlayOf(await facts, diagnostics: diagnostics);
    });
