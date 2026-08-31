/// Vertrag für die Merkung "diese App wurde auf diesem Gerät schon gestartet".
///
/// Entspricht `fact_has_launched` im `localStorage` der PWA (`app.jsx:68-70`
/// liest es, `app.jsx:477` schreibt es). Das Flag entscheidet ausschließlich,
/// ob der Startbildschirm erscheint. Es ist **keine** Sitzung und **keine**
/// Berechtigung: Autorisierung liegt beim Server, hier geht es um Bequemlichkeit
/// beim Start.
///
/// ## Die Bedingung der Quelle hat zwei Hälften, hier ist eine umgesetzt
///
/// `app.jsx:69` lautet vollständig:
///
/// ```js
/// !localStorage.getItem('fact_has_launched') && !Storage.getUser() ? 'onboarding' : 'map'
/// ```
///
/// Der zweite Teil fehlt hier, und zwar notwendig: es gibt noch keinen
/// Sitzungszustand. Praktische Folge des Unterschieds: ein angemeldeter Nutzer,
/// dessen Flag fehlt, sieht in der PWA **keinen** Startbildschirm, hier schon.
/// Genau dieser Fall kann eintreten, weil `app.jsx:525-527` das Flag als
/// Nachbesserung im Anmeldeweg setzt, statt es dort von Anfang an zu führen.
///
/// Schritt 9 bringt den Sitzungszustand. Dann gehört die zweite Hälfte in die
/// Weiche in `lib/app/routing/route_guards.dart`, nicht in diesen Vertrag: ob
/// jemand angemeldet ist, ist keine Eigenschaft dieses Speichers.
///
/// [hasLaunched] ist absichtlich synchron, aus demselben Grund wie
/// `LanguagePreferenceStore.readLanguage`: die Weiche im Router muss beim ersten
/// Redirect antworten können. Ein `Future` hier würde jede Route in einen
/// Ladezustand zwingen, obwohl der Wert beim ersten Frame längst feststeht.
/// Seit dem 31.08.2026 ist die Persistenz gebaut: `bootstrap()` lädt vor und
/// überschreibt `firstLaunchStoreProvider` mit `KeyValueFirstLaunchStore`.
abstract interface class FirstLaunchStore {
  /// Ob der Startbildschirm schon durchlaufen wurde.
  bool hasLaunched();

  /// Merkt dauerhaft, dass der Startbildschirm durchlaufen wurde.
  ///
  /// Idempotent: ein zweiter Aufruf ist erlaubt und ändert nichts.
  Future<void> markLaunched();
}

/// Flüchtiger Speicher, Vorgabe für Tests.
///
/// Die Merkung überlebt den Neustart nicht. **Bis zum 31.08.2026 hieß das für
/// die laufende App: sie zeigte bei jedem Start den Startbildschirm.** Seither
/// überschreibt `bootstrap()` diesen Provider mit `KeyValueFirstLaunchStore`,
/// und der flüchtige bleibt die Vorgabe für Tests.
class InMemoryFirstLaunchStore implements FirstLaunchStore {
  /// [hasLaunched] setzt einen bereits erfolgten Start, etwa in einem Test.
  InMemoryFirstLaunchStore({bool hasLaunched = false})
    : _hasLaunched = hasLaunched;

  bool _hasLaunched;

  @override
  bool hasLaunched() => _hasLaunched;

  @override
  Future<void> markLaunched() async {
    _hasLaunched = true;
  }
}
