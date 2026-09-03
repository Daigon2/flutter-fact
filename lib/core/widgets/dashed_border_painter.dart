/// Ein gestrichelter Rahmen, wie `border-style: dashed` in CSS.
///
/// ## Warum das in `core` liegt und nicht im Feature
///
/// Flutter hat keinen gestrichelten Rahmen. Die erste Stelle, die einen
/// brauchte, war der Beitritts-Knopf der Gruppen-Jagd
/// (`challenge_setup_view.dart`, Schritt 34), und dort stand der Maler
/// privat in der Datei. Am 03.09.2026 kam mit den Leerplätzen des
/// Bücherregals die zweite Stelle dazu, und ein zweites Mal dasselbe
/// hinzuschreiben ist genau das Muster, an dem dieses Repository sonst zu
/// suchen anfängt: gleiche Lücke, zwei Umschreibungen, die auseinanderlaufen
/// können, ohne dass ein Test es merkt.
///
/// `core` ist der richtige Ort und kein Verstoß gegen Regel 11: ein
/// gestrichelter Rahmen ist kein Fakt, kein Sammelzustand und keine Trophäe,
/// sondern eine Zeichentechnik, wie [CssGrayscaleFilter] daneben. Regel 8
/// wäre die Alternative im Weg: `collection` darf `challenges/presentation`
/// nicht lesen.
///
/// ## Strich und Lücke sind gewählt, nicht gemessen
///
/// CSS legt bei `dashed` **nicht** fest, wie lang Strich und Lücke sind, das
/// entscheidet der Browser. Die drei Pixel sind deshalb eine Wahl. Sie stehen
/// als Vorgabe hier, damit beide Aufrufstellen dieselbe treffen; wer einen
/// anderen Rhythmus braucht, setzt ihn am Aufruf und sieht dabei, dass er von
/// der gemeinsamen Vorgabe abweicht.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Malt einen gestrichelten Rahmen entlang der Kante des Kindes.
class DashedBorderPainter extends CustomPainter {
  /// Erzeugt einen Maler.
  const DashedBorderPainter({
    required this.color,
    this.borderRadius = BorderRadius.zero,
    this.strokeWidth = 1,
    this.dashLength = defaultDashLength,
    this.gapLength = defaultGapLength,
  });

  /// Die Vorgabelänge eines Strichs, siehe den Kopf dieser Datei.
  static const double defaultDashLength = 3;

  /// Die Vorgabelänge einer Lücke, siehe den Kopf dieser Datei.
  static const double defaultGapLength = 3;

  /// Die Farbe der Striche.
  final Color color;

  /// Die Ecken, auch ungleiche.
  final BorderRadius borderRadius;

  /// Die Strichbreite.
  final double strokeWidth;

  /// Die Länge eines Strichs.
  final double dashLength;

  /// Die Länge einer Lücke.
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    // Um eine halbe Strichbreite eingerückt: ein Strich sitzt mittig auf der
    // Linie, ohne das Einrücken läge die äußere Hälfte außerhalb des Kindes.
    // CSS legt den Rahmen ebenfalls in die Fläche des Elements.
    final Rect inner = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final Path path = Path()..addRRect(borderRadius.toRRect(inner));
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    for (final ui.PathMetric metric in path.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        final double end = start + dashLength;
        canvas.drawPath(
          metric.extractPath(start, end.clamp(0, metric.length)),
          paint,
        );
        start = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}
