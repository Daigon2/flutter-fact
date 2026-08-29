import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Bildschirmpunkt des Kartenvertrags.
void main() {
  test('zwei gleiche Punkte sind gleich, und zwar wertweise', () {
    // **Nicht mit `const` gebaut.** Dart kanonisiert konstante Ausdrücke: ein
    // `expect(const MapScreenPoint(...), const MapScreenPoint(...))` wäre auch
    // dann grün, wenn `==` auf Identität reduziert wäre. Genau diese Mutation
    // hat in diesem Repository schon zweimal eine Suite überlebt.
    final MapScreenPoint a = MapScreenPoint(
      xInScreenPixels: 12.5 + 0.0,
      yInScreenPixels: 340.0 + 0.0,
    );
    final MapScreenPoint b = MapScreenPoint(
      xInScreenPixels: 12.5 + 0.0,
      yInScreenPixels: 340.0 + 0.0,
    );

    expect(identical(a, b), isFalse, reason: 'wirklich zwei Objekte');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('beide Achsen zählen', () {
    // Ohne diese Prüfung überlebte ein `==`, das nur eine Achse vergleicht,
    // und die Ballons stünden alle in einer Spalte oder in einer Zeile.
    const MapScreenPoint origin = MapScreenPoint(
      xInScreenPixels: 10,
      yInScreenPixels: 20,
    );

    expect(
      origin,
      isNot(const MapScreenPoint(xInScreenPixels: 11, yInScreenPixels: 20)),
    );
    expect(
      origin,
      isNot(const MapScreenPoint(xInScreenPixels: 10, yInScreenPixels: 21)),
    );
  });

  test('vertauschte Achsen sind ein anderer Punkt', () {
    // Die eine Verwechslung, die auf einer quadratischen Testfläche unsichtbar
    // wäre.
    expect(
      const MapScreenPoint(xInScreenPixels: 10, yInScreenPixels: 20),
      isNot(const MapScreenPoint(xInScreenPixels: 20, yInScreenPixels: 10)),
    );
  });

  test('die Ausgabe nennt die Zahlen und die Einheit', () {
    // **Anders als `MapPosition`, und das ist begründet:**
    // `docs/engineering/security.md` §6 verbietet genaue **Standortangaben**
    // im Log. Ein Bildschirmpunkt ist ohne die Kamera, die ihn erzeugt hat,
    // nicht in einen Ort zurückzurechnen, und ohne die Zahlen wäre die Ausgabe
    // für die eine Diagnose wertlos, um die es hier geht.
    expect(
      const MapScreenPoint(xInScreenPixels: 12, yInScreenPixels: 34).toString(),
      contains('12'),
    );
    expect(
      const MapScreenPoint(xInScreenPixels: 12, yInScreenPixels: 34).toString(),
      contains('Bildschirmpixeln'),
    );
  });
}
