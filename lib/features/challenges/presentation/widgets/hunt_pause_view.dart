/// Der Pause-Bildschirm einer laufenden Solo-Jagd, `HuntPauseScreen` in
/// `02_Frontend/app/screen-challenge.jsx:2797-2895`, dazu `HuntStatTile`
/// (`:2896-2909`) und `HuntStopRow` (`:2911-2950`). Schritt 39.
///
/// ## Warum ein `StatefulWidget` und kein `Consumer` auf `huntRunProvider`
///
/// Der [run] kommt als Parameter herein, genau wie bei `HuntStartPointView`:
/// die Seite, die entscheidet, ob gerade eine Jagd läuft, ist
/// `ChallengesPage`, nicht dieses Widget. So bleibt die Rückfrage vor dem
/// Abbruch (`_showAbortConfirm`) mit einem `Widget test`-Rahmen ohne jeden
/// Riverpod-Zustand prüfbar, es braucht nur einen [HuntRun] und vier
/// Rückrufe. Übersetzungen kommen trotzdem über `AppStrings`, deshalb
/// `ConsumerState` und nicht `State`.
///
/// ## Kein Sekundentakt
///
/// Die Quelle lässt `setInterval` laufen (`:2802-2805`), einzig damit die
/// Zeitkachel weiterzählt. Diese Datei baut das nicht nach, siehe die Zeit-
/// Kachel unten und den nächsten Absatz.
///
/// ## Die Zeit-Kachel zeigt `—`, sie wird nicht gerechnet (E-19)
///
/// Die Quelle rechnet `Date.now() - hunt.startedAt` (`:2807`). [HuntRun] trägt
/// bewusst keinen Startzeitstempel, siehe den Kopfkommentar von
/// `hunt_run.dart`: der Client rechnet keine Zeit, an der eine Belohnung
/// hängt (E-19), Dairens Antwort dazu wörtlich: „Der baubare Teil ist alles,
/// was den Ablauf anzeigt; der Moment, in dem daraus Punkte werden, braucht
/// den Serveraufruf." Die Kachel bleibt deshalb stehen und zeigt den
/// Platzhalter `challenge.huntPause.timePlaceholder` (`—`, wie
/// `challenge.huntPill.missingTitle` es für einen fehlenden Titel schon tut).
/// Kein `DateTime.now()`, kein `Timer`, kein Feld `startedAt`: der Tag, an dem
/// der Server einen Startzeitstempel liefert, kostet eine Zeile in dieser
/// Datei und keine neue Uhr.
///
/// ## Die Stufe kommt über `AppStrings`, nicht als Rohwert (Entscheidung 3)
///
/// Die Quelle zeigt `hunt.difficulty` roh an (`:2828`), also wörtlich
/// „leicht", „mittel" oder „schwer". Das sind Datenwerte aus
/// `kernel/puzzle_difficulty.dart`, und dessen Kopfkommentar verlangt
/// ausdrücklich: „Wer sie anzeigt, übersetzt über `AppStrings` und nicht über
/// [code]." [HuntPauseView.difficultyTextKeys] bildet das ab: drei Schlüssel,
/// deren Werte in beiden Sprachen genau `leicht`, `mittel` und `schwer`
/// lauten, sichtbar identisch zur Quelle und trotzdem auf dem
/// vorgeschriebenen Weg.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Pause-Bildschirm, siehe den Bibliothekskopf.
class HuntPauseView extends ConsumerStatefulWidget {
  /// Erzeugt den Pause-Bildschirm.
  const HuntPauseView({
    required this.run,
    required this.cityName,
    required this.onBackToMap,
    required this.onAbort,
    super.key,
  });

  /// Der laufende Jagdzustand.
  final HuntRun run;

  /// Die Stadt, in der die Jagd läuft. Kommt von außen, siehe
  /// `ChallengesPage.placeholderCityName`: dieselbe Begründung wie beim
  /// Startpunkt-Picker, Mehrstädtigkeit bleibt gewahrt.
  final String cityName;

  /// „Zurück zur Karte", `:2849-2855`.
  final VoidCallback onBackToMap;

  /// „Ja, abbrechen" in der Rückfrage, `:2880-2884`. Wird **nicht** direkt vom
  /// Abbrechen-Knopf gerufen, siehe [abortButtonKey].
  final VoidCallback onAbort;

  /// Der Knopf „Hunt abbrechen", öffnet nur die Rückfrage.
  static const Key abortButtonKey = Key('hunt-pause-abort-button');

  /// „Ja, abbrechen" in der geöffneten Rückfrage.
  static const Key confirmAbortKey = Key('hunt-pause-confirm-abort');

  /// „Doch weiterspielen", schließt die Rückfrage ohne [onAbort].
  static const Key cancelAbortKey = Key('hunt-pause-cancel-abort');

  /// „Zurück zur Karte".
  static const Key backToMapKey = Key('hunt-pause-back-to-map');

  /// Die Sprachschlüssel der drei Datenwerte aus [PuzzleDifficulty], siehe
  /// „Die Stufe kommt über `AppStrings`" im Bibliothekskopf.
  static const Map<PuzzleDifficulty, String> difficultyTextKeys =
      <PuzzleDifficulty, String>{
        PuzzleDifficulty.leicht: 'challenge.huntPause.difficulty.leicht',
        PuzzleDifficulty.mittel: 'challenge.huntPause.difficulty.mittel',
        PuzzleDifficulty.schwer: 'challenge.huntPause.difficulty.schwer',
      };

  @override
  ConsumerState<HuntPauseView> createState() => _HuntPauseViewState();
}

class _HuntPauseViewState extends ConsumerState<HuntPauseView> {
  /// `showAbortConfirm`, `:2799`.
  bool _showAbortConfirm = false;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final HuntRun run = widget.run;
    final int solvedCount = run.stops
        .where((HuntRunStop stop) => stop.status == HuntStopStatus.solved)
        .length;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg),
      child: Stack(
        children: <Widget>[
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Kickerzeile, `:2819-2821`.
                  Text(
                    strings.text('challenge.activeHunt').toUpperCase(),
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Der Titel, `:2822-2826`. Die Quelle nimmt bei einer
                  // kuratierten Themenroute `routeEmoji + huntRouteLabel(…)`,
                  // sonst den Rückfall `challenge.title`. `HuntPlan` trägt
                  // keine kuratierte Themenroute, die gibt es im Neubau nicht;
                  // hier steht deshalb **immer** der Rückfallzweig der Quelle,
                  // und das ist keine weggelassene Fallunterscheidung.
                  Text(
                    strings.text('challenge.title'),
                    style: FactTypography.emphasis.copyWith(
                      fontSize: 26,
                      letterSpacing: 26 * -0.01,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Unterzeile, `:2827-2829`.
                  Text(
                    '${widget.cityName} · ${strings.text('challenge.difficulty')}: '
                    '${strings.text(HuntPauseView.difficultyTextKeys[run.plan.difficulty]!)}',
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 13,
                      color: _inkSoft(isDark),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Die drei Kacheln, `:2831-2835`.
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _HuntStatTile(
                          value: '$solvedCount/${run.stops.length}',
                          label: strings.text('challenge.huntPause.stopsLabel'),
                          isDark: isDark,
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HuntStatTile(
                          value: '${run.points}',
                          label: strings.text(
                            'challenge.huntPause.pointsLabel',
                          ),
                          isDark: isDark,
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HuntStatTile(
                          value: strings.text(
                            'challenge.huntPause.timePlaceholder',
                          ),
                          label: strings.text('challenge.huntPause.timeLabel'),
                          isDark: isDark,
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Abschnittslabel, `:2837-2839`.
                  Text(
                    strings
                        .text('challenge.huntPause.stationsHeading')
                        .toUpperCase(),
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _inkSoft(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Die Stationsliste, `:2840-2847`.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _cardBackground(isDark),
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < run.stops.length; i++)
                            _StopRow(
                              stop: run.stops[i],
                              stationNumber: i + 1,
                              isCurrent: i == run.currentStopIndex,
                              isLast: i == run.stops.length - 1,
                              isDark: isDark,
                              colors: colors,
                              strings: strings,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // „Zurück zur Karte", `:2849-2855`.
                  _filledButton(
                    key: HuntPauseView.backToMapKey,
                    label: strings.text('challenge.huntPause.backToMap'),
                    colors: colors,
                    onTap: widget.onBackToMap,
                  ),
                  const SizedBox(height: 12),
                  // „Hunt abbrechen", `:2857-2863`. Öffnet nur die Rückfrage.
                  _outlineButton(
                    key: HuntPauseView.abortButtonKey,
                    label: strings.text('challenge.huntPause.abort'),
                    colors: colors,
                    onTap: () => setState(() => _showAbortConfirm = true),
                  ),
                ],
              ),
            ),
          ),
          if (_showAbortConfirm)
            _abortConfirmOverlay(strings: strings, colors: colors),
        ],
      ),
    );
  }

  /// Die Rückfrage, `:2866-2892`.
  Widget _abortConfirmOverlay({
    required AppStrings strings,
    required FactColors colors,
  }) {
    return Positioned.fill(
      child: DecoratedBox(
        // `rgba(0,0,0,0.65)`, `:2868`.
        decoration: const BoxDecoration(color: Color(0xA6000000)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: DecoratedBox(
                // `#1C1712` / `#FFF8EE`, `:2873`, beide Male [FactColors.surface]
                // in ihrem jeweiligen Theme, nachgeschlagen und nicht geraten.
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        strings.text('challenge.huntPause.abortConfirmMessage'),
                        textAlign: TextAlign.center,
                        style: FactTypography.bodyText.copyWith(
                          fontSize: 15,
                          height: 1.5,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _filledButton(
                        key: HuntPauseView.confirmAbortKey,
                        label: strings.text(
                          'challenge.huntPause.abortConfirmYes',
                        ),
                        colors: colors,
                        onTap: () {
                          widget.onAbort();
                          setState(() => _showAbortConfirm = false);
                        },
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        key: HuntPauseView.cancelAbortKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _showAbortConfirm = false),
                        child: Semantics(
                          button: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              strings.text(
                                'challenge.huntPause.abortConfirmNo',
                              ),
                              textAlign: TextAlign.center,
                              style: FactTypography.bodyText.copyWith(
                                fontSize: 13,
                                color: colors.ink,
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
          ),
        ),
      ),
    );
  }

  /// Der volle, rote Knopf, `:2849-2855` und `:2880-2884`.
  Widget _filledButton({
    required Key key,
    required String label,
    required FactColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.red,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: colors.redDark, offset: const Offset(0, 3)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: FactTypography.heading.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Der Umriss-Knopf, `:2857-2863`.
  Widget _outlineButton({
    required Key key,
    required String label,
    required FactColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.red, width: 1),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: FactTypography.bodyText.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Eine der drei Kacheln, `HuntStatTile`, `:2896-2909`.
class _HuntStatTile extends StatelessWidget {
  const _HuntStatTile({
    required this.value,
    required this.label,
    required this.isDark,
    required this.colors,
  });

  final String value;
  final String label;
  final bool isDark;
  final FactColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // `rgba(255,255,255,0.05)` / `rgba(0,0,0,0.04)`, `:2899`. **Nicht**
        // dieselben Werte wie die Stationskarte (`:2812`): dort steht im
        // dunklen Theme 0.04, hier 0.05, an der Quelle nachgeprüft.
        color: isDark ? const Color(0x0DFFFFFF) : const Color(0x0A000000),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: <Widget>[
            Text(
              value,
              textAlign: TextAlign.center,
              style: FactTypography.mono.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: FactTypography.bodyText.copyWith(
                fontSize: 10,
                letterSpacing: 1,
                color: _inkSoft(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Zeile der Stationsliste, `HuntStopRow`, `:2911-2950`.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.stationNumber,
    required this.isCurrent,
    required this.isLast,
    required this.isDark,
    required this.colors,
    required this.strings,
  });

  final HuntRunStop stop;

  /// Eins-basiert, `idx + 1` in der Quelle.
  final int stationNumber;
  final bool isCurrent;
  final bool isLast;
  final bool isDark;
  final FactColors colors;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final bool isSolved = stop.status == HuntStopStatus.solved;
    final bool isSkipped = stop.status == HuntStopStatus.skipped;
    // `:2918-2923`.
    final String icon = isSolved
        ? '✓'
        : isSkipped
        ? '×'
        : isCurrent
        ? '▶'
        : '○';
    final Color iconColor = isSolved
        ? colors.gold
        : isSkipped
        ? _inkMute(isDark)
        : isCurrent
        ? colors.red
        : _inkMute(isDark);

    // Nur eine gelöste Station zeigt den echten Titel. Die Quelle begründet
    // das an derselben Stelle (`:2925-2926`): ein Titel vorab würde
    // verraten, wohin die Jagd führt, deshalb tragen die anderen drei
    // Zustände nur eine neutrale Stationsnummer.
    final String label = isSolved
        ? stop.stop.fact.canonicalTitle
        : isSkipped
        ? strings.text(
            'challenge.huntPause.stopSkipped',
            params: <String, String>{'station': '$stationNumber'},
          )
        : isCurrent
        ? strings.text(
            'challenge.huntPause.stopCurrent',
            params: <String, String>{'station': '$stationNumber'},
          )
        : strings.text(
            'challenge.huntPause.stopPending',
            params: <String, String>{'station': '$stationNumber'},
          );
    final Color titleColor = isSolved
        ? (isDark ? Colors.white : colors.ink)
        : _inkMute(isDark);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  // `rgba(255,255,255,0.06)` / `rgba(0,0,0,0.06)`, `:2939`.
                  color: isDark
                      ? const Color(0x0FFFFFFF)
                      : const Color(0x0F000000),
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                icon,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: FactTypography.bodyText.copyWith(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  color: titleColor,
                ),
              ),
            ),
            if (isSolved)
              Text(
                '+${stop.pointsAwarded}',
                style: FactTypography.mono.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.gold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `inkSoft`, `:2813`. Literal in der Quelle und kein Token, wörtlich
/// übernommen aus `hunt_start_point_view.dart`.
Color _inkSoft(bool isDark) => isDark
    ? const Color.fromRGBO(255, 255, 255, 0.55)
    : const Color.fromRGBO(0, 0, 0, 0.55);

/// `inkMute`, `:2914`. Ebenfalls Literal.
Color _inkMute(bool isDark) => isDark
    ? const Color.fromRGBO(255, 255, 255, 0.30)
    : const Color.fromRGBO(0, 0, 0, 0.30);

/// `cardBg`, `:2812`. Ebenfalls Literal, und **nicht** dasselbe wie die
/// Kachel-Hintergrundfarbe, siehe [_HuntStatTile].
Color _cardBackground(bool isDark) => isDark
    ? const Color.fromRGBO(255, 255, 255, 0.04)
    : const Color.fromRGBO(0, 0, 0, 0.04);
