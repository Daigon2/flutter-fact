import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/presentation/avatar/avatar_motion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wann der Avatar läuft, `02_Frontend/app/screen-map.jsx:2624-2634`.
///
/// Die Zahlen in den Erwartungen sind **ausgeschrieben** und lesen keine
/// Konstante der Produktion: eine Zusicherung, die dieselbe Konstante liest,
/// die sie prüft, hält jede Änderung für richtig (Muster 18).
void main() {
  // Ein fester Zeitpunkt statt `DateTime.now()`. Ein Test, der die Uhr des
  // Rechners liest, ist an einem langsamen Rechner ein anderer Test.
  final DateTime now = DateTime.utc(2026, 9, 4, 12);

  const MapPosition marienplatz = MapPosition(
    latitude: 48.1374,
    longitude: 11.5755,
  );

  /// Eine Position [meters] nördlich von [from].
  ///
  /// Ein Grad Breite sind rund 111.195 Meter bei einem Erdradius von
  /// 6.371.000 Metern, und genau den benutzt `MapPosition`.
  MapPosition northOf(MapPosition from, double meters) => MapPosition(
    latitude: from.latitude + meters / 111195,
    longitude: from.longitude,
  );

  group('avatarWalkUntil', () {
    test('die erste Ortung lässt die Figur stehen', () {
      // Ohne Vorgänger gibt es keine Strecke. Eine Figur, die beim ersten
      // GPS-Empfang losläuft, behauptet eine Bewegung, die niemand gemacht
      // hat.
      expect(avatarWalkUntil(current: marienplatz, now: now), isNull);
    });

    test('eine Bewegung über der Schwelle lässt sie drei Sekunden laufen', () {
      expect(
        avatarWalkUntil(
          current: northOf(marienplatz, 5),
          now: now,
          previous: marienplatz,
        ),
        DateTime.utc(2026, 9, 4, 12, 0, 3),
      );
    });

    test('eine Bewegung unter der Schwelle ändert nichts', () {
      expect(
        avatarWalkUntil(
          current: northOf(marienplatz, 0.5),
          now: now,
          previous: marienplatz,
        ),
        isNull,
      );
    });

    // **Eine Mutation an dieser Grenze überlebt, und sie ist gleichwertig.**
    // `<=` gegen `<` unterscheidet sich nur bei einer Entfernung von *exakt*
    // 1,5 Metern, und die ist nicht konstruierbar: `distanceInMetersTo`
    // rechnet die volle Haversine mit Sinus und Kosinus, und die Rundung
    // trifft die Zahl nicht. Gemessen am 04.09.2026: der exakte Meridianbogen
    // von 1,5 Metern ergibt 1,5000000003079498878, also knapp darüber.
    //
    // Damit gibt es keine Eingabe, die die beiden Fassungen trennt. Der Test
    // darunter prüft die Grenze so scharf, wie sie prüfbar ist; die Wahl `>`
    // statt `>=` bleibt durch die Quelle belegt und nicht durch eine Messung.
    // Notiert, weil eine überlebende Mutation ohne Erklärung beim nächsten
    // Lauf wie eine Lücke aussieht.
    test('genau auf der Schwelle läuft sie nicht', () {
      // `moved > 1.5` in der Quelle, also streng größer. GPS-Rauschen liegt
      // oft bei ein bis zwei Metern; eine Figur, die im Stehen läuft, ist die
      // auffälligere Störung.
      expect(
        avatarWalkUntil(
          current: northOf(marienplatz, 1.5),
          now: now,
          previous: marienplatz,
        ),
        isNull,
      );
    });

    test('knapp über der Schwelle läuft sie doch', () {
      // Das Gegenstück zum Test darüber. Erst beide zusammen legen die Grenze
      // fest; einer allein lässt offen, wo sie liegt.
      expect(
        avatarWalkUntil(
          current: northOf(marienplatz, 1.6),
          now: now,
          previous: marienplatz,
        ),
        DateTime.utc(2026, 9, 4, 12, 0, 3),
      );
    });

    test('eine weitere Bewegung stellt die drei Sekunden neu', () {
      final DateTime later = now.add(const Duration(seconds: 2));

      expect(
        avatarWalkUntil(
          current: northOf(marienplatz, 10),
          now: later,
          previous: northOf(marienplatz, 5),
          walkUntil: DateTime.utc(2026, 9, 4, 12, 0, 3),
        ),
        DateTime.utc(2026, 9, 4, 12, 0, 5),
        reason: 'Zwei Sekunden später plus drei, nicht die alten drei.',
      );
    });

    test('eine kleine Bewegung während des Laufens verkürzt es nicht', () {
      // Wer läuft und dessen Ortung einmal um einen halben Meter springt,
      // läuft weiter. Die Quelle ruft `clearTimeout` nur im Zweig über der
      // Schwelle.
      final DateTime walkUntil = DateTime.utc(2026, 9, 4, 12, 0, 3);

      expect(
        avatarWalkUntil(
          current: northOf(marienplatz, 0.5),
          now: now.add(const Duration(seconds: 1)),
          previous: marienplatz,
          walkUntil: walkUntil,
        ),
        walkUntil,
      );
    });

    test('eine Bewegung nach Süden zählt genauso', () {
      // Die Strecke ist ein Betrag. Ein Vorzeichenfehler in der Entfernung
      // würde nur in einer Richtung auffallen.
      expect(
        avatarWalkUntil(
          current: northOf(marienplatz, -5),
          now: now,
          previous: marienplatz,
        ),
        DateTime.utc(2026, 9, 4, 12, 0, 3),
      );
    });
  });

  group('avatarAnimationAt', () {
    test('ohne Zeitpunkt steht sie', () {
      expect(avatarAnimationAt(null, now), AvatarAnimation.idle);
    });

    test('vor dem Ablauf läuft sie', () {
      expect(
        avatarAnimationAt(now.add(const Duration(seconds: 3)), now),
        AvatarAnimation.walk,
      );
    });

    test('eine Zehntelsekunde vor dem Ablauf läuft sie noch', () {
      expect(
        avatarAnimationAt(
          now.add(const Duration(seconds: 3)),
          now.add(const Duration(milliseconds: 2900)),
        ),
        AvatarAnimation.walk,
      );
    });

    test('genau auf dem Ablauf steht sie', () {
      // Einschließend, damit das Laufen nicht einen Wimpernschlag länger
      // dauert als drei Sekunden.
      final DateTime walkUntil = now.add(const Duration(seconds: 3));
      expect(avatarAnimationAt(walkUntil, walkUntil), AvatarAnimation.idle);
    });

    test('nach dem Ablauf steht sie', () {
      expect(
        avatarAnimationAt(
          now.add(const Duration(seconds: 3)),
          now.add(const Duration(seconds: 4)),
        ),
        AvatarAnimation.idle,
      );
    });
  });

  group('Wertebereiche', () {
    test('die Figur kennt drei Animationen mit ihren JS-Namen', () {
      // Die Namen gehen wörtlich an `FactAvatar.setAnim`. Ein Tippfehler hier
      // ist eine Figur, die stehenbleibt, und keine Fehlermeldung.
      expect(
        AvatarAnimation.values.map((AvatarAnimation a) => a.jsName),
        <String>['idle', 'walk', 'wave'],
      );
    });

    test('es gibt zwei Fassungen der Figur, male ist die erste', () {
      expect(AvatarGender.values.map((AvatarGender g) => g.jsName), <String>[
        'male',
        'female',
      ]);
      expect(
        AvatarGender.values.first,
        AvatarGender.male,
        reason: 'Vorgabe der Quelle, solange es keine Wahl gibt.',
      );
    });
  });
}
