import 'package:fact_app/features/challenges/domain/hunt_arrow.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Richtungspfeil-Index zu einer Peilung, `screen-map.jsx:1056-1059`.
///
/// Index 0 ist Norden (nach oben), danach im Uhrzeigersinn in 45-Grad-
/// Schritten: 1 = 45° (Nordost), 2 = 90° (Ost), 4 = 180° (Süd), 7 = 315°
/// (Nordwest).
void main() {
  test('die acht Haupthimmelsrichtungen', () {
    expect(huntArrowIndexFor(0), 0);
    expect(huntArrowIndexFor(45), 1);
    expect(huntArrowIndexFor(90), 2);
    expect(huntArrowIndexFor(180), 4);
    expect(huntArrowIndexFor(315), 7);
  });

  test('360 Grad ergibt wieder 0, eine volle Umdrehung', () {
    expect(huntArrowIndexFor(360), 0);
  });

  test(
    'eine negative Peilung ergibt dasselbe wie ihr positives Äquivalent',
    () {
      // -45° zeigt in dieselbe Richtung wie 315° (-45 + 360 = 315).
      expect(huntArrowIndexFor(-45), huntArrowIndexFor(315));
      expect(huntArrowIndexFor(-45), 7);
    },
  );

  test('eine Peilung über 360 Grad ergibt dasselbe wie ihr Rest', () {
    // 405° ist eine volle Umdrehung plus 45° (405 - 360 = 45).
    expect(huntArrowIndexFor(405), huntArrowIndexFor(45));
    expect(huntArrowIndexFor(405), 1);
  });

  group('Grenzen zwischen zwei Pfeilen', () {
    test('22,5 Grad liegt genau zwischen 0 und 45 Grad, 45 gewinnt', () {
      // `Math.round` in JavaScript wie `.round()` in Dart runden ein
      // positives „,5" aufwärts, deshalb gewinnt hier der höhere Nachbar
      // (Index 1, 45°) und nicht der niedrigere (Index 0, 0°).
      expect(huntArrowIndexFor(22.5), 1);
    });

    test('67,5 Grad liegt genau zwischen 45 und 90 Grad, 90 gewinnt', () {
      // Dieselbe Regel wie oben: der höhere Nachbar gewinnt.
      expect(huntArrowIndexFor(67.5), 2);
    });
  });

  test('eine negative Peilung genau auf einer Pfeilgrenze nimmt den korrekten '
      'Pfeil, nicht den einer naiven Übersetzung ohne Normalisierung', () {
    // -22,5° ist dasselbe wie 337,5°, das genau zwischen dem Pfeil für
    // 315° (Index 7) und dem für 360°/0° (Index 0) liegt; der höhere
    // Nachbar gewinnt, hier also der Wrap-around auf Index 0.
    //
    // Dieser Fall steht hier zusätzlich zu den im Auftrag genannten, weil
    // er der einzige unter den erreichbaren Eingaben ist, an dem eine
    // Übersetzung ohne die `% 360`-Normalisierung sichtbar falsch würde:
    // `(-22.5 / 45).round()` rundet in Dart von Null weg zu `-1`, und
    // `-1 % 8` ergibt `7`, nicht `0`. Siehe die Herleitung in
    // `hunt_arrow.dart`.
    expect(huntArrowIndexFor(-22.5), 0);
  });
}
