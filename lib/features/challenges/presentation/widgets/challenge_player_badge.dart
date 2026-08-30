/// Die beiden gezeichneten Abzeichen der Spielerwahl, `ChalSoloBadge`
/// (`02_Frontend/app/screen-challenge.jsx:1135-1165`) und `ChalGroupBadge`
/// (`:1167-1196`).
///
/// ## Warum gezeichnet und nicht als Emoji
///
/// Weil die Quelle sie zeichnet: zusammen 27 SVG-Formen, keine Bilddatei, kein
/// Zeichensatz. Ein Emoji an dieser Stelle wäre eine andere Optik, und die
/// beiden Kacheln sind das Erste, was der Nutzer auf dem Bildschirm sieht.
///
/// ## Die Zahlen sind Koordinaten eines `viewBox`, keine Pixel
///
/// Das Solo-Abzeichen zeichnet in `viewBox="0 0 52 60"`, das Gruppen-Abzeichen
/// in `viewBox="0 0 60 60"`. Beide werden auf `size * 0.78` skaliert
/// (`:1147`, `:1179`). Deshalb steht hier ein [CustomPainter] mit einer
/// Skalierung am Anfang und darunter die Formen mit **exakt** den Zahlen aus
/// der Quelle: so bleibt jede Zeile nachschlagbar.
///
/// ## Warum das Solo-Abzeichen unten anstößt
///
/// Der Rahmen ist 2 Pixel breit und `box-sizing: border-box` gilt global
/// (`styles.css:107-111`), die Zeichenfläche endet also 2 Pixel über der
/// Unterkante. `marginBottom: -2` (`:1147`) hebt das genau auf, `overflow:
/// hidden` beschneidet den Rest. Die Figur steht damit auf der Außenkante,
/// nicht auf der Innenkante.
library;

import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/core/widgets/css_gradient_geometry.dart';
import 'package:flutter/widgets.dart';

/// Ein Abzeichen mit fester Kantenlänge und rundem Rahmen.
class ChallengePlayerBadge extends StatelessWidget {
  /// Das Solo-Abzeichen, `:1135`.
  const ChallengePlayerBadge.solo({this.size = defaultSize, super.key})
    : _group = false;

  /// Das Gruppen-Abzeichen, `:1167`.
  const ChallengePlayerBadge.group({this.size = defaultSize, super.key})
    : _group = true;

  /// `size = 64`, der Vorgabewert beider Abzeichen.
  static const double defaultSize = 64;

  /// `borderRadius: 18`, `:1138` und `:1170`.
  static const double cornerRadius = 18;

  /// `border: '2px solid rgba(255,255,255,0.25)'`, `:1141` und `:1173`.
  static const double borderWidth = 2;

  /// Siehe [borderWidth].
  static const Color borderColor = Color.fromRGBO(255, 255, 255, 0.25);

  /// `inset 0 1px 0 rgba(255,255,255,0.25)`, `:1140` und `:1172`.
  static const Color innerHighlight = Color.fromRGBO(255, 255, 255, 0.25);

  /// Anteil der Kantenlänge, den die Figur einnimmt, `:1147` und `:1179`.
  static const double figureScale = 0.78;

  /// `linear-gradient(145deg, #A855F7, #7C3AC0)` am Gruppen-Abzeichen,
  /// `:1171`. Beide Farben sind Literale, kein Token.
  static const Color groupGradientFrom = Color(0xFFA855F7);

  /// Siehe [groupGradientFrom].
  static const Color groupGradientTo = Color(0xFF7C3AC0);

  /// `0 4px 0 #5B22A0` am Gruppen-Abzeichen, `:1172`.
  static const Color groupShadowSolid = Color(0xFF5B22A0);

  /// `0 8px 18px rgba(168,85,247,0.45)` am Gruppen-Abzeichen, `:1172`.
  static const Color groupShadowGlow = Color.fromRGBO(168, 85, 247, 0.45);

  /// Die Kantenlänge.
  final double size;

  final bool _group;

  @override
  Widget build(BuildContext context) {
    final FactColors colors = context.factColors;
    final ({Alignment begin, Alignment end}) ends = cssLinearGradientEnds(
      angleDegrees: 145,
      box: Size.square(size),
    );

    return DecoratedBox(
      // Die beiden äußeren Schatten liegen außerhalb der Beschneidung.
      // Reihenfolge umgekehrt zur Quelle: CSS zeichnet den ersten Schatten
      // vorne, Flutter den letzten.
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(cornerRadius)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _group ? groupShadowGlow : colors.stampGlow,
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
          BoxShadow(
            color: _group ? groupShadowSolid : colors.redDark,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(cornerRadius)),
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // `linear-gradient(145deg, …)`: CSS zählt im
                    // Uhrzeigersinn ab oben, 145° zeigt also nach rechts
                    // unten. Das ist **nicht** `topLeft → bottomRight`, das
                    // wären auf einem Quadrat 135°; die Umrechnung steht in
                    // `css_gradient_geometry.dart`.
                    gradient: LinearGradient(
                      begin: ends.begin,
                      end: ends.end,
                      colors: _group
                          ? const <Color>[groupGradientFrom, groupGradientTo]
                          : <Color>[colors.redLight, colors.red],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _BadgePainter(group: _group, size: size),
                ),
              ),
              // Die Lichtkante liegt über der Figur, wie in CSS: ein
              // `inset`-Schatten zeichnet über den Inhalt des Elements.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: const ColoredBox(color: innerHighlight),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(cornerRadius),
                    ),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zeichnet die Figuren beider Abzeichen.
class _BadgePainter extends CustomPainter {
  const _BadgePainter({required this.group, required this.size});

  final bool group;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    final double figure = size * ChallengePlayerBadge.figureScale;
    canvas.save();
    if (group) {
      // `alignItems: center`, `viewBox="0 0 60 60"`.
      canvas.translate((box.width - figure) / 2, (box.height - figure) / 2);
      canvas.scale(figure / 60);
      _paintGroup(canvas);
    } else {
      // `alignItems: flex-end` plus `marginBottom: -2` bei 2 Pixel Rahmen:
      // die Unterkante der Figur liegt genau auf der Außenkante.
      //
      // `viewBox="0 0 52 60"` in einem quadratischen Feld: SVG behält mit dem
      // Standardwert von `preserveAspectRatio` das Seitenverhältnis und
      // zentriert. Bei 52:60 bestimmt deshalb die Höhe die Skalierung, und
      // waagerecht bleibt links und rechts etwas Luft.
      final double scale = figure / 60;
      canvas.translate((box.width - 52 * scale) / 2, box.height - 60 * scale);
      canvas.scale(scale);
      _paintSolo(canvas);
    }
    canvas.restore();

    if (group) {
      _paintSparkles(canvas, box);
    } else {
      _paintDots(canvas, box);
    }
  }

  /// Die beiden Lichtpunkte des Solo-Abzeichens, `:1145-1146`.
  ///
  /// `position: absolute` bezieht sich in CSS auf die **Polsterkante** des
  /// nächsten positionierten Vorfahren, also auf die Innenseite des 2 Pixel
  /// breiten Rahmens. `top: 10` sind damit 12 Pixel von der Außenkante.
  void _paintDots(Canvas canvas, Size box) {
    final double unit = size / ChallengePlayerBadge.defaultSize;
    final double inset = ChallengePlayerBadge.borderWidth;
    canvas
      ..drawCircle(
        Offset((inset + 10 + 2.5) * unit, (inset + 10 + 2.5) * unit),
        2.5 * unit,
        Paint()..color = const Color.fromRGBO(255, 224, 102, 0.7),
      )
      ..drawCircle(
        Offset((inset + 18 + 1.5) * unit, (inset + 18 + 1.5) * unit),
        1.5 * unit,
        Paint()..color = const Color.fromRGBO(255, 224, 102, 0.5),
      );
  }

  /// Die beiden Sterne des Gruppen-Abzeichens, `:1177-1178`.
  ///
  /// In der Quelle das Zeichen `✦` in zwei Größen, gesetzt mit `top/right`
  /// beziehungsweise `bottom/left`. Dieselbe Polsterkante wie bei
  /// [_paintDots].
  void _paintSparkles(Canvas canvas, Size box) {
    final double unit = size / ChallengePlayerBadge.defaultSize;
    final double inset = ChallengePlayerBadge.borderWidth * unit;
    final TextPainter top = _sparkle(10 * unit);
    top.paint(
      canvas,
      Offset(box.width - inset - 9 * unit - top.width, inset + 8 * unit),
    );
    top.dispose();
    final TextPainter bottom = _sparkle(8 * unit);
    bottom.paint(
      canvas,
      Offset(inset + 8 * unit, box.height - inset - 10 * unit - bottom.height),
    );
    bottom.dispose();
  }

  TextPainter _sparkle(double fontSize) {
    return TextPainter(
      text: TextSpan(
        text: '✦',
        style: TextStyle(fontSize: fontSize, color: const Color(0xFFFFE066)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// `:1147-1162`, in `viewBox`-Koordinaten.
  void _paintSolo(Canvas canvas) {
    _circle(canvas, 26, 14, 9, 0xFFF5C9A0);
    // `M16 13 Q16 5 26 4 Q36 5 36 13`
    _cap(canvas, 16, 13, 5, 26, 4, 36, 13, 0xFF1A1208);
    _rect(canvas, 13, 12, 26, 4, 2, 0xFF1A1208);
    _rect(canvas, 11, 14, 30, 3, 1.5, 0xFF0A0806);
    _circle(canvas, 26, 10, 2, 0xFFF5C518);
    _rect(canvas, 13, 24, 26, 22, 6, 0xFFFFE066);
    _rect(canvas, 13, 24, 6, 22, 4, 0xFFF5C518);
    _rect(canvas, 33, 24, 6, 22, 4, 0xFFF5C518);
    _rect(canvas, 5, 26, 9, 16, 4.5, 0xFFFF6B3D);
    _rect(canvas, 38, 26, 9, 16, 4.5, 0xFFFF6B3D);
    _ellipse(canvas, 9, 43, 4, 3.5, 0xFFF5C9A0);
    _ellipse(canvas, 43, 43, 4, 3.5, 0xFFF5C9A0);
    _rect(canvas, 17, 46, 8, 14, 4, 0xFF2A2060);
    _rect(canvas, 27, 46, 8, 14, 4, 0xFF1E1850);
  }

  /// `:1179-1193`, in `viewBox`-Koordinaten.
  void _paintGroup(Canvas canvas) {
    _circle(canvas, 40, 18, 8, 0xFFF5C9A0);
    // `M32 17 Q32 10 40 9 Q48 10 48 17`
    _cap(canvas, 32, 17, 10, 40, 9, 48, 17, 0xFF1A1208);
    _rect(canvas, 29, 16, 22, 3, 1.5, 0xFF0A0806);
    _rect(canvas, 26, 26, 28, 22, 6, 0xFFE8380D);
    _rect(canvas, 26, 26, 6, 22, 3, 0xFFA82508);
    _rect(canvas, 48, 26, 6, 22, 3, 0xFFA82508);
    _circle(canvas, 20, 22, 9, 0xFFF5C9A0);
    // `M10 21 Q10 13 20 12 Q30 13 30 21`
    _cap(canvas, 10, 21, 13, 20, 12, 30, 21, 0xFF3B2506);
    _rect(canvas, 7, 20, 26, 3, 1.5, 0xFF2A1804);
    _rect(canvas, 5, 32, 30, 22, 6, 0xFFF5C518);
    _rect(canvas, 5, 32, 6, 22, 3, 0xFFC49A0A);
    _rect(canvas, 29, 32, 6, 22, 3, 0xFFC49A0A);
    _rect(canvas, 13, 34, 14, 10, 3, 0xFFFFE066);
  }

  void _circle(Canvas canvas, double cx, double cy, double r, int color) {
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Color(color));
  }

  void _ellipse(
    Canvas canvas,
    double cx,
    double cy,
    double rx,
    double ry,
    int color,
  ) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()..color = Color(color),
    );
  }

  void _rect(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    double radius,
    int color,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        Radius.circular(radius),
      ),
      Paint()..color = Color(color),
    );
  }

  /// Die Mütze: `M left leftY Q left controlY midX midY Q right controlY right
  /// rightY`.
  ///
  /// Alle drei Mützen der Quelle haben dieselbe Bauform: zwei quadratische
  /// Bögen über denselben Steuerpunkt-Y, die x-Werte der beiden Steuerpunkte
  /// sind die Endpunkte. [controlY] wird trotzdem übergeben und nicht aus
  /// [midY] errechnet: eine Formel, die dreimal zufällig passt, sieht wie eine
  /// Regel aus und ist keine.
  ///
  /// SVG schließt einen gefüllten Pfad selbst, deshalb [Path.close].
  void _cap(
    Canvas canvas,
    double left,
    double leftY,
    double controlY,
    double midX,
    double midY,
    double right,
    double rightY,
    int color,
  ) {
    final Path path = Path()
      ..moveTo(left, leftY)
      ..quadraticBezierTo(left, controlY, midX, midY)
      ..quadraticBezierTo(right, controlY, right, rightY)
      ..close();
    canvas.drawPath(path, Paint()..color = Color(color));
  }

  @override
  bool shouldRepaint(_BadgePainter oldDelegate) =>
      oldDelegate.group != group || oldDelegate.size != size;
}
