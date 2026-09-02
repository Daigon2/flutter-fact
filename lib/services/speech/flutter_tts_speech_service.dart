/// Die Sprachausgabe des Geräts, über `flutter_tts`.
///
/// **Das einzige Verzeichnis, in dem `flutter_tts` vorkommen darf**, Regel 25
/// in `docs/architecture/dependency-rules.md`. Dieselbe Bauform wie
/// `lib/services/location/` für `geolocator` (Regel 21),
/// `lib/services/orientation/` für `flutter_rotation_sensor` (Regel 24) und
/// `lib/services/preferences/` für `shared_preferences` (Regel 22).
///
/// ## Vier Eigenheiten des Pakets, alle am 02.09.2026 in seinem Quelltext
/// nachgelesen, nicht vermutet
///
/// Sie sind der Grund, warum es diesen Adapter gibt und nicht nur einen
/// direkten Aufruf. Jede einzelne wäre am Gerät ein Fehler, den kein
/// Widget-Test zeigt.
///
/// 1. **„Normal" ist `0.5` und nicht `1.0`.** Die Doku am `setSpeechRate` des
///    Pakets sagt „Allowed values are in the range from 0.0 (slowest) to 1.0
///    (fastest)", und der Android-Teil sagt in einem eigenen Kommentar warum:
///    „To make the FlutterTts API consistent across platforms, Android 1.0 is
///    mapped to flutter 0.5", umgesetzt als `rate.toFloat() * 2.0f`
///    (`FlutterTtsPlugin.kt:390-396`). Auf iOS geht der Wert unverändert an
///    `AVSpeechUtterance.rate`, dessen Normalwert
///    `AVSpeechUtteranceDefaultSpeechRate` ebenfalls `0.5` ist
///    (`SwiftFlutterTtsPlugin.swift:11`, `:258`).
///
///    **Die Web-Sprachausgabe der Quelle rechnet umgekehrt**, dort ist `1.0`
///    normal (`audio-player.jsx:262`, `u.rate = Storage.getAudioRate()` mit
///    Rückfall `1.0`). Wer die Zahl der Quelle unverändert übernimmt, bekommt
///    also **die schnellste** Stufe. Deshalb rechnet [_pluginRate] um, und
///    deshalb ist die Einheit des Vertrags die menschliche: `1.0` ist normal.
///
/// 2. **Es gibt kein `resume()`.** Das Paket hat `speak`, `pause` und `stop`
///    und nichts dazwischen. Fortgesetzt wird durch ein erneutes `speak`:
///    iOS ruft dann `continueSpeaking()` und **ignoriert den Text**
///    (`SwiftFlutterTtsPlugin.swift:139-142`), Android setzt an der gemerkten
///    Stelle fort, **aber nur wenn derselbe Text kommt** („Ensure the text
///    hasn't changed", `FlutterTtsPlugin.kt:294-303`); mit einem anderen Text
///    beginnt es von vorn. Dieser Adapter merkt sich deshalb den letzten Text
///    in [_lastText]. Ohne das Merken wäre `resume` auf Android ein Neustart
///    des Vortrags.
///
/// 3. **Anhalten ist auf Android nachgebaut, nicht eingebaut.** Die
///    Paket-Doku: „Android TTS does not support the pause function natively,
///    so we have implemented a work around", über `onRangeStart()`, und
///    deshalb erst ab **SDK 26**. Auf älteren Geräten hält `pause` also an,
///    setzt aber von vorn fort. Das ist eine Eigenschaft der Plattform und
///    keine, die dieser Adapter reparieren kann; sie steht hier, damit sie
///    nicht als eigener Fehler gesucht wird.
///
/// 4. **`awaitSpeakCompletion` bleibt aus.** Damit kehrt `speak` zurück, sobald
///    der Text an die Plattform übergeben ist, und nicht erst am Ende des
///    Vortrags. Das ist die Zusage des Vertrags, und sie ist die richtige:
///    ein `speak`, dessen `Future` bis zum letzten Wort offen bleibt, verleitet
///    jeden Knopfdruck-Handler zu einem `await` über eine halbe Minute. Das
///    Ende kommt über [stateUpdates].
///
///    Nebenwirkung, die dazugehört: mit ausgeschaltetem
///    `awaitSpeakCompletion` setzt der Android-Teil sein internes `speaking`
///    nie auf `true` (`FlutterTtsPlugin.kt:319-322`), und die Sperre, die
///    einen zweiten `speak` verwerfen würde (`:304-310`), greift deshalb nie.
///    Wer die Einstellung einschaltet, muss diese Sperre mitbedenken.
///
/// ## Was hier bewusst fehlt
///
/// **Die Wahl der Stimme** (`setVoice`). Sie hängt an E-15 und ist offen, siehe
/// `defaultSpeechRate`. **Die iOS-Audio-Kategorie** (`setIosAudioCategory`):
/// ob der Vortrag über den Klingelton-Kanal oder den Medienkanal läuft und was
/// bei aktivem Stummschalter passiert, ist am Gerät zu messen und nicht zu
/// raten. Steht als Gerätefrage im Protokoll.
library;

import 'dart:async';

import 'package:fact_app/services/speech/speech_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// [SpeechService] auf der Sprachausgabe des Geräts.
final class FlutterTtsSpeechService implements SpeechService {
  /// Erzeugt den Adapter und hängt die Zustandsmelder ein.
  ///
  /// [tts] ist überschreibbar, damit ein Test den Plattformkanal nicht
  /// braucht. Ohne diesen Haken wäre dieser Adapter nur am Gerät prüfbar.
  FlutterTtsSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts
      ..setStartHandler(() => _emit(SpeechState.speaking))
      ..setCompletionHandler(() => _emit(SpeechState.idle))
      ..setCancelHandler(() => _emit(SpeechState.idle))
      ..setPauseHandler(() => _emit(SpeechState.paused))
      ..setContinueHandler(() => _emit(SpeechState.speaking))
      // Ein Fehlschlag ist kein eigener Zustand, sondern Stille. Der Vertrag
      // sagt es so, und der Knopf soll danach wieder „Abspielen" zeigen und
      // nicht auf „Pause" hängen bleiben.
      ..setErrorHandler((dynamic message) => _emit(SpeechState.idle));
  }

  final FlutterTts _tts;

  /// **`broadcast`, und das ist keine Bequemlichkeit.** Dieser Dienst hat
  /// absehbar mehr als einen Zuhörer: die Fakt-Akte zeigt ihren Knopf, und ab
  /// Schritt 26 hängt die Karte am selben Zustand. Ein Einzel-Abonnement-Strom
  /// würde beim zweiten Zuhörer werfen.
  final StreamController<SpeechState> _states =
      StreamController<SpeechState>.broadcast();

  /// Der letzte gesprochene Text, für [resume].
  ///
  /// Siehe Eigenheit 2 im Kopf dieser Datei: Android setzt nur fort, wenn
  /// derselbe Text noch einmal kommt.
  String? _lastText;

  @override
  Stream<SpeechState> stateUpdates() => _states.stream;

  /// Spricht [text].
  ///
  /// **Erst `stop`, dann sprechen.** Dieselbe Reihenfolge wie in der Quelle
  /// (`this.stop()` als erste Zeile von `AudioPlayer.play`,
  /// `audio-player.jsx:221`), und hier zusätzlich nötig, damit ein
  /// **angehaltener** Vortrag nicht fortgesetzt statt ersetzt wird: ein
  /// `speak` im angehaltenen Zustand ist auf beiden Plattformen ein
  /// Fortsetzen, siehe Eigenheit 2. Ohne das `stop` würde ein Tipp auf einen
  /// anderen Fakt den alten weitersprechen.
  ///
  /// Ein leerer Text spricht nicht. Die Quelle prüft das nicht und schickt bei
  /// einem Fakt ohne Texte die Zeichenkette `undefined` an den Sprecher; das
  /// ist kein Verhalten, das nachgebaut gehört.
  @override
  Future<void> speak({
    required String text,
    required String languageTag,
    double rate = defaultSpeechRate,
  }) async {
    // **`_guard(_tts.stop)` und nicht das öffentliche [stop].** Der
    // Unterschied ist ein `idle`, das hier niemand braucht: es liegt zwischen
    // zwei Vorträgen, kein Knopf soll dabei aufblinken, und ein Verbraucher,
    // der auf `idle` seinen Zustand aufräumt, würde dabei den gerade
    // gesetzten neuen Vortrag mit wegräumen. Das `speaking` kommt vom
    // Startmelder.
    await _guard(_tts.stop);
    if (text.isEmpty) {
      // Nichts zu sprechen heißt: es ist still. Anders als zwischen zwei
      // Vorträgen ist das ein Endzustand, und der Knopf muss ihn sehen.
      _emit(SpeechState.idle);
      return;
    }
    _lastText = text;
    await _guard(() async {
      await _tts.setLanguage(languageTag);
      await _tts.setSpeechRate(_pluginRate(rate));
      await _tts.speak(text);
    });
  }

  @override
  Future<void> pause() => _guard(_tts.pause);

  /// Setzt fort, durch ein erneutes `speak` mit **demselben** Text.
  ///
  /// Siehe Eigenheit 2. Ohne gemerkten Text gibt es nichts fortzusetzen, und
  /// dann passiert nichts: einen Vortrag zu erfinden wäre schlimmer, als den
  /// Knopf ins Leere laufen zu lassen.
  @override
  Future<void> resume() async {
    final String? text = _lastText;
    if (text == null) {
      return;
    }
    await _guard(() => _tts.speak(text));
  }

  @override
  Future<void> stop() async {
    await _guard(_tts.stop);
    // **Nach `_guard` und ohne Bedingung.** Der Zustand muss auch dann auf
    // `idle` fallen, wenn der Plattformkanal gerade nicht antwortet, sonst
    // hängt der Knopf auf „Pause".
    _emit(SpeechState.idle);
  }

  /// Gibt die Mittel des Adapters frei.
  ///
  /// Wer ihn in einem Provider hält, ruft das in `ref.onDispose`. Ohne den
  /// Aufruf bleibt der Strom offen, und in einem Test schlägt das als
  /// „A Timer is still pending" oder als offener Controller auf.
  Future<void> dispose() async {
    await stop();
    await _states.close();
  }

  void _emit(SpeechState state) {
    if (!_states.isClosed) {
      _states.add(state);
    }
  }

  /// Führt [work] aus und verschluckt einen Fehlschlag des Plattformkanals.
  ///
  /// **Der Vertrag verspricht, dass nichts wirft**, und ohne diese Klammer
  /// bricht jede fehlende Sprachausgabe den Aufrufer mit einer
  /// `MissingPluginException` oder einer `PlatformException` ab. Gemeldet wird
  /// hier nichts: eine Diagnosesenke hätte dieser Adapter erst als zweite
  /// Abhängigkeit, und ein Vortrag, der nicht klappt, ist kein Ereignis, das
  /// jemand auswertet. **Der Auslöser, das zu ändern:** die erste Frage „warum
  /// spricht es auf diesem Gerät nicht".
  Future<void> _guard(Future<void> Function() work) async {
    try {
      await work();
    } on Object {
      // Absichtlich alles: `MissingPluginException` ist eine `Exception`,
      // eine gescheiterte Kanalantwort eine `PlatformException`, und ein
      // fehlender Sprecher auf Android kommt als beliebiger `Error` zurück.
      return;
    }
  }

  /// Die Sprechgeschwindigkeit in der Skala des Pakets.
  ///
  /// `1.0` des Vertrags ist normal und wird `0.5`, siehe Eigenheit 1. Geklemmt
  /// auf `[0, 1]`, weil das Paket außerhalb dieses Bereichs auf Android in
  /// `TextToSpeech.setSpeechRate` durchläuft und dort undefiniert ist.
  static double _pluginRate(double rate) => (rate / 2).clamp(0, 1);
}
