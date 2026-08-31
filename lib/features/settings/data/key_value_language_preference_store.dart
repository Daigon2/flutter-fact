import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';

/// [LanguagePreferenceStore] auf dem Gerätespeicher.
///
/// Liegt bei `settings` und nicht bei `app/localization`, weil der Vertrag es
/// so vorgibt: „Hier lebt nur der Vertrag. Wer wirklich schreibt, entscheidet
/// `features/settings`, denn die Sprach*präferenz* ist eine Einstellung,
/// während das Nachschlagen anwendungsweit ist."
///
/// Schlüsselname wie in der Quelle (`fact_lang`, `storage.jsx:120-121`), als
/// Nachvollziehbarkeit und nicht als gemeinsame Nutzung.
///
/// ## `null` bleibt `null`, und das ist die ganze Schwierigkeit hier
///
/// Der Vertrag hält ausdrücklich fest: `null` heißt „keine Wahl getroffen" und
/// nicht „Deutsch", denn nur so zeigt der Splash beim ersten Start die
/// Sprachauswahl. Diese Umsetzung hat **zwei** Wege zu `null`, und sie sind
/// bewusst nicht unterscheidbar:
///
///  1. Es steht nichts unter dem Schlüssel. Der erste Start.
///  2. Es steht ein Kürzel da, das die App nicht ausliefert, etwa weil eine
///     Sprache wieder entfernt wurde. `AppLanguage.fromCode` gibt dafür `null`
///     zurück, und dieser Rückgabewert wird durchgereicht.
///
/// Der zweite Fall zeigt die Sprachauswahl erneut. Das ist die richtige
/// Reaktion: die gespeicherte Wahl ist nicht mehr erfüllbar, und ein stiller
/// Rückfall auf Deutsch würde jemandem, der Englisch gewählt hatte, ohne
/// Erklärung eine andere Sprache geben.
///
/// Der gespeicherte Wert wird dabei **nicht** gelöscht. Ein Lesezugriff, der
/// schreibt, ist eine Überraschung, und der nächste [writeLanguage] überschreibt
/// ihn ohnehin.
final class KeyValueLanguagePreferenceStore implements LanguagePreferenceStore {
  /// [store] ist der geladene Gerätespeicher aus `bootstrap()`.
  const KeyValueLanguagePreferenceStore(this._store);

  /// Schlüssel im Gerätespeicher, wie in der Quelle.
  static const String storageKey = 'fact_lang';

  final KeyValueStore _store;

  @override
  AppLanguage? readLanguage() {
    final String? code = _store.readString(storageKey);
    if (code == null) {
      return null;
    }
    return AppLanguage.fromCode(code);
  }

  /// Speichert das Kürzel, nicht den Namen des Aufzählungswerts.
  ///
  /// Aus demselben Grund, aus dem `ActiveHunt` die Minuten und nicht den Namen
  /// der Dauer speichert: ein umbenannter Aufzählungswert soll keine
  /// gespeicherte Wahl verwerfen. Das Kürzel ist zusätzlich der Schlüssel der
  /// erzeugten Sprachtabellen und damit ohnehin der stabile Wert.
  @override
  Future<void> writeLanguage(AppLanguage language) =>
      _store.writeString(storageKey, language.code);
}
