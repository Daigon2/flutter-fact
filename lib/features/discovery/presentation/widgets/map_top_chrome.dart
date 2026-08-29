/// Das Top-Chrome des Kartenbildschirms, eine geschlossene Einheit.
///
/// Nach außen trägt diese Bibliothek genau einen benutzbaren Namen,
/// [MapTopChrome]. Alles andere ist mit `@visibleForTesting` versehen und damit
/// außerhalb dieser Bibliothek und außerhalb von `test/` nicht aufrufbar.
///
/// ## Warum die Hilfstypen überhaupt einen Namen haben
///
/// Damit Tests **Rechtecke und Farben** messen können. Ohne benennbaren Typ
/// bliebe nur der Griff in den Widget-Baum über Ausdrücke wie
/// `find.byType(DecoratedBox).first`, und genau das verbietet
/// `docs/engineering/testing.md:85` („Do not assert deep widget-tree
/// implementation details"): so ein Ausdruck reißt bei jedem eingezogenen
/// `Container`, ohne dass sich am Bild etwas geändert hätte.
///
/// Nennbar heißt hier trotzdem nicht offen. `@visibleForTesting` ist keine
/// Konvention, sondern wird über Gate 2 durchgesetzt: eine Probe unter
/// `lib/app/`, die einen dieser Typen benutzt, lässt `dart analyze` mit
/// `invalid_use_of_visible_for_testing_member` und Exit-Code 2 abbrechen.
/// Gemessen, nicht angenommen.
///
/// Vier der sichtbaren Bauteile brauchen dafür gar keinen Typ: Coin-Pille,
/// Kompass und die beiden Modus-Knöpfe tragen einen [AnchorTarget], und die
/// Tests greifen sie über die Anker-Registry (`coins`, `compass`,
/// `mode-fact-finder`, `mode-tour`). Ein Anker ist die bessere Kante, weil ihn
/// auch das Tutorial benutzt: er ist bereits Vertrag, nicht Testkrücke.
///
/// ## Warum `part` und nicht neun eigene Dateien
///
/// Weil die Sichtbarkeitsgrenze in Dart die **Bibliothek** ist, nicht die
/// Datei. Als `part` bleiben `_Blurred`, `_fullRadius`, `_blurStrong`,
/// `_blurLight` und `_softShadow` privat, obwohl sie über mehrere dieser
/// Dateien hinweg gebraucht werden. Wären es neun eigenständige Bibliotheken,
/// hätten genau diese fünf öffentlich werden müssen, um geteilt werden zu
/// können: die Aufteilung hätte die Einheit aufgebrochen, statt sie zu ordnen.
/// (`_accentRed` und `_MapModeButton` sind davon nicht betroffen, sie stehen
/// jeweils in derselben Datei wie ihr einziger Nutzer.)
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'map_top_chrome/map_chrome_palette.dart';
part 'map_top_chrome/map_chrome_surface.dart';
part 'map_top_chrome/map_city_pill.dart';
part 'map_top_chrome/map_coin_pill.dart';
part 'map_top_chrome/map_compass_button.dart';
part 'map_top_chrome/map_level_badge.dart';
part 'map_top_chrome/map_mode_toggle.dart';
part 'map_top_chrome/map_notification_dot.dart';
part 'map_top_chrome/map_top_right_column.dart';

/// Die Bedienelemente, die oben über der Karte schweben.
///
/// Pendant zu vier Blöcken aus `02_Frontend/app/screen-map.jsx`:
///
/// | Element | Quelle | z-index | Anker |
/// |---|---|---|---|
/// | Stadt-Pille | `:3105-3116` | 50 | keiner |
/// | Coin-Pille | `:707-728` | 40 | `coins` |
/// | Level-Ring | `:730-745` | 40 | keiner |
/// | Kompass-Knopf | `:3152-3199` | 30 | `compass` |
/// | Modus-Umschalter | `:3203-3241` | 30 | `mode-fact-finder`, `mode-tour` |
///
/// ## Dieses Widget weiß nichts von einer Karte
///
/// Kein Import eines Kartenpakets, keine Kamera, keine Koordinaten. Alles, was
/// in der Quelle aus der Karte kommt, kommt hier als Parameter herein:
/// [cityName] (dort `detectCity(mapCenter)`, `:3006`), [bearingDegrees] (dort
/// `map.getBearing()`, `:1792`) und die drei Rückrufe. Das ist keine
/// Vorsichtsmaßnahme, sondern die Bedingung, unter der dieser Schritt gebaut
/// werden konnte, bevor es den Karten-Host gab. Sie gilt weiter: der Host lebt
/// seit dem 28.08.2026 unter `lib/map/`, und ein Feature sieht davon nur
/// `map/domain/` (Regel 18).
///
/// ## Bezugskante ist die sichere Fläche, nicht der Bildschirmrand
///
/// Alle `top`-Werte der Quelle zählen ab der Oberkante der `.app-frame`, und
/// die liegt unterhalb der Notch: `index.html:101-107` setzt
/// `padding-top: env(safe-area-inset-top)` am **`body`**. Deshalb die
/// [SafeArea] nur oben. Links und rechts setzt die Quelle keinen Inset, also
/// zählen `left: 14` und `right: 14` dort ab der echten Gerätekante.
///
/// ## Was hier bewusst fehlt
///
/// - **Die Münz-Abzugsanimation** (`:3140-3151`). Sie hängt an `coinDelta`,
///   das nur beim Kauf eines Jagd-Hinweises entsteht. Werte für den Nachbau:
///   `top: 62`, `right: 58`, Nunito 900/16, `#E8380D`, `coinDeduct 0.85s`.
/// - **Der Nähe-Toast** (`:3122-3136`). Er zählt ungesammelte Fakten im
///   Kilometer-Umkreis, braucht also Fakten und GPS.
/// - **Die Münzdrehung** `coinFlip`. Sie liefe endlos und ließe jedes
///   `pumpAndSettle` hängen. Zur Quelle gehört eine Falle: `coinFlip` ist
///   **zweimal** definiert, `styles.css:249` staucht per `scaleX`,
///   `index.html:32` dreht per `rotateY`. Der Inline-Block steht nach dem
///   Stylesheet (`index.html:15-16`), bei gleichnamigen `@keyframes` gewinnt
///   die letzte Definition: es ist die Drehung. Derselbe Fallentyp wie bei
///   `slideUp` in Schritt 7.
/// - **Das Verstecken des Umschalters während einer laufenden Jagd**
///   (`:3203`, `{!activeHunt && ...}`). Den Zustand gibt es im Neubau nicht.
class MapTopChrome extends ConsumerWidget {
  /// Erzeugt das Top-Chrome.
  const MapTopChrome({
    required this.cityName,
    required this.coins,
    required this.level,
    required this.levelPercent,
    required this.mode,
    required this.onModeSelected,
    this.onCityTap,
    this.onCompassTap,
    this.onCompassLongPress,
    this.bearingDegrees = 0,
    this.isCompassDead = false,
    this.tourReady = false,
    this.isDark = false,
    super.key,
  });

  /// Seitenabstand von Stadt-Pille und rechter Spalte, `screen-map.jsx:3105`
  /// und `:705`.
  static const double sideInset = 14;

  /// Oberkante der Stadt-Pille, `screen-map.jsx:3105`.
  static const double cityTop = 54;

  /// Oberkante der rechten Spalte, `screen-map.jsx:705`.
  static const double topRightColumnTop = 60;

  /// Oberkante des Modus-Umschalters, `screen-map.jsx:3204`.
  static const double modeToggleTop = 136;

  /// Oberkante des Kompass-Knopfes, `screen-map.jsx:3152`.
  ///
  /// Nur als Zusicherung: gesetzt wird sie nicht, sie **ergibt** sich aus der
  /// rechten Spalte, siehe [MapTopRightColumn].
  static const double compassTop = 148;

  /// Kantenlänge des Kompass-Knopfes, `btnStyle` in `screen-map.jsx:3027`.
  static const double compassSize = 44;

  /// Wie lange gedrückt werden muss, damit aus dem Tipp ein langer Druck wird.
  ///
  /// `screen-map.jsx:3173`: der `setTimeout` im `onPointerDown` läuft **700
  /// Millisekunden**, und `onPointerUp` behandelt alles davor als kurzen Druck
  /// (`:3175-3185`).
  ///
  /// **Flutters Standard ist ein anderer**, `kLongPressTimeout` steht auf 500
  /// (`flutter/lib/src/gestures/constants.dart:29`). Bis Schritt 13 fiel das
  /// nicht auf, weil beide Rückrufe `null` waren und keine Geste irgendwo
  /// ankam. `GestureDetector` lässt die Dauer nicht einstellen, deshalb steht
  /// im Kompass-Knopf ein `RawGestureDetector` mit
  /// `LongPressGestureRecognizer(duration: ...)`.
  static const Duration compassLongPressDuration = Duration(milliseconds: 700);

  /// Wie viel Platz die rechte Spalte dem Umschalter links und rechts frei
  /// hält.
  ///
  /// **Kein Wert der Quelle.** Dort sind Umschalter und rechte Spalte zwei
  /// unabhängige absolute Kästen, die sich bei fester Schriftgröße nie
  /// erreichen. Mit der Systemschrift auf 2.0 erreichen sie sich sehr wohl,
  /// und ein `Stack` schneidet dabei lautlos.
  ///
  /// Reserviert sind [sideInset], die Kompasskachel als breitestes Element der
  /// rechten Spalte im Höhenband des Umschalters, und acht Pixel Luft. Wird
  /// der Umschalter breiter, verkleinert er sich als Ganzes, siehe [build].
  static const double modeToggleSideBand = sideInset + compassSize + 8;

  /// Name der Stadt unter der Kartenmitte, `screen-map.jsx:3114`.
  final String cityName;

  /// Der Münzstand, `screen-map.jsx:727`.
  final int coins;

  /// Die Levelnummer, `screen-map.jsx:741`.
  final int level;

  /// Fortschritt im Level in Prozent, `screen-map.jsx:732`.
  final double levelPercent;

  /// Der gerade aktive Modus.
  final MapMode mode;

  /// Wird beim Antippen eines Modus gerufen, auch wenn er schon aktiv ist.
  final ValueChanged<MapMode> onModeSelected;

  /// Tipp auf die Stadt-Pille, in der Quelle `recenter` (`:3106`).
  ///
  /// `null` heißt: kein Zeiger, kein Tipp. Das ist der Zustand, den die Quelle
  /// ohne GPS-Position ebenfalls zeigt (`cursor: userPos ? 'pointer' :
  /// 'default'`, `:3112`).
  final VoidCallback? onCityTap;

  /// Kurzer Tipp auf den Kompass, in der Quelle Neuzentrieren (`:3175-3185`).
  final VoidCallback? onCompassTap;

  /// Langer Druck auf den Kompass, in der Quelle der harte Reset der Kamera
  /// (`:3158-3174`).
  final VoidCallback? onCompassLongPress;

  /// Blickrichtung der Karte in Grad. Die Nadel dreht dagegen, `:1792`
  /// (`rotate(${-map.getBearing()}deg)`).
  final double bearingDegrees;

  /// Ob der Gerätekompass seit fünf Sekunden nichts mehr gemeldet hat,
  /// `screen-map.jsx:1358`.
  final bool isCompassDead;

  /// Ob eine Tour vorbereitet ist. Setzt den roten Punkt auf den Tour-Knopf,
  /// `screen-map.jsx:3227`.
  final bool tourReady;

  /// Ob die dunkle Fassung gezeichnet wird.
  ///
  /// In der Quelle `mapDark`. Der Zweig existiert dort vollständig und wird
  /// **nie erreicht**: `screen-map.jsx:1353` setzt den Zustand auf `false`,
  /// und es gibt in der ganzen Datei kein `setMapDark`. Die Karte zwingt ihren
  /// Rahmen zusätzlich auf hell (`:3081`), unabhängig vom App-Theme. Deshalb
  /// hängt diese Fassung **nicht** an `Theme.of(context).brightness`: das wäre
  /// eine Kopplung, die die Quelle nicht hat.
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final palette = isDark ? MapChromePalette.dark : MapChromePalette.light;

    return SafeArea(
      left: false,
      right: false,
      bottom: false,
      child: Stack(
        children: <Widget>[
          // Reihenfolge = Malreihenfolge = z-index der Quelle, von hinten nach
          // vorn. Der Umschalter liegt auf 30, die Stadt-Pille auf 50: bei
          // sehr großer Systemschrift berühren sich beide, und dann deckt die
          // Stadt-Pille, genau wie im Browser.
          Positioned(
            top: modeToggleTop,
            left: modeToggleSideBand,
            right: modeToggleSideBand,
            child: Center(
              // `BoxFit.scaleDown` und nicht Kürzen: der Umschalter wächst mit
              // der Systemschrift, bis er an das freie Band stößt, und wird
              // dann als Ganzes verkleinert. Zwei gekürzte Beschriftungen
              // ("🔍 Fact Fi…") wären die schlechtere Antwort, und ohne
              // Begrenzung liefe er bei Skalierung 2.0 unter den Kompass.
              // Gemessen: bei Skalierung 1.0 ist er 196,8 breit und wird nicht
              // angefasst, bei 2.0 auf 360 Pixeln misst er 296,2 und wird auf
              // die 228 des Bandes gebracht.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MapModeToggle(
                  palette: palette,
                  mode: mode,
                  tourReady: tourReady,
                  onSelected: onModeSelected,
                  labelFor: (mapMode) => strings.text(mapMode.labelKey),
                ),
              ),
            ),
          ),
          Positioned(
            top: cityTop,
            left: sideInset,
            right: sideInset,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Die rechte Spalte an den rechten Rand, die Stadt-Pille an den
              // linken. Ohne das säße die Spalte direkt neben der Pille und
              // wanderte mit der Länge des Stadtnamens.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // `Flexible` und nicht `Expanded`: die Pille ist so breit wie
                // ihr Text und weicht erst, wenn die rechte Spalte den Platz
                // braucht. In der Quelle laufen beide Kästen ineinander, weil
                // dort keine Schrift mitwächst.
                Flexible(
                  child: Padding(
                    // Mindestabstand zur rechten Spalte. Kein Wert der Quelle:
                    // dort stehen beide Kästen absolut und dürfen sich
                    // überlagern.
                    padding: const EdgeInsets.only(right: 8),
                    child: MapCityPill(
                      palette: palette,
                      name: cityName,
                      onTap: onCityTap,
                      tooltip: strings.text('map.myLocation'),
                    ),
                  ),
                ),
                Padding(
                  // Die Stadt-Pille beginnt bei 54, die rechte Spalte bei 60.
                  padding: const EdgeInsets.only(
                    top: topRightColumnTop - cityTop,
                  ),
                  child: MapTopRightColumn(
                    palette: palette,
                    coins: coins,
                    level: level,
                    levelPercent: levelPercent,
                    bearingDegrees: bearingDegrees,
                    isCompassDead: isCompassDead,
                    onCompassTap: onCompassTap,
                    onCompassLongPress: onCompassLongPress,
                    compassTooltip:
                        strings.text('map.myLocation') +
                        strings.text(
                          isCompassDead
                              ? 'map.compassOffLongPress'
                              : 'map.longPressReset',
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
