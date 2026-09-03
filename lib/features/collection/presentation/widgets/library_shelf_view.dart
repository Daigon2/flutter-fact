/// Das Bücherregal, `02_Frontend/app/screen-wallet.jsx:914-1031`.
///
/// Überschriftzeile, Regalkasten mit Reihen und Holzbrettern, darunter der
/// Hinweis zum Antippen.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/widgets/dashed_border_painter.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_geometry.dart';
import 'package:fact_app/features/collection/presentation/library_look.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_book_spine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Das Regal mit allen Bänden.
class LibraryShelfView extends ConsumerWidget {
  /// Erzeugt das Regal für [volumes].
  const LibraryShelfView({required this.volumes, this.onOpenVolume, super.key});

  /// Die Kennung des Regalkastens, für Tests.
  static const Key boxKey = Key('library-shelf-box');

  /// Die Kennung eines Leerplatzes, für Tests.
  static Key emptySlotKey(int row, int column) =>
      Key('library-shelf-empty-$row-$column');

  /// Die Bände, in Regalfolge.
  final List<LibraryVolume> volumes;

  /// Was das Antippen eines Bandes auslöst.
  ///
  /// `null`, solange das Stadt-Cover fehlt (Schritt 46). Siehe
  /// [LibraryBookSpine.onTap].
  final void Function(LibraryVolume volume)? onOpenVolume;

  /// Der Außenabstand, `0 18px 14px` (`screen-wallet.jsx:915`).
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 0, 18, 14);

  /// Der Abstand der Überschriftzeile, `4px 4px 10px`
  /// (`screen-wallet.jsx:916`).
  static const EdgeInsets labelPadding = EdgeInsets.fromLTRB(4, 4, 4, 10);

  /// Der Abstand zwischen den Teilen der Überschriftzeile
  /// (`screen-wallet.jsx:916`).
  static const double labelGap = 8;

  /// Der Abstand über dem Hinweis zum Antippen (`screen-wallet.jsx:1029`).
  static const double tapHintSpacing = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;
    final List<List<LibraryVolume?>> rows = libraryShelfRows(volumes);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _label(strings, colors),
          Container(
            key: boxKey,
            padding: libraryShelfBoxPadding,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(libraryShelfBoxRadius),
              ),
              gradient: LinearGradient(
                // `180deg` in CSS zeigt nach unten.
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: libraryShelfBoxColors,
              ),
            ),
            child: Column(
              children: <Widget>[
                for (int row = 0; row < rows.length; row++)
                  _row(strings, rows[row], row),
              ],
            ),
          ),
          const SizedBox(height: tapHintSpacing),
          Text(
            strings.text('wallet.shelfTap'),
            textAlign: TextAlign.center,
            style: FactTypography.mono.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 10,
              letterSpacing: 0.06,
              color: colors.ink3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(AppStrings strings, FactColors colors) => Padding(
    padding: labelPadding,
    child: Row(
      children: <Widget>[
        Text(
          strings.text('wallet.shelfLabel').toUpperCase(),
          style: FactTypography.mono.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 9,
            letterSpacing: 2,
            color: colors.ink3,
          ),
        ),
        const SizedBox(width: labelGap),
        Expanded(child: Container(height: 1, color: colors.border)),
        const SizedBox(width: labelGap),
        Text(
          // `{activeCities.length} {t('wallet.shelfVols')}`,
          // `screen-wallet.jsx:925`. Gezählt werden die **Bände**, nicht die
          // Leerplätze: eine Stadt ohne Fakten hat keinen Band, und die
          // Mindestzahl von zwei Reihen füllt nur die Optik.
          '${volumes.length} ${strings.text('wallet.shelfVols')}',
          style: FactTypography.heading.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 10,
            color: colors.ink3,
          ),
        ),
      ],
    ),
  );

  Widget _row(AppStrings strings, List<LibraryVolume?> row, int rowIndex) =>
      Padding(
        padding: EdgeInsets.only(
          top: rowIndex > 0 ? libraryRowTopPadding : 0,
          bottom: libraryRowBottomPadding,
        ),
        child: Stack(
          // Das Brett ragt links und rechts über die Reihe hinaus
          // (`left: -8, right: -8`), und der Regalkasten hat innen 14 Pixel
          // Luft. Ohne `Clip.none` schnitte der Stapel genau diesen Überstand
          // ab, und das Brett endete an der Buchkante.
          clipBehavior: Clip.none,
          children: <Widget>[
            Row(
              // `alignItems: 'flex-end'` (`screen-wallet.jsx:940`): die Bücher
              // stehen auf dem Brett, und weil sie unterschiedlich hoch sind,
              // ragen sie oben ungleich weit hinauf.
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int column = 0; column < row.length; column++) ...<Widget>[
                  if (column > 0) const SizedBox(width: libraryBookGap),
                  Expanded(
                    child: _slot(strings, row[column], rowIndex, column),
                  ),
                ],
              ],
            ),
            Positioned(
              left: -libraryShelfBoardOverhang,
              right: -libraryShelfBoardOverhang,
              bottom: 0,
              height: libraryShelfBoardHeight,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.circular(libraryShelfBoardRadius),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: libraryShelfBoardStops,
                    colors: libraryShelfBoardColors,
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      );

  Widget _slot(
    AppStrings strings,
    LibraryVolume? volume,
    int rowIndex,
    int columnIndex,
  ) {
    if (volume == null) {
      return _emptySlot(strings, rowIndex, columnIndex);
    }
    final void Function(LibraryVolume)? open = onOpenVolume;
    return LibraryBookSpine(
      volume: volume,
      volumeNumber: libraryVolumeNumber(
        volume,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      ),
      onTap: open == null ? null : () => open(volume),
    );
  }

  Widget _emptySlot(AppStrings strings, int rowIndex, int columnIndex) =>
      SizedBox(
        key: emptySlotKey(rowIndex, columnIndex),
        height: libraryEmptySlotHeight,
        child: CustomPaint(
          painter: const DashedBorderPainter(
            color: libraryEmptySlotBorderColor,
            borderRadius: libraryBookRadius,
            // `2px dashed`, `screen-wallet.jsx:948`.
            strokeWidth: 2,
          ),
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                strings.text('wallet.shelfEmpty').toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FactTypography.mono.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 8.5,
                  letterSpacing: 1.5,
                  color: libraryEmptySlotTextColor,
                ),
              ),
            ),
          ),
        ),
      );
}
