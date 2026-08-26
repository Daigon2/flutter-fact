import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod-Komposition der Lokalisierung. Riverpod ist der einzige
/// DI-Mechanismus (ADR-005), die Provider sind handgeschrieben, weil
/// `riverpod_generator` derzeit nicht mit `go_router_builder` auflösbar ist
/// (ADR-003).

/// Speicher der Sprachwahl.
///
/// Der Standard ist flüchtig. `features/settings` überschreibt diesen Provider
/// später mit einer persistenten Implementierung, ohne dass ein Aufrufer
/// angefasst werden muss.
final languagePreferenceStoreProvider = Provider<LanguagePreferenceStore>(
  (ref) => InMemoryLanguagePreferenceStore(),
);

/// Aktive Sprache der Oberfläche.
final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);

/// Besitzer der aktiven Sprache.
///
/// Der Zustand ist ein einzelner unveränderlicher Wert, kein
/// `ChangeNotifier` (ADR-003).
class AppLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final store = ref.watch(languagePreferenceStoreProvider);
    return store.readLanguage() ?? AppLanguage.initial;
  }

  /// Übernimmt [language] und speichert sie danach.
  ///
  /// Die Oberfläche folgt sofort. Ein fehlgeschlagener Schreibvorgang soll die
  /// Sprachwahl der laufenden Sitzung nicht zurücknehmen, weil der Nutzer
  /// sonst mitten in der Bedienung die Sprache wechseln sieht.
  Future<void> select(AppLanguage language) async {
    if (language == state) {
      return;
    }
    state = language;
    await ref.read(languagePreferenceStoreProvider).writeLanguage(language);
  }
}

/// Texte der aktiven Sprache.
///
/// Widgets lesen ausschließlich hierüber, damit ein Sprachwechsel überall
/// gleichzeitig greift.
final appStringsProvider = Provider<AppStrings>(
  (ref) => AppStrings.of(ref.watch(appLanguageProvider)),
);
