/// Der Audio-Beacon: der Hinweiston, wenn man einem Fakt nahe kommt.
/// Schritt 26.
///
/// ## Was die Quelle tut, `screen-map.jsx:2690-2718`
///
/// Bei jeder Ortung, und nur im Modus „Fakt-Finder" mit eingeschaltetem
/// Audio-Modus:
///
///  1. **Höchstens alle fünf Sekunden**, `now - lastBeaconAtRef.current >
///     5000` (`:2694`). Die Sperre steht **vor** der Suche, es gibt also
///     höchstens einen Ton je Fenster, nicht einen je Fakt.
///  2. Über alle Fakten laufen, die noch nicht gesammelt sind (`:2699`).
///  3. Für jeden die Entfernung bilden und den **Merkzustand** fortschreiben:
///     weiter als 200 Meter setzt ihn auf „draußen", näher als 150 Meter und
///     noch nicht „drinnen" macht ihn zum Kandidaten (`:2703-2710`).
///  4. Vom nächstgelegenen Kandidaten den Merkzustand auf „drinnen" setzen,
///     die Uhr stellen, die Peilung bilden und den Ton auslösen
///     (`:2711-2717`).
///
/// ## Die Hysterese ist der Kern, und sie ist leicht zu übersehen
///
/// Zwischen 150 und 200 Metern passiert **nichts**: ein Fakt, der einmal
/// „drinnen" war, bleibt es, bis man sich über 200 Meter entfernt. Ohne diese
/// Spanne bekäme jemand, der an der Grenze steht und sich um zwei Meter
/// bewegt, alle fünf Sekunden denselben Ton. Wer die 200 auf 150 zieht, weil
/// zwei Zahlen für dieselbe Grenze wie ein Versehen aussehen, baut genau das.
///
/// ## Was hier bewusst fehlt
///
/// **Der Tour-Zweig** (`:2721-2733`), der im Tour-Modus den nächsten
/// ungesammelten Stopp vorliest. Er braucht `tourRoute` und `tourReady`, also
/// Phase 6, und wäre hier Vorrat (ADR-002).
///
/// **Die iOS-Gestensperre** (`window.__factAudioGestureOk`, `:2692`). Eine
/// Regel des Browsers und keine der Plattform, ausführlich begründet in
/// `fact_page.dart` beim Vorlesen.
library;

import 'dart:math' as math;

import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Wie oft der Hinweiston höchstens kommt, `5000` in `screen-map.jsx:2694`.
const Duration factBeaconInterval = Duration(seconds: 5);

/// Ab welcher Entfernung ein Fakt wieder „draußen" ist, `d > 200`
/// (`screen-map.jsx:2703`).
///
/// **Echt größer**, genau 200,0 lässt den Zustand also stehen. Die zweite
/// Zahl neben [factProximityRadiusInMeters] ist kein Versehen, sondern die
/// Hysterese; siehe den Kopf dieser Datei.
const double factBeaconResetInMeters = 200;

/// Wie lange zwischen Ton und Ansage liegt,
/// `await new Promise(r => setTimeout(r, 300))` in `audio-player.jsx:341`.
///
/// Die Quelle wartet, damit der Ton nicht in den ersten Wörtern untergeht.
const Duration factBeaconSpeechDelay = Duration(milliseconds: 300);

/// Ob bei [distanceInMeters] ein Hinweiston fällig wird.
///
/// `d < 150` (`screen-map.jsx:2705`), also **ausschließend**, und damit
/// dieselbe Wahl wie [factTapCollectsAt] und dieselbe Zahl. E-67 hält fest,
/// dass die Quelle sich an dieser 150 mehrfach widerspricht; hier ist sie
/// ausschließend, und der Neubau hat sich darauf festgelegt.
///
/// Als eigene Funktion aus demselben gemessenen Grund wie dort: genau 150,0
/// Meter sind über zwei Koordinaten nicht erreichbar, ein Test am Rand wäre
/// über Koordinaten also blind gegenüber `<` und `<=`.
bool factBeaconFiresAt(double distanceInMeters) =>
    distanceInMeters < factProximityRadiusInMeters;

/// Ob [distanceInMeters] den Merkzustand zurücksetzt.
///
/// `d > 200`, siehe [factBeaconResetInMeters]. Eigene Funktion aus demselben
/// Grund wie [factBeaconFiresAt].
bool factBeaconResetsAt(double distanceInMeters) =>
    distanceInMeters > factBeaconResetInMeters;

/// Die Stunde auf dem Zifferblatt zu einer Peilung, `bearingToClockKey` in
/// `audio-player.jsx:93-97`.
///
/// `Math.round(normalized / 30)`, und `0` wird zu `12`. Die Rundung heißt,
/// dass jede Stunde 30 Grad breit ist und um ihren Mittelpunkt liegt: 15 Grad
/// gehören noch zur 12, 16 Grad schon zur 1.
///
/// **345 Grad und mehr ergeben rechnerisch 12**, weil `round(11.5) = 12`, und
/// nicht `0`: der Sonderfall greift nur für Peilungen unter 15 Grad. Beide
/// Wege enden bei derselben Zahl, was die Fallunterscheidung der Quelle
/// überflüssig aussehen lässt; sie ist es nicht, ohne sie stünde bei Norden
/// eine `0` auf dem Zifferblatt.
int factBeaconClockOf(double bearingInDegrees) {
  final double normalized = ((bearingInDegrees % 360) + 360) % 360;
  final int hour = (normalized / 30).round();
  return hour == 0 ? 12 : hour;
}

/// Die Stereo-Verteilung zu einer Peilung, `bearingToPan` in
/// `audio-player.jsx:99-102`.
///
/// `Math.sin(rad)`: Norden mittig, Osten ganz rechts, Süden wieder mittig,
/// Westen ganz links. **Vorne und hinten klingen damit gleich**, und das ist
/// keine Nachlässigkeit der Quelle, sondern die Grenze von Stereo: zwei
/// Kanäle können eine Richtung auf einem Kreis nicht eindeutig abbilden. Die
/// Ansage sagt deshalb zusätzlich die Uhrzeit, siehe [factBeaconClockOf].
double factBeaconBalanceOf(double bearingInDegrees) =>
    math.sin(bearingInDegrees * math.pi / 180);

/// Ob ein Fakt in dieser Sitzung schon „drinnen" war.
///
/// Der Merkzustand aus `beaconStateRef` (`screen-map.jsx:1343`). Die Quelle
/// führt drei Werte (`undefined`, `'inRange'`, `'left'`), von denen zwei
/// dasselbe bedeuten: `undefined` und `'left'` heißen beide „ein Ton ist
/// wieder fällig". Hier sind es deshalb zwei.
enum FactBeaconState {
  /// Noch nicht angesagt, oder seit dem letzten Mal weit genug entfernt.
  outside,

  /// Angesagt und noch nicht weit genug entfernt gewesen.
  inRange,
}

/// Das Ergebnis einer Suche: wen ansagen, und wie die Merkzustände danach
/// aussehen.
final class FactBeaconScan {
  /// Erzeugt ein Ergebnis.
  const FactBeaconScan({required this.states, this.target, this.bearing});

  /// Der Fakt, der angesagt wird, oder `null`.
  final MapOverlayPoint? target;

  /// Die Peilung zu [target] in Grad, oder `null` ohne Ziel.
  final double? bearing;

  /// Die Merkzustände nach dieser Suche, für die nächste.
  ///
  /// **Vollständig neu und nicht verändert.** Ein Zustand, den der Aufrufer
  /// zwischen zwei Suchen behält, wäre eine zweite Wahrheit; so gibt es genau
  /// eine, und sie kommt aus dieser Funktion.
  final Map<String, FactBeaconState> states;
}

/// Sucht den Fakt, der als Nächstes angesagt wird.
///
/// [candidates] sind die Punkte der Fakt-Überlagerung, [isCollected] sagt für
/// eine Kennung, ob sie schon gesammelt ist, und [states] sind die
/// Merkzustände der vorigen Suche.
///
/// **Die Merkzustände werden für alle Fakten fortgeschrieben, auch für
/// gesammelte?** Nein, und das ist die Quelle: ihr `continue` bei einem
/// gesammelten Fakt (`:2699`) steht **vor** der Entfernungsrechnung, der
/// Zustand eines gesammelten Fakts bleibt also stehen, wie er war. Praktisch
/// spielt es keine Rolle, weil ein gesammelter Fakt nie wieder Kandidat wird;
/// es steht hier, damit die Zeile beim nächsten Lesen nicht wie ein Fehler
/// aussieht.
FactBeaconScan scanForFactBeacon({
  required MapPosition user,
  required Iterable<MapOverlayPoint> candidates,
  required bool Function(String factId) isCollected,
  required Map<String, FactBeaconState> states,
}) {
  final Map<String, FactBeaconState> next = Map<String, FactBeaconState>.of(
    states,
  );
  MapOverlayPoint? target;
  double nearest = double.infinity;
  for (final MapOverlayPoint point in candidates) {
    if (isCollected(point.id)) {
      continue;
    }
    final double distance = user.distanceInMetersTo(point.position);
    if (factBeaconResetsAt(distance)) {
      next[point.id] = FactBeaconState.outside;
      continue;
    }
    if (!factBeaconFiresAt(distance)) {
      // Zwischen 150 und 200 Metern: der Zustand bleibt, wie er war. Das ist
      // die Hysterese, siehe den Kopf dieser Datei.
      continue;
    }
    if (next[point.id] == FactBeaconState.inRange) {
      continue;
    }
    if (distance < nearest) {
      target = point;
      nearest = distance;
    }
  }
  if (target == null) {
    return FactBeaconScan(states: next);
  }
  next[target.id] = FactBeaconState.inRange;
  return FactBeaconScan(
    states: next,
    target: target,
    bearing: user.bearingInDegreesTo(target.position),
  );
}
