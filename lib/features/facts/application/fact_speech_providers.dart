/// Wer gerade vorgelesen wird, und in welchem Zustand. Schritt 25.
///
/// ## Warum in `application/` und nicht in `presentation/notifiers/`
///
/// Aus demselben Grund wie `fact_providers.dart` und
/// `collected_facts_providers.dart` daneben: der zweite Verbraucher steht
/// schon fest. Die Fakt-Akte hängt ab Schritt 25 daran, die Karte ab
/// Schritt 26, und Regel 8 verbietet jedem Feature den Import aus dem
/// `presentation` eines anderen.
///
/// ## Warum der Fakt hier steht und nicht im Dienst
///
/// `SpeechService` spricht Text und kennt keinen Fakt, mit ausführlicher
/// Begründung an seinem Vertrag. Gebraucht wird die Zuordnung trotzdem: der
/// Kopfhörer-Knopf in der Akte muss wissen, ob **dieser** Fakt gerade läuft
/// oder ein anderer. Genau diese Naht ist der Ort dafür.
///
/// **Die Quelle legt es in den Dienst und bezahlt dafür.** Ihr `AudioPlayer`
/// hält `currentFact` selbst, und weil drei ihrer Aufrufer keinen Fakt haben,
/// schieben sie `{ titel: '' }` hinein; der Kommentar an einer vierten Stelle
/// nennt die Folge: „passing { titel: '' } made MiniPlayer pop up with an
/// empty title for every beacon" (`02_Frontend/app/audio-player.jsx:347-348`).
library;

import 'dart:async';

import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/services/speech/speech_providers.dart';
import 'package:fact_app/services/speech/speech_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Das BCP-47-Kennzeichen für [languageCode].
///
/// Gemessen in der Quelle: `lang === 'en' ? 'en-US' : 'de-DE'`
/// (`audio-player.jsx:262`). **Der Rückfall ist Deutsch**, wie dort, und das
/// ist kein Zufall: `AppLanguage.fallback` ist ebenfalls Deutsch, und eine
/// Sprachausgabe, die für eine unbekannte Sprache schweigt, wäre schlechter
/// als eine, die deutsch vorliest.
///
/// **Eine Funktion auf dem Sprachcode und keine auf `AppLanguage`.** Damit
/// bleibt diese Datei frei von `lib/app/`, und der Aufrufer gibt
/// `language.code` mit. Die Zuordnung gehört nicht in
/// `lib/services/speech/`, weil sie eine Entscheidung dieser App ist und
/// keine der Sprachausgabe.
String speechLanguageTagFor(String languageCode) =>
    languageCode == 'en' ? 'en-US' : 'de-DE';

/// Welcher Fakt vorgelesen wird, und wie weit.
final class FactSpeechStatus {
  /// Erzeugt einen Zustand.
  const FactSpeechStatus({this.factId, this.state = SpeechState.idle});

  /// Der Fakt, um den es geht, oder `null`, wenn noch keiner gelaufen ist.
  ///
  /// **Bleibt stehen, wenn der Vortrag endet.** Ein `null` beim Ende wäre
  /// bequem, nähme dem Knopf aber die Information, die er braucht: nach dem
  /// Ende soll bei diesem Fakt wieder „Abspielen" stehen, und nicht bei
  /// einem anderen. Geleert wird es nur durch [FactSpeechNotifier.stop].
  final FactId? factId;

  /// Was die Sprachausgabe tut.
  final SpeechState state;

  /// Ob [candidate] gerade gesprochen wird.
  bool isSpeaking(FactId candidate) =>
      factId == candidate && state == SpeechState.speaking;

  /// Ob [candidate] angehalten ist.
  bool isPaused(FactId candidate) =>
      factId == candidate && state == SpeechState.paused;

  /// Eine Kopie mit geändertem Zustand.
  FactSpeechStatus withState(SpeechState next) =>
      FactSpeechStatus(factId: factId, state: next);

  /// **Wertgleichheit, und die ist hier nötig.** Ohne sie vergleicht Riverpods
  /// `defaultUpdateShouldNotify` zwei Instanzen mit `!=` und weckt jeden
  /// Leser, sobald der Dienst denselben Zustand ein zweites Mal meldet. Genau
  /// das passiert: Android schickt beim Anhalten erst `onStop` und dann seine
  /// Pause-Meldung.
  @override
  bool operator ==(Object other) =>
      other is FactSpeechStatus &&
      other.factId == factId &&
      other.state == state;

  @override
  int get hashCode => Object.hash(factId, state);

  @override
  String toString() => 'FactSpeechStatus($factId, ${state.name})';
}

/// Wer vorgelesen wird.
final factSpeechProvider =
    NotifierProvider<FactSpeechNotifier, FactSpeechStatus>(
      FactSpeechNotifier.new,
    );

/// Besitzer der Zuordnung „welcher Fakt läuft".
class FactSpeechNotifier extends Notifier<FactSpeechStatus> {
  @override
  FactSpeechStatus build() {
    final StreamSubscription<SpeechState> subscription = ref
        .watch(speechServiceProvider)
        .stateUpdates()
        .listen(_apply);
    ref.onDispose(subscription.cancel);
    return const FactSpeechStatus();
  }

  /// Liest [text] für [factId] vor.
  ///
  /// **Der Fakt wird vor dem Sprechen gesetzt**, nicht danach. Die
  /// Zustandsmeldung `speaking` kommt aus dem Plattformkanal und damit später;
  /// wäre der Fakt erst danach gesetzt, zeigte der Knopf für einen Wimpernschlag
  /// den falschen. Dieselbe Reihenfolge wie in der Quelle, die `currentFact`
  /// als erstes setzt (`audio-player.jsx:222`).
  Future<void> speak({
    required FactId factId,
    required String text,
    required String languageTag,
  }) async {
    state = FactSpeechStatus(factId: factId, state: SpeechState.speaking);
    await ref
        .read(speechServiceProvider)
        .speak(text: text, languageTag: languageTag);
  }

  /// Hält den laufenden Vortrag an.
  Future<void> pause() => ref.read(speechServiceProvider).pause();

  /// Setzt den angehaltenen Vortrag fort.
  Future<void> resume() => ref.read(speechServiceProvider).resume();

  /// Beendet den Vortrag und vergisst den Fakt.
  ///
  /// Der einzige Weg, auf dem [FactSpeechStatus.factId] wieder `null` wird,
  /// siehe die Begründung dort.
  Future<void> stop() async {
    state = const FactSpeechStatus();
    await ref.read(speechServiceProvider).stop();
  }

  /// Nimmt eine Zustandsmeldung des Dienstes an.
  ///
  /// Die Prüfung auf `ref.mounted` ist dieselbe wie in
  /// `UserLocationNotifier._apply` und aus demselben Grund: der Strom kommt
  /// von außen, und eine schon eingereihte Ausgabe nach dem Entsorgen ließe
  /// `state =` mit „Cannot use the Ref ... after it has been disposed" werfen.
  void _apply(SpeechState next) {
    if (!ref.mounted) {
      return;
    }
    state = state.withState(next);
  }
}
