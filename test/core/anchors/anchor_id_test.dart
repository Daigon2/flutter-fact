import 'package:fact_app/core/anchors/anchor_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Wertetyp über dem Ankernamen.
void main() {
  group('AnchorId', () {
    test('zwei getrennt erzeugte Kennungen mit gleichem Namen sind gleich', () {
      // Der Umweg über `join` ist kein Zierrat. Dart kanonisiert Konstanten:
      // `expect(const AnchorId('x'), const AnchorId('x'))` vergleicht dasselbe
      // Objekt mit sich selbst und würde auch dann grün bleiben, wenn `==` auf
      // `identical` reduziert wäre. Erst `identical` als `false` macht den
      // folgenden Vergleich aussagekräftig. Muster aus
      // `test/features/identity/presentation/state/auth_city_test.dart:59`.
      const left = AnchorId('tab-wallet');
      final right = AnchorId(<String>['tab', 'wallet'].join('-'));

      expect(identical(left, right), isFalse);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });

    test('verschiedene Namen sind verschieden', () {
      const wallet = AnchorId('tab-wallet');
      const challenge = AnchorId('tab-challenge');

      expect(wallet, isNot(challenge));
    });

    test('taugt als Schlüssel in Map und Set', () {
      // Das ist die eigentliche Anforderung: die Registry schlägt über den
      // Namen nach, nicht über die Objektidentität. Ohne `hashCode` fände sie
      // eine getrennt erzeugte, gleichnamige Kennung nicht wieder.
      final registry = <AnchorId, String>{
        AnchorId(<String>['tab', 'wallet'].join('-')): 'gefunden',
      };

      expect(registry[const AnchorId('tab-wallet')], 'gefunden');
      expect(<AnchorId>{
        const AnchorId('coins'),
        AnchorId(<String>['coin', 's'].join()),
      }, hasLength(1));
    });

    test('ist kein AnchorId, was nur denselben Namen trägt', () {
      // Der Typ soll verhindern, dass eine beliebige Zeichenkette als Anker
      // durchgeht. Ohne die Typprüfung in `==` wäre das hier gleich.
      expect(const AnchorId('coins'), isNot('coins'));
    });

    test('toString nennt den Namen', () {
      // Der Name steht in jeder Assert-Meldung der Registry. Ein `Instance of
      // AnchorId` dort wäre wertlos.
      expect(const AnchorId('compass').toString(), contains('compass'));
    });
  });
}
