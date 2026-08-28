import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/routing/app_router.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/core/anchors/anchor_scope.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wurzel-Widget. Hält ausschließlich Routing, Theme und Localization
/// zusammen. Fachlogik hat hier nichts zu suchen.
class FactApp extends ConsumerWidget {
  const FactApp({super.key});

  /// Einmal aufgebaut, nicht bei jedem Rebuild: `MaterialApp` sucht in dieser
  /// Liste nach der passenden Sprache.
  static final List<Locale> _supportedLocales = AppLanguage.values
      .map((language) => Locale(language.code))
      .toList(growable: false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(appLanguageProvider);

    return MaterialApp.router(
      title: 'FACT',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Der Anker-Scope liegt über allem, was der Router baut, und ist damit
      // die Bezugsfläche für jedes Overlay, das auf ein Bedienelement zeigt.
      //
      // Warum hier und nicht in `app/shell/`: die Bezugsfläche der Quelle ist
      // die `.app-frame` (`screen-tour.jsx:185-186`), also der ganze Rahmen und
      // nicht nur der Tab-Bereich. Und die Placement rules in
      // `docs/architecture/project-structure.md` verbieten `app/shell/`
      // ausdrücklich jeden Feature-Import; die Liste der bekannt fehlenden
      // Anker kommt aber aus `features/discovery`. `app.dart` ist
      // App-Komposition und darf das.
      //
      // `builder` und nicht ein Widget um `MaterialApp.router` herum: der
      // Scope muss **unterhalb** des Navigators liegen, sonst wäre seine
      // Bezugsfläche der Bildschirm statt des dargestellten Rahmens.
      builder: (context, child) => AnchorScope(
        knownMissingAnchors: DiscoveryAnchors.knownMissing,
        // `child` ist bei `MaterialApp.router` nur in Ausnahmefällen null;
        // ein `SizedBox.shrink()` ist dann die ehrlichere Antwort als ein `!`.
        child: child ?? const SizedBox.shrink(),
      ),
      // Die App-Texte kommen aus `app/localization`, nicht von hier.
      // `flutter_localizations` liefert nur die Rahmentexte von Material und
      // Cupertino sowie Datums- und Zahlenformate in der gewählten Sprache.
      locale: Locale(language.code),
      supportedLocales: _supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: FactTheme.light(),
      darkTheme: FactTheme.dark(),
      // Die PWA startet hell, nicht dunkel: `storage.jsx:117` liefert
      // `'light'`, wenn `localStorage` leer ist, `app.jsx:74` nimmt das als
      // Startwert und `chrome.jsx:133` setzt daraus die Theme-Klasse. Dass
      // `:root` in `styles.css` die dunklen Werte trägt, ändert daran nichts,
      // weil `.theme-light` beim ersten Start ohnehin greift.
      //
      // Bis die Theme-Präferenz aus `features/settings` kommt, bleibt es hell
      // statt dem Systemwert zu folgen, damit die App startet wie die PWA.
      themeMode: ThemeMode.light,
    );
  }
}
