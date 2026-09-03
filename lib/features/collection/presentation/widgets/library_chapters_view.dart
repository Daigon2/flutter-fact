/// Das Inhaltsverzeichnis eines Bands,
/// `02_Frontend/app/screen-wallet.jsx:617-780` (`WltChaptersView`).
///
/// Der dritte Bildschirm des Reiseführers: Kopfkarte in den Farben der Stadt,
/// eine Pille „Inhaltsverzeichnis" und sechs Kapitelkarten mit römischen
/// Zahlen.
///
/// ## Ein Kapitel ohne gesammelten Fakt ist verschlossen, aber sichtbar
///
/// `locked = catFacts.length === 0` (`:722`): das Kapitel steht da, auf 45
/// Prozent Deckkraft, trägt statt seines Namens „noch nicht entdeckt" und ist
/// nicht tippbar. Das ist das Sammlergeist-Prinzip, das der Kopf der Quelldatei
/// ausdrücklich nennt: „Lücken-Counter auf jeder Ebene". Ein Kapitel, das man
/// nicht sieht, weckt keinen Ehrgeiz.
///
/// **Ein Kapitel, für das die Stadt gar keine Fakten hat, fehlt dagegen ganz**
/// (`.filter(ch => ch.allCatFacts.length > 0)`, `:639`). Der Unterschied ist
/// wichtig: „gibt es hier nicht" und „hast du noch nicht" sehen sonst gleich
/// aus.
///
/// ## Die römische Zahl zählt über alle sechs, nicht über die sichtbaren
///
/// `wltToRoman(idx + 1)` mit `idx` aus `order.map(...)`, also **vor** dem
/// Filter (`:629`, `:724`). Eine Stadt, die nur Mythos-Fakten hat, zeigt
/// deshalb ein einzelnes Kapitel „III" und nicht „I". Das sieht nach einem
/// Fehler aus und ist keiner: die Zahl ist die Kennung des Kapitels im Band
/// und keine laufende Nummer der Liste. Ein Test nagelt es fest.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_chapter_look.dart';
import 'package:fact_app/features/collection/presentation/library_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Das Inhaltsverzeichnis eines Bands.
class LibraryChaptersView extends ConsumerWidget {
  /// Erzeugt die Kapitelliste für [volume].
  const LibraryChaptersView({
    required this.volume,
    required this.chapters,
    this.onBack,
    this.onOpenChapter,
    super.key,
  });

  /// Die Kennung der Kopfkarte, für Tests.
  static const Key headerKey = Key('library-chapters-header');

  /// Die Kennung des Zurück-Wegs, für Tests.
  static const Key backKey = Key('library-chapters-back');

  /// Die Kennung des Fortschrittsbalkens, für Tests.
  static const Key progressKey = Key('library-chapters-progress');

  /// Die Kennung einer Kapitelkarte, für Tests.
  static Key chapterKey(String categoryKey) =>
      Key('library-chapter-$categoryKey');

  /// Der Band, dessen Kapitel das sind.
  final LibraryVolume volume;

  /// Alle sechs Kapitel, in der Reihenfolge der Quelle.
  ///
  /// Immer alle sechs, auch die leeren: welche die Liste zeigt, entscheidet
  /// sie selbst, und die römische Zahl braucht die Position in der ganzen
  /// Folge.
  final List<LibraryChapter> chapters;

  /// Zurück ins Regal (`onBack`, `:664`).
  final VoidCallback? onBack;

  /// Ein Kapitel öffnen (`onOpenFact(firstFact.id, …)`, `:727`).
  ///
  /// Bekommt den Kapitelschlüssel und nicht den Fakt: welcher Fakt der erste
  /// ist, hängt an der Sortierung der gesammelten Fakten, und die gehört zum
  /// Lesemodus. `null` heißt „der Lesemodus fehlt noch".
  final void Function(String categoryKey)? onOpenChapter;

  /// Der Außenabstand der Kopfkarte, `4px 18px 14px` (`:642`).
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(18, 4, 18, 14);

  /// Die Ecken der Kopfkarte (`:645`).
  static const double headerRadius = 22;

  /// Der Innenabstand der Kopfkarte, `14px 20px` (`:645`).
  static const EdgeInsets headerInnerPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  );

  /// Die Höhe des Fortschrittsbalkens (`:701`).
  static const double progressHeight = 4;

  /// Der Außenabstand der Kapitelliste, `0 18px 24px` (`:720`).
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(18, 0, 18, 24);

  /// Der Abstand zwischen zwei Kapitelkarten (`:720`).
  static const double cardGap = 10;

  /// Die Deckkraft einer verschlossenen Karte (`:735`).
  static const double lockedOpacity = 0.45;

  /// Die Seitenlänge des Zahlen-Abzeichens (`:742`).
  static const double badgeSize = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;
    final Color cityColor = _color(volume.palette.color);
    final Color cityDark = _color(volume.palette.colorDk);
    final List<int> startPages = libraryChapterStartPages(chapters);

    return ColoredBox(
      color: colors.bg,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(strings, cityColor, cityDark),
            _tocPill(strings, cityColor, cityDark),
            Padding(
              padding: listPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < chapters.length; i++)
                    if (chapters[i].total > 0)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i < chapters.length - 1 ? cardGap : 0,
                        ),
                        child: _chapterCard(
                          strings,
                          colors,
                          chapters[i],
                          number: i + 1,
                          startPage: startPages[i],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Die Kopfkarte im Verlauf der Stadt (`:641-706`).
  Widget _header(AppStrings strings, Color cityColor, Color cityDark) {
    final int collected = chapters.fold(
      0,
      (int sum, LibraryChapter c) => sum + c.collected,
    );
    final int total = chapters.fold(
      0,
      (int sum, LibraryChapter c) => sum + c.total,
    );
    final int started = chapters
        .where((LibraryChapter c) => c.isStarted)
        .length;
    // `Math.round(collected / total * 100)` (`:625`).
    final int percent = total > 0 ? (collected / total * 100).round() : 0;

    return Padding(
      padding: headerPadding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(headerRadius)),
          boxShadow: <BoxShadow>[
            // `0 10px 26px ${city.colorDk}55` (`:646`): der Schatten trägt die
            // Farbe der Stadt und nicht Schwarz.
            BoxShadow(
              color: cityDark.withAlpha(0x55),
              offset: const Offset(0, 10),
              blurRadius: 26,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(headerRadius)),
          child: Container(
            key: headerKey,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[cityColor, cityDark],
              ),
            ),
            child: Stack(
              children: <Widget>[
                const Positioned(
                  right: -30,
                  top: -38,
                  child: _DecoCircle(size: 130, color: Color(0x12FFFFFF)),
                ),
                const Positioned(
                  right: 28,
                  bottom: -18,
                  child: _DecoCircle(size: 56, color: Color(0x0DFFFFFF)),
                ),
                Padding(
                  padding: headerInnerPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _backPill(strings),
                      const SizedBox(height: 8),
                      Text(
                        volume.name,
                        style: TextStyle(
                          fontFamily: FactFont.display,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          height: 1,
                          letterSpacing: -0.5,
                          color: const Color(0xFFFFFFFF),
                          shadows: const <Shadow>[
                            Shadow(
                              color: Color(0x2E000000),
                              offset: Offset(0, 2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _HeaderChip(
                            value: '$collected',
                            label: strings.text('wallet.statStories'),
                          ),
                          _HeaderChip(
                            value: '$started',
                            label: strings.text('wallet.statChapters'),
                          ),
                          _HeaderChip(
                            label: strings.text(
                              'wallet.chaptersTotal',
                              params: <String, String>{'total': '$total'},
                            ),
                          ),
                        ],
                      ),
                      // `{pct > 0 && …}` (`:700`): ohne einen gesammelten
                      // Fakt gibt es keinen Balken, nicht einen leeren.
                      if (percent > 0) ...<Widget>[
                        const SizedBox(height: 12),
                        _progressBar(percent),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBar(int percent) => ClipRRect(
    borderRadius: BorderRadius.circular(progressHeight / 2),
    child: SizedBox(
      key: progressKey,
      height: progressHeight,
      child: Stack(
        children: <Widget>[
          const ColoredBox(color: Color(0x29FFFFFF), child: SizedBox.expand()),
          FractionallySizedBox(
            widthFactor: percent / 100,
            child: const ColoredBox(
              color: Color(0xFFFFE066),
              child: SizedBox.expand(),
            ),
          ),
        ],
      ),
    ),
  );

  /// Der Zurück-Weg als Pille in der Kopfkarte (`:663-670`).
  Widget _backPill(AppStrings strings) => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(
      key: backKey,
      onTap: onBack,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: libraryChipColor,
          border: Border.all(color: libraryChipBorderColor),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '‹ ${strings.text('wallet.libraryKicker')}',
          style: FactTypography.heading.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 9.5,
            letterSpacing: 0.5,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ),
    ),
  );

  /// Die mittige Pille „Inhaltsverzeichnis" (`:708-717`).
  ///
  /// `${city.color}15` und `${city.color}40` sind Hex-Alphawerte, also 0x15
  /// und 0x40 unverändert.
  Widget _tocPill(AppStrings strings, Color cityColor, Color cityDark) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cityColor.withAlpha(0x15),
              border: Border.all(color: cityColor.withAlpha(0x40)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '📖 ${strings.text('wallet.chaptersToc').toUpperCase()}',
              style: FactTypography.heading.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                letterSpacing: 1.5,
                color: cityDark,
              ),
            ),
          ),
        ),
      );

  /// Eine Kapitelkarte (`:721-777`).
  Widget _chapterCard(
    AppStrings strings,
    FactColors colors,
    LibraryChapter chapter, {
    required int number,
    required int startPage,
  }) {
    final bool locked = chapter.collected == 0;
    final LibraryChapterLook look = libraryChapterLookOf(chapter.categoryKey);
    final Color accent = locked ? colors.ink3 : look.color;
    final void Function(String)? open = onOpenChapter;

    final Widget card = Container(
      key: chapterKey(chapter.categoryKey),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // Eine verschlossene Karte hat **keinen** Grund, nur den Rahmen
        // (`background: locked ? 'transparent' : tok.s1`, `:734`).
        color: locked ? null : colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: badgeSize,
            height: badgeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: locked ? colors.surface2 : accent.withAlpha(0x1A),
              border: Border.all(
                color: locked ? colors.border2 : accent.withAlpha(0x55),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              libraryRomanNumeral(number),
              style: FactTypography.heading.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                height: 1,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  locked
                      ? strings.text('wallet.chaptersLocked')
                      : strings.text('cat.${chapter.categoryKey}'),
                  style: TextStyle(
                    fontFamily: FactFont.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1.15,
                    letterSpacing: -0.2,
                    color: colors.ink,
                  ),
                ),
                if (!locked) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    '${chapter.collected} '
                    '${strings.text('wallet.statStories')} · S.$startPage',
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 12.5,
                      letterSpacing: 0.2,
                      color: colors.ink2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!locked)
            Text(
              '›',
              style: FactTypography.heading.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                height: 1,
                color: accent,
              ),
            ),
        ],
      ),
    );

    if (locked) {
      // `opacity: 0.45` und `cursor: default`: kein Erkenner, also auch kein
      // Tipp, der ins Leere geht.
      return Opacity(opacity: lockedOpacity, child: card);
    }
    return GestureDetector(
      onTap: open == null ? null : () => open(chapter.categoryKey),
      child: card,
    );
  }

  static Color _color(String hex) =>
      Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// Einer der beiden Deko-Kreise der Kopfkarte (`:652-661`).
class _DecoCircle extends StatelessWidget {
  const _DecoCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// Ein Chip in der Kopfkarte (`:679-781`).
///
/// [value] ist die goldene Zahl davor und fehlt beim dritten Chip, der die
/// Gesamtzahl im Text trägt.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final String? number = value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: libraryChipColor,
        border: Border.all(color: libraryChipBorderColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            if (number != null)
              TextSpan(
                text: '$number ',
                style: const TextStyle(color: Color(0xFFFFE066)),
              ),
            TextSpan(text: label),
          ],
        ),
        style: FactTypography.heading.copyWith(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          color: const Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}
