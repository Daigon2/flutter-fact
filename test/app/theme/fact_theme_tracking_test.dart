import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';

/// Rückfall-Schutz für E-38 und für die Zeilenhöhe: Materials Laufweite und
/// Materials `height` dürfen nicht zurückkommen.
///
/// Material 2021 legt auf jeden Textslot beides, `bodyMedium` etwa 0.25 Pixel
/// je Zeichen und eine Zeilenhöhe von 1.43. Die PWA gibt an den meisten Stellen
/// weder das eine noch das andere an. Der Laufweiten-Zuschlag hat die
/// Sprachzeile des Startbildschirms bei 411 logischen Pixeln zum Umbruch
/// gebracht; die Zeilenhöhe hat am 29.08.2026 auf 46 gemessenen Absätzen jeden
/// Zeilenkasten aufgebläht und damit jede Pillenhöhe, die gegen die Quelle
/// belegt war.
///
/// **`styles.css` enthält das Wort `line-height` kein einziges Mal.** Die
/// Quelle setzt sie ausschließlich am einzelnen Element; wo sie fehlt, rechnet
/// der Browser mit `line-height: normal`, also mit den Metriken der Schrift,
/// und das heißt in Flutter `height: null`.
///
/// Der Weg, auf dem beides in den Baum kommt, ist **nicht** das `textTheme` von
/// `ThemeData`, sondern `ThemeData.typography`: das `Theme`-Widget ruft
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
      test(
        '${build.key}: keine Laufweite und keine Zeilenhoehe in englishLike, '
        'dense und tall',
        () {
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
              expect(
                slot.value(geometry.value)?.height,
                isNull,
                reason:
                    '${geometry.key}.${slot.key} traegt wieder eine '
                    'Zeilenhoehe. Die PWA hat keine globale, null heisst hier '
                    '"Metriken der Schrift" wie `line-height: normal`.',
              );
            }
          }
        },
      );
    }

    test('nur Laufweite und Zeilenhoehe verschwinden, sonst nichts', () {
      // Rundlauf gegen Materials Vorlage: wer die beiden Werte zurücksetzt,
      // muss wieder exakt Materials Stil erhalten. Das schlägt an, sobald der
      // Umbau in `_styleWithoutTrackingAndLineHeight` ein Feld vergisst, etwa
      // `fontSize` oder `leadingDistribution`.
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
            slot
                .value(ours)!
                .copyWith(
                  letterSpacing: theirs.letterSpacing,
                  height: theirs.height,
                ),
            equals(theirs),
            reason:
                '${pair.key}.${slot.key} hat neben Laufweite und Zeilenhoehe '
                'noch etwas anderes verloren.',
          );
        }
      }
    });

    test('Materials Vorlage traegt Laufweite und Zeilenhoehe wirklich', () {
      // Gegenprobe zur vorigen Zusicherung: ohne diese Zeilen wuerde der
      // Rundlauf auch dann gruen bleiben, wenn Material selbst nichts mehr
      // setzte und der Umbau hier gar nichts mehr taete.
      expect(Typography.englishLike2021.bodyMedium?.letterSpacing, 0.25);
      expect(Typography.englishLike2021.labelLarge?.letterSpacing, 0.1);
      expect(Typography.englishLike2021.titleMedium?.letterSpacing, 0.15);
      expect(Typography.englishLike2021.displayLarge?.letterSpacing, -0.25);
      // `bodyMedium` ist der Slot, den `Material` als `DefaultTextStyle`
      // weiterreicht, `bodyLarge` der, den `TextField` als Eingabestil nimmt.
      expect(Typography.englishLike2021.bodyMedium?.height, 1.43);
      expect(Typography.englishLike2021.bodyLarge?.height, 1.50);
      expect(Typography.englishLike2021.displayLarge?.height, 1.12);
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

    testWidgets('kein Slot bringt nach dem Lokalisieren eine Laufweite oder '
        'Zeilenhoehe mit', (tester) async {
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
        expect(
          slot.value(textTheme)?.height,
          isNull,
          reason: 'textTheme.${slot.key} traegt wieder eine Zeilenhoehe.',
        );
        expect(
          slot.value(primaryTextTheme)?.height,
          isNull,
          reason:
              'primaryTextTheme.${slot.key} traegt wieder eine Zeilenhoehe.',
        );
      }
      // `DefaultTextStyle` ist der Kanal, über den ein `Text` mit eigenem Stil
      // beides erbt, ohne es je zu nennen: `Material` setzt ihn auf
      // `textTheme.bodyMedium`.
      expect(defaultStyle.letterSpacing, isNull);
      expect(defaultStyle.height, isNull);
    });

    testWidgets('Materials Groesse bleibt, seine Zeilenhoehe nicht', (
      tester,
    ) async {
      await pumpThemed(tester, FactTheme.dark());
      final body = textTheme.bodyMedium!;
      expect(body.fontSize, 14.0);
      // Der Wert nicht abgetippt, sondern aus Flutter selbst gelesen: genau
      // dieses `TextTheme` mischt das `Theme`-Widget beim Lokalisieren als
      // Basis unter `textTheme`. Ändert Flutter die Zahl, folgt dieser Test
      // ihr, statt gegen eine veraltete gruen zu bleiben.
      expect(body.height, isNot(Typography.englishLike2021.bodyMedium!.height));
      expect(body.height, isNull);
      expect(body.textBaseline, TextBaseline.alphabetic);
      // Half-Leading bleibt bewusst stehen, siehe `FactTheme`: das ist das
      // Umbruchmodell der Quelle, kein Material-Geschmack.
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

    testWidgets('ein geerbter Stil misst genau ohne Materials Zeilenhoehe', (
      tester,
    ) async {
      await pumpThemed(tester, FactTheme.dark());
      // Der Gegenpart zur Breitenmessung oben, und die eigentliche Wirkung
      // dieser Datei: die Höhe eines Textes ohne eigene `height`.
      //
      // JetBrains Mono trägt (aus `assets/fonts/JetBrainsMono-Regular.ttf`,
      // Tabellen `head`, `hhea` und `OS/2`) 1020 Einheiten Oberlänge und 300
      // Unterlänge auf 1000 pro Geviert, Durchschuss 0. Bei Größe 10 sind das
      // 10.2 oben und 3.0 unten; Flutter rundet je Zeile einzeln, also 10 + 3.
      //
      // Mit Materials `height: 1.43` wären es 14.3, aufgerundet 15 statt 13.
      // Die Rundung selbst ist Flutters Umgang mit den Metriken und aus der
      // PWA nicht herleitbar; herleitbar ist, dass die Quelle hier gar keine
      // `line-height` führt und der Browser deshalb ebenfalls mit den
      // Metriken rechnet.
      expect(tester.getSize(find.byKey(const Key('geerbt'))).height, 13.0);
      expect(
        tester.getSize(find.byKey(const Key('geerbt'))).height,
        isNot(15.0),
        reason: 'das waere Materials 1.43 auf Groesse 10',
      );
    });

    testWidgets('das helle Theme verhaelt sich gleich', (tester) async {
      await pumpThemed(tester, FactTheme.light());
      expect(textTheme.bodyMedium?.letterSpacing, isNull);
      expect(textTheme.bodyMedium?.height, isNull);
      expect(defaultStyle.letterSpacing, isNull);
      expect(defaultStyle.height, isNull);
      expect(tester.getSize(find.byKey(const Key('geerbt'))).width, 42.0);
      expect(tester.getSize(find.byKey(const Key('geerbt'))).height, 13.0);
    });
  });
}
