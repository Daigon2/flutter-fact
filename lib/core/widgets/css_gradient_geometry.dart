import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Umrechnung der CSS-Gradienten-Geometrie in Flutters Alignment-Raum.
///
/// Lag bis Schritt 21 bei den Identity-Bildschirmen, mit dem Vermerk „sobald
/// ein zweiter Bildschirm dieselbe Umrechnung braucht, zieht diese Datei um".
/// Die Fakt-Akte braucht sie für den Hero-Verlauf (`screen-fact.jsx:269`) und
/// die Kategorie-Tönung (`:282`), und Regel 8 der `dependency-rules.md` lässt
/// sie das `presentation/` von `identity` nicht lesen. Damit ist die
/// Bedingung aus `docs/architecture/project-structure.md:200` erfüllt:
/// bewiesene Wiederverwendung, keine fachliche Bedeutung.

/// Anfang und Ende eines CSS-`linear-gradient(<angle>, …)` in Alignment-Koordinaten.
///
/// ## Die Formel
///
/// CSS zählt den Winkel im Uhrzeigersinn, `0deg` zeigt nach oben. In Flutters
/// Alignment-Raum zeigt x nach rechts und y nach **unten**, die Richtung ist
/// also `(sin θ, −cos θ)`. Gegenprobe: `180deg` ergibt `(0, 1)`, also nach
/// unten, und damit `topCenter → bottomCenter`.
///
/// Die Länge der Gradientenlinie ist in CSS so festgelegt, dass die Stops 0%
/// und 100% genau auf die Projektionen der beiden Ecken fallen:
/// `L = |W·sin θ| + |H·cos θ|`. Endpunkt in Pixeln vom Mittelpunkt ist also
/// `d · L/2`. Ein Pixelabstand `p` entspricht in Alignment-Einheiten `2p/W`
/// beziehungsweise `2p/H`, damit wird der Endpunkt zu
/// `(L·dx/W, L·dy/H)` und der Anfang zu dessen Gegenteil.
///
/// Werte außerhalb von −1..1 sind richtig und erwartet: bei einem schrägen
/// Verlauf liegen die Endpunkte außerhalb der Fläche.
///
/// [box] ist die Fläche, auf der der Verlauf gezeichnet wird. Ohne sie ist die
/// Umrechnung nicht möglich: Alignment-Einheiten sind in x und y verschieden
/// groß, der Winkel dagegen ist ein Winkel im Pixelraum.
({Alignment begin, Alignment end}) cssLinearGradientEnds({
  required double angleDegrees,
  required Size box,
}) {
  if (box.isEmpty) {
    // Ohne Fläche gibt es keine Richtung, die stimmt. Der senkrechte Verlauf
    // ist der Standardfall in CSS (`180deg`) und ein harmloser Notnagel.
    return (begin: Alignment.topCenter, end: Alignment.bottomCenter);
  }
  final radians = angleDegrees * math.pi / 180;
  final dx = math.sin(radians);
  final dy = -math.cos(radians);
  final length = (box.width * dx).abs() + (box.height * dy).abs();
  final end = Alignment(length * dx / box.width, length * dy / box.height);
  return (begin: -end, end: end);
}

/// Radien der Ellipse eines CSS-`radial-gradient(ellipse at …)` in Pixeln.
///
/// Die Ausdehnung ist der CSS-Standard `farthest-corner`: die Ellipse hat das
/// Seitenverhältnis der `farthest-side`-Ellipse und geht durch die entfernteste
/// Ecke. Deren Abstände zum Mittelpunkt sind genau die `farthest-side`-Radien,
/// also folgt aus `(rx_fs/rx)² + (ry_fs/ry)² = 1` bei gleichem Verhältnis der
/// Faktor `√2` für beide Radien. Das ist exakt, keine Näherung.
({double x, double y}) cssFarthestCornerEllipseRadii({
  required Alignment center,
  required Size box,
}) {
  final centerX = (center.x + 1) / 2 * box.width;
  final centerY = (center.y + 1) / 2 * box.height;
  return (
    x: math.sqrt2 * math.max(centerX, box.width - centerX),
    y: math.sqrt2 * math.max(centerY, box.height - centerY),
  );
}

/// Verzerrt einen kreisförmigen [RadialGradient] zu einer Ellipse.
///
/// Flutters `RadialGradient` ist kreisförmig, CSS kennt `ellipse`. Die
/// Verzerrung läuft über die lokale Matrix des Shaders: y wird um [scaleY] um
/// den Mittelpunkt gestreckt, x bleibt. Der Kreis mit Radius `rx` wird damit zu
/// einer Ellipse `rx × rx·scaleY`.
///
/// Bewusst über `setEntry` statt über `Matrix4.translate`/`scale`: das ist
/// dieselbe Abbildung `y' = scaleY·y + cy·(1 − scaleY)`, aber ohne die in
/// neueren Flutter-Versionen als veraltet markierten Methoden.
@immutable
class EllipticalGradientScale extends GradientTransform {
  /// [center] ist der Mittelpunkt des Verlaufs, [scaleY] das Verhältnis
  /// `ry / rx`.
  const EllipticalGradientScale({required this.center, required this.scaleY});

  /// Mittelpunkt, um den gestreckt wird.
  final Alignment center;

  /// Streckung in y, also `ry / rx`.
  final double scaleY;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final centerY = center.withinRect(bounds).dy;
    return Matrix4.identity()
      ..setEntry(1, 1, scaleY)
      ..setEntry(1, 3, centerY * (1 - scaleY));
  }

  @override
  bool operator ==(Object other) =>
      other is EllipticalGradientScale &&
      other.center == center &&
      other.scaleY == scaleY;

  @override
  int get hashCode => Object.hash(center, scaleY);
}
