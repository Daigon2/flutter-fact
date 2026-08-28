import 'package:fact_app/app/onboarding/tour_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod-Komposition des Tutorials (ADR-005: Riverpod ist der einzige
/// DI-Mechanismus). Handgeschriebene Provider, weil `riverpod_generator` mit
/// diesem Abhängigkeitsstand nicht neben `go_router_builder` auflösbar ist
/// (ADR-003).
///
/// ## Warum das hier liegt und nicht bei einem Feature
///
/// E-26 in `REBUILD_STATUS.md`: das Tutorial ist App-Komposition und kein
/// vierter Feature-Ordner. Es zeigt auf Bedienelemente aus `app/shell/` und ab
/// Phase 2 zusätzlich auf fünf Anker aus `features/discovery/presentation/`.
/// Ein Feature, das quer über zwei fremde Oberflächen zeigt, wäre genau die
/// Cross-Feature-Abhängigkeit, die `dependency-rules.md` verbietet.

/// Speicher der Tutorial-Merkung.
///
/// Der Standard ist flüchtig, siehe [InMemoryTourStore]. Sobald echte
/// Persistenz kommt, wird dieser Provider aus `bootstrap()` überschrieben,
/// genau wie es `authRepositoryProvider` heute schon vormacht.
final tourStoreProvider = Provider<TourStore>((ref) => InMemoryTourStore());

/// Ob das Tutorial schon gezeigt wurde.
///
/// `true` heißt: `OnboardingHost` baut kein Overlay. `false` heißt: das
/// Tutorial läuft. Der Wert ist bewusst so herum benannt wie das Flag der
/// Quelle (`fact_tour_shown`), damit niemand beim Vergleich mit `app.jsx:73`
/// die Negation übersieht.
final tourShownProvider = NotifierProvider<TourShownNotifier, bool>(
  TourShownNotifier.new,
);

/// Besitzer der Tutorial-Merkung.
///
/// Der Zustand ist ein einzelner unveränderlicher Wert, kein `ChangeNotifier`
/// (ADR-003).
class TourShownNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(tourStoreProvider).hasSeenTour();

  /// Merkt das erledigte Tutorial und speichert es danach.
  ///
  /// Die Oberfläche folgt sofort, der Schreibvorgang läuft hinterher. Ein
  /// fehlgeschlagenes Speichern soll das Overlay nicht wieder aufklappen
  /// lassen, während der Nutzer schon die Karte bedient.
  ///
  /// Idempotent: ist die Merkung schon gesetzt, passiert nichts. Ohne diese
  /// Abkürzung würde ein zweiter Aufruf einen überflüssigen Provider-Zyklus
  /// auslösen. Beide Ausgänge des Tutorials, "durchgetippt" und
  /// "übersprungen", laufen hier zusammen; die Quelle ruft an beiden Stellen
  /// dasselbe `Storage.setTourShown(true)` (`screen-tour.jsx:265` und `:274`).
  Future<void> markSeen() async {
    if (state) {
      return;
    }
    state = true;
    await ref.read(tourStoreProvider).markTourSeen();
  }
}
