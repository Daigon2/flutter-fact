import 'dart:math' as math;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/identity/presentation/widgets/flag_mark.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Sprachauswahl und Audio-Knopf des Startbildschirms,
/// `screen-auth.jsx:331-372`.
///
/// ## Die Sprachtexte sind absichtlich nicht übersetzt
///
/// `screen-auth.jsx:334` sagt es wörtlich: "Subs intentionally not translated —
/// each language shows in its own tongue". Eine Karte zeigt ihre eigene Sprache,
/// unabhängig davon, welche gerade aktiv ist. Deshalb stehen `Deutsch`,
/// `Weiter auf Deutsch`, `English` und `Continue in English` hier als Literale.
/// Der Schlüssel `lang.continue` ist **nicht** dasselbe und ersetzt sie nicht.
class SplashLanguageRow extends StatelessWidget {
  /// Erzeugt die Zeile.
  const SplashLanguageRow({
    required this.strings,
    required this.activeLanguage,
    required this.onLanguageSelected,
    required this.onAudioGuidePressed,
    super.key,
  });

  /// Eckenradius von Karten und Audio-Knopf, `borderRadius: 16`.
  static const double cornerRadius = 16;

  /// Breite der Flaggen ab [compactBelowWidth], `<Flag size={30}/>`
  /// (`screen-auth.jsx:348`).
  static const double flagSize = 30;

  /// Breite der Flaggen unterhalb von [compactBelowWidth].
  ///
  /// **Die Quelle kennt diese Regel nicht.** Sie hat genau einen Umbruchpunkt,
  /// `@media (max-width: 500px)` (`styles.css:269`, dieselbe Zahl in
  /// `chrome.jsx:128`), und der schaltet den Telefonrahmen auf Vollbild, nicht
  /// die Flagge. Ihre Flaggen sind überall 30 breit; ihr zweiter Wert, die
  /// Vorgabe 28 der Komponenten (`screen-auth.jsx:179` und `:192`), wird von
  /// der Sprachauswahl nie benutzt. Schwelle und Größe sind hier deshalb
  /// **hergeleitet und nicht übernommen** (E-36, entschieden am 30.08.2026).
  ///
  /// Hergeleitet aus einer Messung mit echten Schriften, nicht gewählt: bei 360
  /// logischen Pixeln stehen der Zeile 316 Pixel zur Verfügung, gebraucht
  /// werden 2 × 125,348 für die Karten, 63,961 für den Knopf und 16 für die
  /// Abstände, zusammen 330,657. Der Fehlbetrag von 14,657 verteilt sich auf
  /// zwei Karten, jede Karte muss also um 7,33 Pixel schmaler werden, und weil
  /// die Flagge mit ihrer vollen Breite in die Mindestbreite der Karte eingeht,
  /// heißt das: höchstens 22,67 Pixel Flagge.
  ///
  /// **Warum trotzdem 20 und nicht 22.** Bei 22 geht die Rechnung mit 0,039
  /// Pixeln Rest auf, das ist kein Spielraum, sondern ein Zufall: eine neue
  /// Schriftfassung, ein anderes Wort oder ein Pixel mehr Innenabstand kippt
  /// die Titel wieder auf zwei Zeilen. Bei 20 bleiben 4,04 Pixel, und die
  /// Beschriftung des Kopfhörer-Knopfes fällt von drei Zeilen auf zwei. Beides
  /// gemessen, nicht gerechnet.
  static const double compactFlagSize = 20;

  /// Unterhalb dieser Gerätebreite gilt [compactFlagSize].
  ///
  /// 390 ist das Rahmenmaß der Quelle (`chrome.jsx:135`, `width: isMobile ?
  /// '100vw' : 390`) und damit die schmalste Breite, für die die Quelle
  /// überhaupt entworfen hat. Ab dort aufwärts bleibt alles, wie es war; nur
  /// schmaler, als je entworfen wurde, gibt die Flagge nach.
  ///
  /// Die Schwelle liegt auf der **Gerätebreite** und nicht auf der Breite
  /// dieser Zeile. Der Grund ist kein Geschmack: ein `LayoutBuilder` ist hier
  /// nicht benutzbar, weil der Startbildschirm seine Inhaltsspalte in ein
  /// `IntrinsicHeight` legt. Siehe die Begründung an [_FieldRow].
  static const double compactBelowWidth = 390;

  /// Die Flaggenbreite für eine Gerätebreite von [width] logischen Pixeln.
  static double flagSizeFor(double width) =>
      width < compactBelowWidth ? compactFlagSize : flagSize;

  /// Abstand zwischen Flagge und Textspalte einer Karte, `gap: 10`.
  static const double cardContentSpacing = 10;

  /// Abstand zwischen den drei Feldern, `gap: 8` am Flex-Container.
  static const double fieldSpacing = 8;

  /// Rahmenstärke aller drei Felder, `1.5px solid`.
  static const double fieldBorderWidth = 1.5;

  /// Innenabstand aller drei Felder, `padding: '11px 14px'`.
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 11,
  );

  /// Schriftgröße des Kopfhörer-Emojis, `fontSize: 28`.
  static const double audioEmojiSize = 28;

  /// Texte der aktiven Sprache, für den Audio-Knopf.
  final AppStrings strings;

  /// Welche Karte hervorgehoben ist.
  final AppLanguage activeLanguage;

  /// Wird beim Tippen auf eine Sprachkarte gerufen.
  final ValueChanged<AppLanguage> onLanguageSelected;

  /// Wird beim Tippen auf den Kopfhörer-Knopf gerufen.
  final VoidCallback onAudioGuidePressed;

  @override
  Widget build(BuildContext context) {
    // Kein `Row` mit `Expanded` und kein `IntrinsicHeight`: die Verteilung der
    // Breite und die gleiche Höhe der drei Felder macht [_FieldRow] selbst.
    // Warum, steht dort.
    final flagWidth = flagSizeFor(MediaQuery.sizeOf(context).width);
    return _FieldRow(
      spacing: fieldSpacing,
      children: <Widget>[
        _languageCard(
          language: AppLanguage.de,
          kind: FlagKind.de,
          label: 'Deutsch',
          subtitle: 'Weiter auf Deutsch',
          flagWidth: flagWidth,
        ),
        _languageCard(
          language: AppLanguage.en,
          kind: FlagKind.gb,
          label: 'English',
          subtitle: 'Continue in English',
          flagWidth: flagWidth,
        ),
        _audioGuideButton(),
      ],
    );
  }

  Widget _languageCard({
    required AppLanguage language,
    required FlagKind kind,
    required String label,
    required String subtitle,
    required double flagWidth,
  }) {
    final selected = language == activeLanguage;
    return SplashPressable(
      onPressed: () => onLanguageSelected(language),
      // Der Auswahlzustand ist in der Quelle nur farbig. Siehe
      // [SplashPressable.selected].
      selected: selected,
      child: Container(
        padding: fieldPadding,
        decoration: BoxDecoration(
          color: selected
              ? const Color.fromRGBO(232, 56, 13, 0.18)
              : const Color.fromRGBO(255, 255, 255, 0.06),
          borderRadius: const BorderRadius.all(Radius.circular(cornerRadius)),
          border: Border.fromBorderSide(
            BorderSide(
              color: selected
                  ? const Color.fromRGBO(232, 56, 13, 0.55)
                  : const Color.fromRGBO(255, 255, 255, 0.12),
              width: fieldBorderWidth,
            ),
          ),
          // `boxShadow: '0 0 0 3px rgba(232,56,13,0.12)'`: kein Versatz, keine
          // Unschärfe, nur Ausbreitung. Das ist ein Ring, kein Schatten.
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color.fromRGBO(232, 56, 13, 0.12),
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: cardContentSpacing,
          children: <Widget>[
            FlagMark(kind: kind, size: flagWidth),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: FactTypography.heading.copyWith(
                      fontSize: 14,
                      height: 1,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 11,
                      color: const Color.fromRGBO(255, 255, 255, 0.45),
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

  /// Der Kopfhörer-Knopf.
  ///
  /// Die Quelle gibt ihm keine Breite (`screen-auth.jsx:356-370`, kein `flex`),
  /// er bemisst sich also an seinem Inhalt. Hier gilt dasselbe, mit einer
  /// Einschränkung: er tritt zurück, wenn die beiden Sprachkarten den Platz für
  /// ihren Titel brauchen. Die Rechnung dazu steht in [_FieldRow].
  Widget _audioGuideButton() {
    final label = strings.text('audio.splash.button');
    return SplashPressable(
      onPressed: onAudioGuidePressed,
      // `aria-label` der Quelle ist derselbe Schlüssel wie die Beschriftung.
      semanticLabel: label,
      child: Container(
        padding: fieldPadding,
        decoration: const BoxDecoration(
          color: Color.fromRGBO(255, 255, 255, 0.06),
          borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
          border: Border.fromBorderSide(
            BorderSide(
              color: Color.fromRGBO(255, 255, 255, 0.12),
              width: fieldBorderWidth,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 4,
          children: <Widget>[
            // `fontSize: 28`, ohne feste Zeilenhöhe: die Quelle setzt keine,
            // und eine gekappte Zeile schneidet dem Emoji die Oberkante ab.
            const Text('🎧', style: TextStyle(fontSize: audioEmojiSize)),
            _TwoLineFloor(
              child: Text(
                label,
                // Mittig, damit eine umgebrochene Beschriftung unter dem Emoji
                // sitzt statt links wegzulaufen. Bei einer Zeile ist das nicht
                // zu sehen.
                textAlign: TextAlign.center,
                style: FactTypography.bodyText.copyWith(
                  fontSize: 11,
                  color: const Color.fromRGBO(255, 255, 255, 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die drei Felder der Sprachzeile: nebeneinander, gleich hoch, mit [spacing]
/// dazwischen.
///
/// Erwartet genau drei Kinder in dieser Reihenfolge: Sprachkarte, Sprachkarte,
/// Kopfhörer-Knopf.
///
/// ## Warum das kein `Row` mit `Expanded` ist
///
/// In der Quelle sind die beiden Karten `flex: 1`, der Knopf hat keine
/// Breitenangabe. `flex: 1` heißt in CSS `flex-basis: 0%`, und daraus folgt
/// zweierlei, das ein `Row` nicht abbilden kann:
///
///  1. Die Karten dürfen **nicht unter ihre min-content-Breite** schrumpfen.
///     Das ist `min-width: auto`, die automatische Mindestbreite eines
///     Flex-Kindes: Rahmen, Innenabstand, Flagge, Abstand und das längste
///     unteilbare Wort der Textspalte. Bei der deutschen Karte ist das der
///     Titel `Deutsch`.
///  2. Beim Schrumpfen gibt der **Knopf** nach, nicht die Karten: die
///     gewichtete Schrumpfrate eines Kindes mit `flex-basis: 0%` ist null.
///
/// `Row` verteilt die Breite, **bevor** es die Kinder nach ihrem Bedarf fragt.
/// Mit `Expanded` bekommt jede Karte genau ein Drittel, und was nicht
/// hineinpasst, bricht um. Genau das war der Defekt, am Emulator gesehen und
/// mit echten Schriften nachgerechnet: bei 411 logischen Pixeln (Pixel 8)
/// blieben der Textspalte 54,7 Pixel, `Deutsch` braucht 56,1, und der Titel
/// stand als "Deutsc / h" auf zwei Zeilen. Bei 390, dem Rahmenmaß der Quelle,
/// waren es 44,2 Pixel; dort brachen beide Titel um.
///
/// **Ein `LayoutBuilder` ist kein Ausweg.** Der Startbildschirm legt seine
/// Inhaltsspalte in ein `IntrinsicHeight` (`splash_page.dart`), und
/// `LayoutBuilder` kann keine intrinsischen Maße liefern: "LayoutBuilder does
/// not support returning intrinsic dimensions." Ein eigenes Layout kann es,
/// weil es die intrinsischen Breiten seiner Kinder erfragt, statt Widgets
/// während des Layouts zu bauen.
///
/// ## Die Verteilung
///
/// Gerechnet wird mit den intrinsischen Breiten der Kinder, nicht mit
/// Konstanten. Damit hängt die Zeile nicht an Schriftschnitt, Sprache oder
/// Textgrößen-Einstellung:
///
/// ```
/// frei  = Breite - 2 * spacing
/// Karte = min-content der breiteren Karte, auf ganze Pixel aufgerundet
/// Knopf = frei - 2 * Karte, begrenzt auf [Untergrenze, Inhaltsbreite]
/// Karte = (frei - Knopf) / 2
/// ```
///
/// Die Untergrenze des Knopfes ist seine eigene min-content-Breite. Sie fällt
/// klein aus, weil [_TwoLineFloor] der Beschriftung eine zweite Zeile erlaubt;
/// als harte Grenze bleibt das Emoji. Gemessen mit echten Schriften:
/// Inhaltsbreite 99,7 Pixel, Untergrenze 65,3.
///
/// Ergebnis bei Systemschriftgröße 1.0: bei 411 und bei 390 logischen Pixeln
/// bekommen die Karten ihre 128 Pixel, die Titel stehen einzeilig, und der
/// Knopf nimmt 95 beziehungsweise 74 Pixel und bricht seine Beschriftung um.
/// Die Quelle bricht sie dort ebenfalls um; bei 390 reicht es selbst ihr nicht,
/// dort schneidet `#root { overflow: hidden }` den Knopf um vier Pixel ab.
///
/// **Bei 360 logischen Pixeln ging es mit der Flagge der Quelle in keiner
/// Aufteilung auf:** zwei Karten à 125,348, ein Knopf mit 63,961 und 16 Pixel
/// Abstand sind 330,657, verfügbar sind 316. Die Karten schrumpften dann unter
/// ihre Mindestbreite, und beide Titel brachen um. Was nachgeben soll, war eine
/// Gestaltungsfrage und keine Layout-Frage, und sie ist seit dem 30.08.2026
/// entschieden (E-36): unterhalb von [SplashLanguageRow.compactBelowWidth] wird
/// die Flagge kleiner. Die Verteilung unten ist davon unberührt, sie rechnet
/// weiter mit den intrinsischen Breiten ihrer Kinder; die Flagge ist eine davon.
/// Gemessen bei 360 nach der Änderung: Karten 116, Knopf 68, beide Titel
/// einzeilig.
///
/// Bei Systemschriftgröße 2.0 gilt dasselbe auf jedem Format: die Untergrenze
/// des Knopfes bindet, die Karten bekommen den Rest, die Texte brechen um.
/// Überlaufen darf dabei nichts, das ist per Test zugesichert.
class _FieldRow extends MultiChildRenderObjectWidget {
  const _FieldRow({required this.spacing, required super.children});

  /// Abstand zwischen zwei Feldern.
  final double spacing;

  @override
  _RenderFieldRow createRenderObject(BuildContext context) =>
      _RenderFieldRow(spacing: spacing);

  @override
  void updateRenderObject(BuildContext context, _RenderFieldRow renderObject) {
    renderObject.spacing = spacing;
  }
}

/// Position eines Feldes in [_RenderFieldRow].
class _FieldParentData extends ContainerBoxParentData<RenderBox> {}

/// Das Layout hinter [_FieldRow].
class _RenderFieldRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FieldParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FieldParentData> {
  _RenderFieldRow({required double spacing}) : _spacing = spacing;

  static const double _unbounded = double.infinity;

  double _spacing;

  /// Abstand zwischen zwei Feldern.
  double get spacing => _spacing;

  set spacing(double value) {
    if (value == _spacing) {
      return;
    }
    _spacing = value;
    markNeedsLayout();
  }

  RenderBox get _firstCard => firstChild!;

  RenderBox get _secondCard => childAfter(_firstCard)!;

  RenderBox get _audioButton => childAfter(_secondCard)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FieldParentData) {
      child.parentData = _FieldParentData();
    }
  }

  /// Die min-content-Breite der breiteren Sprachkarte.
  ///
  /// Aufgerundet: die Rechnung im Kind zieht Rahmen, Innenabstand, Flagge und
  /// Abstand von dieser Zahl wieder ab, und eine Abweichung im letzten Bit
  /// würde den Titel umbrechen lassen. Der Aufschlag ist kleiner als ein
  /// logisches Pixel und verändert keine Maßangabe der Quelle.
  double get _cardFloor => math
      .max(
        _firstCard.getMinIntrinsicWidth(_unbounded),
        _secondCard.getMinIntrinsicWidth(_unbounded),
      )
      .ceilToDouble();

  /// Die Breite, die die breitere Karte hätte, wenn niemand sie beschränkt.
  double get _cardContent => math.max(
    _firstCard.getMaxIntrinsicWidth(_unbounded),
    _secondCard.getMaxIntrinsicWidth(_unbounded),
  );

  /// Die Breiten der drei Felder für eine gegebene Gesamtbreite.
  ///
  /// Siehe die Rechnung im Klassenkommentar von [_FieldRow].
  ({double card, double button}) _distribute(double availableWidth) {
    final buttonContent = _audioButton.getMaxIntrinsicWidth(_unbounded);
    if (!availableWidth.isFinite) {
      // Ohne Obergrenze gibt es nichts zu verteilen. Dieser Fall entsteht in
      // intrinsischen Abfragen, nicht im Layout des Startbildschirms.
      return (card: _cardContent, button: buttonContent);
    }
    final buttonFloor = math.min(
      _audioButton.getMinIntrinsicWidth(_unbounded),
      buttonContent,
    );
    final free = availableWidth - 2 * spacing;
    final button = math.min(
      math.max(free - 2 * _cardFloor, buttonFloor),
      buttonContent,
    );
    return (card: math.max((free - button) / 2, 0), button: button);
  }

  /// Die drei Felder mit ihrer Breite, in Zeichenreihenfolge.
  List<(RenderBox, double)> _fields(({double card, double button}) widths) {
    return <(RenderBox, double)>[
      (_firstCard, widths.card),
      (_secondCard, widths.card),
      (_audioButton, widths.button),
    ];
  }

  double _totalWidth(({double card, double button}) widths) =>
      2 * widths.card + widths.button + 2 * spacing;

  @override
  double computeMinIntrinsicWidth(double height) =>
      2 * _cardFloor +
      _audioButton.getMinIntrinsicWidth(_unbounded) +
      2 * spacing;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      2 * _cardContent +
      _audioButton.getMaxIntrinsicWidth(_unbounded) +
      2 * spacing;

  // Alle drei Felder sind Textblöcke: ihre Höhe steht mit ihrer Breite fest,
  // und damit fallen kleinste und größte Höhe zusammen.
  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    var height = 0.0;
    for (final (field, fieldWidth) in _fields(_distribute(width))) {
      height = math.max(height, field.getMaxIntrinsicHeight(fieldWidth));
    }
    return height;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final widths = _distribute(constraints.maxWidth);
    var height = 0.0;
    for (final (field, fieldWidth) in _fields(widths)) {
      final size = field.getDryLayout(
        BoxConstraints(minWidth: fieldWidth, maxWidth: fieldWidth),
      );
      height = math.max(height, size.height);
    }
    return constraints.constrain(Size(_totalWidth(widths), height));
  }

  @override
  void performLayout() {
    assert(
      childCount == 3,
      '_FieldRow erwartet Sprachkarte, Sprachkarte und Kopfhörer-Knopf, '
      'bekommen hat es $childCount Kinder.',
    );
    final widths = _distribute(constraints.maxWidth);
    final fields = _fields(widths);

    // Erster Durchgang: endgültige Breite, Höhe frei. Erst danach ist bekannt,
    // welches der drei Felder das höchste ist.
    var height = 0.0;
    for (final (field, fieldWidth) in fields) {
      field.layout(
        BoxConstraints(minWidth: fieldWidth, maxWidth: fieldWidth),
        parentUsesSize: true,
      );
      height = math.max(height, field.size.height);
    }
    height = constraints.constrainHeight(height);

    // Zweiter Durchgang: alle Felder auf diese Höhe, das ist
    // `align-items: stretch` des Flex-Containers. Ohne ihn wäre der Rahmen des
    // kürzeren Feldes niedriger als der des höchsten.
    //
    // Bewusst ein echtes zweites Layout und nicht die intrinsische Höhe der
    // Kinder: die intrinsische Höhe eines `Row` schätzt die Breitenverteilung
    // seiner Flex-Kinder, und eine Schätzung, die zu niedrig ausfällt, würde
    // Text abschneiden.
    var x = 0.0;
    for (final (field, fieldWidth) in fields) {
      field.layout(
        BoxConstraints.tightFor(width: fieldWidth, height: height),
        parentUsesSize: true,
      );
      (field.parentData! as _FieldParentData).offset = Offset(x, 0);
      x += fieldWidth + spacing;
    }
    size = constraints.constrain(Size(_totalWidth(widths), height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// Erlaubt dem Kind, bis auf die Hälfte seiner Inhaltsbreite zu schrumpfen.
///
/// Gemeint ist die Beschriftung des Kopfhörer-Knopfes, und gemeint ist damit
/// eine zweite Zeile. Ohne das wäre die min-content-Breite des Knopfes seine
/// Beschriftung in **einer** Zeile: Flutter meldet für `Audio-Guide` als
/// kleinste intrinsische Breite die ganze Zeichenkette, weil es dafür nur an
/// Leerzeichen trennt. Der Knopf könnte dann nie zurücktreten, und die Karten
/// hätten weiterhin zu wenig Platz für ihren Titel.
///
/// Umbrechen **kann** Flutter dort, gemessen: bei Systemschriftgröße 2.0 und
/// einer Obergrenze von 84 Pixeln stehen `Audio-` und `Guide` auf zwei Zeilen.
/// Nur die intrinsische Auskunft kennt diese Trennstelle nicht. Deshalb steht
/// die Hälfte hier als Regel: zwei Zeilen ja, eine dritte nicht, denn dafür
/// müsste Flutter innerhalb eines Wortes trennen, und das tut die Quelle nie.
class _TwoLineFloor extends SingleChildRenderObjectWidget {
  const _TwoLineFloor({required Widget super.child});

  @override
  _RenderTwoLineFloor createRenderObject(BuildContext context) =>
      _RenderTwoLineFloor();
}

/// Das Layout hinter [_TwoLineFloor].
class _RenderTwoLineFloor extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) {
      return 0;
    }
    return child.getMaxIntrinsicWidth(height) / 2;
  }
}
