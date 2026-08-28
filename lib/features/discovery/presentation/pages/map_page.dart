import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Karten-Bildschirm (`02_Frontend/app/screen-map.jsx`).
///
/// Unter dem Top-Chrome liegt seit Schritt 12 die echte Karte. Wem die Kamera
/// gehört, ist seit dem 28.08.2026 entschieden: dem Host unter `lib/map/`.
/// Dieses Feature steuert sie nicht, es gibt über `map/domain/` Absichten ab.
///
/// ## Warum die Karte hereingereicht wird und nicht hier entsteht
///
/// [mapSurface] kommt von außen, obwohl es hier bequemer wäre, das Widget
/// selbst zu bauen. **Regel 18 des Prüfskripts lässt das nicht zu**, und zwar
/// gemessen und nicht vermutet: ein Import von
/// `package:fact_app/map/presentation/...` aus einem Feature bricht den
/// Architektur-Check mit Exit-Code 1 ab. Das ist genau die Grenze, die die
/// Kamerahoheit des Hosts absichert.
///
/// Der Ausweg ist derselbe wie bei der Audio-Präferenz auf dem
/// Startbildschirm: ein Kompositions-Adapter auf App-Ebene (Regel 10 der
/// `dependency-rules.md`). `MapRoute.build` in `lib/app/routing/app_routes.dart`
/// setzt die Kartenfläche ein, und `discovery` erfährt nicht, woraus sie
/// besteht. Von `maplibre_gl` steht in diesem Verzeichnis deshalb kein
/// einziger Import, was Regel 20 zusätzlich absichert.
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
  /// Erzeugt den Karten-Bildschirm mit der Kartenfläche [mapSurface].
  const MapPage({required this.mapSurface, super.key});

  /// Die Kartenfläche, die unter dem Top-Chrome liegt.
  ///
  /// Verpflichtend und nicht `null`-fähig: ein Standard wäre eine leere Fläche,
  /// und eine Karte, die aus Versehen fehlt, sähe dann genauso aus wie eine,
  /// die noch lädt.
  final Widget mapSurface;

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

  /// Wo die Karte steht, bis es eine gespeicherte Position gibt.
  ///
  /// Dieselbe Rückfallposition wie oben, aus derselben Zeile:
  /// `screen-map.jsx:1668` nimmt `cachedPos || { lat: 48.1351, lng: 11.5820 }`
  /// und setzt damit `center`, `zoom: 14`, `pitch: 35` und `bearing: 0`
  /// (`:1669-1682`). Sie steht hier und nicht im Karten-Host: der Host hat
  /// keine Stadt, und eine Startkamera in seinem Code wäre genau die fest
  /// verdrahtete Annahme, die Mehrstädtigkeit verbietet. Sobald
  /// `features/city` und die gespeicherte Position existieren, kommt der Wert
  /// von dort und diese Konstante fällt weg.
  static const MapCameraView placeholderCamera = MapCameraView(
    center: MapPosition(latitude: 48.1351, longitude: 11.582),
    zoom: 14,
    bearing: 0,
    pitch: 35,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(mapModeProvider);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        mapSurface,
        MapTopChrome(
          cityName: placeholderCityName,
          coins: placeholderCoins,
          level: placeholderLevel,
          levelPercent: placeholderLevelPercent,
          mode: mode,
          onModeSelected: ref.read(mapModeProvider.notifier).select,
          // Alle drei Rückrufe der Quelle bewegen die Kamera: `recenter` an
          // der Stadt-Pille (`screen-map.jsx:3105`), Neuzentrieren und harter
          // Reset am Kompass (`:3155-3186`). Sie bleiben **weiterhin** `null`,
          // und das ist jetzt eine Abgrenzung und kein fehlender Unterbau: die
          // Karte ist da, die drei Gesten gehören aber zu den Schritten 13 und
          // 14, samt der Frage, welche Absicht jede von ihnen abgibt. Ein
          // halb verdrahteter Kompass wäre schlechter als ein sichtbar
          // untätiger. Sichtbar sind sie trotzdem, und sie melden ihre Anker
          // an: das Tutorial zeigt auf den Kompass (Schritt 8).
          //
          // `isDark` bleibt beim Standard `false`, weil `mapDark` in der
          // Quelle nie `true` wird, siehe `MapTopChrome.isDark`.
        ),
      ],
    );
  }
}
