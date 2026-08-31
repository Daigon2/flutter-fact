/// Emuliert CSS' `filter: grayscale(<amount>)` als Flutter-Farbmatrix.
///
/// Rein technisch, keine Geschäftsbedeutung: die erste Verwendung ist die
/// gesperrte Trophäe (`screen-profil.jsx:451`, `filter: 'grayscale(0.6)'`),
/// aber die Umrechnung selbst kennt keine Trophäe. Vorbild ist
/// `css_gradient_geometry.dart`, das dieselbe Rolle für CSS-Verläufe spielt.
library;

/// Die 4×5-Matrix für `ColorFilter.matrix`.
///
/// [amount] entspricht dem CSS-Parameter, `0` unverändert und `1` vollständig
/// entsättigt, Werte dazwischen mischen linear. Formel aus der CSS Filter
/// Effects Module Level 1-Spezifikation (Abschnitt `grayscale()`), mit den
/// Rec.-709-Luminanzgewichten `0.2126`/`0.7152`/`0.0722`.
///
/// Gegenprobe an den Rändern: bei `amount: 0` liefert jede Zeile die
/// Einheitsmatrix für ihren Kanal (`R' = R`, `G' = G`, `B' = B`), bei
/// `amount: 1` liefert jede Zeile dieselben drei Luminanzgewichte, das
/// Ergebnis ist also für alle drei Kanäle identisch, also grau.
List<double> cssGrayscaleColorMatrix(double amount) {
  final double a = amount.clamp(0, 1).toDouble();
  final double inv = 1 - a;
  return <double>[
    0.2126 + 0.7874 * inv,
    0.7152 - 0.7152 * inv,
    0.0722 - 0.0722 * inv,
    0,
    0,
    0.2126 - 0.2126 * inv,
    0.7152 + 0.2848 * inv,
    0.0722 - 0.0722 * inv,
    0,
    0,
    0.2126 - 0.2126 * inv,
    0.7152 - 0.7152 * inv,
    0.0722 + 0.9278 * inv,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
