import 'package:fact_app/features/settings/domain/audio_mode_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod-Komposition der Audio-Guide-Präferenz (ADR-005: Riverpod ist der
/// einzige DI-Mechanismus). Handgeschriebene Provider, weil `riverpod_generator`
/// mit diesem Abhängigkeitsstand nicht neben `go_router_builder` auflösbar ist
/// (ADR-003).
///
/// ## Warum das hier in `presentation/notifiers/` liegt und nicht in `data/`
///
/// `tool/check_architecture.dart` verbietet `presentation` jeden Import aus
/// `data`, auch aus dem eigenen Feature. Der Dialog muss die Präferenz aber
/// selbst setzen, also braucht er einen Zugang, der nicht durch `data` führt.
/// `docs/architecture/project-structure.md` deckt das ab: "Feature UI providers
/// live in `presentation`". Der Vertrag steht in der Domäne, hier steht nur die
/// Verdrahtung.
///
/// Sobald echte Persistenz kommt, zieht die persistente Implementierung nach
/// `features/settings/data/` und wird per `overrideWithValue` aus `bootstrap()`
/// gebunden. An dieser Datei ändert sich dabei nichts.

/// Speicher der Audio-Guide-Präferenz.
///
/// Der Standard ist flüchtig, siehe [InMemoryAudioModeStore].
final audioModeStoreProvider = Provider<AudioModeStore>(
  (ref) => InMemoryAudioModeStore(),
);

/// Ob der Audio-Guide eingeschaltet ist.
///
/// Heute liest diesen Wert **niemand** außer den Tests. Es gibt noch keine
/// Wiedergabe und keine Sprachausgabe, die darauf reagieren könnte, siehe
/// [AudioModeStore]. Der Zustand existiert trotzdem hier und nicht im Dialog:
/// eine Präferenz, die im Widget lebt, verschwindet mit dem Widget.
final audioModeProvider = NotifierProvider<AudioModeNotifier, bool>(
  AudioModeNotifier.new,
);

/// Besitzer der Audio-Guide-Präferenz.
///
/// Der Zustand ist ein einzelner unveränderlicher Wert, kein `ChangeNotifier`
/// (ADR-003).
class AudioModeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(audioModeStoreProvider).isEnabled();

  /// Schaltet den Audio-Guide ein und speichert das danach.
  ///
  /// Die Oberfläche folgt sofort, der Schreibvorgang läuft hinterher. Ein
  /// fehlgeschlagenes Speichern soll die gerade getroffene Entscheidung nicht
  /// zurücknehmen.
  ///
  /// **Kein `if (state) return` wie in `FirstLaunchNotifier.markLaunched`.**
  /// Dort verhindert die Abkürzung ein überflüssiges `router.refresh()`, hier
  /// hängt keine Weiche am Wert. Und sie hätte einen Preis: liefe das
  /// Speichern einmal ins Leere, wäre der Zustand `true`, der Speicher `false`,
  /// und ein zweiter Versuch käme nie beim Speicher an. Ein Rebuild droht
  /// dadurch nicht: Riverpods `defaultUpdateShouldNotify` vergleicht mit `!=`
  /// (`riverpod-3.4.2/lib/src/core/element.dart:372-374`), `true` auf `true`
  /// benachrichtigt also niemanden. Per Test zugesichert.
  ///
  /// Es gibt hier absichtlich kein `disable()`. Der Ausschalter sitzt laut
  /// `audio.dialog.body` im Profil und entsteht mit dem
  /// Einstellungs-Bildschirm; der Vertrag kann es längst, siehe
  /// [AudioModeStore.setEnabled].
  Future<void> enable() async {
    state = true;
    await ref.read(audioModeStoreProvider).setEnabled(true);
  }
}
