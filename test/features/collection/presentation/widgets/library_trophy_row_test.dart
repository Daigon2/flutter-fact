import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/generated/app_strings_de.g.dart';
import 'package:fact_app/app/localization/generated/app_strings_en.g.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/collection/presentation/library_look.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_trophy_row.dart';
import 'package:fact_app/features/progression/application/trophy_catalog.dart';
import 'package:fact_app/features/progression/domain/entities/trophy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_fonts.dart';

/// Die Trophäenzeile des Reiseführers,
/// `02_Frontend/app/screen-wallet.jsx:1032-1075`.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpRow(
    WidgetTester tester, {
    Set<String> unlockedKeys = const <String>{},
    AppLanguage language = AppLanguage.de,
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
        ],
        child: MaterialApp(
          theme: theme ?? FactTheme.light(),
          home: Scaffold(body: LibraryTrophyRow(unlockedKeys: unlockedKeys)),
        ),
      ),
    );
    await tester.pump();
  }

  BoxDecoration decorationOf(WidgetTester tester, String key) =>
      tester
              .widget<Container>(find.byKey(LibraryTrophyRow.cardKey(key)))
              .decoration!
          as BoxDecoration;

  testWidgets('alle sechsunddreißig Trophäen stehen in der Zeile', (
    tester,
  ) async {
    await pumpRow(tester);

    expect(trophyCatalog.length, 36);
    for (final Trophy trophy in trophyCatalog) {
      expect(
        find.byKey(LibraryTrophyRow.cardKey(trophy.key)),
        findsOneWidget,
        reason: 'Karte ${trophy.key} fehlt',
      );
    }
    expect(find.text('0 / 36'), findsOneWidget);
  });

  testWidgets('die Beschriftung kommt aus den Daten, nicht aus i18n', (
    tester,
  ) async {
    // **Der Kern von E-73.** Die Quelle holt die Beschriftung mit
    // `t('trophy.' + tr.key, lang)`, und dreißig der sechsunddreißig
    // Schlüssel gibt es nicht; auf dem Bildschirm stehen dort rohe Schlüssel.
    // Diese drei Trophäen sind genau solche Fälle: `meister_hist`,
    // `weltenbummler` und `münchen_first` haben **keinen** i18n-Schlüssel.
    await pumpRow(tester);

    expect(find.text('Meister-Chronist'), findsOneWidget);
    expect(find.text('Weltenbummler'), findsOneWidget);
    expect(find.text('Münchner'), findsOneWidget);

    // Und der Gegenbeweis: kein roher Schlüssel steht auf dem Bildschirm.
    expect(find.text('trophy.meister_hist'), findsNothing);
    expect(find.text('meister_hist'), findsNothing);
  });

  testWidgets('der fehlende i18n-Schlüssel ist wirklich fehlend', (
    tester,
  ) async {
    // Die Zusicherung darüber wäre auch grün, wenn es den Schlüssel gäbe und
    // er zufällig denselben Text trüge. Diese hier hängt an der Lücke selbst:
    // `AppStrings` findet für `trophy.meister_hist` nichts. Ohne sie könnte
    // die Behauptung „dreißig rohe Schlüssel" stillschweigend veralten.
    expect(appTextsDe.containsKey('trophy.meister_hist'), isFalse);
    expect(appTextsEn.containsKey('trophy.meister_hist'), isFalse);
    // Einer der sechs, die es gibt, als Gegenprobe.
    expect(appTextsDe.containsKey('trophy.chronist'), isTrue);
  });

  testWidgets('die Beschriftung folgt der Sprache', (tester) async {
    await pumpRow(tester, language: AppLanguage.en);

    expect(find.text('Master Chronicler'), findsOneWidget);
    expect(find.text('Globetrotter'), findsOneWidget);
    expect(find.text('Recently earned'.toUpperCase()), findsOneWidget);
  });

  testWidgets('eine verdiente Trophäe trägt den Creme-Verlauf', (tester) async {
    await pumpRow(tester, unlockedKeys: <String>{'chronist'});

    final BoxDecoration earned = decorationOf(tester, 'chronist');
    expect(earned.color, isNull);
    expect(
      (earned.gradient! as LinearGradient).colors,
      libraryTrophyEarnedColors,
    );
    expect(earned.border, Border.all(color: libraryTrophyEarnedBorderColor));

    final BoxDecoration locked = decorationOf(tester, 'steinleser');
    expect(locked.color, libraryTrophyLockedColor);
    expect(locked.gradient, isNull);

    expect(find.text('1 / 36'), findsOneWidget);
  });

  testWidgets('die Reihenfolge ist die der Definition, nicht Verdiente zuerst', (
    tester,
  ) async {
    // Der Profil-Bildschirm sortiert Verdiente nach vorn
    // (`screen-profil.jsx:216`), diese Zeile nicht (`screen-wallet.jsx:1049`).
    // Deshalb liest sie `trophyCatalog` und nicht `trophiesInDisplayOrder`.
    await pumpRow(tester, unlockedKeys: <String>{'legende'});

    final double firstCard = tester
        .getTopLeft(
          find.byKey(LibraryTrophyRow.cardKey(trophyCatalog.first.key)),
        )
        .dx;
    final double unlockedCard = tester
        .getTopLeft(find.byKey(LibraryTrophyRow.cardKey('legende')))
        .dx;

    expect(unlockedCard, greaterThan(firstCard));
  });

  testWidgets('im dunklen Theme bleibt die Beschriftung lesbar', (
    tester,
  ) async {
    // **Der Kern von E-77.** Die Quelle setzt den Kartengrund hart auf `#fff`
    // und die Schrift auf `tok.ink`, im dunklen Theme also `#F5F0E8`: weiß
    // auf weiß, alle sechsunddreißig Beschriftungen unlesbar. Hier folgt die
    // Schriftfarbe der Karte und nicht dem App-Theme.
    await pumpRow(tester, theme: FactTheme.dark());

    final Text label = tester.widget<Text>(find.text('Chronist'));

    expect(label.style!.color, FactColors.light.ink);
    expect(label.style!.color, isNot(FactColors.dark.ink));
    // Und der Grund ist derselbe wie im hellen Theme, sonst wäre die Prüfung
    // oben ohne Gegenstand.
    expect(decorationOf(tester, 'chronist').color, libraryTrophyLockedColor);
  });

  testWidgets('das Zeichen einer gesperrten Trophäe ist abgeblendet', (
    tester,
  ) async {
    await pumpRow(tester, unlockedKeys: <String>{'chronist'});

    final Finder lockedGlyph = find.descendant(
      of: find.byKey(LibraryTrophyRow.cardKey('steinleser')),
      matching: find.byType(Opacity),
    );
    final Finder earnedGlyph = find.descendant(
      of: find.byKey(LibraryTrophyRow.cardKey('chronist')),
      matching: find.byType(Opacity),
    );

    expect(
      tester.widget<Opacity>(lockedGlyph).opacity,
      libraryTrophyLockedGlyphOpacity,
    );
    expect(tester.widget<Opacity>(earnedGlyph).opacity, 1);
  });

  testWidgets('nur die verdiente Karte trägt den Goldschatten am Zeichen', (
    tester,
  ) async {
    await pumpRow(tester, unlockedKeys: <String>{'chronist'});

    final Text earned = tester.widget<Text>(
      find.descendant(
        of: find.byKey(LibraryTrophyRow.cardKey('chronist')),
        matching: find.text('§'),
      ),
    );
    final Text locked = tester.widget<Text>(
      find.descendant(
        of: find.byKey(LibraryTrophyRow.cardKey('steinleser')),
        matching: find.text('⌂'),
      ),
    );

    expect(earned.style!.shadows, isNotNull);
    expect(locked.style!.shadows, isNull);
  });
}
