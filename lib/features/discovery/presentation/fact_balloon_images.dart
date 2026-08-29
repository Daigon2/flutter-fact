/// Die Ballons der Fakten, zur Laufzeit gezeichnet.
///
/// ## Zwei Entscheidungen von Janek vom 29.08.2026 stecken hier drin
///
/// 1. **Die Ballons werden nativ gezeichnet**, nicht als Flutter-Widgets über
///    der Karte. Ein Symbol-Layer kostet bei 600 Fakten null Widgets und null
///    Aufbauten je Bild; 600 Positionswidgets kosten beides bei jeder
///    Kamerabewegung.
/// 2. **Die Bilder entstehen zur Laufzeit und liegen nicht als Dateien im
///    Repository.** So folgen sie den Design-Tokens: eine Kategoriefarbe
///    ändert sich an einer Stelle und nicht in zwölf PNG-Dateien.
///
/// ## Die Zusage, die zu Punkt 1 gehört, und sie ist nicht eingelöst
///
/// Janek hat der nativen Zeichnung mit einer Auflage zugestimmt, wörtlich:
/// **„aber Animation und Glühen, Drehung müssen dann später aber kommen!!"**
/// Das ist eine Zusage und keine Option. Sie ist in diesem Schritt
/// **ausdrücklich nicht** eingelöst: hier entsteht ein stehendes Bild je
/// Kategorie, es schwebt nicht, es glüht nicht und es dreht sich nicht.
///
/// Der Schritt, der sie einlöst, ist Schritt 17, und er setzt genau hier an.
/// Was die Verhaltensquelle dafür vorgibt:
///
/// | Wirkung | Fundstelle |
/// |---|---|
/// | Schweben des Kopfes | `styles.css:296-307`, `coinFloatFar/Near/Gold` |
/// | Atmen des Bodenschattens | `styles.css:308-319`, `coinShadowNear/Far/Gold` |
/// | Y-Drehung, Tempo nach Entfernung | `screen-map.jsx:2272-2277` |
/// | Größe 26 px fern bis 48 px nah | `screen-map.jsx:2252-2256` |
/// | Glühen im Sammelradius | `screen-map.jsx:2281-2295` |
///
/// **Warum das nicht nebenbei geht:** ein Symbol-Layer zeichnet ein Bild, er
/// animiert es nicht. Für Schritt 17 stehen zwei Wege im Raum, und keiner ist
/// gemessen: entweder die wenigen Ballons im Sammelradius werden zusätzlich
/// als Flutter-Widgets über der Karte gezeichnet (die Karte liefert dafür
/// `toScreenLocation`), oder die Bildfabrik erzeugt Einzelbilder einer
/// Bewegung und der Layer schaltet zwischen ihnen um. Der erste Weg ist näher
/// an der Quelle, der zweite bleibt nativ.
///
/// ## Warum die Entfernungsstufe hier nicht vorkommt
///
/// `screen-map.jsx:2252-2256` staucht den Kopf stufenlos von 26 auf 48 Pixel
/// (`26 + 22 * pow(t, 1.5)`). Stufenlos heißt: unendlich viele Bilder. Die
/// Achsen dieser Fabrik sind deshalb **Kategorie mal Sammelzustand** und
/// nichts sonst, also eine zweistellige Zahl von Bildern. Die Entfernung ist
/// genau der Teil, der zu Schritt 17 gehört.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:flutter/painting.dart';

/// Der Sammelzustand „noch nicht gesammelt".
///
/// **Heute der einzige, weil es keine Quelle für einen zweiten gibt.**
/// `features/collection` existiert nicht, niemand kann sagen, welcher Fakt
/// gesammelt ist, und ein zweiter Satz Bilder wäre Zeichenarbeit ohne
/// Aufrufer.
///
/// **Der Auslöser:** das erste Feature, das den Sammelzustand kennt. Der
/// goldene Ballon der Quelle ist vollständig belegt und muss nicht erfunden
/// werden (`screen-map.jsx:2147-2181`): Kopf als Radialverlauf
/// `#EAD58E → #B0974A → #6E5826`, Rahmen `rgba(240,220,150,0.55)`,
/// Sättigung 0,62, ein grüner Haken oben rechts, das Emoji auf 0,8 Deckkraft
/// und mit 0,38 Graustufe, dazu ein bräunlicher Bodenschatten. Dann kommt eine
/// zweite Zeile in diese Datei und eine zweite Achse in [buildFactBalloonImages].
const String factNotCollectedState = 'uncollected';

/// Die Stil-Kennung eines Ballons.
///
/// **Mit `fact.` davor, und das ist kein Schmuck.** Bilder gehören der Karte
/// und nicht einer Überlagerung: `MapLibreMapController.addImage` legt sie in
/// einen gemeinsamen Namensraum, den sich alle Layer teilen. Ohne Präfix hieße
/// das erste Bild des nächsten Features vielleicht ebenfalls `hist`, und eines
/// von beiden verschwände lautlos.
String factBalloonStyleId(String categoryKey, String state) =>
    'fact.$categoryKey.$state';

// -----------------------------------------------------------------------------
// Maße
// -----------------------------------------------------------------------------
//
// Alle Zahlen in logischen Pixeln und alle aus `coinMakeEl`
// (`screen-map.jsx:1835-1880`). `styles.css:107-111` setzt
// `box-sizing: border-box` für alles, der Rahmen von 2 px liegt also **innen**:
// der Kopf ist außen 28 px breit und nicht 32.

/// Durchmesser des Kopfes, außen.
const double factBalloonHeadDiameter = 28;

/// Breite des Rahmens um den Kopf, nach innen.
const double factBalloonBorderWidth = 2;

/// Schriftgröße des Emojis, `line-height: 1`.
const double factBalloonEmojiSize = 15;

/// Breite des Stiels.
const double factBalloonStemWidth = 2;

/// Höhe des Stiels.
const double factBalloonStemHeight = 50;

/// Breite des Bodenschattens.
const double factBalloonGroundShadowWidth = 22;

/// Höhe des Bodenschattens.
const double factBalloonGroundShadowHeight = 7;

/// Freier Rand um den Kopf, für den weichen Schlagschatten.
///
/// CSS gibt einem Schlagschatten mit `blur-radius: 12px` eine
/// Standardabweichung von 6 (die Spezifikation definiert den Blur-Radius als
/// das Doppelte davon). Eine Gaußglocke reicht rechnerisch unendlich weit;
/// jenseits von zwei Standardabweichungen liegt sie unter fünf Prozent
/// Deckkraft, und dieser Rest wird hier abgeschnitten. Zwölf statt achtzehn
/// Pixel Rand sparen bei Bildverhältnis 3 rund ein Drittel der Bildfläche je
/// Ballon.
///
/// **Nach unten braucht es keinen Rand:** der Schatten sitzt am Kopf, und
/// unter dem Kopf liegen 50 Pixel Stiel. Er ist damit ohnehin im Bild. Ein
/// unterer Rand wäre sogar schädlich, denn `icon-anchor: bottom` setzt die
/// **Unterkante des Bildes** auf die Koordinate: jeder Pixel Rand dort schöbe
/// den ganzen Ballon nach oben.
const double factBalloonShadowPadding = 12;

/// Breite des fertigen Bildes.
const double factBalloonWidth =
    factBalloonHeadDiameter + 2 * factBalloonShadowPadding;

/// Höhe des fertigen Bildes.
const double factBalloonHeight =
    factBalloonShadowPadding +
    factBalloonHeadDiameter +
    factBalloonStemHeight +
    factBalloonGroundShadowHeight;

// -----------------------------------------------------------------------------
// Fabrik
// -----------------------------------------------------------------------------

/// Zeichnet je Kategorie einen Ballon, für ein Gerät mit [pixelRatio].
///
/// Der Reihe nach und nicht nebenläufig: zwölf kleine Bilder sind in Summe
/// wenige Millisekunden, und `Picture.toImage` gleichzeitig zwölfmal zu
/// starten spart nichts, was der Aufwand wert wäre.
Future<List<MapOverlayImage>> buildFactBalloonImages({
  required double pixelRatio,
}) async {
  final List<MapOverlayImage> images = <MapOverlayImage>[];
  for (final FactCategoryStyle style in factCategoryStyles) {
    images.add(await buildFactBalloonImage(style, pixelRatio: pixelRatio));
  }
  return images;
}

/// Zeichnet einen einzelnen Ballon.
///
/// [pixelRatio] ist das Bildverhältnis des Bildschirms. Das Bild wird
/// entsprechend größer gerechnet und meldet sein Verhältnis mit, damit
/// MapLibre es wieder auf die logische Größe bringt. Wer hier immer 1 liefert,
/// bekommt auf einem 3x-Gerät matschige Ballons; wer das Verhältnis
/// verschweigt, dreifach zu große.
Future<MapOverlayImage> buildFactBalloonImage(
  FactCategoryStyle style, {
  required double pixelRatio,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  _paintBalloon(canvas, style);

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    (factBalloonWidth * pixelRatio).round(),
    (factBalloonHeight * pixelRatio).round(),
  );
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  if (data == null) {
    // `toByteData` gibt `null` zurück, wenn das Bild nicht kodiert werden
    // konnte. Ein leeres Bild wäre ein Symbol-Layer, der lautlos nichts
    // zeichnet, also genau der Ausfall, gegen den dieser ganze Schritt gebaut
    // ist.
    throw StateError('Ballonbild für ${style.key} ließ sich nicht kodieren');
  }

  return MapOverlayImage(
    styleId: factBalloonStyleId(style.key, factNotCollectedState),
    bytes: data.buffer.asUint8List(),
    pixelRatio: pixelRatio,
  );
}

/// Zeichnet den Ballon in logischen Pixeln.
///
/// Die Reihenfolge ist die von CSS: Schatten liegen hinter dem Element, und
/// unter zwei `box-shadow`-Einträgen liegt der zuerst genannte oben
/// (`screen-map.jsx:1848`: erst der harte, dann der weiche). Gezeichnet wird
/// deshalb von hinten nach vorn.
void _paintBalloon(Canvas canvas, FactCategoryStyle style) {
  const double centerX = factBalloonWidth / 2;
  const double headRadius = factBalloonHeadDiameter / 2;
  const double headTop = factBalloonShadowPadding;
  const Offset headCenter = Offset(centerX, headTop + headRadius);

  // `0 3px 12px rgba(0,0,0,0.45)`. Blur-Radius 12 heißt Standardabweichung 6.
  canvas.drawCircle(
    headCenter.translate(0, 3),
    headRadius,
    Paint()
      ..color = const Color(0x73000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  // `0 2px 0 {dk}`: harte Kante, kein Weichzeichner.
  canvas.drawCircle(
    headCenter.translate(0, 2),
    headRadius,
    Paint()..color = style.darkColor,
  );

  canvas.drawCircle(headCenter, headRadius, Paint()..color = style.color);

  // `border: 2px solid rgba(255,255,255,0.3)`, innen liegend: die Strichmitte
  // liegt deshalb eine halbe Strichbreite innerhalb des Außenrandes.
  canvas.drawCircle(
    headCenter,
    headRadius - factBalloonBorderWidth / 2,
    Paint()
      ..color = const Color(0x4DFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = factBalloonBorderWidth,
  );

  _paintEmoji(canvas, style.emoji, headCenter);

  // `linear-gradient(180deg, {color}CC, {color}11)`.
  const Rect stem = Rect.fromLTWH(
    centerX - factBalloonStemWidth / 2,
    headTop + factBalloonHeadDiameter,
    factBalloonStemWidth,
    factBalloonStemHeight,
  );
  canvas.drawRect(
    stem,
    Paint()
      ..shader = ui.Gradient.linear(stem.topCenter, stem.bottomCenter, <Color>[
        style.color.withAlpha(0xCC),
        style.color.withAlpha(0x11),
      ]),
  );

  _paintGroundShadow(canvas, style.color, stem.bottom);
}

/// Setzt das Emoji mittig in den Kopf.
///
/// `font-size: 15px; line-height: 1`, waagerecht und senkrecht zentriert
/// (`screen-map.jsx:1856-1860`). Die Farbe im [TextStyle] ist ohne Wirkung,
/// weil ein Emoji seine eigenen Farben mitbringt; sie steht trotzdem da, weil
/// ein `TextStyle` ohne Farbe je nach Umgebung eine geerbte bekäme, und diese
/// Fabrik hat keine Umgebung.
void _paintEmoji(Canvas canvas, String emoji, Offset center) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: emoji,
      style: const TextStyle(
        fontSize: factBalloonEmojiSize,
        height: 1,
        color: Color(0xFF000000),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}

/// Zeichnet die Ellipse am Boden.
///
/// `radial-gradient(ellipse, {color}44 0%, {color}11 55%, transparent 75%)` in
/// einem Kasten von 22 mal 7 Pixeln (`screen-map.jsx:1863-1867`).
///
/// **Eine bewusste Näherung, und sie liegt woanders, als man zuerst denkt.**
/// Die Form stimmt: CSS zeichnet ohne weitere Angabe eine Ellipse, hier
/// entsteht ein Kreis, der in der Höhe auf dasselbe Seitenverhältnis gestaucht
/// wird. Was abweicht, ist die **Ausdehnung**. `radial-gradient(ellipse, ...)`
/// ohne Größenangabe heißt `farthest-corner`: die Ellipse wächst, bis sie durch
/// die entfernteste Ecke des Kastens geht, ihre große Halbachse ist also
/// 11 mal Wurzel 2, rund 15,6, und nicht 11. Die Farbstopps bei 0, 55 und 75
/// Prozent liegen damit in der Quelle weiter außen als hier.
///
/// Unsichtbar, weil der äußerste Ring ohnehin bei Deckkraft 0x11 von 255
/// beginnt und bei 75 Prozent auf null steht. Genau gerechnet wäre der Radius
/// mit Wurzel 2 zu multiplizieren; das bleibt bewusst weg, weil es den Schatten
/// breiter machte als den 22 Pixel breiten Kasten der Quelle.
void _paintGroundShadow(Canvas canvas, Color color, double top) {
  const double radius = factBalloonGroundShadowWidth / 2;
  final Offset center = Offset(
    factBalloonWidth / 2,
    top + factBalloonGroundShadowHeight / 2,
  );

  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..scale(1, factBalloonGroundShadowHeight / factBalloonGroundShadowWidth)
    ..drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          radius,
          <Color>[
            color.withAlpha(0x44),
            color.withAlpha(0x11),
            color.withAlpha(0),
          ],
          <double>[0, 0.55, 0.75],
        ),
    )
    ..restore();
}
