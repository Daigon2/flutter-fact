import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/anchors/anchor_target.dart';
import 'package:fact_app/features/discovery/presentation/discovery_anchors.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Bedienelemente, die oben über der Karte schweben.
///
/// Pendant zu vier Blöcken aus `02_Frontend/app/screen-map.jsx`:
///
/// | Element | Quelle | z-index | Anker |
/// |---|---|---|---|
/// | Stadt-Pille | `:3103-3115` | 50 | keiner |
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
/// Vorsichtsmaßnahme, sondern die Bedingung, unter der dieser Schritt vor der
/// offenen Entscheidung über den Karten-Host gebaut werden konnte.
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

  /// Seitenabstand von Stadt-Pille und rechter Spalte, `screen-map.jsx:3103`
  /// und `:706`.
  static const double sideInset = 14;

  /// Oberkante der Stadt-Pille, `screen-map.jsx:3103`.
  static const double cityTop = 54;

  /// Oberkante der rechten Spalte, `screen-map.jsx:706`.
  static const double topRightColumnTop = 60;

  /// Oberkante des Modus-Umschalters, `screen-map.jsx:3205`.
  static const double modeToggleTop = 136;

  /// Oberkante des Kompass-Knopfes, `screen-map.jsx:3152`.
  ///
  /// Nur als Zusicherung: gesetzt wird sie nicht, sie **ergibt** sich aus der
  /// rechten Spalte, siehe [MapTopRightColumn].
  static const double compassTop = 148;

  /// Kantenlänge des Kompass-Knopfes, `btnStyle` in `screen-map.jsx:3027`.
  static const double compassSize = 44;

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

  /// Die Levelnummer, `screen-map.jsx:744`.
  final int level;

  /// Fortschritt im Level in Prozent, `screen-map.jsx:733`.
  final double levelPercent;

  /// Der gerade aktive Modus.
  final MapMode mode;

  /// Wird beim Antippen eines Modus gerufen, auch wenn er schon aktiv ist.
  final ValueChanged<MapMode> onModeSelected;

  /// Tipp auf die Stadt-Pille, in der Quelle `recenter` (`:3105`).
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

/// Die Stadt-Pille links oben, `screen-map.jsx:3103-3115`.
class MapCityPill extends StatelessWidget {
  /// Erzeugt die Stadt-Pille.
  const MapCityPill({
    required this.palette,
    required this.name,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Der angezeigte Stadtname.
  final String name;

  /// Beschriftung für die Sprachausgabe, `title` in der Quelle (`:3105`).
  final String tooltip;

  /// Tipp auf die Pille. `null` heißt: nicht antippbar.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = _Blurred(
      // `borderRadius: 12`, `:3109`.
      radius: 12,
      sigma: _blurStrong,
      background: palette.background,
      border: palette.border,
      shadow: _softShadow,
      // `padding: '8px 15px'`, `:3109`.
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Text(
        name,
        // `fontFamily: 'Nunito', fontWeight: 900, fontSize: 24`, `:3110`.
        style: FactTypography.emphasis.copyWith(
          fontSize: 24,
          color: palette.text,
        ),
        maxLines: 1,
        // Die Quelle kennt keinen Überlauf, weil ihre Schrift nicht mitwächst.
        // Hier schon: eine gekürzte Stadt ist besser als eine, die unter der
        // Coin-Pille verschwindet.
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );

    if (onTap == null) {
      return pill;
    }
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: pill,
      ),
    );
  }
}

/// Coin-Pille, Level-Ring und Kompass in einer Spalte.
///
/// ## Warum eine Spalte und nicht drei absolute Kästen
///
/// Die Quelle setzt `top: 60` für den XP-Streifen (`:706`) und `top: 148` für
/// den Kompass (`:3152`). Beide Zahlen passen nur zueinander, solange die
/// Schrift nicht mitwächst: bei Systemschrift 2.0 ist der Streifen hoch genug,
/// um unter dem Kompass zu liegen, und ein `Stack` meldet das nicht, er
/// zeichnet einfach übereinander.
///
/// In einer Spalte **ergibt** sich die Kompassposition. Bei Skalierung 1.0
/// kommt exakt die 148 der Quelle heraus, nachgerechnet und per Test
/// zugesichert: 60 + 32 (Coin-Pille) + 6 (`gap`, `:706`) + 42 (Level-Ring,
/// `:731`) + 8. Die Höhe 32 der Coin-Pille ist 4 + 22 + 4 plus zwei mal ein
/// Pixel Rahmen; `box-sizing: border-box` aus `styles.css:109` ändert daran
/// nichts, weil die Pille keine gesetzte Höhe hat. Die letzten 8 sind der
/// Rest, und sie sind zugleich der `gap: 8`, den die Quelle der
/// Kompass-Spalte selbst gibt (`:3151`).
class MapTopRightColumn extends StatelessWidget {
  /// Erzeugt die rechte Spalte.
  const MapTopRightColumn({
    required this.palette,
    required this.coins,
    required this.level,
    required this.levelPercent,
    required this.bearingDegrees,
    required this.isCompassDead,
    required this.compassTooltip,
    required this.onCompassTap,
    required this.onCompassLongPress,
    super.key,
  });

  /// `gap: 6` zwischen Coin-Pille und Level-Ring, `screen-map.jsx:706`.
  static const double coinToLevelGap = 6;

  /// Abstand zwischen Level-Ring und Kompass, siehe Klassenkommentar.
  static const double levelToCompassGap = 8;

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Der Münzstand.
  final int coins;

  /// Die Levelnummer.
  final int level;

  /// Fortschritt im Level in Prozent.
  final double levelPercent;

  /// Blickrichtung der Karte in Grad.
  final double bearingDegrees;

  /// Ob der Gerätekompass stumm ist.
  final bool isCompassDead;

  /// Beschriftung des Kompass-Knopfes für die Sprachausgabe.
  final String compassTooltip;

  /// Kurzer Tipp auf den Kompass.
  final VoidCallback? onCompassTap;

  /// Langer Druck auf den Kompass.
  final VoidCallback? onCompassLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      // `alignItems: 'flex-end'`, `screen-map.jsx:706`.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        MapCoinPill(palette: palette, coins: coins),
        const SizedBox(height: coinToLevelGap),
        MapLevelBadge(palette: palette, level: level, percent: levelPercent),
        const SizedBox(height: levelToCompassGap),
        MapCompassButton(
          palette: palette,
          bearingDegrees: bearingDegrees,
          isDead: isCompassDead,
          tooltip: compassTooltip,
          onTap: onCompassTap,
          onLongPress: onCompassLongPress,
        ),
      ],
    );
  }
}

/// Die Coin-Pille, `screen-map.jsx:707-728`. Trägt den Anker `coins`.
class MapCoinPill extends StatelessWidget {
  /// Erzeugt die Coin-Pille.
  const MapCoinPill({required this.palette, required this.coins, super.key});

  /// Durchmesser der Münze, `screen-map.jsx:717`.
  static const double discSize = 22;

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Der angezeigte Münzstand.
  final int coins;

  @override
  Widget build(BuildContext context) {
    // Der Anker sitzt außen an der Pille, wie `data-tour-anchor` in der Quelle
    // (`:708`). Weiter innen gesetzt, umschlösse der Leuchtring nur die Zahl.
    return AnchorTarget(
      anchorId: DiscoveryAnchors.coins,
      child: _Blurred(
        // `borderRadius: 999`, `:712`.
        radius: _fullRadius,
        sigma: _blurLight,
        background: palette.coinPillBackground,
        border: palette.coinPillBorder,
        shadow: _softShadow,
        // `padding: '4px 10px 4px 4px'`, `:713`.
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: discSize,
              height: discSize,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                // `linear-gradient(145deg,#FFE066,#F5C518)`, `:719`. CSS misst
                // 0 Grad nach oben und dreht im Uhrzeigersinn; die beiden
                // Ausrichtungen unten sind derselbe Vektor. Die
                // Gradientenlänge weicht bei CSS geringfügig ab, auf 22 Pixeln
                // ist das nicht sichtbar.
                gradient: LinearGradient(
                  begin: Alignment(-0.574, -0.819),
                  end: Alignment(0.574, 0.819),
                  colors: <Color>[Color(0xFFFFE066), Color(0xFFF5C518)],
                ),
                // `boxShadow: '0 2px 0 #C49A0A'`, `:720`.
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0xFFC49A0A), offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                // Kein Fall für `AppStrings`: das "F" ist die Prägung der
                // Münze, kein Text. Die Quelle schreibt es in beiden Sprachen
                // hart (`:723`).
                'F',
                style: FactTypography.emphasis.copyWith(
                  // `fontWeight: 900, fontSize: 11, color: '#7A5C00'`, `:722`.
                  fontSize: 11,
                  color: const Color(0xFF7A5C00),
                ),
                // Die Prägung wächst nicht mit der Systemschrift: sie sitzt in
                // einer 22 Pixel großen Scheibe mit fester Größe, und eine
                // mitwachsende Glyphe darin wäre abgeschnitten statt größer.
                textScaler: TextScaler.noScaling,
              ),
            ),
            // `gap: 5`, `:711`.
            const SizedBox(width: 5),
            Text(
              '$coins',
              // `fontWeight: 900, fontSize: 13, color: '#F5C518'`, `:727`.
              style: FactTypography.emphasis.copyWith(
                fontSize: 13,
                color: const Color(0xFFF5C518),
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Der Level-Ring, `screen-map.jsx:730-745`.
class MapLevelBadge extends StatelessWidget {
  /// Erzeugt den Level-Ring.
  const MapLevelBadge({
    required this.palette,
    required this.level,
    required this.percent,
    super.key,
  });

  /// Außenmaß, `screen-map.jsx:731`. Die Quelle setzt dort ausdrücklich
  /// `boxSizing: 'border-box'`, der Innenabstand liegt also innerhalb der 42.
  static const double size = 42;

  /// `padding: 3`, `screen-map.jsx:734`.
  static const double ringWidth = 3;

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Die angezeigte Levelnummer.
  final int level;

  /// Fortschritt im Level in Prozent, 0 bis 100.
  final double percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // `conic-gradient(#F5C518 ${levelPct * 3.6}deg, <track> 0deg)`,
          // `:733`. Zwei harte Stopps an derselben Stelle ergeben die Kante.
          // CSS beginnt oben und dreht im Uhrzeigersinn, `SweepGradient`
          // beginnt rechts, daher die Vierteldrehung zurück.
          gradient: SweepGradient(
            colors: <Color>[const Color(0xFFF5C518), palette.levelTrack],
            stops: <double>[percent / 100, percent / 100],
            transform: const GradientRotation(-math.pi / 2),
          ),
          // `boxShadow: '0 2px 8px rgba(0,0,0,0.18)'`, `:735`.
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x2E000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(ringWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.levelInnerBackground,
            ),
            child: Center(
              child: Text(
                '$level',
                // `fontWeight: 900, fontSize: 15`, `:741`.
                style: FactTypography.emphasis.copyWith(
                  fontSize: 15,
                  color: palette.levelText,
                ),
                // Wie die Münzprägung: feste Scheibe, feste Ziffer.
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Der Kompass-Knopf, `screen-map.jsx:3152-3199`. Trägt den Anker `compass`.
class MapCompassButton extends StatelessWidget {
  /// Erzeugt den Kompass-Knopf.
  const MapCompassButton({
    required this.palette,
    required this.bearingDegrees,
    required this.isDead,
    required this.tooltip,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Blickrichtung der Karte in Grad; die Nadel dreht dagegen.
  final double bearingDegrees;

  /// Ob der Gerätekompass stumm ist.
  final bool isDead;

  /// Beschriftung für die Sprachausgabe, `title` in der Quelle (`:3189`).
  final String tooltip;

  /// Kurzer Tipp.
  final VoidCallback? onTap;

  /// Langer Druck.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    Widget needle = Transform.rotate(
      // `rotate(${-map.getBearing()}deg)`, `:1792`.
      angle: -bearingDegrees * math.pi / 180,
      child: Text(
        // Ein Piktogramm, kein Text: die Quelle schreibt es hart (`:3192`) und
        // führt dafür keinen Schlüssel.
        '🧭',
        // `fontSize: 20` aus `btnStyle` (`:3031`), `lineHeight: 1` (`:3192`).
        style: const TextStyle(fontSize: 20, height: 1),
        // Feste 44er Kachel: eine mitwachsende Nadel würde beschnitten.
        textScaler: TextScaler.noScaling,
      ),
    );
    if (isDead) {
      // `filter: grayscale(1)`, `:3192`. Die Koeffizienten sind die der
      // CSS-Filter-Spezifikation (Rec. 709).
      needle = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
        child: needle,
      );
    }

    return AnchorTarget(
      anchorId: DiscoveryAnchors.compass,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Opacity(
          // `opacity: compassDead ? 0.55 : 1`, `:3190`.
          opacity: isDead ? 0.55 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPress: onLongPress,
            child: _Blurred(
              // 44x44, `borderRadius: 14`, `btnStyle` in `:3027`.
              radius: 14,
              sigma: _blurStrong,
              background: palette.background,
              border: palette.border,
              size: const Size.square(MapTopChrome.compassSize),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  needle,
                  if (isDead)
                    Positioned(
                      // `top: 3, right: 5`, 8x8, `:3195`.
                      top: 3,
                      right: 5,
                      child: MapNotificationDot(
                        size: 8,
                        // `boxShadow: '0 0 0 2px ' + pill.bg`, `:3197`.
                        ringWidth: 2,
                        ringColor: palette.background,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Der Modus-Umschalter, `screen-map.jsx:3203-3241`.
///
/// **Keine fünfte Tab-Leiste und auch nicht `ModeBar`**, siehe `map_mode.dart`.
class MapModeToggle extends StatelessWidget {
  /// Erzeugt den Umschalter.
  const MapModeToggle({
    required this.palette,
    required this.mode,
    required this.tourReady,
    required this.onSelected,
    required this.labelFor,
    super.key,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Der gerade aktive Modus.
  final MapMode mode;

  /// Ob eine Tour vorbereitet ist.
  final bool tourReady;

  /// Wird beim Antippen eines Modus gerufen.
  final ValueChanged<MapMode> onSelected;

  /// Liefert die Beschriftung eines Modus.
  ///
  /// Eine Funktion und nicht zwei fertige Texte: der Umschalter kennt beide
  /// Modi selbst, und zwei Parameter für zwei Beschriftungen wären eine
  /// Aufzählung von Hand.
  final String Function(MapMode) labelFor;

  @override
  Widget build(BuildContext context) {
    return _Blurred(
      radius: _fullRadius,
      sigma: _blurStrong,
      background: palette.background,
      border: palette.border,
      // `padding: 4`, `screen-map.jsx:3210`.
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final entry in MapMode.values) ...<Widget>[
            // `gap: 3`, `:3208`. Vor jedem Eintrag außer dem ersten.
            if (entry != MapMode.values.first) const SizedBox(width: 3),
            // Ausdrücklich **kein** `Flexible`: zwei `Flexible` mit gleichem
            // `flex` deckeln beide Knöpfe auf die halbe Breite, und die
            // längere Beschriftung wird gekürzt, obwohl daneben Platz frei
            // ist. Gemessen, nicht vermutet: bei 360 Pixeln und Skalierung 1.0
            // bekam "🔍 Fact Finder" so 107,5 statt der benötigten 142.
            MapModeButton(
              palette: palette,
              mapMode: entry,
              label: labelFor(entry),
              isActive: entry == mode,
              showDot: tourReady && entry == MapMode.tour && entry != mode,
              onTap: () => onSelected(entry),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ein Knopf des Umschalters, `screen-map.jsx:3216-3236`.
class MapModeButton extends StatelessWidget {
  /// Erzeugt einen Knopf des Umschalters.
  const MapModeButton({
    required this.palette,
    required this.mapMode,
    required this.label,
    required this.isActive,
    required this.showDot,
    required this.onTap,
    super.key,
  });

  /// Farben der aktiven Fassung.
  final MapChromePalette palette;

  /// Welchen Modus dieser Knopf wählt.
  final MapMode mapMode;

  /// Die sichtbare Beschriftung.
  final String label;

  /// Ob dieser Modus gerade aktiv ist.
  final bool isActive;

  /// Ob der rote Punkt sichtbar ist.
  final bool showDot;

  /// Tipp auf den Knopf.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnchorTarget(
      anchorId: mapMode.anchorId,
      child: Semantics(
        button: true,
        selected: isActive,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                // `padding: '7px 16px'`, `borderRadius: 999`, `:3220`.
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_fullRadius),
                  ),
                  color: isActive
                      ? palette.modeActiveBackground
                      : const Color(0x00000000),
                ),
                child: Text(
                  label,
                  // `fontWeight: 900, fontSize: 13`, `:3224`.
                  style: FactTypography.emphasis.copyWith(
                    fontSize: 13,
                    color: isActive ? palette.modeActiveText : palette.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              if (showDot)
                Positioned(
                  // `top: 3, right: 3`, 7x7, `:3229-3233`.
                  top: 3,
                  right: 3,
                  child: MapNotificationDot(
                    size: 7,
                    // `border: 1.5px solid pill.bg`, `:3233`. Ein CSS-Rahmen
                    // liegt innerhalb der 7 Pixel, weil `styles.css:109`
                    // global `box-sizing: border-box` setzt.
                    ringWidth: 1.5,
                    ringColor: palette.background,
                    ringInside: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ein roter Meldepunkt mit Ring, in zwei Ausprägungen.
class MapNotificationDot extends StatelessWidget {
  /// Erzeugt einen Meldepunkt.
  const MapNotificationDot({
    required this.size,
    required this.ringWidth,
    required this.ringColor,
    this.ringInside = false,
    super.key,
  });

  /// Durchmesser des Punktes.
  final double size;

  /// Stärke des Rings um den Punkt.
  final double ringWidth;

  /// Farbe des Rings, in der Quelle jeweils die Hintergrundfarbe der Pille.
  final Color ringColor;

  /// `true` für einen CSS-`border` (liegt innerhalb der Größe), `false` für
  /// einen `box-shadow`-Ring (liegt außerhalb).
  final bool ringInside;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _accentRed,
        border: ringInside
            ? Border.all(color: ringColor, width: ringWidth)
            : null,
        boxShadow: ringInside
            ? null
            : <BoxShadow>[BoxShadow(color: ringColor, spreadRadius: ringWidth)],
      ),
    );
  }
}

/// Eine Pille mit Weichzeichner, Rahmen und optionalem Schatten.
///
/// Der Weichzeichner braucht einen Clip, sonst greift er über die Pille
/// hinaus; der Schatten muss außerhalb dieses Clips liegen, sonst schneidet
/// ihn derselbe Clip weg. Dieselbe Reihenfolge wie in
/// `app/shell/floating_tab_bar.dart`.
class _Blurred extends StatelessWidget {
  const _Blurred({
    required this.radius,
    required this.sigma,
    required this.background,
    required this.border,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.shadow,
    this.size,
  });

  final double radius;
  final double sigma;
  final Color background;
  final Color border;
  final EdgeInsets padding;
  final BoxShadow? shadow;
  final Size? size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.all(Radius.circular(radius));
    Widget content = Container(
      width: size?.width,
      height: size?.height,
      alignment: size == null ? null : Alignment.center,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: Border.all(color: border),
      ),
      child: child,
    );
    content = ClipRRect(
      borderRadius: borderRadius,
      // Der Parameter von CSS `blur()` ist laut Filter Effects Level 1 die
      // Standardabweichung der Gaußfunktion, also derselbe Wert, den
      // `ImageFilter.blur` als Sigma erwartet. Keine Umrechnung nötig.
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      ),
    );
    if (shadow == null) {
      return content;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[shadow!],
      ),
      child: content,
    );
  }
}

/// `borderRadius: 999`, also so rund wie möglich.
const double _fullRadius = 999;

/// `backdropFilter: 'blur(14px)'`, `screen-map.jsx:3029`, `:3106`, `:3209`.
const double _blurStrong = 14;

/// `backdropFilter: 'blur(10px)'` der Coin-Pille, `screen-map.jsx:711`.
const double _blurLight = 10;

/// `boxShadow: '0 1px 6px rgba(0,0,0,0.12)'`, `screen-map.jsx:714` und `:3111`.
const BoxShadow _softShadow = BoxShadow(
  color: Color(0x1F000000),
  offset: Offset(0, 1),
  blurRadius: 6,
);

/// `#E8380D`, `screen-map.jsx:3196` und `:3232`.
///
/// Wertgleich mit `--red` aus `styles.css`, aber **nicht** von dort geholt: die
/// Quelle schreibt an diesen beiden Stellen die Zahl hin und nicht
/// `var(--stamp)`. Ein stadtabhängiges Theme dürfte diesen Punkt also nicht
/// mitfärben.
const Color _accentRed = Color(0xFFE8380D);

/// Die beiden Farbfassungen des Top-Chrome.
///
/// Die Quelle führt **zwei** Paletten, die nicht dieselben sind: `pill` in
/// `screen-map.jsx:3019-3021` für Stadt, Kompass und Umschalter, und ein
/// eigenes `pill` in `:687-689` für die Coin-Pille. Im hellen Zustand ist die
/// zweite grünlich (`rgba(240,255,248,0.92)`) statt cremefarben. Wer beide
/// zusammenlegt, verliert diesen Unterschied.
@immutable
class MapChromePalette {
  /// Erzeugt eine Fassung.
  const MapChromePalette({
    required this.background,
    required this.border,
    required this.text,
    required this.muted,
    required this.coinPillBackground,
    required this.coinPillBorder,
    required this.levelTrack,
    required this.levelInnerBackground,
    required this.levelText,
    required this.modeActiveBackground,
    required this.modeActiveText,
  });

  /// `mapDark === false`, der einzige Zustand, den die PWA erreicht.
  static const MapChromePalette light = MapChromePalette(
    // `rgba(255,248,238,0.92)`, `:3021`. 0.92 * 255 = 234.6.
    background: Color(0xEBFFF8EE),
    // `rgba(140,100,40,0.2)`, `:3021`.
    border: Color(0x338C6428),
    // `#1A1208`, `:3021`.
    text: Color(0xFF1A1208),
    // `rgba(26,18,8,0.5)`, `:3021`.
    muted: Color(0x801A1208),
    // `rgba(240,255,248,0.92)`, `:689`. Grünlich, nicht cremefarben.
    coinPillBackground: Color(0xEBF0FFF8),
    // `rgba(80,160,80,0.25)`, `:689`.
    coinPillBorder: Color(0x4050A050),
    // `rgba(0,0,0,0.08)`, `:733`.
    levelTrack: Color(0x14000000),
    // `#FDF7E8`, `:739`.
    levelInnerBackground: Color(0xFFFDF7E8),
    // `#7A5C00`, `:741`.
    levelText: Color(0xFF7A5C00),
    // `actBg`, `:3220`.
    modeActiveBackground: Color(0xFF1A1208),
    // `actText`, `:3221`.
    modeActiveText: Color(0xFFFDF5E8),
  );

  /// `mapDark === true`. Vollständig in der Quelle, dort aber unerreichbar,
  /// siehe [MapTopChrome.isDark].
  static const MapChromePalette dark = MapChromePalette(
    // `rgba(18,14,10,0.86)`, `:3020`. 0.86 * 255 = 219.3.
    background: Color(0xDB120E0A),
    // `rgba(255,200,120,0.12)`, `:3020`.
    border: Color(0x1FFFC878),
    // `#F5F0E8`, `:3020`.
    text: Color(0xFFF5F0E8),
    // `rgba(245,240,232,0.45)`, `:3020`.
    muted: Color(0x73F5F0E8),
    // `rgba(18,14,10,0.86)`, `:688`.
    coinPillBackground: Color(0xDB120E0A),
    // `rgba(255,200,120,0.12)`, `:688`.
    coinPillBorder: Color(0x1FFFC878),
    // `rgba(255,255,255,0.10)`, `:733`.
    levelTrack: Color(0x1AFFFFFF),
    // `#1A1410`, `:739`.
    levelInnerBackground: Color(0xFF1A1410),
    // `#F5C518`, `:741`.
    levelText: Color(0xFFF5C518),
    // `actBg`, `:3220`.
    modeActiveBackground: Color(0xFFFFFFFF),
    // `actText`, `:3221`.
    modeActiveText: Color(0xFF111111),
  );

  /// Hintergrund von Stadt-Pille, Kompass und Umschalter, `pill.bg`.
  final Color background;

  /// Rahmen derselben drei, `pill.border`.
  final Color border;

  /// Textfarbe der Stadt-Pille, `pill.text`.
  final Color text;

  /// Textfarbe eines inaktiven Modus, `pill.muted`.
  final Color muted;

  /// Hintergrund der Coin-Pille, eigene Palette in `screen-map.jsx:687-689`.
  final Color coinPillBackground;

  /// Rahmen der Coin-Pille, dieselbe eigene Palette.
  final Color coinPillBorder;

  /// Ungefüllter Teil des Level-Rings.
  final Color levelTrack;

  /// Innenfläche des Level-Rings.
  final Color levelInnerBackground;

  /// Ziffer im Level-Ring.
  final Color levelText;

  /// Fläche des aktiven Modus-Knopfes, `actBg`.
  final Color modeActiveBackground;

  /// Schrift des aktiven Modus-Knopfes, `actText`.
  final Color modeActiveText;
}
