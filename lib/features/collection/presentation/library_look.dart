/// Die Farben und Maße des Reiseführers, die es nur hier gibt.
///
/// ## Warum das nicht ins Theme gehört
///
/// `FactColors` ist die Abschrift von `styles.css`, also der Tokens, die die
/// ganze PWA teilt. Der Reiseführer bringt einen **eigenen** Satz mit:
/// `wltUseTok` (`02_Frontend/app/screen-wallet.jsx:215-243`) definiert neben
/// den geteilten Werten Regalholz, Buchpapier und ein Creme, die in keiner
/// CSS-Variable stehen. Sie inszenieren ein Bücherregal und tauchen auf keinem
/// anderen Bildschirm auf; im Theme wären sie tote Felder für alle anderen.
///
/// Dieselbe Aufteilung wie beim Ballon: geteilte Tokens aus dem Theme,
/// bildschirmeigene Werte als Konstanten daneben.
///
/// ## Eine gemessene Abweichung von zwei Prozent
///
/// `wltUseTok.brd` ist `rgba(140,100,40,0.14)`, `FactColors.border` ist
/// `0x1F8C6428`, also 0,12. Der Reiseführer weicht damit von der CSS-Variable
/// ab, die er sonst spiegelt. Genommen wird der **Theme-Wert**: es geht um
/// Haarlinien, zwei Prozent Deckkraft sind auf keinem Gerät zu sehen, und ein
/// eigenes Rahmen-Token hier hieße, dieselbe Linie zweimal zu pflegen.
///
/// ## Deckkraft nach Ganzzahl
///
/// CSS rechnet `rgba(…, 0.55)` als Bruch, Flutter als Byte. Umgerechnet wird
/// kaufmännisch gerundet: `0.55 * 255 = 140,25 → 140 = 0x8C`. Steht einmal
/// hier, damit es an den einzelnen Konstanten nicht wiederholt werden muss.
library;

import 'package:flutter/material.dart';

/// Der Farbverlauf des Regalkastens (`screen-wallet.jsx:928`).
const List<Color> libraryShelfBoxColors = <Color>[
  Color(0xFF2A1D14),
  Color(0xFF1F1410),
];

/// Die Ecken des Regalkastens (`screen-wallet.jsx:929`).
const double libraryShelfBoxRadius = 18;

/// Der Innenabstand des Regalkastens, `18px 14px 8px`
/// (`screen-wallet.jsx:929`).
const EdgeInsets libraryShelfBoxPadding = EdgeInsets.fromLTRB(14, 18, 14, 8);

/// Der Farbverlauf des Holzbretts unter jeder Reihe
/// (`screen-wallet.jsx:1016`).
///
/// Drei Stützstellen mit der mittleren bei 30 Prozent, deshalb die `stops`
/// daneben.
const List<Color> libraryShelfBoardColors = <Color>[
  Color(0xFF8B5E33),
  Color(0xFF6B4423),
  Color(0xFF3F2614),
];

/// Die Stützstellen zu [libraryShelfBoardColors].
const List<double> libraryShelfBoardStops = <double>[0, 0.3, 1];

/// Die Höhe des Holzbretts (`screen-wallet.jsx:1015`).
const double libraryShelfBoardHeight = 9;

/// Wie weit das Brett links und rechts über die Bücher hinausragt
/// (`screen-wallet.jsx:1015`, `left: -8, right: -8`).
const double libraryShelfBoardOverhang = 8;

/// Die Ecken des Holzbretts (`screen-wallet.jsx:1017`).
const double libraryShelfBoardRadius = 3;

/// Der waagerechte Abstand zwischen zwei Büchern (`screen-wallet.jsx:939`).
const double libraryBookGap = 6;

/// Der Abstand unter einer Reihe, also zwischen Buchfuß und Brett
/// (`screen-wallet.jsx:940`).
const double libraryRowBottomPadding = 14;

/// Der Abstand über jeder Reihe außer der ersten (`screen-wallet.jsx:941`).
const double libraryRowTopPadding = 18;

/// Die Ecken eines Buchrückens, `3px 5px 5px 3px`
/// (`screen-wallet.jsx:970`).
///
/// Links schmaler als rechts: der Rücken sitzt links am Falz.
const BorderRadius libraryBookRadius = BorderRadius.only(
  topLeft: Radius.circular(3),
  topRight: Radius.circular(5),
  bottomRight: Radius.circular(5),
  bottomLeft: Radius.circular(3),
);

/// Die Stützstellen des Buchrücken-Verlaufs (`screen-wallet.jsx:974`).
///
/// `linear-gradient(90deg, colorDk, color 14%, color 86%, colorLt)`: dunkel am
/// Falz, hell an der Schnittkante.
const List<double> libraryBookGradientStops = <double>[0, 0.14, 0.86, 1];

/// Der Schlagschatten eines Buchrückens (`screen-wallet.jsx:975`).
///
/// Nur der äußere. Die drei `inset`-Schatten derselben Zeile sind hier
/// **nicht** nachgebaut: Flutter kennt keinen inneren Schatten, und die
/// Nachbildung über eine zusätzliche Verlaufsebene je Buch kostet vier
/// Zeichenebenen pro Regal für einen Effekt, den man auf 90 Pixel Breite nicht
/// auseinanderhalten kann. Die Abweichung steht hier, statt unbemerkt zu
/// bleiben.
const BoxShadow libraryBookShadow = BoxShadow(
  color: Color(0x8C000000),
  offset: Offset(-3, 5),
  blurRadius: 10,
);

/// Das Goldband am Kopf des Buchrückens (`screen-wallet.jsx:980`).
const List<Color> libraryBookRibbonColors = <Color>[
  Color(0xFF1A1208),
  Color(0xFFF5C518),
  Color(0xFFFFE066),
  Color(0xFFF5C518),
  Color(0xFF1A1208),
];

/// Die Stützstellen zu [libraryBookRibbonColors] (`screen-wallet.jsx:980`).
const List<double> libraryBookRibbonStops = <double>[0, 0.16, 0.5, 0.86, 1];

/// Die Höhe des Goldbands (`screen-wallet.jsx:979`).
///
/// Sechs Pixel. Das ausgebaute `WltBookSpine` derselben Datei sagt acht, und
/// es wird nirgends aufgerufen, siehe E-76.
const double libraryBookRibbonHeight = 6;

/// Die Farbe des Titels auf dem Buchrücken (`screen-wallet.jsx:986`).
const Color libraryBookTitleColor = Color(0xFFFFFFFF);

/// Der Schatten unter dem Titel (`screen-wallet.jsx:988`).
const Shadow libraryBookTitleShadow = Shadow(
  color: Color(0x80000000),
  offset: Offset(0, 1),
);

/// Die Breite der Zählerplatte, als Anteil der Buchbreite
/// (`screen-wallet.jsx:991`).
const double libraryCounterPlateWidthFactor = 0.84;

/// Die Linien über und unter der Zählerplatte
/// (`screen-wallet.jsx:992-993`).
const Color libraryCounterPlateLineColor = Color(0x52FFFFFF);

/// Der Grund der Zählerplatte (`screen-wallet.jsx:994`).
const Color libraryCounterPlateColor = Color(0x38000000);

/// Die Deckkraft des `/gesamt`-Teils im Zähler (`screen-wallet.jsx:999`).
const double libraryCounterTotalOpacity = 0.55;

/// Die Farbe der Bandnummer (`screen-wallet.jsx:1006`).
const Color libraryVolumeNumberColor = Color(0x8CFFFFFF);

/// Der gestrichelte Rand eines Leerplatzes (`screen-wallet.jsx:948`).
const Color libraryEmptySlotBorderColor = Color(0x2EFFC878);

/// Die Beschriftung eines Leerplatzes (`screen-wallet.jsx:955`).
const Color libraryEmptySlotTextColor = Color(0x4DFFC878);

/// Der Farbverlauf der Kopfkarte, `135deg` (`screen-wallet.jsx:809`).
const List<Color> libraryHeaderColors = <Color>[
  Color(0xFFFF8A55),
  Color(0xFFE8380D),
  Color(0xFFB82707),
];

/// Die Stützstellen zu [libraryHeaderColors] (`screen-wallet.jsx:809`).
const List<double> libraryHeaderStops = <double>[0, 0.55, 1];

/// Die Ecken der Kopfkarte (`screen-wallet.jsx:810`).
const double libraryHeaderRadius = 24;

/// Der Innenabstand der Kopfkarte, `18px 22px 16px`
/// (`screen-wallet.jsx:810`).
const EdgeInsets libraryHeaderPadding = EdgeInsets.fromLTRB(22, 18, 22, 16);

/// Der Schatten unter der Kopfkarte (`screen-wallet.jsx:811`).
const BoxShadow libraryHeaderShadow = BoxShadow(
  color: Color(0x4DE8380D),
  offset: Offset(0, 10),
  blurRadius: 26,
);

/// Die Schrift der Zeile über dem Titel (`screen-wallet.jsx:834`).
const Color libraryHeaderKickerColor = Color(0xA6FFFFFF);

/// Die Schrift der Zeile unter dem Titel (`screen-wallet.jsx:848`).
const Color libraryHeaderSubColor = Color(0xB8FFFFFF);

/// Der Grund eines Merkmal-Chips in der Kopfkarte
/// (`screen-wallet.jsx:866`).
const Color libraryChipColor = Color(0x29FFFFFF);

/// Der Rand eines Merkmal-Chips (`screen-wallet.jsx:866`).
const Color libraryChipBorderColor = Color(0x38FFFFFF);

/// Der Farbverlauf einer verdienten Trophäenkarte
/// (`screen-wallet.jsx:1055-1056`).
const List<Color> libraryTrophyEarnedColors = <Color>[
  Color(0xFFFFFCE8),
  Color(0xFFFFF4C2),
];

/// Der Rand einer verdienten Trophäenkarte (`screen-wallet.jsx:1058`).
const Color libraryTrophyEarnedBorderColor = Color(0x73F5C518);

/// Der Schatten einer verdienten Trophäenkarte (`screen-wallet.jsx:1062`).
const BoxShadow libraryTrophyEarnedShadow = BoxShadow(
  color: Color(0x38F5C518),
  offset: Offset(0, 3),
  blurRadius: 12,
);

/// Der Schatten einer gesperrten Trophäenkarte (`screen-wallet.jsx:1062`).
const BoxShadow libraryTrophyLockedShadow = BoxShadow(
  color: Color(0x0D000000),
  offset: Offset(0, 2),
  blurRadius: 6,
);

/// Der Grund einer gesperrten Trophäenkarte (`screen-wallet.jsx:1057`).
///
/// `#fff`, und zwar in **beiden** Themes: die Quelle schreibt die Farbe hier
/// fest hin, statt ein Token zu nehmen. Im dunklen Theme ist eine weiße Karte
/// auf `#13100E` ein harter Kontrast, und das ist genau, was die PWA zeigt.
/// Übernommen, weil es Aussehen ist und keine Funktion; wer es ändern will,
/// entscheidet über Gestaltung.
const Color libraryTrophyLockedColor = Color(0xFFFFFFFF);

/// Die Seitenlänge einer Trophäenkarte (`screen-wallet.jsx:1053-1054`).
///
/// `width: 88` mit `aspectRatio: '1 / 1'`, also ein Quadrat.
const double libraryTrophyCardSize = 88;

/// Die Ecken einer Trophäenkarte (`screen-wallet.jsx:1059`).
const double libraryTrophyCardRadius = 14;

/// Die Deckkraft des Zeichens einer gesperrten Trophäe
/// (`screen-wallet.jsx:1066`).
const double libraryTrophyLockedGlyphOpacity = 0.42;
