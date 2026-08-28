/// Die drei Aufsätze, die auf **jedem** Schritt gleich aussehen:
/// "Überspringen", der Tipp-Hinweis und die Punktreihe.
///
/// Die Quelle baut sie einmal als `SkipBtn`, `TapHint` und `Dots`
/// (`02_Frontend/app/screen-tour.jsx:284-338`) und setzt dieselben drei
/// Elemente in den Hero-Zweig und in den regulären Zweig. Genau deshalb stehen
/// sie hier zusammen in einer Datei: drei kleine Typen, die immer gemeinsam
/// auftreten und deren einzige Gemeinsamkeit ist, dass sie über beiden
/// Schrittarten liegen.
///
/// Alle drei erwarten einen `Stack` als Elternteil.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:fact_app/app/onboarding/widgets/tour_palette.dart';
import 'package:fact_app/app/shell/floating_tab_bar.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';

/// Der Knopf "Überspringen", `screen-tour.jsx:286-306`.
///
/// Er beendet das Tutorial sofort und setzt dieselbe Merkung wie der letzte
/// Schritt. In der Quelle steht dafür ein eigenes `stopPropagation`
/// (`screen-tour.jsx:282`), damit der Tipp nicht zusätzlich weiterschaltet.
/// In Flutter erledigt das die Gestenarena von selbst: von zwei geschachtelten
/// Tipp-Erkennern gewinnt der innere. Ein Test sichert das zu, weil es sonst
/// ein stiller Doppelschritt wäre.
class TourSkipButton extends StatelessWidget {
  /// [label] ist `tour.skip`, [onSkip] beendet das Tutorial.
  const TourSkipButton({required this.label, required this.onSkip, super.key});

  /// `top: 18, right: 18`, `screen-tour.jsx:289`.
  static const double inset = 18;

  /// `borderRadius: 999`, `screen-tour.jsx:298`.
  static const double borderRadius = 999;

  /// `backdropFilter: blur(8px)`, `screen-tour.jsx:299`.
  static const double blurSigma = 8;

  /// Die Beschriftung.
  final String label;

  /// Wird beim Antippen gerufen.
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Die 18 der Quelle plus die Systemleiste. `screen-tour.jsx:294` setzt
      // `top: 18`, misst das aber **innerhalb** der `.app-frame`, und die trägt
      // laut `index.html:101-107` bereits `padding-top:
      // env(safe-area-inset-top)`. Ein `Positioned` misst dagegen ab der
      // Bildschirmkante.
      //
      // Am 28.08.2026 am Emulator gesehen: ohne diesen Zuschlag liegt
      // "Überspringen" über Uhrzeit und Funkanzeige. Kein Test hat es gemeldet,
      // weil der Testrahmen ohne `FakeViewPadding` gar keine Systemleiste hat.
      top: inset + MediaQuery.paddingOf(context).top,
      right: inset,
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSkip,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(borderRadius)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: TourPalette.skipBackground,
                  borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                ),
                child: Padding(
                  // `padding: '7px 14px'`, `screen-tour.jsx:297`.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  child: Text(
                    label,
                    // DM Sans 600, 12, weiß, `screen-tour.jsx:293-295`.
                    // Gewicht 600 hat in `FactTypography` keine eigene Rolle,
                    // weil `styles.css` dafür keine Klasse führt; die Quelle
                    // setzt es inline. Deshalb die Ableitung aus
                    // `bodyEmphasis` (DM Sans 500).
                    style: FactTypography.bodyEmphasis.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TourPalette.heroTitle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Der Hinweis "Tipp irgendwo für weiter", `screen-tour.jsx:325-337`.
class TourTapHint extends StatelessWidget {
  /// [label] ist `tour.tapHint`, [bottom] kommt aus [TourBottomChrome].
  const TourTapHint({required this.label, required this.bottom, super.key});

  /// Schriftgröße, `screen-tour.jsx:330`.
  ///
  /// Öffentlich, weil [TourBottomChrome.tapHintHeight] daraus rechnet, wie
  /// viel Platz dieser Hinweis bei großer Systemschrift braucht.
  static const double fontSize = 11;

  /// Der Text.
  final String label;

  /// Abstand der Unterkante vom unteren Bildschirmrand.
  ///
  /// Kommt von außen und wird hier nicht gerechnet: er hängt an der Oberkante
  /// der Tab-Leiste, und die kennt nur `TourOverlay`, das sie misst.
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottom,
      left: 0,
      right: 0,
      // `pointerEvents: 'none'`, `screen-tour.jsx:334`: der Hinweis fängt den
      // Tipp nicht ab, der ihn erklärt.
      child: IgnorePointer(
        child: Text(
          label,
          textAlign: TextAlign.center,
          // DM Sans 500, 11, `letterSpacing: '0.04em'`,
          // `screen-tour.jsx:329-334`.
          style: FactTypography.bodyEmphasis.copyWith(
            fontSize: fontSize,
            letterSpacing: fontSize * 0.04,
            color: TourPalette.tapHint,
          ),
        ),
      ),
    );
  }
}

/// Die Punktreihe, ein Punkt je Schritt, `screen-tour.jsx:308-323`.
class TourStepDots extends StatelessWidget {
  /// [count] ist die Zahl aller Schritte, [current] der laufende, ab 0 gezählt.
  /// [bottom] kommt aus [TourBottomChrome].
  const TourStepDots({
    required this.count,
    required this.current,
    required this.bottom,
    super.key,
  });

  /// `width: 6, height: 6`, `screen-tour.jsx:319`.
  static const double dotSize = 6;

  /// `gap: 6`, `screen-tour.jsx:313`.
  static const double gap = 6;

  /// Anzahl der Punkte.
  final int count;

  /// Der Index des aktiven Punktes.
  final int current;

  /// Abstand der Unterkante vom unteren Bildschirmrand, siehe [TourTapHint].
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottom,
      left: 0,
      right: 0,
      // `pointerEvents: 'none'`, `screen-tour.jsx:314`. Die Punkte sind keine
      // Bedienung: die Quelle springt nicht per Tipp auf einen Schritt.
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var index = 0; index < count; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: gap),
              _Dot(isActive: index == current),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TourStepDots.dotSize,
      height: TourStepDots.dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? TourPalette.accent : TourPalette.inactiveDot,
        // `0 0 0 3px rgba(184,58,46,0.25)`, `screen-tour.jsx:321`. Ein
        // Schatten ohne Weichzeichner und ohne Versatz ist ein Hof.
        boxShadow: isActive
            ? const <BoxShadow>[
                BoxShadow(color: TourPalette.activeDotGlow, spreadRadius: 3),
              ]
            : null,
      ),
    );
  }
}

/// Die Maße des unteren Tutorial-Chrome: Punktreihe und Tipp-Hinweis.
///
/// ## Eine bewusste Abweichung von der PWA, entschieden am 28.08.2026
///
/// Die Quelle setzt die Punktreihe auf `bottom: 24` (`screen-tour.jsx:310`)
/// und den Tipp-Hinweis auf `bottom: 50` (`:327`), gemessen in derselben
/// `.app-frame`, in der die Tab-Leiste auf `bottom: max(14px,
/// env(safe-area-inset-bottom))` sitzt (`chrome.jsx:70`). Auf einem Gerät
/// ohne unteren Systemeinzug liegen beide damit **in** der Leiste: die Punkte
/// zwischen den Symbolen von "Fakten" und "Challenge", der Hinweis auf ihrer
/// Oberkante. Am 28.08.2026 am Emulator gesehen und in der Quelle
/// nachgerechnet. Mit Home-Indicator rutschen sie in der Quelle unter die
/// Leiste, weil diese die Safe Area doppelt zählt, siehe
/// `FloatingTabBar.minBottomInset`.
///
/// Der Product Owner hat am selben Tag entschieden, dass beide **über** der
/// Leiste liegen, in Kenntnis dessen, dass das von der PWA abweicht. Der
/// Bezugspunkt ist deshalb nicht mehr die Bildschirmkante, sondern die
/// Oberkante der unteren Shell-Leiste.
///
/// ## Warum die Leiste gemessen und nicht gerechnet wird
///
/// Sie ist bei Systemschriftgröße 1.0 genau 64 Pixel hoch und bei 2.0 schon
/// 94, weil "Challenge" dann zweizeilig umbricht (gemessen auf 360, 375 und
/// 390 Pixeln Breite). Eine feste Zahl wäre bei einer der beiden Größen
/// falsch: zu klein heißt Überlappung, zu groß kostet unten den Platz, den
/// `TourBubble` für ihren Text braucht. `TourOverlay` misst die Leiste
/// deshalb über `ShellAnchors.bottomBar` und reicht ihre Oberkante als
/// `barInset` hier hinein, also als Abstand vom unteren Bildschirmrand.
///
/// ## Die Systemleiste steckt im gemessenen Wert
///
/// Ein eigener Zuschlag aus `MediaQuery.paddingOf` wäre hier falsch und
/// doppelt: die Tab-Leiste hält selbst `max(14, Safe Area)` Abstand nach
/// unten (`FloatingTabBar.minBottomInset`), ihre gemessene Oberkante liegt
/// also bereits über der Gestenleiste. Nur [fallbackBarInset], solange noch
/// nichts gemessen ist, rechnet dieselbe Regel nach.
abstract final class TourBottomChrome {
  /// Luft zwischen der Oberkante der Tab-Leiste und der Punktreihe.
  ///
  /// Bewusst knapp: jeder Pixel hier geht `TourBubble` verloren, siehe
  /// [bubbleReserve]. Auf 375x667 bleiben Schritt 3 bei Systemschrift 1.0
  /// derzeit 2,5 Pixel Rest, bevor sein Text scrollen müsste.
  static const double dotsGap = 8;

  /// Abstand zwischen Punktreihe und Tipp-Hinweis.
  ///
  /// Die Differenz der beiden Werte der Quelle, 50 minus 24. Sie bleibt
  /// unverändert, nur ihr gemeinsamer Bezugspunkt wandert nach oben.
  static const double gapToTapHint = 26;

  /// Luft zwischen der Unterkante der Blase und dem Tipp-Hinweis.
  static const double bubbleClearance = 8;

  /// Zeilenhöhe des Tipp-Hinweises als Vielfaches seiner Schriftgröße.
  ///
  /// **Aus der Quelle nicht herleitbar, und das ist kein Versäumnis:**
  /// `screen-tour.jsx:325-337` setzt für den Hinweis keine `line-height`,
  /// und keine Regel im Vorfahrenpfad tut es. Der berechnete Wert dort ist
  /// `normal`, also die Metrik von DM Sans. Was hier steht, ist deshalb
  /// notwendigerweise eine Messung mit Sicherheitszuschlag und keine Zahl
  /// aus dem JSX.
  ///
  /// Gemessen am 29.08.2026 in beiden Sprachen und auf 360, 375 und 390
  /// Pixeln Breite: eine Zeile ist bei Skalierung 1.0 genau 14 Pixel hoch
  /// (Faktor 1,273) und bei 2.0 genau 29 (Faktor 1,318). Der Wert hier liegt
  /// darüber, damit [bubbleReserve] eher zu viel als zu wenig freihält.
  ///
  /// **Die Vorgängerzahlen waren an Materials Zeilenhöhe gemessen.** Bis zum
  /// 29.08.2026 standen hier 16 Pixel (Faktor 1,45) und 31 (Faktor 1,41).
  /// Sie stimmten für den damaligen Zustand: das `Material` im
  /// `OnboardingHost` hatte keinen eigenen Basisstil und vererbte
  /// `height: 1.43` an jeden Text, der selbst keine setzt. Der Hinweis ist
  /// einer davon. Seit `OnboardingHost.overlayTextStyle` steht, gilt wieder
  /// die Schriftmetrik, und die Zeile ist niedriger. Der Zuschlag wächst
  /// damit, [bubbleReserve] hält also etwas mehr frei als nötig; das ist die
  /// Richtung, in die dieser Wert irren soll.
  ///
  /// **Bewusst kein Zuschlag für eine zweite Zeile.** Es gibt genau zwei
  /// Sprachen, beide sind gemessen und beide einzeilig, auch bei 2.0 auf 360
  /// Pixeln. Ein Zuschlag von einer ganzen Zeile würde die Blase auf kleinen
  /// Geräten schon bei Systemschrift 1.0 zum Scrollen zwingen, und das ist
  /// der teurere Fehler. Kommt eine dritte Sprache dazu, meldet der
  /// Nichtüberlappungs-Test in `tour_overlay_test.dart` es.
  static const double tapHintLineFactor = 1.5;

  /// Abstand der Punktreihe vom unteren Bildschirmrand.
  static double dotsBottom(double barInset) => barInset + dotsGap;

  /// Abstand des Tipp-Hinweises vom unteren Bildschirmrand.
  static double tapHintBottom(double barInset) =>
      dotsBottom(barInset) + gapToTapHint;

  /// Höhe einer Zeile des Tipp-Hinweises bei der aktuellen Systemschrift.
  static double tapHintHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(TourTapHint.fontSize) *
      tapHintLineFactor;

  /// Wie viel Platz am unteren Rand `TourBubble` freilassen muss.
  ///
  /// Der Tipp-Hinweis wird **nach** der Blase gezeichnet und läge sonst auf
  /// ihrem Glas.
  static double bubbleReserve(BuildContext context, double barInset) =>
      tapHintBottom(barInset) + tapHintHeight(context) + bubbleClearance;

  /// Ersatzwert für die Oberkante der Leiste, solange nichts gemessen ist.
  ///
  /// Dieselbe Rechnung, die `FloatingTabBar` für sich selbst anstellt, plus
  /// die Pillenhöhe bei Systemschrift 1.0. Er stimmt damit im häufigen Fall
  /// genau und ist bei großer Systemschrift um den Umbruch der Beschriftung
  /// zu klein. Sichtbar wird er nur im ersten Frame, danach steht die
  /// Messung.
  static double fallbackBarInset(BuildContext context) =>
      math.max(
        FloatingTabBar.minBottomInset,
        MediaQuery.paddingOf(context).bottom,
      ) +
      FloatingTabBar.nominalPillHeight;
}
