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

import 'dart:ui' show ImageFilter;

import 'package:fact_app/app/onboarding/widgets/tour_palette.dart';
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
      top: inset,
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
  /// [label] ist `tour.tapHint`.
  const TourTapHint({required this.label, super.key});

  /// `bottom: 50`, `screen-tour.jsx:327`.
  static const double bottom = 50;

  /// Der Text.
  final String label;

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
            fontSize: 11,
            letterSpacing: 11 * 0.04,
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
  const TourStepDots({required this.count, required this.current, super.key});

  /// `bottom: 24`, `screen-tour.jsx:310`.
  static const double bottom = 24;

  /// `width: 6, height: 6`, `screen-tour.jsx:319`.
  static const double dotSize = 6;

  /// `gap: 6`, `screen-tour.jsx:313`.
  static const double gap = 6;

  /// Anzahl der Punkte.
  final int count;

  /// Der Index des aktiven Punktes.
  final int current;

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
