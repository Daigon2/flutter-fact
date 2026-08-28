import 'package:fact_app/app/onboarding/widgets/tour_bubble.dart';
import 'package:fact_app/app/onboarding/widgets/tour_highlight.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die beiden Rechenstellen der Verzierung: die Sättigungsmatrix der Glasblase
/// und die Maße des Leuchtrings.
///
/// Beide fallen ohne Test nicht auf. Eine vertauschte Zeile in der Matrix ist
/// eine Farbverschiebung, die ohne Referenzbild niemand bemerkt, und ein
/// falscher Eckradius sieht immer noch aus wie ein Ring.
void main() {
  group('Sättigung, `backdrop-filter: saturate(1.4)`', () {
    test('bei 1.0 kommt die Einheitsmatrix heraus', () {
      // Der wichtigste Einzelfall: eine Matrix, die bei "keine Änderung"
      // etwas ändert, ändert bei 1.4 garantiert das Falsche.
      expect(TourBubble.saturationMatrix(1), <double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0,
      ]);
    });

    test('bei 0.0 tragen alle drei Zeilen die Leuchtdichte-Gewichte', () {
      final matrix = TourBubble.saturationMatrix(0);

      for (var row = 0; row < 3; row++) {
        expect(matrix.sublist(row * 5, row * 5 + 3), <double>[
          0.213,
          0.715,
          0.072,
        ], reason: 'Zeile $row');
      }
    });

    test('jede Farbzeile summiert sich auf 1, egal wie stark gesättigt', () {
      // Damit bleibt Grau grau. Eine Zeile, deren Summe abweicht, hellt das
      // Bild auf oder dunkelt es ab, und das sähe wie ein falscher Verdunkler
      // aus statt wie ein Filterfehler.
      for (final amount in <double>[0, 0.5, 1, 1.4, 3]) {
        final matrix = TourBubble.saturationMatrix(amount);
        for (var row = 0; row < 3; row++) {
          expect(
            matrix.sublist(row * 5, row * 5 + 3).reduce((a, b) => a + b),
            closeTo(1, 1e-12),
            reason: 'Zeile $row bei $amount',
          );
        }
      }
    });

    test('die Alpha-Zeile bleibt unangetastet', () {
      expect(TourBubble.saturationMatrix(1.4).sublist(15), <double>[
        0,
        0,
        0,
        1,
        0,
      ]);
    });

    test('ab 1.0 werden die Nebendiagonalen negativ', () {
      // Das ist die Richtung, die `saturate` von `desaturate` unterscheidet.
      final matrix = TourBubble.saturationMatrix(TourBubble.saturation);

      expect(matrix[0], greaterThan(1));
      expect(matrix[1], lessThan(0));
      expect(matrix[2], lessThan(0));
    });
  });

  group('Der Leuchtring', () {
    test('umschließt das Ziel mit 5 Pixeln Luft', () {
      const target = Rect.fromLTWH(100, 200, 40, 30);

      expect(
        TourHighlight.ringRect(target),
        const Rect.fromLTWH(95, 195, 50, 40),
      );
    });

    test('ein quadratisches Ziel ergibt einen Kreis', () {
      // `min(w, h) / 2 + 2` bei gleichen Kanten heißt: der Radius ist größer
      // als die halbe Kante, die Ecken verschwinden also vollständig.
      const target = Rect.fromLTWH(0, 0, 30, 30);
      final ring = TourHighlight.ringRect(target);

      expect(TourHighlight.ringRadius(target), ring.width / 2 + 2);
      expect(TourHighlight.ringRadius(target), greaterThan(ring.height / 2));
    });

    test('ein breites Ziel ergibt eine Pille', () {
      // Genau der Fall der Tab-Knöpfe: rund 190 breit, rund 50 hoch.
      const target = Rect.fromLTWH(0, 0, 190, 50);
      final ring = TourHighlight.ringRect(target);

      expect(TourHighlight.ringRadius(target), ring.height / 2 + 2);
      expect(TourHighlight.ringRadius(target), lessThan(ring.width / 2));
    });

    test(
      'die Pulsation läuft zwischen den beiden Keyframes von index.html:52',
      () {
        // Der inline gesetzte `boxShadow` der Quelle (3px, 14px) ist nie
        // sichtbar, die Animation überschreibt ihn ab dem ersten Frame. Der
        // Ruhewert ist deshalb der 0%-Keyframe.
        expect(TourHighlight.restShadows.first.spreadRadius, 4);
        expect(TourHighlight.restShadows.last.blurRadius, 16);
        expect(TourHighlight.peakShadows.first.spreadRadius, 7);
        expect(TourHighlight.peakShadows.last.blurRadius, 22);
        expect(
          TourHighlight.peakShadows.last.offset,
          const Offset(0, 6),
          reason: 'der zweite Schatten wandert auch nach unten',
        );
      },
    );
  });
}
