/// Die Auto-Neigung: je näher die Karte, desto schräger die Kamera.
///
/// Nachbau von `02_Frontend/app/screen-map.jsx:1755-1765`. Die Quelle hängt sie
/// an `zoomend` und rechnet den Sollwinkel aus der Zoomstufe.
///
/// ## Warum die Rechnung hier steht und nicht in `map/domain/`
///
/// Der Kommentar von `MapCameraThresholds` sagt es schon: die 2-Grad-Schwelle
/// ist **kein Urteil des Gates über eine vorhandene Absicht, sondern die
/// Frage, ob es überhaupt eine gibt**. Wer den Sollwinkel schon erreicht hat,
/// gibt gar keine Absicht ab. Dieselbe Trennung wie bei der Kompassglättung
/// (`screen-map.jsx:2831`): was **vor** der Absicht passiert, gehört dem Host.
///
/// ## Der eine echte Aufrufer der Domäne in Schritt 12
///
/// [MapCameraIntentOrigin.mapHost] gibt es genau für diesen Fall: die
/// Auto-Neigung reagiert auf die Kamera selbst und gehört keinem Feature.
library;

import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';

/// Zoomstufe, ab der die Karte flach von oben gezeigt wird.
///
/// `screen-map.jsx:1756`: `if (z <= 11) return 0;`. Der Kommentar darüber
/// nennt den Grund: weit draußen soll man Cluster auf einer Weltsicht sehen.
const double mapAutoPitchFlatZoom = 11;

/// Zoomstufe, ab der die volle Neigung gilt.
///
/// `screen-map.jsx:1757`: `if (z >= 15) return 58;`.
const double mapAutoPitchFullZoom = 15;

/// Die volle Neigung in Grad.
///
/// `screen-map.jsx:1757`. **Die Zahl ist 58 und nicht 65 oder 75**, obwohl der
/// Kommentar drei Zeilen darüber (`:1752-1753`) noch von 65 und 75 spricht:
/// der Kommentar ist mit der Änderung nicht mitgezogen worden, der Code sagt
/// `58 // PoGo-Kamerawinkel (vorher 75 = zu steil)`. Maßgeblich ist der Code.
const double mapAutoPitchFullDegrees = 58;

/// Ab welcher Abweichung vom Sollwinkel überhaupt geneigt wird.
///
/// `screen-map.jsx:1764`: `if (Math.abs(cur - target) > 2)`. **Echt größer**,
/// genau 2 Grad lösen also nichts aus.
const double mapAutoPitchThresholdDegrees = 2;

/// Wie lange die Auto-Neigung animiert.
///
/// `screen-map.jsx:1764`: `map.easeTo({ pitch: target, duration: 300 })`.
const Duration mapAutoPitchDuration = Duration(milliseconds: 300);

/// Der Sollwinkel der Kamera zur Zoomstufe [zoom], in Grad.
///
/// Flach bis [mapAutoPitchFlatZoom], voll ab [mapAutoPitchFullZoom], dazwischen
/// linear. Gleiche Rechnung wie `screen-map.jsx:1755-1759`, einschließlich der
/// Form `((z - 11) / 4) * 58`.
double mapAutoPitchForZoom(double zoom) {
  if (zoom <= mapAutoPitchFlatZoom) {
    return 0;
  }
  if (zoom >= mapAutoPitchFullZoom) {
    return mapAutoPitchFullDegrees;
  }
  return ((zoom - mapAutoPitchFlatZoom) /
          (mapAutoPitchFullZoom - mapAutoPitchFlatZoom)) *
      mapAutoPitchFullDegrees;
}

/// Die Absicht, [view] auf ihren Sollwinkel zu neigen, oder `null`.
///
/// `null` heißt: die Neigung liegt nah genug am Sollwert, es gibt nichts zu
/// tun. Das ist die Entsprechung zu `screen-map.jsx:1764`, wo ohne diese
/// Prüfung gar kein `easeTo` entsteht.
///
/// Die Absicht ändert **nur** die Neigung. Alle anderen Felder von
/// [MapCameraChange] bleiben `null` und heißen damit „unverändert lassen",
/// genau wie `easeTo({ pitch: target, duration: 300 })` Mittelpunkt, Zoom und
/// Blickrichtung stehen lässt.
///
/// [MapCameraOneShot.yieldsToRunningAnimation] ist `true`: das ist der Wächter
/// `if (map.isEasing()) return;` aus `:1761`. Eine laufende `flyTo`/`easeTo`
/// setzt die Neigung selbst, und die Automatik würde ihr ins Steuer greifen.
MapCameraOneShot? mapAutoPitchIntent(MapCameraView view) {
  final double target = mapAutoPitchForZoom(view.zoom);
  if ((view.pitch - target).abs() <= mapAutoPitchThresholdDegrees) {
    return null;
  }
  return MapCameraOneShot(
    change: MapCameraChange(pitch: target),
    motion: const MapCameraAnimated(mapAutoPitchDuration),
    origin: MapCameraIntentOrigin.mapHost,
    yieldsToRunningAnimation: true,
  );
}
