/// Vertrag für die Merkung "das Tutorial wurde auf diesem Gerät gezeigt".
///
/// Entspricht `fact_tour_shown` im `localStorage` der PWA: `storage.jsx:100`
/// liest es, `storage.jsx:101` schreibt es, `app.jsx:73` macht daraus den
/// Startwert `tourActive = !getTourShown()`.
///
/// ## Zwei Flags, zwei Bedeutungen, keine gemeinsame Bedingung
///
/// `fact_has_launched` (siehe `features/identity/domain/first_launch_store.dart`)
/// entscheidet, **welcher Bildschirm** erscheint, und wird in der Quelle
/// zusammen mit dem Anmeldezustand gelesen (`app.jsx:69`). Dieses Flag hier
/// entscheidet über eine **Ebene darüber** und wird ohne jede weitere Bedingung
/// gelesen: `app.jsx:73` fragt weder `Storage.getUser()` noch
/// `fact_has_launched` ab.
///
/// Die praktische Folge steht so in keiner Vorlage und ist trotzdem belegt: ein
/// angemeldeter Rückkehrer, der die Tour nie gesehen hat, sieht **keinen**
/// Startbildschirm und **trotzdem** das Tutorial. Deshalb gehört dieses Flag
/// nicht in `lib/app/routing/route_guards.dart`: die Weiche entscheidet über
/// Routen, das Tutorial liegt über einer Route.
///
/// [hasSeenTour] ist absichtlich synchron, aus demselben Grund wie
/// `FirstLaunchStore.hasLaunched` und `LanguagePreferenceStore.readLanguage`:
/// die Entscheidung "Overlay bauen oder nicht" fällt beim ersten Frame. Ein
/// `Future` hier würde die App-Shell in einen Ladezustand zwingen, obwohl der
/// Wert längst feststeht. Seit dem 31.08.2026 ist die Persistenz gebaut:
/// `bootstrap()` lädt vor und überschreibt `tourStoreProvider` mit
/// `KeyValueTourStore`.
abstract interface class TourStore {
  /// Ob das Tutorial schon einmal gezeigt und beendet wurde.
  bool hasSeenTour();

  /// Merkt dauerhaft, dass das Tutorial erledigt ist.
  ///
  /// Idempotent: ein zweiter Aufruf ist erlaubt und ändert nichts.
  ///
  /// Es gibt bewusst **kein** Gegenstück zum Zurücksetzen. `setTourShown(false)`
  /// existiert in der Quelle als Parameter (`storage.jsx:101`), wird aber
  /// nirgends mit `false` aufgerufen. Ein Weg, der nur in der Schnittstelle
  /// existiert, ist ein Weg, den niemand testet.
  Future<void> markTourSeen();
}

/// Flüchtiger Speicher, Vorgabe für Tests.
///
/// Die Merkung überlebt den Neustart nicht. **Bis zum 31.08.2026 hieß das für
/// die laufende App: das Tutorial erschien bei jedem Start erneut.** Seither
/// überschreibt `bootstrap()` diesen Provider mit `KeyValueTourStore`, und der
/// flüchtige bleibt die Vorgabe für Tests.
class InMemoryTourStore implements TourStore {
  /// [hasSeenTour] setzt eine bereits gezeigte Tour, etwa in einem Test.
  InMemoryTourStore({bool hasSeenTour = false}) : _hasSeenTour = hasSeenTour;

  bool _hasSeenTour;

  @override
  bool hasSeenTour() => _hasSeenTour;

  @override
  Future<void> markTourSeen() async {
    _hasSeenTour = true;
  }
}
