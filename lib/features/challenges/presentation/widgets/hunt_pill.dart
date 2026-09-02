/// Die Jagd-Pille der laufenden Solo-Jagd, `HuntPill` in
/// `02_Frontend/app/screen-map.jsx:1011-1135`. Schritt 37.
///
/// ## Woher der Zustand kommt, und woher nicht
///
/// Dieses Widget liest [huntRunProvider] selbst: solange keine Jagd läuft,
/// zeigt es nichts (`if (!activeHunt || !activeHunt.stops) return null;`,
/// `:1025`). Die **Nutzerposition** dagegen kommt als Parameter herein und
/// nicht aus einem eigenen Provider-Zugriff. `userLocationProvider` liegt in
/// `discovery/presentation/notifiers/`, und Regel 8 sperrt jedem anderen
/// Feature den Import aus dem `presentation/` eines Features. Ein eigenes
/// Abonnement am Ortungsdienst wäre außerdem der **dritte** Verbraucher
/// desselben Stroms: `hunt_start_providers.dart` benennt im eigenen
/// Kopfkommentar bereits die offene Kante, dass der 35-Meter-Filter zwischen
/// Dienst und Verbraucher wandern sollte, sobald ein zweiter Verbraucher
/// dazukommt. Ein dritter verschärft genau das. Die Position kommt deshalb aus
/// der App-Komposition, `lib/app/routing/app_routes.dart`.
///
/// ## Die fehlende Peilung, eine offene Lücke und keine stille Annahme
///
/// Die Quelle rechnet `bearing = mapBearing(userPos, stop)`
/// (`screen-map.jsx:647-653`, Kugelnavigation). `MapPosition` trug dafür
/// zunächst **kein** Gegenstück, und der erste Bau dieser Datei hat die Lücke
/// offen gelassen und gemeldet, statt die Formel hier nachzubauen. Das war
/// richtig: eine Peilung ist domänenwertig und gehört neben
/// [MapPosition.distanceInMetersTo], nicht in ein Widget.
///
/// **Die Lücke ist am 31.08.2026 geschlossen**,
/// [MapPosition.bearingInDegreesTo] gibt es seither. Diese Datei rechnet die
/// Peilung deshalb aus denselben zwei Punkten wie die Distanz, eine Zeile
/// darunter, und braucht keinen eigenen Parameter dafür. Der Pfeil erscheint
/// damit wirklich, statt nur geprüft dazustehen.
///
/// ## Die Pfeil-Glyphen gehören hierher, nicht in die Domäne
///
/// `hunt_arrow.dart` liefert nur den Index (0 bis 7); die acht Zeichen selbst
/// sind Oberflächentext und stehen deshalb in [huntArrowGlyphs].
///
/// ## E-60: welche Station die Hinweise beschreibt, ist offen
///
/// Die Quelle legt an Stopp `i` das Hinweis-Trio des Fakts von Stopp `i + 1`
/// ab (`hunt-generator.jsx`) und liest es an der aktuellen Station
/// (`screen-map.jsx:1034`). Ob das Absicht oder ein Defekt ist, ist in
/// `REBUILD_STATUS.md` als E-60 offen. Gebaut ist hier die **Paritätsvariante**
/// (Hinweise der **nächsten** Station), gekapselt in [_nextStationHintTexts]:
/// fällt die Entscheidung um, ändert sich dort eine Zeile.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/challenges/application/active_hunt_providers.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:fact_app/features/challenges/domain/hunt_arrow.dart';
import 'package:fact_app/features/challenges/domain/hunt_hints.dart';
import 'package:fact_app/features/challenges/domain/hunt_navigation_aids.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die acht Pfeilzeichen der Quelle, `screen-map.jsx:1057`, indiziert mit
/// [huntArrowIndexFor]. Index 0 ist Norden, im Uhrzeigersinn weiter.
@visibleForTesting
const List<String> huntArrowGlyphs = <String>[
  '↑',
  '↗',
  '→',
  '↘',
  '↓',
  '↙',
  '←',
  '↖',
];

/// Die Glyphe für [bearingDegrees], siehe [huntArrowGlyphs].
@visibleForTesting
String huntArrowGlyphFor(double bearingDegrees) =>
    huntArrowGlyphs[huntArrowIndexFor(bearingDegrees)];

/// Unter welcher Distanz noch in Metern gezeigt wird, `screen-map.jsx:1098`:
/// `dist < 1000 ? Math.round(dist) + 'm' : (dist / 1000).toFixed(1) + 'km'`.
@visibleForTesting
const double huntPillKmThresholdMeters = 1000;

/// Formatiert [meters] wörtlich wie `:1098`.
///
/// Unter der Schwelle gerundete Meter, das `m` steht wie in `fact_page.dart`
/// (`_pill`, `:886`) als Literal und nicht als Übersetzungsschlüssel: es ist
/// ein Einheitenzeichen, kein Lesetext. Die Kilometer-Einheit hat mit
/// `entdecken.km` bereits einen Schlüssel in den erzeugten Tabellen, der hier
/// wiederverwendet wird, statt einen zweiten anzulegen.
@visibleForTesting
String formatHuntPillDistance(double meters, AppStrings strings) {
  if (meters < huntPillKmThresholdMeters) {
    return '${meters.round()}m';
  }
  return '${(meters / 1000).toStringAsFixed(1)}${strings.text('entdecken.km')}';
}

/// Die Pille der laufenden Solo-Jagd, siehe den Bibliothekskopf.
///
/// Zeigt nichts, solange keine Jagd läuft.
class HuntPill extends ConsumerStatefulWidget {
  /// Erzeugt die Pille.
  const HuntPill({this.userPosition, super.key});

  /// Die Position des Nutzers, oder `null` ohne Ortung. Kommt von außen, siehe
  /// den Bibliothekskopf.
  final MapPosition? userPosition;

  /// Höhe der eingeklappten Zeile, `:1080`.
  static const double collapsedRowHeight = 60;

  /// Seitlicher Innenabstand der eingeklappten Zeile, `padding:'0 14px'`,
  /// `:1080`. Gleichzeitig der Innenabstand des ausgeklappten Bereichs unten
  /// und oben, `padding:'0 14px 14px'`, `:1108`.
  static const double horizontalPadding = 14;

  /// Abstand der Elemente in der eingeklappten Zeile, `gap:10`, `:1080`.
  static const double rowGap = 10;

  /// Eckenradius der ganzen Pille, `borderRadius:16`, `:1076`.
  static const double cornerRadius = 16;

  @override
  ConsumerState<HuntPill> createState() => _HuntPillState();
}

class _HuntPillState extends ConsumerState<HuntPill> {
  /// `useState(false)`, `:1012`.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final HuntRun? run = ref.watch(huntRunProvider);
    if (run == null) {
      return const SizedBox.shrink();
    }
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;
    final HuntRunStop currentStop = run.currentStop;
    final HuntNavigationAids aids = HuntNavigationAids.forDifficulty(
      run.plan.difficulty,
    );
    final MapPosition? userPosition = widget.userPosition;

    // `showDist = diff === 'leicht' || diff === 'mittel'`, `showNav = showDist
    // && userPos && stop.lat && stop.lng`, `:1051-1052`. Die Station hat immer
    // eine Position ([HuntStop.position] ist nicht nullbar), das dritte
    // Glied der Quelle entfällt deshalb hier.
    final bool showsDistance = aids.showsDistance && userPosition != null;
    final double? distanceInMeters = showsDistance
        ? userPosition.distanceInMetersTo(currentStop.stop.position)
        : null;
    // `showArrow = diff === 'leicht'`, `:1050`, zusätzlich an dieselbe
    // Navigationsbedingung gebunden wie die Distanz (`:1094`, verschachtelt in
    // `showNav`) und an das Vorliegen einer Peilung, siehe den Bibliothekskopf.
    final bool showsArrow = aids.showsArrow && showsDistance;
    // Aus denselben zwei Punkten wie die Distanz eine Zeile darüber. Die
    // Quelle rechnet an derselben Stelle `mapBearing(userPos, stop)`
    // (`screen-map.jsx:1055`).
    final double? bearingDegrees = showsArrow
        ? userPosition.bearingInDegreesTo(currentStop.stop.position)
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        // `linear-gradient(135deg,#E8380D,#c02a05)`, `:1075`. Der erste Farbwert
        // ist `FactColors.red`, siehe dort; für den zweiten gibt es kein Token.
        gradient: LinearGradient(
          begin: const Alignment(-0.7071, -0.7071),
          end: const Alignment(0.7071, 0.7071),
          colors: <Color>[colors.red, const Color(0xFFC02A05)],
        ),
        borderRadius: BorderRadius.circular(HuntPill.cornerRadius),
        // `boxShadow: '0 6px 20px rgba(232,56,13,0.4)'`, `:1076`.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.red.withValues(alpha: 0.4),
            offset: const Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HuntPill.cornerRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _collapsedRow(
              strings: strings,
              run: run,
              currentStop: currentStop,
              showsArrow: showsArrow,
              showsDistance: showsDistance,
              distanceInMeters: distanceInMeters,
              bearingDegrees: bearingDegrees,
            ),
            if (_expanded) _expandedHints(ref: ref, strings: strings, run: run),
          ],
        ),
      ),
    );
  }

  /// Die eingeklappte Zeile, `:1079-1105`.
  Widget _collapsedRow({
    required AppStrings strings,
    required HuntRun run,
    required HuntRunStop currentStop,
    required bool showsArrow,
    required bool showsDistance,
    required double? distanceInMeters,
    required double? bearingDegrees,
  }) {
    return GestureDetector(
      // `cursor:pointer` gilt in der Quelle für die ganze Zeile, `:1080`,
      // nicht nur für die Stellen, an denen Text steht. Ohne `opaque` würde
      // ein `GestureDetector` einen Tipp auf die leere Fläche neben der
      // linksbündigen Spalte gar nicht erst als Treffer werten.
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: SizedBox(
        height: HuntPill.collapsedRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HuntPill.horizontalPadding,
          ),
          child: Row(
            children: <Widget>[
              // `<span>🎯</span>`, `fontSize:20`, `:1083`.
              const Text('🎯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: HuntPill.rowGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // `Station {n} / {total}`, klein und in Versalien,
                    // `fontFamily:'JetBrains Mono', fontSize:10,
                    // color:'rgba(255,255,255,0.7)', fontWeight:700,
                    // letterSpacing:'0.08em', textTransform:'uppercase'`,
                    // `:1085-1086`. `textTransform` gibt es in Flutter nicht,
                    // deshalb `toUpperCase()` am Text selbst.
                    Text(
                      strings
                          .text(
                            'challenge.huntPill.stationCounter',
                            params: {
                              'station': '${run.currentStopIndex + 1}',
                              'total': '${run.stops.length}',
                            },
                          )
                          .toUpperCase(),
                      style: FactTypography.mono.copyWith(
                        fontSize: 10,
                        color: const Color(0xB3FFFFFF),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // `fontFamily:'Nunito', fontWeight:800, fontSize:14,
                    // color:'#fff'`, einzeilig mit Ellipse, `:1088-1089`.
                    Text(
                      currentStop.stop.fact.canonicalTitle.isEmpty
                          ? strings.text('challenge.huntPill.missingTitle')
                          : currentStop.stop.fact.canonicalTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FactTypography.heading.copyWith(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (showsDistance)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    // `gap:4`, `:1093`.
                    children: <Widget>[
                      if (showsArrow) ...<Widget>[
                        Text(
                          huntArrowGlyphFor(bearingDegrees!),
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        formatHuntPillDistance(distanceInMeters!, strings),
                        style: FactTypography.mono.copyWith(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: HuntPill.rowGap),
              // Der Tipp-Knopf, `:1102-1104`. `💡` steht davon getrennt: das
              // ist Bildschmuck des Widgets, kein Bestandteil des Lesetexts,
              // siehe den Kopfkommentar von `app_strings_supplement.dart` zu
              // `audio.dialog.volumeHint` und `AuthField.icon` in
              // `signup_page.dart:352`.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x38FFFFFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('💡', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        strings.text('challenge.huntPill.hintsLabel'),
                        style: FactTypography.emphasis.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Der ausgeklappte Bereich, `:1107-1132`.
  Widget _expandedHints({
    required WidgetRef ref,
    required AppStrings strings,
    required HuntRun run,
  }) {
    final List<String?> hintTexts = _nextStationHintTexts(run, strings);
    final List<Widget> rows = <Widget>[];
    for (int index = 0; index < huntHintCount; index++) {
      final String? text = hintTexts[index];
      final bool unlocked =
          isHuntHintFree(index) || run.unlockedHintIndices.contains(index);
      // `if (!hint && !unlockedHints[idx]) return null;`, `:1110`: ein
      // gesperrter Hinweis ohne Text wird gar nicht gezeigt.
      if (text == null && !unlocked) {
        continue;
      }
      rows.add(
        _hintRow(
          ref: ref,
          strings: strings,
          index: index,
          text: text,
          unlocked: unlocked,
        ),
      );
    }
    rows.add(_closeRow(strings));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HuntPill.horizontalPadding,
        0,
        HuntPill.horizontalPadding,
        HuntPill.horizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  /// Eine Zeile im ausgeklappten Bereich, `:1111-1125`.
  Widget _hintRow({
    required WidgetRef ref,
    required AppStrings strings,
    required int index,
    required String? text,
    required bool unlocked,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // `{idx + 1}`, `:1113`.
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 8),
                child: Text(
                  '${index + 1}',
                  style: FactTypography.mono.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xB3FFFFFF),
                  ),
                ),
              ),
              Expanded(
                child: unlocked
                    ? Text(
                        // `{hint || '—'}`, `:1115`: derselbe Platzhalter wie
                        // beim fehlenden Stationstitel, hier für einen leeren
                        // Text an einem freigeschalteten Hinweis. In der
                        // laufenden App unerreichbar (der Knopf, der einen
                        // Hinweis freischaltet, existiert nur, wenn Text
                        // vorliegt), als Absicherung trotzdem gebaut.
                        text ?? strings.text('challenge.huntPill.missingTitle'),
                        style: FactTypography.bodyText.copyWith(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.45,
                        ),
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ref
                            .read(huntRunProvider.notifier)
                            .unlockHint(index),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text('🔒', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                strings.text(
                                  'challenge.huntPill.hintLocked',
                                  params: {'cost': '${huntHintCosts[index]}'},
                                ),
                                style: FactTypography.emphasis.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Der Einklapp-Text, `:1127-1130`.
  Widget _closeRow(AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('▲', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                strings.text('challenge.huntPill.close'),
                style: FactTypography.heading.copyWith(
                  fontFamily: FactFont.display,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: const Color(0x99FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Die drei Hinweistexte für die aktuelle Station, aus dem Fakt der
/// **nächsten** Station. Siehe „E-60" im Bibliothekskopf.
///
/// Index 0 fällt, wenn die nächste Station keinen eigenen ersten Hinweis
/// trägt, auf `challenge.huntPill.hintFallback` zurück (`stop.nextHint ||
/// 'Schau dich in der Umgebung aufmerksam um.'`, `:1036`/`:1040`, immer wahr
/// in der Quelle, weil das alte `nextHint`-Feld hier kein Gegenstück hat).
/// Indizes 1 und 2 bleiben ohne eigenen Text `null`.
///
/// **An der letzten Station gibt es keine nächste, und trotzdem steht dort der
/// Rückfallsatz an Index 0.** Das ist nachgemessen und war zuerst falsch
/// gebaut: mein Auftrag sagte „die letzte Station bekommt keine", der Bauende
/// hat die Abweichung von der Quelle gemeldet, und die Quelle gewinnt. Ihr
/// Ausdruck `stop.locationHints || (dbHints && (...) ? [...] : [stop.nextHint
/// || 'Schau dich...', null, null])` (`:1035-1043`) fällt an der letzten
/// Station in den **else**-Zweig, weil `nextHints` dort `null` ist, und der
/// setzt genau diesen Satz an Index 0. Ein Nutzer an der letzten Station sieht
/// also einen offenen ersten Hinweis mit dem Rückfalltext, nicht eine leere
/// Fläche.
List<String?> _nextStationHintTexts(HuntRun run, AppStrings strings) {
  final int nextIndex = run.currentStopIndex + 1;
  if (nextIndex >= run.plan.stops.length) {
    // Der else-Zweig der Quelle, siehe oben: nur der Rückfallsatz, und der
    // steht an Index 0, den [isHuntHintFree] ohnehin offen hält.
    return <String?>[
      strings.text('challenge.huntPill.hintFallback'),
      null,
      null,
    ];
  }
  final List<String> hints = run.plan.stops[nextIndex].fact.stationHints;
  String? at(int i) =>
      (i < hints.length && hints[i].isNotEmpty) ? hints[i] : null;
  return <String?>[
    at(0) ?? strings.text('challenge.huntPill.hintFallback'),
    at(1),
    at(2),
  ];
}
