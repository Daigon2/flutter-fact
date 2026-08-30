import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/challenges/presentation/challenge_genre.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Themen-Filter des Assistenten, `ChalGenreFilter` in
/// `02_Frontend/app/screen-challenge.jsx:1538-1581`.
///
/// Ein Gitter aus acht Kacheln, Mehrfachauswahl, leer heißt kein Filter. Der
/// Filter wirkt **weich**: der Generator lässt ihn fallen, wenn danach nicht
/// mehr genug Fakten für die gewählte Länge übrig sind
/// (`hunt-generator.jsx:169-175`). Deshalb ist die Zeile unter dem Gitter eine
/// Warnung („weniger Fakten verfügbar") und keine Zusage.
class ChallengeGenreFilter extends ConsumerWidget {
  /// Erzeugt den Filter.
  const ChallengeGenreFilter({
    required this.selected,
    required this.onToggle,
    required this.onClear,
    super.key,
  });

  /// `gridTemplateColumns: 'repeat(4, 1fr)'`, `:1555`.
  static const int columns = 4;

  /// `gap: 6` im Gitter, `:1555`.
  static const double gridGap = 6;

  /// `marginBottom: 8` unter der Kopfzeile, `:1543`.
  static const double headerBottomSpacing = 8;

  /// `padding: '7px 4px'` an einer Kachel, `:1561`.
  static const EdgeInsets tilePadding = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 7,
  );

  /// `borderRadius: 10` an einer Kachel, `:1561`.
  static const double tileRadius = 10;

  /// `border: 1.5px` an einer Kachel, `:1563`.
  static const double tileBorderWidth = 1.5;

  /// `gap: 2` zwischen Sinnbild und Beschriftung, `:1560`.
  static const double tileGap = 2;

  /// `marginTop: 5` über der Hinweiszeile, `:1573`.
  static const double hintTopSpacing = 5;

  /// Der Knopf, der die Auswahl leert, für Tests.
  static const Key clearKey = Key('challenge-genre-clear');

  /// Die Hinweiszeile unter dem Gitter, für Tests.
  static const Key hintKey = Key('challenge-genre-hint');

  /// Die Kachel zu [genre], für Tests.
  static Key tileKey(ChallengeGenre genre) =>
      Key('challenge-genre-${genre.name}');

  /// Die gewählten Themen. Leer heißt: kein Filter.
  final Set<ChallengeGenre> selected;

  /// Schaltet ein Thema um, `:1973`.
  final ValueChanged<ChallengeGenre> onToggle;

  /// Leert die Auswahl.
  ///
  /// Die Quelle schreibt dafür `selected.forEach(g => onToggle(g))` (`:1548`),
  /// schaltet also jedes gewählte Thema einzeln ab. Das Ergebnis ist dasselbe,
  /// und ein eigener Rückruf sagt, was gemeint ist.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;
    final bool allClear = selected.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: headerBottomSpacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  strings.text('challenge.setup.topicsLabel'),
                  style: FactTypography.heading.copyWith(
                    fontSize: 13,
                    color: colors.ink,
                  ),
                ),
              ),
              if (!allClear)
                GestureDetector(
                  key: clearKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: Text(
                    strings.text('challenge.setup.topicsClear'),
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 11,
                      // `color: 'var(--stamp)'`, `:1549`.
                      color: colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _grid(context, strings, colors),
        if (!allClear)
          Padding(
            key: hintKey,
            padding: const EdgeInsets.only(top: hintTopSpacing),
            child: Text(
              strings.text(
                selected.length > 1
                    ? 'challenge.setup.topicsHintMany'
                    : 'challenge.setup.topicsHintOne',
                params: <String, String>{'count': '${selected.length}'},
              ),
              style: FactTypography.bodyText.copyWith(
                fontSize: 10,
                color: colors.ink2,
              ),
            ),
          ),
      ],
    );
  }

  /// Vier Spalten, zwei Zeilen, `:1555-1571`.
  ///
  /// `IntrinsicHeight` je Zeile, weil ein CSS-Gitter alle Zellen einer Zeile
  /// gleich hoch macht und „Persönlichkeit" mehr Zeilen braucht als „Natur".
  Widget _grid(BuildContext context, AppStrings strings, FactColors colors) {
    final List<ChallengeGenre> genres = ChallengeGenre.values;
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < genres.length; start += columns) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: gridGap));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int column = 0; column < columns; column++) ...<Widget>[
                if (column > 0) const SizedBox(width: gridGap),
                Expanded(
                  child: start + column < genres.length
                      ? _tile(genres[start + column], strings, colors)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _tile(ChallengeGenre genre, AppStrings strings, FactColors colors) {
    final bool on = selected.contains(genre);
    return GestureDetector(
      key: tileKey(genre),
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggle(genre),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: on ? colors.red : colors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(tileRadius)),
          border: Border.all(
            color: on ? colors.red : colors.border,
            width: tileBorderWidth,
          ),
        ),
        child: Padding(
          padding: tilePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(genre.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: tileGap),
              Text(
                strings.text(genre.labelKey),
                textAlign: TextAlign.center,
                style: FactTypography.heading.copyWith(
                  fontSize: 9,
                  height: 1.2,
                  color: on ? const Color(0xFFFFFFFF) : colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
