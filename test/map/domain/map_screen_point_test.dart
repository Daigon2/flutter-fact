import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Bildschirmpunkt des Kartenvertrags.
void main() {
  test('zwei gleiche Punkte sind gleich, und zwar wertweise', () {
    // **Nicht mit `const` gebaut.** Dart kanonisiert konstante Ausdrücke: ein
    // `expect(const MapScreenPoint(..., isInFrontOfCamera: true,), const MapScreenPoint(..., isInFrontOfCamera: true,))` wäre auch
    // dann grün, wenn `==` auf Identität reduziert wäre. Genau diese Mutation
    // hat in diesem Repository schon zweimal eine Suite überlebt.
    final MapScreenPoint a = MapScreenPoint(
      xInScreenPixels: 12.5 + 0.0,
      yInScreenPixels: 340.0 + 0.0,
      isInFrontOfCamera: true,
    );
    final MapScreenPoint b = MapScreenPoint(
      xInScreenPixels: 12.5 + 0.0,
      yInScreenPixels: 340.0 + 0.0,
      isInFrontOfCamera: true,
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
      isInFrontOfCamera: true,
    );

    expect(
      origin,
      isNot(
        const MapScreenPoint(
          xInScreenPixels: 11,
          yInScreenPixels: 20,
          isInFrontOfCamera: true,
        ),
      ),
    );
    expect(
      origin,
      isNot(
        const MapScreenPoint(
          xInScreenPixels: 10,
          yInScreenPixels: 21,
          isInFrontOfCamera: true,
        ),
      ),
    );
  });

  test('vertauschte Achsen sind ein anderer Punkt', () {
    // Die eine Verwechslung, die auf einer quadratischen Testfläche unsichtbar
    // wäre.
    expect(
      const MapScreenPoint(
        xInScreenPixels: 10,
        yInScreenPixels: 20,
        isInFrontOfCamera: true,
      ),
      isNot(
        const MapScreenPoint(
          xInScreenPixels: 20,
          yInScreenPixels: 10,
          isInFrontOfCamera: true,
        ),
      ),
    );
  });

  test('die Ausgabe nennt die Zahlen und die Einheit', () {
    // **Anders als `MapPosition`, und das ist begründet:**
    // `docs/engineering/security.md` §6 verbietet genaue **Standortangaben**
    // im Log. Ein Bildschirmpunkt ist ohne die Kamera, die ihn erzeugt hat,
    // nicht in einen Ort zurückzurechnen, und ohne die Zahlen wäre die Ausgabe
    // für die eine Diagnose wertlos, um die es hier geht.
    expect(
      const MapScreenPoint(
        xInScreenPixels: 12,
        yInScreenPixels: 34,
        isInFrontOfCamera: true,
      ).toString(),
      contains('12'),
    );
    expect(
      const MapScreenPoint(
        xInScreenPixels: 12,
        yInScreenPixels: 34,
        isInFrontOfCamera: true,
      ).toString(),
      contains('Bildschirmpixeln'),
    );
  });

  test('die Lage zur Kamera zählt für die Gleichheit mit', () {
    // **Nicht mit `const` gebaut**, aus demselben Grund wie oben: Dart
    // kanonisiert konstante Ausdrücke. Zwei Punkte, die sich **nur** in
    // diesem Feld unterscheiden, sind zwei verschiedene Aussagen über
    // dieselben Zahlen, und die teure davon ist die stille: ein `==`, das
    // dieses Feld vergisst, lässt einen gespiegelten Punkt als den echten
    // durchgehen.
    final MapScreenPoint inFront = MapScreenPoint(
      xInScreenPixels: 12.5 + 0.0,
      yInScreenPixels: 340.0 + 0.0,
      isInFrontOfCamera: true,
    );
    final MapScreenPoint mirrored = MapScreenPoint(
      xInScreenPixels: 12.5 + 0.0,
      yInScreenPixels: 340.0 + 0.0,
      isInFrontOfCamera: false,
    );

    expect(inFront, isNot(mirrored));
    // Kein Zufall und keine Kollision: `Object.hash` über drei Felder gegen
    // `Object.hash` über zwei ist der ganze Unterschied. Ohne diese Zeile
    // überlebt ein [hashCode], der das dritte Feld nicht mitnimmt.
    expect(inFront.hashCode, isNot(mirrored.hashCode));
  });

  test('die Ausgabe sagt, auf welcher Seite der Kamera der Punkt liegt', () {
    // Die eine Diagnose, für die dieses Feld gebaut ist, lautet „warum steht
    // da ein Ballon, wo keiner sein kann". Ein nackter Wahrheitswert würde sie
    // nicht beantworten.
    expect(
      const MapScreenPoint(
        xInScreenPixels: 12,
        yInScreenPixels: 34,
        isInFrontOfCamera: true,
      ).toString(),
      contains('vor der Kamera'),
    );
    expect(
      const MapScreenPoint(
        xInScreenPixels: 12,
        yInScreenPixels: 34,
        isInFrontOfCamera: false,
      ).toString(),
      contains('hinter der Kamera'),
    );
  });
}
