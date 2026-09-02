import 'package:fact_app/services/speech/flutter_tts_speech_service.dart';
import 'package:fact_app/services/speech/speech_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Der Adapter auf `flutter_tts`.
///
/// **Ohne Plattformkanal, und das ist der Grund, warum
/// [FlutterTtsSpeechService] sein `FlutterTts` von außen nimmt.** Ein
/// Widget-Test hat keinen Kanal; ein Adapter, der seine Abhängigkeit selbst
/// baut, wäre nur am Gerät prüfbar, und dann bliebe die Umrechnung der
/// Sprechgeschwindigkeit ungeprüft. Genau die ist die Stelle, an der ein
/// naiver Port die schnellste Stufe eingestellt hätte.
void main() {
  // `FlutterTts()` setzt im Konstruktor einen Methodenkanal-Handler, und das
  // braucht eine initialisierte Bindung. Ohne diese Zeile scheitert schon der
  // Bau des Doppelgängers.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTts tts;
  late FlutterTtsSpeechService service;

  setUp(() {
    tts = _FakeTts();
    service = FlutterTtsSpeechService(tts: tts);
  });

  tearDown(() => service.dispose());

  group('sprechen', () {
    test('setzt Sprache und Geschwindigkeit, dann den Text', () async {
      await service.speak(text: 'Hallo', languageTag: 'de-DE');

      expect(tts.calls, <String>[
        'stop',
        'setLanguage:de-DE',
        'setSpeechRate:0.5',
        'speak:Hallo',
      ]);
    });

    test('hält vorher an, damit ein Vortrag ersetzt und nicht fortgesetzt '
        'wird', () async {
      // `this.stop()` als erste Zeile von `AudioPlayer.play`
      // (`audio-player.jsx:221`), und hier zusätzlich nötig: ein `speak` im
      // angehaltenen Zustand ist auf beiden Plattformen ein **Fortsetzen**.
      // Ohne das `stop` sprach ein Tipp auf einen anderen Fakt den alten
      // weiter.
      await service.speak(text: 'Erster', languageTag: 'de-DE');
      tts.calls.clear();

      await service.speak(text: 'Zweiter', languageTag: 'de-DE');

      expect(tts.calls.first, 'stop');
    });

    test('ein leerer Text spricht nicht', () async {
      // Die Quelle prüft das nicht und schickt bei einem Fakt ohne Texte
      // `undefined` an den Sprecher.
      await service.speak(text: '', languageTag: 'de-DE');

      expect(
        tts.calls.where((String call) => call.startsWith('speak')),
        isEmpty,
      );
    });

    test('ein leerer Text meldet Stille', () async {
      final List<SpeechState> seen = <SpeechState>[];
      service.stateUpdates().listen(seen.add);

      await service.speak(text: '', languageTag: 'de-DE');
      await pumpEventQueue();

      expect(seen, <SpeechState>[SpeechState.idle]);
    });

    test('das Ersetzen eines Vortrags meldet kein Zwischen-Idle', () async {
      // Sonst blinkte der Knopf zwischen zwei Fakten auf „Abspielen", und ein
      // Verbraucher, der auf `idle` aufräumt, würde den gerade gesetzten
      // neuen Fakt mit wegräumen.
      await service.speak(text: 'Erster', languageTag: 'de-DE');
      final List<SpeechState> seen = <SpeechState>[];
      service.stateUpdates().listen(seen.add);

      await service.speak(text: 'Zweiter', languageTag: 'de-DE');
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });

  group('die Geschwindigkeit, und die ist die Falle', () {
    // Die Doku des Pakets: „Allowed values are in the range from 0.0
    // (slowest) to 1.0 (fastest)", und der Android-Teil rechnet
    // `rate * 2.0f`, mit dem eigenen Kommentar „Android 1.0 is mapped to
    // flutter 0.5". Auf iOS ist `AVSpeechUtteranceDefaultSpeechRate` ebenfalls
    // 0.5. Die Quelle rechnet umgekehrt, dort ist 1.0 normal.
    test('der Normalwert des Vertrags wird 0,5', () async {
      await service.speak(
        text: 'Hallo',
        languageTag: 'de-DE',
        rate: defaultSpeechRate,
      );

      expect(tts.calls, contains('setSpeechRate:0.5'));
    });

    test('die Zahl der Quelle wäre die schnellste Stufe gewesen', () async {
      // Genau der Fehler, den ein unbesehener Port gemacht hätte: die Quelle
      // hat 1.0 als Rückfall, und 1.0 heißt im Paket „fastest".
      expect(defaultSpeechRate, 1.0);
      await service.speak(text: 'Hallo', languageTag: 'de-DE', rate: 2);

      expect(tts.calls, contains('setSpeechRate:1.0'));
    });

    test('halb so schnell wird 0,25', () async {
      await service.speak(text: 'Hallo', languageTag: 'de-DE', rate: 0.5);

      expect(tts.calls, contains('setSpeechRate:0.25'));
    });

    test('geklemmt nach oben', () async {
      await service.speak(text: 'Hallo', languageTag: 'de-DE', rate: 10);

      expect(tts.calls, contains('setSpeechRate:1.0'));
    });

    test('geklemmt nach unten', () async {
      await service.speak(text: 'Hallo', languageTag: 'de-DE', rate: -3);

      expect(tts.calls, contains('setSpeechRate:0.0'));
    });
  });

  group('anhalten und fortsetzen', () {
    test('anhalten gibt den Befehl weiter', () async {
      await service.pause();

      expect(tts.calls, <String>['pause']);
    });

    test('fortsetzen spricht denselben Text noch einmal', () async {
      // Es gibt in `flutter_tts` kein `resume`. iOS ruft bei einem `speak` im
      // angehaltenen Zustand `continueSpeaking()` und ignoriert den Text;
      // Android setzt an der gemerkten Stelle fort, **aber nur wenn derselbe
      // Text kommt** („Ensure the text hasn't changed"). Wer den Text nicht
      // merkt, baut auf Android einen Neustart des Vortrags.
      await service.speak(text: 'Ein langer Satz', languageTag: 'de-DE');
      await service.pause();
      tts.calls.clear();

      await service.resume();

      expect(tts.calls, <String>['speak:Ein langer Satz']);
    });

    test('ohne vorherigen Vortrag setzt fortsetzen nichts fort', () async {
      await service.resume();

      expect(tts.calls, isEmpty);
    });
  });

  group('beenden', () {
    test('gibt den Befehl weiter und meldet Stille', () async {
      final List<SpeechState> seen = <SpeechState>[];
      service.stateUpdates().listen(seen.add);

      await service.stop();
      await pumpEventQueue();

      expect(tts.calls, <String>['stop']);
      expect(seen, <SpeechState>[SpeechState.idle]);
    });

    test('meldet Stille auch, wenn der Kanal scheitert', () async {
      // Sonst hängt der Knopf auf „Pause", während nichts mehr spricht.
      tts.failEverything = true;
      final List<SpeechState> seen = <SpeechState>[];
      service.stateUpdates().listen(seen.add);

      await service.stop();
      await pumpEventQueue();

      expect(seen, <SpeechState>[SpeechState.idle]);
    });
  });

  group('der Zustandsstrom', () {
    test('folgt den Meldern des Pakets', () async {
      final List<SpeechState> seen = <SpeechState>[];
      service.stateUpdates().listen(seen.add);

      tts.fireStart();
      tts.firePause();
      tts.fireContinue();
      tts.fireCompletion();
      tts.fireCancel();
      await pumpEventQueue();

      expect(seen, <SpeechState>[
        SpeechState.speaking,
        SpeechState.paused,
        SpeechState.speaking,
        SpeechState.idle,
        SpeechState.idle,
      ]);
    });

    test('ein Fehler ist Stille und kein eigener Zustand', () async {
      final List<SpeechState> seen = <SpeechState>[];
      service.stateUpdates().listen(seen.add);

      tts.fireError('kein Sprecher installiert');
      await pumpEventQueue();

      expect(seen, <SpeechState>[SpeechState.idle]);
    });

    test('mehr als ein Zuhörer ist erlaubt', () async {
      // `broadcast`: ab Schritt 26 hängt die Karte am selben Zustand wie die
      // Fakt-Akte. Ein Einzel-Abonnement-Strom würde beim zweiten werfen.
      final List<SpeechState> ersterZuhoerer = <SpeechState>[];
      final List<SpeechState> zweiterZuhoerer = <SpeechState>[];
      service.stateUpdates().listen(ersterZuhoerer.add);
      service.stateUpdates().listen(zweiterZuhoerer.add);

      tts.fireStart();
      await pumpEventQueue();

      expect(ersterZuhoerer, <SpeechState>[SpeechState.speaking]);
      expect(zweiterZuhoerer, <SpeechState>[SpeechState.speaking]);
    });
  });

  group('ein Plattformkanal, der scheitert', () {
    test('nimmt den Aufrufer nicht mit', () async {
      // Der Vertrag verspricht, dass nichts wirft. Ohne die Klammer im
      // Adapter bricht jede fehlende Sprachausgabe den Bildschirm ab.
      tts.failEverything = true;

      await expectLater(
        service.speak(text: 'Hallo', languageTag: 'de-DE'),
        completes,
      );
      await expectLater(service.pause(), completes);
      await expectLater(service.stop(), completes);
    });

    test('auch ein Error und nicht nur eine Exception', () async {
      // `MissingPluginException` ist eine `Exception`, ein fehlender Sprecher
      // auf Android kommt als beliebiger `Error` zurück. Deshalb fängt der
      // Adapter `Object` und nicht `Exception`.
      //
      // **Dieser Test war zuerst blind, und eine Mutation hat es gezeigt.**
      // Er setzte `failWith` und **nicht** `failEverything`, und der
      // Doppelgänger wirft nur, wenn das zweite Feld gesetzt ist. Damit warf
      // gar nichts, und `_guard` mit `on Exception` statt `on Object`
      // überlebte die Mutation ungestraft. Muster 5 aus dem
      // Blindheitskatalog: ein Aufbau, der die Bedingung nicht herstellt,
      // prüft die Zusicherung nie.
      tts.failEverything = true;
      tts.failWith = StateError('kaputt');

      await expectLater(
        service.speak(text: 'Hallo', languageTag: 'de-DE'),
        completes,
      );
    });
  });

  group('aufräumen', () {
    test('beendet den Vortrag und schließt den Strom', () async {
      final List<SpeechState> seen = <SpeechState>[];
      service.stateUpdates().listen(
        seen.add,
        onDone: () => seen.add(SpeechState.idle),
      );

      await service.dispose();
      await pumpEventQueue();

      expect(tts.calls, contains('stop'));
      // Nach dem Schließen melden weitere Ereignisse nichts mehr, und zwar
      // ohne zu werfen: `_emit` prüft `isClosed`. Ohne die Prüfung wäre eine
      // verspätete Meldung des Plattformkanals ein „Cannot add new events
      // after calling close".
      expect(tts.fireStart, returnsNormally);
    });
  });
}

/// Ein `FlutterTts`, das nichts sagt und alles mitschreibt.
///
/// Erbt von der echten Klasse, weil [FlutterTtsSpeechService] auf ihr
/// typisiert ist: sie ist weder `final` noch `sealed`, und die fünf benutzten
/// Methoden sind überschreibbar. Der Konstruktor der Basisklasse setzt einen
/// Kanal-Handler; das ist der Grund für das `ensureInitialized` oben.
class _FakeTts extends FlutterTts {
  final List<String> calls = <String>[];

  /// Wenn gesetzt, wirft jeder Aufruf.
  bool failEverything = false;

  /// Womit geworfen wird, wenn [failEverything] gilt.
  Object failWith = Exception('kein Kanal');

  VoidCallback? _start;
  VoidCallback? _completion;
  VoidCallback? _cancel;
  VoidCallback? _pause;
  VoidCallback? _continue;
  ErrorHandler? _error;

  void fireStart() => _start?.call();
  void fireCompletion() => _completion?.call();
  void fireCancel() => _cancel?.call();
  void firePause() => _pause?.call();
  void fireContinue() => _continue?.call();
  void fireError(String message) => _error?.call(message);

  Future<dynamic> _record(String call) async {
    if (failEverything) {
      throw failWith;
    }
    calls.add(call);
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) =>
      _record('speak:$text');

  @override
  Future<dynamic> pause() => _record('pause');

  @override
  Future<dynamic> stop() => _record('stop');

  @override
  Future<dynamic> setLanguage(String language) =>
      _record('setLanguage:$language');

  @override
  Future<dynamic> setSpeechRate(double rate) => _record('setSpeechRate:$rate');

  @override
  void setStartHandler(VoidCallback callback) => _start = callback;

  @override
  void setCompletionHandler(VoidCallback callback) => _completion = callback;

  @override
  void setCancelHandler(VoidCallback callback) => _cancel = callback;

  @override
  void setPauseHandler(VoidCallback callback) => _pause = callback;

  @override
  void setContinueHandler(VoidCallback callback) => _continue = callback;

  @override
  void setErrorHandler(ErrorHandler handler) => _error = handler;
}
