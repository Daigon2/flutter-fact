import 'dart:io';

import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nagelt die Design-Tokens auf die Werte aus `02_Frontend/app/styles.css`
/// fest. Die PWA ist die Verhaltensquelle, also darf sich hier nichts
/// unbemerkt verschieben. Wer einen Wert ändert, muss diesen Test anfassen und
/// begründet damit die Änderung.
///
/// Erwartungen stehen absichtlich als Literal da und nie als Verweis auf die
/// Implementierung. `expect(FactColors.light.red, FactColors.dark.red)` bliebe
/// grün, wenn jemand beide Seiten gleichzeitig verschiebt, und sichert damit
/// nichts ab.
void main() {
  group('FactColors dunkel, entspricht :root', () {
    const t = FactColors.dark;

    test('Flächen', () {
      expect(t.bg, const Color(0xFF13100E), reason: '--bg');
      expect(t.surface, const Color(0xFF1C1712), reason: '--surface');
      expect(t.surface2, const Color(0xFF251F17), reason: '--surface-2');
      expect(t.surface3, const Color(0xFF2E2720), reason: '--surface-3');
      expect(t.surfaceEdge, const Color(0xFF3A3028), reason: '--surface-edge');
    });

    test('Rot und Gold', () {
      expect(t.red, const Color(0xFFE8380D), reason: '--red');
      expect(t.redDark, const Color(0xFFA82508), reason: '--red-dk');
      expect(t.redLight, const Color(0xFFFF6B3D), reason: '--red-lt');
      expect(t.gold, const Color(0xFFF5C518), reason: '--gold');
      expect(t.goldDark, const Color(0xFFC49A0A), reason: '--gold-dk');
      expect(t.goldLight, const Color(0xFFFFE066), reason: '--gold-lt');
    });

    test('Coin ist im dunklen Theme deckungsgleich mit Gold', () {
      // :root Zeile 54: --coin: #F5C518, identisch zu --gold in Zeile 20.
      // Erst .theme-light trennt die beiden.
      expect(t.coin, const Color(0xFFF5C518), reason: '--coin');
      expect(t.coinSoft, const Color(0x24F5C518), reason: '--coin-soft');
    });

    test('Kategorie-Werte', () {
      expect(t.catHist, const Color(0xFFE8380D), reason: '--cat-hist');
      expect(t.catMyth, const Color(0xFFA855F7), reason: '--cat-myth');
      expect(t.catFun, const Color(0xFFF5C518), reason: '--cat-fun');
      expect(t.catGeo, const Color(0xFF00C2A8), reason: '--cat-geo');
      expect(t.catArch, const Color(0xFF3B82F6), reason: '--cat-arch');
    });

    test('Text', () {
      expect(t.ink, const Color(0xFFF5F0E8), reason: '--ink');
      expect(t.ink2, const Color(0xFFB0A898), reason: '--ink-2');
      expect(t.ink3, const Color(0xFF706860), reason: '--ink-3');
      expect(t.inkFaint, const Color(0xFF4A4040), reason: '--ink-faint');
    });

    test('Karte', () {
      expect(t.mapBg, const Color(0xFF0E1116), reason: '--map-bg');
      expect(t.mapText, const Color(0xFFF2EADC), reason: '--map-text');
    });

    test('halbtransparente Werte: rgba korrekt in ARGB übersetzt', () {
      // --border: rgba(255,200,120,0.10) → alpha 0.10 * 255 = 25.5 → 0x1A
      expect(t.border, const Color(0x1AFFC878));
      // --border-2: rgba(255,200,120,0.18) → 45.9 → 0x2E
      expect(t.border2, const Color(0x2EFFC878));
      // --stamp-soft: rgba(232,56,13,0.14) → 35.7 → 0x24
      expect(t.redSoft, const Color(0x24E8380D));
      // --red-glow: rgba(232,56,13,0.38) → 96.9 → 0x61
      expect(t.redGlow, const Color(0x61E8380D));
      // --stamp-glow: dunkel identisch zu --red-glow, 0.38 → 0x61
      expect(t.stampGlow, const Color(0x61E8380D));
      // --gold-soft: rgba(245,197,24,0.14) → 35.7 → 0x24
      expect(t.goldSoft, const Color(0x24F5C518));
      // --map-surface: rgba(15,18,24,0.75) → 191.25 → 0xBF
      expect(t.mapSurface, const Color(0xBF0F1218));
    });
  });

  group('FactColors hell, entspricht .theme-light', () {
    const t = FactColors.light;

    test('Flächen kippen', () {
      expect(t.bg, const Color(0xFFFDF5E8), reason: '--bg');
      expect(t.surface, const Color(0xFFFFF8EE), reason: '--surface');
      expect(t.surface2, const Color(0xFFF5EDD8), reason: '--surface-2');
      expect(t.surface3, const Color(0xFFEDE1C8), reason: '--surface-3');
      expect(t.surfaceEdge, const Color(0xFFD8CDB2), reason: '--surface-edge');
    });

    test('Text kippt', () {
      expect(t.ink, const Color(0xFF1A1208), reason: '--ink');
      expect(t.ink2, const Color(0xFF5C4A30), reason: '--ink-2');
      expect(t.ink3, const Color(0xFFA08860), reason: '--ink-3');
      expect(t.inkFaint, const Color(0xFFC8B890), reason: '--ink-faint');
    });

    test('Rot bleibt, die Rot-Grundtöne sind themeneutral', () {
      // .theme-light setzt --stamp und --primary erneut auf denselben Wert und
      // überschreibt --red gar nicht. Alle drei bleiben also #E8380D.
      expect(t.red, const Color(0xFFE8380D), reason: '--red');
      expect(t.redDark, const Color(0xFFA82508), reason: '--red-dk');
      expect(t.redLight, const Color(0xFFFF6B3D), reason: '--red-lt');
    });

    test('Gold erbt die :root-Werte, weil .theme-light --gold nicht anfasst', () {
      // Kernpunkt: .theme-light listet --coin, aber kein --gold. Wer hier den
      // Coin-Wert einsetzt, zieht die 5 live var(--gold)-Stellen der PWA
      // (screen-creator 554/628, screen-entdecken 369, .btn.gold, .btn-game.coin)
      // im hellen Theme auf den falschen Ton.
      expect(t.gold, const Color(0xFFF5C518), reason: '--gold aus :root');
      expect(
        t.goldDark,
        const Color(0xFFC49A0A),
        reason: '--gold-dk aus :root',
      );
      expect(
        t.goldLight,
        const Color(0xFFFFE066),
        reason: '--gold-lt aus :root',
      );
      // --gold-soft: rgba(245,197,24,0.14) → 0x24, unverändert aus :root
      expect(t.goldSoft, const Color(0x24F5C518), reason: '--gold-soft');
    });

    test('Coin wird abgedunkelt', () {
      // styles.css Zeile 94: --coin: #D4A820
      expect(t.coin, const Color(0xFFD4A820), reason: '--coin');
      // Zeile 96: --coin-soft: rgba(212,168,32,0.14) → 35.7 → 0x24
      expect(t.coinSoft, const Color(0x24D4A820), reason: '--coin-soft');
    });

    test('Coin und Gold sind im hellen Theme verschieden', () {
      // Der Regressionsschutz gegen das Verschmelzen beider Tokens.
      expect(t.coin, isNot(t.gold));
      expect(t.coinSoft, isNot(t.goldSoft));
    });

    test('Rot-Glow: --red-glow erbt, --stamp-glow wird abgesenkt', () {
      // Zeile 18 wird nicht überschrieben: 0.38 → 96.9 → 0x61
      expect(
        t.redGlow,
        const Color(0x61E8380D),
        reason: '--red-glow aus :root',
      );
      // Zeile 93: --stamp-glow: rgba(232,56,13,0.35) → 89.25 → 0x59
      expect(t.stampGlow, const Color(0x59E8380D), reason: '--stamp-glow');
      expect(t.stampGlow, isNot(t.redGlow));
    });

    test('redSoft trägt --stamp-soft, weil --red-soft ungenutzt ist', () {
      // Zeile 92: --stamp-soft: rgba(232,56,13,0.12) → 30.6 → 0x1F
      expect(t.redSoft, const Color(0x1FE8380D), reason: '--stamp-soft');
    });

    test('Rahmen wechseln von warmem Hell auf warmes Dunkel', () {
      // --border: rgba(140,100,40,0.12) → 30.6 → 0x1F
      expect(t.border, const Color(0x1F8C6428), reason: '--border');
      // --border-2: rgba(140,100,40,0.22) → 56.1 → 0x38
      expect(t.border2, const Color(0x388C6428), reason: '--border-2');
    });

    test('Kategorie-Werte sind themeneutral', () {
      expect(t.catHist, const Color(0xFFE8380D), reason: '--cat-hist');
      expect(t.catMyth, const Color(0xFFA855F7), reason: '--cat-myth');
      expect(t.catFun, const Color(0xFFF5C518), reason: '--cat-fun');
      expect(t.catGeo, const Color(0xFF00C2A8), reason: '--cat-geo');
      expect(t.catArch, const Color(0xFF3B82F6), reason: '--cat-arch');
    });

    test('die Karte bleibt dunkel, .theme-light fasst --map-* nicht an', () {
      expect(t.mapBg, const Color(0xFF0E1116), reason: '--map-bg');
      expect(t.mapSurface, const Color(0xBF0F1218), reason: '--map-surface');
      expect(t.mapText, const Color(0xFFF2EADC), reason: '--map-text');
    });
  });

  group('FactColors Wertgleichheit', () {
    test(
      'zwei getrennt erzeugte, strukturell gleiche Instanzen sind gleich',
      () {
        // Ohne == wäre das hier zwei verschiedene Objekte. ThemeData.== prüft
        // seine Extensions über mapEquals, also über ==, und ein ungleiches
        // ThemeData baut den ganzen Baum unter Theme neu auf.
        final copy = FactColors.dark.copyWith(bg: FactColors.dark.bg);

        expect(identical(copy, FactColors.dark), isFalse);
        expect(copy, FactColors.dark);
        expect(copy.hashCode, FactColors.dark.hashCode);
      },
    );

    test('ein einziges abweichendes Feld macht die Instanzen ungleich', () {
      final changed = FactColors.dark.copyWith(coin: const Color(0xFF000000));

      expect(changed, isNot(FactColors.dark));
    });

    test('dunkel und hell sind ungleich', () {
      expect(FactColors.dark, isNot(FactColors.light));
    });
  });

  group('Theme-Anbindung', () {
    test('beide Themes tragen die Extension mit den erwarteten Werten', () {
      final dark = FactTheme.dark().extension<FactColors>();
      final light = FactTheme.light().extension<FactColors>();

      expect(dark, isNotNull);
      expect(light, isNotNull);
      // Nach dem Hinzufügen von == prüft das die Werte und nicht mehr nur die
      // Instanz-Identität der const-Singletons.
      expect(dark, FactColors.dark);
      expect(light, FactColors.light);
      expect(dark!.coin, const Color(0xFFF5C518));
      expect(light!.coin, const Color(0xFFD4A820));
    });

    test('scaffoldBackgroundColor und canvasColor tragen --bg', () {
      expect(FactTheme.dark().scaffoldBackgroundColor, const Color(0xFF13100E));
      expect(FactTheme.dark().canvasColor, const Color(0xFF13100E));
      expect(
        FactTheme.light().scaffoldBackgroundColor,
        const Color(0xFFFDF5E8),
      );
      expect(FactTheme.light().canvasColor, const Color(0xFFFDF5E8));
    });

    test('die colorScheme-Zuweisungen kommen an', () {
      final dark = FactTheme.dark().colorScheme;

      expect(dark.brightness, Brightness.dark);
      expect(dark.primary, const Color(0xFFE8380D), reason: '--red');
      expect(dark.secondary, const Color(0xFFF5C518), reason: '--coin');
      expect(dark.surface, const Color(0xFF1C1712), reason: '--surface');
      expect(dark.onSurface, const Color(0xFFF5F0E8), reason: '--ink');

      final light = FactTheme.light().colorScheme;

      expect(light.brightness, Brightness.light);
      expect(light.primary, const Color(0xFFE8380D));
      expect(light.secondary, const Color(0xFFD4A820), reason: '--coin hell');
      expect(light.surface, const Color(0xFFFFF8EE));
      expect(light.onSurface, const Color(0xFF1A1208));
    });

    test('wiederholte Aufrufe liefern gleichwertige Themes', () {
      // Belegt, dass das gecachte ColorScheme keinen Unterschied macht und
      // MaterialApp bei jedem Build ein gleiches ThemeData sieht.
      expect(FactTheme.dark().colorScheme, FactTheme.dark().colorScheme);
      expect(FactTheme.dark(), FactTheme.dark());
      expect(FactTheme.light(), FactTheme.light());
      expect(FactTheme.dark(), isNot(FactTheme.light()));
    });

    testWidgets('context.factColors liefert die Tokens des aktiven Themes', (
      tester,
    ) async {
      late FactColors seen;

      await tester.pumpWidget(
        MaterialApp(
          theme: FactTheme.dark(),
          home: Builder(
            builder: (context) {
              seen = context.factColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen.bg, const Color(0xFF13100E));
      expect(seen.coin, const Color(0xFFF5C518));
    });

    test('lerp bleibt bei t=0 und t=1 auf den Endpunkten', () {
      final atStart = FactColors.dark.lerp(FactColors.light, 0);
      final atEnd = FactColors.dark.lerp(FactColors.light, 1);

      expect(atStart, FactColors.dark);
      expect(atEnd, FactColors.light);
    });

    test('lerp gegen null bleibt beim Ausgangswert', () {
      expect(FactColors.dark.lerp(null, 0.5), FactColors.dark);
    });
  });

  group('FactTypography', () {
    test('Familien entsprechen den family-Namen in pubspec.yaml', () {
      // Direkter Textabgleich gegen die Quelle. Der frühere Test verglich
      // FactFont.display mit 'Nunito', also eine Konstante mit ihrem eigenen
      // Literal, und hätte ein Umbenennen im pubspec nicht bemerkt.
      final families = _pubspecFontFamilies();

      expect(
        families,
        containsAll(<String>[FactFont.display, FactFont.body, FactFont.mono]),
        reason:
            'FactFont-Namen müssen den family-Einträgen in pubspec.yaml '
            'entsprechen, sonst laufen alle Texte still auf die '
            'Systemschrift zurück. In pubspec.yaml gefunden: $families',
      );
    });

    test('Gewichte entsprechen den CSS-Klassen', () {
      expect(FactTypography.bodyText.fontWeight, FontWeight.w400);
      expect(FactTypography.bodyEmphasis.fontWeight, FontWeight.w500);
      expect(FactTypography.heading.fontWeight, FontWeight.w800);
      expect(FactTypography.emphasis.fontWeight, FontWeight.w900);
      expect(FactTypography.displayTitle.fontWeight, FontWeight.w900);
    });

    test('displayTracking rechnet -0.02em in Pixel um', () {
      expect(FactTypography.displayTracking(38), closeTo(-0.76, 0.001));
      expect(FactTypography.displayTracking(16), closeTo(-0.32, 0.001));
    });
  });
}

/// Liest die `family:`-Einträge aus dem `flutter: fonts:`-Block von
/// `pubspec.yaml`. Bewusst als schlichter Textabgleich und ohne YAML-Paket:
/// die Struktur ist flach, und ein neues Paket wäre für diesen einen Test
/// nicht zu rechtfertigen.
List<String> _pubspecFontFamilies() {
  final file = File('pubspec.yaml');
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'pubspec.yaml nicht unter ${file.absolute.path} gefunden. '
        'flutter test läuft normalerweise im Paket-Wurzelverzeichnis.',
  );

  final families = <String>[];
  for (final line in file.readAsLinesSync()) {
    final match = RegExp(r'^\s*-\s*family:\s*(\S+)\s*$').firstMatch(line);
    if (match != null) {
      families.add(match.group(1)!);
    }
  }

  expect(
    families,
    isNotEmpty,
    reason: 'Im pubspec.yaml steht kein einziger family-Eintrag.',
  );
  return families;
}
