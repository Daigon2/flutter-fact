/// Der Ergebnisbildschirm einer beendeten Solo-Jagd, `HuntResultScreen` in
/// `02_Frontend/app/screen-challenge.jsx:2952-2977`. Schritt 39.
///
/// ## Warum `ConsumerWidget` ohne eigenen Zustand
///
/// Der [run] kommt als Parameter herein, genau wie bei `HuntPauseView`: es
/// gibt nichts zu merken, nur einen fertigen [HuntRun] und einen Rückruf zu
/// zeigen. `ConsumerWidget` reicht deshalb, `AppStrings` kommt trotzdem über
/// Riverpod, sonst nichts.
///
/// ## Die Zeitzeile zeigt `—`, sie wird nicht gerechnet (E-19)
///
/// Dieselbe Begründung wie in `HuntPauseView`: die Quelle rechnet
/// `hunt.finishedAt - hunt.startedAt` (`:2954`), [HuntRun] trägt aber
/// bewusst keine Zeitstempel (siehe den Kopfkommentar von `hunt_run.dart`
/// und E-19: der Client rechnet keine Zeit, an der eine Belohnung hängt).
/// Die Zeile „Zeit: —" bleibt deshalb stehen, mit dem Platzhalter aus
/// `challenge.huntResult.timePlaceholder`, und ohne `DateTime.now()`, ohne
/// `Timer`, ohne ein Feld für den Startzeitpunkt.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Ergebnisbildschirm, siehe den Bibliothekskopf.
class HuntResultView extends ConsumerWidget {
  /// Erzeugt den Ergebnisbildschirm.
  const HuntResultView({required this.run, required this.onClose, super.key});

  /// Die beendete Jagd. Ob sie wirklich fertig ist ([HuntRun.isFinished]),
  /// entscheidet der Aufrufer (`ChallengesPage`); dieses Widget zeigt nur an,
  /// was drinsteht.
  final HuntRun run;

  /// „Fertig", `:2969-2974`.
  final VoidCallback onClose;

  /// Der Knopf „Fertig", für Tests.
  static const Key closeKey = Key('hunt-result-close');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;
    final int solved = run.stops
        .where((HuntRunStop stop) => stop.status == HuntStopStatus.solved)
        .length;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // `🎉`, `:2961`. Bildschmuck des Widgets, kein Lesetext,
                // deshalb kein Sprachschlüssel, dieselbe Regel wie beim 🎯 in
                // `hunt_pill.dart`.
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text(
                  strings.text('challenge.huntResult.title'),
                  textAlign: TextAlign.center,
                  style: FactTypography.emphasis.copyWith(
                    fontSize: 28,
                    letterSpacing: 28 * -0.01,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                // Die Punktzahl, `:2963`, `fontSize:64`, Farbe [FactColors.gold]:
                // `#F5C518` in **beiden** Themes, anders als [FactColors.coin],
                // das im hellen Theme abgedunkelt ist. Die Quelle setzt hier
                // die feste Zahl `#F5C518` und keine themenabhängige Variable.
                Text(
                  '${run.points}',
                  style: FactTypography.emphasis.copyWith(
                    fontSize: 64,
                    height: 1,
                    color: colors.gold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings
                      .text('challenge.huntResult.pointsLabel')
                      .toUpperCase(),
                  style: FactTypography.bodyText.copyWith(
                    fontSize: 13,
                    letterSpacing: 1.5,
                    color: colors.ink.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  strings.text(
                    'challenge.huntResult.solvedCount',
                    params: <String, String>{
                      'solved': '$solved',
                      'total': '${run.stops.length}',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: FactTypography.bodyText.copyWith(
                    fontSize: 14,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.text(
                    'challenge.huntResult.timeLine',
                    params: <String, String>{
                      'time': strings.text(
                        'challenge.huntResult.timePlaceholder',
                      ),
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: FactTypography.bodyText.copyWith(
                    fontSize: 14,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  key: HuntResultView.closeKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: Semantics(
                    button: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.red,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(14),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: colors.redDark,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                        child: Text(
                          strings.text('challenge.huntResult.close'),
                          style: FactTypography.heading.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
