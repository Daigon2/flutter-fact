import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/app_strings_supplement.dart';
import 'package:fact_app/app/localization/generated/app_strings_index.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verhalten der handgepflegten Ergänzung (E-39).
///
/// Die Gegenprüfung gegen die PWA gehört bewusst **nicht** hierher, sondern in
/// `tool/generate_i18n.dart`. Ein Test, der die PWA braucht, würde `flutter
/// test` auf jedem Rechner ohne Lese-Repo rot machen, und der Generator ist
/// die Stelle, an der die Quelle ohnehin schon offen liegt.
void main() {
  group('Bestand', () {
    test('jede ausgelieferte Sprache hat eine Ergänzung', () {
      for (final language in AppLanguage.values) {
        expect(
          supplementTextsByLanguage.containsKey(language),
          isTrue,
          reason: 'keine Ergänzung für ${language.code}',
        );
      }
    });

    test('alle Sprachen tragen denselben Schlüsselsatz', () {
      final reference = supplementTextsFor(
        AppLanguage.values.first,
      ).keys.toSet();
      for (final language in AppLanguage.values) {
        expect(
          supplementTextsFor(language).keys.toSet(),
          reference,
          reason: 'Ergänzung von ${language.code} weicht ab',
        );
      }
    });

    test('die Ergänzung trägt genau den einen belegten Schlüssel', () {
      // Wächst diese Menge, gehört jeder neue Eintrag zu einem Text, den die
      // PWA sichtbar anzeigt, ohne ihn als Schlüssel zu führen. Alles andere
      // gehört in die Quelle.
      expect(supplementTextsFor(AppLanguage.de).keys.toSet(), {
        'tour.stepCounter',
      });
    });

    test('kein Ergänzungs-Schlüssel steht in den erzeugten Tabellen', () {
      // Zweite Verteidigungslinie zur Prüfung im Generator: die greift nur,
      // wenn jemand den Generator startet, dieser Test bei jedem `flutter
      // test`. Er sieht allerdings nur den erzeugten Stand, nicht die PWA.
      for (final language in AppLanguage.values) {
        final generated = generatedTextsByLanguage[language.code]!;
        for (final key in supplementTextsFor(language).keys) {
          expect(
            generated.containsKey(key),
            isFalse,
            reason: '"$key" kommt in ${language.code} schon aus der Quelle',
          );
        }
      }
    });

    test('kein Ergänzungs-Wert ist leer', () {
      for (final language in AppLanguage.values) {
        for (final entry in supplementTextsFor(language).entries) {
          expect(entry.value, isNotEmpty, reason: entry.key);
        }
      }
    });
  });

  group('Schrittanzeige des Tutorials', () {
    test('liefert den Wortlaut der Quelle in beiden Sprachen', () {
      // `screen-tour.jsx:483`, hartcodierter Ternär, Großschreibung wie dort.
      expect(
        AppStrings.of(
          AppLanguage.de,
        ).text('tour.stepCounter', params: {'step': '3', 'total': '9'}),
        'SCHRITT 3 VON 9',
      );
      expect(
        AppStrings.of(
          AppLanguage.en,
        ).text('tour.stepCounter', params: {'step': '3', 'total': '9'}),
        'STEP 3 OF 9',
      );
    });

    test('ein vergessener Platzhalter fällt im Debug-Lauf auf', () {
      // Dieselbe Zusicherung wie für erzeugte Texte: `_interpolate` prüft am
      // Ende, dass keine Klammer stehen geblieben ist.
      expect(
        () => AppStrings.of(
          AppLanguage.de,
        ).text('tour.stepCounter', params: {'step': '3'}),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => AppStrings.of(AppLanguage.de).text('tour.stepCounter'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('hasText kennt den Ergänzungs-Schlüssel', () {
      for (final language in AppLanguage.values) {
        expect(AppStrings.of(language).hasText('tour.stepCounter'), isTrue);
      }
    });

    test('textKeys bleibt die reine PWA-Fläche', () {
      // Die Ergänzung darf die Paritätszahlen nicht verschieben, sonst
      // verliert `app_strings_parity_test.dart` seine Aussage.
      expect(
        AppStrings.of(AppLanguage.de).textKeys.contains('tour.stepCounter'),
        isFalse,
      );
    });
  });

  group('Suchreihenfolge', () {
    // An echten Daten nicht nachweisbar: die Ergänzung trägt per Konstruktion
    // nur Schlüssel, die in keiner erzeugten Tabelle stehen. Deshalb hier mit
    // gestellten Tabellen gegen `AppStrings.debugResolve`, also gegen genau
    // die Funktion, die `text()` benutzt.
    const key = 'demo.key';

    test('der erzeugte Wert schlägt den gleichnamigen Ergänzungs-Wert', () {
      expect(
        AppStrings.debugResolve(
          key,
          texts: const {key: 'aus der Quelle'},
          supplement: const {key: 'handgepflegt'},
          fallbackTexts: const {},
          fallbackSupplement: const {},
        ),
        'aus der Quelle',
      );
    });

    test(
      'die Ergänzung der gewählten Sprache kommt vor der Fallback-Sprache',
      () {
        expect(
          AppStrings.debugResolve(
            key,
            texts: const {},
            supplement: const {key: 'gewählte Sprache, handgepflegt'},
            fallbackTexts: const {key: 'Fallback, erzeugt'},
            fallbackSupplement: const {key: 'Fallback, handgepflegt'},
          ),
          'gewählte Sprache, handgepflegt',
        );
      },
    );

    test('die Fallback-Ergänzung ist die letzte Station', () {
      expect(
        AppStrings.debugResolve(
          key,
          texts: const {},
          supplement: const {},
          fallbackTexts: const {},
          fallbackSupplement: const {key: 'Fallback, handgepflegt'},
        ),
        'Fallback, handgepflegt',
      );
    });

    test('ohne Treffer bleibt es null, und darauf schlägt der assert an', () {
      expect(
        AppStrings.debugResolve(
          key,
          texts: const {},
          supplement: const {},
          fallbackTexts: const {},
          fallbackSupplement: const {},
        ),
        isNull,
      );
      expect(
        () => AppStrings.of(AppLanguage.de).text('gibt.es.wirklich.nicht'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
