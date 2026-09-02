import 'package:fact_app/app/localization/app_language.dart';

/// Vertrag für die gespeicherte Sprachwahl des Nutzers.
///
/// Hier lebt nur der Vertrag. Wer wirklich schreibt, entscheidet
/// `features/settings`: seit dem 31.08.2026 ist das
/// `KeyValueLanguagePreferenceStore` in `features/settings/data`, denn die
/// Sprach*präferenz* ist eine Einstellung, während das Nachschlagen
/// anwendungsweit ist. An dieser Schnittstelle hängt weiterhin keine
/// Speichertechnik: die Umsetzung kennt `KeyValueStore` aus `core`, und das
/// Vendor-Paket kennt nur `lib/services/preferences/` (Regel 22).
///
/// `readLanguage` ist absichtlich synchron. `bootstrap()` lädt die Präferenz
/// vor dem ersten Frame und überschreibt den Provider mit einer gefüllten
/// Implementierung. Ein asynchroner Lesezugriff würde jeden Textaufruf in
/// `AsyncValue` zwingen, obwohl die Sprache beim ersten Frame längst feststeht.
abstract interface class LanguagePreferenceStore {
  /// Gespeicherte Sprache oder `null`, wenn noch nie gewählt wurde.
  ///
  /// `null` bedeutet ausdrücklich "keine Wahl getroffen" und nicht "Deutsch".
  /// Nur so kann der Splash die Sprachauswahl beim ersten Start zeigen.
  AppLanguage? readLanguage();

  /// Speichert die Wahl dauerhaft.
  Future<void> writeLanguage(AppLanguage language);
}

/// Flüchtiger Speicher, Vorgabe für Tests.
///
/// Die Wahl überlebt den Neustart nicht. **Bis zum 31.08.2026 war das auch der
/// Zustand der laufenden App**, seither überschreibt `bootstrap()` diesen
/// Provider mit `KeyValueLanguagePreferenceStore`. Hier bleibt er, weil ein
/// Test keinen Gerätespeicher braucht und weil ein flüchtiger Standard
/// leichter zu erkennen ist als eine halbe Persistenz.
class InMemoryLanguagePreferenceStore implements LanguagePreferenceStore {
  /// [initial] setzt eine bereits getroffene Wahl, etwa in einem Test.
  InMemoryLanguagePreferenceStore([AppLanguage? initial]) : _language = initial;

  AppLanguage? _language;

  @override
  AppLanguage? readLanguage() => _language;

  @override
  Future<void> writeLanguage(AppLanguage language) async {
    _language = language;
  }
}
