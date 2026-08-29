/// Die Ballons der Fakten: ihre Maße, ihr Pinsel und die stehenden Bilder, mit
/// denen der Symbol-Layer sie zeichnet.
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
/// ## Die Zusage, die zu Punkt 1 gehört, und sie ist ab Schritt 17 eingelöst
///
/// Janek hat der nativen Zeichnung mit einer Auflage zugestimmt, wörtlich:
/// **„aber Animation und Glühen, Drehung müssen dann später aber kommen!!"**
/// Schritt 17 löst das ein, und zwar **ohne** Punkt 1 zurückzunehmen: die
/// Handvoll Ballons innerhalb von 150 Metern verlässt die native Überlagerung
/// und wird von `fact_balloon_overlay.dart` als Flutter-Widget gezeichnet,
/// alles darüber hinaus bleibt genau so nativ wie zuvor.
///
/// **Und deshalb malt beides derselbe Pinsel.** [paintFactBalloon] zeichnet
/// sowohl in die `Picture` dieser Fabrik als auch auf die Leinwand des
/// lebenden Widgets. Zwei Umsetzungen desselben Ballons wären nie gleichzeitig
/// sichtbar und liefen deshalb unbemerkt auseinander; sichtbar würde es erst
/// als Sprung beim Überqueren der 150-Meter-Grenze.
///
/// ## Warum die Maße hier stufenlos sind, die Bilder aber nicht
///
/// [FactBalloonMetrics] rechnet den Kopf stufenlos von 26 auf 48 Pixel
/// (`screen-map.jsx:2252-2256`). Stufenlos heißt: unendlich viele Bilder. Die
/// Achsen dieser **Fabrik** sind deshalb weiterhin Kategorie mal
/// Sammelzustand und nichts sonst, also eine zweistellige Zahl von Bildern;
/// sie zeichnet allein den ruhenden Ballon ([FactBalloonMetrics.resting]). Die
/// Betonung dazwischen zeichnet das Widget.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
// `Matrix4` liegt in `vector_math` und wird von `flutter/painting.dart`
// **nicht** exportiert. Der kleinste Flutter-Import, der ihn hergibt, ist
// `rendering.dart` (`flutter/lib/rendering.dart:36`); direkt aus `vector_math`
// zu importieren wäre eine Abhängigkeit, die nicht im `pubspec` steht.
import 'package:flutter/rendering.dart' show Matrix4;

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
/// zweite Zeile in diese Datei und eine zweite Achse in
/// [buildFactBalloonImages].
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

/// Der Rückweg: welche Kategorie hinter einer Stil-Kennung steckt.
///
/// Gibt `null` zurück, wenn die Kennung nicht von [factBalloonStyleId] stammt
/// oder auf eine unbekannte Kategorie zeigt.
///
/// **Warum es den Rückweg gibt.** Die Näherungs-Animation zeichnet ihre
/// Ballons selbst und braucht dafür Farbe und Zeichen; was sie in der Hand
/// hält, ist ein `MapOverlayPoint`, und der trägt laut Vertrag nur eine
/// Zeichenkette. Der Vertrag darf keine Fakt-Kategorie kennen (Regel 18), also
/// bleibt der Weg zurück über den Namen.
///
/// **Er zerlegt und rät nicht.** Drei Teile, der erste `fact`, der zweite die
/// Kategorie: ein Name mit einem Punkt mehr oder weniger fällt heraus, statt
/// als Kategorie durchzugehen. Dass Hin- und Rückweg zusammenpassen, ist für
/// alle zwölf Kategorien zugesichert.
FactCategoryStyle? factBalloonCategoryOf(String styleId) {
  final List<String> parts = styleId.split('.');
  if (parts.length != 3 || parts.first != 'fact') {
    return null;
  }
  return factCategoryStylesByKey[parts[1]];
}

// -----------------------------------------------------------------------------
// Maße
// -----------------------------------------------------------------------------
//
// Alle Zahlen in logischen Pixeln.
//
// ## Vier Zahlen standen hier falsch, und der Grund ist lehrreich
//
// Bis Schritt 17 waren sie sauber aus `coinMakeEl` (`screen-map.jsx:1835-1880`)
// abgeschrieben. **`coinMakeEl` beschreibt aber einen Zustand, den es weniger
// als ein Bild lang gibt.** `coinRafTick` läuft ab `:2325` sofort und
// **unbedingt**, auch ohne jede Ortung: der Else-Zweig `:2310-2321` greift
// dann, und `:2252-2270` laufen in jedem Fall vorher. Was der Nutzer sieht,
// steht deshalb im RAF und nicht im HTML:
//
// | Wert | stand hier | der Nutzer sieht | Fundstelle |
// |---|---|---|---|
// | Kopfdurchmesser | 28 | **26** | `:2252`, `:2257-2258` |
// | Emoji-Schriftgröße | 15 | **10,01** = 26·0,7·0,55 | `:2261-2264` |
// | Bodenschatten-Breite | 22 | **23,4** = 26·0,9 | `:2269` |
// | Weicher Schlagschatten | 12 px / 0,45 | **10 px / 0,40** | `:2315` |
//
// Ohne diese Korrektur **springt der Ballon beim Überqueren der
// 150-Meter-Grenze**, weil dort das PNG auf das gezeichnete Widget trifft.
//
// `styles.css:107-111` setzt `box-sizing: border-box` für alles, der Rahmen
// von 2 px liegt also **innen**: mit `width: 26px` ist der Kopf außen 26 breit
// und nicht 30.

/// Durchmesser des Kopfes ohne Betonung, außen.
///
/// `screen-map.jsx:2252`: `let sizePx = 26;`, und `:2257-2258` schreiben ihn
/// unbedingt an den Kopf.
const double factBalloonRestingHeadDiameter = 26;

/// Durchmesser des Kopfes bei voller Betonung.
///
/// `screen-map.jsx:2255`: `26 + (48 - 26) * Math.pow(t, 1.5)`.
const double factBalloonNearHeadDiameter = 48;

/// Der Exponent, mit dem der Kopf wächst (`screen-map.jsx:2255`).
const double factBalloonHeadGrowthExponent = 1.5;

/// Breite des Rahmens um den Kopf, nach innen (`screen-map.jsx:1854`).
const double factBalloonBorderWidth = 2;

/// Wie groß der innere Kasten im Verhältnis zum Kopf ist.
///
/// `screen-map.jsx:2261`: `const innerPx = sizePx * 0.7;`.
const double factBalloonInnerFraction = 0.7;

/// Wie groß die Schrift im Verhältnis zum inneren Kasten ist.
///
/// `screen-map.jsx:2264`: `innerEl.style.fontSize = (innerPx * 0.55)`.
const double factBalloonEmojiFraction = 0.55;

/// Breite des Stiels (`screen-map.jsx:1862`).
const double factBalloonStemWidth = 2;

/// Höhe des Stiels (`screen-map.jsx:1862`).
///
/// **Sie wächst nicht mit.** Die Quelle skaliert allein den Kopf; Stiel und
/// Bodenschatten behalten ihre Maße, und der Kopf steigt dadurch höher über
/// seine Koordinate. Genau das ist der Grund, warum `icon-size` diese
/// Animation nicht leisten kann: es skaliert das ganze Bild.
const double factBalloonStemHeight = 50;

/// Wie breit der Bodenschatten im Verhältnis zum Kopf ist.
///
/// `screen-map.jsx:2269`: `shadow.style.width = (sizePx * 0.9)`.
const double factBalloonGroundShadowFraction = 0.9;

/// Höhe des Bodenschattens (`screen-map.jsx:1864`).
const double factBalloonGroundShadowHeight = 7;

/// Freier Rand um den ruhenden Kopf, für den weichen Schlagschatten.
///
/// CSS gibt einem Schlagschatten mit `blur-radius: 10px` eine
/// Standardabweichung von 5 (die Spezifikation definiert den Blur-Radius als
/// das Doppelte davon). Eine Gaußglocke reicht rechnerisch unendlich weit;
/// jenseits von zwei Standardabweichungen liegt sie unter fünf Prozent
/// Deckkraft, und dieser Rest wird hier abgeschnitten. Zehn Pixel genügten
/// damit; es bleiben **zwölf**, weil der Wert schon vor der Korrektur so
/// lautete und ein Pixel Rand mehr weder etwas verschiebt noch etwas
/// abschneidet: der Ballon hängt an seiner **Unterkante**.
///
/// **Nach unten braucht es keinen Rand:** der Schatten sitzt am Kopf, und
/// unter dem Kopf liegen 50 Pixel Stiel. Er ist damit ohnehin im Bild. Ein
/// unterer Rand wäre sogar schädlich, denn `icon-anchor: bottom` setzt die
/// **Unterkante des Bildes** auf die Koordinate: jeder Pixel Rand dort schöbe
/// den ganzen Ballon nach oben.
const double factBalloonShadowPadding = 12;

/// Breite des fertigen Bildes der Fabrik.
const double factBalloonWidth =
    factBalloonRestingHeadDiameter + 2 * factBalloonShadowPadding;

/// Höhe des fertigen Bildes der Fabrik.
const double factBalloonHeight =
    factBalloonShadowPadding +
    factBalloonRestingHeadDiameter +
    factBalloonStemHeight +
    factBalloonGroundShadowHeight;

// -----------------------------------------------------------------------------
// Schatten
// -----------------------------------------------------------------------------
//
// Der Kopf trägt zwei verschiedene Schattensätze, und zwischen ihnen steht
// keine Blende, sondern eine Kante: `inRange` ist `dist < 150`.
//
// **Ruhend** (`screen-map.jsx:2315`, der Else-Zweig des RAF):
// `0 2px 0 {dk}` und `0 3px 10px rgba(0,0,0,0.4)`.
//
// **In Reichweite** (`:2295`), und das sind **drei** Schatten und nicht zwei:
// eine harte Kante `0 3px 0 {catDk}` mit Versatz 3 statt 2, ein harter
// Farbring `0 0 0 {4+8t}px` mit Deckkraft `0,28 t`, und ein weicher Schein
// `0 4px {16+14t}px` mit Deckkraft `0,15 + 0,55 t`.
//
// Der mittlere hat **keinen** Weichzeichner und wächst allein über die
// Streuung: das ist ein scharf berandeter Farbring um den Kopf, und den sieht
// man.
//
// ## Bekannte Abweichung: der Wechsel ist hier hart
//
// `screen-map.jsx:1851` setzt am Kopf `transition:box-shadow 0.4s`. Der
// Schattenwechsel an der 150-Meter-Grenze läuft in der Quelle also über vier
// Zehntelsekunden weich hinüber, im Nachbau schlägt er um. **Bewusst nicht
// gebaut:** die Grenze ist zugleich der Wechsel zwischen zwei Zeichenwegen,
// nativem Symbol-Layer und gezeichnetem Widget, und eine Blende darüber
// müsste beide Seiten gleichzeitig kennen. Wer sie nachrüstet, fängt hier an.

/// Deckkraft des schwarzen Schlagschattens am ruhenden Kopf
/// (`screen-map.jsx:2315`, `rgba(0,0,0,0.4)`).
const double factBalloonRestingShadowAlpha = 0.4;

/// Blur-Radius des schwarzen Schlagschattens am ruhenden Kopf
/// (`screen-map.jsx:2315`, `0 3px 10px`).
const double factBalloonRestingShadowBlur = 10;

/// Senkrechter Versatz des schwarzen Schlagschattens am ruhenden Kopf.
const double factBalloonRestingShadowOffsetY = 3;

/// Senkrechter Versatz der harten Kante am ruhenden Kopf
/// (`screen-map.jsx:2315`, `0 2px 0`).
const double factBalloonRestingEdgeOffsetY = 2;

/// Senkrechter Versatz der harten Kante am betonten Kopf
/// (`screen-map.jsx:2295`, `0 3px 0`).
const double factBalloonNearEdgeOffsetY = 3;

/// Senkrechter Versatz des weichen Scheins am betonten Kopf
/// (`screen-map.jsx:2295`).
const double factBalloonGlowOffsetY = 4;

/// Die Fluchtpunktweite des Ballons.
///
/// **Die Quelle setzt sie, und sie kommt am Kopf nicht an.** Gemessen an der
/// DOM-Kette:
///
/// ```text
/// el                    perspective:300px                     :1841
///  └─ .coin-float-wrap  kein preserve-3d, eigenes scale()     :1844, :2185
///       └─ .coin-head   transform-style:preserve-3d, rotateY  :1845, :1850, :2279
/// ```
///
/// CSS-`perspective` gilt nur für **direkte** Kinder. Der Kopf ist ein Enkel,
/// und `.coin-float-wrap` flacht seine Kinder mangels `preserve-3d` in die
/// eigene Ebene ab. Nachgesehen: `preserve-3d` kommt in `screen-map.jsx` und
/// `styles.css` zusammen **genau einmal** vor, auf `:1850`, also am Kopf
/// selbst, wo es nur `.coin-inner` betrifft. In der PWA wird `rotateY(θ)`
/// damit orthografisch projiziert, also zu einem symmetrischen `scaleX(cos θ)`
/// ohne jede Verkürzung.
///
/// **Wir zeichnen sie trotzdem: bewusste Abweichung vom 29.08.2026, dem
/// Product Owner vorgelegt.** Die Quelle *wollte* die Perspektive, sonst
/// stünden dort weder `perspective:300px` noch `preserve-3d`. Dass sie nicht
/// ankommt, ist derselbe Fehlertyp wie der statische `coinShadowFar` bei
/// `:1866`: eine Absicht, die an einer CSS-Feinheit scheitert und die niemand
/// bemerkt hat. Die stehende Anweisung dieses Projekts lautet, gefundene
/// Fehler zu beheben statt sie mitzuportieren. Es ist eine Zeile in beide
/// Richtungen, siehe [_applySpin].
const double factBalloonPerspective = 300;

/// Wie weit der harte Farbring über den Kopf hinausragt.
///
/// `screen-map.jsx:2283`: `const glowSize = 4 + g * 8;`, also 4 bis 12.
double factBalloonGlowRingSpread(double emphasis) => 4 + 8 * emphasis;

/// Die Deckkraft des harten Farbrings.
///
/// `screen-map.jsx:2295` setzt `g * 0.28`, also 0 bis 0,28. Bei Betonung 0 ist
/// der Ring damit unsichtbar; er wird es mit der Nähe.
double factBalloonGlowRingAlpha(double emphasis) => 0.28 * emphasis;

/// Der Blur-Radius des weichen Scheins.
///
/// `screen-map.jsx:2295` setzt `16 + g * 14`, also 16 bis 30.
double factBalloonGlowBlur(double emphasis) => 16 + 14 * emphasis;

/// Die Deckkraft des weichen Scheins.
///
/// `screen-map.jsx:2284`: `const glowAlpha = 0.15 + g * 0.55;`, also 0,15
/// bis 0,70.
double factBalloonGlowAlpha(double emphasis) => 0.15 + 0.55 * emphasis;

// -----------------------------------------------------------------------------
// Das Hüpfen und der Schatten darunter
// -----------------------------------------------------------------------------
//
// **Es sind zwei Wirkungen einer Bewegung und nicht zwei Bewegungen.**
// `screen-map.jsx:2300-2303` setzt `coinFloatNear` und `coinShadowNear`
// zusammen, `:2304-2308` löscht beide zusammen, beide laufen 2,2 Sekunden mit
// `ease-in-out`. Sie sind damit phasengleich, und genau deshalb nimmt
// [paintFactBalloon] **einen** Fortschritt entgegen und nicht zwei Zahlen: zwei
// Parameter wären zwei Gelegenheiten, auseinanderzulaufen, und das sähe aus wie
// ein Ballon, dessen Schatten neben ihm atmet.
//
// **Der statische `coinShadowFar` bei `:1866` bleibt weiterhin weg**, und der
// Unterschied ist wichtig: der ist eine vergessene Rückstellung. Der RAF
// schaltet ihn nur ab, wenn vorher `nearAnim` gesetzt war (`:2316-2320`). Jeder
// Ballon, der nie in Reichweite war, atmet dort dauerhaft; jeder, der einmal
// nah war, danach nie wieder. Zwei Ballons nebeneinander verhalten sich
// verschieden, je nachdem, wo der Nutzer einmal stand.

/// Wie hoch der Kopf des nächsten Ballons steigt, in Pixeln.
///
/// `styles.css:300-303`, `@keyframes coinFloatNear`: `translateY(-9px)` bei
/// 50 Prozent, 0 an beiden Enden.
const double factBalloonFloatRise = 9;

/// Wie schmal der Bodenschatten am Scheitel des Hüpfens wird.
///
/// `styles.css:308-311`, `@keyframes coinShadowNear`: `scaleX(0.55)` bei
/// 50 Prozent.
const double factBalloonNearShadowScaleX = 0.55;

/// Wie flach der Bodenschatten am Scheitel des Hüpfens wird.
///
/// `styles.css:310`: `scaleY(0.6)`.
const double factBalloonNearShadowScaleY = 0.6;

/// Wie blass der Bodenschatten am Scheitel des Hüpfens wird.
///
/// `styles.css:310`: `opacity: 0.5`. Der `transform-origin` steht auf seinem
/// Standard, also der Mitte des Schattenkastens; er schrumpft zur Mitte hin
/// und wandert nicht.
const double factBalloonNearShadowOpacity = 0.5;

// -----------------------------------------------------------------------------
// Maßsatz
// -----------------------------------------------------------------------------

/// Alle Maße eines Ballons bei einer bestimmten Betonung.
///
/// **Betonung** ist `t = 1 - Entfernung / 150` aus `screen-map.jsx:2254`, also
/// 0 am Rand des Sammelradius und 1 auf dem Fakt. Sie steht hier und nicht als
/// „Entfernung in Metern", weil dieser Typ nichts über GPS wissen soll: er
/// beschreibt einen Ballon, nicht einen Nutzer.
///
/// Es gibt ihn, damit **Fabrik und Widget dieselben Zahlen benutzen**. Der
/// Sprung an der 150-Meter-Grenze ist genau der Fehler, den zwei getrennte
/// Rechnungen erzeugen und den kein Test sieht, der nur eine Seite ansieht.
@immutable
final class FactBalloonMetrics {
  /// Erzeugt einen Maßsatz für [emphasis] zwischen 0 und 1.
  const FactBalloonMetrics({this.emphasis = 0});

  /// Der ruhende Ballon, den die Bildfabrik zeichnet.
  static const FactBalloonMetrics resting = FactBalloonMetrics();

  /// Wie stark der Ballon betont ist, 0 bis 1.
  final double emphasis;

  /// Durchmesser des Kopfes.
  ///
  /// `screen-map.jsx:2255`: `26 + (48 - 26) * Math.pow(t, 1.5)`.
  double get headDiameter =>
      factBalloonRestingHeadDiameter +
      (factBalloonNearHeadDiameter - factBalloonRestingHeadDiameter) *
          math.pow(emphasis, factBalloonHeadGrowthExponent);

  /// Schriftgröße des Zeichens im Kopf, `line-height: 1`.
  double get emojiSize =>
      headDiameter * factBalloonInnerFraction * factBalloonEmojiFraction;

  /// Breite des Bodenschattens.
  double get groundShadowWidth =>
      headDiameter * factBalloonGroundShadowFraction;

  /// Freier Rand um den Kopf, gerade so groß wie der Schatten dieses Zustands.
  ///
  /// **Zwei Zustände, zwei Reichweiten**, siehe den Abschnitt „Schatten": der
  /// ruhende Kopf trägt einen schwarzen Schlagschatten mit Blur 10, der
  /// betonte einen farbigen mit Blur 16 bis 30. Der harte Farbring
  /// ([factBalloonGlowRingSpread], höchstens 12) bleibt dabei immer innerhalb
  /// des weichen Scheins.
  ///
  /// Bei Betonung 0 gilt ausdrücklich der Rand des ruhenden Bildes, und das
  /// ist der Grund, warum [size] dort **genau** [factBalloonWidth] mal
  /// [factBalloonHeight] ergibt.
  double get shadowPadding =>
      emphasis <= 0 ? factBalloonShadowPadding : factBalloonGlowBlur(emphasis);

  /// Breite der Fläche, in die dieser Ballon passt.
  double get width => headDiameter + 2 * shadowPadding;

  /// Höhe der Fläche, in die dieser Ballon passt.
  ///
  /// Kopf, Stiel und Bodenschatten stehen in einer Spalte, wie die drei
  /// Kinder von `el` in `coinMakeEl` (`screen-map.jsx:1843-1868`,
  /// `flex-direction:column`). Der Stiel wächst nicht mit, der Kopf steigt
  /// also, wenn er wächst.
  double get height =>
      shadowPadding +
      headDiameter +
      factBalloonStemHeight +
      factBalloonGroundShadowHeight;

  /// Die Fläche als Ganzes.
  Size get size => Size(width, height);

  /// Wo der Mittelpunkt des Kopfes liegt, ohne das Auf-und-ab.
  Offset get headCenter => Offset(width / 2, shadowPadding + headDiameter / 2);

  /// Wo der Ballon die Karte berührt.
  ///
  /// Die Unterkante der Fläche, mittig: `icon-anchor: bottom` setzt genau die
  /// auf die Koordinate, und `new mapboxgl.Marker({ anchor: 'bottom' })`
  /// (`screen-map.jsx:2187`) tut dasselbe. **Das ist die Zeile, an der Widget
  /// und Symbol-Layer sich treffen müssen.**
  Offset get anchor => Offset(width / 2, height);

  @override
  bool operator ==(Object other) =>
      other is FactBalloonMetrics && other.emphasis == emphasis;

  @override
  int get hashCode => emphasis.hashCode;

  @override
  String toString() => 'FactBalloonMetrics(Betonung $emphasis)';
}

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

/// Zeichnet einen einzelnen ruhenden Ballon.
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
  paintFactBalloon(canvas, style);

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

// -----------------------------------------------------------------------------
// Der gemeinsame Pinsel
// -----------------------------------------------------------------------------

/// Zeichnet den Ballon in logischen Pixeln, mit der linken oberen Ecke seiner
/// Fläche im Ursprung.
///
/// **Diese eine Funktion malt beide Ballons**, das stehende PNG des
/// Symbol-Layers und den lebenden Ballon über der Karte. Ohne das gäbe es zwei
/// Umsetzungen desselben Bildes, die **nie gleichzeitig sichtbar sind** und
/// deshalb unbemerkt auseinanderlaufen; auffallen würde es erst als Sprung an
/// der 150-Meter-Grenze.
///
/// [spinDegrees] dreht **allein den Kopf** um seine senkrechte Achse, samt
/// seinen Schatten und seinem Zeichen: in der Quelle sitzt das `rotateY` an
/// `.coin-head` (`screen-map.jsx:2279`), und ein `box-shadow` gehört zum
/// Element und dreht sich mit.
///
/// [floatProgress] ist der Stand des Hüpfens, 0 am Boden und 1 im Scheitel.
/// Er treibt **zwei** Dinge, und beide gehören zusammen: der Kopf steigt um
/// [factBalloonFloatRise], und der Bodenschatten schrumpft und verblasst.
/// `screen-map.jsx:2300-2303` schaltet `coinFloatNear` und `coinShadowNear`
/// gemeinsam ein.
///
/// **Gehoben wird allein der Kopf.** `transform` verändert kein Layout, in der
/// Quelle bleiben Stiel und Bodenschatten deshalb an Ort und Stelle, wenn
/// `.coin-float-wrap` schwebt; der Schatten ändert nur seine Größe, nicht
/// seinen Platz.
///
/// Die Zeichenreihenfolge ist die von CSS: Schatten liegen hinter dem Element,
/// und unter mehreren `box-shadow`-Einträgen liegt der zuerst genannte oben.
/// Gezeichnet wird deshalb von hinten nach vorn.
void paintFactBalloon(
  Canvas canvas,
  FactCategoryStyle style, {
  FactBalloonMetrics metrics = FactBalloonMetrics.resting,
  double spinDegrees = 0,
  double floatProgress = 0,
}) {
  final double headRadius = metrics.headDiameter / 2;
  final Offset headCenter = metrics.headCenter.translate(
    0,
    -factBalloonFloatRise * floatProgress,
  );

  canvas.save();
  _applySpin(canvas, headCenter, spinDegrees);
  _paintHeadShadows(canvas, style, metrics, headCenter);
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
  _paintEmoji(canvas, style.emoji, headCenter, metrics.emojiSize);
  canvas.restore();

  // `linear-gradient(180deg, {color}CC, {color}11)`. Der Stiel hängt an der
  // **ungehobenen** Unterkante des Kopfes: schwebt der Kopf, entsteht die
  // Lücke, die die Quelle auch zeigt.
  final Rect stem = Rect.fromLTWH(
    metrics.width / 2 - factBalloonStemWidth / 2,
    metrics.shadowPadding + metrics.headDiameter,
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

  _paintGroundShadow(
    canvas,
    style.color,
    metrics,
    stem.bottom,
    floatProgress: floatProgress,
  );
}

/// Dreht die Leinwand so, wie CSS den Kopf dreht.
///
/// ## Die Drehung ist keine Drehung in der Bildebene
///
/// `screen-map.jsx:1845-1861` setzt **kein** `backface-visibility:hidden`.
/// Jenseits von 90 Grad sieht man deshalb die gespiegelte Rückseite samt
/// gespiegeltem Zeichen, hier wie dort. Der Weg dahin ist allerdings ein
/// anderer: in der Quelle entsteht die Spiegelung aus dem orthografischen
/// `scaleX(cos θ)`, das bei stumpfem Winkel negativ wird, hier aus der
/// perspektivischen Matrix, die den Inhalt von selbst spiegelt, sobald die
/// Vorderseite wegdreht.
///
/// ## Das Vorzeichen ist hergeleitet und nicht abgeschrieben
///
/// CSS setzt `w = 1 - z/d`, die Perspektivzeile ist also `-1/d`. Flutters
/// `Matrix4.rotateY` bildet einen Punkt `(u, 0, 0)` auf
/// `(u·cos θ, 0, -u·sin θ)` ab, genau wie die CSS-Spezifikation. Mit `+1/d`
/// würde die **wegdrehende** Seite größer statt kleiner, und das sieht man:
/// ein Ballon, dessen abgewandte Kante nach vorn quillt.
///
/// **Die Herleitung stimmt, ihre Voraussetzung nicht.** In der Quelle erreicht
/// die Perspektive den Kopf gar nicht, siehe [factBalloonPerspective]. Das
/// Vorzeichen beantwortet damit richtig, wie CSS es rechnete, wenn die
/// Perspektive ankäme; angekommen ist sie nur hier. Gemessen an der Quelle ist
/// die Verkürzung selbst die Abweichung, nicht ihre Richtung.
///
/// ## Der Fluchtpunkt sitzt in der Kopfmitte, und das ist eine Wahl
///
/// CSS läge er in der Mitte von `el`, also der ganzen Spalte aus Kopf, Stiel
/// und Bodenschatten, und damit `(50 + 7) / 2 = 28,5` Pixel **unter** der
/// Kopfmitte. Der Unterschied wäre eine leichte senkrechte Scherung, bei 90
/// Grad und einem 48er Kopf rund zwei Pixel.
///
/// **Diese Rechnung ist richtig und dadurch gegenstandslos:** ohne Perspektive
/// an `.coin-head` hat die Quelle keinen Fluchtpunkt, gegen den sich hier
/// etwas verschieben ließe. Die Kopfmitte ist deshalb keine Näherung an einen
/// gemessenen Wert, sondern gesetzt, und sie ist gesetzt, weil der Kopf das
/// einzige Teil ist, das sich dreht.
void _applySpin(Canvas canvas, Offset headCenter, double spinDegrees) {
  if (spinDegrees == 0) {
    return;
  }
  final Matrix4 matrix = Matrix4.identity()
    ..setEntry(3, 2, -1 / factBalloonPerspective)
    ..rotateY(spinDegrees * math.pi / 180);
  canvas
    ..translate(headCenter.dx, headCenter.dy)
    ..transform(matrix.storage)
    ..translate(-headCenter.dx, -headCenter.dy);
}

/// Die Schatten des Kopfes, von hinten nach vorn.
void _paintHeadShadows(
  Canvas canvas,
  FactCategoryStyle style,
  FactBalloonMetrics metrics,
  Offset headCenter,
) {
  final double headRadius = metrics.headDiameter / 2;

  if (metrics.emphasis <= 0) {
    // Ruhend: harte Kante mit Versatz 2, darüber der schwarze Schlagschatten
    // mit Versatz 3 und Blur 10 (`screen-map.jsx:2315`).
    canvas
      ..drawCircle(
        headCenter.translate(0, factBalloonRestingShadowOffsetY),
        headRadius,
        Paint()
          ..color = const Color(
            0xFF000000,
          ).withValues(alpha: factBalloonRestingShadowAlpha)
          // Blur-Radius 10 heißt Standardabweichung 5.
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            factBalloonRestingShadowBlur / 2,
          ),
      )
      ..drawCircle(
        headCenter.translate(0, factBalloonRestingEdgeOffsetY),
        headRadius,
        Paint()..color = style.darkColor,
      );
    return;
  }

  canvas
    // Weicher Schein, Blur 16 bis 30, Deckkraft 0,15 bis 0,70.
    ..drawCircle(
      headCenter.translate(0, factBalloonGlowOffsetY),
      headRadius,
      Paint()
        ..color = style.color.withValues(
          alpha: factBalloonGlowAlpha(metrics.emphasis),
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          factBalloonGlowBlur(metrics.emphasis) / 2,
        ),
    )
    // Harter Farbring: kein Versatz, kein Weichzeichner, nur Streuung 4 bis
    // 12. Eine scharfe Kante, und die sieht man.
    ..drawCircle(
      headCenter,
      headRadius + factBalloonGlowRingSpread(metrics.emphasis),
      Paint()
        ..color = style.color.withValues(
          alpha: factBalloonGlowRingAlpha(metrics.emphasis),
        ),
    )
    // Harte Kante, ein Pixel tiefer als im Ruhezustand.
    ..drawCircle(
      headCenter.translate(0, factBalloonNearEdgeOffsetY),
      headRadius,
      Paint()..color = style.darkColor,
    );
}

/// Setzt das Zeichen mittig in den Kopf.
///
/// `line-height: 1`, waagerecht und senkrecht zentriert
/// (`screen-map.jsx:1856-1860`, Größe aus `:2264`). Die Farbe im [TextStyle]
/// ist ohne Wirkung, weil ein Emoji seine eigenen Farben mitbringt; sie steht
/// trotzdem da, weil ein `TextStyle` ohne Farbe je nach Umgebung eine geerbte
/// bekäme, und dieser Pinsel hat keine Umgebung.
void _paintEmoji(Canvas canvas, String emoji, Offset center, double fontSize) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: emoji,
      style: TextStyle(
        fontSize: fontSize,
        height: 1,
        color: const Color(0xFF000000),
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
/// einem Kasten von [FactBalloonMetrics.groundShadowWidth] mal 7 Pixeln
/// (`screen-map.jsx:1863-1867`, Breite aus `:2269`).
///
/// **Eine bewusste Näherung, und sie liegt woanders, als man zuerst denkt.**
/// Die Form stimmt: CSS zeichnet ohne weitere Angabe eine Ellipse, hier
/// entsteht ein Kreis, der in der Höhe auf dasselbe Seitenverhältnis gestaucht
/// wird. Was abweicht, ist die **Ausdehnung**. `radial-gradient(ellipse, ...)`
/// ohne Größenangabe heißt `farthest-corner`: die Ellipse wächst, bis sie durch
/// die entfernteste Ecke des Kastens geht, ihre große Halbachse ist also mit
/// Wurzel 2 zu multiplizieren. Die Farbstopps bei 0, 55 und 75 Prozent liegen
/// damit in der Quelle weiter außen als hier.
///
/// Unsichtbar, weil der äußerste Ring ohnehin bei Deckkraft 0x11 von 255
/// beginnt und bei 75 Prozent auf null steht. Genau gerechnet wäre der Radius
/// mit Wurzel 2 zu multiplizieren; das bleibt bewusst weg, weil es den Schatten
/// breiter machte als den Kasten der Quelle.
///
/// **[floatProgress] lässt ihn mit dem Kopf atmen** (`coinShadowNear`,
/// `styles.css:308-311`): im Scheitel ist er 0,55 mal so breit, 0,6 mal so hoch
/// und halb so deckend. Die Deckkraft wird hier in die Farbstopps gerechnet und
/// nicht über `Paint.color` gelegt. Ob ein `Paint.color` neben einem gesetzten
/// `shader` überhaupt wirkt, ist hier **nicht** gemessen; ein in die Stopps
/// gerechneter Alphawert braucht die Frage nicht zu beantworten.
void _paintGroundShadow(
  Canvas canvas,
  Color color,
  FactBalloonMetrics metrics,
  double top, {
  required double floatProgress,
}) {
  final double radius = metrics.groundShadowWidth / 2;
  final Offset center = Offset(
    metrics.width / 2,
    top + factBalloonGroundShadowHeight / 2,
  );
  final double squashX = 1 - (1 - factBalloonNearShadowScaleX) * floatProgress;
  final double squashY = 1 - (1 - factBalloonNearShadowScaleY) * floatProgress;
  final double opacity = 1 - (1 - factBalloonNearShadowOpacity) * floatProgress;

  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..scale(
      squashX,
      squashY * factBalloonGroundShadowHeight / metrics.groundShadowWidth,
    )
    ..drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          radius,
          <Color>[
            color.withAlpha((0x44 * opacity).round()),
            color.withAlpha((0x11 * opacity).round()),
            color.withAlpha(0),
          ],
          <double>[0, 0.55, 0.75],
        ),
    )
    ..restore();
}
