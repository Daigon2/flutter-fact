import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Größe der Kartenfläche, in Stilpixeln.
void main() {
  test('zwei gleiche Größen sind gleich, und zwar wertweise', () {
    // **Nicht mit `const` gebaut**, aus demselben Grund wie in
    // `map_screen_point_test.dart`: zwei gleich geschriebene `const`-Werte
    // sind in Dart dasselbe Objekt, und ein `expect` darauf prüfte nichts,
    // selbst wenn `==` auf `identical` reduziert wäre.
    final MapViewport a = MapViewport(
      widthInScreenPixels: 390.0 + 0.0,
      heightInScreenPixels: 844.0 + 0.0,
    );
    final MapViewport b = MapViewport(
      widthInScreenPixels: 390.0 + 0.0,
      heightInScreenPixels: 844.0 + 0.0,
    );

    expect(identical(a, b), isFalse, reason: 'wirklich zwei Objekte');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('jedes Feld zählt für die Gleichheit', () {
    const MapViewport base = MapViewport(
      widthInScreenPixels: 390,
      heightInScreenPixels: 844,
    );

    expect(
      base,
      isNot(
        const MapViewport(widthInScreenPixels: 391, heightInScreenPixels: 844),
      ),
    );
    expect(
      base,
      isNot(
        const MapViewport(widthInScreenPixels: 390, heightInScreenPixels: 845),
      ),
    );
  });

  test('vertauschte Breite und Höhe sind eine andere Größe', () {
    // Die eine Verwechslung, die auf einer quadratischen Fläche unsichtbar
    // wäre.
    expect(
      const MapViewport(widthInScreenPixels: 390, heightInScreenPixels: 844),
      isNot(
        const MapViewport(widthInScreenPixels: 844, heightInScreenPixels: 390),
      ),
    );
  });

  test('ungleiche Größen streuen verschieden', () {
    // Dieselbe Lücke wie bei `MapPositionRect`, am selben Tag von derselben
    // Review gefunden: `int get hashCode => 0` lief durch alle Proben dieser
    // Datei, weil keine von ihnen zwei Streuwerte verglich. Kollisionen sind
    // nach dem Dart-Vertrag erlaubt, deshalb sichert diese Probe nur zu, was
    // für **diese** beiden Beispiele gelten muss.
    final MapViewport one = MapViewport(
      widthInScreenPixels: 411,
      heightInScreenPixels: 914,
    );
    final MapViewport other = MapViewport(
      widthInScreenPixels: 411,
      heightInScreenPixels: 915,
    );

    expect(one == other, isFalse);
    expect(one.hashCode, isNot(other.hashCode));
  });

  test('die Ausgabe nennt die Zahlen und die Einheit', () {
    // Anders als `MapPosition`: eine Flächengröße ist keine Standortangabe,
    // `security.md` §6 betrifft sie nicht, und ohne die Zahlen wäre die
    // Ausgabe für die Diagnose wertlos, um die es hier geht.
    const MapViewport viewport = MapViewport(
      widthInScreenPixels: 390,
      heightInScreenPixels: 844,
    );

    expect(viewport.toString(), contains('390'));
    expect(viewport.toString(), contains('844'));
    expect(viewport.toString(), contains('Stilpixel'));
  });
}
