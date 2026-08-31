import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/settings/domain/audio_mode_store.dart';

/// [AudioModeStore] auf dem Gerätespeicher.
///
/// Löst die Lücke, die [InMemoryAudioModeStore] in ihrer Dokumentation benennt:
/// „der Audio-Modus ist bei jedem Start aus".
///
/// Schlüsselname wie in der Quelle (`fact_audio_mode`, `storage.jsx:161-166`),
/// als Nachvollziehbarkeit und nicht als gemeinsame Nutzung.
///
/// **Was hier weiterhin fehlt, und zwar absichtlich:** `fact_audio_help_shown`,
/// `fact_audio_rate`, `fact_audio_voice` und `fact_headphone_mode`. Der Vertrag
/// begründet das je einzeln. Persistenz zu haben ist kein Grund, Schlüssel auf
/// Vorrat anzulegen: ein gespeicherter Wert ohne Leser ist ein zweiter Ort, der
/// falsch sein kann.
final class KeyValueAudioModeStore implements AudioModeStore {
  /// [store] ist der geladene Gerätespeicher aus `bootstrap()`.
  const KeyValueAudioModeStore(this._store);

  /// Schlüssel im Gerätespeicher, wie in der Quelle.
  static const String storageKey = 'fact_audio_mode';

  final KeyValueStore _store;

  @override
  bool isEnabled() => _store.readBool(storageKey) ?? false;

  /// Schreibt [enabled] und ist damit anders als die beiden Einbahn-Schalter
  /// ein echter Umschalter, wie der Vertrag verlangt.
  @override
  Future<void> setEnabled(bool enabled) =>
      _store.writeBool(storageKey, enabled);
}
