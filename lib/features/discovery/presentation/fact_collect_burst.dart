/// Der Münzflug beim Sammeln, `CollectAnimOverlay` in
/// `02_Frontend/app/screen-map.jsx:1157-1199`, mit den Keyframes aus
/// `styles.css:325-339`.
///
/// ## Was gezeigt wird
///
/// Zehn Münzen fliegen aus der Bildschirmlage des angetippten Ballons
/// auseinander, jede um 40 Millisekunden nach der vorigen, und darüber steigt
/// die Zahl der Gutschrift auf. Die Fläche nimmt **keine** Berührungen an
/// (`pointerEvents:'none'`, `:1183`): sie liegt über der ganzen Karte, und ein
/// Fingertipp während der 1,25 Sekunden gehört weiter der Karte.
///
/// ## Die Zahl ist ein Pflichtparameter, und das ist eine Entscheidung
///
/// Die Quelle schreibt `+12 🪙` fest hin (`:1196`). **Diese 12 stimmt mit
/// keiner Buchung überein**, und zwar mit keiner der drei, die es gibt
/// (gemessen am 02.09.2026, Belege an [FactCollectBurst.coinAmount]). Ein
/// Versprechen, das die Gutschrift nicht einhält, ist ein Defekt der Quelle
/// und keine Vorlage, siehe `CLAUDE.md`, „The PWA is a reference, not a gold
/// standard". [FactCollectBurst.coinAmount] ist deshalb **erforderlich**: eine
/// Voreinstellung wäre genau die stille Zahl, die hier gerade das Problem ist.
///
/// ## Warum die Keyframes hier nachgerechnet werden und nicht implizit sind
///
/// CSS wendet die Zeitfunktion **zwischen je zwei Keyframes** an, nicht über
/// die ganze Dauer. `coinFloatUp` hat vier Stützstellen (0, 15, 80, 100
/// Prozent), und eine einzelne `CurvedAnimation` über 1,1 Sekunden träfe
/// keine davon. [factCollectLabelFrameAt] rechnet deshalb Abschnitt für
/// Abschnitt, und weil es eine reine Funktion ist, sind die vier Stützstellen
/// ohne Widget prüfbar.
///
/// ## Der Zufall in der Fluglänge braucht eine einspeisbare Quelle
///
/// `d = 32 + Math.random() * 22` (`:1176`). Ohne einspeisbaren Zufall wäre ein
/// Test entweder blind (er prüft die Länge gar nicht) oder flatterhaft (er
/// prüft sie gegen einen Zufallswert). Dasselbe Muster wie die eingespeiste
/// Uhr in `MapCameraHost` und wie `nextDouble` in
/// `challenges/application/hunt_route_generator.dart`.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Die zehn Winkel in Grad, **in dieser Reihenfolge**, `screen-map.jsx:1161`.
///
/// Die Reihenfolge ist Teil der Aussage und keine Sortierfrage: sie bestimmt
/// zusammen mit [factCollectBurstStagger], welche Münze wann losfliegt. Wer
/// sie aufsteigend sortiert, ändert das Bild.
const List<double> factCollectBurstAngles = <double>[
  200,
  225,
  250,
  270,
  290,
  310,
  330,
  170,
  190,
  155,
];

/// Versatz je Münze, `${i * 40}ms` in `:1172`.
const Duration factCollectBurstStagger = Duration(milliseconds: 40);

/// Flugdauer einer Münze, `0.7s` in `:1172`.
const Duration factCollectBurstCoinDuration = Duration(milliseconds: 700);

/// Dauer der aufsteigenden Zahl, `1.1s` in `:1196`.
const Duration factCollectBurstLabelDuration = Duration(milliseconds: 1100);

/// Verzögerung der aufsteigenden Zahl, `0.15s` in `:1196`.
const Duration factCollectBurstLabelDelay = Duration(milliseconds: 150);

/// `cubic-bezier(0.25,0.8,0.25,1)`, `:1172` und `:1196`.
const Cubic factCollectBurstCurve = Cubic(0.25, 0.8, 0.25, 1);

/// Kürzeste Fluglänge in logischen Pixeln, `32 + Math.random() * 22`, `:1176`.
const double factCollectBurstMinDistance = 32;

/// Wie weit die Fluglänge darüber hinaus streut, dieselbe Zeile.
///
/// **Ausschließend**: `Math.random()` liefert `[0, 1)`, die Länge liegt also
/// in `[32, 54)` und erreicht 54 nie.
const double factCollectBurstDistanceSpread = 22;

/// Der Betrag, um den jede Münze zusätzlich nach unten versetzt wird,
/// `Math.sin(rad) * d + 20`, `:1179`.
///
/// **Nachgemessen, weil die naheliegende Annahme falsch ist.** Die zehn
/// Winkel liegen zwischen 155 und 330 Grad, und in CSS wächst y nach **unten**;
/// `sin` ist dort nur zwischen 180 und 330 Grad negativ. Bei der kürzesten
/// Fluglänge von 32 Pixeln landet deshalb ein Teil des Schwarms **unter** dem
/// Ballon: 155 Grad um 33 Pixel, 170 Grad um 26, 190 Grad um 14, 200 Grad um
/// 9 und 330 Grad um 4. Nach oben gehen bei dieser Länge nur 225 bis 310 Grad.
///
/// **Und das bleibt so, auch über die ganze Streuung.** Bei der längsten
/// Fluglänge von knapp 54 Pixeln dreht nur 330 Grad nach oben; 155, 170, 190
/// und 200 Grad bleiben unten, weil `sin(200°)` mit -0,342 selbst über die
/// volle Strecke nicht gegen die 20 ankommt. Vier von zehn Münzen fliegen
/// damit **in jeder Ziehung** nach unten weg.
///
/// Der Schwarm fächert also nicht gleichmäßig nach oben auf, sondern nach
/// links und rechts oben, mit vier Münzen, die nach unten wegkippen. Genauso
/// sieht die PWA aus, und die Zahl bleibt.
const double factCollectBurstDownwardOffset = 20;

/// Schriftgröße einer Münze, `font-size:14px`, `:1170`.
const double factCollectBurstCoinFontSize = 14;

/// Das Münzzeichen, `el.textContent = '🪙'`, `:1165`.
const String factCollectBurstCoinGlyph = '🪙';

/// Schriftgröße der Zahl, `fontSize:15`, `:1191`.
const double factCollectBurstLabelFontSize = 15;

/// Farbe der Zahl, `color:'#F5C518'`, `:1192`.
const Color factCollectBurstLabelColor = Color(0xFFF5C518);

/// Schlagschatten der Zahl, `textShadow:'0 2px 8px rgba(0,0,0,0.9)'`, `:1193`.
const Shadow factCollectBurstLabelShadow = Shadow(
  color: Color(0xE6000000),
  offset: Offset(0, 2),
  blurRadius: 8,
);

/// Wie lange die ganze Überlagerung etwas zeigt.
///
/// Das Maximum beider Läufe: die Zahl endet nach 150 + 1100 = 1250
/// Millisekunden, die letzte Münze nach 9 × 40 + 700 = 1060. **Nicht zu
/// verwechseln mit den 1400 Millisekunden, nach denen der Ablauf die
/// Überlagerung entfernt** (`:3076`): die 150 Millisekunden Rest sind in der
/// Quelle eine ruhige Pause vor dem Fakt-Blatt, und sie bleiben eine.
final Duration factCollectBurstDuration = () {
  final Duration lastCoin =
      factCollectBurstStagger * (factCollectBurstAngles.length - 1) +
      factCollectBurstCoinDuration;
  final Duration label =
      factCollectBurstLabelDelay + factCollectBurstLabelDuration;
  return lastCoin > label ? lastCoin : label;
}();

/// Die zehn Fluglängen, gezogen aus [nextDouble].
///
/// Eine Liste und nicht ein Zug je Bild: die Quelle zieht sie **einmal** beim
/// Anlegen der Elemente (`:1176` läuft im `useEffect`), nicht in jedem Bild.
/// Zöge man je Bild neu, zappelten die Münzen.
List<double> factCollectBurstDistances(
  double Function() nextDouble,
) => <double>[
  for (int i = 0; i < factCollectBurstAngles.length; i++)
    factCollectBurstMinDistance + nextDouble() * factCollectBurstDistanceSpread,
];

/// Wohin eine Münze fliegt, `:1177-1179`.
///
/// `ex = cos(rad) * d`, `ey = sin(rad) * d + 20`. Der Winkel kommt in Grad
/// herein, wie in der Quelle, und wird hier umgerechnet.
Offset factCollectBurstTarget({
  required double angleInDegrees,
  required double distance,
}) {
  final double radians = angleInDegrees * math.pi / 180;
  return Offset(
    math.cos(radians) * distance,
    math.sin(radians) * distance + factCollectBurstDownwardOffset,
  );
}

/// Der Stand einer Münze zum Zeitpunkt [elapsed], Münze [index].
///
/// `coinBurstParticle` hat nur zwei Stützstellen (`styles.css:325-328`), die
/// Kurve läuft also über die ganzen 0,7 Sekunden.
///
/// **Vor ihrem Versatz ist die Münze unsichtbar**, und das steht nicht in den
/// Keyframes: das Element trägt `opacity:0` als Inline-Stil (`:1169`), und
/// eine Animation ohne `backwards`-Füllung wirkt vor ihrem Start nicht. Ohne
/// diese Zeile blitzten alle zehn Münzen im ersten Bild gemeinsam auf.
FactCollectCoinFrame factCollectCoinFrameAt({
  required int index,
  required Duration elapsed,
}) {
  final Duration delay = factCollectBurstStagger * index;
  if (elapsed < delay) {
    return const FactCollectCoinFrame(
      progress: 0,
      opacity: 0,
      scale: 1,
      rotationInDegrees: 0,
    );
  }
  final double raw =
      ((elapsed - delay).inMicroseconds /
              factCollectBurstCoinDuration.inMicroseconds)
          .clamp(0.0, 1.0);
  final double t = factCollectBurstCurve.transform(raw);
  return FactCollectCoinFrame(
    progress: t,
    // `0%: opacity 1` bis `100%: opacity 0`.
    opacity: 1 - t,
    // `scale(1)` bis `scale(0.5)`.
    scale: 1 - 0.5 * t,
    // `rotate(0deg)` bis `rotate(540deg)`.
    rotationInDegrees: 540 * t,
  );
}

/// Der Stand einer Münze: ein Wert je Eigenschaft, die sich bewegt.
final class FactCollectCoinFrame {
  /// Erzeugt den Stand.
  const FactCollectCoinFrame({
    required this.progress,
    required this.opacity,
    required this.scale,
    required this.rotationInDegrees,
  });

  /// Wie weit die Münze auf ihrem Weg ist, 0 am Ballon und 1 am Ziel.
  ///
  /// **Schon durch die Zeitfunktion gelaufen**, also nicht die verstrichene
  /// Zeit. Der Aufrufer multipliziert damit den Zielversatz.
  final double progress;

  /// Deckkraft, 1 am Anfang und 0 am Ende.
  final double opacity;

  /// Maßstab, 1 am Anfang und 0,5 am Ende.
  final double scale;

  /// Drehung in Grad, 0 am Anfang und 540 am Ende.
  final double rotationInDegrees;
}

/// Der Stand der aufsteigenden Zahl zum Zeitpunkt [elapsed].
///
/// `coinFloatUp`, `styles.css:334-339`, vier Stützstellen:
///
/// | Zeit | Deckkraft | Verschiebung | Maßstab |
/// |---|---|---|---|
/// | 0 % | 0 | `translate(-50%, -50%)` | 0,8 |
/// | 15 % | 1 | `translate(-50%, -70%)` | 1 |
/// | 80 % | 1 | `translate(55px, -195%)` | 1 |
/// | 100 % | 0 | `translate(60px, -210%)` | 1 |
///
/// ## Die x-Achse wechselt mitten im Lauf ihre Einheit
///
/// Bis 15 Prozent steht dort `-50%`, also die halbe **Elementbreite** nach
/// links, danach `55px` und `60px`, also ein absoluter Betrag nach rechts. Die
/// beiden Werte kommen aus `var(--coin-float-x, 55px)` und
/// `var(--coin-float-x, 60px)`, und **`--coin-float-x` setzt an diesem
/// Element niemand**: `CollectAnimOverlay` gibt die Variable nicht mit
/// (`screen-map.jsx:1186-1197`), es greifen also die Ausfallwerte. Die Zahl
/// wandert damit nicht nur nach oben, sondern auch nach rechts aus der Mitte
/// heraus. Das sieht wie ein Versehen aus und ist trotzdem, was die PWA zeigt;
/// es ist reine Optik ohne Aussage, deshalb wird es übernommen und nicht
/// begradigt.
///
/// **Vor [factCollectBurstLabelDelay] ist die Zahl unsichtbar**, aus
/// demselben Grund wie bei den Münzen: `opacity:0` steht als Inline-Stil
/// (`:1197`).
FactCollectLabelFrame factCollectLabelFrameAt(Duration elapsed) {
  if (elapsed < factCollectBurstLabelDelay) {
    return const FactCollectLabelFrame(
      xInPixels: 0,
      xFraction: -0.5,
      yFraction: -0.5,
      scale: 0.8,
      opacity: 0,
    );
  }
  final double raw =
      ((elapsed - factCollectBurstLabelDelay).inMicroseconds /
              factCollectBurstLabelDuration.inMicroseconds)
          .clamp(0.0, 1.0);

  const List<double> stops = <double>[0, 0.15, 0.80, 1];
  const List<FactCollectLabelFrame> frames = <FactCollectLabelFrame>[
    FactCollectLabelFrame(
      xInPixels: 0,
      xFraction: -0.5,
      yFraction: -0.5,
      scale: 0.8,
      opacity: 0,
    ),
    FactCollectLabelFrame(
      xInPixels: 0,
      xFraction: -0.5,
      yFraction: -0.7,
      scale: 1,
      opacity: 1,
    ),
    FactCollectLabelFrame(
      xInPixels: 55,
      xFraction: 0,
      yFraction: -1.95,
      scale: 1,
      opacity: 1,
    ),
    FactCollectLabelFrame(
      xInPixels: 60,
      xFraction: 0,
      yFraction: -2.10,
      scale: 1,
      opacity: 0,
    ),
  ];

  for (int i = 0; i < stops.length - 1; i++) {
    if (raw > stops[i + 1] && i + 1 < stops.length - 1) {
      continue;
    }
    // **Die Zeitfunktion läuft je Abschnitt**, nicht über den ganzen Lauf.
    // Das ist das Verhalten von CSS bei mehreren Keyframes und der Grund,
    // warum diese Funktion überhaupt existiert.
    final double local = factCollectBurstCurve.transform(
      ((raw - stops[i]) / (stops[i + 1] - stops[i])).clamp(0.0, 1.0),
    );
    return frames[i].lerpTo(frames[i + 1], local);
  }
  return frames.last;
}

/// Der Stand der aufsteigenden Zahl.
final class FactCollectLabelFrame {
  /// Erzeugt den Stand.
  const FactCollectLabelFrame({
    required this.xInPixels,
    required this.xFraction,
    required this.yFraction,
    required this.scale,
    required this.opacity,
  });

  /// Verschiebung nach rechts in logischen Pixeln, siehe
  /// [factCollectLabelFrameAt].
  final double xInPixels;

  /// Verschiebung als Anteil der eigenen Breite.
  final double xFraction;

  /// Verschiebung als Anteil der eigenen Höhe, negativ heißt nach oben.
  final double yFraction;

  /// Maßstab.
  final double scale;

  /// Deckkraft.
  final double opacity;

  /// Zwischenwert auf dem Weg zu [other], [t] von 0 bis 1.
  FactCollectLabelFrame lerpTo(FactCollectLabelFrame other, double t) =>
      FactCollectLabelFrame(
        xInPixels: xInPixels + (other.xInPixels - xInPixels) * t,
        xFraction: xFraction + (other.xFraction - xFraction) * t,
        yFraction: yFraction + (other.yFraction - yFraction) * t,
        scale: scale + (other.scale - scale) * t,
        opacity: opacity + (other.opacity - opacity) * t,
      );
}

/// Der Münzflug über der Karte, siehe den Bibliothekskopf.
class FactCollectBurst extends StatefulWidget {
  /// Erzeugt den Münzflug an der Bildschirmlage [origin].
  const FactCollectBurst({
    required this.origin,
    required this.coinAmount,
    this.nextDouble,
    super.key,
  });

  /// Wo der angetippte Ballon auf dem Bildschirm liegt, in logischen Pixeln.
  ///
  /// Die Quelle rechnet sie mit `mapInst.project(...)` in einem `try/catch`
  /// und nimmt bei einem Fehler `0/0` (`screen-map.jsx:3058-3067`). Der
  /// Rückfall bleibt beim Aufrufer: dieses Widget bekommt eine Lage und fragt
  /// nicht, woher sie kommt.
  final Offset origin;

  /// Die Zahl, die über dem Ballon aufsteigt.
  ///
  /// **Erforderlich, weil jede Voreinstellung eine stille Behauptung wäre.**
  /// Der Stand der Messung vom 02.09.2026, und er ist unangenehm:
  ///
  /// | Zahl | Wo |
  /// |---|---|
  /// | 12 | die Anzeige der Quelle, `screen-map.jsx:1196` |
  /// | 50 | was der Solo-Sammelweg wirklich bucht, `app.jsx:712` und `:714` |
  /// | 10 | `collect_fact_validated`, `supabase-schema.sql:125` und `:127` |
  ///
  /// Keine zwei davon stimmen überein, und die Anzeige stimmt mit keiner. Das
  /// ist die Anzeigehälfte von E-06. Welche Zahl der Neubau gutschreibt, ist
  /// mit dem Belohnungsjournal (J-C) eine offene Entscheidung; welche er
  /// **anzeigt**, entscheidet deshalb der Aufrufer und nicht dieses Widget.
  final int coinAmount;

  /// Die Zufallsquelle der Fluglängen, siehe [factCollectBurstDistances].
  ///
  /// `null` heißt `math.Random().nextDouble`. Ein Test speist eine eigene ein.
  final double Function()? nextDouble;

  @override
  State<FactCollectBurst> createState() => _FactCollectBurstState();
}

class _FactCollectBurstState extends State<FactCollectBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Die zehn Fluglängen, **einmal** gezogen, siehe
  /// [factCollectBurstDistances].
  late final List<double> _distances;

  @override
  void initState() {
    super.initState();
    _distances = factCollectBurstDistances(
      widget.nextDouble ?? math.Random().nextDouble,
    );
    _controller = AnimationController(
      duration: factCollectBurstDuration,
      vsync: this,
    );
    // `forward()` gibt eine `TickerFuture` zurück, die erst beim Ende oder
    // beim Anhalten erfüllt wird. Hier gibt es nichts abzuwarten, und
    // `reportDetached` wäre falsch: eine angehaltene Animation ist kein
    // Fehler. Dieselbe Zeile und dieselbe Begründung wie in
    // `fact_balloon_overlay.dart`, `_syncTicker`.
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `pointerEvents:'none'` (`:1183`): die Fläche liegt über der ganzen
    // Karte, und ein Tipp während des Fluges gehört weiter der Karte. Ohne
    // das verschluckte der Münzflug 1,25 Sekunden lang jede Geste.
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final Duration elapsed = factCollectBurstDuration * _controller.value;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              for (int i = 0; i < factCollectBurstAngles.length; i++)
                FactCollectBurstCoin(
                  key: ValueKey<int>(i),
                  index: i,
                  origin: widget.origin,
                  angleInDegrees: factCollectBurstAngles[i],
                  distance: _distances[i],
                  frame: factCollectCoinFrameAt(index: i, elapsed: elapsed),
                ),
              _FactCollectBurstLabel(
                origin: widget.origin,
                coinAmount: widget.coinAmount,
                frame: factCollectLabelFrameAt(elapsed),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Eine einzelne fliegende Münze.
///
/// **Öffentlich, damit ein Test Winkel, Länge und Versatz je Münze ablesen
/// kann.** Zehn gleich aussehende `Text`-Widgets sagen nichts darüber, ob die
/// Winkel stimmen und in der richtigen Reihenfolge stehen; genau daran war in
/// diesem Projekt schon ein Test blind (Muster 25).
@visibleForTesting
class FactCollectBurstCoin extends StatelessWidget {
  /// Erzeugt die Münze.
  const FactCollectBurstCoin({
    required this.index,
    required this.origin,
    required this.angleInDegrees,
    required this.distance,
    required this.frame,
    super.key,
  });

  /// Die Nummer der Münze, 0 bis 9. Bestimmt ihren Versatz, siehe [delay].
  final int index;

  /// Die Bildschirmlage des Ballons.
  final Offset origin;

  /// Der Winkel dieser Münze, siehe [factCollectBurstAngles].
  final double angleInDegrees;

  /// Die Fluglänge dieser Münze, siehe [factCollectBurstDistances].
  final double distance;

  /// Ihr aktueller Stand.
  final FactCollectCoinFrame frame;

  /// Wann diese Münze losfliegt, `${i * 40}ms`.
  Duration get delay => factCollectBurstStagger * index;

  @override
  Widget build(BuildContext context) {
    final Offset target = factCollectBurstTarget(
      angleInDegrees: angleInDegrees,
      distance: distance,
    );
    return Positioned(
      left: origin.dx + target.dx * frame.progress,
      top: origin.dy + target.dy * frame.progress,
      // `translate(-50%, -50%)`: die Münze sitzt mittig auf ihrer Lage, und
      // der Anteil bezieht sich auf ihre eigene Größe, nicht auf die Fläche.
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Opacity(
          opacity: frame.opacity,
          child: Transform.scale(
            scale: frame.scale,
            child: Transform.rotate(
              angle: frame.rotationInDegrees * math.pi / 180,
              child: const Text(
                factCollectBurstCoinGlyph,
                style: TextStyle(fontSize: factCollectBurstCoinFontSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Die aufsteigende Zahl über dem Ballon.
class _FactCollectBurstLabel extends StatelessWidget {
  const _FactCollectBurstLabel({
    required this.origin,
    required this.coinAmount,
    required this.frame,
  });

  final Offset origin;
  final int coinAmount;
  final FactCollectLabelFrame frame;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: origin.dx + frame.xInPixels,
      top: origin.dy,
      child: FractionalTranslation(
        translation: Offset(frame.xFraction, frame.yFraction),
        child: Opacity(
          opacity: frame.opacity,
          child: Transform.scale(
            scale: frame.scale,
            child: Text(
              // `+12 🪙` in der Quelle (`:1196`), hier mit der übergebenen
              // Zahl. **Kein Übersetzungsschlüssel**, und das ist dieselbe
              // Erwägung wie beim `m` in `hunt_pill.dart`: eine Ziffer und
              // ein Zeichen sind kein Lesetext. Die Quelle hat dafür
              // ebenfalls keinen Schlüssel.
              '+$coinAmount $factCollectBurstCoinGlyph',
              maxLines: 1,
              softWrap: false,
              style: FactTypography.emphasis.copyWith(
                fontSize: factCollectBurstLabelFontSize,
                color: factCollectBurstLabelColor,
                shadows: const <Shadow>[factCollectBurstLabelShadow],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
