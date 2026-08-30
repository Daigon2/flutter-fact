import 'dart:math' as math;

import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:flutter/material.dart';

/// Die Marken-Blase über dem Schnitzeljagd-Assistenten, `ChalBubble` in
/// `02_Frontend/app/screen-challenge.jsx:964-1041`.
///
/// ## Sie bleibt über allen Schritten stehen
///
/// Das ist der Grund, warum der Assistent keine eigene Route je Schritt hat:
/// `SnjdSetupView` rendert diese Blase einmal (`:1659-1666`) und tauscht
/// darunter den Inhalt. Ein Routenwechsel würde sie mit austauschen.
///
/// ## Der Zähler steht immer auf drei
///
/// `stepTotal = 3` ist fest, auch im Solo-Pfad, der nur zwei Schritte hat. Die
/// Quelle begründet das an Ort und Stelle (`:1631-1634`): vorher wechselte die
/// Gesamtzahl zwischen 2 und 3, und der Zähler sprang „1/3" → „2/2" → „3/3".
/// Solo benutzt jetzt die ersten beiden Positionen, die dritte bleibt grau.
///
/// ## Was von der Quelle fehlt
///
/// Der `kicker` (`:1001-1007`), die kleine Zeile über dem Titel. Der Assistent
/// setzt ihn nicht, damit ist in der Quelle auch `marginTop` des Titels 0
/// (`:1010`). Ein Parameter, den der einzige Aufrufer nie füllt, wäre hier
/// ungeprüfter Code.
class ChallengeBubble extends StatelessWidget {
  /// Erzeugt die Blase.
  const ChallengeBubble({
    required this.title,
    required this.subtitle,
    required this.step,
    this.totalSteps = defaultTotalSteps,
    this.onBack,
    super.key,
  });

  /// `totalSteps = 3`, `:964` und `:1634`.
  static const int defaultTotalSteps = 3;

  /// `margin: '8px 16px 0'`, `:967`.
  static const EdgeInsets margin = EdgeInsets.only(left: 16, top: 8, right: 16);

  /// `borderRadius: 22`, `:967`.
  static const double cornerRadius = 22;

  /// `padding: '16px 18px 18px'`, `:970`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 16, 18, 18);

  /// `0 12px 28px rgba(168,37,8,0.32)`, `:971`.
  ///
  /// Als Literal und **nicht** als [FactColors.stampGlow]: die Quelle schreibt
  /// hier eine feste Farbe statt `var(--stamp-glow)`, und das Token trägt
  /// einen anderen Ton (`rgba(232,56,13,…)`). Das Rätsel-Sheet nimmt an
  /// derselben Stelle das Token, weil es dort `var(--stamp-glow)` heißt.
  static const Color shadowColor = Color.fromRGBO(168, 37, 8, 0.32);

  /// `inset 0 1px 0 rgba(255,255,255,0.12)`, `:971`.
  ///
  /// `BoxShadow` kann kein `inset`; ohne Weichzeichner und um ein Pixel nach
  /// unten versetzt ist das genau eine ein Pixel hohe Lichtkante oben innen.
  static const Color innerHighlight = Color.fromRGBO(255, 255, 255, 0.12);

  /// Die drei Zierkreise als `[links, oben, Größe]`, `:974`.
  ///
  /// Die ersten beiden Werte sind Prozent der Blasenfläche, der dritte ist
  /// absolut. Deshalb werden sie unten in einem `LayoutBuilder` ausgewertet.
  static const List<(double left, double top, double size)> decorCircles =
      <(double, double, double)>[
        (0.88, 0.08, 36),
        (0.92, 0.60, 22),
        (0.78, 0.88, 14),
      ];

  /// `background: 'rgba(255,255,255,0.14)'` an den Zierkreisen, `:978`.
  static const Color decorCircleColor = Color.fromRGBO(255, 255, 255, 0.14);

  /// `top: -40`, `right: -30`, `width/height: 140` am Schimmer, `:982`.
  static const double glowTop = -40;

  /// Siehe [glowTop].
  static const double glowRight = -30;

  /// Siehe [glowTop].
  static const double glowSize = 140;

  /// `rgba(255,224,102,0.30)` im Schimmer, `:984`.
  static const Color glowColor = Color.fromRGBO(255, 224, 102, 0.30);

  /// `width/height: 30`, `borderRadius: 10` am Zurück-Knopf, `:991`.
  static const double backButtonSize = 30;

  /// Siehe [backButtonSize].
  static const double backButtonRadius = 10;

  /// `background: 'rgba(0,0,0,0.22)'` am Zurück-Knopf, `:992`.
  static const Color backButtonBackground = Color.fromRGBO(0, 0, 0, 0.22);

  /// `border: '1px solid rgba(255,255,255,0.20)'` am Zurück-Knopf, `:992`.
  static const Color backButtonBorder = Color.fromRGBO(255, 255, 255, 0.20);

  /// `textShadow: '0 2px 0 rgba(120,20,2,0.4)'` am Titel, `:1014`.
  static const Shadow titleShadow = Shadow(
    color: Color.fromRGBO(120, 20, 2, 0.4),
    offset: Offset(0, 2),
  );

  /// `color: 'rgba(255,255,255,0.7)'` am Zähler, `:1019`.
  static const Color counterColor = Color.fromRGBO(255, 255, 255, 0.7);

  /// `color: 'rgba(255,255,255,0.88)'` an der Unterzeile, `:1024`.
  static const Color subtitleColor = Color.fromRGBO(255, 255, 255, 0.88);

  /// `#FFE066` an einem erledigten Fortschrittsbalken, `:1033`.
  static const Color progressDoneColor = Color(0xFFFFE066);

  /// `rgba(255,255,255,0.25)` an einem offenen Balken, `:1033`.
  static const Color progressOpenColor = Color.fromRGBO(255, 255, 255, 0.25);

  /// `height: 3`, `gap: 5`, `marginTop: 14` an der Fortschrittszeile,
  /// `:1029-1032`.
  static const double progressHeight = 3;

  /// Siehe [progressHeight].
  static const double progressGap = 5;

  /// Siehe [progressHeight].
  static const double progressTopSpacing = 14;

  /// Der Zurück-Knopf, für Tests.
  static const Key backButtonKey = Key('challenge-bubble-back');

  /// Der Zähler „1/3", für Tests.
  static const Key counterKey = Key('challenge-bubble-counter');

  /// Die Fortschrittszeile, für Tests.
  static const Key progressKey = Key('challenge-bubble-progress');

  /// Der Titel, `:1011-1015`.
  final String title;

  /// Die Unterzeile, `:1023-1027`. Sie sagt, was der aktuelle Schritt fragt.
  final String subtitle;

  /// Der laufende Schritt, einsbasiert.
  final int step;

  /// Wie viele Positionen der Zähler zeigt.
  final int totalSteps;

  /// Was der Zurück-Knopf auslöst, oder `null`, wenn keiner gezeigt wird.
  ///
  /// Die Quelle steuert das mit `showBack={step > 1}` (`:1664`) und einem
  /// eigenen `onBack`. Ein Rückruf statt `context.pop()`: der Assistent ist
  /// **eine** Route, und Zurück setzt dort Felder zurück (`:1622-1625`), statt
  /// einen Bildschirm zu verlassen.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onBack = this.onBack;

    return Padding(
      padding: margin,
      child: DecoratedBox(
        // Der Schlagschatten liegt außerhalb der Beschneidung: `overflow:
        // hidden` in CSS beschneidet Kinder, keinen Schatten.
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadowColor,
              offset: Offset(0, 12),
              blurRadius: 28,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(cornerRadius)),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) =>
                            _backdrop(context, constraints.biggest),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (onBack != null) _backButton(onBack),
                    _titleRow(),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: FactTypography.bodyText.copyWith(
                          fontSize: 13,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                    _progress(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Verlauf, Zierkreise, Schimmer und Lichtkante, `:966-986`.
  Widget _backdrop(BuildContext context, Size box) {
    final FactColors colors = context.factColors;
    // `linear-gradient(135deg, var(--stamp-deep) 0%, var(--stamp) 60%,
    // var(--primary-lt) 110%)`, `:969`.
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
                  // Der dritte Stop liegt bei 110 Prozent, also außerhalb der
                  // Fläche. Flutters `stops` reichen nur bis 1, deshalb die
                  // Farbe am sichtbaren Ende: (100 − 60) / (110 − 60) = 0,8
                  // des Wegs. Ein auf 1,0 gekürzter Stop wäre zu hell.
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
                // `radial-gradient(circle, …)` ohne Ausdehnung heißt in CSS
                // `farthest-corner`, auf einer quadratischen Fläche also
                // `√2/2` der Kantenlänge.
                radius: math.sqrt2 / 2,
                colors: <Color>[
                  glowColor,
                  // CSS interpoliert vormultipliziert, Flutter nicht: gegen
                  // durchsichtiges Schwarz entstünde ein grauer Ring.
                  Color.fromRGBO(255, 224, 102, 0),
                ],
                stops: <double>[0, 0.7],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 1,
          child: const ColoredBox(color: innerHighlight),
        ),
      ],
    );
  }

  /// `:989-1000`.
  Widget _backButton(VoidCallback onBack) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        child: GestureDetector(
          key: backButtonKey,
          behavior: HitTestBehavior.opaque,
          onTap: onBack,
          child: Container(
            width: backButtonSize,
            height: backButtonSize,
            decoration: BoxDecoration(
              color: backButtonBackground,
              borderRadius: const BorderRadius.all(
                Radius.circular(backButtonRadius),
              ),
              border: Border.all(color: backButtonBorder),
            ),
            alignment: Alignment.center,
            // `<path d="M14 6l-6 6 6 6" />` in einem 24er-Feld auf 16 Pixel,
            // `:996-998`. Materials `chevron_left` zeichnet dieselbe Form.
            child: const Icon(
              Icons.chevron_left,
              size: 16,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    );
  }

  /// Titel und Zähler, `:1010-1022`.
  Widget _titleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Flexible(
          child: Text(
            title,
            style: FactTypography.displayTitle.copyWith(
              fontSize: 28,
              height: 1.05,
              letterSpacing: FactTypography.displayTracking(28),
              color: const Color(0xFFFFFFFF),
              shadows: const <Shadow>[titleShadow],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          key: counterKey,
          '$step/$totalSteps',
          style: FactTypography.mono.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: counterColor,
          ),
        ),
      ],
    );
  }

  /// `:1028-1038`.
  Widget _progress() {
    return Padding(
      key: progressKey,
      padding: const EdgeInsets.only(top: progressTopSpacing),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < totalSteps; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: progressGap),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: index < step ? progressDoneColor : progressOpenColor,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  // `boxShadow: '0 0 8px rgba(255,224,102,0.6)'`, nur am
                  // erledigten Balken, `:1034`.
                  boxShadow: index < step
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color.fromRGBO(255, 224, 102, 0.6),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: const SizedBox(height: progressHeight),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
