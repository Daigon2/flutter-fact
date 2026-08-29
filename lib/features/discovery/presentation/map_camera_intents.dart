/// Die Kameraabsichten des Kartenbildschirms, als reine Funktionen.
///
/// Vier Anlässe, sechs Zahlen, keine Zeile Oberfläche: Sky-Fall, GPS-Folgen,
/// Neuzentrieren und der harte Reset. Jede Funktion nimmt entgegen, was sie
/// wissen muss, und gibt eine Absicht zurück. Ob sie ausgeführt wird,
/// entscheidet der Karten-Host mit `decideMapCameraIntent`.
///
/// ## Warum das in `presentation/` liegt und nicht in `domain/`
///
/// Weil es in `discovery/domain/` nicht liegen **kann**: Gate 6 des
/// Prüfskripts lässt in einer Feature-Domäne nur `dart:`-Importe und Dateien
/// derselben Feature-Domäne zu, und diese Datei lebt von `map/domain/`.
/// `discovery/application/` wäre erlaubt, entstünde aber allein für diese
/// Datei; ADR-002 lässt die Struktur mit der Komplexität wachsen, und
/// `discovery` hat heute nur `presentation/`. Vorbild ist
/// `map/presentation/map_auto_pitch.dart`: dieselbe Sorte reiner Rechnung,
/// ebenfalls in `presentation/`, ebenfalls ohne einen Flutter-Import.
///
/// ## Was hier bewusst fehlt
///
/// **Die zwischengespeicherte letzte Position.** Die Quelle legt jeden Fix in
/// `localStorage` ab (`screen-map.jsx:2648`), liest ihn beim Start wieder
/// (`:1663`) und startet damit sowohl die Startkamera (`:1668`) als auch den
/// Sky-Fall (`:1746-1747`, `map.once` auf `idle`). Dafür bräuchte es dauerhafte
/// Speicherung, die es im Neubau nicht gibt; ein Paket dafür wäre
/// freigabepflichtig. **Die Startkamera bleibt deshalb die Rückfallstadt, bis
/// der erste Fix kommt** (`MapPage.placeholderCamera`), und der Sky-Fall hat
/// genau einen Auslöser statt zwei.
///
/// **Der Auslöser, ab dem diese Auslassung fällt:** die erste Entscheidung
/// über dauerhafte Speicherung auf dem Gerät. Dann ist es eine gespeicherte
/// Position, eine geänderte Startkamera und ein zweiter Aufrufer für
/// [skyFallIntent], und keine Zeile hier ändert sich.
///
/// **Das Kamera-Padding von 320 Pixeln** (`:1694`) und **der Abbruch per
/// `stop()` beim harten Reset** (`:3164`) sind zwei Paketlücken, die in
/// `map/presentation/map_surface.dart` und `map/domain/map_camera_intent.dart`
/// bereits festgehalten sind. Hier steht dazu nichts Neues und nichts
/// Umgehendes.
library;

import 'dart:math' as math;

import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_gate.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Zoomstufe, auf die der Sky-Fall zufliegt. `screen-map.jsx:1734`.
///
/// Der Kommentar dort: „PoGo-Parität: weiter raus, ganzes Straßen-Raster
/// sichtbar".
const double skyFallZoom = 16.5;

/// Neigung am Ende des Sky-Falls, in Grad. `screen-map.jsx:1735`.
///
/// **58 und nicht 65 oder 75**, dieselbe Falle wie bei der Auto-Neigung: der
/// Kommentar bei `:1752-1753` nennt noch die alten Werte, der Code sagt
/// `pitch: 58` mit dem Zusatz „(vorher 65 = zu steil, zu viel Himmel)".
const double skyFallPitch = 58;

/// Blickrichtung am Ende des Sky-Falls, in Grad. `screen-map.jsx:1736`.
///
/// Ausgeschrieben und nicht weggelassen: `bearing: 0` steht in der Quelle, und
/// ein weggelassenes Feld hieße nach [MapCameraChange] „Blickrichtung
/// behalten". Der Sky-Fall dreht die Karte also ausdrücklich nach Norden.
const double skyFallBearing = 0;

/// Wie lange der Sky-Fall dauert.
///
/// **Diese Zahl ist geschätzt und steht in keiner Quelle.** Die Quelle steuert
/// ihren Flug über `speed: 4.2` und `curve: 1.2` (`screen-map.jsx:1737-1738`),
/// und `maplibre_gl 0.26.2` hat dafür kein Gegenstück: `animateCamera` kennt
/// ausschließlich eine [Duration]. Das ist bereits in
/// `map/domain/map_camera.dart` festgehalten, samt der Forderung, jede daraus
/// entstehende Dauer als Ersatzwert zu kennzeichnen. Hier ist sie.
///
/// **Wogegen zu messen wäre:** die PWA im Browser, Sky-Fall auslösen und die
/// Zeit von der ersten Bewegung bis zum Stillstand nehmen. Das Ergebnis hängt
/// zusätzlich von der Strecke ab, weil die Quelle mit einer Geschwindigkeit
/// und nicht mit einer Dauer rechnet; ein fester Wert kann das grundsätzlich
/// nicht abbilden.
///
/// Eine Herleitung wird hier **nicht** behauptet. Die einzige Randbedingung,
/// die wirklich aus dem Code folgt: solange die Animation läuft, unterdrückt
/// das Gate jede Dauerabsicht (Vorrangregel 3), eine sehr lange Dauer
/// verzögert also das erste GPS-Folgen. Und es ist eine Zeile.
const Duration skyFallDuration = Duration(milliseconds: 900);

/// Wie lange das GPS-Folgen für einen Schritt braucht.
///
/// `screen-map.jsx:2673`: `duration: 900` am `easeTo`.
const Duration followDuration = Duration(milliseconds: 900);

/// Zoomstufe, unter die das Neuzentrieren nicht geht.
///
/// `screen-map.jsx:2985`: `zoom: Math.max(m.getZoom(), 15)`. Wer weiter drin
/// steht als 15, behält seinen Zoom; wer weiter draußen steht, wird
/// herangeholt.
const double recenterMinZoom = 15;

/// Wie lange das Neuzentrieren dauert. `screen-map.jsx:2986`.
const Duration recenterDuration = Duration(milliseconds: 400);

/// Zoomstufe des harten Resets. `screen-map.jsx:3168`.
const double hardResetZoom = 15;

/// Neigung des harten Resets, in Grad. `screen-map.jsx:3168` und `:3170`.
const double hardResetPitch = 30;

/// Blickrichtung des harten Resets, in Grad. `screen-map.jsx:3168` und `:3170`.
const double hardResetBearing = 0;

/// Die Eröffnungsanimation auf den ersten Fix, `screen-map.jsx:1731-1739`.
///
/// Einmal-Absicht und kein Befehl: sie ist keine Nutzergeste, sondern die
/// Reaktion auf den ersten GPS-Fix. [MapCameraOneShot.yieldsToRunningAnimation]
/// bleibt beim Standard `false`, weil der Flug überschreibt, was gerade läuft.
///
/// ## Zwei Dinge der Quelle, die hier nicht auftauchen
///
/// **Der Riegel `skyFallDone`** (`:1726-1729`) steht nicht hier, sondern beim
/// Aufrufer. Eine reine Funktion kann sich nicht merken, dass sie schon einmal
/// gerufen wurde, und ein Modulzustand dafür wäre genau die Sorte versteckter
/// Zustand, die einen Test von der Reihenfolge seiner Nachbarn abhängig macht.
///
/// **Die 60 Millisekunden Verzögerung** (`:1730`, „Slight delay so the user
/// perceives starting high before falling") sind bewusst nicht nachgebaut. Sie
/// sorgen im Browser dafür, dass der Startzustand einmal gezeichnet ist, bevor
/// die Animation beginnt: dort kann der Sky-Fall im selben Umlauf ausgelöst
/// werden, in dem der Stil fertig lädt. Im Neubau zeichnet die Kartenfläche,
/// seit sie im Baum hängt, und die Absicht entsteht frühestens mit dem ersten
/// GPS-Fix, also viele Bilder später.
MapCameraOneShot skyFallIntent(MapPosition target) => MapCameraOneShot(
  change: MapCameraChange(
    center: target,
    zoom: skyFallZoom,
    bearing: skyFallBearing,
    pitch: skyFallPitch,
  ),
  motion: const MapCameraAnimated(skyFallDuration),
  origin: MapCameraIntentOrigin.discovery,
);

/// Die Karte folgt dem Nutzer, `screen-map.jsx:2665-2675`.
///
/// Die vier Eigenschaften stehen alle in einer Zeile der Quelle:
/// `if (!m.isEasing() && movedSinceCamera > 12 && sinceLastEase > 800)`
/// (`:2668`).
///
/// * **Totzone 12 Meter** und **Mindestpause 800 Millisekunden**, beide aus
///   [MapCameraThresholds], wo sie mit Fundstelle stehen.
/// * **Weicht keiner Geste.** `userInteracting` ist an dieser Stelle gar nicht
///   erreichbar, es ist eine lokale Variable im Closure des Kompass-Effekts
///   (`:2807`). Das ist keine Nachlässigkeit der Quelle, sondern der
///   Unterschied zur zweiten Dauerabsicht, siehe
///   [MapCameraFollow.yieldsToUserGesture].
/// * **Keine Winkel-Totzone**, weil diese Absicht die Blickrichtung nicht
///   anfasst. [MapCameraChange.changesBearing] ist damit `false`, und das
///   Einrasten der Blickrichtung hält sie nicht auf.
///
/// Sie verschiebt allein den Mittelpunkt. Zoom, Blickrichtung und Neigung
/// bleiben `null`, also unverändert, genau wie beim `easeTo` der Quelle.
MapCameraFollow userPositionFollowIntent(MapPosition target) => MapCameraFollow(
  kind: MapCameraFollowKind.userPosition,
  change: MapCameraChange(center: target),
  motion: const MapCameraAnimated(followDuration),
  origin: MapCameraIntentOrigin.discovery,
  yieldsToUserGesture: false,
  deadZoneMeters: MapCameraThresholds.followDeadZoneMeters,
  minPause: MapCameraThresholds.followMinPause,
);

/// Was das Neuzentrieren an der Kamera ändert, `screen-map.jsx:2983-2987`.
///
/// Eigene Funktion, weil zwei Absichten sie teilen: die Stadt-Pille
/// ([recenterIntent]) und der kurze Druck auf den Kompass
/// ([compassTapIntent]). In der Quelle rufen beide dieselbe Funktion
/// `recenter` (`:3106` und `:3183`), und die Ränge unterscheiden sich trotzdem.
MapCameraChange recenterChange({
  required MapPosition target,
  required double currentZoom,
}) => MapCameraChange(
  center: target,
  zoom: math.max(currentZoom, recenterMinZoom),
);

/// Neuzentrieren, ausgelöst von der Stadt-Pille (`screen-map.jsx:3106`).
///
/// **Einmal-Absicht und kein Befehl, und das ist der Unterschied zum Kompass.**
/// Die Pille ruft `recenter` und sonst nichts; sie fasst `manualBearingRef`
/// nicht an. Ein [MapCameraCommand] hier wäre die bequeme Verallgemeinerung
/// „jeder Tipp ist ein Nutzerbefehl", und sie wäre falsch: das Lösen des
/// Einrastens gilt nur für [MapCameraCommand], die Pille löste damit eine
/// Sperre, die nur der Kompassknopf lösen darf (`map_camera_gate.dart`,
/// `releasesBearingLock`).
///
/// Die Quelle ruft die Pille ohne Position gar nicht wirksam auf: `recenter`
/// kehrt bei fehlender Position sofort zurück (`:2978-2979`), und die Pille
/// zeigt dann nicht einmal einen Zeiger (`cursor: userPos ? pointer :
/// default`, `:3112`). Deshalb nimmt diese Funktion eine nicht-nullbare
/// Position: wo es keine gibt, entsteht kein Rückruf, siehe
/// `MapTopChrome.onCityTap`.
MapCameraOneShot recenterIntent({
  required MapPosition target,
  required double currentZoom,
}) => MapCameraOneShot(
  change: recenterChange(target: target, currentZoom: currentZoom),
  motion: const MapCameraAnimated(recenterDuration),
  origin: MapCameraIntentOrigin.discovery,
);

/// Kurzer Druck auf den Kompass, `screen-map.jsx:3175-3185`.
///
/// Zwei Wirkungen in dieser Reihenfolge, und die zweite hängt an einer
/// Bedingung, die erste nicht:
///
/// 1. `manualBearingRef.current = false` (`:3182`), **unbedingt**. Das
///    Einrasten der Blickrichtung wird gelöst, auch wenn es keine Position
///    gibt.
/// 2. `recenter()` (`:3183`), das ohne Position sofort zurückkehrt.
///
/// Deshalb ist das ein [MapCameraCommand] mit `releasesBearingLock: true`, und
/// deshalb ist [target] nullbar. **`clearsFollowAnchor` bleibt `false`:** der
/// kurze Druck fasst `lastCameraPosRef` nicht an, nur der lange tut das
/// (`:3165`).
///
/// ## Die eine Abweichung, ohne Position
///
/// Gibt es keine Position, entsteht in der Quelle **gar kein** Kameraaufruf.
/// Hier entsteht trotzdem eine Absicht, weil das Einrasten nur über einen
/// Befehl lösbar ist und ein Befehl immer eine Bewegung mitbringt. Ihre
/// [MapCameraChange] ist leer, also „nichts ändern", und **der Host ruft den
/// Treiber dann gar nicht**: er führt die Nebenwirkungen des Befehls aus, das
/// Lösen des Einrastens, und lässt die Kamera stehen, wo sie ist
/// (`map/presentation/map_camera_host.dart`, `_touchesNothing`). An der Kamera
/// ist die Abweichung damit folgenlos.
///
/// **Hier stand einmal eine andere Begründung, und sie war falsch.** Sie
/// lautete, der Sprung auf die eigene Ist-Stellung sei unsichtbar und der
/// einzige messbare Unterschied, der verworfene Animationszustand, sei ohne
/// Position unerreichbar, „denn ohne Position gab es auch keinen Sky-Fall".
/// Die Aufzählung der Animationsquellen war unvollständig: **die Auto-Neigung
/// braucht keine Position** (`map/presentation/map_auto_pitch.dart`), sie
/// hängt am Zoom-Ende. Wer ohne Ortungsfreigabe zoomt und in diesen 300
/// Millisekunden den Kompass tippt, sah seine Neigung auf halbem Weg
/// einfrieren.
MapCameraCommand compassTapIntent({
  required double currentZoom,
  MapPosition? target,
}) => MapCameraCommand(
  change: target == null
      ? const MapCameraChange()
      : recenterChange(target: target, currentZoom: currentZoom),
  motion: target == null
      ? const MapCameraImmediate()
      : const MapCameraAnimated(recenterDuration),
  origin: MapCameraIntentOrigin.discovery,
  releasesBearingLock: true,
  clearsFollowAnchor: false,
);

/// Langer Druck auf den Kompass, der harte Reset, `screen-map.jsx:3158-3172`.
///
/// Vier Wirkungen, davon drei unbedingt:
///
/// 1. Der Abbruch der laufenden Animation (`:3164`). **Den gibt es in
///    `maplibre_gl 0.26.2` nicht.** Er entsteht daraus, dass ein
///    [MapCameraCommand] immer ausgeführt wird und der Host dabei seinen
///    Animationszustand verwirft; das ist in
///    `map/domain/map_camera_intent.dart` festgehalten und wird hier nicht
///    umgangen.
/// 2. `lastCameraPosRef.current = null` (`:3165`), also
///    `clearsFollowAnchor: true`. Ohne das unterdrückte die Strecken-Totzone
///    den nächsten GPS-Fix, während die Quelle ihn ausführt.
/// 3. `manualBearingRef.current = false` (`:3166`), also
///    `releasesBearingLock: true`.
/// 4. Der Sprung, und **hier unterscheidet die Quelle zwei Fälle**: mit
///    Position `{ center, bearing: 0, pitch: 30, zoom: 15 }` (`:3168`), ohne
///    Position nur `{ bearing: 0, pitch: 30 }` (`:3170`). Mittelpunkt und Zoom
///    bleiben dann, wo sie sind. Genau das drücken die `null`-Felder von
///    [MapCameraChange] aus.
///
/// [MapCameraImmediate] und keine Animation: die Quelle springt.
MapCameraCommand compassLongPressIntent({MapPosition? target}) =>
    MapCameraCommand(
      change: MapCameraChange(
        center: target,
        zoom: target == null ? null : hardResetZoom,
        bearing: hardResetBearing,
        pitch: hardResetPitch,
      ),
      motion: const MapCameraImmediate(),
      origin: MapCameraIntentOrigin.discovery,
      releasesBearingLock: true,
      clearsFollowAnchor: true,
    );
