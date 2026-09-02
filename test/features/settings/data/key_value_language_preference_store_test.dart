import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/settings/data/key_value_language_preference_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die persistente Sprachwahl.
void main() {
  test('ohne gespeicherte Wahl bleibt es null', () {
    // **Der wichtigste Test dieser Datei.** `null` heißt „noch nie gewählt",
    // und nur so zeigt der Splash beim ersten Start die Sprachauswahl. Eine
    // Umsetzung, die hier hilfsbereit `AppLanguage.de` liefert, nimmt jedem
    // neuen Nutzer die Wahl weg, ohne dass irgendetwas abstürzt.
    expect(
      KeyValueLanguagePreferenceStore(InMemoryKeyValueStore()).readLanguage(),
      isNull,
    );
  });

  test('eine gespeicherte Wahl wird gelesen', () {
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueLanguagePreferenceStore.storageKey: 'en',
    });

    expect(
      KeyValueLanguagePreferenceStore(preferences).readLanguage(),
      AppLanguage.en,
    );
  });

  test('auch die andere ausgelieferte Sprache wird gelesen', () {
    // Die Gegenprobe: ohne sie käme eine Umsetzung durch, die jedes vorhandene
    // Kürzel auf Englisch abbildet.
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueLanguagePreferenceStore.storageKey: 'de',
    });

    expect(
      KeyValueLanguagePreferenceStore(preferences).readLanguage(),
      AppLanguage.de,
    );
  });

  test('ein unbekanntes Kürzel gilt als keine Wahl', () {
    // Der Fall entsteht, wenn eine Sprache wieder aus der App genommen wird.
    // Die Sprachauswahl erscheint dann erneut, und das ist die richtige
    // Reaktion: ein stiller Rückfall auf Deutsch gäbe jemandem ohne Erklärung
    // eine andere Sprache.
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueLanguagePreferenceStore.storageKey: 'it',
    });

    expect(KeyValueLanguagePreferenceStore(preferences).readLanguage(), isNull);
  });

  test('ein unbekanntes Kürzel wird beim Lesen nicht gelöscht', () {
    // Ein Lesezugriff, der schreibt, ist eine Überraschung. Zudem wäre der
    // Wert die einzige Spur davon, was jemand einmal gewählt hat.
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueLanguagePreferenceStore.storageKey: 'it',
    });

    KeyValueLanguagePreferenceStore(preferences).readLanguage();

    expect(preferences.readString('fact_lang'), 'it');
  });

  test(
    'writeLanguage schreibt das Kürzel unter den Schlüssel der Quelle',
    () async {
      // Das Kürzel und nicht der Name des Aufzählungswerts. Sie sind heute für
      // beide Sprachen gleich, und genau deshalb steht die Aussage hier: sie
      // fällt erst bei einer Sprache wie `pt-BR` an, und dann ist der Fehler
      // teuer, weil ein umbenannter Wert jede gespeicherte Wahl verwerfen würde.
      final KeyValueStore preferences = InMemoryKeyValueStore();

      await KeyValueLanguagePreferenceStore(
        preferences,
      ).writeLanguage(AppLanguage.en);

      expect(preferences.readString('fact_lang'), 'en');
    },
  );

  test('eine zweite Wahl ersetzt die erste', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();
    final KeyValueLanguagePreferenceStore store =
        KeyValueLanguagePreferenceStore(preferences);

    await store.writeLanguage(AppLanguage.en);
    await store.writeLanguage(AppLanguage.de);

    expect(store.readLanguage(), AppLanguage.de);
  });
}
