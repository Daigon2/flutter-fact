import 'package:flutter/material.dart';

/// Farb-Tokens der FACT-Oberfläche, 1:1 aus `02_Frontend/app/styles.css`.
///
/// Wichtig zur Quelle: dort ist `:root` das **dunkle** Theme und
/// `.theme-light` überschreibt es. Der alte REBUILD_PLAN behauptet die
/// umgekehrte Zuordnung, das ist falsch.
///
/// Als `ThemeExtension`, damit Widgets über `Theme.of(context)` an die Tokens
/// kommen und nicht an globale Konstanten gebunden sind. Das macht abweichende
/// Themes pro Stadt später möglich, ohne jeden Aufrufer anzufassen.
///
/// Die Kategorie-Farben stehen hier nur als Werte. Welche Fakt-Kategorie welche
/// Farbe bekommt, entscheidet `features/facts`, nicht das Theme.
///
/// ## Alias-Paare sind keine Aliase
///
/// `styles.css` führt für Rot und Gold je mehrere Namen, die im dunklen Theme
/// identisch sind. Im hellen Theme überschreibt `.theme-light` aber nur einen
/// Teil davon, der Rest erbt still die `:root`-Werte. Wer solche Paare zu einem
/// Feld verschmilzt, zieht damit im hellen Theme echte Verwendungsstellen auf
/// den falschen Wert. Deshalb gilt hier pro Paar:
///
/// | Paar | Verwendungen live | Umsetzung |
/// |---|---|---|
/// | `--gold` / `--coin` | 5 / 19 | zwei Felder, siehe [gold] und [coin] |
/// | `--gold-soft` / `--coin-soft` | 3 / 1 | zwei Felder, [goldSoft] und [coinSoft] |
/// | `--red-glow` / `--stamp-glow` | 7 / 3 | zwei Felder, [redGlow] und [stampGlow] |
/// | `--red-soft` / `--stamp-soft` | 0 / 7 | ein Feld [redSoft], trägt `--stamp-soft` |
/// | `--gold-dk` / `--coin-dk` | 5 / 0 | ein Feld [goldDark], Werte sind gleich |
///
/// ## Keine Schatten-Tokens
///
/// `--shadow-sm`, `--shadow-md`, `--shadow-lg` und `--shadow` haben in der PWA
/// null `var()`-Verwendungen, die Schatten liegen inline am Element (169
/// `boxShadow`-Stellen im JSX). Es gibt also keine Verhaltensquelle, gegen die
/// man Schatten-Felder prüfen könnte. Schatten werden beim Portieren des
/// jeweiligen Screens aus dem JSX übernommen, genau wie `FactTypography` es mit
/// den Schriftgrößen macht. Bitte nicht wieder hinzufügen.
@immutable
class FactColors extends ThemeExtension<FactColors> {
  const FactColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.surfaceEdge,
    required this.border,
    required this.border2,
    required this.red,
    required this.redDark,
    required this.redLight,
    required this.redSoft,
    required this.redGlow,
    required this.stampGlow,
    required this.gold,
    required this.goldDark,
    required this.goldLight,
    required this.goldSoft,
    required this.coin,
    required this.coinSoft,
    required this.catHist,
    required this.catMyth,
    required this.catFun,
    required this.catGeo,
    required this.catArch,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.inkFaint,
    required this.mapBg,
    required this.mapSurface,
    required this.mapText,
  });

  // ── Flächen ────────────────────────────────────────────────────────────
  /// `--bg`
  final Color bg;

  /// `--surface`, Alias `--card`, `--paper`
  final Color surface;

  /// `--surface-2`, Alias `--surface-soft`, `--card-soft`
  final Color surface2;

  /// `--surface-3`, Alias `--surface-deep`, `--paper-edge`
  final Color surface3;

  /// `--surface-edge`
  final Color surfaceEdge;

  /// `--border`
  final Color border;

  /// `--border-2`
  final Color border2;

  // ── Rot ────────────────────────────────────────────────────────────────
  /// `--red`, in der PWA auch `--stamp` und `--primary`. Alle drei tragen in
  /// beiden Themes `#E8380D`.
  final Color red;

  /// `--red-dk`, Alias `--stamp-deep`, `--primary-dk`. Themeneutral.
  final Color redDark;

  /// `--red-lt`, Alias `--primary-lt`. Themeneutral.
  final Color redLight;

  /// `--stamp-soft`. Bewusst nicht `--red-soft`: das helle Theme überschreibt
  /// nur `--stamp-soft` (und das ungenutzte `--primary-soft`) auf 0.12,
  /// `--red-soft` erbt 0.14. Da `var(--red-soft)` in der PWA null Verwendungen
  /// hat, gibt es hier nur ein Feld und es trägt den `--stamp-soft`-Wert.
  final Color redSoft;

  /// `--red-glow`. Wird ausschließlich in `styles.css` verwendet, dort 7 mal
  /// für Button- und XP-Bar-Glow. Erbt im hellen Theme die 0.38 aus `:root`.
  final Color redGlow;

  /// `--stamp-glow`. Gleiche Rolle wie [redGlow], aber im hellen Theme auf 0.35
  /// abgesenkt. Eigenes Feld, weil die 3 Verwendungen im JSX (`screen-challenge`,
  /// `puzzle-sheet`) sonst auf den geerbten 0.38-Wert gezogen würden.
  final Color stampGlow;

  // ── Gold und Coin ──────────────────────────────────────────────────────
  /// `--gold`. Achtung: `.theme-light` überschreibt `--gold` **nicht**, der
  /// Wert bleibt also in beiden Themes `#F5C518`. Nicht mit [coin] verwechseln.
  final Color gold;

  /// `--gold-dk`, in der PWA auch `--coin-dk`. Beide tragen in beiden Themes
  /// `#C49A0A`, deshalb genügt ein Feld.
  final Color goldDark;

  /// `--gold-lt`. Kein Coin-Gegenstück in der Quelle. Themeneutral.
  final Color goldLight;

  /// `--gold-soft`. Wie [gold] im hellen Theme nicht überschrieben.
  final Color goldSoft;

  /// `--coin`. Im hellen Theme auf `#D4A820` abgedunkelt, während [gold] hell
  /// bleibt. Das ist keine Redundanz, sondern der Zustand der Quelle: 19 live
  /// Verwendungsstellen hängen an `--coin`, 5 an `--gold`.
  final Color coin;

  /// `--coin-soft`. Im hellen Theme `rgba(212,168,32,0.14)`, also auf dem
  /// abgedunkelten Coin-Ton statt auf dem Gold-Ton.
  final Color coinSoft;

  // ── Kategorie-Werte ────────────────────────────────────────────────────
  final Color catHist;
  final Color catMyth;
  final Color catFun;
  final Color catGeo;
  final Color catArch;

  // ── Text ───────────────────────────────────────────────────────────────
  /// `--ink`
  final Color ink;

  /// `--ink-2`, Alias `--ink-soft`
  final Color ink2;

  /// `--ink-3`, Alias `--ink-mute`
  final Color ink3;

  /// `--ink-faint`
  final Color inkFaint;

  // ── Karte ──────────────────────────────────────────────────────────────
  /// `--map-bg`. Von `.theme-light` nicht überschrieben.
  final Color mapBg;

  /// `--map-surface`. Von `.theme-light` nicht überschrieben.
  final Color mapSurface;

  /// `--map-text`. Von `.theme-light` nicht überschrieben.
  final Color mapText;

  /// Dunkles Theme, entspricht `:root` in `styles.css`.
  static const dark = FactColors(
    bg: Color(0xFF13100E),
    surface: Color(0xFF1C1712),
    surface2: Color(0xFF251F17),
    surface3: Color(0xFF2E2720),
    surfaceEdge: Color(0xFF3A3028),
    border: Color(0x1AFFC878),
    border2: Color(0x2EFFC878),
    red: Color(0xFFE8380D),
    redDark: Color(0xFFA82508),
    redLight: Color(0xFFFF6B3D),
    redSoft: Color(0x24E8380D),
    redGlow: Color(0x61E8380D),
    stampGlow: Color(0x61E8380D),
    gold: Color(0xFFF5C518),
    goldDark: Color(0xFFC49A0A),
    goldLight: Color(0xFFFFE066),
    goldSoft: Color(0x24F5C518),
    coin: Color(0xFFF5C518),
    coinSoft: Color(0x24F5C518),
    catHist: Color(0xFFE8380D),
    catMyth: Color(0xFFA855F7),
    catFun: Color(0xFFF5C518),
    catGeo: Color(0xFF00C2A8),
    catArch: Color(0xFF3B82F6),
    ink: Color(0xFFF5F0E8),
    ink2: Color(0xFFB0A898),
    ink3: Color(0xFF706860),
    inkFaint: Color(0xFF4A4040),
    mapBg: Color(0xFF0E1116),
    mapSurface: Color(0xBF0F1218),
    mapText: Color(0xFFF2EADC),
  );

  /// Helles Theme, entspricht `.theme-light`.
  ///
  /// Flächen und Text kippen, die Rot- und Kategorie-Grundtöne bleiben. Was
  /// `.theme-light` **nicht** überschreibt, erbt hier bewusst den Wert aus
  /// `:root`: die ganze `--gold`-Familie, `--red-soft`, `--red-glow` und alle
  /// `--map-*`. Die Karte bleibt also auch im hellen Theme dunkel, so wie in
  /// der PWA.
  static const light = FactColors(
    bg: Color(0xFFFDF5E8),
    surface: Color(0xFFFFF8EE),
    surface2: Color(0xFFF5EDD8),
    surface3: Color(0xFFEDE1C8),
    surfaceEdge: Color(0xFFD8CDB2),
    border: Color(0x1F8C6428),
    border2: Color(0x388C6428),
    red: Color(0xFFE8380D),
    redDark: Color(0xFFA82508),
    redLight: Color(0xFFFF6B3D),
    redSoft: Color(0x1FE8380D),
    redGlow: Color(0x61E8380D),
    stampGlow: Color(0x59E8380D),
    gold: Color(0xFFF5C518),
    goldDark: Color(0xFFC49A0A),
    goldLight: Color(0xFFFFE066),
    goldSoft: Color(0x24F5C518),
    coin: Color(0xFFD4A820),
    coinSoft: Color(0x24D4A820),
    catHist: Color(0xFFE8380D),
    catMyth: Color(0xFFA855F7),
    catFun: Color(0xFFF5C518),
    catGeo: Color(0xFF00C2A8),
    catArch: Color(0xFF3B82F6),
    ink: Color(0xFF1A1208),
    ink2: Color(0xFF5C4A30),
    ink3: Color(0xFFA08860),
    inkFaint: Color(0xFFC8B890),
    mapBg: Color(0xFF0E1116),
    mapSurface: Color(0xBF0F1218),
    mapText: Color(0xFFF2EADC),
  );

  @override
  FactColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? surfaceEdge,
    Color? border,
    Color? border2,
    Color? red,
    Color? redDark,
    Color? redLight,
    Color? redSoft,
    Color? redGlow,
    Color? stampGlow,
    Color? gold,
    Color? goldDark,
    Color? goldLight,
    Color? goldSoft,
    Color? coin,
    Color? coinSoft,
    Color? catHist,
    Color? catMyth,
    Color? catFun,
    Color? catGeo,
    Color? catArch,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? inkFaint,
    Color? mapBg,
    Color? mapSurface,
    Color? mapText,
  }) {
    return FactColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      surfaceEdge: surfaceEdge ?? this.surfaceEdge,
      border: border ?? this.border,
      border2: border2 ?? this.border2,
      red: red ?? this.red,
      redDark: redDark ?? this.redDark,
      redLight: redLight ?? this.redLight,
      redSoft: redSoft ?? this.redSoft,
      redGlow: redGlow ?? this.redGlow,
      stampGlow: stampGlow ?? this.stampGlow,
      gold: gold ?? this.gold,
      goldDark: goldDark ?? this.goldDark,
      goldLight: goldLight ?? this.goldLight,
      goldSoft: goldSoft ?? this.goldSoft,
      coin: coin ?? this.coin,
      coinSoft: coinSoft ?? this.coinSoft,
      catHist: catHist ?? this.catHist,
      catMyth: catMyth ?? this.catMyth,
      catFun: catFun ?? this.catFun,
      catGeo: catGeo ?? this.catGeo,
      catArch: catArch ?? this.catArch,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      inkFaint: inkFaint ?? this.inkFaint,
      mapBg: mapBg ?? this.mapBg,
      mapSurface: mapSurface ?? this.mapSurface,
      mapText: mapText ?? this.mapText,
    );
  }

  @override
  FactColors lerp(covariant FactColors? other, double t) {
    if (other == null) {
      return this;
    }
    return FactColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      surfaceEdge: Color.lerp(surfaceEdge, other.surfaceEdge, t)!,
      border: Color.lerp(border, other.border, t)!,
      border2: Color.lerp(border2, other.border2, t)!,
      red: Color.lerp(red, other.red, t)!,
      redDark: Color.lerp(redDark, other.redDark, t)!,
      redLight: Color.lerp(redLight, other.redLight, t)!,
      redSoft: Color.lerp(redSoft, other.redSoft, t)!,
      redGlow: Color.lerp(redGlow, other.redGlow, t)!,
      stampGlow: Color.lerp(stampGlow, other.stampGlow, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldDark: Color.lerp(goldDark, other.goldDark, t)!,
      goldLight: Color.lerp(goldLight, other.goldLight, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      coin: Color.lerp(coin, other.coin, t)!,
      coinSoft: Color.lerp(coinSoft, other.coinSoft, t)!,
      catHist: Color.lerp(catHist, other.catHist, t)!,
      catMyth: Color.lerp(catMyth, other.catMyth, t)!,
      catFun: Color.lerp(catFun, other.catFun, t)!,
      catGeo: Color.lerp(catGeo, other.catGeo, t)!,
      catArch: Color.lerp(catArch, other.catArch, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
      mapSurface: Color.lerp(mapSurface, other.mapSurface, t)!,
      mapText: Color.lerp(mapText, other.mapText, t)!,
    );
  }

  /// Wertgleichheit ist hier Pflicht, nicht Komfort: `ThemeData.==` vergleicht
  /// seine Extensions über `mapEquals`, also über `==` der Werte. Ohne das
  /// Folgende wären zwei strukturell gleiche, aber getrennt erzeugte Instanzen
  /// (etwa aus `copyWith` für stadtspezifische Farben) ungleich. Damit wäre
  /// auch `ThemeData` ungleich und der komplette Baum unter `Theme` würde bei
  /// jedem Build neu aufbauen.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FactColors &&
        other.bg == bg &&
        other.surface == surface &&
        other.surface2 == surface2 &&
        other.surface3 == surface3 &&
        other.surfaceEdge == surfaceEdge &&
        other.border == border &&
        other.border2 == border2 &&
        other.red == red &&
        other.redDark == redDark &&
        other.redLight == redLight &&
        other.redSoft == redSoft &&
        other.redGlow == redGlow &&
        other.stampGlow == stampGlow &&
        other.gold == gold &&
        other.goldDark == goldDark &&
        other.goldLight == goldLight &&
        other.goldSoft == goldSoft &&
        other.coin == coin &&
        other.coinSoft == coinSoft &&
        other.catHist == catHist &&
        other.catMyth == catMyth &&
        other.catFun == catFun &&
        other.catGeo == catGeo &&
        other.catArch == catArch &&
        other.ink == ink &&
        other.ink2 == ink2 &&
        other.ink3 == ink3 &&
        other.inkFaint == inkFaint &&
        other.mapBg == mapBg &&
        other.mapSurface == mapSurface &&
        other.mapText == mapText;
  }

  /// `Object.hashAll` statt `Object.hash`, weil letzteres bei 20 Argumenten
  /// endet und hier 31 Felder eingehen.
  @override
  int get hashCode => Object.hashAll(<Object?>[
    bg,
    surface,
    surface2,
    surface3,
    surfaceEdge,
    border,
    border2,
    red,
    redDark,
    redLight,
    redSoft,
    redGlow,
    stampGlow,
    gold,
    goldDark,
    goldLight,
    goldSoft,
    coin,
    coinSoft,
    catHist,
    catMyth,
    catFun,
    catGeo,
    catArch,
    ink,
    ink2,
    ink3,
    inkFaint,
    mapBg,
    mapSurface,
    mapText,
  ]);
}

/// Kurzer Zugriff auf die Tokens: `context.factColors.coin`.
extension FactColorsContext on BuildContext {
  FactColors get factColors => Theme.of(this).extension<FactColors>()!;
}
