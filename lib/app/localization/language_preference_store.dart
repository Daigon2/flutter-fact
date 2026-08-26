import 'package:fact_app/app/localization/app_language.dart';

/// Vertrag für die gespeicherte Sprachwahl des Nutzers.
///
/// Hier lebt nur der Vertrag. Wer wirklich schreibt, entscheidet
/// `features/settings`, denn die Sprach*präferenz* ist eine Einstellung,
/// während das Nachschlagen anwendungsweit ist. `shared_preferences` ist im
/// Projekt bewusst nicht installiert, an dieser Schnittstelle hängt also keine
/// Speichertechnik.
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

/// Flüchtiger Standard, solange `features/settings` nichts persistiert, und
/// Vorgabe für Tests.
///
/// Die Wahl überlebt den Neustart nicht. Das ist hier gewollt: eine halbe
/// Persistenz wäre schwerer zu erkennen als gar keine.
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
