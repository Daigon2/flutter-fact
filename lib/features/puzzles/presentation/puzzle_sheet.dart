import 'dart:math' as math;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:fact_app/features/puzzles/domain/entities/puzzle.dart';
import 'package:fact_app/features/puzzles/presentation/puzzle_type_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Rahmen des Rätsel-Sheets, `02_Frontend/app/puzzle-sheet.jsx:113-196`.
///
/// ## Dieses Widget hat keinen Einstieg, und das ist Absicht
///
/// Es gibt keine Route, keinen Provider und kein `showModalBottomSheet`, das
/// es öffnet. Der Grund ist nicht Unfertigkeit, sondern Eigentümerschaft: der
/// Öffner ist der Besitzer der **Rätsel-Sitzung**, und die entsteht erst in
/// Phase 5. In der Quelle hängt das Sheet an einer laufenden Schnitzeljagd
/// (`screen-map.jsx:3909`), es braucht also einen Stopp, einen Stationsindex,
/// einen Fortschritt und einen Ort, an den das Ergebnis zurückfließt. Wer hier
/// vorher einen Öffner verdrahtet, muss sich diese vier Dinge ausdenken.
/// Dieselbe Bauform wie die Fakt-Akte in Schritt 21.
///
/// `test/features/puzzles/presentation/puzzle_sheet_test.dart` bewacht das mit
/// einer Textsuche über `lib/`, und dort steht auch, was diese Suche **nicht**
/// kann.
///
/// ## Was hier bewusst fehlt
///
/// * **Der Rätselkörper** (`:198-199`, `PuzzleBody`). Die sechs Eingabemasken
///   und ihre Auswertung sind Schritt 28 und hängen an E-08. An seiner Stelle
///   steht nichts, nicht ein leerer Platzhalter: ein Feld, das nichts
///   annimmt, wäre gegenüber dem Nutzer eine Unwahrheit (E-33).
/// * **Tipp, Ergebniszeile und Überspringen** (`:201-238`). Schritt 29 bis 32,
///   blockiert an E-06 und E-08.
/// * **Der Reveal-Bildschirm** (`:100-111`). Schritt 30.
/// * **Wisch-nach-unten zum Schließen** (`:59-62`) und die Einblend-Animation
///   `factRevealSlideUp` (`:118`). Beide gehören dem Öffner: das eine ist eine
///   Geste auf dem Blatt, das andere sein Auftritt, und es gibt kein Blatt,
///   solange niemand es aufmacht.
///
/// ## Die vier Texte ohne Schlüssel in der PWA
///
/// Stationszeile (`:150`), Überschrift (`:165`), Aufgaben-Beschriftung
/// (`:194`) und Foto-Leiste (`:176`) zeigt die Quelle sichtbar an, ohne sie
/// als i18n-Schlüssel zu führen. Sie liegen als `puzzle.stationCounter`,
/// `puzzle.riddleCounter`, `puzzle.taskLabel` und `puzzle.photoCaption` in
/// `app/localization/app_strings_supplement.dart` (E-39); Wortlaut und
/// Namenswahl sind dort begründet, hier stehen nur die Aufrufe.
class PuzzleSheet extends ConsumerWidget {
  /// Erzeugt das Sheet zu [puzzle].
  const PuzzleSheet({
    required this.puzzle,
    required this.stopIndex,
    required this.onClose,
    super.key,
  });

  /// `paddingTop: 44` am Blatt, `:117`.
  ///
  /// Eine feste Zahl der Quelle und **keine** sichere Fläche: das Sheet liegt
  /// dort absolut über dem Kartenbildschirm, dessen Systemleiste schon
  /// abgezogen ist.
  static const double topPadding = 44;

  /// `margin: '8px 16px 0'` an der Marken-Blase, `:124`.
  static const EdgeInsets headerMargin = EdgeInsets.only(
    left: 16,
    top: 8,
    right: 16,
  );

  /// `borderRadius: 22` an der Marken-Blase, `:124`.
  static const double headerRadius = 22;

  /// `padding: '14px 16px'` an der Marken-Blase, `:126`.
  static const EdgeInsets headerPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  /// `gap: 12` in der Marken-Blase, `:129`.
  static const double headerGap = 12;

  /// `width/height: 32` am Schließknopf, `:144`.
  static const double closeButtonSize = 32;

  /// `padding: '20px 20px 100px'` am Inhalt, `:159`.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(20, 20, 20, 100);

  /// `margin: '0 0 16px'` an der Überschrift, `:164`.
  static const double headingBottomSpacing = 16;

  /// `marginBottom: 14` am Foto-Block, `:169`.
  static const double photoBottomSpacing = 14;

  /// `borderRadius: 12` am Foto-Block, `:169`.
  static const double photoRadius = 12;

  /// `padding: '6px 10px'` an der Foto-Leiste, `:173`.
  static const EdgeInsets photoCaptionPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  );

  /// `borderRadius: 14` an der Aufgaben-Karte, `:184`.
  static const double taskCardRadius = 14;

  /// `padding: '14px 16px'` an der Aufgaben-Karte, `:185`.
  static const EdgeInsets taskCardPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  /// `marginBottom: 20` an der Aufgaben-Karte, `:186`.
  static const double taskCardBottomSpacing = 20;

  /// `borderLeft: '3px solid var(--stamp)'` an der Aufgaben-Karte, `:183`.
  static const double taskCardAccentWidth = 3;

  /// `marginBottom: 6` unter der Aufgaben-Beschriftung, `:193`.
  static const double taskLabelBottomSpacing = 6;

  /// Der Kopf der Blase, für Maßtests.
  static const Key headerKey = Key('puzzle-sheet-header');

  /// Der Schließknopf `×`, `:140-147`.
  static const Key closeButtonKey = Key('puzzle-sheet-close');

  /// Die Stationszeile, `:149-151`.
  static const Key stationLineKey = Key('puzzle-sheet-station');

  /// Die Typbeschriftung, `:152-154`.
  static const Key typeLabelKey = Key('puzzle-sheet-type-label');

  /// Das Typsymbol, `:156`.
  static const Key typeIconKey = Key('puzzle-sheet-type-icon');

  /// Die scrollbare Fläche, `:159`.
  static const Key contentKey = Key('puzzle-sheet-content');

  /// Die Überschrift „Rätsel N", `:163-165`.
  static const Key headingKey = Key('puzzle-sheet-heading');

  /// Der Foto-Block, `:168-178`.
  static const Key photoKey = Key('puzzle-sheet-photo');

  /// Die Leiste unter dem Foto, `:172-176`.
  static const Key photoCaptionKey = Key('puzzle-sheet-photo-caption');

  /// Die Aufgaben-Karte, `:181-196`.
  static const Key taskCardKey = Key('puzzle-sheet-task-card');

  /// Die Beschriftung „AUFGABE", `:190-194`.
  static const Key taskLabelKey = Key('puzzle-sheet-task-label');

  /// Die Aufgabe selbst, `:195`.
  static const Key questionKey = Key('puzzle-sheet-question');

  /// `background: 'rgba(255,255,255,0.14)'` an den drei Zierkreisen, `:135`.
  static const Color decorCircleColor = Color.fromRGBO(255, 255, 255, 0.14);

  /// Die drei Zierkreise als `[links in Prozent, oben in Prozent, Größe]`,
  /// `:131`.
  ///
  /// Die beiden Prozentwerte zählen in CSS gegen die Fläche der Blase, die
  /// Größe ist absolut. Deshalb kann diese Tabelle nicht in `Positioned`
  /// wandern, ohne die Fläche zu kennen; sie wird unten in einem
  /// `LayoutBuilder` ausgewertet.
  static const List<(double left, double top, double size)> decorCircles =
      <(double, double, double)>[
        (0.88, 0.10, 32),
        (0.92, 0.60, 20),
        (0.78, 0.88, 12),
      ];

  /// `top: -30` am radialen Schimmer, `:138`.
  static const double glowTop = -30;

  /// `right: -20` am radialen Schimmer, `:138`.
  static const double glowRight = -20;

  /// `width/height: 110` am radialen Schimmer, `:138`.
  static const double glowSize = 110;

  /// `rgba(255,224,102,0.28)` im Schimmer, `:138`.
  ///
  /// Als Literal und nicht als Token, weil die Quelle es hier inline schreibt
  /// und nicht über `var()` holt. Dass der Ton zufällig `--gold-lt`
  /// (`FactColors.goldLight`) entspricht, ändert daran nichts: die Blase
  /// bliebe gelb, wenn ein Theme das Token verschöbe.
  static const Color glowColor = Color.fromRGBO(255, 224, 102, 0.28);

  /// `background: 'rgba(255,255,255,0.18)'` am Schließknopf, `:142`.
  static const Color closeButtonBackground = Color.fromRGBO(
    255,
    255,
    255,
    0.18,
  );

  /// `color: 'rgba(255,255,255,0.78)'` an der Stationszeile, `:149`.
  static const Color stationLineColor = Color.fromRGBO(255, 255, 255, 0.78);

  /// `textShadow: '0 2px 0 rgba(120,20,2,0.4)'` an der Typbeschriftung,
  /// `:152`.
  static const Shadow typeLabelShadow = Shadow(
    color: Color.fromRGBO(120, 20, 2, 0.4),
    offset: Offset(0, 2),
  );

  /// `boxShadow: '… inset 0 1px 0 rgba(255,255,255,0.12)'` an der Blase,
  /// `:127`.
  ///
  /// `BoxShadow` kann kein `inset`. Ein Inset-Schatten ohne Weichzeichner und
  /// ohne Streuung, um 1 Pixel nach unten versetzt, ist genau eine ein Pixel
  /// hohe Lichtkante am oberen Innenrand; sie wird als solche gezeichnet.
  /// Dieselbe Überlegung wie bei der Innenkante der Tutorial-Blase, nur
  /// versetzt statt umlaufend.
  static const Color headerInnerHighlight = Color.fromRGBO(255, 255, 255, 0.12);

  /// `background: card` der Aufgaben-Karte im dunklen Zustand,
  /// `rgba(255,255,255,0.05)`, `:77` und `:182`.
  static const Color taskCardDark = Color.fromRGBO(255, 255, 255, 0.05);

  /// Dasselbe im hellen Zustand, `rgba(0,0,0,0.04)`, `:77`.
  static const Color taskCardLight = Color.fromRGBO(0, 0, 0, 0.04);

  /// `boxShadow: '0 2px 6px rgba(0,0,0,0.04)'` der Aufgaben-Karte, **nur im
  /// hellen Zustand**, `:188`.
  static const BoxShadow taskCardLightShadow = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.04),
    offset: Offset(0, 2),
    blurRadius: 6,
  );

  /// `rgba(255,255,255,0.06)` hinter der Foto-Leiste im dunklen Zustand,
  /// `:174`.
  static const Color photoCaptionDark = Color.fromRGBO(255, 255, 255, 0.06);

  /// `rgba(0,0,0,0.05)` hinter der Foto-Leiste im hellen Zustand, `:174`.
  static const Color photoCaptionLight = Color.fromRGBO(0, 0, 0, 0.05);

  /// Das Rätsel in seiner typisierten Form.
  ///
  /// Kommt aus `puzzles/application/puzzle_from_fact_puzzle.dart`. Die
  /// Presentation kennt `FactPuzzle` bewusst nicht.
  final Puzzle puzzle;

  /// Der nullbasierte Index der Station, `stopIdx` in der Quelle.
  ///
  /// Station und Rätsel werden **beide** als `stopIdx + 1` angezeigt
  /// (`:150` und `:165`), es ist also eine Zahl und nicht zwei.
  final int stopIndex;

  /// Was der Schließknopf auslöst, `:140`.
  ///
  /// Absichtlich ein Rückruf und kein `context.pop()`: das Sheet ist keine
  /// Route, und wer es zeigt, entscheidet, was Schließen bedeutet.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // `background: bg` mit `bg = 'var(--surface)'`, `:74` und `:115`.
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.only(top: topPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(colors, strings),
            Expanded(child: _content(colors, strings, isDark: isDark)),
          ],
        ),
      ),
    );
  }

  /// Die Marken-Blase, `:123-157`.
  Widget _header(FactColors colors, AppStrings strings) {
    final ({String icon, String label}) meta = puzzleTypeMetaOf(
      puzzle.type,
      strings,
    );

    return Padding(
      padding: headerMargin,
      child: DecoratedBox(
        // Der äußere Schatten liegt außerhalb der Beschneidung, sonst wäre er
        // weg: `overflow: 'hidden'` in CSS beschneidet Kinder, keinen
        // Schlagschatten. `0 12px 28px var(--stamp-glow)`, `:127`. Der Radius
        // geht unverändert als `blurRadius` mit, wie überall hier, siehe
        // `app/shell/floating_tab_bar.dart`.
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(headerRadius)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.stampGlow,
              offset: const Offset(0, 12),
              blurRadius: 28,
            ),
          ],
        ),
        child: ClipRRect(
          key: headerKey,
          borderRadius: const BorderRadius.all(Radius.circular(headerRadius)),
          child: Stack(
            children: <Widget>[
              // Zuerst gezeichnet, also hinter dem Inhalt, und wie in der
              // Quelle außerhalb des Flusses: Verlauf, drei Zierkreise,
              // Schimmer und Lichtkante hängen dort an `position: absolute`
              // beziehungsweise am Elternelement selbst und verschieben
              // nichts. `Positioned.fill` bekommt die Fläche, die der Inhalt
              // unten festgelegt hat, deshalb sind die Prozentwerte der
              // Zierkreise hier auflösbar.
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) =>
                        _headerBackdrop(colors, c.biggest),
                  ),
                ),
              ),
              Padding(
                padding: headerPadding,
                child: Row(
                  children: <Widget>[
                    _closeButton(),
                    const SizedBox(width: headerGap),
                    Expanded(child: _headerTexts(meta.label, strings)),
                    const SizedBox(width: headerGap),
                    Text(
                      meta.icon,
                      key: typeIconKey,
                      // `fontSize: 28`, `:156`.
                      style: const TextStyle(fontSize: 28),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Verlauf, Zierkreise, Schimmer und Lichtkante der Blase, `:124-138`.
  Widget _headerBackdrop(FactColors colors, Size box) {
    // `linear-gradient(135deg, var(--stamp-deep) 0%, var(--stamp) 60%,
    // var(--primary-lt) 110%)`, `:125`.
    final ({Alignment begin, Alignment end}) ends = cssLinearGradientEnds(
      angleDegrees: 135,
      box: box,
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: ends.begin,
                end: ends.end,
                colors: <Color>[
                  colors.redDark,
                  colors.red,
                  // Der dritte Stop liegt in CSS bei **110 Prozent**, also
                  // außerhalb der Fläche; sichtbar ist nur, was bis 100
                  // Prozent kommt. Flutters `stops` sind auf 0..1 festgelegt,
                  // deshalb wird die Farbe am sichtbaren Ende ausgerechnet:
                  // (100 − 60) / (110 − 60) = 0,8 des Wegs von `--stamp` nach
                  // `--primary-lt`. Ein auf 1,0 gekürzter Stop ohne diese
                  // Rechnung wäre sichtbar zu hell.
                  Color.lerp(colors.red, colors.redLight, 0.8)!,
                ],
                stops: const <double>[0, 0.6, 1],
              ),
            ),
          ),
        ),
        for (final (double left, double top, double size) in decorCircles)
          Positioned(
            left: box.width * left,
            top: box.height * top,
            width: size,
            height: size,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: decorCircleColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        Positioned(
          top: glowTop,
          right: glowRight,
          width: glowSize,
          height: glowSize,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                // `radial-gradient(circle, …)` ohne Ausdehnungsangabe heißt in
                // CSS `farthest-corner`: der Radius reicht auf einer
                // quadratischen Fläche vom Mittelpunkt in die Ecke, also
                // `√2/2` der Kantenlänge. `RadialGradient.radius` zählt in
                // Anteilen der kürzeren Seite, hier sind beide gleich.
                radius: math.sqrt2 / 2,
                colors: <Color>[
                  glowColor,
                  // CSS `transparent` ist rgba(0,0,0,0), CSS interpoliert
                  // Verläufe aber vormultipliziert und Flutter nicht: gegen
                  // durchsichtiges Schwarz entstünde ein grauer Ring. Deshalb
                  // dieselbe Farbe mit Deckkraft 0.
                  Color.fromRGBO(255, 224, 102, 0),
                ],
                stops: <double>[0, 0.7],
              ),
            ),
          ),
        ),
        // `inset 0 1px 0 rgba(255,255,255,0.12)`, `:127`.
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 1,
          child: ColoredBox(color: headerInnerHighlight),
        ),
      ],
    );
  }

  /// Der Schließknopf, `:140-147`.
  Widget _closeButton() {
    return GestureDetector(
      key: closeButtonKey,
      onTap: onClose,
      child: Container(
        width: closeButtonSize,
        height: closeButtonSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: closeButtonBackground,
          shape: BoxShape.circle,
        ),
        // Das Zeichen ist `×` (U+00D7) wie in der Quelle und nicht der
        // Buchstabe x. `fontSize: 18`, `:143`, Farbe `#fff`, `:142`.
        child: const Text(
          '×',
          style: TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
        ),
      ),
    );
  }

  /// Stationszeile und Typbeschriftung, `:148-155`.
  Widget _headerTexts(String typeLabel, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          // `textTransform: 'uppercase'`, `:149`. Die Großschreibung steht in
          // der Quelle am Element und nicht im Text, deshalb hier und nicht
          // in der Ergänzungs-Map.
          strings
              .text(
                'puzzle.stationCounter',
                params: <String, String>{'station': '${stopIndex + 1}'},
              )
              .toUpperCase(),
          key: stationLineKey,
          style: FactTypography.mono.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: stationLineColor,
            // `letterSpacing: '0.22em'` bei 9 Pixeln, `:149`. Flutter zählt
            // absolut.
            letterSpacing: 9 * 0.22,
          ),
        ),
        // `marginTop: 2`, `:152`.
        const SizedBox(height: 2),
        Text(
          typeLabel,
          key: typeLabelKey,
          style: FactTypography.emphasis.copyWith(
            fontSize: 18,
            color: const Color(0xFFFFFFFF),
            // `lineHeight: 1.05`, `:152`. Von der Quelle ausdrücklich gesetzt
            // und deshalb nach E-40 zu übernehmen.
            height: 1.05,
            // `letterSpacing: '-0.015em'` bei 18 Pixeln, `:152`.
            letterSpacing: 18 * -0.015,
            shadows: const <Shadow>[typeLabelShadow],
          ),
        ),
      ],
    );
  }

  /// Der scrollbare Inhalt, `:159-196`.
  Widget _content(
    FactColors colors,
    AppStrings strings, {
    required bool isDark,
  }) {
    return SingleChildScrollView(
      key: contentKey,
      padding: contentPadding,
      child: Column(
        // `stretch` und nicht `start`: die Kinder sind in CSS Blockelemente
        // und füllen die Breite. Mit `start` wäre die Aufgaben-Karte nur so
        // breit wie ihr längster Absatz, und ihr roter Akzentstrich stünde
        // je nach Frage woanders.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            strings.text(
              'puzzle.riddleCounter',
              params: <String, String>{'number': '${stopIndex + 1}'},
            ),
            key: headingKey,
            style: FactTypography.emphasis.copyWith(
              fontSize: 22,
              color: colors.ink,
              // `lineHeight: 1.3`, `:164`, ausdrücklich gesetzt (E-40).
              height: 1.3,
              // `letterSpacing: '-0.01em'` bei 22 Pixeln, `:164`.
              letterSpacing: 22 * -0.01,
            ),
          ),
          const SizedBox(height: headingBottomSpacing),
          if (puzzle.photoUrl case final String url)
            _photo(url, colors, strings, isDark: isDark),
          _taskCard(colors, strings, isDark: isDark),
          // Hier stünde `PuzzleBody`, `:198-199`. Siehe den Kopf dieser Datei:
          // die sechs Eingabemasken sind Schritt 28 und hängen an E-08.
        ],
      ),
    );
  }

  /// Der Foto-Block, `:168-178`.
  Widget _photo(
    String url,
    FactColors colors,
    AppStrings strings, {
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: photoBottomSpacing),
      child: ClipRRect(
        key: photoKey,
        borderRadius: const BorderRadius.all(Radius.circular(photoRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // `width: '100%', height: 'auto'`, `:171`: die Breite kommt aus
            // dem Elternelement, die Höhe aus dem Seitenverhältnis.
            Image.network(
              url,
              width: double.infinity,
              // Wie in der Fakt-Akte: ohne diesen Zweig wirft `Image` im
              // Debug-Build bei jedem Ladefehler, und in `flutter test`
              // scheitert **jede** Netzanfrage. Die Quelle zeigt bei einem
              // kaputten Bild nur die Leiste darunter, also tut es das hier
              // auch.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            ColoredBox(
              color: isDark ? photoCaptionDark : photoCaptionLight,
              child: Padding(
                padding: photoCaptionPadding,
                child: Text(
                  strings.text('puzzle.photoCaption'),
                  key: photoCaptionKey,
                  style: FactTypography.mono.copyWith(
                    fontSize: 10,
                    // `color: inkSoft` mit `inkSoft = 'var(--ink-soft)'`,
                    // `:76` und `:175`. `--ink-soft` ist der Alias von
                    // `--ink-2`, siehe `FactColors.ink2`.
                    color: colors.ink2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Die Aufgaben-Karte, `:181-196`.
  Widget _taskCard(
    FactColors colors,
    AppStrings strings, {
    required bool isDark,
  }) {
    return Container(
      key: taskCardKey,
      margin: const EdgeInsets.only(bottom: taskCardBottomSpacing),
      decoration: BoxDecoration(
        color: isDark ? taskCardDark : taskCardLight,
        borderRadius: const BorderRadius.all(Radius.circular(taskCardRadius)),
        // `borderLeft: '3px solid var(--stamp)'`, `:183`. Nur links, deshalb
        // `Border(left: …)` und nicht `Border.all`.
        border: Border(
          left: BorderSide(color: colors.red, width: taskCardAccentWidth),
        ),
        boxShadow: isDark ? null : const <BoxShadow>[taskCardLightShadow],
      ),
      padding: taskCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // `textTransform: 'uppercase'`, `:192`.
            strings.text('puzzle.taskLabel').toUpperCase(),
            key: taskLabelKey,
            style: FactTypography.emphasis.copyWith(
              fontSize: 10,
              // `letterSpacing: 1.5`, `:192`. React hängt an eine Zahl bei
              // `letterSpacing` ein `px` an, der Wert ist also absolut und
              // wird nicht mit der Schriftgröße multipliziert.
              letterSpacing: 1.5,
              color: colors.red,
              // Die Karte setzt `lineHeight: 1.5` (`:187`), und die
              // Beschriftung erbt sie in CSS. Ausdrücklich gesetzter Wert der
              // Quelle, also nach E-40 zu übernehmen.
              height: 1.5,
            ),
          ),
          const SizedBox(height: taskLabelBottomSpacing),
          Text(
            puzzle.question,
            key: questionKey,
            // `fontSize: 16, lineHeight: 1.5` stehen an der Karte (`:187`)
            // und werden vom Textknoten geerbt. Die Farbe kommt aus
            // `color: ink` am Blatt (`:115`).
            style: FactTypography.bodyText.copyWith(
              fontSize: 16,
              height: 1.5,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
