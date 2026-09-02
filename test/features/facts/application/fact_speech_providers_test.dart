import 'dart:async';

import 'package:fact_app/features/facts/application/fact_speech_providers.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/services/speech/speech_providers.dart';
import 'package:fact_app/services/speech/speech_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Naht zwischen „welcher Fakt" und „was tut die Sprachausgabe".
void main() {
  late _FakeSpeechService speech;

  setUp(() => speech = _FakeSpeechService());
  tearDown(() => speech.close());

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [speechServiceProvider.overrideWithValue(speech)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('speechLanguageTagFor', () {
    // `lang === 'en' ? 'en-US' : 'de-DE'`, `audio-player.jsx:262`.
    test('Englisch wird en-US', () {
      expect(speechLanguageTagFor('en'), 'en-US');
    });

    test('Deutsch wird de-DE', () {
      expect(speechLanguageTagFor('de'), 'de-DE');
    });

    test('alles andere fällt auf Deutsch zurück', () {
      // Wie in der Quelle, und wie `AppLanguage.fallback`. Eine
      // Sprachausgabe, die für eine unbekannte Sprache schweigt, wäre
      // schlechter als eine, die deutsch vorliest.
      expect(speechLanguageTagFor('fr'), 'de-DE');
      expect(speechLanguageTagFor(''), 'de-DE');
    });
  });

  group('der Anfangszustand', () {
    test('kein Fakt, keine Ausgabe', () {
      final FactSpeechStatus status = newContainer().read(factSpeechProvider);

      expect(status.factId, isNull);
      expect(status.state, SpeechState.idle);
    });
  });

  group('sprechen', () {
    test('setzt den Fakt und schickt Text und Sprache an den Dienst', () async {
      final ProviderContainer container = newContainer();

      await container
          .read(factSpeechProvider.notifier)
          .speak(
            factId: const FactId(7),
            text: 'Die Glyptothek',
            languageTag: 'de-DE',
          );

      expect(speech.spoken, <String>['Die Glyptothek|de-DE']);
      expect(container.read(factSpeechProvider).factId, const FactId(7));
    });

    test('der Fakt steht schon, bevor der Dienst antwortet', () async {
      // Die Meldung `speaking` kommt aus dem Plattformkanal und damit später.
      // Wäre der Fakt erst danach gesetzt, zeigte der Knopf für einen
      // Wimpernschlag den falschen.
      final ProviderContainer container = newContainer();
      speech.blockSpeak = true;

      unawaited(
        container
            .read(factSpeechProvider.notifier)
            .speak(factId: const FactId(7), text: 'Text', languageTag: 'de-DE'),
      );

      expect(container.read(factSpeechProvider).factId, const FactId(7));
      expect(
        container.read(factSpeechProvider).isSpeaking(const FactId(7)),
        isTrue,
      );
    });

    test('ein zweiter Fakt ersetzt den ersten', () async {
      final ProviderContainer container = newContainer();
      final FactSpeechNotifier notifier = container.read(
        factSpeechProvider.notifier,
      );

      await notifier.speak(
        factId: const FactId(7),
        text: 'Erster',
        languageTag: 'de-DE',
      );
      await notifier.speak(
        factId: const FactId(3),
        text: 'Zweiter',
        languageTag: 'de-DE',
      );

      expect(container.read(factSpeechProvider).factId, const FactId(3));
    });
  });

  group('der Zustand folgt dem Dienst', () {
    test(
      'eine Meldung des Dienstes ändert den Zustand, nicht den Fakt',
      () async {
        final ProviderContainer container = newContainer();
        await container
            .read(factSpeechProvider.notifier)
            .speak(factId: const FactId(7), text: 'Text', languageTag: 'de-DE');

        speech.emit(SpeechState.paused);
        await pumpEventQueue();

        expect(container.read(factSpeechProvider).factId, const FactId(7));
        expect(
          container.read(factSpeechProvider).isPaused(const FactId(7)),
          isTrue,
        );
      },
    );

    test('das Ende des Vortrags lässt den Fakt stehen', () async {
      // **Absichtlich.** Nach dem Ende soll bei diesem Fakt wieder
      // „Abspielen" stehen und nicht bei einem anderen. Ein `null` beim Ende
      // wäre bequem und nähme dem Knopf genau diese Information.
      final ProviderContainer container = newContainer();
      await container
          .read(factSpeechProvider.notifier)
          .speak(factId: const FactId(7), text: 'Text', languageTag: 'de-DE');

      speech.emit(SpeechState.idle);
      await pumpEventQueue();

      expect(container.read(factSpeechProvider).factId, const FactId(7));
      expect(
        container.read(factSpeechProvider).isSpeaking(const FactId(7)),
        isFalse,
      );
    });

    test('dieselbe Meldung zweimal weckt niemanden', () async {
      // Der Grund für die Wertgleichheit an `FactSpeechStatus`. Android
      // schickt beim Anhalten erst `onStop` und dann seine Pause-Meldung;
      // ohne Wertgleichheit wäre jede Wiederholung ein Neuaufbau aller Leser.
      final ProviderContainer container = newContainer();
      container.read(factSpeechProvider);
      int weckrufe = 0;
      container.listen<FactSpeechStatus>(
        factSpeechProvider,
        (_, _) => weckrufe++,
      );

      speech.emit(SpeechState.idle);
      speech.emit(SpeechState.idle);
      await pumpEventQueue();

      expect(weckrufe, 0);
    });
  });

  group('anhalten, fortsetzen, beenden', () {
    test('reichen den Befehl an den Dienst weiter', () async {
      final ProviderContainer container = newContainer();
      final FactSpeechNotifier notifier = container.read(
        factSpeechProvider.notifier,
      );

      await notifier.pause();
      await notifier.resume();
      await notifier.stop();

      expect(speech.commands, <String>['pause', 'resume', 'stop']);
    });

    test('beenden vergisst den Fakt, und nur beenden', () async {
      final ProviderContainer container = newContainer();
      final FactSpeechNotifier notifier = container.read(
        factSpeechProvider.notifier,
      );
      await notifier.speak(
        factId: const FactId(7),
        text: 'Text',
        languageTag: 'de-DE',
      );

      await notifier.pause();
      expect(container.read(factSpeechProvider).factId, const FactId(7));

      await notifier.stop();

      expect(container.read(factSpeechProvider).factId, isNull);
    });
  });

  group('isSpeaking und isPaused', () {
    test('gelten nur für den eigenen Fakt', () async {
      final ProviderContainer container = newContainer();
      await container
          .read(factSpeechProvider.notifier)
          .speak(factId: const FactId(7), text: 'Text', languageTag: 'de-DE');

      final FactSpeechStatus status = container.read(factSpeechProvider);

      expect(status.isSpeaking(const FactId(7)), isTrue);
      expect(status.isSpeaking(const FactId(3)), isFalse);
      expect(status.isPaused(const FactId(7)), isFalse);
    });
  });

  group('Wertgleichheit', () {
    test('gleicher Fakt und gleicher Zustand sind gleich', () {
      expect(
        const FactSpeechStatus(factId: FactId(7), state: SpeechState.paused),
        const FactSpeechStatus(factId: FactId(7), state: SpeechState.paused),
      );
    });

    test('ein anderer Fakt ist ungleich', () {
      expect(
        const FactSpeechStatus(factId: FactId(7)),
        isNot(const FactSpeechStatus(factId: FactId(3))),
      );
    });

    test('toString nennt Fakt und Zustand', () {
      expect(
        const FactSpeechStatus(
          factId: FactId(7),
          state: SpeechState.speaking,
        ).toString(),
        'FactSpeechStatus(FactId(7), speaking)',
      );
    });
  });
}

/// Eine Sprachausgabe, die alles mitschreibt und nichts sagt.
class _FakeSpeechService implements SpeechService {
  final StreamController<SpeechState> _states =
      StreamController<SpeechState>.broadcast();

  /// Jeder Vortrag als `Text|Sprache`.
  final List<String> spoken = <String>[];

  /// Jeder Befehl außer dem Sprechen.
  final List<String> commands = <String>[];

  /// Wenn gesetzt, kehrt [speak] nie zurück.
  bool blockSpeak = false;

  void emit(SpeechState state) => _states.add(state);

  void close() => _states.close();

  @override
  Stream<SpeechState> stateUpdates() => _states.stream;

  @override
  Future<void> speak({
    required String text,
    required String languageTag,
    double rate = defaultSpeechRate,
  }) {
    spoken.add('$text|$languageTag');
    return blockSpeak ? Completer<void>().future : Future<void>.value();
  }

  @override
  Future<void> pause() async => commands.add('pause');

  @override
  Future<void> resume() async => commands.add('resume');

  @override
  Future<void> stop() async => commands.add('stop');
}
