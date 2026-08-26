import 'package:flutter/widgets.dart';

/// Schrift-Tokens aus `02_Frontend/app/styles.css`.
///
/// Die PWA arbeitet mit fünf Rollen, die als CSS-Klassen vergeben werden:
///
/// | CSS      | Familie        | Gewicht | Besonderheit          |
/// |----------|----------------|---------|-----------------------|
/// | `body`   | DM Sans        | 400     | Grundtext             |
/// | `.serif` | DM Sans        | 500     | betonter Lesetext     |
/// | `.h`     | Nunito         | 800     | Überschrift           |
/// | `.d`     | Nunito         | 900     | Auszeichnung          |
/// | `.display`| Nunito        | 900     | `letter-spacing` −.02em |
/// | `.mono`  | JetBrains Mono | 400     | Zahlen, Codes         |
///
/// Absichtlich ohne Schriftgrößen und ohne Farben. Größen stehen in der PWA
/// direkt am Element und werden beim Portieren des jeweiligen Screens von dort
/// übernommen. Eine erfundene globale Skala würde nur von den echten Werten
/// ablenken. Farben kommen aus `FactColors`.
abstract final class FactFont {
  static const display = 'Nunito';
  static const body = 'DMSans';
  static const mono = 'JetBrainsMono';
}

/// Die fünf Rollen als wiederverwendbare Basis. Konkrete Größe pro Verwendung
/// über `copyWith(fontSize: ...)` aus dem JSX-Wert setzen.
abstract final class FactTypography {
  /// `body`: Grundtext der App.
  static const bodyText = TextStyle(
    fontFamily: FactFont.body,
    fontWeight: FontWeight.w400,
  );

  /// `.serif`: betonter Lesetext, etwa im Reiseführer.
  static const bodyEmphasis = TextStyle(
    fontFamily: FactFont.body,
    fontWeight: FontWeight.w500,
  );

  /// `.h`: Überschriften.
  static const heading = TextStyle(
    fontFamily: FactFont.display,
    fontWeight: FontWeight.w800,
  );

  /// `.d`: Auszeichnungen, Labels, Buttons.
  static const emphasis = TextStyle(
    fontFamily: FactFont.display,
    fontWeight: FontWeight.w900,
  );

  /// `.display`: große Titel. `letter-spacing: -0.02em` wird in Flutter als
  /// absoluter Wert gesetzt, also abhängig von der Größe. Bei der Verwendung
  /// mitrechnen: `letterSpacing: fontSize * -0.02`.
  static const displayTitle = TextStyle(
    fontFamily: FactFont.display,
    fontWeight: FontWeight.w900,
  );

  /// `.mono`: Zahlen, Codes, Beitrittscodes.
  static const mono = TextStyle(
    fontFamily: FactFont.mono,
    fontWeight: FontWeight.w400,
  );

  /// `letter-spacing: -0.02em` von `.display` in Pixel umgerechnet.
  static double displayTracking(double fontSize) => fontSize * -0.02;
}
