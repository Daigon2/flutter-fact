import 'dart:math';

import 'package:fact_app/features/identity/presentation/notifiers/username_suggestion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Username-Vorschlag, festgenagelt gegen
/// `02_Frontend/app/screen-auth.jsx:585-590`.
void main() {
  group('Die Wortliste', () {
    test('steht hartcodiert auf Deutsch, in der Reihenfolge der Quelle', () {
      // Kein i18n-Schlüssel, und dieser Schritt legt keinen an. Auf Englisch
      // entstehen dieselben deutschen Vorschläge, genau wie in der PWA.
      expect(usernameSuggestionWords, <String>[
        'stadt',
        'nacht',
        'fluss',
        'stein',
        'turm',
        'markt',
        'gold',
      ]);
    });
  });

  group('Der Vorschlag', () {
    test('setzt Wort, fuchs_ und den ersten Buchstaben zusammen', () {
      // Der Zufall ist injiziert, nicht ausgeschaltet: mit festem Index ist das
      // Ergebnis eine reine Funktion.
      expect(suggestUsername('München', randomIndex: (_) => 6), 'goldfuchs_m');
      expect(
        suggestUsername('Regensburg', randomIndex: (_) => 0),
        'stadtfuchs_r',
      );
    });

    test('der Anfangsbuchstabe wird kleingeschrieben', () {
      expect(suggestUsername('Passau', randomIndex: (_) => 4), 'turmfuchs_p');
    });

    test('ein leerer Stadtname ergibt x', () {
      // Über die Oberfläche nicht erreichbar, die Liste hat keine leeren Namen.
      // Steht hier, weil die Quelle den Fall hat: `(cityVal || 'x')[0]`.
      expect(suggestUsername('', randomIndex: (_) => 1), 'nachtfuchs_x');
    });

    test('jeder Vorschlag besteht die Syntaxprüfung des Feldes', () {
      // Sonst schlüge der Vorschlag sofort in `invalid` um. Nur ASCII-Städte
      // sind sicher: eine Stadt, die mit einem Umlaut beginnt, ergäbe einen
      // ungültigen Namen. In der Liste gibt es keine, und ein Test dafür wäre
      // eine Zusicherung über Daten, die hier nicht entstehen.
      final syntax = RegExp(r'^[a-zA-Z0-9_]{2,20}$');
      for (var index = 0; index < usernameSuggestionWords.length; index++) {
        for (final city in <String>['München', 'Rom', 'Passau', 'Regensburg']) {
          final suggestion = suggestUsername(city, randomIndex: (_) => index);
          expect(syntax.hasMatch(suggestion), isTrue, reason: suggestion);
        }
      }
    });
  });

  group('Der Zufallsgenerator', () {
    test('kommt aus einem Provider und ist überschreibbar', () {
      final scope = ProviderContainer(
        overrides: [randomIndexProvider.overrideWithValue((_) => 3)],
      );
      addTearDown(scope.dispose);

      expect(
        suggestUsername('Rom', randomIndex: scope.read(randomIndexProvider)),
        'steinfuchs_r',
      );
    });

    test('der Standard zieht Werte im gültigen Bereich', () {
      // Kein Test auf einen bestimmten Wert: `Random` ist absichtlich nicht
      // festgelegt. Geprüft wird der Bereich, denn ein Index daneben wäre ein
      // Absturz beim Antippen einer Stadt.
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      final randomIndex = scope.read(randomIndexProvider);

      for (var i = 0; i < 200; i++) {
        final index = randomIndex(usernameSuggestionWords.length);
        expect(index, inInclusiveRange(0, usernameSuggestionWords.length - 1));
      }
    });

    test('ein echtes Random deckt über die Zeit alle Wörter ab', () {
      // Damit niemand den Generator versehentlich auf einen festen Index
      // festlegt. `Random(1)` ist hier nur eine Quelle von Streuung, kein
      // erwarteter Wert.
      final random = Random(1);
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        seen.add(suggestUsername('Rom', randomIndex: random.nextInt));
      }

      expect(seen, hasLength(usernameSuggestionWords.length));
    });
  });
}
