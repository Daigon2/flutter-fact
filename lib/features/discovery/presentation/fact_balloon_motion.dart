/// Die zwei Dinge, die sich an einem Ballon von Bild zu Bild ändern: sein
/// Drehwinkel und sein Auf-und-ab.
///
/// Beides steht hier und nicht im Widget, und der Grund ist bei der Drehung
/// zwingend: **der Winkel ist ein Zähler mit Gedächtnis.** Er wird aufsummiert
/// (`screen-map.jsx:2276-2278`) und beim Verlassen der Reichweite gelöscht
/// (`:2312`), beim erneuten Betreten beginnt er wieder bei 0. Ein Zustand, der
/// einen Neuaufbau des Widgets überleben muss, gehört nicht in dessen `build`.
///
/// Das Auf-und-ab braucht kein Gedächtnis, es ist eine reine Funktion der
/// verstrichenen Zeit. Es steht trotzdem daneben, weil beide dieselbe Frage
/// beantworten und dieselbe Uhr benutzen.
library;

import 'dart:math' as math;

import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:flutter/animation.dart';

// -----------------------------------------------------------------------------
// Drehung
// -----------------------------------------------------------------------------
//
// ## „Grad je Bild" ist ein Fehler der Quelle und wird nicht nachgebaut
//
// `screen-map.jsx:2208-2209` nennt die beiden Grenzen ausdrücklich
// „deg/frame", und `:2277` addiert sie einmal je `requestAnimationFrame`.
// Damit dreht derselbe Ballon auf einem 120-Hz-Gerät **doppelt so schnell**
// wie auf einem 60-Hz-Gerät. Das ist keine Absicht, die Quelle stellt die
// Frage gar nicht.
//
// Umgerechnet wird deshalb auf **Grad je Sekunde bei 60 Hz**, also das Tempo,
// das die PWA auf einem gewöhnlichen Gerät zeigt. **Das ist eine Wahl und
// keine Fundstelle.**
//
// Nebenbei, weil es beim Nachschlagen auffällt: der Kommentar bei `:2209`
// behauptet, `COIN_MAX_SPEED` werde „bei 18 m" erreicht. Die Formel erreicht
// ihr Maximum bei `t = 1`, also bei 0 Metern; bei 18 Metern sind es 13,6.

/// Wie viele Bilder je Sekunde die Umrechnung annimmt.
const double factSpinReferenceFramesPerSecond = 60;

/// Das langsamste Drehtempo, am Rand der Reichweite.
///
/// `screen-map.jsx:2208`: `COIN_MIN_SPEED = 0.12` Grad je Bild.
const double factSpinMinDegreesPerSecond =
    0.12 * factSpinReferenceFramesPerSecond;

/// Das schnellste Drehtempo, auf dem Fakt.
///
/// `screen-map.jsx:2209`: `COIN_MAX_SPEED = 18` Grad je Bild.
const double factSpinMaxDegreesPerSecond =
    18 * factSpinReferenceFramesPerSecond;

/// Der Exponent der Tempokurve (`screen-map.jsx:2275`).
const double factSpinExponent = 2.2;

/// Wie schnell sich ein Ballon mit dieser Betonung dreht, in Grad je Sekunde.
///
/// `screen-map.jsx:2275`:
/// `COIN_MIN_SPEED + (COIN_MAX_SPEED - COIN_MIN_SPEED) * Math.pow(t, 2.2)`.
double factSpinSpeedAt(double emphasis) =>
    factSpinMinDegreesPerSecond +
    (factSpinMaxDegreesPerSecond - factSpinMinDegreesPerSecond) *
        math.pow(emphasis, factSpinExponent);

/// Der Winkelzähler der Ballons.
///
/// **Kein Flutter, kein Riverpod, keine Uhr von außen.** Er bekommt die
/// verstrichene Zeit übergeben und ist deshalb ohne Widget und ohne Warten
/// prüfbar. Das ist der Punkt: „der Zähler summiert auf", „er überlebt einen
/// Neuaufbau" und „er wird beim Verlassen der Reichweite gelöscht" sind drei
/// verschiedene Zusicherungen, und keine davon ist an einem gezeichneten Bild
/// zu erkennen.
class FactBalloonSpin {
  /// Der aufgelaufene Winkel je Fakt, in Grad.
  final Map<String, double> _angles = <String, double>{};

  /// Der Winkel von [id] in Grad, oder 0, wenn er nicht mitläuft.
  double angleOf(String id) => _angles[id] ?? 0;

  /// Welche Fakten gerade mitlaufen. Nur für Tests.
  Set<String> get trackedIds => _angles.keys.toSet();

  /// Rechnet [seconds] Sekunden weiter.
  ///
  /// [points] ist die vollständige Liste derer, die gerade leben. Wer nicht
  /// darin steht, **verliert seinen Winkel**: die Quelle löscht ihn beim
  /// Verlassen der Reichweite (`screen-map.jsx:2312`), und beim erneuten
  /// Betreten beginnt die Drehung wieder bei 0. Ohne das Löschen setzte ein
  /// Ballon nach einem Spaziergang um den Block dort wieder an, wo er
  /// aufgehört hat, und stünde dabei schief.
  ///
  /// **Der Winkel wird nicht auf 360 Grad zurückgeholt.** Die Quelle tut es
  /// auch nicht, sichtbar ist es nicht, und ein Zähler, der irgendwo
  /// umschlägt, macht „er summiert auf" zu einer Aussage mit Sternchen.
  void advance(Iterable<FactProximityPoint> points, Duration elapsed) {
    final double seconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final Set<String> alive = <String>{};
    for (final FactProximityPoint point in points) {
      alive.add(point.id);
      _angles[point.id] =
          angleOf(point.id) + factSpinSpeedAt(point.emphasis) * seconds;
    }
    _angles.removeWhere((String id, double _) => !alive.contains(id));
  }
}

// -----------------------------------------------------------------------------
// Auf-und-ab
// -----------------------------------------------------------------------------

/// Die Dauer eines vollen Auf-und-ab.
///
/// `screen-map.jsx:2301`: `coinFloatNear 2.2s ease-in-out infinite`.
const Duration factBalloonFloatPeriod = Duration(milliseconds: 2200);

/// Wie weit das Hüpfen zu diesem Zeitpunkt fortgeschritten ist, 0 am Boden und
/// 1 im Scheitel.
///
/// **Ein Fortschritt und keine Pixelzahl, und das ist tragend.** An diesem
/// einen Wert hängen zwei Wirkungen: der Kopf steigt um
/// [factBalloonFloatRise], und der Bodenschatten schrumpft und verblasst
/// ([factBalloonNearShadowScaleX] und die beiden daneben). Die Quelle schaltet
/// `coinFloatNear` und `coinShadowNear` in derselben Verzweigung ein und
/// wieder aus (`screen-map.jsx:2300-2308`), beide 2,2 Sekunden lang. Zwei
/// getrennte Zahlen von hier bis zum Pinsel zu reichen wäre die Gelegenheit,
/// sie auseinanderlaufen zu lassen, und niemand sähe es außer dem Nutzer.
///
/// **Die Kurve ist zeichengenau dieselbe.** CSS setzt zwischen zwei
/// Schlüsselbildern `ease-in-out`, und das ist `cubic-bezier(0.42, 0, 0.58,
/// 1)`; Flutters [Curves.easeInOut] ist `Cubic(0.42, 0.0, 0.58, 1.0)`. Der
/// Verlauf gilt **je Abschnitt**, deshalb wird hier auf die halbe Periode
/// abgebildet und nicht auf die ganze.
///
/// **Nur der nächste Ballon bekommt das überhaupt zu sehen.** Das ist eine
/// nachgezogene Entscheidung der Quelle mit Begründung im Kommentar
/// (`screen-map.jsx:2217-2220`): vorher hüpften alle Marker, und auf dichten
/// Karten sahen Nutzer „dauerndes Gehuepfe".
double factBalloonFloatProgress(Duration elapsed) {
  final double period = factBalloonFloatPeriod.inMicroseconds.toDouble();
  final double phase = (elapsed.inMicroseconds % period) / period;
  final double segment = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  return Curves.easeInOut.transform(segment);
}
