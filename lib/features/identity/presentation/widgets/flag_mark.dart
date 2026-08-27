import 'package:flutter/widgets.dart';

/// Welche Flagge [FlagMark] zeichnet.
enum FlagKind {
  /// `FlagDE`, screen-auth.jsx:179-190.
  de,

  /// `FlagGB`, screen-auth.jsx:192-212.
  gb,
}

/// Die beiden Flaggen der Sprachauswahl, aus `screen-auth.jsx:179-212`.
///
/// Die Quelle zeichnet sie als Inline-SVG mit `viewBox="0 0 28 18"`. Deshalb
/// wird hier gemalt und kein Asset geladen: es gibt keins.
///
/// ## Das Seitenverhältnis ist nicht 3:2
///
/// Die Quelle rechnet `h = Math.round(size * 18 / 28)`. Bei `size: 30`, dem Wert
/// der Sprachauswahl, ergibt das 30 × 19, nicht 30 × 20. Der eingefrorene
/// Flutter-Port nimmt 30 × 20; das ist eine Abweichung von der Quelle und wird
/// hier nicht übernommen.
///
/// Die Zeichnung folgt der Quelle auch dort, wo sie vereinfacht: das rote
/// Andreaskreuz der britischen Flagge ist nicht wie beim Original gegenständig
/// versetzt, sondern liegt mittig auf dem weißen. So steht es im SVG.
class FlagMark extends StatelessWidget {
  /// Erzeugt eine Flagge mit der Breite [size].
  const FlagMark({required this.kind, required this.size, super.key});

  /// Breite des `viewBox`.
  static const double viewBoxWidth = 28;

  /// Höhe des `viewBox`.
  static const double viewBoxHeight = 18;

  /// Welche Flagge.
  final FlagKind kind;

  /// Breite in logischen Pixeln, entspricht `size` in der Quelle.
  final double size;

  /// `h = Math.round(size * 18 / 28)`.
  double get renderedHeight =>
      (size * viewBoxHeight / viewBoxWidth).roundToDouble();

  /// `r = size * 0.14`, als `borderRadius` am SVG-Element.
  double get cornerRadius => size * 0.14;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.all(Radius.circular(cornerRadius));
    return DecoratedBox(
      // Der Schatten liegt außerhalb des Clips, sonst schneidet ihn das
      // ClipRRect weg: `boxShadow: '0 1px 4px rgba(0,0,0,0.35)'`.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.35),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        // SVG beschneidet seinen Inhalt am `viewBox`; die Striche des
        // Andreaskreuzes ragen darüber hinaus.
        borderRadius: radius,
        child: CustomPaint(
          size: Size(size, renderedHeight),
          painter: _FlagPainter(kind: kind, width: size),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter({required this.kind, required this.width});

  final FlagKind kind;

  /// Die Breite in logischen Pixeln, also `size` aus der Quelle. Gebraucht für
  /// `rx`, das die Quelle aus `size` und nicht aus dem `viewBox` rechnet.
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Ab hier wird in `viewBox`-Einheiten gezeichnet, genau wie im SVG.
    //
    // Gleichmäßig skaliert, weil SVG das tut: `preserveAspectRatio` ist
    // standardmäßig `xMidYMid meet`. Die gerundete Höhe (19 bei size 30) ist
    // einen Drittelpixel kleiner als das gleichmäßige Verhältnis verlangt. Der
    // Überstand wird vom `ClipRRect` abgeschnitten, statt ihn als Rand
    // stehenzulassen: ein Rand wären zwei durchsichtige Streifen an den
    // Seitenkanten, und das sieht nach Fehler aus.
    final scale = size.width / FlagMark.viewBoxWidth;
    canvas.translate(0, (size.height - FlagMark.viewBoxHeight * scale) / 2);
    canvas.scale(scale);
    switch (kind) {
      case FlagKind.de:
        _paintGermany(canvas);
      case FlagKind.gb:
        _paintBritain(canvas);
    }
    canvas.restore();
  }

  void _paintGermany(Canvas canvas) {
    _fill(canvas, const Rect.fromLTWH(0, 0, 28, 6), const Color(0xFF1A1A1A));
    _fill(canvas, const Rect.fromLTWH(0, 6, 28, 6), const Color(0xFFDD0000));
    _fill(canvas, const Rect.fromLTWH(0, 12, 28, 6), const Color(0xFFFFCE00));
    // `<rect ... rx={r} stroke="rgba(255,255,255,0.15)" strokeWidth="0.8"/>`.
    // `rx` steht im SVG in viewBox-Einheiten, die Zahl ist dieselbe wie der
    // CSS-Radius des Elements. Bei `size: 30` liegt der gezeichnete Rand damit
    // minimal weiter innen als die Ecke des Clips. So steht es in der Quelle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 28, 18),
        Radius.circular(width * 0.14),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color.fromRGBO(255, 255, 255, 0.15),
    );
  }

  void _paintBritain(Canvas canvas) {
    const white = Color(0xFFFFFFFF);
    const red = Color(0xFFC8102E);
    _fill(canvas, const Rect.fromLTWH(0, 0, 28, 18), const Color(0xFF012169));
    _saltire(canvas, white, 5);
    _saltire(canvas, red, 2.5);
    _fill(canvas, const Rect.fromLTWH(11, 0, 6, 18), white);
    _fill(canvas, const Rect.fromLTWH(0, 6, 28, 6), white);
    _fill(canvas, const Rect.fromLTWH(12, 0, 4, 18), red);
    _fill(canvas, const Rect.fromLTWH(0, 7, 28, 4), red);
  }

  void _saltire(Canvas canvas, Color color, double strokeWidth) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawLine(Offset.zero, const Offset(28, 18), paint);
    canvas.drawLine(const Offset(28, 0), const Offset(0, 18), paint);
  }

  void _fill(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlagPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.width != width;
}
