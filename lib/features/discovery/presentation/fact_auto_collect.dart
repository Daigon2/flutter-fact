/// Das automatische Sammeln: was passiert, wenn man einem Fakt einfach nahe
/// kommt, ohne etwas anzutippen.
///
/// ## Diese Mechanik stand auf keiner Liste
///
/// Gefunden am 02.09.2026 beim Zuschnitt von Schritt 22, aufgenommen als
/// E-68. In `lib/` gab es davon keine Zeile, und `REBUILD_STATUS.md` hatte
/// kein Wort dazu; gesucht wurde nach `autoOpen`, `autoToast`, „automatisch
/// öffnen", „30 Meter" und „20 Meter".
///
/// **Sie verschiebt, was Schritt 20 eigentlich ist.** Der Tipp aus Schritt 20
/// ist nur für die **mittlere** Entfernung nötig, zwischen dem Radius hier und
/// [factProximityRadiusInMeters]. Wer nah genug herangeht, sammelt ohne jede
/// Eingabe, und das Fakt-Blatt öffnet sich als Folge davon.
///
/// ## Der Ablauf in der Quelle, `screen-map.jsx:1471-1489`
///
/// `scanAutoOpenRef` läuft bei **jeder** neuen Ortung (`:2650`) und zusätzlich
/// 600 Millisekunden nachdem ein Blatt geschlossen wurde (`:1544`, mit dem
/// Kommentar „maybe the user is still standing near another fact"). Er sucht
/// den **nächstgelegenen** Fakt, der
///
///  * eine Koordinate hat,
///  * noch nicht gesammelt ist,
///  * in dieser Sitzung noch nicht automatisch ausgelöst wurde,
///  * und höchstens [factAutoCollectRadiusInMeters] entfernt ist,
///
/// merkt ihn in `autoOpenedRef` und ruft `triggerCollect`. Übersprungen wird
/// der ganze Scan, solange ein Fakt-Blatt offen ist (`:1474`) oder eine
/// Sammel-Animation läuft (`:1475`).
///
/// ## Drei Dinge stimmen an der Fundstelle nicht
///
/// Alle drei am 02.09.2026 nachgemessen und nach der Regel aus `CLAUDE.md`
/// getrennt: das **Verhalten** ist die Referenz, ein **gemessener Defekt** ist
/// ein Fund und keine Vorlage.
///
/// 1. **Der Kommentar sagt 30 Meter, der Code prüft 18** (`d <= 18` in
///    `:1483` gegen „when entering 30m" in `:1470`). Gebaut ist das
///    Verhalten, also 18, siehe [factAutoCollectRadiusInMeters].
/// 2. **Der Kommentar sagt „pop a fact's full sheet", der Code sammelt.** Der
///    Unterschied ist keine Wortklauberei: `triggerCollect` ruft
///    `onCollectFact` und bucht damit die Belohnung. Das Blatt ist nur die
///    Folge 1400 Millisekunden später. Wer nur den Kommentar liest, hält
///    diese Mechanik für eine Anzeige; sie ist eine Buchung.
/// 3. **Die 20-Meter-Meldung ist tote Anzeige.** Der Kasten wird gerendert
///    (`:3808-3822`), aber `setAutoToast` wird in der **ganzen** PWA nie
///    aufgerufen; die einzige Fundstelle ist die Deklaration (`:1370`). Sie
///    wird nicht nachgebaut. Was dort stehen soll, ist eine Inhaltsfrage, und
///    erfundener Nutzertext ist nach derselben Linie wie bei E-28 keine
///    Lösung.
///
/// ## Und eine Bauform der Quelle wird ausdrücklich nicht übernommen
///
/// `onCollectFact` beginnt mit `if (!requireAuth()) return;`
/// (`app.jsx:681`). In der Quelle springt einem also beim **Vorbeigehen**
/// eine Anmeldeaufforderung entgegen, ohne dass man etwas angetippt hat. Der
/// Neubau hat für das Sammeln überhaupt keine Anmeldeschranke, und ob es eine
/// geben soll, ist die offene Hälfte von E-68. Die schlechteste der
/// Möglichkeiten ist jedenfalls die der Quelle.
library;

import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Bis zu welcher Entfernung ohne Zutun gesammelt wird, `d <= 18` in
/// `screen-map.jsx:1483`.
///
/// **18 und nicht 30**, obwohl der Kommentar drei Zeilen darüber „30m" sagt.
/// Das Verhalten ist die Referenz, siehe den Kopf dieser Datei.
///
/// ## Der Vergleich ist `<=`, anders als beim Tipp
///
/// Und das ist kein Versehen. E-67 hält für die **150** fest, dass die Quelle
/// sich an derselben Zahl dreimal widerspricht und der Neubau sich deshalb auf
/// das ausschließende `<` festlegen musste. Diese 18 hat genau **eine**
/// Fundstelle, und die ist einschließend. Es gibt hier nichts zu vereinheitlichen,
/// also folgt der Neubau ihr. Wer die beiden Zeichen angleicht, weil sie
/// nebeneinander ungleich aussehen, ändert eine gemessene Regel.
const double factAutoCollectRadiusInMeters = 18;

/// Ob bei [distanceInMeters] von selbst gesammelt wird.
///
/// ## Eine eigene Funktion, und der Grund ist gemessen
///
/// Dieselbe Falle wie bei `factTapCollectsAt`, und sie ist beim Schreiben der
/// Tests dieser Datei ein zweites Mal aufgeschlagen. **Genau 18,0 Meter sind
/// über zwei Koordinaten nicht erreichbar.** Eine Bisektion über die
/// Breitendifferenz landet auf dem Wert direkt darunter und springt von dort
/// über 18 hinweg; `2 * R * asin(sqrt(a))` hat dort keine feinere Auflösung.
///
/// Ein Test, der den Rand über Koordinaten anfährt, ist deshalb **blind
/// gegenüber der Wahl zwischen `<=` und `<`**: beide nehmen den erreichbaren
/// Wert an. Er sieht aus, als prüfe er den Rand, und prüft ihn nicht. Genau
/// diese Zusicherung hat `fact_proximity_test.dart` bei der 150 verloren, und
/// dort steht sie bis heute nicht (der offene Rest von E-67).
///
/// Mit einer Zahl statt zwei Koordinaten ist der Rand exakt prüfbar.
bool factAutoCollectsAt(double distanceInMeters) =>
    distanceInMeters <= factAutoCollectRadiusInMeters;

/// Wie lange nach dem Schließen des Fakt-Blatts erneut gesucht wird,
/// `setTimeout(..., 600)` in `screen-map.jsx:1544`.
///
/// Der Kommentar dort nennt den Grund: „small delay so the close animation
/// finishes before the next pop". **Ohne diese zweite Suche wäre die Mechanik
/// nicht kaputt, nur langsamer**: die nächste Ortung löst sie ohnehin aus. Die
/// Quelle will den Fall nicht abwarten, dass jemand vor zwei Fakten steht,
/// das erste Blatt schließt und dann auf ein GPS-Signal warten müsste.
const Duration factAutoCollectRescanDelay = Duration(milliseconds: 600);

/// Der Fakt, der bei [user] von selbst eingesammelt wird, oder `null`.
///
/// [candidates] sind die Punkte der Fakt-Überlagerung, [isEligible] sagt für
/// eine Kennung, ob sie überhaupt in Frage kommt: die Quelle schließt hier die
/// schon gesammelten und die in dieser Sitzung schon ausgelösten aus
/// (`:1479-1480`).
///
/// ## Warum eine reine Funktion und kein Zweig im Widget
///
/// Aus dem Grund, den `factTapCollectsAt` teuer gelernt hat: eine Regel, die
/// nur über zwei Koordinaten und ein Widget erreichbar ist, hat einen Rand,
/// den kein Test sehen kann. Hier sind es sogar drei Entscheidungen in einer
/// Zeile (der Rand, die Auswahl des Nächstgelegenen und die Reihenfolge bei
/// Gleichstand), und jede einzelne ist so prüfbar.
///
/// **Der Nächstgelegene und nicht der erste im Radius.** Die Quelle sucht mit
/// `d <= 18 && d < nearestD` weiter, auch wenn sie schon einen hat. Bei
/// Gleichstand gewinnt der **frühere** in [candidates], weil `<` den späteren
/// nicht durchlässt; das ist bei zwei Fakten an derselben Stelle die einzige
/// Stelle, an der die Reihenfolge der Liste durchschlägt.
///
/// Punkte ohne Koordinate gibt es hier nicht. Die Quelle prüft `if (!f.lat ||
/// !f.lng) continue` (`:1478`), weil `window.FACTS` Rohdaten sind; eine
/// [MapOverlayPoint] hat ihre Lage im Typ.
///
/// Zurück kommt der **Punkt** und nicht seine Kennung, weil der Aufrufer die
/// Lage sofort wieder braucht: der Münzflug startet an der Bildschirmstelle
/// des Ballons. Die Kennung allein zwänge ihn, die Liste ein zweites Mal zu
/// durchsuchen.
MapOverlayPoint? pickAutomaticCollect({
  required MapPosition user,
  required Iterable<MapOverlayPoint> candidates,
  required bool Function(String factId) isEligible,
}) {
  MapOverlayPoint? nearest;
  double nearestDistance = double.infinity;
  for (final MapOverlayPoint point in candidates) {
    if (!isEligible(point.id)) {
      continue;
    }
    final double distance = user.distanceInMetersTo(point.position);
    if (factAutoCollectsAt(distance) && distance < nearestDistance) {
      nearest = point;
      nearestDistance = distance;
    }
  }
  return nearest;
}
