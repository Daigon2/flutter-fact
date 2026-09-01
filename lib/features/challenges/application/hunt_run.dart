/// Die Phasenmaschine einer laufenden Solo-Jagd, `app.jsx:903-960`.
///
/// ## Warum diese Datei in `application/` liegt und nicht in `domain/`
///
/// [HuntRun] hält einen [HuntPlan], und der trägt einen [Fact] und ein
/// [FactPuzzle], also Wertobjekte der Domäne `facts`. Die Begründung, warum
/// das denselben Ausschlag ergibt wie bei [HuntPlan] selbst, steht bereits
/// ausführlich im Kopfkommentar von `hunt_plan.dart` unter „Warum diese Typen
/// in `application/` liegen und nicht in `domain/`"; sie wird hier bewusst
/// nicht wiederholt, sondern nur referenziert.
///
/// ## Rein, unveränderlich, ohne Uhr
///
/// Kein Riverpod-Import, kein Widget, keine `DateTime.now()`. Jeder
/// Übergang ([unlockHint], [solveStop], [skipStop], [collectStop]) gibt ein
/// **neues** [HuntRun] zurück; das alte bleibt unverändert nutzbar. Die
/// Listen [HuntRun.stops] und [HuntRun.unlockedHintIndices] sind
/// `List.unmodifiable`.
///
/// ## `isFinished` ist abgeleitet, kein Feld
///
/// Die Quelle prüft `allDone = stops.every(s => s.status === 'solved' ||
/// s.status === 'skipped')`. **`collected` zählt ausdrücklich nicht als
/// erledigt.** Das bedeutet: ein Fakt kann an seiner Station eingesammelt
/// sein (`collectStop`), ohne dass sein Rätsel gelöst ist, und die Jagd gilt
/// trotzdem noch nicht als fertig, solange diese Station weder `solved` noch
/// `skipped` ist.
///
/// ## Keine Zeitstempel
///
/// Die Quelle schreibt bei jedem Lösen `solvedAt` und, wenn `allDone` gilt,
/// `finishedAt`. Beides fehlt hier, und das ist begründet, nicht vergessen:
/// `finishedAt` wird in `screen-challenge.jsx:2954` als **Dauer** gelesen,
/// und daran hängt E-19, „der Client rechnet keine Zeit, an der eine
/// Belohnung hängt". Zeitstempel gehören zu Schritt 39 und zum
/// Backend-Auftrag. **Wer sie hier beiläufig nachträgt, bricht E-19.**
///
/// ## `unlockedHintIndices` gehört dem Lauf, nicht der Station
///
/// Die Quelle hält den Hinweiszustand einer Station in Komponentenzustand
/// und setzt ihn bei Stationswechsel zurück (`screen-map.jsx:1016-1023`).
/// [ActiveHunt] speichert genau **eine** Liste, nicht eine je Station, und
/// [HuntRun] bildet das hier ab: die Liste liegt am Lauf und wird bei jedem
/// tatsächlichen Wechsel der aktuellen Station (in [solveStop] oder
/// [skipStop]) auf leer zurückgesetzt. Bleibt der Zeiger stehen, weil es
/// keine nächste offene Station gibt, bleibt auch die Liste stehen; das
/// entspricht der Quelle, deren Rücksetz-Effekt an einer Änderung von
/// `currentStopIdx` hängt und nicht feuert, wenn sich der Wert nicht ändert.
///
/// Der erste Hinweis ist immer offen, siehe [isHuntHintFree], ganz gleich, ob
/// er in dieser Liste steht oder nicht; die Liste führt ihn deshalb nie mit,
/// exakt wie [ActiveHunt.unlockedHintIndices] das für die gespeicherte
/// Nutzlast schon hält.
///
/// ## Die Weiterschaltregel, wörtlich
///
/// `stops.findIndex((s, i) => i > stopIdx && s.status === 'pending')`. Das
/// gilt für [solveStop] **und** [skipStop] gleichermaßen. Zwei Folgen davon:
///
/// * **Eine übersprungene Station wird nie wieder angelaufen.** Sie zählt
///   nicht mehr als `pending`, also findet sie kein späterer Suchlauf mehr,
///   auch wenn sie vor der aktuellen Station liegt.
/// * **Nach der letzten Station bleibt der Zeiger stehen**, statt an den
///   Anfang umzulaufen: gibt es keine Station mit `pending` und größerem
///   Index, bleibt [HuntRun.currentStopIndex], wo er war.
///
/// ## `solveStop` nimmt einen Index
///
/// Genau wie die Quelle, obwohl heute nur die aktuelle Station lösbar ist:
/// der übergebene `index` ist im heutigen Aufrufer immer
/// [HuntRun.currentStopIndex]. Die Weiterschaltsuche sucht ab **diesem**
/// Index, nicht ab dem alten [HuntRun.currentStopIndex], exakt wie
/// `i > stopIdx` in der Quelle es tut; das ist heute derselbe Wert, muss es
/// aber nicht bleiben.
///
/// ## `toActiveHunt()` und die Bedeutung von `null`
///
/// [ActiveHunt.tryFrom] prüft Werte, die aus jeder Herkunft ankommen können,
/// also auch aus einer wiederhergestellten Nutzlast mit kaputten Feldern.
/// Ein [HuntRun], der aus [HuntRun.start] entsteht und nur über die
/// Übergänge dieser Datei verändert wurde, kann seine eigenen Zusicherungen
/// nicht verletzen: [currentStopIndex] liegt immer in
/// `[0, stops.length - 1]`, also liegt `stationOrdinal` immer in
/// `[1, stationCount]`; [unlockedHintIndices] enthält nie einen negativen
/// Index, weil [unlockHint] über [isHuntHintFree] jeden Index außerhalb von
/// `[0, huntHintCount)` mit einem `RangeError` abweist, bevor er in die Liste
/// kommt. Ein `null` aus [toActiveHunt] zeigt deshalb **nicht** auf einen
/// Fehler dieser Phasenmaschine, sondern auf eine nicht-endliche oder
/// außerhalb von ±90/±180 liegende Koordinate am zugrunde liegenden [Fact]:
/// ein Datenfehler, der schon vor dieser Datei entstanden ist. Der Aufrufer
/// (die Persistenzschicht aus Schritt 36) behandelt `null` deshalb wie „keine
/// speicherbare Jagd", genau wie ADR-007 es für [ActiveHunt] selbst verlangt:
/// verwerfen statt reparieren, nicht werfen.
library;

import 'dart:math' as math;

import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:fact_app/features/challenges/domain/hunt_hints.dart';

/// Der Zustand einer einzelnen Station im Verlauf einer Jagd.
enum HuntStopStatus {
  /// Noch nicht dran gewesen. Der Ausgangszustand jeder Station.
  pending,

  /// Der Fakt an dieser Station wurde eingesammelt (`huntCollectStop`).
  ///
  /// **Zählt nicht als erledigt.** Siehe [HuntRun.isFinished].
  collected,

  /// Das Rätsel an dieser Station wurde gelöst (`huntSolveStop`).
  solved,

  /// Die Station wurde übersprungen (`huntSkipStop`), ohne sie zu lösen.
  skipped,
}

/// Eine Station, so wie sie im Verlauf eines [HuntRun] dasteht: die
/// unveränderliche Auswahl aus [HuntPlan] plus das, was der Lauf selbst
/// daran fortschreibt.
final class HuntRunStop {
  const HuntRunStop._({
    required this.stop,
    required this.status,
    required this.hintCostSpent,
    required this.pointsAwarded,
    required this.hintUsed,
  });

  /// Die unveränderliche Auswahl des Generators: Ort und Rätsel.
  final HuntStop stop;

  /// Der Fortschritt an dieser Station.
  final HuntStopStatus status;

  /// Summe der Kosten aller an dieser Station freigeschalteten Hinweise, in
  /// Coins vom Fakt-Lohn (`app.jsx:927-935`, `huntHintCosts`).
  ///
  /// Bleibt auch nach [HuntRun.solveStop] stehen: die Quelle löscht
  /// `hintCostSpent` beim Lösen nicht, sie liest es nur einmal für die
  /// Abzugsrechnung.
  final int hintCostSpent;

  /// Die dem Spieler gutgeschriebenen Punkte, **nach** Abzug von
  /// [hintCostSpent]. Null, solange die Station nicht [HuntStopStatus.solved]
  /// ist.
  final int pointsAwarded;

  /// Ob beim Lösen dieser Station ein Hinweis benutzt wurde.
  final bool hintUsed;

  /// Neue Kopie mit denselben Feldern außer den genannten.
  HuntRunStop _copyWith({
    HuntStopStatus? status,
    int? hintCostSpent,
    int? pointsAwarded,
    bool? hintUsed,
  }) => HuntRunStop._(
    stop: stop,
    status: status ?? this.status,
    hintCostSpent: hintCostSpent ?? this.hintCostSpent,
    pointsAwarded: pointsAwarded ?? this.pointsAwarded,
    hintUsed: hintUsed ?? this.hintUsed,
  );
}

/// Der Zustand einer laufenden Solo-Jagd, `app.jsx`s `activeHunt`-Reducer.
///
/// Siehe den Kopfkommentar dieser Datei für die Übergangsregeln.
final class HuntRun {
  const HuntRun._({
    required this.plan,
    required this.stops,
    required this.currentStopIndex,
    required this.points,
    required this.unlockedHintIndices,
  });

  /// Beginnt eine neue Jagd: jede Station `pending`, der Zeiger auf der
  /// ersten, keine Punkte, keine freigeschalteten Hinweise.
  static HuntRun start(HuntPlan plan) => HuntRun._(
    plan: plan,
    stops: List<HuntRunStop>.unmodifiable(<HuntRunStop>[
      for (final HuntStop stop in plan.stops)
        HuntRunStop._(
          stop: stop,
          status: HuntStopStatus.pending,
          hintCostSpent: 0,
          pointsAwarded: 0,
          hintUsed: false,
        ),
    ]),
    currentStopIndex: 0,
    points: 0,
    unlockedHintIndices: List<int>.unmodifiable(const <int>[]),
  );

  /// Der Plan, aus dem dieser Lauf entstanden ist. Unveränderlich über die
  /// gesamte Jagd.
  final HuntPlan plan;

  /// Die Stationen in Laufreihenfolge, mit ihrem jeweiligen Fortschritt.
  final List<HuntRunStop> stops;

  /// Index der Station, die gerade dran ist, **0-basiert**.
  ///
  /// Siehe „Die Weiterschaltregel" im Kopfkommentar für die Regel, nach der
  /// sich dieser Wert ändert.
  final int currentStopIndex;

  /// Die insgesamt in diesem Lauf gesammelten Punkte, Summe der
  /// [HuntRunStop.pointsAwarded] jeder gelösten Station.
  final int points;

  /// Indizes der an der **aktuellen** Station freigeschalteten Hinweise,
  /// aufsteigend sortiert, ohne Duplikate, `List.unmodifiable`. Enthält nie
  /// den Index eines gratis Hinweises, siehe [isHuntHintFree] und den
  /// Kopfkommentar.
  final List<int> unlockedHintIndices;

  /// Ob die Jagd fertig ist: jede Station ist [HuntStopStatus.solved] oder
  /// [HuntStopStatus.skipped]. **`collected` zählt nicht mit**, siehe den
  /// Kopfkommentar.
  bool get isFinished => stops.every(
    (HuntRunStop stop) =>
        stop.status == HuntStopStatus.solved ||
        stop.status == HuntStopStatus.skipped,
  );

  /// Die Station, die gerade dran ist.
  HuntRunStop get currentStop => stops[currentStopIndex];

  /// Schaltet den Hinweis an [hintIndex] für die aktuelle Station frei.
  ///
  /// Addiert `huntHintCosts[hintIndex]` auf
  /// [HuntRunStop.hintCostSpent] der aktuellen Station und nimmt den Index in
  /// [unlockedHintIndices] auf. Ist der Hinweis bereits freigeschaltet, oder
  /// ist er gratis ([isHuntHintFree]), ändert sich nichts: weder an der
  /// Liste noch an den Kosten. Ein Index außerhalb von
  /// `[0, huntHintCount)` ist ein Programmfehler des Aufrufers, kein
  /// ungeprüfter Fremdwert, und wird deshalb wie in [isHuntHintFree] mit
  /// einem `RangeError` abgewiesen statt still ignoriert.
  HuntRun unlockHint(int hintIndex) {
    final bool alreadyUnlocked =
        isHuntHintFree(hintIndex) || unlockedHintIndices.contains(hintIndex);
    if (alreadyUnlocked) {
      return this;
    }
    final int cost = huntHintCosts[hintIndex];
    final List<int> newUnlockedHintIndices = List<int>.unmodifiable(
      <int>{...unlockedHintIndices, hintIndex}.toList()..sort(),
    );
    final List<HuntRunStop> newStops =
        List<HuntRunStop>.unmodifiable(<HuntRunStop>[
          for (int i = 0; i < stops.length; i++)
            if (i == currentStopIndex)
              stops[i]._copyWith(hintCostSpent: stops[i].hintCostSpent + cost)
            else
              stops[i],
        ]);
    return HuntRun._(
      plan: plan,
      stops: newStops,
      currentStopIndex: currentStopIndex,
      points: points,
      unlockedHintIndices: newUnlockedHintIndices,
    );
  }

  /// Löst die Station an [index].
  ///
  /// Zieht [HuntRunStop.hintCostSpent] dieser Station von [pointsAwarded] ab,
  /// nie unter null (`Math.max(0, …)` der Quelle), addiert das Ergebnis auf
  /// [points] und schaltet nach der in „Die Weiterschaltregel" beschriebenen
  /// Regel weiter. Ändert sich dabei die aktuelle Station tatsächlich, wird
  /// [unlockedHintIndices] auf leer zurückgesetzt.
  ///
  /// `index` ist heute immer [currentStopIndex], siehe den Kopfkommentar.
  HuntRun solveStop(
    int index, {
    required int pointsAwarded,
    required bool hintUsed,
  }) {
    RangeError.checkValidIndex(index, stops, 'index');
    final int netPoints = math.max(
      0,
      pointsAwarded - stops[index].hintCostSpent,
    );
    final List<HuntRunStop> newStops =
        List<HuntRunStop>.unmodifiable(<HuntRunStop>[
          for (int i = 0; i < stops.length; i++)
            if (i == index)
              stops[i]._copyWith(
                status: HuntStopStatus.solved,
                pointsAwarded: netPoints,
                hintUsed: hintUsed,
              )
            else
              stops[i],
        ]);
    return _advanceFrom(index, newStops, points: points + netPoints);
  }

  /// Überspringt die Station an [index], ohne sie zu lösen.
  ///
  /// Dieselbe Weiterschalt- und Fertig-Regel wie [solveStop]. Punkte bleiben
  /// unverändert, denn eine übersprungene Station trägt keine.
  HuntRun skipStop(int index) {
    RangeError.checkValidIndex(index, stops, 'index');
    final List<HuntRunStop> newStops =
        List<HuntRunStop>.unmodifiable(<HuntRunStop>[
          for (int i = 0; i < stops.length; i++)
            if (i == index)
              stops[i]._copyWith(status: HuntStopStatus.skipped)
            else
              stops[i],
        ]);
    return _advanceFrom(index, newStops, points: points);
  }

  /// Markiert den Fakt an [index] als eingesammelt.
  ///
  /// Ändert ausschließlich [HuntRunStop.status]. Kein Punktezuwachs, keine
  /// Weiterschaltung, keine Rücksetzung der Hinweise: `huntCollectStop` der
  /// Quelle tut nichts anderes.
  HuntRun collectStop(int index) {
    RangeError.checkValidIndex(index, stops, 'index');
    final List<HuntRunStop> newStops =
        List<HuntRunStop>.unmodifiable(<HuntRunStop>[
          for (int i = 0; i < stops.length; i++)
            if (i == index)
              stops[i]._copyWith(status: HuntStopStatus.collected)
            else
              stops[i],
        ]);
    return HuntRun._(
      plan: plan,
      stops: newStops,
      currentStopIndex: currentStopIndex,
      points: points,
      unlockedHintIndices: unlockedHintIndices,
    );
  }

  /// Gemeinsame Weiterschaltung für [solveStop] und [skipStop].
  ///
  /// Sucht die erste Station mit [HuntStopStatus.pending] und einem Index
  /// größer als [fromIndex] in [newStops]; findet sie keine, bleibt
  /// [currentStopIndex] stehen. Ändert sich der Zeiger dabei tatsächlich,
  /// wird [unlockedHintIndices] geleert.
  HuntRun _advanceFrom(
    int fromIndex,
    List<HuntRunStop> newStops, {
    required int points,
  }) {
    int newCurrentStopIndex = currentStopIndex;
    for (int i = fromIndex + 1; i < newStops.length; i++) {
      if (newStops[i].status == HuntStopStatus.pending) {
        newCurrentStopIndex = i;
        break;
      }
    }
    final bool advanced = newCurrentStopIndex != currentStopIndex;
    return HuntRun._(
      plan: plan,
      stops: newStops,
      currentStopIndex: newCurrentStopIndex,
      points: points,
      unlockedHintIndices: advanced
          ? List<int>.unmodifiable(const <int>[])
          : unlockedHintIndices,
    );
  }

  /// Projiziert den Lauf auf das dauerhafte Lesemodell aus `challenges/domain`.
  ///
  /// `stationOrdinal` ist [currentStopIndex] eins-basiert, `stationCount` die
  /// Zahl der Stationen, `stationTitle` und die Lage kommen vom [Fact] und
  /// von [HuntStop.position] der aktuellen Station. Zur Bedeutung eines
  /// `null`-Ergebnisses siehe den Kopfkommentar dieser Datei.
  ActiveHunt? toActiveHunt() {
    final HuntRunStop current = currentStop;
    return ActiveHunt.tryFrom(
      stationOrdinal: currentStopIndex + 1,
      stationCount: stops.length,
      stationTitle: current.stop.fact.canonicalTitle,
      stationLatitude: current.stop.position.latitude,
      stationLongitude: current.stop.position.longitude,
      unlockedHintIndices: unlockedHintIndices,
      difficulty: plan.difficulty,
      duration: plan.duration,
    );
  }
}
