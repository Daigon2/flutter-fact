import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Karten-Bildschirm (`02_Frontend/app/screen-map.jsx`).
///
/// **Die Karte selbst fehlt noch.** Wo der Karten-Host lebt und wem die Kamera
/// gehört, ist seit dem 28.08.2026 entschieden: der Host liegt unter
/// `lib/map/`, ihm gehört die Kamera, und dieses Feature gibt ihm über
/// `map/domain/` Absichten. Gebaut ist davon noch nichts, deshalb liegt unter
/// dem Top-Chrome weiter eine einfarbige Fläche in der Kartenfarbe des Themes.
/// Das Top-Chrome hängt am Host nicht, siehe [MapTopChrome].
///
/// ## Die Platzhalterwerte, und warum sie so und nicht anders lauten
///
/// Drei Zahlen und ein Name gehören Domänen, die es noch nicht gibt. Keine
/// davon ist erfunden; jede ist der Wert, den die PWA bei frischem Zustand
/// selbst anzeigt:
///
/// | Wert | Herkunft |
/// |---|---|
/// | [placeholderCoins] | `storage.jsx:45`, `load('coins', 0)` |
/// | [placeholderLevel] | `storage.jsx:229-236` mit XP 0 ergibt `FACT_LEVELS[0]` |
/// | [placeholderLevelPercent] | dieselbe Rechnung: `(0 - 0) / (50 - 0) * 100` |
/// | [placeholderCityName] | `screen-map.jsx:3008`, `CITIES[0]` ohne Kartenmitte |
///
/// Sie verschwinden, sobald `features/progression` und `features/city`
/// entstehen. Bis dahin steht hier ausdrücklich ein Platzhalter und keine
/// stille Annahme.
class MapPage extends ConsumerWidget {
  /// Erzeugt den Karten-Bildschirm.
  const MapPage({super.key});

  /// Münzstand ohne `features/progression`.
  static const int placeholderCoins = 0;

  /// Levelnummer ohne `features/progression`.
  static const int placeholderLevel = 1;

  /// Fortschritt im Level ohne `features/progression`, in Prozent.
  static const double placeholderLevelPercent = 0;

  /// Stadtname ohne Kartenmitte und ohne `features/city`.
  ///
  /// Das ist die Rückfallstadt der Quelle, nicht eine fest verdrahtete
  /// Annahme: `detectCity` läuft über zwölf Städte (`screen-map.jsx:310-322`),
  /// und ohne Kartenmitte und ohne GPS nimmt der Bildschirm die erste
  /// (`:3006-3008`). Mehrstädtigkeit bleibt damit erhalten, [MapTopChrome]
  /// bekommt den Namen von außen.
  static const String placeholderCityName = 'München';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(mapModeProvider);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Platzhalter für die Kartenfläche. `--map-bg` aus `styles.css`, damit
        // die Farbe schon jetzt aus dem Theme kommt und nicht aus einer
        // Wegwerf-Konstante.
        ColoredBox(color: context.factColors.mapBg),
        MapTopChrome(
          cityName: placeholderCityName,
          coins: placeholderCoins,
          level: placeholderLevel,
          levelPercent: placeholderLevelPercent,
          mode: mode,
          onModeSelected: ref.read(mapModeProvider.notifier).select,
          // Alle drei Rückrufe der Quelle bewegen die Kamera: `recenter` an
          // der Stadt-Pille (`screen-map.jsx:3105`), Neuzentrieren und harter
          // Reset am Kompass (`:3155-3186`). Solange es keinen Karten-Host
          // gibt, ist nichts zu bewegen: sie bleiben `null` und die Elemente
          // reagieren
          // nicht auf einen Tipp. Sichtbar sind sie trotzdem, und sie melden
          // ihre Anker an: das Tutorial zeigt auf den Kompass (Schritt 8).
          //
          // `isDark` bleibt beim Standard `false`, weil `mapDark` in der
          // Quelle nie `true` wird, siehe `MapTopChrome.isDark`.
        ),
      ],
    );
  }
}
