/// Die Farben und Maße der Buchseite,
/// `02_Frontend/app/screen-wallet.jsx:1413-1824` (`WltBookPageView`).
///
/// ## Buchpapier ist ein eigener Satz Farben
///
/// `wltUseTok` (`:232-236`) definiert vier Werte, die es nur im Lesemodus
/// gibt: `bookBg`, `bookFooter`, `bookInk`, `bookInk2`. Sie stehen in keiner
/// CSS-Variable, weil sie kein anderer Bildschirm benutzt: es ist die Farbe
/// von altem Papier, und die soll nirgends sonst auftauchen. Dieselbe
/// Aufteilung wie in `library_look.dart`, deren Kopf sie begründet.
///
/// ## Ein rotes Dunkel, das aus dem Prototyp stammt
///
/// Der Lesemodus setzt sich drei eigene Marken-Konstanten (`:1562`):
///
/// ```js
/// const BRAND = '#E8380D', BRAND_LT = '#FF6B3D', BRAND_DK = '#B82707';
/// ```
///
/// Die ersten zwei sind `FactColors.red` und `FactColors.redLight`. Die dritte
/// **nicht**: `FactColors.redDark` ist `#A82508`. Nachgesehen, woher der
/// Unterschied kommt, und die Antwort ist eindeutig: `#B82707` ist
/// `--brand-dk` in den Entwurfsdateien des Reiseführers (`variants.html:15`,
/// `wallet-final.html:12`, `wallet-variants.html:12`), `#A82508` ist es in
/// `styles.css`, und jeder andere Bildschirm nimmt die CSS-Variable. Der
/// Reiseführer trägt also den Wert seines Prototyps weiter, während der Rest
/// der App umgestellt hat.
///
/// **Genommen wird trotzdem `#B82707`**, und der Grund ist nicht Parität um
/// ihrer selbst willen: derselbe Wert steht schon als dritte Stützstelle in
/// [libraryHeaderColors], weil er dort eine sichtbare Verlaufsfläche ist. Zwei
/// verschiedene Rot-Dunkel innerhalb eines Bildschirms wären der schlechtere
/// Zustand als eines, das um vier Prozent von der Variable abweicht.
/// Aufgenommen als Fund an der Quelle.
///
/// ## Deckkraft nach Ganzzahl
///
/// Wie in `library_look.dart`: CSS rechnet `rgba(…, 0.30)` als Bruch, Flutter
/// als Byte. `0.30 * 255 = 76,5 → 77 = 0x4D`.
library;

import 'package:flutter/material.dart';

/// Das Rot des Lesemodus, `BRAND` (`screen-wallet.jsx:1562`).
///
/// Gleich `FactColors.red`. Steht hier als Name, damit die drei Marken-Werte
/// des Bildschirms beieinander liegen und der abweichende dritte nicht wie ein
/// Versehen aussieht.
const Color libraryReaderBrand = Color(0xFFE8380D);

/// Das helle Rot, `BRAND_LT` (`screen-wallet.jsx:1562`).
const Color libraryReaderBrandLight = Color(0xFFFF6B3D);

/// Das dunkle Rot, `BRAND_DK` (`screen-wallet.jsx:1562`).
///
/// Weicht von `FactColors.redDark` ab. Warum, steht im Kopf dieser Datei.
const Color libraryReaderBrandDark = Color(0xFFB82707);

/// Die Farben der Buchseite, hell und dunkel.
@immutable
final class LibraryReaderPalette {
  /// Erzeugt eine Palette.
  const LibraryReaderPalette({
    required this.page,
    required this.footer,
    required this.ink,
    required this.ink2,
  });

  /// Die hellen Werte (`screen-wallet.jsx:232-236`, `isLight`).
  static const LibraryReaderPalette light = LibraryReaderPalette(
    page: Color(0xFFF7F1E6),
    footer: Color(0xFFEDE4CC),
    ink: Color(0xFF1A1208),
    ink2: Color(0xFF2A1E10),
  );

  /// Die dunklen Werte (`screen-wallet.jsx:232-236`).
  static const LibraryReaderPalette dark = LibraryReaderPalette(
    page: Color(0xFF1C1712),
    footer: Color(0xFF141008),
    ink: Color(0xFFF0EAD8),
    ink2: Color(0xFFC8B898),
  );

  /// Die Fläche der Seite, `bookBg`.
  final Color page;

  /// Die Fläche der Fußleiste, `bookFooter`.
  final Color footer;

  /// Die kräftige Textfarbe, `bookInk`.
  final Color ink;

  /// Die Textfarbe des Fließtexts, `bookInk2`.
  final Color ink2;

  /// Die Palette zu [brightness].
  ///
  /// Dieselbe Bauform wie `FactDetailPalette.of`: die Helligkeit kommt aus dem
  /// Theme und nicht aus einem eigenen Schalter.
  static LibraryReaderPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Die Breite des Buchrückens am linken Rand (`screen-wallet.jsx:1576`).
const double libraryReaderSpineWidth = 11;

/// Die Stützstellen des Buchrücken-Verlaufs (`screen-wallet.jsx:1577`).
///
/// `90deg` mit der mittleren Farbe bei 55 Prozent, also von links nach rechts:
/// Stadt-Dunkel, Stadt, Stadt-Dunkel.
const List<double> libraryReaderSpineStops = <double>[0, 0.55, 1];

/// Die Breite des Seitenschattens am rechten Rand
/// (`screen-wallet.jsx:1582`).
const double libraryReaderCurlWidth = 18;

/// Die Farben des Seitenschattens (`screen-wallet.jsx:1583`).
///
/// `transparent`, dann zwei Schwarztöne: `0.04 * 255 = 10,2 → 10 = 0x0A` und
/// `0.09 * 255 = 22,95 → 23 = 0x17`.
const List<Color> libraryReaderCurlColors = <Color>[
  Color(0x00000000),
  Color(0x0A000000),
  Color(0x17000000),
];

/// Die Stützstellen zu [libraryReaderCurlColors] (`screen-wallet.jsx:1583`).
const List<double> libraryReaderCurlStops = <double>[0, 0.55, 1];

/// Der Innenabstand der Seite, `22px` rechts und `26px` links
/// (`screen-wallet.jsx:1589`).
///
/// **Die 52 Pixel oben fehlen mit Grund**, derselbe wie in
/// `collection_page.dart`: in der Quelle ist das die Höhe ihrer festen
/// Kopfleiste, dieser Bildschirm hat keine. Genommen wird das
/// Sicherheitsgebiet des Geräts.
const EdgeInsets libraryReaderPagePadding = EdgeInsets.fromLTRB(26, 0, 22, 16);

/// Der Abstand unter der Kopfreihe (`screen-wallet.jsx:1592`).
const double libraryReaderHeaderGap = 22;

/// Die Seitenlänge des Kopfhörer-Knopfs (`screen-wallet.jsx:1626`).
const double libraryReaderListenSize = 34;

/// Die Schriftgröße des Titels (`screen-wallet.jsx:1637`).
const double libraryReaderTitleSize = 27;

/// Die Drehung des Titels in Grad (`screen-wallet.jsx:1640`).
///
/// `rotate(-0.4deg)`, umgerechnet in Bogenmaß beim Gebrauch.
const double libraryReaderTitleTiltDegrees = -0.4;

/// Der Abstand unter dem Titel (`screen-wallet.jsx:1636`).
const double libraryReaderTitleGap = 22;

/// Die Schriftgröße des Fließtexts (`screen-wallet.jsx:1645`).
const double libraryReaderBodySize = 15.5;

/// Die Schriftgröße der beiden hinteren Absätze
/// (`screen-wallet.jsx:1660`, `:1665`).
const double libraryReaderBodySmallSize = 15;

/// Die Zeilenhöhe des Fließtexts (`screen-wallet.jsx:1645`).
const double libraryReaderBodyHeight = 1.65;

/// Der Abstand zwischen zwei Absätzen (`screen-wallet.jsx:1655`).
const double libraryReaderParagraphGap = 14;

/// Die Deckkraft des dritten Absatzes (`screen-wallet.jsx:1660`).
const double libraryReaderBackgroundOpacity = 0.88;

/// Die Breite des Balkens links am vierten Absatz
/// (`screen-wallet.jsx:1665`).
const double libraryReaderQuoteBarWidth = 3;

/// Der Abstand zwischen Balken und Text am vierten Absatz
/// (`screen-wallet.jsx:1665`).
const double libraryReaderQuoteGap = 14;

/// Die Schriftgröße der Initiale (`screen-wallet.jsx:1649`).
const double libraryReaderDropCapSize = 64;

/// Die Zeilenhöhe der Initiale (`screen-wallet.jsx:1649`).
const double libraryReaderDropCapHeight = 0.85;

/// Der Abstand rechts neben der Initiale (`screen-wallet.jsx:1650`).
const double libraryReaderDropCapGap = 8;

/// Die Mindesthöhe der Fußleiste (`screen-wallet.jsx:1762`).
const double libraryReaderFooterHeight = 78;

/// Der Innenabstand der Fußleiste, `10px 16px` (`screen-wallet.jsx:1761`).
const EdgeInsets libraryReaderFooterPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 10,
);

/// Die Farbe der Seitenzahl und ihres Balkens (`screen-wallet.jsx:1779`).
const Color libraryReaderPageNumberColor = Color(0xFF8A6A3F);

/// Die Breite des Fortschrittsbalkens in der Fußleiste
/// (`screen-wallet.jsx:1782`).
const double libraryReaderProgressWidth = 64;

/// Die Höhe des Fortschrittsbalkens (`screen-wallet.jsx:1782`).
const double libraryReaderProgressHeight = 2;

/// Die Rinne des Fortschrittsbalkens (`screen-wallet.jsx:1782`).
///
/// `rgba(140,100,40,0.15)`, also `0.15 * 255 = 38,25 → 38 = 0x26`.
const Color libraryReaderProgressTrackColor = Color(0x268C6428);

/// Die Deckkraft eines Blätter-Knopfs am Ende der Folge
/// (`screen-wallet.jsx:1772`).
const double libraryReaderDisabledOpacity = 0.25;

/// Ab welcher Strecke ein Wischen als Blättern gilt
/// (`screen-wallet.jsx:1537`).
const double libraryReaderSwipeThreshold = 50;

/// Der linke Anteil der Seite, der zurückblättert
/// (`screen-wallet.jsx:1547`).
const double libraryReaderTapZoneStart = 0.28;

/// Ab welchem Anteil nach rechts weitergeblättert wird
/// (`screen-wallet.jsx:1548`).
const double libraryReaderTapZoneEnd = 0.72;
