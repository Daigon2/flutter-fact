/// Die Buchseite, `02_Frontend/app/screen-wallet.jsx:1413-1824`
/// (`WltBookPageView`). Der vierte und letzte Zustand des Reiseführers,
/// zweite Hälfte von Schritt 47.
///
/// ## Drei Wege zu blättern, und alle drei sind derselbe Aufruf
///
/// Die Quelle nimmt Wischen (`:1532-1540`), Tippen auf das linke oder rechte
/// Seitendrittel (`:1543-1549`) und die Knöpfe in der Fußleiste. Alle drei
/// rufen `onOpenFact(nachbar.id, ctx)` und ändern nichts am Zustand: eine
/// Buchseite kennt ihre Nachbarn, und Blättern heißt, den Nachbarn zu öffnen.
///
/// Die Tastaturbedienung (`:1438-1447`, Pfeiltasten und `Escape`) fehlt hier
/// und ist die einzige der vier, die nichts hinzufügt: die Quelle läuft im
/// Browser, diese App auf einem Telefon.
///
/// ## Was fehlt, und aus welchem Grund jeweils
///
/// **Die Frage-Leiste an Claude** (`:1685-1755`). Sie schickt den Fakt und
/// eine Frage an die Anthropic-Schnittstelle, führt ein Kontingent von zehn
/// Fragen und braucht einen Schlüssel. Laufende Kosten, ein Geheimnis und
/// ausgehende Nutzerdaten sind zusammen genau die Art Entscheidung, die
/// `docs/ai/escalation.md` dem Eigentümer vorbehält. Der mitgelieferte
/// Schlüssel der PWA ist außerdem seit dem 03.09.2026 deaktiviert. Aufgenommen
/// als offene Entscheidung.
///
/// **Der Link „Mehr erfahren"** (`:1671-1679`). Zum Öffnen bräuchte es
/// `url_launcher`, und ein neues Paket ist eine Entscheidung, die dieser
/// Schritt nicht trifft. Genau dieselbe Lage und dieselbe Antwort wie bei der
/// Quellenliste der Akte, deren Kopf sie begründet: ein Ding, das wie ein Link
/// aussieht und keiner ist, wäre die schlechtere Hälfte davon.
///
/// **Die Wiedergabeliste beim Vorlesen** (`:1551-1559`). Die Quelle legt die
/// ganze Blätterfolge in den Abspieler, liest also über die Seite hinaus
/// weiter. `SpeechService` kennt keine Liste, sondern einen Text
/// (Schritt 25). Der Knopf liest deshalb **diese** Seite vor und blättert
/// nicht weiter. Das ist weniger, aber nichts Falsches, und der Knopf tut
/// etwas.
///
/// **Die Leseposition** (`:1420-1435`, `Storage.setLastRead`). Sie hängt an
/// einem Leseverlauf mit Zeitstempeln, und den gibt es nicht: „gesammelt ist
/// gelesen" (E-80). Dieselbe Begründung wie bei der Weiterlesen-Pille in
/// `collection_page.dart`.
///
/// ## Eine Abweichung, die man sieht: die Reiterleiste bleibt stehen
///
/// Die Quelle blendet ihre Leiste im Lesemodus aus
/// (`{view !== 'reader' && <TabBar …>}`, `:1919`), weil derselbe Baustein
/// beides hält. Hier trägt die `StatefulShellRoute` die Leiste, und eine Seite
/// darin kann sie nicht verstecken; dafür wäre eine achte Route außerhalb der
/// Shell nötig, und E-25 hat die öffentliche Routenfläche auf sieben Pfade
/// festgelegt.
///
/// Genommen ist der Zustand, den die Akte schon hat: `/map/fact/:factId` ist
/// ebenfalls ein Kind der Shell und zeigt die Leiste. Zwei Vollbild-Lesearten
/// mit verschiedenem Rahmen wären der schlechtere Zustand. Aufgenommen als
/// offene Entscheidung, weil es sichtbar ist.
///
/// ## Die Initiale schwimmt nicht
///
/// `float: left` (`:1648`) lässt die ersten zwei Zeilen um den großen
/// Buchstaben herumlaufen. Flutters Textsatz kennt kein Umfließen; es gäbe es
/// nur mit einem eigenen `RenderObject`. Die Initiale steht hier deshalb
/// **in** der ersten Zeile, in ihrer Größe und ihrer Farbe. Die erste Zeile
/// wird dadurch hoch, der Rest läuft normal weiter.
library;

import 'dart:math' as math;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/features/collection/application/library_categories.dart';
import 'package:fact_app/features/collection/application/library_reader.dart';
import 'package:fact_app/features/collection/application/library_shelf.dart';
import 'package:fact_app/features/collection/presentation/library_chapter_look.dart';
import 'package:fact_app/features/collection/presentation/library_reader_look.dart';
import 'package:fact_app/features/collection/presentation/widgets/library_reader_footer.dart';
import 'package:fact_app/features/facts/application/fact_speech_providers.dart';
import 'package:fact_app/features/facts/domain/fact_prose.dart';
import 'package:fact_app/features/facts/domain/spoken_fact_text.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Lesemodus: ein Fakt als Seite eines Buchs.
class LibraryReaderView extends ConsumerWidget {
  /// Erzeugt die Buchseite für [page].
  const LibraryReaderView({
    required this.volume,
    required this.page,
    required this.onOpenFact,
    this.onBack,
    super.key,
  });

  /// Die Kennung der Bildlaufliste, für Tests.
  static const Key scrollKey = Key('library-reader-scroll');

  /// Die Kennung des Zurück-Wegs, für Tests.
  static const Key backKey = Key('library-reader-back');

  /// Die Kennung des Vorlese-Knopfs, für Tests.
  static const Key listenKey = Key('library-reader-listen');

  /// Die Kennung der Kategorie-Pille, für Tests.
  static const Key categoryKey = Key('library-reader-category');

  /// Die Kennung des Titels, für Tests.
  static const Key titleKey = Key('library-reader-title');

  /// Die Kennung des ersten Absatzes samt Initiale, für Tests.
  static const Key bodyKey = Key('library-reader-body');

  /// Die Kennung eines der drei hinteren Absätze, für Tests.
  static Key paragraphKey(int index) => Key('library-reader-paragraph-$index');

  /// Der Band, in dem geblättert wird. Liefert Name und Farben.
  final LibraryVolume volume;

  /// Die offene Seite mit ihren Nachbarn.
  final LibraryReaderPage page;

  /// Zurück zur Kapitelliste (`closeReader`, `:1854-1857`).
  final VoidCallback? onBack;

  /// Einen Nachbarn öffnen. Bekommt dessen Kennung.
  final void Function(FactId factId) onOpenFact;

  /// Die Deckkraft der Fläche der Kategorie-Pille, `${city.color}1F`
  /// (`:1637`).
  static const int categoryFillAlpha = 0x1F;

  /// Die Deckkraft des Rands der Kategorie-Pille, `${city.color}55`
  /// (`:1638`).
  static const int categoryBorderAlpha = 0x55;

  /// Die Deckkraft des ersten Titelschattens, `${city.color}2E` (`:1639`).
  static const int titleShadowAlpha = 0x2E;

  /// Die Deckkraft des zweiten Titelschattens, `${tok.bookInk}14` (`:1639`).
  static const int titleShadowAlpha2 = 0x14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final LibraryReaderPalette palette = LibraryReaderPalette.of(
      Theme.of(context).brightness,
    );
    final Color cityColor = _color(volume.palette.color);
    final Color cityDark = _color(volume.palette.colorDk);
    final FactText content = page.fact.contentFor(
      language.code,
      fallbackLanguageCode: AppLanguage.fallback.code,
    );

    return ColoredBox(
      color: palette.page,
      child: _PageGestures(
        onPrevious: page.hasPrevious
            ? () => onOpenFact(page.previous!.id)
            : null,
        onNext: page.hasNext ? () => onOpenFact(page.next!.id) : null,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: SingleChildScrollView(
                      key: scrollKey,
                      padding: libraryReaderPagePadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _header(
                            context: context,
                            ref: ref,
                            strings: strings,
                            language: language,
                            cityColor: cityColor,
                            cityDark: cityDark,
                            content: content,
                          ),
                          const SizedBox(height: libraryReaderHeaderGap),
                          _title(content, cityColor, cityDark, palette),
                          const SizedBox(height: libraryReaderTitleGap),
                          ..._paragraphs(content, cityColor, palette),
                        ],
                      ),
                    ),
                  ),
                ),
                LibraryReaderFooter(
                  page: page,
                  palette: palette,
                  cityColor: cityColor,
                  onPrevious: page.hasPrevious
                      ? () => onOpenFact(page.previous!.id)
                      : null,
                  onNext: page.hasNext ? () => onOpenFact(page.next!.id) : null,
                ),
              ],
            ),
            _Spine(color: cityColor, dark: cityDark),
            const _PageCurl(),
          ],
        ),
      ),
    );
  }

  /// Die Kopfreihe: zurück, vorlesen, Kategorie (`:1595-1633`).
  Widget _header({
    required BuildContext context,
    required WidgetRef ref,
    required AppStrings strings,
    required AppLanguage language,
    required Color cityColor,
    required Color cityDark,
    required FactText content,
  }) {
    final LibraryChapterLook look = libraryChapterLookOf(
      libraryCategoryKeyOf(page.fact.canonicalCategory),
    );

    return Row(
      children: <Widget>[
        _BackPill(
          label: strings.text('common.back'),
          semanticsLabel: strings.text('wallet.backToOverview'),
          onTap: onBack,
        ),
        const Spacer(),
        _ListenButton(
          label: strings.text('wallet.listen'),
          onTap: () => _speak(ref, language, content),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: DecoratedBox(
            key: categoryKey,
            decoration: BoxDecoration(
              color: cityColor.withAlpha(categoryFillAlpha),
              border: Border.all(
                color: cityColor.withAlpha(categoryBorderAlpha),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                '${look.glyph} '
                '${strings.text(libraryChapterNameKey(look.key)).toUpperCase()}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: FactFont.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  height: 1,
                  color: cityDark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Der Titel mit dem Comic-Schatten und der leichten Drehung (`:1635-1642`).
  Widget _title(
    FactText content,
    Color cityColor,
    Color cityDark,
    LibraryReaderPalette palette,
  ) => Transform.rotate(
    angle: libraryReaderTitleTiltDegrees * math.pi / 180,
    child: Text(
      content.title ?? '',
      key: titleKey,
      style: TextStyle(
        fontFamily: FactFont.display,
        fontWeight: FontWeight.w900,
        fontSize: libraryReaderTitleSize,
        height: 1.15,
        letterSpacing: -0.3,
        color: cityDark,
        shadows: <Shadow>[
          Shadow(
            color: cityColor.withAlpha(titleShadowAlpha),
            offset: const Offset(3, 3),
          ),
          Shadow(
            color: palette.ink.withAlpha(titleShadowAlpha2),
            offset: const Offset(5, 5),
          ),
        ],
      ),
    ),
  );

  /// Die vier Textblöcke in ihrer Nummerierung (`:1644-1668`).
  ///
  /// Der erste trägt die Initiale, der zweite hängt an [isRealProse], der
  /// dritte ist kursiv und leicht durchsichtig, der vierte bekommt einen
  /// Balken in der Stadtfarbe.
  ///
  /// **Die Quelle prüft nur `text2` auf Fließtext** (`:1653`) und die beiden
  /// dahinter bloß auf Vorhandensein (`:1658`, `:1663`). Das ist hier
  /// übernommen, obwohl die Akte alle drei prüft: der Anlass des Filters war
  /// `text2` mit einem Emotion-Tag darin, und für `text3` und `text4` ist
  /// derselbe Fall nicht gemessen. Eine Prüfung, die nichts filtert, wäre eine
  /// Behauptung über Daten, die niemand nachgesehen hat.
  List<Widget> _paragraphs(
    FactText content,
    Color cityColor,
    LibraryReaderPalette palette,
  ) {
    final String body = factTextWithoutReferences(content.body);
    final List<Widget> widgets = <Widget>[];

    if (body.isNotEmpty) {
      widgets.add(_dropCapBody(body, cityColor, palette));
    }

    if (isRealProse(content.bodyExtra)) {
      widgets.add(
        _paragraph(
          index: 2,
          text: factTextWithoutReferences(content.bodyExtra),
          palette: palette,
          fontSize: libraryReaderBodySize,
        ),
      );
    }

    final String background = factTextWithoutReferences(content.bodyBackground);
    if (background.isNotEmpty) {
      widgets.add(
        _paragraph(
          index: 3,
          text: background,
          palette: palette,
          fontSize: libraryReaderBodySmallSize,
          italic: true,
          opacity: libraryReaderBackgroundOpacity,
        ),
      );
    }

    final String today = factTextWithoutReferences(content.bodyToday);
    if (today.isNotEmpty) {
      widgets.add(
        _paragraph(
          index: 4,
          text: today,
          palette: palette,
          fontSize: libraryReaderBodySmallSize,
          quoteColor: cityColor,
        ),
      );
    }

    return widgets;
  }

  /// Der erste Absatz mit der Initiale (`:1645-1652`).
  Widget _dropCapBody(
    String body,
    Color cityColor,
    LibraryReaderPalette palette,
  ) {
    // `charAt(0)` und `slice(1)` der Quelle (`:1526-1527`). Auf Zeichen und
    // nicht auf Code-Einheiten: ein Titel, der mit einem Emoji anfängt, würde
    // sonst in zwei halbe Zeichen zerfallen.
    final Iterable<String> characters = body.split('');
    final String initial = characters.first;
    final String rest = body.substring(initial.length);

    return Text.rich(
      key: bodyKey,
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: initial,
            style: TextStyle(
              fontFamily: FactFont.display,
              fontWeight: FontWeight.w900,
              fontSize: libraryReaderDropCapSize,
              height: libraryReaderDropCapHeight,
              color: cityColor,
            ),
          ),
          TextSpan(text: rest),
        ],
      ),
      textAlign: TextAlign.justify,
      style: FactTypography.bodyText.copyWith(
        fontSize: libraryReaderBodySize,
        height: libraryReaderBodyHeight,
        color: palette.ink2,
      ),
    );
  }

  /// Einer der drei hinteren Absätze (`:1654-1668`).
  Widget _paragraph({
    required int index,
    required String text,
    required LibraryReaderPalette palette,
    required double fontSize,
    bool italic = false,
    double opacity = 1,
    Color? quoteColor,
  }) {
    final Widget content = Text(
      text,
      textAlign: TextAlign.justify,
      style: FactTypography.bodyText.copyWith(
        fontSize: fontSize,
        height: libraryReaderBodyHeight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        // Der vierte Absatz nimmt `bookInk` statt `bookInk2` (`:1665`): er ist
        // der Zitatblock und soll kräftiger stehen als der Fließtext.
        color: quoteColor == null ? palette.ink2 : palette.ink,
      ),
    );

    return Padding(
      key: paragraphKey(index),
      padding: const EdgeInsets.only(top: libraryReaderParagraphGap),
      child: Opacity(
        opacity: opacity,
        child: quoteColor == null
            ? content
            : DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: quoteColor,
                      width: libraryReaderQuoteBarWidth,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: libraryReaderQuoteGap),
                  child: content,
                ),
              ),
      ),
    );
  }

  /// Schickt die Vorlesefassung dieser Seite an den Sprachdienst.
  ///
  /// Derselbe Weg wie in `fact_page.dart`, damit es eine Vorlesefassung gibt
  /// und nicht zwei: der Text kommt aus `spokenFactText`, also ohne die
  /// Zitat-Hochziffern.
  void _speak(WidgetRef ref, AppLanguage language, FactText content) {
    reportDetached(
      ref
          .read(factSpeechProvider.notifier)
          .speak(
            factId: page.fact.id,
            text: spokenFactText(content),
            languageTag: speechLanguageTagFor(language.code),
          ),
      origin: 'collection.reader.speak',
    );
  }

  static Color _color(String hex) =>
      Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// Wischen und Tippen auf die Seitendrittel (`:1532-1549`).
///
/// ## Warum das Tippen nicht prüfen muss, was darunter liegt
///
/// Die Quelle fängt Treffer auf Knöpfe selbst ab
/// (`if (e.target.closest('[role="button"], button, a')) return`, `:1544`),
/// weil ein `onClick` am Elternelement sonst mitfeuert. Flutters
/// Gesten-Arena entscheidet das andersherum: der innerste Erkenner gewinnt,
/// ein Tipp auf den Zurück-Knopf erreicht diesen Erkenner also nie.
class _PageGestures extends StatefulWidget {
  const _PageGestures({
    required this.child,
    required this.onPrevious,
    required this.onNext,
  });

  final Widget child;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<_PageGestures> createState() => _PageGesturesState();
}

class _PageGesturesState extends State<_PageGestures> {
  /// Die zurückgelegte waagerechte Strecke der laufenden Geste.
  ///
  /// Aufsummiert, weil `DragEndDetails` nur die Geschwindigkeit trägt und
  /// nicht die Strecke. Die Quelle entscheidet über die **Strecke**
  /// (`clientX` beim Loslassen minus `clientX` beim Auflegen, `:1534-1537`),
  /// und das ist nicht dasselbe: ein langsamer Zug über die halbe Seite hat
  /// kaum Geschwindigkeit und ist trotzdem ein Blättern.
  double _dragDx = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragStart: (_) => _dragDx = 0,
    onHorizontalDragUpdate: (DragUpdateDetails d) => _dragDx += d.delta.dx,
    onHorizontalDragEnd: _onDragEnd,
    onTapUp: _onTapUp,
    child: widget.child,
  );

  /// `dx < 0 && next` blättert vorwärts, `dx > 0 && prev` zurück (`:1538`).
  ///
  /// Die Quelle prüft zusätzlich `Math.abs(dy) > Math.abs(dx)` und verwirft
  /// dann (`:1537`). Das braucht es hier nicht: `onHorizontalDragEnd` bekommt
  /// die Geste erst, wenn die Arena sie als waagerecht entschieden hat, und
  /// eine senkrechte gewinnt die Bildlaufliste.
  void _onDragEnd(DragEndDetails details) {
    final double dx = _dragDx;
    _dragDx = 0;
    if (dx.abs() < libraryReaderSwipeThreshold) {
      return;
    }
    if (dx < 0) {
      widget.onNext?.call();
    } else {
      widget.onPrevious?.call();
    }
  }

  void _onTapUp(TapUpDetails details) {
    final Size? size = context.size;
    if (size == null || size.width <= 0) {
      return;
    }
    final double relative = details.localPosition.dx / size.width;
    if (relative < libraryReaderTapZoneStart) {
      widget.onPrevious?.call();
    } else if (relative > libraryReaderTapZoneEnd) {
      widget.onNext?.call();
    }
  }
}

/// Der Buchrücken am linken Seitenrand (`:1575-1580`).
class _Spine extends StatelessWidget {
  const _Spine({required this.color, required this.dark});

  final Color color;
  final Color dark;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    bottom: 0,
    width: libraryReaderSpineWidth,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[dark, color, dark],
            stops: libraryReaderSpineStops,
          ),
        ),
      ),
    ),
  );
}

/// Der Schatten am rechten Seitenrand, der die gewölbte Seite andeutet
/// (`:1581-1586`).
class _PageCurl extends StatelessWidget {
  const _PageCurl();

  @override
  Widget build(BuildContext context) => Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    width: libraryReaderCurlWidth,
    child: const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: libraryReaderCurlColors,
            stops: libraryReaderCurlStops,
          ),
        ),
      ),
    ),
  );
}

/// Der Zurück-Knopf in der Kopfreihe (`:1596-1614`).
class _BackPill extends StatelessWidget {
  const _BackPill({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    excludeSemantics: true,
    child: GestureDetector(
      key: LibraryReaderView.backKey,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: libraryReaderBrandDark),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[libraryReaderBrandLight, libraryReaderBrand],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                '‹',
                style: TextStyle(
                  fontFamily: FactFont.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: FactFont.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Der Kopfhörer-Knopf (`:1616-1630`).
class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.label, required this.onTap});

  /// Die Fläche des Knopfs, `rgba(232,56,13,0.10)` (`:1622`).
  ///
  /// `0.10 * 255 = 25,5 → 26 = 0x1A`.
  static const Color fill = Color(0x1AE8380D);

  /// Der Rand, `rgba(232,56,13,0.32)` (`:1622`).
  ///
  /// `0.32 * 255 = 81,6 → 82 = 0x52`.
  static const Color border = Color(0x52E8380D);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      key: LibraryReaderView.listenKey,
      onTap: onTap,
      child: Container(
        width: libraryReaderListenSize,
        height: libraryReaderListenSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.fromBorderSide(BorderSide(color: border)),
        ),
        child: const Text('🎧', style: TextStyle(fontSize: 15, height: 1)),
      ),
    ),
  );
}
