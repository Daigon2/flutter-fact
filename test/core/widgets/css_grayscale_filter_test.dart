import 'package:fact_app/core/widgets/css_grayscale_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// `cssGrayscaleColorMatrix`, die einzige Stelle, die CSS'
/// `filter: grayscale(<amount>)` nachbaut.
///
/// ## Warum diese Datei existiert, obwohl es einen Widget-Test gibt
///
/// `trophy_list_test.dart` prüft die gesperrte Trophäenkarte über echte
/// Bildpunkte, und genau das hat beim Bauen dieses Blocks eine Mutation
/// **nicht** gefangen: eine gesperrte Karte trägt ohnehin nur
/// themenneutrale Töne (`FactColors.border`, `.surface3`), die schon vor
/// jeder Graustufe kaum gesättigt sind. Der Farbabstand zwischen einer
/// **offenen** (bunten, stufengefärbten) und einer **gesperrten** Karte ist so
/// groß, dass ein auf 0 gesetzter Graustufenbetrag am Vergleichspunkt der
/// gesperrten Karte kaum etwas ändert und die Bildpunkt-Zusicherung trotzdem
/// grün bleibt. Diese Datei prüft deshalb die Umrechnung selbst, unabhängig
/// vom Bildschirm, an dem sie hängt.
void main() {
  test('amount 0 ist die Einheitsmatrix je Kanal (kein Effekt)', () {
    final List<double> matrix = cssGrayscaleColorMatrix(0);

    // R' = R, G' = G, B' = B, A' = A.
    expect(matrix, <double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  });

  test('amount 1 liefert für alle drei Kanäle dieselben Luminanzgewichte', () {
    final List<double> matrix = cssGrayscaleColorMatrix(1);

    const List<double> luminanceRow = <double>[0.2126, 0.7152, 0.0722, 0, 0];
    expect(matrix.sublist(0, 5), luminanceRow);
    expect(matrix.sublist(5, 10), luminanceRow);
    expect(matrix.sublist(10, 15), luminanceRow);
    expect(matrix.sublist(15, 20), <double>[0, 0, 0, 1, 0]);
  });

  test('amount 0.6 (die gesperrte Trophäenkarte) trifft die von Hand '
      'gerechneten Werte', () {
    // Von Hand nach der Spezifikationsformel gerechnet, unabhängig vom
    // Produktionscode: inv = 1 - 0.6 = 0.4.
    final List<double> matrix = cssGrayscaleColorMatrix(0.6);

    const double inv = 0.4;
    final List<double> expected = <double>[
      0.2126 + 0.7874 * inv, 0.7152 - 0.7152 * inv, 0.0722 - 0.0722 * inv, 0,
      0, //
      0.2126 - 0.2126 * inv, 0.7152 + 0.2848 * inv, 0.0722 - 0.0722 * inv, 0,
      0,
      0.2126 - 0.2126 * inv, 0.7152 - 0.7152 * inv, 0.0722 + 0.9278 * inv, 0,
      0,
      0, 0, 0, 1, 0,
    ];

    expect(matrix.length, 20);
    for (var i = 0; i < matrix.length; i++) {
      expect(matrix[i], closeTo(expected[i], 1e-9), reason: 'Index $i');
    }
  });

  test('Werte außerhalb von 0..1 werden geklemmt, nicht abgelehnt', () {
    expect(cssGrayscaleColorMatrix(-1), cssGrayscaleColorMatrix(0));
    expect(cssGrayscaleColorMatrix(2), cssGrayscaleColorMatrix(1));
  });

  test('eine Zwischenstufe liegt strikt zwischen den beiden Rändern', () {
    // Gegenprobe gegen eine Mutation, die den Betrag ignoriert und immer die
    // Einheitsmatrix oder immer die Luminanzmatrix zurückgibt.
    final List<double> zero = cssGrayscaleColorMatrix(0);
    final List<double> full = cssGrayscaleColorMatrix(1);
    final List<double> half = cssGrayscaleColorMatrix(0.5);

    expect(half, isNot(zero));
    expect(half, isNot(full));
  });
}
