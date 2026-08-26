import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verhalten des Nachschlagens: Sprachwahl, Fallback, fehlender Schlüssel,
/// Platzhalter. Die Werte selbst prüft `app_strings_parity_test.dart`.
void main() {
  group('text', () {
    test('liefert den Wert der gewählten Sprache', () {
      expect(AppStrings.of(AppLanguage.de).text('tab.map'), 'Karte');
      expect(AppStrings.of(AppLanguage.en).text('tab.map'), 'Map');
    });

    test('ein unbekannter Schlüssel fällt im Debug-Lauf auf', () {
      // In Produktion darf ein fehlender Schlüssel die App nicht zerlegen, im
      // Test muss er auffallen. Deshalb `assert`: hier fliegt der Fehler, im
      // Release-Build erscheint der Schlüssel als Text.
      expect(
        () => AppStrings.of(AppLanguage.de).text('gibt.es.nicht'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('hasText trennt bekannt von unbekannt, ohne zu scheitern', () {
      final strings = AppStrings.of(AppLanguage.en);
      expect(strings.hasText('tab.map'), isTrue);
      expect(strings.hasText('gibt.es.nicht'), isFalse);
    });

    test('language nennt die gewählte Sprache', () {
      expect(AppStrings.of(AppLanguage.en).language, AppLanguage.en);
    });
  });

  group('Platzhalter', () {
    test('ersetzt die Form {name} wie window.t in der PWA', () {
      final en = AppStrings.of(AppLanguage.en);

      expect(en.text('signup.cityFactsCount', params: {'n': '42'}), '42 facts');
    });

    test('ersetzt mehrere Platzhalter in einem Text', () {
      final de = AppStrings.of(AppLanguage.de);

      expect(
        de.text(
          'audio.position.prompt',
          params: {
            'titel': 'Frauenkirche',
            'distance': '120',
            'direction': 'Südwesten',
          },
        ),
        'Frauenkirche, 120 Meter, Südwesten.',
      );
    });

    test('ein leerer Wert ist erlaubt, die PWA nutzt das für {plural}', () {
      final de = AppStrings.of(AppLanguage.de);

      final singular = de.text(
        'map.factsWithin1km',
        params: {'n': '1', 'plural': ''},
      );
      final plural = de.text(
        'map.factsWithin1km',
        params: {'n': '3', 'plural': 'en'},
      );

      expect(singular, isNot(contains('{')));
      expect(plural, isNot(contains('{')));
      expect(singular, isNot(plural));
    });

    test('ein vergessener Platzhalter fällt im Debug-Lauf auf', () {
      expect(
        () => AppStrings.of(AppLanguage.en).text('signup.cityFactsCount'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('ein falsch benannter Platzhalter fällt im Debug-Lauf auf', () {
      expect(
        () => AppStrings.of(
          AppLanguage.en,
        ).text('signup.cityFactsCount', params: {'count': '42'}),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('textList', () {
    test('liefert die Liste der gewählten Sprache', () {
      expect(
        AppStrings.of(AppLanguage.en).textList('creator.steps'),
        hasLength(4),
      );
    });

    test('die Liste ist nicht veränderbar', () {
      final steps = AppStrings.of(AppLanguage.de).textList('creator.steps');

      expect(() => steps.add('extra'), throwsUnsupportedError);
    });

    test('ein unbekannter Listen-Schlüssel fällt im Debug-Lauf auf', () {
      expect(
        () => AppStrings.of(AppLanguage.de).textList('tab.map'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Gleichheit', () {
    test('gleiche Sprache ergibt gleiche Texte', () {
      expect(AppStrings.of(AppLanguage.de), AppStrings.of(AppLanguage.de));
      expect(
        AppStrings.of(AppLanguage.de),
        isNot(AppStrings.of(AppLanguage.en)),
      );
    });
  });

  group('AppLanguage', () {
    test('fromCode kennt nur ausgelieferte Sprachen', () {
      expect(AppLanguage.fromCode('de'), AppLanguage.de);
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('it'), isNull);
      expect(AppLanguage.fromCode('DE'), isNull);
    });

    test('isoLabel liefert das Badge-Kürzel', () {
      expect(AppLanguage.de.isoLabel, 'DE');
      expect(AppLanguage.en.isoLabel, 'EN');
    });
  });
}
