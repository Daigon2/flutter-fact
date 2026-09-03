/// Die Fußleiste der Buchseite,
/// `02_Frontend/app/screen-wallet.jsx:1757-1800`.
///
/// Drei Dinge in einer Reihe: zurückblättern, wo man ist, weiterblättern.
///
/// ## Ein Knopf am Ende der Folge bleibt stehen
///
/// `opacity: prev ? 1 : 0.25` und `background: prev ? gradient : transparent`
/// (`:1768-1772`): der Knopf verschwindet nicht, er wird blass und
/// durchsichtig. Das ist dieselbe Entscheidung wie beim verschlossenen Kapitel
/// in `library_chapters_view.dart` und derselbe Grund: eine Fläche, die
/// verschwindet, verschiebt alles daneben, und der Leser verliert die Stelle.
///
/// ## Die Seitenzahl zählt den Zusammenhang, nicht den Band
///
/// `{pageInTotal} / {totalInContext}` (`:1783`). Wer Kapitel III öffnet, sieht
/// hier „1 / 4" und nicht „7 / 23". Warum das kein Widerspruch zur Seitenzahl
/// in der Kapitelliste ist, steht im Kopf von `library_reader.dart`.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/collection/application/library_reader.dart';
import 'package:fact_app/features/collection/presentation/library_reader_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Fußleiste mit den beiden Blätter-Knöpfen und der Seitenzahl.
class LibraryReaderFooter extends ConsumerWidget {
  /// Erzeugt die Fußleiste für [page].
  const LibraryReaderFooter({
    required this.page,
    required this.palette,
    required this.cityColor,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  /// Die Kennung des Zurück-Knopfs, für Tests.
  static const Key previousKey = Key('library-reader-previous');

  /// Die Kennung des Weiter-Knopfs, für Tests.
  static const Key nextKey = Key('library-reader-next');

  /// Die Kennung der Seitenzahl, für Tests.
  static const Key counterKey = Key('library-reader-counter');

  /// Die Kennung des Fortschrittsbalkens, für Tests.
  static const Key progressKey = Key('library-reader-progress');

  /// Die offene Seite mit ihren Nachbarn.
  final LibraryReaderPage page;

  /// Die Farben des Buchpapiers.
  final LibraryReaderPalette palette;

  /// Die Farbe der Stadt, für die Trennlinie oben.
  final Color cityColor;

  /// Eine Seite zurück. `null`, wenn es keine gibt.
  final VoidCallback? onPrevious;

  /// Eine Seite weiter. `null`, wenn es keine gibt.
  final VoidCallback? onNext;

  /// Die Deckkraft der Trennlinie oben, `${city.color}22` (`:1760`).
  static const int borderAlpha = 0x22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.footer,
        border: Border(
          top: BorderSide(color: cityColor.withAlpha(borderAlpha)),
        ),
      ),
      child: Padding(
        padding: libraryReaderFooterPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: libraryReaderFooterHeight,
          ),
          child: Row(
            children: <Widget>[
              _TurnButton(
                buttonKey: previousKey,
                label: strings.text('reader.prev'),
                chevron: '‹',
                chevronLeading: true,
                onTap: onPrevious,
              ),
              Expanded(
                child: _Counter(page: page, strings: strings),
              ),
              _TurnButton(
                buttonKey: nextKey,
                label: strings.text('reader.next'),
                chevron: '›',
                chevronLeading: false,
                onTap: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Die Seitenzahl mit ihrem Balken (`screen-wallet.jsx:1777-1786`).
class _Counter extends StatelessWidget {
  const _Counter({required this.page, required this.strings});

  final LibraryReaderPage page;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    // `pageInTotal / totalInContext * 100`, hier als Bruch. Bei einer leeren
    // Folge käme eine Division durch null heraus; die Quelle fängt das mit
    // `totalInContext > 0 ? … : 0` ab (`:1784`). Der Fall ist hier
    // unerreichbar, weil eine Seite ohne Folge nicht entsteht, und genau
    // deshalb steht die Klammer da: sie ist eine Zusicherung und kein Zweig.
    final double progress = page.count > 0 ? page.number / page.count : 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          '${page.number} / ${page.count}',
          key: LibraryReaderFooter.counterKey,
          style: FactTypography.mono.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: libraryReaderPageNumberColor,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(libraryReaderProgressHeight / 2),
          child: SizedBox(
            key: LibraryReaderFooter.progressKey,
            width: libraryReaderProgressWidth,
            height: libraryReaderProgressHeight,
            child: ColoredBox(
              color: libraryReaderProgressTrackColor,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: const ColoredBox(color: libraryReaderPageNumberColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Einer der beiden Blätter-Knöpfe (`screen-wallet.jsx:1765-1799`).
class _TurnButton extends StatelessWidget {
  const _TurnButton({
    required this.buttonKey,
    required this.label,
    required this.chevron,
    required this.chevronLeading,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final String chevron;
  final bool chevronLeading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    final Widget chevronText = Text(
      chevron,
      style: const TextStyle(
        fontFamily: FactFont.display,
        fontWeight: FontWeight.w900,
        fontSize: 18,
        height: 1,
        color: Colors.white,
      ),
    );

    final Widget labelText = Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontFamily: FactFont.display,
        fontWeight: FontWeight.w900,
        fontSize: 10,
        letterSpacing: 0.5,
        color: Colors.white,
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : libraryReaderDisabledOpacity,
      child: Semantics(
        button: enabled,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          key: buttonKey,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: enabled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        libraryReaderBrandLight,
                        libraryReaderBrand,
                      ],
                    )
                  : null,
              border: Border.all(
                color: enabled
                    ? libraryReaderBrandDark
                    : const Color(0x00000000),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (chevronLeading) chevronText,
                  if (chevronLeading) const SizedBox(width: 6),
                  labelText,
                  if (!chevronLeading) const SizedBox(width: 6),
                  if (!chevronLeading) chevronText,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
