/// Der Vertrag der Sprachausgabe. Schritt 25.
///
/// ## Warum das in `services/` liegt und nicht in einem Feature
///
/// Dieselbe Erwägung wie bei `LocationService` und `OrientationService`, dort
/// ausführlich: `docs/architecture/domain-map.md` führt Vendor-Anbindungen
/// ohne eigene Oberfläche ausdrücklich **nicht** unter den Fachdomänen, und
/// `lib/features/README.md` nennt genau diesen Fall („Was bewusst kein Feature
/// ist"). Die Sprachausgabe hat kein Widget und keinen Zustand, den man
/// ansehen könnte; was man ansieht, ist der Knopf in der Fakt-Akte, und der
/// gehört `features/facts`.
///
/// ## Dieser Vertrag kennt keinen Fakt, und das ist Absicht
///
/// Er spricht **Text**. Die Quelle mischt beides: `AudioPlayer.play(fact,
/// lang)` nimmt einen Fakt, baut daraus die Vorlesefassung, hält ihn als
/// `currentFact` und gibt ihn im Zustand wieder heraus
/// (`02_Frontend/app/audio-player.jsx:219-272`). Für drei ihrer eigenen
/// Aufrufer passt das nicht, und sie behilft sich mit
/// `{ titel: '', text }`-Attrappen (`:394`, `:399`, `:410`); an einer vierten
/// Stelle steht der Grund als Kommentar im Code: „passing { titel: '' } made
/// MiniPlayer pop up with an empty title for every beacon" (`:347-348`).
///
/// Wer den Fakt braucht, hält ihn selbst. Die Vorlesefassung baut
/// `spokenFactText` in `features/facts`, und wer gerade läuft, weiß der
/// Aufrufer, der es angestoßen hat.
///
/// ## Anbieterneutral, und der Schlüssel liegt nie im Client
///
/// Beides steht so in E-15, und beides ist eine Vorgabe von Janek vom
/// 31.08.2026: „erstmal einfach Gerät und später kann man dann über chatgpt
/// das nice abspielen lassen … bau auch alles schon so, dass nur noch ein
/// Klick wäre das andere zu aktivieren. soll aber nirgends rumliegen, ist ja
/// schließlich ein api key."
///
/// **Der „eine Klick" ist der Provider.** `speechServiceProvider` ist auf
/// diesem Vertrag typisiert; eine Cloud-Fassung tauschen heißt, in
/// `bootstrap()` eine Zeile zu ändern. Es gibt hier bewusst **kein**
/// `prepare()` oder `cache()` auf Vorrat: das Gerät hat nichts vorzuladen, und
/// ADR-002 verbietet Vorrat ohne Aufrufer. Was die Cloud-Fassung zusätzlich
/// braucht, bringt sie mit, und E-15 sagt, was das sein wird: vorladen, dann
/// abspielen, über Edge Function und Proxy.
///
/// **Warum der zweite Halbsatz nicht verhandelbar ist**, gemessen am
/// 02.09.2026: die Quelle hat den Schlüssel im Klartext in einer Datei, die
/// jeder Browser ausgeliefert bekommt, und in zwei gebauten Bündeln
/// dazu (E-70). Das war eine bewusste Abwägung von damals. Sie ist der Grund,
/// warum dieser Vertrag von einem Schlüssel nichts weiß.
///
/// `abstract interface class`: ein versehentliches `extends` geht damit nicht
/// durch, und jeder Doppelgänger im Test schreibt sichtbar
/// `implements SpeechService`.
library;

/// Was die Sprachausgabe gerade tut.
///
/// Drei Zustände und nicht zwei Wahrheitswerte. Die Quelle führt
/// `isPlaying` und `isPaused` getrennt (`audio-player.jsx:55-57`) und muss sie
/// an jeder Abfrage zusammenrechnen; ihr eigener Knopf tut das in drei
/// Zweigen (`screen-fact.jsx:376-378`). Mit einem Wert gibt es die vierte,
/// unmögliche Kombination nicht.
enum SpeechState {
  /// Es wird nicht gesprochen.
  idle,

  /// Es wird gerade gesprochen.
  speaking,

  /// Angehalten, und fortsetzbar.
  paused,
}

/// Woher die App die Sprachausgabe bekommt.
abstract interface class SpeechService {
  /// Jede Änderung des Zustands.
  ///
  /// **Ein Strom und kein Abfragewert**, weil das Ende einer Ausgabe von
  /// außen kommt: der Sprecher ist irgendwann fertig, und der Knopf muss von
  /// „Pause" auf „Abspielen" zurückfallen, ohne dass jemand nachfragt. Die
  /// Quelle löst dasselbe mit `onStateChange` und einer Liste von Rückrufen
  /// (`audio-player.jsx:319-325`).
  ///
  /// Der Strom endet nicht von sich aus, und ein Fehlschlag der Ausgabe
  /// beendet ihn auch nicht: er meldet dann [SpeechState.idle]. Eine
  /// Sprachausgabe, die einmal nicht kann, ist kein Grund, den Knopf für den
  /// Rest der Sitzung stumm zu schalten.
  Stream<SpeechState> stateUpdates();

  /// Spricht [text] in der Sprache [languageTag].
  ///
  /// [languageTag] ist ein BCP-47-Kennzeichen. Die beiden Werte, die die App
  /// benutzt, sind in der Quelle gemessen: `de-DE` und `en-US`
  /// (`audio-player.jsx:262`). Die Zuordnung von `AppLanguage` auf das
  /// Kennzeichen macht der Aufrufer; dieser Vertrag kennt die Sprachwahl der
  /// App nicht, sonst müsste `lib/services/` `lib/app/` importieren.
  ///
  /// [rate] ist die Sprechgeschwindigkeit, 1,0 ist normal.
  ///
  /// **Ein laufender Vortrag wird abgebrochen.** Die Quelle ruft als erste
  /// Zeile ihres `play` ein `this.stop()` (`audio-player.jsx:221`), und das
  /// ist auch die einzige sinnvolle Wahl: zwei gleichzeitige Stimmen sind
  /// keine Funktion.
  ///
  /// **Wirft nicht.** Scheitert die Ausgabe, bleibt es still und der Zustand
  /// fällt auf [SpeechState.idle]. Die Quelle macht es genauso und begründet
  /// es an drei Stellen mit demselben `console.warn`: ein Vorlesen, das nicht
  /// klappt, darf den Bildschirm nicht mitnehmen.
  Future<void> speak({
    required String text,
    required String languageTag,
    double rate,
  });

  /// Hält den laufenden Vortrag an.
  ///
  /// Ohne laufenden Vortrag passiert nichts. Wirft nicht.
  Future<void> pause();

  /// Setzt einen angehaltenen Vortrag fort.
  ///
  /// Ohne angehaltenen Vortrag passiert nichts. Wirft nicht.
  Future<void> resume();

  /// Beendet den Vortrag.
  ///
  /// Idempotent, und der Zustand ist danach [SpeechState.idle]. Wirft nicht.
  Future<void> stop();
}

/// Die Standard-Sprechgeschwindigkeit, `1.0` in der Quelle.
///
/// `Storage.getAudioRate()` hat `1.0` als Rückfall (`storage.jsx:168`), und
/// **eine Einstellung dafür gibt es im Neubau noch nicht.** Die Quelle hat
/// einen Schieber im Profil; er kommt mit dem Einstellungs-Bildschirm, und
/// dann wird daraus ein siebter Speicher am `KeyValueStore`. Bis dahin ist die
/// Zahl eine Konstante und keine erfundene Einstellung.
///
/// Dasselbe gilt für die Stimmenwahl (`Storage.getAudioVoice()`): sie hängt
/// laut Schrittliste an E-15 und ist offen.
const double defaultSpeechRate = 1;

/// Der untätige Standard: eine Sprachausgabe, die nichts sagt.
///
/// Dasselbe Muster wie `unavailableLocationService`, und aus demselben Grund:
/// der Standard eines Providers muss ohne Plattformkanal auskommen, sonst
/// fällt jeder Widget-Test über eine `MissingPluginException`. Die echte
/// Fassung setzt `lib/app/bootstrap.dart` per Override ein.
const SpeechService unavailableSpeechService = _UnavailableSpeechService();

final class _UnavailableSpeechService implements SpeechService {
  const _UnavailableSpeechService();

  /// Ein leerer Strom, der sofort endet.
  ///
  /// **Nicht ein Strom, der ewig offen bleibt**, dieselbe Begründung wie bei
  /// `_UnavailableLocationService`: ein Abonnent sähe keinen Unterschied,
  /// aber ein offener Strom hielte in jedem Test eine Zeitüberschreitung
  /// offen, die niemand sucht.
  @override
  Stream<SpeechState> stateUpdates() => const Stream<SpeechState>.empty();

  @override
  Future<void> speak({
    required String text,
    required String languageTag,
    double rate = defaultSpeechRate,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}
}
