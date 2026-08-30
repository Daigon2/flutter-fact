import 'dart:ui' as ui;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:fact_app/core/widgets/primary_button.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/challenges/presentation/challenge_genre.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_bubble.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_genre_filter.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_player_badge.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_puzzle_difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Assistent der Schnitzeljagd, `SnjdSetupView` in
/// `02_Frontend/app/screen-challenge.jsx:1584-1993`.
///
/// ## Warum das kein Bildschirmwechsel ist
///
/// Der Assistent hat in der Quelle **keine** eigenen Routen. `SnjdSetupView`
/// hält `step` als Zustand (`:1586`), die Marken-Blase bleibt über allen
/// Schritten stehen, und der Zurück-Weg setzt Felder zurück (`:1622-1625`),
/// was ein `context.pop()` nicht täte. Deshalb ist das hier ein Widget mit
/// Zustand und keine zweite Route. Die öffentliche Routenfläche ist mit E-25
/// auf sieben Pfade festgelegt; ein achter würde eine Migration kosten und
/// wäre für einen Schritt-Zustand die falsche Währung.
///
/// ## Der Gruppenpfad endet hier an der Auswahl
///
/// Die Quelle führt „Gruppe" auf einen Modus-Picker (`:1765-1809`) und von
/// dort auf `GrpCreateForm` beziehungsweise `TeamCreateForm` (`:1812-1835`).
/// Beide legen über Supabase eine Koop-Sitzung an, ebenso `GrpJoinInline`
/// (`:1996`), das einen sechsstelligen Code gegen den Server prüft. Von
/// diesem Unterbau existiert im Neubau **nichts**: kein Repository, keine
/// RPC-Anbindung, keine Domäne. Ein Formular, das jeden Code mit einem Fehler
/// beantwortet, wäre gegenüber dem Nutzer eine Unwahrheit (E-33).
///
/// Deshalb rufen die Gruppen-Kachel und „Mit Code beitreten" hier je einen
/// Rückruf auf, den die Tab-Seite heute nicht belegt. Sichtbar ist dasselbe
/// wie in der Quelle, nur der Weg dahinter fehlt, und er fehlt an einer
/// Stelle, an der man ihn später ohne Umbau einhängt.
///
/// ## Der Solo-Pfad endet an [onStart]
///
/// In der Quelle geht es von dort zum Startpunkt-Picker (`:4325`,
/// `setView('hotspot')`), und der ist Schritt 35. Bis dahin führt der
/// Assistent nirgendwohin. Auch das ist ein Rückruf und keine Navigation: wer
/// den Assistenten zeigt, entscheidet, was „Start" bedeutet.
class ChallengeSetupView extends ConsumerStatefulWidget {
  /// Erzeugt den Assistenten.
  const ChallengeSetupView({
    required this.onStart,
    required this.onGroupSelected,
    required this.onJoinRequested,
    super.key,
  });

  /// `paddingBottom: 120` am äußeren Kasten, `:1658`.
  ///
  /// **Nicht übernommen.** Die Zahl hält in der PWA die schwebende
  /// Reiterleiste frei. Hier macht das die Shell selbst: ihr `Scaffold` läuft
  /// mit `extendBody: true` und erhöht das untere `MediaQuery`-Padding um die
  /// Höhe der Leiste (`app/shell/app_shell.dart`). Beides zusammen wäre die
  /// doppelte Lücke, deshalb steht unten ein `SafeArea` und keine 120.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(16, 22, 16, 0);

  /// `gap: 12` zwischen den Blöcken, `:1668`.
  static const double blockGap = 12;

  /// Die Kachel „Solo", für Tests.
  static const Key soloKey = Key('challenge-setup-solo');

  /// Die Kachel „Gruppe", für Tests.
  static const Key groupKey = Key('challenge-setup-group');

  /// „Mit Code beitreten", für Tests.
  static const Key joinKey = Key('challenge-setup-join');

  /// Die Karte „Überrasch mich", für Tests.
  static const Key randomRouteKey = Key('challenge-setup-route-random');

  /// Der Startknopf, für Tests.
  static const Key startKey = Key('challenge-setup-start');

  /// Die Karte zu [difficulty], für Tests.
  static Key difficultyKey(FactPuzzleDifficulty difficulty) =>
      Key('challenge-setup-difficulty-${difficulty.code}');

  /// Die Karte zu [duration], für Tests.
  static Key durationKey(HuntDuration duration) =>
      Key('challenge-setup-duration-${duration.minutes}');

  /// Was „Starten" auslöst, `:1614-1617`:
  /// `onStart(diff, 'solo', routeKey, duration, selectedGenres)`.
  ///
  /// Der Modus `'solo'` fehlt in dieser Signatur, weil dieser Assistent nur
  /// den Solo-Pfad zu Ende führt. `routeKey` fehlt aus demselben Grund wie die
  /// Themenrouten selbst, siehe [_routeCard].
  final void Function(
    FactPuzzleDifficulty difficulty,
    HuntDuration duration,
    List<String> genreCodes,
  )
  onStart;

  /// Der Nutzer hat „Gruppe" gewählt, `:1609-1612`.
  final VoidCallback onGroupSelected;

  /// Der Nutzer will einer Sitzung mit Code beitreten, `:1742`.
  final VoidCallback onJoinRequested;

  @override
  ConsumerState<ChallengeSetupView> createState() => _ChallengeSetupViewState();
}

class _ChallengeSetupViewState extends ConsumerState<ChallengeSetupView> {
  /// `const [step, setStep] = React.useState(1)`, `:1586`.
  int _step = 1;

  /// `diff`, `:1589`.
  FactPuzzleDifficulty? _difficulty;

  /// `duration`, `:1590`.
  HuntDuration? _duration;

  /// `selectedGenres`, `:1594`.
  final Set<ChallengeGenre> _genres = <ChallengeGenre>{};

  /// `choosePlayer(false)`, `:1609-1612`.
  void _chooseSolo() {
    setState(() {
      _difficulty = null;
      _duration = null;
      _step = 2;
    });
  }

  /// `goBack()`, `:1622-1625`.
  ///
  /// Setzt zurück, statt zu navigieren: wer aus Schritt 2 herausgeht, soll
  /// keine halb gefüllte Auswahl vorfinden, wenn er wieder hineingeht.
  void _goBack() {
    setState(() {
      _step = 1;
      _difficulty = null;
      _duration = null;
    });
  }

  /// `confirmStep2()`, `:1614-1617`.
  void _confirm() {
    final FactPuzzleDifficulty? difficulty = _difficulty;
    final HuntDuration? duration = _duration;
    if (difficulty == null || duration == null) {
      return;
    }
    widget.onStart(difficulty, duration, <String>[
      for (final ChallengeGenre genre in ChallengeGenre.values)
        if (_genres.contains(genre)) genre.code,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;

    return SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ChallengeBubble(
              title: strings.text('challenge.bubbleTitle'),
              subtitle: strings.text(
                // `subForStep()`, `:1644-1655`. Der Gruppenzweig entfällt mit
                // dem Gruppenpfad.
                _step == 1 ? 'challenge.step.friends' : 'challenge.step.time',
              ),
              step: _step,
              onBack: _step > 1 ? _goBack : null,
            ),
            Padding(
              padding: ChallengeSetupView.contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _step == 1
                    ? _stepOne(strings, colors)
                    : _stepTwo(strings, colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fügt `gap: 12` zwischen die Blöcke, `:1668`.
  List<Widget> _spaced(List<Widget> blocks) {
    final List<Widget> spaced = <Widget>[];
    for (final Widget block in blocks) {
      if (spaced.isNotEmpty) {
        spaced.add(const SizedBox(height: ChallengeSetupView.blockGap));
      }
      spaced.add(block);
    }
    return spaced;
  }

  /// Schritt 1: Hero, Solo, Gruppe, Beitreten. `:1671-1752`.
  List<Widget> _stepOne(AppStrings strings, FactColors colors) {
    return _spaced(<Widget>[
      _hero(strings),
      _playerCard(
        key: ChallengeSetupView.soloKey,
        badge: const ChallengePlayerBadge.solo(),
        title: strings.text('challenge.select.solo'),
        description: strings.text('challenge.select.soloDesc'),
        onTap: _chooseSolo,
        colors: colors,
      ),
      _playerCard(
        key: ChallengeSetupView.groupKey,
        badge: const ChallengePlayerBadge.group(),
        title: strings.text('challenge.select.group'),
        description: strings.text('challenge.select.groupDesc'),
        onTap: widget.onGroupSelected,
        colors: colors,
      ),
      _joinButton(strings, colors),
    ]);
  }

  /// Schritt 2 im Solo-Pfad: Schwierigkeit, Dauer, Route, Themen, Start.
  /// `:1838-1988`.
  List<Widget> _stepTwo(AppStrings strings, FactColors colors) {
    final bool ready = _difficulty != null && _duration != null;
    return _spaced(<Widget>[
      // `marginBottom: 6` an der Überschrift, `:1843`.
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: _sectionLabel(strings.text('challenge.difficulty'), colors),
      ),
      for (final FactPuzzleDifficulty difficulty in FactPuzzleDifficulty.values)
        _difficultyCard(difficulty, strings, colors),
      // `marginTop: 10`, `marginBottom: 6`, `:1894`.
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 10, bottom: 6),
        child: _sectionLabel(
          strings.text('challenge.setup.durationLabel'),
          colors,
        ),
      ),
      Row(
        children: <Widget>[
          for (final HuntDuration duration in HuntDuration.values) ...<Widget>[
            // `gap: 8` zwischen den drei Karten, `:1898`.
            if (duration != HuntDuration.values.first) const SizedBox(width: 8),
            Expanded(child: _durationCard(duration, strings, colors)),
          ],
        ],
      ),
      // `marginTop: 4` am Routen-Block, `:1919`.
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _routeCard(strings, colors),
      ),
      ChallengeGenreFilter(
        selected: _genres,
        onToggle: (ChallengeGenre genre) => setState(() {
          if (!_genres.remove(genre)) {
            _genres.add(genre);
          }
        }),
        onClear: () => setState(_genres.clear),
      ),
      // `marginTop: 8` und `opacity: 0.4` im gesperrten Zustand, `:1981-1982`.
      // Die Deckkraft sitzt in der Quelle am Aufrufer und nicht in `.btn`,
      // deshalb auch hier.
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Opacity(
          opacity: ready ? 1 : 0.4,
          child: PrimaryButton(
            key: ChallengeSetupView.startKey,
            label: strings.text('challenge.setup.startCta'),
            onPressed: ready ? _confirm : null,
          ),
        ),
      ),
    ]);
  }

  /// Die Überschriften über Schwierigkeit und Dauer, `:1841-1846`.
  Widget _sectionLabel(String text, FactColors colors) {
    return Text(
      text.toUpperCase(),
      style: FactTypography.bodyText.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: colors.ink2,
      ),
    );
  }

  /// Der dunkle Kasten mit den vier Pillen, `:1671-1714`.
  Widget _hero(AppStrings strings) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // `linear-gradient(135deg, #1A0830 0%, #2D1408 60%, #1A0A04 100%)`,
        // `:1674`. Drei Literale, keine Tokens: der Kasten ist in beiden
        // Themes dunkel.
        final ({Alignment begin, Alignment end}) ends = cssLinearGradientEnds(
          angleDegrees: 135,
          box: Size(constraints.maxWidth, _heroHeight),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(22)),
            border: Border.all(
              // `border: '1px solid rgba(232,56,13,0.22)'`, `:1675`.
              color: const Color.fromRGBO(232, 56, 13, 0.22),
            ),
            gradient: LinearGradient(
              begin: ends.begin,
              end: ends.end,
              colors: const <Color>[
                Color(0xFF1A0830),
                Color(0xFF2D1408),
                Color(0xFF1A0A04),
              ],
              stops: const <double>[0, 0.6, 1],
            ),
            boxShadow: const <BoxShadow>[
              // `0 8px 32px rgba(0,0,0,0.28)`, `:1676`.
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.28),
                offset: Offset(0, 8),
                blurRadius: 32,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                // `padding: '20px 18px 16px'`, `:1680`.
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      strings.text('challenge.hero.city').toUpperCase(),
                      style: FactTypography.mono.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: const Color.fromRGBO(245, 240, 232, 0.55),
                      ),
                    ),
                    // `marginBottom: 10` an der Kickerzeile, `:1684`.
                    const SizedBox(height: 10),
                    Text(
                      strings.text('challenge.hero.desc'),
                      style: FactTypography.bodyText.copyWith(
                        fontSize: 13.5,
                        height: 1.55,
                        color: const Color.fromRGBO(245, 240, 232, 0.80),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                // `padding: '0 18px 18px'`, `gap: 6`, `flexWrap: 'wrap'`,
                // `:1693-1694`.
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final ({String icon, String key}) pill in _heroPills)
                      _heroPill(pill.icon, strings.text(pill.key)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Die vier Pillen, `:1696-1701`.
  ///
  /// **Jede zeigt zwei Sinnbilder.** Das Symbol steht hier im Code, und der
  /// übersetzte Text beginnt seinerseits mit einem anderen Emoji
  /// (`challenge.pills.routes` ist „🕵️ Versteckte Spuren"). Die PWA zeigt
  /// damit „🗺 🕵️ Versteckte Spuren". Übernommen wie vorgefunden, gemeldet,
  /// nicht stillschweigend um eines der beiden gekürzt.
  static const List<({String icon, String key})> _heroPills =
      <({String icon, String key})>[
        (icon: '🗺', key: 'challenge.pills.routes'),
        (icon: '📍', key: 'challenge.pills.stops'),
        (icon: '🎮', key: 'challenge.pills.modes'),
        (icon: '📸', key: 'challenge.pills.photo'),
      ];

  /// Nur für die Richtung des Verlaufs.
  ///
  /// Ein CSS-Verlaufswinkel braucht das Seitenverhältnis der Fläche, und die
  /// Höhe steht erst nach dem Layout fest; ein `LayoutBuilder` liefert nur die
  /// Breite. Der Wert ist **gemessen**, nicht geschätzt: der Kasten ist bei
  /// Systemschrift 1.0 auf 390 und auf 360 Pixel Breite 198 Pixel hoch und auf
  /// 320 Pixel Breite 230, weil dort eine Pille umbricht. Bei doppelter
  /// Systemschrift wird er höher.
  ///
  /// Die Abweichung kostet Winkel und sonst nichts: mit 198 statt 230 dreht
  /// sich die Verlaufsachse um wenige Grad. Wer das genauer braucht, misst im
  /// `CustomPainter` statt im Layout.
  static const double _heroHeight = 198;

  Widget _heroPill(String icon, String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.07),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              label,
              style: FactTypography.bodyText.copyWith(
                fontSize: 11,
                color: const Color.fromRGBO(245, 240, 232, 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Eine der beiden Kacheln der Spielerwahl, `:1723-1739`.
  Widget _playerCard({
    required Key key,
    required Widget badge,
    required String title,
    required String description,
    required VoidCallback onTap,
    required FactColors colors,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(color: colors.border, width: 1.5),
          boxShadow: const <BoxShadow>[
            // `0 2px 0 rgba(140,100,40,0.04)`, `:1728`.
            BoxShadow(
              color: Color.fromRGBO(140, 100, 40, 0.04),
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              badge,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: FactTypography.emphasis.copyWith(
                        fontSize: 19,
                        height: 1.1,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: FactTypography.bodyText.copyWith(
                        fontSize: 13,
                        color: colors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // `<path d="M9 6l6 6-6 6" />`, `:1736-1738`.
              Icon(Icons.chevron_right, size: 20, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }

  /// „🔑 Mit Code beitreten", `:1742-1750`.
  Widget _joinButton(AppStrings strings, FactColors colors) {
    return GestureDetector(
      key: ChallengeSetupView.joinKey,
      behavior: HitTestBehavior.opaque,
      onTap: widget.onJoinRequested,
      child: Padding(
        // `marginTop: 4`, `:1743`.
        padding: const EdgeInsets.only(top: 4),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: colors.border2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('🔑', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    strings.text('group.join.cta'),
                    style: FactTypography.heading.copyWith(
                      fontSize: 13,
                      color: colors.ink2,
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

  /// Eine Schwierigkeitskarte, `:1869-1888`.
  Widget _difficultyCard(
    FactPuzzleDifficulty difficulty,
    AppStrings strings,
    FactColors colors,
  ) {
    final bool selected = _difficulty == difficulty;
    final ({String emoji, String labelKey, String descriptionKey}) look =
        _difficultyLook[difficulty]!;

    return GestureDetector(
      key: ChallengeSetupView.difficultyKey(difficulty),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _difficulty = difficulty),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? colors.surface2 : colors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(
            color: selected ? colors.red : colors.border,
            width: 1.5,
          ),
          boxShadow: const <BoxShadow>[
            // `0 2px 0 rgba(140,100,40,0.06)`, `:1876`.
            BoxShadow(
              color: Color.fromRGBO(140, 100, 40, 0.06),
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _emojiTile(look.emoji, colors),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      strings.text(look.labelKey),
                      style: FactTypography.emphasis.copyWith(
                        fontSize: 18,
                        height: 1.1,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.text(look.descriptionKey),
                      style: FactTypography.bodyText.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...<Widget>[
                const SizedBox(width: 14),
                // `marginTop: 22` am Punkt, `:1887`.
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: _selectedDot(colors, size: 8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Sinnbild, Beschriftung und Beschreibung je Stufe, `:1847-1868`.
  ///
  /// Die Beschreibungen kommen aus `app_strings_supplement.dart`: die Quelle
  /// schreibt sie als Ternär ins JSX. Die kürzeren `challenge.easyDesc` und
  /// Geschwister aus den erzeugten Tabellen gehören zu einem anderen
  /// Bildschirm, siehe die Begründung dort.
  static const Map<
    FactPuzzleDifficulty,
    ({String emoji, String labelKey, String descriptionKey})
  >
  _difficultyLook =
      <
        FactPuzzleDifficulty,
        ({String emoji, String labelKey, String descriptionKey})
      >{
        FactPuzzleDifficulty.leicht: (
          emoji: '🚶',
          labelKey: 'challenge.easy',
          descriptionKey: 'challenge.setup.easyDesc',
        ),
        FactPuzzleDifficulty.mittel: (
          emoji: '🏃',
          labelKey: 'challenge.medium',
          descriptionKey: 'challenge.setup.mediumDesc',
        ),
        FactPuzzleDifficulty.schwer: (
          emoji: '🧭',
          labelKey: 'challenge.hard',
          descriptionKey: 'challenge.setup.hardDesc',
        ),
      };

  /// Die 54er-Kachel mit dem Sinnbild, `:1877-1882`.
  Widget _emojiTile(String emoji, FactColors colors) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: colors.border2),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 26)),
    );
  }

  /// Der Punkt, der die Auswahl markiert, `:1887`, `:1938`.
  Widget _selectedDot(FactColors colors, {required double size}) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.red, shape: BoxShape.circle),
      ),
    );
  }

  /// Eine Dauer-Karte, `:1904-1914`.
  Widget _durationCard(
    HuntDuration duration,
    AppStrings strings,
    FactColors colors,
  ) {
    final bool selected = _duration == duration;
    return GestureDetector(
      key: ChallengeSetupView.durationKey(duration),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _duration = duration),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? colors.surface2 : colors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(
            color: selected ? colors.red : colors.border,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                strings.text(
                  'challenge.setup.durationCard',
                  params: <String, String>{'minutes': '${duration.minutes}'},
                ),
                style: FactTypography.emphasis.copyWith(
                  fontSize: 17,
                  height: 1.1,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${duration.stopCount} '
                        '${strings.text('challenge.setup.stopsSuffix')}'
                    .toUpperCase(),
                textAlign: TextAlign.center,
                style: FactTypography.mono.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.2,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Die Routenwahl, `:1918-1970`.
  ///
  /// **Nur die Zufallskarte.** Darunter listet die Quelle die kuratierten
  /// Themenrouten der Stadt aus `HUNT_ROUTES` (`:1942-1969`), und der ganze
  /// Block hängt an `cityRoutes.length > 0`: eine Stadt ohne kuratierte
  /// Routen sieht dort genau das, was hier steht. Die Datei
  /// `02_Frontend/app/hunt-routes.jsx` ist im Neubau nicht angelegt, weil ihr
  /// Ort, ihre Stadt-Schlüssel (E-11) und ihre Drift-Prüfung nicht entschieden
  /// sind und weil `tours` sie ebenfalls braucht. Begründung im Kopf von
  /// `hunt_route_generator.dart`.
  ///
  /// Die Karte ist deshalb **nicht** antippbar: sie ist die einzige Wahl und
  /// von Anfang an ausgewählt (`routeKey` startet in der Quelle auf `zufall`,
  /// `:1591`). Ein Tipp, der nichts ändert, ist ein Bedienelement, das nichts
  /// tut (E-33). Kommen die Themenrouten dazu, kommt der Rückruf mit ihnen.
  Widget _routeCard(AppStrings strings, FactColors colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: colors.red, width: 1.5),
      ),
      child: Padding(
        key: ChallengeSetupView.randomRouteKey,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: <Widget>[
            const Text('🎲', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    strings.text('challenge.route.zufall.title'),
                    style: FactTypography.heading.copyWith(
                      fontSize: 15,
                      color: colors.ink,
                    ),
                  ),
                  Text(
                    strings.text('challenge.route.zufall.desc'),
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 12,
                      color: colors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _selectedDot(colors, size: 8),
          ],
        ),
      ),
    );
  }
}

/// Der gestrichelte Rahmen des Beitritts-Knopfes, `:1744`.
///
/// CSS legt bei `border-style: dashed` **nicht** fest, wie lang Strich und
/// Lücke sind; das entscheidet der Browser. Die 3 Pixel hier sind deshalb
/// gewählt und nicht gemessen. Alles andere am Knopf steht in der Quelle.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  /// `borderRadius: 14`, `:1743`.
  static const double cornerRadius = 14;

  /// `1px dashed`, `:1744`.
  static const double strokeWidth = 1;

  static const double dashLength = 3;
  static const double gapLength = 3;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            strokeWidth / 2,
            strokeWidth / 2,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          const Radius.circular(cornerRadius),
        ),
      );
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    for (final ui.PathMetric metric in path.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        final double end = start + dashLength;
        canvas.drawPath(
          metric.extractPath(start, end.clamp(0, metric.length)),
          paint,
        );
        start = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
