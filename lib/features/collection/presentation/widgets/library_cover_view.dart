/// Das Stadt-Cover des Reiseführers,
/// `02_Frontend/app/screen-wallet.jsx:460-616` (`WltCoverView`).
///
/// Der zweite der drei Zustände: ein aufgeschlagener Buchdeckel mit
/// Illustration, Titelblock, drei Kennzahlen und dem Weg in die Kapitel.
///
/// ## Der ganze Deckel ist der Knopf
///
/// `handleCoverClick` (`:473-476`) führt in die Kapitel, **außer** der Tipp
/// traf ein Element mit `data-cover-interactive="1"`. Die Quelle löst das über
/// die DOM-Hierarchie: der Zurück-Pfeil, die Weiterlesen-Pille und der
/// Intro-Knopf tragen das Attribut und rufen zusätzlich `stopPropagation()`.
///
/// **In Flutter ist das umgekehrt und einfacher.** Ein Tipp geht an den
/// innersten Erkenner, der ihn beansprucht; ein `GestureDetector` um alles
/// bekommt ihn nur, wenn kein Kind zugegriffen hat. Das Attribut braucht
/// deshalb keine Entsprechung, und `stopPropagation` auch nicht. Der Knopf
/// „Alle Kapitel" ist in der Quelle bewusst **ohne** das Attribut (`:574`),
/// weil er dasselbe tut wie der Deckel; hier hat er trotzdem seinen eigenen
/// Erkenner, damit die Vorlesehilfe ihn benennen kann.
///
/// ## Drei Teile fehlen, alle drei aus dem Grund der Quelle selbst
///
/// * Die **Weiterlesen-Pille** (`:561-573`) hängt an `Storage.getLastRead()`.
///   Einen Leseverlauf gibt es nicht, und die Quelle zeigt die Pille nur bei
///   `{lastFact && …}`. Sie kommt mit dem Lesemodus, Schritt 47.
/// * Der **Intro-Knopf** (`:582-601`) hängt an `CITY_INTROS`, einem eigenen
///   Datensatz mit Willkommenstexten je Stadt. Auch er steht nur bei
///   `{introKey && …}`, und ohne die Daten gibt es keinen Schlüssel.
/// * Die Kachel **„seit"** zeigt ein Datum aus dem Leseverlauf. Ohne
///   Zeitstempel steht dort `—`, und zwar genau das Zeichen, das die Quelle
///   bei leerem Verlauf zeigt. Siehe `wallet.statSincePlaceholder`.
///
/// ## Das Jahr kommt von außen
///
/// `new Date().getFullYear()` (`:548`) steht in der Untertitelzeile. Als
/// Parameter mit `DateTime.now().year` als Vorgabe: `docs/engineering/testing.md`
/// verlangt, Zeit zu kontrollieren, und ein Test, der die Jahreszahl des
/// laufenden Systems erwartet, wird am 1. Januar rot.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_illustrations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Buchdeckel einer Stadt.
class LibraryCoverView extends ConsumerWidget {
  /// Erzeugt das Cover für [volume].
  const LibraryCoverView({
    required this.volume,
    required this.startedChapters,
    this.onBack,
    this.onOpenChapters,
    this.year,
    super.key,
  });

  /// Die Kennung des Deckels, für Tests.
  static const Key coverKey = Key('library-cover');

  /// Die Kennung des Zurück-Wegs, für Tests.
  static const Key backKey = Key('library-cover-back');

  /// Die Kennung des Knopfes „Alle Kapitel", für Tests.
  static const Key chaptersKey = Key('library-cover-chapters');

  /// Die Kennung einer Kennzahl-Kachel, für Tests.
  static Key statKey(String name) => Key('library-cover-stat-$name');

  /// Der Band, dessen Deckel das ist.
  final LibraryVolume volume;

  /// Wie viele der sechs Kapitel angefangen sind.
  ///
  /// `chaptersCount = cats.filter(c => c.collected > 0).length` (`:467`).
  /// Kommt als Zahl herein und nicht als Kapitelliste: der Deckel zeigt nur
  /// sie, und die Liste selbst gehört Schritt 47.
  final int startedChapters;

  /// Zurück ins Regal (`onBack`, `:513`).
  final VoidCallback? onBack;

  /// In die Kapitelliste (`onShowChapters`, `:475` und `:574`).
  ///
  /// `null` heißt „Schritt 47 fehlt noch": der Deckel bleibt dann still statt
  /// in einen halben Bildschirm zu führen.
  final VoidCallback? onOpenChapters;

  /// Das Jahr in der Untertitelzeile, siehe den Kopf dieser Datei.
  final int? year;

  /// Wie viel Höhe die Illustration bekommt (`height: '58%'`, `:481`).
  static const double illustrationHeightFactor = 0.58;

  /// Die Breite des Buchrückens am linken Rand (`width: 14`, `:504`).
  static const double spineWidth = 14;

  /// Die Höhe des Goldbands am Kopf (`height: 6`, `:510`).
  static const double topBandHeight = 6;

  /// Die Höhe der Goldlinie am Fuß (`height: 3`, `:604`).
  static const double bottomRuleHeight = 3;

  /// Die Deckkraft der Goldlinie am Fuß (`opacity: 0.6`, `:606`).
  static const double bottomRuleOpacity = 0.6;

  /// Wie weit der Textblock in die Illustration hineinragt
  /// (`marginTop: '-24px'`, `:519`).
  static const double textOverlap = 24;

  /// Der Innenabstand des Textblocks, `0 18px 28px 22px` (`:519`).
  static const EdgeInsets textPadding = EdgeInsets.fromLTRB(22, 0, 18, 28);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final Color dark = _color(volume.palette.colorDk);
    final Color mid = _color(volume.palette.color);
    final Color light = _color(volume.palette.colorLt);

    return Semantics(
      button: true,
      label: strings.text('wallet.openChapters'),
      child: GestureDetector(
        onTap: onOpenChapters,
        child: ColoredBox(
          key: coverKey,
          color: dark,
          child: Stack(
            children: <Widget>[
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _illustration(context, strings, dark, mid, light),
                    Transform.translate(
                      offset: const Offset(0, -textOverlap),
                      child: _textBlock(strings, light),
                    ),
                  ],
                ),
              ),
              _spine(dark, mid),
              _topBand(dark),
              _bottomRule(dark),
              _back(strings),
            ],
          ),
        ),
      ),
    );
  }

  /// Die obere Fläche: Silhouette, Verlauf darüber, Tipp-Hinweis.
  Widget _illustration(
    BuildContext context,
    AppStrings strings,
    Color dark,
    Color mid,
    Color light,
  ) => SizedBox(
    // `height: '58%'` bezieht sich in der Quelle auf die Höhe des
    // Bildschirms, nicht auf den Inhalt. Genommen wird deshalb die Höhe des
    // Kastens, in dem das Cover steht.
    height: MediaQuery.sizeOf(context).height * illustrationHeightFactor,
    child: ClipRect(
      child: Stack(
        children: <Widget>[
          LibraryCityIllustration(
            cityKey: volume.cityKey,
            dark: dark,
            mid: mid,
            light: light,
          ),
          // `linear-gradient(to bottom, transparent 25%, colorDk 100%)`
          // (`:485`): erst ab einem Viertel Höhe fängt der Verlauf an, das
          // obere Viertel bleibt unangetastet.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const <double>[0.25, 1],
                colors: <Color>[const Color(0x00000000), dark],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            bottom: 12,
            right: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x73000000),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '📖 ${strings.text('wallet.tapToOpen')}',
                  style: FactTypography.heading.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: const Color(0xE6FFFFFF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// Der Buchrücken am linken Rand (`:503-508`).
  Widget _spine(Color dark, Color mid) => Positioned(
    left: 0,
    top: 0,
    bottom: 0,
    width: spineWidth,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          // `colorDk 0%, colorDk 40%, color 100%`: die erste Zweifünftel
          // bleiben flach dunkel, danach hellt es auf.
          stops: const <double>[0, 0.4, 1],
          colors: <Color>[dark, dark, mid],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            offset: Offset(3, 0),
            blurRadius: 12,
          ),
        ],
      ),
      child: const SizedBox.expand(),
    ),
  );

  /// Das Goldband am Kopf (`:509-513`).
  Widget _topBand(Color dark) => Positioned(
    top: 0,
    left: 0,
    right: 0,
    height: topBandHeight,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const <double>[0, 0.2, 0.5, 0.8, 1],
          colors: <Color>[
            dark,
            const Color(0xFFF5C518),
            const Color(0xFFFFE066),
            const Color(0xFFF5C518),
            dark,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    ),
  );

  /// Die Goldlinie am Fuß (`:602-607`).
  ///
  /// Beginnt bei `left: 14`, also **hinter** dem Buchrücken: die Linie
  /// gehört zur Seite und nicht zum Rücken.
  Widget _bottomRule(Color dark) => Positioned(
    bottom: 0,
    left: spineWidth,
    right: 0,
    height: bottomRuleHeight,
    child: Opacity(
      opacity: bottomRuleOpacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const <double>[0, 0.3, 1],
            colors: <Color>[dark, const Color(0xFFF5C518), dark],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );

  /// Der Weg zurück ins Regal (`:512-518`).
  Widget _back(AppStrings strings) => Positioned(
    top: 14,
    left: 22,
    child: GestureDetector(
      key: backKey,
      onTap: onBack,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          '‹ ${strings.text('wallet.libraryKicker')}',
          style: FactTypography.heading.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
            color: const Color(0x99FFFFFF),
          ),
        ),
      ),
    ),
  );

  Widget _textBlock(AppStrings strings, Color light) => Padding(
    padding: textPadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _brandBadge(strings),
        const SizedBox(height: 8),
        _bandLine(strings, light),
        const SizedBox(height: 3),
        Text(
          volume.name,
          style: TextStyle(
            fontFamily: FactFont.display,
            fontWeight: FontWeight.w900,
            fontSize: 38,
            height: 0.9,
            letterSpacing: -0.5,
            color: const Color(0xFFFFFFFF),
            shadows: const <Shadow>[
              Shadow(
                color: Color(0x80000000),
                offset: Offset(0, 3),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${strings.text('wallet.coverSubtitle')} · '
                  '${year ?? DateTime.now().year}'
              .toUpperCase(),
          style: FactTypography.mono.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 8.5,
            letterSpacing: 1.5,
            color: light.withAlpha(0x77),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Container(
            width: 28,
            height: 1.5,
            color: light.withAlpha(0xCC),
          ),
        ),
        _stats(strings, light),
        const SizedBox(height: 14),
        _chaptersButton(strings),
      ],
    ),
  );

  /// Das rote Abzeichen (`:521-531`).
  ///
  /// Der Text `FACT Reiseführer` steht in der Quelle hartcodiert im JSX, ohne
  /// `t()`. Siehe `wallet.coverBrand`.
  Widget _brandBadge(AppStrings strings) => Container(
    padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
    decoration: BoxDecoration(
      color: const Color(0xE0E8380D),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0xCCFFFFFF),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          strings.text('wallet.coverBrand').toUpperCase(),
          style: FactTypography.heading.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 7.5,
            letterSpacing: 0.5,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ],
    ),
  );

  /// „Band 3 · Bayern · Oberpfalz" (`:532-537`).
  ///
  /// **Ohne Bandnummer bleibt die Zeile beim Gebiet**, und ohne beides ist sie
  /// leer. Die Quelle setzt hier `wltSimpleFormat(t('wallet.bandLabel'), { n:
  /// city.bandNo })`, und `bandNo` ist bei einer Stadt ohne Palette `0`: dort
  /// steht dann „Band 0 · " mit leerem Gebiet. Eine Bandnummer null gibt es
  /// nicht, siehe `LibraryVolume.bandNumber`.
  Widget _bandLine(AppStrings strings, Color light) {
    final int? number = volume.bandNumber;
    final String label = number == null
        ? volume.palette.region
        : <String>[
            strings.text(
              'wallet.bandLabel',
              params: <String, String>{'n': '$number'},
            ),
            if (volume.palette.region.isNotEmpty) volume.palette.region,
          ].join(' · ');

    return Text(
      label.toUpperCase(),
      style: FactTypography.mono.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 7.5,
        letterSpacing: 2.5,
        color: light.withAlpha(0x99),
      ),
    );
  }

  /// Die drei Kennzahlen (`:546-559`).
  Widget _stats(AppStrings strings, Color light) => Row(
    children: <Widget>[
      _stat(
        'stories',
        '${volume.collected}',
        strings.text('wallet.statStories'),
        light,
      ),
      const SizedBox(width: 16),
      _stat(
        'chapters',
        '$startedChapters',
        strings.text('wallet.statChapters'),
        light,
      ),
      const SizedBox(width: 16),
      _stat(
        'since',
        strings.text('wallet.statSincePlaceholder'),
        strings.text('wallet.statSince'),
        light,
      ),
    ],
  );

  Widget _stat(String name, String value, String label, Color light) => Column(
    key: statKey(name),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        value,
        style: FactTypography.heading.copyWith(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          height: 1,
          color: const Color(0xFFFFFFFF),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label.toUpperCase(),
        style: FactTypography.mono.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 6.5,
          letterSpacing: 0.5,
          color: light.withAlpha(0x66),
        ),
      ),
    ],
  );

  /// „Alle Kapitel ↓" (`:574-581`).
  Widget _chaptersButton(AppStrings strings) => GestureDetector(
    key: chaptersKey,
    onTap: onOpenChapters,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            strings.text('wallet.coverAllChapters'),
            style: FactTypography.heading.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              color: const Color(0xCCFFFFFF),
            ),
          ),
          Text(
            '↓',
            style: FactTypography.heading.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: const Color(0x80FFFFFF),
            ),
          ),
        ],
      ),
    ),
  );

  /// Wie in `library_book_spine.dart`: die Palette hält Hexzeichenketten, weil sie
  /// eine Abschrift der Quelle ist.
  static Color _color(String hex) =>
      Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
