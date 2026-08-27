/// Vertrag für die Präferenz "Audio-Guide ist eingeschaltet".
///
/// Entspricht `fact_audio_mode` im `localStorage` der PWA: `storage.jsx:161`
/// liest es, `storage.jsx:162-166` schreibt es. Eingeschaltet wird es an genau
/// einer Stelle, dem Audio-Dialog des Startbildschirms
/// (`screen-auth.jsx:404`).
///
/// ## Warum dieser Vertrag bei `settings` liegt und nicht bei `identity`
///
/// Der Dialog gehört zum Startbildschirm, die Präferenz nicht.
/// `lib/features/README.md:22` gibt `settings` ausdrücklich die
/// "Audio-Präferenzen". `identity` besitzt Session und Anmeldung, und ein
/// Schalter, der später im Profil wieder umgelegt wird
/// (`audio.dialog.body`: "Du kannst den Modus jederzeit im Profil wieder
/// ausschalten"), wäre dort am falschen Platz.
///
/// Ein Feature `audio` gibt es bewusst nicht (`lib/features/README.md:43-45`):
/// Wiedergabe und Sprachausgabe sind Transport und landen unter `services`. Was
/// hier steht, ist die **Absicht des Nutzers**, nicht der Weg zum Lautsprecher.
///
/// ## Diese Präferenz hat heute noch keinen Konsumenten
///
/// Nach Schritt 8 speichert sie ein `true`, und danach passiert nichts: es gibt
/// keine Wiedergabe, keine Sprachausgabe und keine Kartenlogik, die sie liest.
/// Das ist der geplante Zwischenstand, aber es heißt **nicht**, dass Audio
/// funktioniert.
///
/// ## Was die Quelle noch kennt und hier absichtlich fehlt
///
/// - **`fact_audio_help_shown`** (`storage.jsx:177-178`). Steuert
///   ausschließlich, ob die gesprochene Begrüßung `audio.help.greeting` beim
///   Aktivieren wiederholt wird (`screen-auth.jsx:413-416`). Ohne
///   Sprachausgabe hat dieser Zustand keinen Leser. Er ist bekannt und bleibt
///   bewusst offen, bis Schritt 25 den TTS-Weg entscheidet (offene Entscheidung
///   E-15 in `REBUILD_STATUS.md`). Ein Flag ohne Konsumenten wäre nur ein
///   zweiter Ort, der falsch sein kann.
/// - **`fact_audio_rate`, `fact_audio_voice`, `fact_headphone_mode`**
///   (`storage.jsx:168-175`). Gehören zum Audio-Abschnitt der Einstellungen
///   (`audio.settings.*`), nicht zu diesem Dialog. Sie kommen mit dem
///   Einstellungs-Bildschirm, nicht auf Vorrat.
/// - **Das Ereignis `fact-audio-mode-changed`** (`storage.jsx:164`). Der
///   Kommentar dort nennt den Grund: globale Gesten-Listener in `app.jsx`
///   hören darauf. Das ist ein Ersatz für fehlende Zustandsverwaltung im
///   Browser. Hier übernimmt Riverpod diese Aufgabe, ein zweiter
///   Benachrichtigungsweg wäre eine Fehlerquelle ohne Nutzen.
///
/// ## Warum [isEnabled] synchron ist
///
/// Aus demselben Grund wie bei `FirstLaunchStore.hasLaunched` und
/// `LanguagePreferenceStore.readLanguage`: der Wert steht beim ersten Frame
/// fest, und ein `Future` würde jeden Leser in einen Ladezustand zwingen. Beim
/// Audio-Modus wäre das besonders unpassend, denn er entscheidet später
/// darüber, **wie** ein Bildschirm überhaupt aufgebaut wird (Töne statt
/// Symbole). Ein Aufflackern der visuellen Variante wäre genau für die
/// Zielgruppe dieses Modus die schlechteste Reihenfolge.
///
/// Wer später persistiert, lädt in `bootstrap()` vor und überschreibt
/// `audioModeStoreProvider` mit einer gefüllten Implementierung.
///
/// Das ist eine Bequemlichkeits-Präferenz, **keine Sicherheitsgrenze**.
abstract interface class AudioModeStore {
  /// Ob der Audio-Guide eingeschaltet ist.
  bool isEnabled();

  /// Speichert [enabled] dauerhaft.
  ///
  /// Nimmt bewusst einen Bool und ist nicht wie `markLaunched` ein
  /// Einbahn-Schalter: die Quelle führt `fact_audio_mode` als Wahrheitswert
  /// (`storage.jsx:162`), und der Dialogtext verspricht das Ausschalten im
  /// Profil. Heute ruft nur der Audio-Dialog mit `true` auf; der Ausschalter
  /// entsteht mit dem Einstellungs-Bildschirm.
  ///
  /// Idempotent: derselbe Wert zweimal ist erlaubt und ändert nichts.
  Future<void> setEnabled(bool enabled);
}

/// Flüchtiger Standard, solange nichts persistiert, und Vorgabe für Tests.
///
/// Die Präferenz überlebt den Neustart nicht. Gewollt, aus demselben Grund wie
/// bei `InMemoryFirstLaunchStore`: eine halbe Persistenz wäre schwerer zu
/// erkennen als gar keine. Praktische Folge im aktuellen Stand: der Audio-Modus
/// ist bei jedem Start aus.
class InMemoryAudioModeStore implements AudioModeStore {
  /// [enabled] setzt einen bereits eingeschalteten Audio-Modus, etwa in einem
  /// Test.
  InMemoryAudioModeStore({bool enabled = false}) : _enabled = enabled;

  bool _enabled;

  @override
  bool isEnabled() => _enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
  }
}
