/// Kurze Klänge über `audioplayers`.
///
/// **Das einzige Verzeichnis, in dem `audioplayers` vorkommen darf**, Regel 26
/// in `docs/architecture/dependency-rules.md`. Dieselbe Bauform wie
/// `lib/services/speech/` für `flutter_tts` (Regel 25) und die drei Regeln
/// davor.
///
/// ## Drei Eigenheiten des Pakets, alle am 02.09.2026 im Quelltext nachgelesen
///
/// 1. **Der Pfad trägt kein `assets/`.** `AssetSource('audio/beacon.mp3')`
///    landet bei `assets/audio/beacon.mp3`, weil `AudioCache` einen Präfix
///    davorsetzt, dessen Standard `'assets/'` ist
///    (`audio_cache.dart:44-57`). Wer den Präfix mitschreibt, sucht die Datei
///    unter `assets/assets/audio/beacon.mp3` und findet nichts.
/// 2. **`play` nimmt die Stereo-Verteilung als Parameter mit** und setzt sie
///    vor der Quelle (`audioplayer.dart:194-217`). Ein eigenes `setBalance`
///    davor wäre ein zweiter Kanalaufruf ohne Wirkung.
/// 3. **Die Bedeutung von `balance` passt genau auf die Quelle.** Das Paket:
///    „-1 - The left channel is at full volume; the right channel is silent"
///    (`audioplayer.dart:305-310`). Die Quelle rechnet
///    `panner.pan.value = Math.sin(bearing)` (`audio-player.jsx:99-101`,
///    `:334`), und `pan` des `StereoPannerNode` hat denselben Bereich und
///    dieselbe Richtung. Es gibt hier also nichts umzurechnen, anders als bei
///    der Sprechgeschwindigkeit im Sprachdienst.
///
/// ## Ein Spieler, und er entsteht erst beim ersten Ton
///
/// `AudioPlayer` aus `audioplayers` hält einen Plattform-Spieler samt
/// Ressourcen. Für einen Hinweiston, der höchstens alle fünf Sekunden kommt,
/// ist eine Instanz genug, und ein zweiter Ton löst den ersten ab. Das ist
/// auch das Verhalten der Quelle: sie legt für jeden Ton einen
/// `BufferSource` an derselben `AudioContext` an.
///
/// **Erst beim ersten Ton, und das ist gemessen.** Der Konstruktor von
/// `AudioPlayer` ruft `_create()` und greift damit sofort auf den
/// Plattformkanal zu (`audioplayer.dart:150-174`). Ein Adapter, der ihn im
/// eigenen Konstruktor anlegt, macht damit zwei Dinge falsch: er belegt beim
/// Start Ressourcen für ein Merkmal, das die meisten Nutzer nie einschalten,
/// und er ist in `flutter test` nicht einmal lesbar. Der Testlauf des
/// `bootstrap_test` ist daran gescheitert, ohne jede Fehlermeldung, was die
/// Ursache erst nach einigem Suchen zeigte.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:fact_app/services/audio/tone_service.dart';

/// [ToneService] auf `audioplayers`.
final class AudioplayersToneService implements ToneService {
  /// Erzeugt den Adapter.
  ///
  /// Der Spieler ist überschreibbar, damit ein Test den Plattformkanal nicht
  /// braucht. Ohne diesen Haken wäre der Adapter nur am Gerät prüfbar, und
  /// dann bliebe der Pfad-Präfix aus Eigenheit 1 ungeprüft.
  ///
  /// Der Parameter heißt `_player` und nicht `player`, weil
  /// `prefer_initializing_formals` sonst anschlägt: ein Feldwert, der
  /// unverändert aus einem Parameter kommt, gehört als `this._player`
  /// geschrieben. Am Aufrufer ändert das nichts, dort steht weiter
  /// `AudioplayersToneService(player: ...)`, denn Dart streicht den
  /// Unterstrich im benannten Argument.
  AudioplayersToneService({this._player});

  /// Der Spieler, oder `null`, solange noch kein Ton kam.
  AudioPlayer? _player;

  @override
  Future<void> playTone(String assetPath, {double balance = 0}) async {
    try {
      // **Hier und nicht im Konstruktor**, siehe den Kopf dieser Datei. Das
      // `??=` ist der ganze Unterschied zwischen „belegt beim Start einen
      // Plattform-Spieler" und „belegt einen, sobald jemand ihn braucht".
      final AudioPlayer player = _player ??= AudioPlayer();
      await player.play(AssetSource(assetPath), balance: balance);
    } on Object {
      // Absichtlich alles, dieselbe Begründung wie im Sprachdienst: eine
      // fehlende Datei kommt als `Exception`, ein fehlender Kanal als
      // `MissingPluginException`, und ein Plattformfehler auf Android als
      // beliebiger `Error`. Ein Hinweiston, der nicht kommt, ist kein Grund,
      // den Aufrufer abzubrechen.
      return;
    }
  }

  /// Gibt den Spieler frei, falls es einen gibt.
  ///
  /// Wer den Dienst in einem Provider hält, ruft das in `ref.onDispose`. Ohne
  /// den Aufruf bleibt der Plattform-Spieler offen. **Ohne einen einzigen Ton
  /// gibt es nichts freizugeben**, und ein `AudioPlayer`, den erst das
  /// Aufräumen anlegt, wäre die schlechteste Reihenfolge von allen.
  Future<void> dispose() async {
    final AudioPlayer? player = _player;
    _player = null;
    await player?.dispose();
  }
}
