/// Die Maße und Farben des Nutzermarkers,
/// `02_Frontend/app/screen-map.jsx:655-682` (`createUserMarkerEl`).
///
/// ## Der Marker ist breiter als die Figur, und das ist der Pulsring
///
/// Die Figur ist 72 mal 100 Punkte, der Ring 118 mal 118. Er sitzt hinter ihr,
/// 6 Punkte über dem Fuß, und ragt damit oben aus der Figur heraus. Die Quelle
/// löst das mit `overflow: visible` und `position: absolute`; hier ist der
/// Kasten so groß gewählt, dass beides hineinpasst, weil ein Flutter-`Stack`
/// nicht über seine Grenzen malt.
///
/// ## Wo der Marker die Koordinate berührt
///
/// Am **Fuß der Figur**, nicht in der Mitte. Die Quelle setzt
/// `anchor: 'bottom'` (`:1772`), und das ist die einzige Wahl, die stimmt: eine
/// Figur steht auf einem Punkt, sie schwebt nicht darüber.
library;

import 'package:flutter/painting.dart';

/// Die Breite der Figur (`screen-map.jsx:679`).
const double avatarFigureWidth = 72;

/// Die Höhe der Figur (`screen-map.jsx:679`).
const double avatarFigureHeight = 100;

/// Der Durchmesser des Pulsrings (`screen-map.jsx:672`).
const double avatarPulseDiameter = 118;

/// Wie weit der Ring über dem Fuß der Figur sitzt, `bottom: 6px`
/// (`screen-map.jsx:671`).
const double avatarPulseBottomOffset = 6;

/// Die Breite des ganzen Markers.
///
/// Der Ring ist das breitere der beiden, also bestimmt er.
const double avatarMarkerWidth = avatarPulseDiameter;

/// Die Höhe des ganzen Markers.
///
/// Die Figur plus das, was der Ring oben heraussteht: er ist 118 hoch, sitzt 6
/// über dem Fuß, die Figur ist 100 hoch, also stehen `118 - 6 - 100 = 12`
/// Punkte über ihrem Kopf. Ausgerechnet und nicht geschätzt, weil ein zu
/// kleiner Kasten den Ring abschneidet, ohne dass Flutter etwas meldet: ein
/// `Stack` clippt lautlos, Muster 2 des Blindheitskatalogs.
const double avatarMarkerHeight = avatarFigureHeight + avatarPulseOverhang;

/// Wie weit der Ring über dem Kopf der Figur steht.
///
/// `118 - 6 - 100 = 12`. Als eigene Konstante, weil der Ausdruck
/// ausgeschrieben aussah wie ein Fehler: die Figurhöhe kürzt sich heraus, und
/// wer das übersieht, hält die Zahl für falsch.
const double avatarPulseOverhang =
    avatarPulseDiameter - avatarPulseBottomOffset - avatarFigureHeight;

/// Die Farbstufen des Pulsrings (`screen-map.jsx:673`).
///
/// `rgba(232,56,13,0.55)`, `rgba(232,56,13,0.20)`, `rgba(232,56,13,0)`.
/// Umgerechnet nach Byte, kaufmännisch gerundet: `0.55 * 255 = 140,25 → 140 =
/// 0x8C` und `0.20 * 255 = 51 = 0x33`.
const List<Color> avatarPulseColors = <Color>[
  Color(0x8CE8380D),
  Color(0x33E8380D),
  Color(0x00E8380D),
];

/// Die Stützstellen zu [avatarPulseColors] (`screen-map.jsx:673`).
const List<double> avatarPulseStops = <double>[0, 0.38, 0.7];

/// Die Dauer eines Pulsschlags, `2.2s` (`screen-map.jsx:676`).
const Duration avatarPulseDuration = Duration(milliseconds: 2200);

/// Die Skalierung am Anfang eines Pulsschlags (`screen-map.jsx:678`,
/// `@keyframes userPulseRing`).
const double avatarPulseScaleFrom = 0.55;

/// Die Skalierung am Ende.
const double avatarPulseScaleTo = 1.55;

/// Die Deckkraft am Anfang.
const double avatarPulseOpacityFrom = 0.9;

/// Die Deckkraft am Ende.
///
/// Null, der Ring verschwindet also, statt zu springen.
const double avatarPulseOpacityTo = 0;
