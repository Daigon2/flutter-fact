import 'package:fact_app/services/speech/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der untätige Standard der Sprachausgabe.
///
/// Er ist der Grund, warum `flutter test` ohne Plattformkanal durchläuft, und
/// gleichzeitig genau der stille Ausfall, den `bootstrap_test.dart` mit dem
/// Override absichert.
void main() {
  group('unavailableSpeechService', () {
    test('sein Zustandsstrom endet sofort', () async {
      // **Nicht ein Strom, der ewig offen bleibt.** Ein Abonnent sähe keinen
      // Unterschied, aber ein offener Strom hielte in jedem Test eine
      // Zeitüberschreitung offen, die niemand sucht.
      expect(await unavailableSpeechService.stateUpdates().toList(), isEmpty);
    });

    test('alle vier Befehle laufen durch, ohne zu werfen', () async {
      await expectLater(
        unavailableSpeechService.speak(text: 'Hallo', languageTag: 'de-DE'),
        completes,
      );
      await expectLater(unavailableSpeechService.pause(), completes);
      await expectLater(unavailableSpeechService.resume(), completes);
      await expectLater(unavailableSpeechService.stop(), completes);
    });

    test('er ist eine Konstante und damit überall dieselbe Instanz', () {
      expect(unavailableSpeechService, same(unavailableSpeechService));
    });
  });

  group('die Zustände', () {
    test('drei und nicht zwei Wahrheitswerte', () {
      // Die Quelle führt `isPlaying` und `isPaused` getrennt und muss sie an
      // jeder Abfrage zusammenrechnen; ihr Knopf tut das in drei Zweigen. Mit
      // einem Wert gibt es die vierte, unmögliche Kombination nicht.
      expect(SpeechState.values, <SpeechState>[
        SpeechState.idle,
        SpeechState.speaking,
        SpeechState.paused,
      ]);
    });
  });

  group('die Standardgeschwindigkeit', () {
    test('ist die menschliche Einheit, nicht die des Pakets', () {
      // `1.0` heißt normal, wie in der Quelle (`Storage.getAudioRate()` mit
      // Rückfall `1.0`). Die Umrechnung auf die Skala von `flutter_tts`, in
      // der `0.5` normal ist, macht der Adapter.
      expect(defaultSpeechRate, 1.0);
    });
  });
}
