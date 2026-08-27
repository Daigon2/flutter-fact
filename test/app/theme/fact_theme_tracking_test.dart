import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';

/// Rückfall-Schutz für E-38: Materials Laufweite darf nicht zurückkommen.
///
/// Material 2021 legt auf jeden Textslot eine Laufweite, `bodyMedium` etwa
/// 0.25 Pixel je Zeichen. Die PWA gibt an den meisten Stellen keine an, und der
/// Zuschlag hat die Sprachzeile des Startbildschirms bei 411 logischen Pixeln
/// zum Umbruch gebracht.
///
/// Der Weg, auf dem die Laufweite in den Baum kommt, ist **nicht** das
/// `textTheme` von `ThemeData`, sondern `ThemeData.typography`: das
/// `Theme`-Widget ruft
/// `ThemeData.localize(theme, theme.typography.geometryThemeFor(category))`
/// auf, und `localize` mischt die Geometrie als **Basis** unter das eigene
/// `textTheme`. Deshalb prüft diese Datei beide Enden: die Geometrie im
/// `ThemeData` und das, was unten im Widget-Baum ankommt.
void main() {
  // Echte Schriften, weil unten Breiten gemessen werden. Nur aus `setUpAll`,
  // siehe `test/support/app_fonts.dart`.
  setUpAll(loadAppFonts);

  /// Die fünfzehn Material-Slots als Paar aus Name und Zugriff.
  final slots = <String, TextStyle? Function(TextTheme)>{
    'displayLarge': (t) => t.displayLarge,
    'displayMedium': (t) => t.displayMedium,
    'displaySmall': (t) => t.displaySmall,
    'headlineLarge': (t) => t.headlineLarge,
    'headlineMedium': (t) => t.headlineMedium,
    'headlineSmall': (t) => t.headlineSmall,
    'titleLarge': (t) => t.titleLarge,
    'titleMedium': (t) => t.titleMedium,
    'titleSmall': (t) => t.titleSmall,
    'bodyLarge': (t) => t.bodyLarge,
    'bodyMedium': (t) => t.bodyMedium,
    'bodySmall': (t) => t.bodySmall,
    'labelLarge': (t) => t.labelLarge,
    'labelMedium': (t) => t.labelMedium,
    'labelSmall': (t) => t.labelSmall,
  };

  group('Geometrie im ThemeData', () {
    for (final build in <String, ThemeData Function()>{
      'dark': FactTheme.dark,
      'light': FactTheme.light,
    }.entries) {
      test('${build.key}: keine Laufweite in englishLike, dense und tall', () {
        final typography = build.value().typography;
        for (final geometry in <String, TextTheme>{
          'englishLike': typography.englishLike,
          'dense': typography.dense,
          'tall': typography.tall,
        }.entries) {
          for (final slot in slots.entries) {
            expect(
              slot.value(geometry.value)?.letterSpacing,
              isNull,
              reason:
                  '${geometry.key}.${slot.key} traegt wieder eine Laufweite. '
                  'E-38 verlangt null, wo die PWA keine angibt.',
            );
          }
        }
      });
    }

    test('nur die Laufweite verschwindet, sonst nichts', () {
      // Rundlauf gegen Materials Vorlage: wer die Laufweite zurücksetzt, muss
      // wieder exakt Materials Stil erhalten. Das schlägt an, sobald der
      // Umbau in `_styleWithoutTracking` ein Feld vergisst, etwa `height` oder
      // `leadingDistribution`.
      final typography = FactTheme.dark().typography;
      final pairs = <String, (TextTheme, TextTheme)>{
        'englishLike': (typography.englishLike, Typography.englishLike2021),
        'dense': (typography.dense, Typography.dense2021),
        'tall': (typography.tall, Typography.tall2021),
      };
      for (final pair in pairs.entries) {
        final (ours, material) = pair.value;
        for (final slot in slots.entries) {
          final theirs = slot.value(material)!;
          expect(
            slot.value(ours)!.copyWith(letterSpacing: theirs.letterSpacing),
            equals(theirs),
            reason:
                '${pair.key}.${slot.key} hat neben der Laufweite noch etwas '
                'anderes verloren.',
          );
        }
      }
    });

    test('Materials Vorlage traegt die Laufweite wirklich', () {
      // Gegenprobe zur vorigen Zusicherung: ohne diese Zeile wuerde der
      // Rundlauf auch dann gruen bleiben, wenn Material selbst keine
      // Laufweite mehr setzte und der Umbau hier gar nichts mehr taete.
      expect(Typography.englishLike2021.bodyMedium?.letterSpacing, 0.25);
      expect(Typography.englishLike2021.labelLarge?.letterSpacing, 0.1);
      expect(Typography.englishLike2021.titleMedium?.letterSpacing, 0.15);
      expect(Typography.englishLike2021.displayLarge?.letterSpacing, -0.25);
    });
  });

  group('was im Widget-Baum ankommt', () {
    late TextTheme textTheme;
    late TextTheme primaryTextTheme;
    late TextStyle defaultStyle;

    Future<void> pumpThemed(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                textTheme = Theme.of(context).textTheme;
                primaryTextTheme = Theme.of(context).primaryTextTheme;
                defaultStyle = DefaultTextStyle.of(context).style;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Deutsch',
                      key: const Key('geerbt'),
                      style: FactTypography.mono.copyWith(fontSize: 10),
                    ),
                    Text(
                      'Deutsch',
                      key: const Key('eigen'),
                      style: FactTypography.mono.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('kein Slot bringt nach dem Lokalisieren eine Laufweite mit', (
      tester,
    ) async {
      await pumpThemed(tester, FactTheme.dark());
      for (final slot in slots.entries) {
        expect(
          slot.value(textTheme)?.letterSpacing,
          isNull,
          reason: 'textTheme.${slot.key} traegt wieder eine Laufweite.',
        );
        expect(
          slot.value(primaryTextTheme)?.letterSpacing,
          isNull,
          reason: 'primaryTextTheme.${slot.key} traegt wieder eine Laufweite.',
        );
      }
      // `DefaultTextStyle` ist der Kanal, über den ein `Text` mit eigenem Stil
      // die Laufweite erbt, ohne sie je zu nennen: `Material` setzt ihn auf
      // `textTheme.bodyMedium`.
      expect(defaultStyle.letterSpacing, isNull);
    });

    testWidgets('Materials Groessen bleiben erhalten', (tester) async {
      await pumpThemed(tester, FactTheme.dark());
      final body = textTheme.bodyMedium!;
      expect(body.fontSize, 14.0);
      expect(body.height, 1.43);
      expect(body.textBaseline, TextBaseline.alphabetic);
      expect(body.leadingDistribution, TextLeadingDistribution.even);
      expect(body.fontFamily, 'DMSans');
    });

    testWidgets('ein geerbter Stil misst genau ohne Zuschlag', (tester) async {
      await pumpThemed(tester, FactTheme.dark());
      // "Deutsch" in JetBrains Mono 10: sieben Zeichen. Mit Materials 0.25
      // wären es 43,75 statt 42,0 Pixel, also 1,75 mehr. Genau dieser
      // Zuschlag ist der Gegenstand von E-38.
      expect(tester.getSize(find.byKey(const Key('geerbt'))).width, 42.0);
      // Eine ausdrücklich gesetzte Laufweite wirkt weiter: 7 mal 0,3 mehr.
      // `moreOrLessEquals` nur wegen der Fließkomma-Darstellung: gemessen
      // werden 44,099998474121094, und das ist keine Messtoleranz, sondern
      // 44,1 in `double`. Die Schranke ist entsprechend eng.
      expect(
        tester.getSize(find.byKey(const Key('eigen'))).width,
        moreOrLessEquals(44.1, epsilon: 0.0001),
      );
    });

    testWidgets('das helle Theme verhaelt sich gleich', (tester) async {
      await pumpThemed(tester, FactTheme.light());
      expect(textTheme.bodyMedium?.letterSpacing, isNull);
      expect(defaultStyle.letterSpacing, isNull);
      expect(tester.getSize(find.byKey(const Key('geerbt'))).width, 42.0);
    });
  });
}
