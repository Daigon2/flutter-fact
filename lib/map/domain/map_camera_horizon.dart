/// Wo auf dem Bildschirm der Horizont der geneigten Karte liegt, und damit
/// die Antwort auf „liegt dieser Punkt vor der Kamera".
///
/// ## Warum diese Rechnung überhaupt sein muss
///
/// `maplibre_gl 0.26.2` meldet einen Punkt hinter der Kamera **nicht**. Die
/// Doku von `toScreenLocation` behauptet zwar „Returns null if [latLng] is not
/// currently visible on the map" (`lib/src/controller.dart:1784`), im Code
/// beider Plattformen existiert diese Prüfung aber nicht
/// (`MapLibreMapController.java:913-925`, `MapLibreMapController.swift:562-571`,
/// nachgesehen am 31.08.2026). Am Gerät kommt für einen Punkt hinter der
/// Kamera eine endliche, plausibel aussehende, **gespiegelte** Zahl heraus
/// (`REBUILD_STATUS.md`, „Die vier Gerätemessungen", Messung 3). Sichtfeld und
/// Kamerahöhe gibt das Paket nicht heraus, `getVisibleRegion` liefert bei
/// Neigung nur die achsparallele Box des Trapezes. Wer die Unterscheidung
/// will, rechnet sie also selbst, und das ist diese Datei.
///
/// Die Entscheidung, sie zu wollen, ist D-17, entschieden am 31.08.2026:
/// `MapScreenPoint` trägt das Ergebnis als eigenes Feld, siehe
/// `map_screen_point.dart`.
///
/// ## Die Rechnung, und warum am Ende nur zwei Zahlen übrig bleiben
///
/// Modell: Lochkamera, Bodenebene, Neigung `θ` gegen die Senkrechte (so misst
/// das Paket sie selbst: „The angle, in degrees, of the camera angle from the
/// nadir", `maplibre_gl_platform_interface-0.26.2`,
/// `lib/src/camera.dart:28-36`). Das Auge sitzt im Abstand `D` vom Kameraziel
/// auf der Blickachse, das Ziel selbst liegt auf der Bodenebene. `f` ist die
/// Brennweite in Bildschirmpixeln, `H` die Höhe der Kartenfläche.
///
/// Für einen Bodenpunkt im vorzeichenbehafteten Abstand `s` vom Kameraziel
/// **entlang der Blickrichtung** (positiv heißt weiter weg von der Kamera)
/// gilt im Kamerasystem
///
///     Tiefe    t = D + s·sin θ
///     Höhe     v = s·cos θ
///     Bildlage y = H/2 − f·v/t
///
/// Der Punkt liegt **vor** der Kamera, wenn `t > 0`. Nach `y` aufgelöst:
///
///     t = D·f·cos θ / (f·cos θ − (H/2 − y)·sin θ)
///
/// und daraus, für `0 < θ < 90°` und `D > 0`,
///
///     t > 0   ⟺   y > H/2 − f·cot θ
///
/// **`D` fällt heraus.** Das ist der ganze Grund, warum diese Rechnung ohne
/// die Dinge auskommt, die das Paket nicht hergibt: keine Kamerahöhe, kein
/// Zoom, keine Umrechnung von Metern in Pixel, keine Kachelgröße. Übrig
/// bleiben `H/2` (die Bildmitte) und `f` (die Brennweite), und beide sind am
/// Gerät gemessen, siehe unten.
///
/// **Der seitliche Abstand kommt nicht vor**, und das ist keine Vereinfachung:
/// Blickachse und Bildhochachse haben keine seitliche Komponente, also hängen
/// weder `t` noch `y` davon ab. Ein Punkt weit links und einer weit rechts
/// werden von derselben Zeile richtig eingeordnet.
///
/// **Wie der Umschlag aussieht, damit niemand die Richtung verwechselt.**
/// Ein Punkt knapp **vor** der Augenebene läuft mit `t → 0+` nach `y → +∞`,
/// also weit unter den Bildschirmrand; ein Punkt knapp **hinter** ihr nach
/// `y → −∞`, also weit darüber. Beide sind unsichtbar, und nur der zweite ist
/// gefährlich: von dort wandert er mit wachsendem Abstand wieder zum Horizont
/// hoch und landet dabei mitten in demselben Zahlenbereich wie ein Punkt weit
/// voraus. Genau das hat Messung 3 gesehen.
///
/// ## Die beiden Zahlen, am Gerät gemessen
///
/// **Die Bildmitte, `H/2`.** Am 30.08.2026 gemessen: die projizierte
/// Kameramitte kommt auf (540,75 | 1200,94) Geräte-Pixel heraus, bei einer
/// Kartenfläche von 1080 × 2400 Geräte-Pixeln, deren Mitte bei (540 | 1200)
/// liegt (`REBUILD_STATUS.md`, „Ungefragter Fund A"). Unter einem Pixel
/// Abweichung, und geometrisch ist das auch der erwartete Wert: das Kameraziel
/// liegt auf der Blickachse und trifft deshalb den Hauptpunkt, unabhängig von
/// der Neigung.
///
/// **Die Brennweite, `f = 1,5·H`.** Sie folgt aus derselben Messnacht, aus der
/// Leiter der Messung 3. Deren Werte laufen für große Abstände gegen einen
/// Fluchtwert: nach vorn auf −1047,95, nach hinten auf −1053,83 Geräte-Pixel,
/// der Horizont liegt also bei rund −1050,89. Mit `H/2 = 1200` und `θ = 58°`
/// ergibt `f = (H/2 − y∞)·tan θ = 2250,89 · 1,60033 = 3602,2` Pixel, also
///
///     f / H = 1,5009
///
/// Das ist die Brennweite, die zu einem senkrechten Sichtfeld von
/// `2·arctan(1/3) = 36,87°` gehört, der festen Konstante, die MapLibre GL JS
/// als `_fov` trägt und von der MapLibre Native abstammt. Gemessen kommen
/// 36,85° heraus, 0,06 % daneben.
///
/// **Zweite, unabhängige Probe: das ganze Modell rechnet die Leiter nach.**
/// Nachgerechnet am 31.08.2026 aus der Tabelle in `REBUILD_STATUS.md`, nicht
/// neu am Gerät gemessen. Aus dem Fluchtwert und zwei der vierzehn Punkte
/// (100 km und 20 km nach vorn) folgen die zwei Größen, die die Messnacht
/// selbst als unsicher gekennzeichnet hat: die Lage des Kameraziels auf der
/// Leiter (0,44 km nördlich des Startpunkts der Probe) und der Abstand `m` des
/// Pols hinter dem Ziel (2,687 km). Mit diesen beiden trifft das Modell die
/// **restlichen elf** Punkte auf 0,42 % im schlechtesten Fall, über einen
/// Wertebereich von −3241 bis +3826 Pixeln.
///
/// Und `m` lässt sich unabhängig vorhersagen: `m = D/sin θ`, mit `D = f`
/// (MapLibre setzt den Abstand zum Kameraziel gleich der Brennweite) und dem
/// Web-Mercator-Maßstab bei Zoom 14,94, Breite 48,15° und Skalierungsfaktor
/// 2,625, also 0,6329 Meter je Geräte-Pixel. Das ergibt 2,688 km gegen die
/// gefitteten 2,687 km, **0,06 % Abweichung**.
///
/// **Was diese zweite Probe nicht kann, und das gehört dazu:** sie bestätigt
/// das **Produkt** aus `D = f` und dem Pixelmaßstab. Eine Welt, in der `D`
/// doppelt so groß und der Maßstab halb so fein ist (also die
/// Kachelgröße 256 statt 512), passte genauso. Für die Formel dieser Datei ist
/// das gleichgültig, `D` fällt ohnehin heraus; für `map_camera_fit.dart`, das
/// seine 512 bis heute nur hergeleitet und nicht gemessen hat, ist es ein
/// Indiz und kein Beweis. **Nebenbei bemerkt widerspricht die Paketdoku sich
/// hier selbst:** `camera.dart:40-42` sagt „A zoom of 0.0, the default, means
/// the screen width of the world is 256", und dieselbe Sorte Satz hat bei
/// `toScreenLocation` schon einmal nicht gestimmt.
///
/// ## Die Annahme, die übrig bleibt, und die eine Messung, die sie fällt
///
/// **Gemessen ist `f/H = 1,5` bei genau einer Neigung (58°) und genau einer
/// Fläche (1080 × 2400 Geräte-Pixel).** Angenommen ist, dass das Verhältnis
/// bei **jeder** Neigung und **jeder** Flächengröße gilt, also dass das
/// senkrechte Sichtfeld des SDK eine feste Konstante ist. Das ist plausibel,
/// weil eine Kamera nicht ihre Optik wechselt, wenn sie sich neigt, aber es
/// ist an diesem Paket nicht nachgeprüft.
///
/// **Welche Messung die Formel bestätigen würde:** die Karte am Gerät auf eine
/// Neigung stellen, die **nicht** 58 Grad ist, etwa 30, die Kamera stehen
/// lassen, und mit `toScreenLocationBatch` einen einzigen Punkt rund 2000 km
/// in Blickrichtung projizieren. Sein `y` ist der Horizont, bis auf ein paar
/// Pixel. Vorhergesagt bei einer Fläche von 2400 Geräte-Pixeln Höhe:
///
/// | Neigung | erwartetes `y` |
/// |---|---|
/// | 30° | −5035,4 |
/// | 45° | −2400,0 |
/// | 58° | −1049,5 |
/// | 60° | −878,5 |
///
/// Trifft der abgelesene Wert, gilt die Annahme. Trifft er nicht, folgt das
/// richtige Verhältnis direkt aus derselben Ablesung, nämlich
/// `f/H = (H/2 − y)·tan(Neigung)/H`, und diese Zahl ersetzt dann die 1,5 in
/// [_focalLengthPerViewportHeight]. Eine einzige Ablesung entscheidet es, und
/// sie braucht keinen sichtbaren Punkt: die Projektion antwortet auch weit
/// außerhalb des Bildes, das hat Messung 3 mit Werten von −3241 bis +3826
/// gezeigt.
///
/// **Was diese Datei ausdrücklich nicht tut:** raten. Eine hier eingetragene
/// Sichtfeldkonstante ohne die Herleitung oben wäre dieselbe Sorte unbelegte
/// Zahl wie die 512 in `map_camera_fit.dart`, und die trägt dort vierzig
/// Zeilen Rechtfertigung.
///
/// ## Reine Geometrie, keine Politik
///
/// Wie `map_camera_fit.dart`: diese Datei kennt keinen Ballon, keine Gruppe
/// und keine Schwelle. Sie rechnet aus einer Flächenhöhe und einer Neigung
/// eine Bildschirmzeile aus, mehr nicht.
library;

import 'dart:math' as math;

/// Brennweite je Höhe der Kartenfläche.
///
/// Siehe Kopfkommentar: am Gerät kommen 1,5009 heraus, und das ist das
/// Sichtfeld `2·arctan(1/3) = 36,87°`. Eingetragen ist der glatte Wert, weil
/// die Abweichung von 0,06 % die Messgenauigkeit der Leiter ist und nicht ein
/// zweites Sichtfeld.
const double _focalLengthPerViewportHeight = 1.5;

/// Die Bildschirmzeile, unterhalb derer Bodenpunkte vor der Kamera liegen, in
/// **Geräte-Pixeln** ab dem oberen Rand der Kartenfläche.
///
/// [viewportHeightInDevicePixels] ist die Höhe der Kartenfläche im
/// Geräteraster, also in derselben Einheit, in der `MapScreenPoint` seine
/// Zahlen trägt (`MapViewport` misst in Stilpixeln, das ist eine andere
/// Einheit, siehe dort). [pitchInDegrees] ist die Neigung gegen die
/// Senkrechte, `MapCameraView.pitch`.
///
/// ## Die Randfälle, und warum jeder von ihnen so ausgeht
///
/// **Neigung 0 oder kleiner:** `double.negativeInfinity`. Eine senkrecht nach
/// unten blickende Kamera hat nichts hinter sich, jeder Bodenpunkt liegt vor
/// ihr. Das ist nicht bloß ein Schutz vor `cot(0) = ∞`, es ist die richtige
/// Antwort.
///
/// **Fläche ohne Höhe:** ebenfalls `double.negativeInfinity`, und das ist eine
/// Entscheidung und keine Geometrie. Vor dem ersten Layout kennt niemand die
/// Fläche, und ohne sie ist der Horizont nicht zu berechnen. Von den beiden
/// möglichen Antworten ist „alles liegt vor der Kamera" die harmlose: sie ist
/// genau der Zustand vor D-17, während „alles liegt hinter der Kamera" jeden
/// Ballon einer noch nicht gemessenen Fläche verschwinden ließe. Das wäre ein
/// schwererer Ausfall als der gespiegelte Geisterballon, den dieses Feld
/// verhindern soll. Ohne diese Abfrage stünde hier außerdem `0 · ∞`, also
/// `NaN`, und ein `NaN` im Vergleich ist immer `false`: aus „ich weiß es
/// nicht" würde lautlos „liegt hinter der Kamera".
///
/// **Neigung ab 90 Grad:** die Bildmitte. Bei genau 90 Grad ist `cot θ = 0`
/// und der Horizont liegt in der Bildmitte; jenseits davon blickt die Kamera
/// über die Senkrechte hinaus, `cos θ` wechselt das Vorzeichen und das Modell
/// gilt nicht mehr. Erreichbar ist das nicht: die Karte klemmt die Neigung
/// selbst („Values beyond the supported range are allowed, but on applying
/// them to a map they will be silently clamped to the supported range",
/// `camera.dart:33-35`). Die Zeile steht hier, damit aus einem Wert, den
/// niemand erwartet, keine Zahl entsteht, die nach Geometrie aussieht.
double cameraHorizonYInDevicePixels({
  required double viewportHeightInDevicePixels,
  required double pitchInDegrees,
}) {
  if (viewportHeightInDevicePixels <= 0 || pitchInDegrees <= 0) {
    return double.negativeInfinity;
  }
  final double centerY = viewportHeightInDevicePixels / 2;
  if (pitchInDegrees >= 90) {
    return centerY;
  }
  final double pitch = pitchInDegrees * math.pi / 180;
  final double focalLength =
      _focalLengthPerViewportHeight * viewportHeightInDevicePixels;
  return centerY - focalLength * math.cos(pitch) / math.sin(pitch);
}

/// Ob ein Bodenpunkt, der auf die Bildzeile [yInDevicePixels] projiziert
/// wurde, vor der Kamera liegt.
///
/// **Die Richtung des Vergleichs ist die eine Stelle, an der das lautlos
/// falsch wird**, und deshalb steht sie als eigene, benannte Funktion da und
/// nicht als Ausdruck im Aufrufer: die Bildschirmachse wächst nach **unten**,
/// „vor der Kamera" ist also das **größere** `y`. Verdreht man es, verschwindet
/// alles Sichtbare und die Geister bleiben, und beides sähe nach einem Fehler
/// an einer ganz anderen Stelle aus.
///
/// Der Horizont selbst zählt nicht mehr als „vor der Kamera": dort liegt der
/// unendlich ferne Punkt, und ein Bodenpunkt erreicht ihn nie.
bool liesInFrontOfCamera({
  required double yInDevicePixels,
  required double horizonYInDevicePixels,
}) => yInDevicePixels > horizonYInDevicePixels;
