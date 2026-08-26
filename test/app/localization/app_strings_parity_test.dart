import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/generated/app_strings_index.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nagelt die erzeugten Sprachtabellen auf die PWA-Quelle fest.
///
/// Quelle sind `02_Frontend/app/translations.jsx` und
/// `02_Frontend/app/audio-strings.jsx`, erzeugt von
/// `tool/generate_i18n.dart`. Wer hier einen Wert ändert, muss diesen Test
/// anfassen und begründet damit die Abweichung von der Verhaltensquelle.
void main() {
  final de = AppStrings.of(AppLanguage.de);
  final en = AppStrings.of(AppLanguage.en);

  group('Vollständigkeit', () {
    test('beide Sprachen haben denselben Schlüsselsatz', () {
      final deKeys = de.textKeys.toSet();
      final enKeys = en.textKeys.toSet();

      expect(deKeys.difference(enKeys), isEmpty, reason: 'nur in DE vorhanden');
      expect(enKeys.difference(deKeys), isEmpty, reason: 'nur in EN vorhanden');
    });

    test('Schlüsselzahl entspricht dem Stand der PWA-Quelle', () {
      // Stand 26.08.2026: 714 Texte plus 2 Listen, also 716 Schlüssel je
      // Sprache. Die Zahl bewegt sich nur, wenn die PWA Schlüssel bekommt oder
      // verliert. Dann ist der Generator gelaufen und diese Zahl wird bewusst
      // mitgezogen.
      expect(de.textKeys.length, 714);
      expect(en.textKeys.length, 714);
      expect(de.textListKeys.length, 2);
      expect(en.textListKeys.length, 2);
    });

    test('Listen-Schlüssel sind in beiden Sprachen dieselben', () {
      expect(de.textListKeys.toSet(), en.textListKeys.toSet());
      expect(de.textListKeys.toSet(), {'creator.steps', 'profil.levelTitles'});
    });

    test('kein Wert ist leer', () {
      for (final language in AppLanguage.values) {
        final table = generatedTextsByLanguage[language.code]!;
        final empty = table.entries
            .where((e) => e.value.isEmpty)
            .map((e) => e.key)
            .toList();
        expect(empty, isEmpty, reason: 'leere Werte in ${language.code}');
      }
    });

    test('AppLanguage deckt genau die erzeugten Sprachen ab', () {
      expect(
        AppLanguage.values.map((l) => l.code).toList(),
        generatedLanguageCodes,
      );
      expect(AppLanguage.initial, AppLanguage.de);
      expect(AppLanguage.fallback, AppLanguage.de);
    });
  });

  group('Platzhalter', () {
    final placeholder = RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}');

    test('jeder Platzhalter der Quelle lässt sich auflösen', () {
      // Läuft über alle 714 Schlüssel. Bleibt eine Klammer stehen, passt der
      // Platzhalter-Namensraum nicht zu dem, was `text()` ersetzt.
      for (final key in de.textKeys) {
        final resolved = de.text(key, params: _dummyParams(key, de));
        expect(
          placeholder.allMatches(resolved).map((m) => m.group(0)!).toSet(),
          isEmpty,
          reason: 'Interpolation von "$key" in DE',
        );
      }
    });

    test('DE und EN erwarten dieselben Platzhalter', () {
      final mismatches = <String>[];
      for (final key in de.textKeys) {
        final deRaw = generatedTextsByLanguage['de']![key]!;
        final enRaw = generatedTextsByLanguage['en']![key]!;
        final deNames = placeholder
            .allMatches(deRaw)
            .map((m) => m.group(0)!)
            .toSet();
        final enNames = placeholder
            .allMatches(enRaw)
            .map((m) => m.group(0)!)
            .toSet();
        if (deNames.length != enNames.length || !deNames.containsAll(enNames)) {
          mismatches.add('$key: DE $deNames, EN $enNames');
        }
      }
      expect(mismatches, isEmpty);
    });

    test('die App-Form ist geschweifte Klammer plus Name', () {
      // Gegenprobe gegen weitere Interpolationsformen. `{{n}}` und `%s` kommen
      // in der Quelle nicht vor, `text()` unterstützt sie deshalb nicht.
      for (final language in AppLanguage.values) {
        for (final value in generatedTextsByLanguage[language.code]!.values) {
          expect(value.contains('{{'), isFalse, reason: value);
          expect(value.contains('%s'), isFalse, reason: value);
        }
      }
    });

    test('nur zwei Altlasten nutzen die printf-Form %d', () {
      // Befund an der Quelle, nicht an dieser App: `screen-challenge.jsx:3506`
      // und `:3602` interpolieren positionsweise mit
      // `.replace('%d', a).replace('%d', b)`, während der Rest der PWA
      // `{name}` nutzt. `text()` löst `%d` bewusst nicht auf, weil eine zweite
      // Interpolationsform eine Entscheidung wäre und die Quelle die bessere
      // Stelle für die Korrektur ist.
      //
      // Wer den Gruppenmodus portiert, formatiert diese zwei Texte am
      // Aufrufort oder lässt die Schlüssel in der PWA auf `{name}` umstellen.
      final affected = <String>{};
      for (final language in AppLanguage.values) {
        generatedTextsByLanguage[language.code]!.forEach((key, value) {
          if (value.contains('%d')) {
            affected.add(key);
          }
        });
      }

      expect(affected, {'group.active.counter', 'group.results.summary'});
    });

    test('bekannte Platzhalter sind vorhanden', () {
      expect(
        generatedTextsByLanguage['en']!['signup.cityFactsCount'],
        '{n} facts',
      );
      expect(
        generatedTextsByLanguage['de']!['audio.beacon.prompt'],
        contains('{distance}'),
      );
    });
  });

  group('Schlüssel, die dem alten Flutter-Port fehlten', () {
    // Der Parity-Spec-Abschnitt 0 nennt 35 fehlende Schlüssel. Sie müssen aus
    // der PWA kommen, nicht aus dem alten Bestand.
    const expected = <String>[
      'audio.dialog.title',
      'audio.dialog.body',
      'audio.dialog.activate',
      'audio.dialog.cancel',
      'audio.beacon.prompt',
      'audio.direction.n',
      'audio.direction.ne',
      'audio.direction.e',
      'audio.direction.se',
      'audio.direction.s',
      'audio.direction.sw',
      'audio.direction.w',
      'audio.direction.nw',
      'audio.metadata.prompt',
      'audio.position.prompt',
      'audio.others',
      'audio.toast.paused',
      'audio.toast.resumed',
      'audio.miniplayer.close',
      'audio.miniplayer.skip',
      'audio.settings.voice',
      'cat.heute',
      'dh.button',
      'dh.hint',
      'dh.now',
      'dh.then',
      'dh.close',
      'dh.noCamera',
      'signup.confirmEmailHint',
      'signup.errGeneric',
      'tour.freeform',
      'tour.routeSectionLabel',
      'tour.stopsSuffix',
      'trophy.stadtreporter',
      'wallet.replayIntro',
    ];

    test('alle 35 existieren in beiden Sprachen', () {
      for (final key in expected) {
        expect(de.hasText(key), isTrue, reason: 'DE fehlt "$key"');
        expect(en.hasText(key), isTrue, reason: 'EN fehlt "$key"');
      }
    });

    test('die acht Himmelsrichtungen tragen echte Werte', () {
      expect(de.text('audio.direction.n'), 'Norden');
      expect(de.text('audio.direction.sw'), 'Südwesten');
      expect(de.text('audio.direction.nw'), 'Nordwesten');
      expect(en.text('audio.direction.n'), 'north');
      expect(en.text('audio.direction.nw'), 'northwest');
    });
  });

  group('Werte kommen aus der PWA, nicht aus dem alten Port', () {
    test('driftende Beispiele aus dem Parity-Spec tragen den PWA-Wortlaut', () {
      expect(de.text('splash.createAccountCta'), 'Jetzt registrieren →');
      expect(de.text('login.heroTitle'), 'Wieder da?');
      expect(de.text('signup.agbTerms'), 'Nutzungsbedingungen');
    });
  });

  group('Kodierung', () {
    test('deutsche Werte tragen echte Umlaute', () {
      expect(de.text('lang.headline'), 'Sprache wählen');
      expect(de.text('tour.skip'), 'Überspringen');
      expect(de.text('dh.close'), 'Schließen');
      expect(de.text('audio.direction.se'), 'Südosten');
      expect(de.text('creator.bodyLabel'), 'Was weißt du darüber?');
    });

    test('keine Ersatzschreibung ae, oe, ue oder ss in deutschen Werten', () {
      final transcribed = RegExp(
        r'\b(waehl\w*|Waehl\w*|ueber\w*|Ueber\w*|oeffn\w*|Oeffn\w*|'
        r'schliess\w*|Schliess\w*|Ueberspringen|fuer|Fuer)\b',
      );
      final hits = <String>[];
      generatedTextsByLanguage['de']!.forEach((key, value) {
        if (transcribed.hasMatch(value)) {
          hits.add('$key: $value');
        }
      });
      expect(hits, isEmpty);
    });

    test('Sonderzeichen und Emoji der Quelle sind erhalten', () {
      expect(de.text('onboarding.quote'), '»Man sieht nur, was man weiß.«');
      expect(de.text('audio.dialog.title'), '🎧 Audio-Guide aktivieren');
      expect(de.text('map.tour'), '🗺 Tour');
    });

    test('Zeilenumbrüche der Quelle sind echte Umbrüche', () {
      expect(de.text('tour.step1.title'), '»Man sieht nur,\nwas man weiß.«');
      expect(de.text('audio.dialog.body'), contains('\n\n'));
    });
  });

  group('Bewusst nicht übersetzte Texte', () {
    // Parity-Spec Abschnitt 0: Goethe-Zitat auf dem Splash, `Deutsch` und
    // `Weiter auf Deutsch`, der Wordmark-Untertitel, die
    // Passwort-Stärke-Labels und der ODER-Trenner bleiben unübersetzt. In der
    // PWA stehen sie hartcodiert im Screen und **nicht** in translations.jsx:
    //   screen-auth.jsx:51    Stadtführer · Urban Explorer (CSS uppercase)
    //   screen-auth.jsx:108   ['Zu schwach','Schwach','Okay','Gut','Stark']
    //   screen-auth.jsx:127   oder (CSS uppercase)
    //   screen-auth.jsx:308   „Man sieht nur, was man weiß." / — Goethe
    //   screen-auth.jsx:334   Deutsch / Weiter auf Deutsch
    // Diese Konvention bleibt. Wer eine dieser Stellen doch übersetzt, ändert
    // Verhalten und braucht dafür eine Entscheidung.
    test('kein Schlüssel trägt einen dieser Werte', () {
      const hardcoded = <String>[
        'Stadtführer · Urban Explorer',
        'Weiter auf Deutsch',
        'Continue in English',
        'Zu schwach',
        'oder',
        'ODER',
        '— Goethe',
      ];
      for (final language in AppLanguage.values) {
        final table = generatedTextsByLanguage[language.code]!;
        for (final value in hardcoded) {
          final hits = table.entries
              .where((e) => e.value == value)
              .map((e) => e.key)
              .toList();
          expect(
            hits,
            isEmpty,
            reason:
                '"$value" rendert die PWA hartcodiert im Screen, '
                'siehe screen-auth.jsx. Ein Schlüssel dafür wäre eine '
                'Verhaltensänderung.',
          );
        }
      }
    });

    test('lang.de bleibt in beiden Sprachen deutsch', () {
      // In der PWA zeigt der Sprachwähler jede Sprache in ihrer eigenen
      // Sprache. `lang.de` ist deshalb kein Übersetzungsfehler.
      expect(de.text('lang.de'), 'Deutsch');
      expect(en.text('lang.de'), 'Deutsch');
      expect(de.text('lang.en'), 'English');
      expect(en.text('lang.en'), 'English');
    });

    test('das Zitat im Onboarding ist dagegen übersetzt', () {
      // Nicht mit dem hartcodierten Splash-Zitat verwechseln: die Schlüssel
      // `onboarding.quote` und `creator.quote` existieren und tragen in EN
      // einen englischen Wert.
      expect(en.text('onboarding.quote'), '»You only see what you know.«');
      expect(en.text('creator.quote'), 'You only see what you know.');
    });
  });

  group('Listenwerte', () {
    test('creator.steps trägt vier Schritte je Sprache', () {
      expect(de.textList('creator.steps'), [
        'Foto & Ort',
        'Dein Wissen',
        'Quelle',
        'Fertig',
      ]);
      expect(en.textList('creator.steps'), [
        'Photo & Location',
        'Your Knowledge',
        'Source',
        'Done',
      ]);
    });

    test('profil.levelTitles trägt sechs Stufen je Sprache', () {
      expect(de.textList('profil.levelTitles'), hasLength(6));
      expect(en.textList('profil.levelTitles'), hasLength(6));
      expect(de.textList('profil.levelTitles').first, 'Newcomer');
    });
  });
}

/// Füllt für einen Schlüssel alle in DE vorkommenden Platzhalter, damit
/// `text()` ohne Assertion durchläuft.
Map<String, String> _dummyParams(String key, AppStrings strings) {
  final raw = generatedTextsByLanguage[strings.language.code]![key]!;
  final names = RegExp(
    r'\{([A-Za-z_][A-Za-z0-9_]*)\}',
  ).allMatches(raw).map((m) => m.group(1)!).toSet();
  return {for (final name in names) name: 'x'};
}
