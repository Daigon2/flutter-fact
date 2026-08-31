import 'package:fact_app/map/domain/map_camera_horizon.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Horizont der geneigten Karte, und damit die Antwort auf „liegt dieser
/// Punkt vor der Kamera" (D-17).
///
/// **Die erwarteten Zahlen kommen aus der Gerätemessung und nicht aus der
/// Formel.** Das ist hier die tragende Entscheidung: eine Zusicherung gegen
/// die Konstante, die sie festnageln soll, prüft nichts
/// (`REBUILD_STATUS.md`, „Wie Tests hier blind werden", Muster 18). Die
/// Messnacht vom 30.08.2026 hat eine Leiter projiziert, deren Werte gegen
/// einen Fluchtwert laufen; dieser Fluchtwert **ist** der Horizont, und gegen
/// ihn wird hier gemessen.
///
/// Der Messaufbau, für alle Zahlen unten derselbe: Kartenfläche 1080 × 2400
/// Geräte-Pixel, Neigung 58 Grad, Skalierungsfaktor 2,625
/// (`REBUILD_STATUS.md`, „Die vier Gerätemessungen", Messung 3, und
/// „Ungefragter Fund A").
void main() {
  /// Höhe der gemessenen Kartenfläche, in Geräte-Pixeln.
  const double measuredHeight = 2400;

  /// Die Neigung, bei der gemessen wurde.
  const double measuredPitch = 58;

  /// Der gemessene Fluchtwert der Leiter, in Geräte-Pixeln.
  ///
  /// Die Leiter klemmt ihn zwischen zwei Ablesungen ein: 2000 km nach vorn
  /// ergibt −1047,95, 2000 km nach hinten −1053,83. Der Horizont liegt
  /// dazwischen, bei rund −1050,9.
  const double measuredHorizon = -1050.89;

  group('die Lage des Horizonts', () {
    test('trifft den am Gerät gemessenen Fluchtwert', () {
      // **Die eine Zusicherung, an der die Konstante 1,5 hängt.** Sie steht
      // gegen die Messung und nicht gegen die Konstante: ein Verhältnis von
      // 1,6 ergäbe −1199,3, ein Verhältnis von 1,4 ergäbe −899,8, und beides
      // liegt weit außerhalb der zwei Pixel Toleranz unten.
      //
      // Die Toleranz selbst ist begründet: die Leiter kann den Fluchtwert nur
      // einklemmen (−1047,95 bis −1053,83), also auf knapp sechs Pixel, und
      // zwei Pixel um die Mitte dieses Intervalls sind die Genauigkeit, die
      // die Messung hergibt. Sie ist nicht so weit, dass eine andere
      // Konstante hineinpasste.
      expect(
        cameraHorizonYInDevicePixels(
          viewportHeightInDevicePixels: measuredHeight,
          pitchInDegrees: measuredPitch,
        ),
        closeTo(measuredHorizon, 2),
      );
    });

    test('wächst mit der Flächenhöhe, nicht mit einer festen Zahl', () {
      // **Zwei Höhen statt einer**, aus demselben Grund, aus dem der
      // Platzierungstest der Ballons über zwei Skalierungsfaktoren läuft: mit
      // nur einer Höhe wäre die Formel durch eine beliebige Konstante zu
      // ersetzen, und der Test bliebe grün. Die halbe Höhe muss den halben
      // Wert ergeben, denn Bildmitte und Brennweite hängen beide linear an
      // der Höhe.
      final double full = cameraHorizonYInDevicePixels(
        viewportHeightInDevicePixels: measuredHeight,
        pitchInDegrees: measuredPitch,
      );
      final double half = cameraHorizonYInDevicePixels(
        viewportHeightInDevicePixels: measuredHeight / 2,
        pitchInDegrees: measuredPitch,
      );

      expect(half, closeTo(full / 2, 0.001));
      expect(half, closeTo(-524.77, 0.5), reason: 'nicht bloß proportional');
    });

    test('sinkt mit steigender Neigung, und zwar auf die vorhergesagten '
        'Zeilen', () {
      // Die Tabelle aus dem Kopfkommentar von `map_camera_horizon.dart`. Sie
      // ist gleichzeitig die Vorhersage für die eine offene Gerätemessung:
      // wer die Karte auf 30 Grad stellt und einen Punkt 2000 km voraus
      // projiziert, muss −5035 ablesen.
      double at(double pitch) => cameraHorizonYInDevicePixels(
        viewportHeightInDevicePixels: measuredHeight,
        pitchInDegrees: pitch,
      );

      expect(at(30), closeTo(-5035.4, 0.1));
      expect(at(45), closeTo(-2400, 0.1));
      expect(at(60), closeTo(-878.5, 0.1));
      // Monotonie, damit ein vertauschtes Vorzeichen in der Kotangente nicht
      // an drei einzelnen Zahlen vorbeikommt.
      expect(at(30), lessThan(at(45)));
      expect(at(45), lessThan(at(60)));
    });

    test('bei 90 Grad liegt er in der Bildmitte', () {
      // `cot(90°) = 0`. Erreichbar ist das nicht, die Karte klemmt die
      // Neigung selbst (`camera.dart:33-35`); die Zeile hält den Rand
      // trotzdem fest, damit dort keine Zahl entsteht, die nach Geometrie
      // aussieht.
      expect(
        cameraHorizonYInDevicePixels(
          viewportHeightInDevicePixels: measuredHeight,
          pitchInDegrees: 90,
        ),
        measuredHeight / 2,
      );
      expect(
        cameraHorizonYInDevicePixels(
          viewportHeightInDevicePixels: measuredHeight,
          pitchInDegrees: 120,
        ),
        measuredHeight / 2,
      );
    });
  });

  group('wenn es keinen Horizont gibt', () {
    test('liegt bei Neigung 0 alles vor der Kamera', () {
      // Keine Notlösung, sondern die richtige Antwort: eine senkrecht nach
      // unten blickende Kamera hat nichts hinter sich.
      expect(
        cameraHorizonYInDevicePixels(
          viewportHeightInDevicePixels: measuredHeight,
          pitchInDegrees: 0,
        ),
        double.negativeInfinity,
      );
    });

    test('gilt dasselbe für eine Fläche ohne Höhe', () {
      // Der Zustand vor dem ersten Layout. **Und ausdrücklich kein `NaN`:**
      // die Formel enthält `0 · ∞`, und ein `NaN` im Vergleich ist immer
      // `false`, aus „ich weiß es nicht" würde also lautlos „liegt hinter der
      // Kamera" und jeder Ballon verschwände.
      final double horizon = cameraHorizonYInDevicePixels(
        viewportHeightInDevicePixels: 0,
        pitchInDegrees: measuredPitch,
      );

      expect(horizon.isNaN, isFalse);
      expect(horizon, double.negativeInfinity);
      expect(
        liesInFrontOfCamera(
          yInDevicePixels: -99999,
          horizonYInDevicePixels: horizon,
        ),
        isTrue,
      );
    });

    test('eine negative Neigung fällt in denselben Zweig', () {
      expect(
        cameraHorizonYInDevicePixels(
          viewportHeightInDevicePixels: measuredHeight,
          pitchInDegrees: -1,
        ),
        double.negativeInfinity,
      );
    });
  });

  group('die Richtung des Vergleichs', () {
    test('die Bildschirmachse wächst nach unten, „vor der Kamera" ist das '
        'größere y', () {
      // Verdreht man das, verschwindet alles Sichtbare und die Geister
      // bleiben. Deshalb steht die Richtung als eigene Zusicherung da und
      // nicht nur als Nebenwirkung der Proben unten.
      expect(
        liesInFrontOfCamera(yInDevicePixels: 0, horizonYInDevicePixels: -1000),
        isTrue,
      );
      expect(
        liesInFrontOfCamera(
          yInDevicePixels: -2000,
          horizonYInDevicePixels: -1000,
        ),
        isFalse,
      );
    });

    test('genau auf dem Horizont zählt nicht mehr als davor', () {
      // Dort liegt der unendlich ferne Punkt, und ein Bodenpunkt erreicht ihn
      // nie.
      expect(
        liesInFrontOfCamera(
          yInDevicePixels: -1000,
          horizonYInDevicePixels: -1000,
        ),
        isFalse,
      );
    });
  });

  group('die gemessene Leiter, Zeile für Zeile', () {
    // **Das ist die eigentliche Probe dieser Datei.** Alle Werte sind am
    // 30.08.2026 am Gerät abgelesen (`REBUILD_STATUS.md`, Messung 3), und
    // keiner davon trägt sein Vorzeichen als Hinweis: die Leiter enthält
    // zwei Werte über 1500, von denen einer vor und einer hinter der Kamera
    // liegt, und fünf negative, von denen vier davor liegen. Wer „negativ
    // heißt hinter der Kamera" baut, fällt hier durch.
    final double horizon = cameraHorizonYInDevicePixels(
      viewportHeightInDevicePixels: measuredHeight,
      pitchInDegrees: measuredPitch,
    );

    bool inFront(double y) => liesInFrontOfCamera(
      yInDevicePixels: y,
      horizonYInDevicePixels: horizon,
    );

    test('jede Ablesung nach vorn zählt als vor der Kamera', () {
      for (final double y in <double>[
        1533.23,
        815.38,
        -215.73,
        -779.01,
        -991.74,
        -1038.86,
        -1047.95,
      ]) {
        expect(inFront(y), isTrue, reason: 'Ablesung $y');
      }
    });

    test('die Ablesungen jenseits des Umschlags zählen als dahinter', () {
      // Die Leiter nach hinten kippt zwischen 1 km und 5 km das Vorzeichen,
      // und ab dort liegt sie hinter der Kamera. Der Wert bei 2000 km,
      // −1053,83, ist der schärfste Fall der ganzen Messung: er liegt nur
      // rund vier Pixel jenseits des Horizonts, und der Gegenwert nach vorn
      // (−1047,95) nur rund zwei Pixel davor. Die Formel trennt die beiden,
      // und das ist die engste Trennung, die diese Messung hergibt.
      for (final double y in <double>[
        -3241.45,
        -1391.32,
        -1112.72,
        -1063.01,
        -1053.83,
      ]) {
        expect(inFront(y), isFalse, reason: 'Ablesung $y');
      }
    });

    test('die zwei nahen Ablesungen nach hinten liegen trotzdem davor', () {
      // **Die verwirrendste Zeile der Messung, und deshalb steht sie hier.**
      // 1774,76 und 3825,91 gehören zu Punkten, die vom Startpunkt der Probe
      // aus nach hinten liegen, von der **Kamera** aus aber noch davor: sie
      // sitzen weit unter dem Bildrand, nicht hinter der Augenebene. Eine
      // Formel, die stumpf „großes y heißt gespiegelt" prüft, käme hier
      // durch die andere Zeile und fiele über diese.
      expect(inFront(1774.76), isTrue);
      expect(inFront(3825.91), isTrue);
    });
  });
}
