import 'dart:ui' show Color;

/// Die Farben des Tutorial-Overlays, alle inline aus
/// `02_Frontend/app/screen-tour.jsx`.
///
/// ## Warum sie hier gebündelt stehen und nicht in `FactColors`
///
/// `FactColors` nimmt bewusst nur die Tokens aus `styles.css` auf; was die PWA
/// inline am Element setzt, bleibt beim Bauteil, das es benutzt (siehe
/// Abschnitt "Keine Schatten-Tokens" in `fact_colors.dart`). Das Overlay ist
/// aber kein Bauteil, sondern sechs, und [accent] taucht in vieren davon auf.
/// Sechs Kopien derselben Zeichenfolge wären genau der Fall, in dem später
/// niemand mehr erkennt, ob zwei gleiche Werte dasselbe **bedeuten** oder nur
/// zufällig gleich sind.
///
/// Deshalb: gebündelt, aber nur für dieses Overlay, und jede Zeile mit ihrer
/// Fundstelle. Kein Import von hier aus irgendwo anders hin.
abstract final class TourPalette {
  /// `#B83A2E`, das Rot des Tutorials.
  ///
  /// Es ist **nicht** `--red` (`#E8380D`) und auch kein anderes Token aus
  /// `styles.css`. Die Quelle setzt es an vier Stellen hart: Pfeilstrich
  /// (`screen-tour.jsx:36`), Leuchtring (`:83`), Schrittanzeige (`:480`) und
  /// aktiver Punkt (`:320`). Wer es gegen `--red` austauscht, ändert vier
  /// Stellen auf einmal und keine davon fällt einzeln auf.
  static const Color accent = Color(0xFFB83A2E);

  /// `rgba(15,13,10,0.82)`, der Verdunkler des Hero-Schritts,
  /// `screen-tour.jsx:349`.
  static const Color heroScrim = Color.fromRGBO(15, 13, 10, 0.82);

  /// `rgba(15,13,10,0.32)`, der Verdunkler des regulären Schritts,
  /// `screen-tour.jsx:442`. Deutlich heller, weil man die App darunter noch
  /// erkennen soll.
  static const Color stepScrim = Color.fromRGBO(15, 13, 10, 0.32);

  /// `rgba(15,13,10,0.55)`, Hintergrund von "Überspringen",
  /// `screen-tour.jsx:295`.
  static const Color skipBackground = Color.fromRGBO(15, 13, 10, 0.55);

  /// `white`, Titel des Hero-Schritts, `screen-tour.jsx:362`.
  static const Color heroTitle = Color(0xFFFFFFFF);

  /// `rgba(255,255,255,0.88)`, Fließtext des Hero-Schritts,
  /// `screen-tour.jsx:375`.
  static const Color heroBody = Color.fromRGBO(255, 255, 255, 0.88);

  /// `#F5C518`, die goldene Meta-Zeile, `screen-tour.jsx:386`.
  ///
  /// Wertgleich mit `--gold` und `--coin` im dunklen Theme. Trotzdem eigener
  /// Eintrag: die Quelle schreibt hier eine Zeichenfolge und greift nicht auf
  /// die Variable zu, und im hellen Theme trägt `--coin` einen **anderen**
  /// Wert (`#D4A820`). Ein Token an dieser Stelle wäre also nicht dieselbe
  /// Farbe, sondern eine, die sich beim Theme-Wechsel mitbewegt.
  static const Color heroMeta = Color(0xFFF5C518);

  /// `rgba(255,255,255,0.6)`, der Hinweis "Tipp irgendwo für weiter",
  /// `screen-tour.jsx:333`.
  static const Color tapHint = Color.fromRGBO(255, 255, 255, 0.6);

  /// `rgba(255,255,255,0.55)`, ein nicht aktiver Punkt der Reihe,
  /// `screen-tour.jsx:320`.
  static const Color inactiveDot = Color.fromRGBO(255, 255, 255, 0.55);

  /// `rgba(184,58,46,0.25)`, der Hof um den aktiven Punkt,
  /// `screen-tour.jsx:321`.
  static const Color activeDotGlow = Color.fromRGBO(184, 58, 46, 0.25);

  /// `rgba(255,255,255,0.78)`, die Glasblase, `screen-tour.jsx:469`.
  static const Color bubbleBackground = Color.fromRGBO(255, 255, 255, 0.78);

  /// `inset 0 0 0 0.5px rgba(255,255,255,0.6)`, die Innenkante der Blase,
  /// `screen-tour.jsx:474`.
  static const Color bubbleEdge = Color.fromRGBO(255, 255, 255, 0.6);

  /// `rgba(0,0,0,0.15)`, der Schlagschatten der Blase,
  /// `screen-tour.jsx:474`.
  static const Color bubbleShadow = Color.fromRGBO(0, 0, 0, 0.15);

  /// `#15171A`, die Überschrift in der Blase, `screen-tour.jsx:488`.
  static const Color bubbleTitle = Color(0xFF15171A);

  /// `#3A352F`, der Fließtext in der Blase, `screen-tour.jsx:499`.
  static const Color bubbleBody = Color(0xFF3A352F);

  /// `drop-shadow(0 2px 5px rgba(0,0,0,0.45))` am Pfeil,
  /// `screen-tour.jsx:47`.
  static const Color arrowShadow = Color.fromRGBO(0, 0, 0, 0.45);
}
