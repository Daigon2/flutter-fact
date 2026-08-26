import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verhalten der Sprach-Provider. Persistenz wird über den Vertrag
/// eingesetzt, nicht über eine echte Speichertechnik.
void main() {
  group('appLanguageProvider', () {
    test('startet in der Sprache aus der PWA-Konfiguration', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appLanguageProvider), AppLanguage.de);
    });

    test('übernimmt eine bereits gespeicherte Wahl', () {
      final container = ProviderContainer(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(AppLanguage.en),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(appLanguageProvider), AppLanguage.en);
    });

    test(
      'select wechselt die Sprache und schreibt sie in den Speicher',
      () async {
        final store = InMemoryLanguagePreferenceStore();
        final container = ProviderContainer(
          overrides: [languagePreferenceStoreProvider.overrideWithValue(store)],
        );
        addTearDown(container.dispose);

        await container
            .read(appLanguageProvider.notifier)
            .select(AppLanguage.en);

        expect(container.read(appLanguageProvider), AppLanguage.en);
        expect(store.readLanguage(), AppLanguage.en);
      },
    );

    test('select auf die aktive Sprache schreibt nichts', () async {
      final store = InMemoryLanguagePreferenceStore();
      final container = ProviderContainer(
        overrides: [languagePreferenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container.read(appLanguageProvider.notifier).select(AppLanguage.de);

      expect(container.read(appLanguageProvider), AppLanguage.de);
      expect(
        store.readLanguage(),
        isNull,
        reason:
            'Ohne echte Änderung soll keine Wahl entstehen, sonst zeigt der '
            'Splash die Sprachauswahl beim ersten Start nicht mehr.',
      );
    });

    test('lässt sich für einen Test direkt überschreiben', () {
      final container = ProviderContainer(
        overrides: [appLanguageProvider.overrideWith(() => _FixedEnglish())],
      );
      addTearDown(container.dispose);

      expect(container.read(appLanguageProvider), AppLanguage.en);
      expect(container.read(appStringsProvider).text('tab.map'), 'Map');
    });
  });

  group('appStringsProvider', () {
    test('folgt der aktiven Sprache', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appStringsProvider).text('tab.map'), 'Karte');

      await container.read(appLanguageProvider.notifier).select(AppLanguage.en);

      expect(container.read(appStringsProvider).text('tab.map'), 'Map');
    });
  });

  group('InMemoryLanguagePreferenceStore', () {
    test('ohne Wahl liefert null, nicht die Standardsprache', () {
      expect(InMemoryLanguagePreferenceStore().readLanguage(), isNull);
    });

    test('gibt zurück, was geschrieben wurde', () async {
      final store = InMemoryLanguagePreferenceStore();

      await store.writeLanguage(AppLanguage.en);

      expect(store.readLanguage(), AppLanguage.en);
    });
  });
}

class _FixedEnglish extends AppLanguageNotifier {
  @override
  AppLanguage build() => AppLanguage.en;
}
