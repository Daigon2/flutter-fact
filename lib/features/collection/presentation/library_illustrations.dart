/// Die Stadt-Illustrationen des Reiseführers,
/// `02_Frontend/app/screen-wallet.jsx:244-381` (`WltCityIllustration`).
///
/// ## Drei Städte haben eine eigene, alle anderen eine allgemeine
///
/// Gemessen am 03.09.2026: die Funktion hat genau **drei** Zweige, für
/// `münchen` (`:249`), `rom` (`:302`) und `regensburg` (`:330`), und danach
/// einen Rückfall (`:359`). **Passau und Weimar bekommen den Rückfall**,
/// obwohl sie in `WalletCities` eine eigene Palette haben und im Regal stehen.
/// Das ist keine Auslassung dieses Neubaus, sondern der Stand der Quelle; die
/// Silhouette ist dort Handarbeit, und für zwei der fünf Pilotstädte hat sie
/// noch niemand gezeichnet.
///
/// Weil die Farben aus der Palette der Stadt kommen, sieht der Rückfall
/// trotzdem nach der jeweiligen Stadt aus: Passau bleibt teal, Weimar ocker.
///
/// ## Kein SVG-Paket, sondern Canvas
///
/// Die Quelle ist wörtliches SVG. `flutter_svg` wäre der offensichtliche Weg
/// und ist **nicht** freigegeben; ein neues Paket ist nach `CLAUDE.md` eine
/// Entscheidung des Eigentümers. Gebraucht wird es hier auch nicht: es sind
/// vier Zeichnungen aus Rechtecken, Kreisen, Ellipsen, Linien und quadratischen
/// Kurven, und die kann `Canvas` alle. **Wenn eine sechste Stadt eine eigene
/// Silhouette bekommen soll, ist das die richtige Stelle, die Frage neu zu
/// stellen:** eine SVG-Datei je Stadt ist besser zu pflegen als ein Painter je
/// Stadt, und mehrstädtisch wächst genau diese Zahl.
///
/// ## Die Geometrie steckt in einem Attribut
///
/// `viewBox="0 0 240 280"` mit `preserveAspectRatio="xMidYMax slice"`.
/// `slice` heißt „füllen und überstehen lassen", also der größere der beiden
/// Maßstäbe, und `xMidYMax` heißt waagerecht mittig, senkrecht **unten**
/// ausgerichtet. Das ist keine Kleinigkeit: mit `contain` statt `cover` stünde
/// die Silhouette in der Luft, und mit mittiger senkrechter Ausrichtung
/// verschwände die Häuserzeile unten aus dem Bild. Siehe
/// [libraryIllustrationTransform].
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Das Koordinatensystem aller vier Zeichnungen, `viewBox="0 0 240 280"`.
const Size libraryIllustrationViewBox = Size(240, 280);

/// Die Städte mit eigener Silhouette, in der Reihenfolge der Zweige.
///
/// Alles andere fällt auf die allgemeine Zeichnung. Als Konstante, damit ein
/// Test die Zahl drei festnagelt: wer eine vierte hinzufügt, ohne sie hier
/// einzutragen, zeichnet sie nie.
const List<String> libraryIllustratedCities = <String>[
  'muenchen',
  'rom',
  'regensburg',
];

/// Wie das Bild in [size] gesetzt wird: erst verschieben, dann skalieren.
///
/// Gibt den Maßstab und den Ursprung zurück, damit ein Test die Rechnung
/// prüfen kann, ohne zu zeichnen. `slice` ist der **größere** Maßstab,
/// `xMidYMax` mittig und unten.
({double scale, Offset origin}) libraryIllustrationTransform(Size size) {
  final double scale = <double>[
    size.width / libraryIllustrationViewBox.width,
    size.height / libraryIllustrationViewBox.height,
  ].reduce((double a, double b) => a > b ? a : b);
  return (
    scale: scale,
    origin: Offset(
      (size.width - libraryIllustrationViewBox.width * scale) / 2,
      size.height - libraryIllustrationViewBox.height * scale,
    ),
  );
}

/// Zeichnet die Silhouette von [cityKey] in [size].
///
/// [dark], [mid] und [light] sind `colorDk`, `color` und `colorLt` der
/// Stadtpalette. Der Rückfall der Quelle auf `#0E1A2A`, `#1A4A6E` und
/// `#4898C0` (`:245-247`) ist hier **nicht** nachgebaut: dort greift er, wenn
/// eine Farbe `undefined` ist, und `WalletCityRecord` hat keine nullfähigen
/// Farbfelder. Ein Rückfall, der nie greifen kann, wäre toter Code.
void paintLibraryIllustration(
  Canvas canvas,
  Size size, {
  required String cityKey,
  required Color dark,
  required Color mid,
  required Color light,
}) {
  final ({double scale, Offset origin}) fit = libraryIllustrationTransform(
    size,
  );
  canvas
    ..save()
    ..clipRect(Offset.zero & size)
    ..translate(fit.origin.dx, fit.origin.dy)
    ..scale(fit.scale);

  switch (cityKey) {
    case 'muenchen':
      _paintMunich(canvas, dark, mid, light);
    case 'rom':
      _paintRome(canvas, dark, mid, light);
    case 'regensburg':
      _paintRegensburg(canvas, dark, mid, light);
    default:
      _paintGeneric(canvas, dark, mid, light);
  }

  canvas.restore();
}

// ── Gemeinsame Bausteine ─────────────────────────────────────────────────────

/// Der Himmel: ein senkrechter Verlauf über die ganze `viewBox`.
///
/// [midStop] ist die mittlere Stützstelle. München und Regensburg setzen sie
/// auf 50 Prozent, Rom und der Rückfall auf 55.
void _paintSky(
  Canvas canvas,
  Color dark,
  Color mid,
  Color light,
  double midStop,
) {
  final Rect box = Offset.zero & libraryIllustrationViewBox;
  canvas.drawRect(
    box,
    Paint()
      ..shader = ui.Gradient.linear(
        box.topCenter,
        box.bottomCenter,
        <Color>[dark, mid, light],
        <double>[0, midStop, 1],
      ),
  );
}

/// Der Schleier über der unteren Hälfte, der die Silhouette in die Farbe der
/// Stadt auslaufen lässt.
///
/// **Die erste Stützstelle ist durchsichtiges Schwarz und nicht durchsichtiges
/// `dark`.** In der Quelle steht dort `stopColor="transparent"`, und das ist
/// `rgba(0,0,0,0)`. Übernommen ist der Wert der Quelle. Ob man den Unterschied
/// sieht, hängt davon ab, ob der Verlauf vormultipliziert interpoliert; im
/// Browser tut er es nicht, in Skia meist doch. Der Wert bleibt deshalb der
/// abgeschriebene, statt hier eine Annahme einzubauen.
void _paintFade(
  Canvas canvas,
  Rect rect,
  Color dark,
  double midStop,
  int midAlpha,
) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        <Color>[const Color(0x00000000), dark.withAlpha(midAlpha), dark],
        <double>[0, midStop, 1],
      ),
  );
}

/// Ein Mondhof: ein oder zwei weiche Kreise oben rechts.
void _paintMoon(
  Canvas canvas,
  Offset center,
  double outerRadius,
  Color outerColor, {
  double? innerRadius,
  Color? innerColor,
}) {
  canvas.drawCircle(center, outerRadius, Paint()..color = outerColor);
  if (innerRadius != null && innerColor != null) {
    canvas.drawCircle(center, innerRadius, Paint()..color = innerColor);
  }
}

/// Ein Streckenzug aus flachen Koordinatenpaaren, geschlossen und gefüllt.
///
/// Die Dachlinien der Quelle sind lange `path`-Angaben aus lauter `L`-Befehlen.
/// Als flache Liste geschrieben bleiben sie mit der Quelle vergleichbar, ohne
/// dass jede Ecke eine eigene Zeile Dart kostet.
void _paintPolygon(Canvas canvas, List<double> points, Color color) {
  assert(points.length.isEven, 'Koordinatenpaare, also gerade Anzahl.');
  final Path path = Path()..moveTo(points[0], points[1]);
  for (var i = 2; i < points.length; i += 2) {
    path.lineTo(points[i], points[i + 1]);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Ein Turmfenster: ein Rechteck mit vollständig runden Enden.
void _paintWindow(
  Canvas canvas,
  double x,
  double y,
  double width,
  double height,
  double radius,
  Color color,
) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      Radius.circular(radius),
    ),
    Paint()..color = color,
  );
}

/// Eine dünne Linie in der hellen Farbe: Turmspitzen und Kreuzbalken.
void _paintStroke(Canvas canvas, Offset from, Offset to, Color color) {
  canvas.drawLine(
    from,
    to,
    Paint()
      ..color = color
      ..strokeWidth = 1.5,
  );
}

/// Ein Turmdach: zwei quadratische Kurven, `M … Q … Q … Z`.
void _paintDome(Canvas canvas, List<double> path, Color color) {
  assert(path.length == 10, 'Start plus zwei Kurven mit je zwei Punkten.');
  canvas.drawPath(
    Path()
      ..moveTo(path[0], path[1])
      ..quadraticBezierTo(path[2], path[3], path[4], path[5])
      ..quadraticBezierTo(path[6], path[7], path[8], path[9])
      ..close(),
    Paint()..color = color,
  );
}

// ── München, `screen-wallet.jsx:249-300` ─────────────────────────────────────

void _paintMunich(Canvas canvas, Color dark, Color mid, Color light) {
  _paintSky(canvas, dark, mid, light, 0.5);
  _paintMoon(
    canvas,
    const Offset(190, 55),
    14,
    const Color(0x26FFDC64),
    innerRadius: 8,
    innerColor: const Color(0x33FFDC64),
  );

  // Die beiden Türme der Frauenkirche. Der rechte steht acht Pixel tiefer und
  // ist entsprechend kürzer; die Quelle setzt beide Zahlen einzeln.
  _paintTower(canvas, dark, light, left: 55, top: 110, height: 170);
  _paintTower(canvas, dark, light, left: 153, top: 118, height: 162);

  // Der linke Turm trägt zusätzlich einen Lichtreflex auf der Kuppel, der
  // rechte nicht. Auch das ist die Quelle und keine Vereinfachung.
  _paintDome(canvas, const <double>[
    65,
    110,
    62,
    80,
    71,
    55,
    77,
    75,
    77,
    110,
  ], const Color(0x0DFFFFFF));

  // Das Rathaus in der Mitte, `:295-301`.
  canvas
    ..drawRect(
      const Rect.fromLTWH(105, 160, 30, 120),
      Paint()..color = dark.withAlpha(0xEE),
    )
    ..drawRect(const Rect.fromLTWH(105, 152, 30, 10), Paint()..color = dark)
    ..drawRect(const Rect.fromLTWH(105, 143, 7, 10), Paint()..color = dark)
    ..drawRect(const Rect.fromLTWH(114, 143, 7, 10), Paint()..color = dark)
    ..drawRect(const Rect.fromLTWH(124, 143, 7, 10), Paint()..color = dark);
  _paintPolygon(canvas, const <double>[105, 143, 135, 143, 120, 122], dark);
  _paintStroke(canvas, const Offset(120, 122), const Offset(120, 108), light);
  _paintStroke(canvas, const Offset(115, 114), const Offset(125, 114), light);

  _paintPolygon(canvas, const <double>[
    14,
    200,
    14,
    220,
    35,
    220,
    35,
    190,
    45,
    190,
    50,
    182,
    55,
    190,
    55,
    220,
    89,
    220,
    89,
    205,
    96,
    200,
    103,
    205,
    105,
    220,
    151,
    220,
    151,
    205,
    158,
    200,
    167,
    205,
    185,
    220,
    226,
    220,
    226,
    200,
    240,
    200,
    240,
    280,
    14,
    280,
  ], dark);

  _paintFade(canvas, const Rect.fromLTWH(14, 160, 226, 120), dark, 0.6, 0xBB);
}

/// Ein Kirchturm mit vier Fenstern, Kuppelsockel, Kuppel und Kreuz.
///
/// Beide Türme der Frauenkirche sind bis auf ihren Ursprung gleich gebaut, und
/// die Quelle schreibt sie zweimal aus. Hier stehen sie einmal, mit den drei
/// Zahlen, die sich unterscheiden.
void _paintTower(
  Canvas canvas,
  Color dark,
  Color light, {
  required double left,
  required double top,
  required double height,
}) {
  final double center = left + 16;
  canvas.drawRect(Rect.fromLTWH(left, top, 32, height), Paint()..color = dark);
  // Vier Fenster in zwei Reihen. Die untere Reihe ist blasser, `0.12` gegen
  // `0.15`.
  for (final (double dy, Color color) row in <(double, Color)>[
    (18, const Color(0x26FFDC78)),
    (40, const Color(0x1FFFDC78)),
  ]) {
    _paintWindow(canvas, left + 5, top + row.$1, 9, 13, 4.5, row.$2);
    _paintWindow(canvas, left + 18, top + row.$1, 9, 13, 4.5, row.$2);
  }
  canvas.drawOval(
    Rect.fromCenter(center: Offset(center, top), width: 36, height: 14),
    Paint()..color = dark.withAlpha(0xCC),
  );
  // `M 53 110 Q 47 76 71 50 Q 95 76 89 110 Z` beim linken Turm, dieselben
  // Abstände beim rechten (`M 151 118 Q 145 84 169 58 Q 193 84 187 118 Z`).
  // Die Kuppel ist nicht symmetrisch zur Turmmitte: sie greift links zwei
  // Pixel über den Schaft hinaus und rechts zwei darüber hinaus, und der
  // Scheitel sitzt genau auf der Mitte.
  _paintDome(canvas, <double>[
    left - 2,
    top,
    left - 8,
    top - 34,
    center,
    top - 60,
    center + 24,
    top - 34,
    center + 18,
    top,
  ], dark);
  _paintStroke(
    canvas,
    Offset(center, top - 60),
    Offset(center, top - 74),
    light,
  );
  _paintStroke(
    canvas,
    Offset(center - 5, top - 68),
    Offset(center + 5, top - 68),
    light,
  );
}

// ── Rom, `screen-wallet.jsx:302-328` ─────────────────────────────────────────

void _paintRome(Canvas canvas, Color dark, Color mid, Color light) {
  _paintSky(canvas, dark, mid, light, 0.55);
  _paintMoon(
    canvas,
    const Offset(185, 60),
    18,
    const Color(0x1FFFC850),
    innerRadius: 10,
    innerColor: const Color(0x2EFFC850),
  );

  // Der Körper des Kolosseums.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 160, 180, 80),
      const Radius.circular(4),
    ),
    Paint()..color = dark,
  );

  // Neun Bögen in der unteren Reihe, neun Rundfenster darüber, elf Zinnen
  // oben. Die Zahlen und die Abstände stehen so in der Quelle; die drei
  // Schleifen sind dort `[0,…,8].map` und `[0,…,10].map`.
  final Paint archPaint = Paint()..color = mid.withValues(alpha: 0.2);
  final Paint windowPaint = Paint()..color = mid.withValues(alpha: 0.18);
  for (var i = 0; i < 9; i++) {
    final double x = 36 + i * 18;
    canvas.drawPath(
      Path()
        ..moveTo(x, 195)
        ..lineTo(x, 215)
        ..quadraticBezierTo(x + 9, 210, x + 18, 215)
        ..lineTo(x + 18, 195)
        ..close(),
      archPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(38 + i * 18, 168, 14, 18),
        const Radius.circular(7),
      ),
      windowPaint,
    );
  }
  for (var i = 0; i < 11; i++) {
    canvas.drawRect(
      Rect.fromLTWH(32 + i * 16, 155, 10, 8),
      Paint()..color = dark,
    );
  }

  canvas.drawRect(const Rect.fromLTWH(30, 238, 180, 42), Paint()..color = dark);
  _paintFade(canvas, const Rect.fromLTWH(0, 150, 240, 130), dark, 0.55, 0xAA);
}

// ── Regensburg, `screen-wallet.jsx:330-357` ──────────────────────────────────

void _paintRegensburg(Canvas canvas, Color dark, Color mid, Color light) {
  _paintSky(canvas, dark, mid, light, 0.5);

  // Die zwei Domtürme: schmal, spitz, ohne Fenster. Kein Mond.
  _paintSpire(canvas, dark, light, left: 70, top: 130, height: 130);
  _paintSpire(canvas, dark, light, left: 152, top: 138, height: 122);

  // Die Steinerne Brücke: ein Riegel mit elf Bögen darunter und dem Wasser
  // dahinter.
  canvas.drawRect(const Rect.fromLTWH(14, 218, 212, 40), Paint()..color = dark);
  final Paint archPaint = Paint()..color = mid.withValues(alpha: 0.25);
  for (var i = 0; i < 11; i++) {
    final double x = 14 + i * 19;
    canvas.drawPath(
      Path()
        ..moveTo(x, 218)
        ..quadraticBezierTo(x + 9, 205, x + 19, 218)
        ..close(),
      archPaint,
    );
  }
  canvas.drawRect(
    const Rect.fromLTWH(14, 240, 212, 40),
    Paint()..color = light.withAlpha(0x33),
  );
  _paintFade(canvas, const Rect.fromLTWH(0, 160, 240, 120), dark, 0.55, 0xAA);
}

/// Ein spitzer Turm mit Kreuz, ohne Kuppel und ohne Fenster.
void _paintSpire(
  Canvas canvas,
  Color dark,
  Color light, {
  required double left,
  required double top,
  required double height,
}) {
  final double center = left + 9;
  canvas.drawRect(Rect.fromLTWH(left, top, 18, height), Paint()..color = dark);
  // `M 66 130 L 88 130 L 79 95 Z` links, `M 148 138 L 170 138 L 161 103 Z`
  // rechts. **Die Basis der Spitze ist nicht symmetrisch:** sie greift links
  // vier Pixel über den Schaft hinaus und endet rechts genau an seiner Kante
  // (70 bis 88 beim linken, 152 bis 170 beim rechten Turm). Zweimal derselbe
  // Versatz, also die Quelle und kein Zufall eines Datensatzes.
  _paintPolygon(canvas, <double>[
    left - 4,
    top,
    left + 18,
    top,
    center,
    top - 35,
  ], dark);
  _paintStroke(
    canvas,
    Offset(center, top - 35),
    Offset(center, top - 52),
    light,
  );
  _paintStroke(
    canvas,
    Offset(center - 5, top - 45),
    Offset(center + 5, top - 45),
    light,
  );
}

// ── Der Rückfall, `screen-wallet.jsx:359-379` ────────────────────────────────

void _paintGeneric(Canvas canvas, Color dark, Color mid, Color light) {
  _paintSky(canvas, dark, mid, light, 0.55);
  _paintMoon(canvas, const Offset(185, 65), 14, const Color(0x26FFDC64));

  // Eine Dachlinie ohne Wahrzeichen: Giebel, Flachdächer, ein paar Spitzen.
  _paintPolygon(canvas, const <double>[
    14,
    220,
    14,
    190,
    30,
    190,
    30,
    175,
    40,
    175,
    40,
    165,
    46,
    155,
    52,
    165,
    52,
    175,
    65,
    175,
    65,
    188,
    80,
    188,
    80,
    172,
    90,
    172,
    96,
    160,
    102,
    172,
    112,
    172,
    112,
    195,
    128,
    195,
    128,
    178,
    140,
    178,
    145,
    165,
    150,
    178,
    162,
    178,
    162,
    185,
    175,
    185,
    175,
    170,
    185,
    170,
    190,
    158,
    195,
    170,
    210,
    170,
    210,
    190,
    226,
    190,
    226,
    220,
    240,
    220,
    240,
    280,
    14,
    280,
  ], dark);

  _paintFade(canvas, const Rect.fromLTWH(0, 155, 240, 125), dark, 0.55, 0xBB);
}

/// Die Illustration als Widget.
class LibraryCityIllustration extends StatelessWidget {
  /// Erzeugt die Illustration für [cityKey].
  const LibraryCityIllustration({
    required this.cityKey,
    required this.dark,
    required this.mid,
    required this.light,
    super.key,
  });

  /// Der Bandschlüssel, siehe `libraryCityKeyOf`.
  final String cityKey;

  /// `colorDk` der Stadtpalette.
  final Color dark;

  /// `color` der Stadtpalette.
  final Color mid;

  /// `colorLt` der Stadtpalette.
  final Color light;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LibraryIllustrationPainter(
      cityKey: cityKey,
      dark: dark,
      mid: mid,
      light: light,
    ),
    // `position: absolute; inset: 0`: die Zeichnung füllt ihren Kasten und
    // bringt keine eigene Größe mit.
    child: const SizedBox.expand(),
  );
}

class _LibraryIllustrationPainter extends CustomPainter {
  const _LibraryIllustrationPainter({
    required this.cityKey,
    required this.dark,
    required this.mid,
    required this.light,
  });

  final String cityKey;
  final Color dark;
  final Color mid;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) => paintLibraryIllustration(
    canvas,
    size,
    cityKey: cityKey,
    dark: dark,
    mid: mid,
    light: light,
  );

  @override
  bool shouldRepaint(_LibraryIllustrationPainter oldDelegate) =>
      oldDelegate.cityKey != cityKey ||
      oldDelegate.dark != dark ||
      oldDelegate.mid != mid ||
      oldDelegate.light != light;
}
