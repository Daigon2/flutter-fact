import 'package:fact_app/features/settings/domain/audio_mode_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod-Komposition der Audio-Guide-Präferenz (ADR-005: Riverpod ist der
/// einzige DI-Mechanismus). Handgeschriebene Provider, weil `riverpod_generator`
/// mit diesem Abhängigkeitsstand nicht neben `go_router_builder` auflösbar ist
/// (ADR-003).
///
/// ## Warum das hier in `application/` liegt, seit dem 02.09.2026
///
/// Zwei Regeln zusammen lassen keinen anderen Ort zu.
///
/// `tool/check_architecture.dart` verbietet `presentation` jeden Import aus
/// `data`, auch aus dem eigenen Feature. Der Dialog muss die Präferenz aber
/// selbst setzen, also braucht er einen Zugang, der nicht durch `data` führt.
/// Deshalb stand diese Datei bis zum 02.09.2026 in
/// `presentation/notifiers/`, mit dem Verweis auf
/// `docs/architecture/project-structure.md` („Feature UI providers live in
/// `presentation`").
///
/// **Mit Schritt 25 hat der Audio-Modus seinen ersten Verbraucher bekommen,
/// und der sitzt in einem anderen Feature.** Die Fakt-Akte liest ihn, um zu
/// entscheiden, ob sie beim Öffnen von selbst vorliest, und Regel 8 verbietet
/// jedem Feature den Import aus dem `presentation` eines fremden. Der Vertrag
/// in `features/settings/domain/` kann den Provider nicht tragen, weil eine
/// Domäne Riverpod nicht kennen darf (Regel 2). Bleibt `application/`, und
/// Regel 10 nennt genau das als erlaubten Weg über die Feature-Grenze.
///
/// Derselbe Zwang und dieselbe Auflösung wie bei
/// `features/facts/application/fact_providers.dart`, dort ausführlich. Der
/// Umzug ist eine Verschiebung ohne Verhaltensänderung; der Vertrag steht
/// weiter in der Domäne, hier steht nur die Verdrahtung.
///
/// Die persistente Umsetzung liegt seit dem 31.08.2026 in
/// `features/settings/data/` und wird per `overrideWithValue` aus
/// `bootstrap()` gebunden.

/// Speicher der Audio-Guide-Präferenz.
///
/// Der Standard ist flüchtig, siehe [InMemoryAudioModeStore].
final audioModeStoreProvider = Provider<AudioModeStore>(
  (ref) => InMemoryAudioModeStore(),
);

/// Ob der Audio-Guide eingeschaltet ist.
///
/// **Seit Schritt 25 hat dieser Wert einen Leser**, und das war lange nicht
/// so: hier stand „heute liest diesen Wert niemand außer den Tests". Die
/// Fakt-Akte fragt ihn beim Öffnen und liest den Fakt von selbst vor, wenn er
/// gesetzt ist. Der Zustand liegt hier und nicht im Dialog: eine Präferenz,
/// die im Widget lebt, verschwindet mit dem Widget.
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
