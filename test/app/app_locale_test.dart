import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flutter_localizations` trägt nicht die App-Texte, aber die Rahmentexte von
/// Material und Cupertino sowie Datums- und Zahlenformate. Diese Verdrahtung
/// muss der aktiven Sprache folgen, sonst steht die halbe Oberfläche auf
/// Deutsch und der Dialog-Abbrechen-Knopf auf Englisch.
void main() {
  Future<void> pumpApp(WidgetTester tester, AppLanguage language) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(language),
          ),
          // Vorbedingung: ohne das startet die App auf dem Startbildschirm,
          // und dessen Dauer-Animationen lassen `pumpAndSettle` auflaufen.
          firstLaunchStoreProvider.overrideWithValue(
            InMemoryFirstLaunchStore(hasLaunched: true),
          ),
        ],
        child: const FactApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Locale folgt der aktiven Sprache', (tester) async {
    await pumpApp(tester, AppLanguage.en);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('en'));
    expect(app.supportedLocales, contains(const Locale('de')));
  });

  testWidgets('Material-Rahmentexte kommen auf Deutsch', (tester) async {
    await pumpApp(tester, AppLanguage.de);

    final context = tester.element(find.byType(Scaffold));
    expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Abbrechen');
  });
}
