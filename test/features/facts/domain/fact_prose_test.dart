import 'package:fact_app/features/facts/domain/fact_prose.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die zwei Textregeln, die zwei Features teilen.
///
/// `isRealProse` hat seine Tests weiter in `cited_text_test.dart`, wo es sie
/// immer hatte: die Akte bezieht die Funktion über den Wiederexport, und ein
/// zweiter Satz Tests für dieselbe Funktion wäre zwei Wahrheiten. Hier steht,
/// was mit dem Umzug **neu** öffentlich geworden ist.
void main() {
  group('factTextWithoutReferences', () {
    test('nimmt die Hochziffer samt Leerraum davor mit', () {
      expect(
        factTextWithoutReferences('Der Turm [3] wurde 1180 erwähnt.'),
        'Der Turm wurde 1180 erwähnt.',
      );
    });

    test('lässt keinen Leerraum vor einem Satzzeichen zurück', () {
      // Der gemessene Anlass für das `\s*` im Ausdruck: ohne es wurde aus
      // „Text [42]." ein „Text ." mit Leerzeichen vor dem Punkt.
      expect(factTextWithoutReferences('Text [42].'), 'Text.');
    });

    test('nimmt mehrstellige Ziffern als eine Referenz', () {
      expect(factTextWithoutReferences('A [12] B'), 'A B');
    });

    test('lässt Klammern ohne Ziffer stehen', () {
      // `[a]` ist keine Referenz, dieselbe Abgrenzung wie in `cited_text`.
      expect(factTextWithoutReferences('A [a] B'), 'A [a] B');
    });

    test('räumt doppelten Leerraum auf, der beim Entfernen entsteht', () {
      expect(factTextWithoutReferences('Wort  [1]  Wort'), 'Wort Wort');
    });

    test('trimmt eine Hochziffer am Ende weg', () {
      expect(factTextWithoutReferences('Ein Satz [7]'), 'Ein Satz');
    });

    test('null wird zur leeren Zeichenkette', () {
      expect(factTextWithoutReferences(null), '');
    });

    test('ein Text ohne Hochziffern bleibt, wie er ist', () {
      expect(factTextWithoutReferences('Nichts zu tun.'), 'Nichts zu tun.');
    });

    test('mehrere Hochziffern fallen alle', () {
      expect(factTextWithoutReferences('A [1] B [2] C [3]'), 'A B C');
    });
  });
}
