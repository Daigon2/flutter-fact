import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// Die Geometrie des Tutorial-Pfeils, `02_Frontend/app/screen-tour.jsx:6-33`
/// und `:398-433`.
///
/// Eigene Klasse und kein Rechnen im Painter, aus einem Grund: die Punkte sind
/// die einzige Stelle des Overlays, an der ein Vorzeichenfehler kein sichtbares
/// Muster ergibt, sondern nur einen Pfeil, der ein bisschen falsch zeigt. Als
/// reine Funktion ist jeder einzelne Wert prüfbar, im Painter wäre nur das
/// gemalte Ergebnis prüfbar.
///
/// Alle Koordinaten sind relativ zur Bezugsfläche des `AnchorScope`, also
/// derselbe Raum, in dem `AnchorRegistry.rectOf` seine Rechtecke liefert.
@immutable
class TourArrowGeometry {
  const TourArrowGeometry._({
    required this.from,
    required this.to,
    required this.control1,
    required this.control2,
    required this.tipLeft,
    required this.tipRight,
  });

  /// Die Blase gilt für die Pfeilrechnung als 85 hoch, `screen-tour.jsx:399`.
  ///
  /// Das ist eine Annahme der Quelle und **keine** gemessene Höhe: die echte
  /// Blase ist so hoch, wie ihr Text sie macht. Übernommen wird die Annahme,
  /// nicht die Messung, weil der Pfeilanfang sonst bei jedem Sprachwechsel
  /// woanders säße als in der PWA.
  static const double bubbleHeight = 85;

  /// Die Blase gilt für die Pfeilrechnung als 260 breit,
  /// `screen-tour.jsx:400`. Das ist zugleich ihre `maxWidth`.
  static const double bubbleWidth = 260;

  /// Abstand des Pfeilanfangs von der Blasenkante, `screen-tour.jsx:418`.
  static const double bubbleGap = 4;

  /// Abstand des Pfeilendes von der Zielmitte, über die halbe längere
  /// Zielkante hinaus, `screen-tour.jsx:424`.
  ///
  /// Der Kommentar der Quelle rechnet mit "Ring-pad=10, +6 Luft" und passt
  /// damit weder zum Wert 18 noch zum tatsächlichen Ring-Pad von 5
  /// (`screen-tour.jsx:71`). Übernommen ist die Zahl, nicht die Rechnung.
  static const double ringClearance = 18;

  /// Länge der beiden Striche der Pfeilspitze, `screen-tour.jsx:28`.
  static const double tipLength = 14;

  /// Halber Öffnungswinkel der Pfeilspitze, `screen-tour.jsx:29-30`.
  static final double tipAngle = math.pi / 7;

  /// Wo der Pfeil aus der Blase austritt.
  final Offset from;

  /// Wo er endet, kurz vor dem Leuchtring.
  final Offset to;

  /// Erster Kontrollpunkt der kubischen Kurve.
  final Offset control1;

  /// Zweiter Kontrollpunkt. Er bestimmt zugleich die Richtung der Spitze.
  final Offset control2;

  /// Ein Schenkel der Pfeilspitze.
  final Offset tipLeft;

  /// Der andere Schenkel der Pfeilspitze.
  final Offset tipRight;

  /// Rechnet die Punkte für [target] aus, oder `null`, wenn es kein Ziel gibt.
  ///
  /// `null` ist der Degradationsfall und der ganze Grund, warum diese Funktion
  /// ein Rechteck und keine Ankerkennung nimmt: ohne Rechteck gibt es keinen
  /// Endpunkt (`screen-tour.jsx:423`), also keinen Pfeil. Die Blase wird
  /// trotzdem gezeichnet, dafür ist der Aufrufer zuständig.
  static TourArrowGeometry? forTarget({
    required Rect? target,
    required double bubbleTop,
    required double frameWidth,
    required double curve,
  }) {
    if (target == null) {
      return null;
    }

    final from = _from(
      target: target,
      bubbleTop: bubbleTop,
      frameWidth: frameWidth,
    );
    final to = _to(target: target, from: from);

    // Die Kurve, `screen-tour.jsx:7-19`. `nx`/`ny` ist die um 90 Grad gedrehte
    // Richtung, `off` der Ausschlag zur Seite. Das Vorzeichen von `curve`
    // entscheidet also, auf welcher Seite der Bogen liegt.
    final delta = to - from;
    final length = _nonZero(delta.distance);
    final normal = Offset(-delta.dy / length, delta.dx / length);
    final offset = length * curve * 0.55;

    final control1 = from + delta * 0.25 + normal * (offset * 0.85);
    final control2 = from + delta * 0.70 + normal * (offset * 1.10);

    // Die Spitze folgt der Tangente im Endpunkt, und die ist bei einer
    // kubischen Bézierkurve die Richtung vom zweiten Kontrollpunkt zum Ende.
    final tangentRaw = to - control2;
    final tangentLength = _nonZero(tangentRaw.distance);
    final tangent = tangentRaw / tangentLength;
    final cosA = math.cos(tipAngle);
    final sinA = math.sin(tipAngle);

    return TourArrowGeometry._(
      from: from,
      to: to,
      control1: control1,
      control2: control2,
      tipLeft: Offset(
        to.dx - tipLength * (tangent.dx * cosA - tangent.dy * sinA),
        to.dy - tipLength * (tangent.dy * cosA + tangent.dx * sinA),
      ),
      tipRight: Offset(
        to.dx - tipLength * (tangent.dx * cosA + tangent.dy * sinA),
        to.dy - tipLength * (tangent.dy * cosA - tangent.dx * sinA),
      ),
    );
  }

  /// Der Austrittspunkt an der Blase, `screen-tour.jsx:410-421`.
  ///
  /// Liegt das Ziel eher über oder unter der Blase, tritt der Pfeil oben oder
  /// unten aus, sonst seitlich. Das Kriterium ist ein Vergleich der Beträge,
  /// nicht ein Winkel: bei genau 45 Grad gewinnt die senkrechte Richtung, weil
  /// die Quelle `>=` schreibt.
  static Offset _from({
    required Rect target,
    required double bubbleTop,
    required double frameWidth,
  }) {
    final centerX = frameWidth / 2;
    final centerY = bubbleTop + bubbleHeight / 2;
    final dx = target.center.dx - centerX;
    final dy = target.center.dy - centerY;

    if (dy.abs() >= dx.abs()) {
      return Offset(
        centerX,
        dy > 0 ? bubbleTop + bubbleHeight + bubbleGap : bubbleTop - bubbleGap,
      );
    }
    return Offset(centerX + dx.sign * (bubbleWidth / 2 + bubbleGap), centerY);
  }

  /// Der Endpunkt, `screen-tour.jsx:423-433`.
  ///
  /// Er liegt auf der Geraden vom Austrittspunkt zur Zielmitte, aber um die
  /// halbe längere Zielkante plus [ringClearance] davor. Deshalb schneidet der
  /// Pfeil den Leuchtring nicht, egal wie groß das Ziel ist.
  static Offset _to({required Rect target, required Offset from}) {
    final halfMax = math.max(target.width, target.height) / 2 + ringClearance;
    final delta = target.center - from;
    return target.center - delta / _nonZero(delta.distance) * halfMax;
  }

  /// Wertgleichheit, damit `CustomPainter.shouldRepaint` sie benutzen kann.
  ///
  /// Ohne sie wäre jedes neu gerechnete Ergebnis ein anderes Objekt, und der
  /// Pfeil würde bei jedem Rebuild neu gemalt, auch wenn sich nichts bewegt
  /// hat.
  @override
  bool operator ==(Object other) =>
      other is TourArrowGeometry &&
      other.from == from &&
      other.to == to &&
      other.control1 == control1 &&
      other.control2 == control2 &&
      other.tipLeft == tipLeft &&
      other.tipRight == tipRight;

  @override
  int get hashCode =>
      Object.hash(from, to, control1, control2, tipLeft, tipRight);

  /// Pendant zum `|| 1` der Quelle: eine Länge von null würde durch null
  /// teilen. Praktisch tritt der Fall nur auf, wenn das Ziel genau auf dem
  /// Austrittspunkt sitzt.
  static double _nonZero(double value) => value == 0 ? 1 : value;
}
