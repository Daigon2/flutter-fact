import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/features/identity/presentation/widgets/password_strength_meter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Stärkeanzeige, festgenagelt gegen `02_Frontend/app/screen-auth.jsx:106-121`
/// und `:583`.
///
/// Ohne Widget-Baum: Score, Beschriftung und Farbtabelle sind reine Funktionen,
/// und genau dort sitzt die Verhaltensaussage. Dass die Anzeige nur bei
/// gefülltem Feld erscheint und nichts blockiert, prüft `signup_page_test.dart`
/// am gerenderten Bildschirm.
void main() {
  group('Der Score von 0 bis 4', () {
    test('ein leeres Passwort hat 0', () {
      expect(passwordStrengthScore(''), 0);
    });

    test('jedes der vier Kriterien zählt einen Punkt', () {
      // Genau ein Kriterium je Fall, damit ein vergessenes auffällt.
      expect(passwordStrengthScore('abcdefgh'), 1, reason: 'Länge >= 8');
      expect(passwordStrengthScore('abcA'), 1, reason: 'Großbuchstabe');
      expect(passwordStrengthScore('abc1'), 1, reason: 'Ziffer');
      expect(passwordStrengthScore('abc!'), 1, reason: 'Sonderzeichen');
    });

    test('sieben Zeichen sind noch kein Längenpunkt, acht schon', () {
      expect(passwordStrengthScore('abcdefg'), 0);
      expect(passwordStrengthScore('abcdefgh'), 1);
    });

    test('die Punkte summieren sich bis 4', () {
      expect(passwordStrengthScore('abcdefgA'), 2);
      expect(passwordStrengthScore('abcdefgA1'), 3);
      expect(passwordStrengthScore('abcdefgA1!'), 4);
    });

    test('mehr als vier Kriterien gibt es nicht, der Score bleibt bei 4', () {
      // Das `Math.min(4, ...)` der Quelle ist bei vier Kriterien wirkungslos.
      // Der Test hält die Obergrenze fest, weil ein fünftes Kriterium sonst
      // stillschweigend über den Rand der Farbtabelle liefe.
      expect(passwordStrengthScore('abcdefghA1!"§\$%&/()=?'), 4);
    });

    test('Kleinbuchstaben und Umlaute sind keine eigenen Kriterien', () {
      // `ÄÖÜ` sind keine `[A-Z]`, sie zählen als Sonderzeichen. Das ist das
      // Verhalten der Quelle und harmlos, solange die Anzeige nichts blockiert.
      expect(passwordStrengthScore('äöü'), 1);
      expect(passwordStrengthScore('ßßßßßßßß'), 2);
    });
  });

  group('Beschriftung', () {
    test('die fünf Texte stehen hartcodiert auf Deutsch', () {
      // Es gibt dafür keinen i18n-Schlüssel, und dieser Schritt legt keinen an.
      // Auf Englisch steht in der PWA dasselbe.
      expect(PasswordStrengthMeter.labels, <String>[
        'Zu schwach',
        'Schwach',
        'Okay',
        'Gut',
        'Stark',
      ]);
    });

    test('ab Score 3 kommt der Bonus-Zusatz dazu', () {
      expect(PasswordStrengthMeter.strengthLabel(0), 'Zu schwach');
      expect(PasswordStrengthMeter.strengthLabel(2), 'Okay');
      expect(PasswordStrengthMeter.strengthLabel(3), 'Gut · +5 XP Bonus');
      expect(PasswordStrengthMeter.strengthLabel(4), 'Stark · +5 XP Bonus');
    });
  });

  group('Farbtabelle', () {
    test('fünf Farben bei vier Balken, in der Reihenfolge der Quelle', () {
      final colors = PasswordStrengthMeter.segmentColors(FactColors.light);

      expect(colors, <Color>[
        const Color(0xFFE8380D),
        const Color(0xFFF59E0B),
        const Color(0xFFF5C518),
        const Color(0xFF84CC16),
        const Color(0xFF16A34A),
      ]);
    });

    test('zwei der fünf sind Theme-Tokens, drei sind Literale', () {
      // `segs = [t.red, '#F59E0B', t.gold, '#84CC16', '#16A34A']`. Beide Tokens
      // sind in den zwei Themes wertgleich, der Test hält deshalb die Herkunft
      // fest und nicht einen Unterschied.
      for (final theme in <FactColors>[FactColors.light, FactColors.dark]) {
        final colors = PasswordStrengthMeter.segmentColors(theme);
        expect(colors[0], theme.red);
        expect(colors[2], theme.gold);
      }
    });

    test('die erste Farbe ist unerreichbar', () {
      // Bei `score == 0` wird kein Balken gefüllt, `segs[0]` also nie benutzt.
      // Rot erscheint in dieser Anzeige nie. Die überzählige Farbe steht
      // trotzdem in der Tabelle: sie zu entfernen verschöbe die Zuordnung um
      // eins, und Score 1 zeigte die Farbe von Score 2.
      expect(
        PasswordStrengthMeter.segmentColors(FactColors.light),
        hasLength(PasswordStrengthMeter.segmentCount + 1),
      );
    });
  });

  group('Der negative Außenabstand der Quelle', () {
    test('wird in Verschiebung und verkürzten Abstand aufgeteilt', () {
      // `marginTop: -4, marginBottom: 12`. In Flutter gibt es keinen negativen
      // Innenabstand: gezeichnet wird um 4 nach oben verschoben, und der Platz
      // nach unten ist um dieselben 4 kürzer. Damit sitzt das nächste Element
      // dort, wo CSS es hätte.
      expect(PasswordStrengthMeter.topShift, -4);
      expect(PasswordStrengthMeter.blockBottomSpacing, 8);
    });
  });
}
