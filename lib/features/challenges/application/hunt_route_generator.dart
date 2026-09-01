/// Der Routengenerator der Schnitzeljagd, `02_Frontend/app/hunt-generator.jsx`.
///
/// Reine Funktion: keine Datenbank, kein Netz, kein Sprachmodell. Die Quelle
/// sagt das in ihrem Kopf selbst (`:5`): „pure JS-Funktion, deterministisch
/// bei gegebenem seed". Genau das macht sie zum wertvollsten Prüfgegenstand
/// dieses Blocks, und deshalb liegt sie hier und nicht in einem Notifier.
///
/// ## Warum `application/` und nicht `domain/`
///
/// Sie rechnet auf [Fact] und misst Entfernungen mit
/// [MapPosition.distanceInMetersTo]. Beides sind fremde Domänen, und Gate 6
/// verbietet sie einer Feature-Domäne. Der Grund für **diese** Zeile ist aber
/// nicht nur die Regel: `MapPosition` trägt die Haversine-Rechnung samt dem
/// Erdradius 6371000 aus `screen-map.jsx:297` bereits, und `hunt-generator.jsx`
/// rechnet mit exakt derselben Formel (`:9-16`). Ein vierter Koordinatentyp in
/// `challenges/domain/` würde D-9 ein weiteres Mal auslösen und dabei eine
/// geeichte Rechnung abschreiben.
///
/// ## Was von der Quelle bewusst fehlt
///
/// * **Der Stadt-Filter** (`:110-121`, `:155-159`). `factCity()` fällt dort
///   über `window.detectCity` auf die nächste Pilotstadt zurück, weil `ort`
///   („Marienplatz · Altstadt") nicht auf „München" passt. Der Stadtbegriff
///   ist mit E-11 offen: die Datenbank speichert den Anzeigenamen, das
///   Frontend benutzt Slugs. Deshalb bekommt diese Funktion die Fakten
///   **bereits auf die Stadt eingegrenzt** und entscheidet nichts über
///   Stadt-Identität.
/// * **Die kuratierten Themenrouten** (`:147-152`, `:162-167`, `:231`). Sie
///   stehen in `02_Frontend/app/hunt-routes.jsx`, einer kuratierten Datendatei
///   mit 229 Zeilen, die nach deutschem Stadt-Anzeigenamen verschlüsselt ist
///   (`München:`) und ihre Texte als `name` / `nameEn` im Datensatz trägt,
///   ohne i18n-Schlüssel. Wohin diese Datei im Neubau gehört, ob als Asset und
///   ob mit Drift-Prüfung, ist nicht entschieden und hängt an E-11. Sie wird
///   auch nicht nur hier gebraucht: `screen-map.jsx:1580-1600` baut damit die
///   Tour-Presets. Deshalb fehlt in diesem Schritt beides, die Datei und der
///   Gebiets-Filter, statt dass eine halbe Fassung die spätere Entscheidung
///   festlegt.
/// * **Die Hinweis-Trios** (`:317-338`), siehe `hunt_plan.dart`.
///
/// ## Drei der vier Auswahlstufen laufen im heutigen Bestand nie
///
/// Das ist nicht geschätzt, sondern in Schritt 5 am ausgelieferten Bestand
/// gemessen und an den Feldern von `FactPuzzle` dokumentiert. Die Kaskade ist
/// hier trotzdem vollständig nachgebaut, weil die Pipeline die Felder setzen
/// kann; an jeder toten Stufe steht, warum sie heute niemand erreicht. Ohne
/// diese Vermerke entstünden grüne Tests über Code, den kein Nutzer ausführt.
///
/// **Nicht verwechseln:** der Qualitäts*bonus* im Scoring (`:302-306`) liest
/// `Fact.qualityScore`, also ein Feld am Fakt, und wirkt. Tot ist nur der
/// Vorzugs*filter* auf `FactPuzzle.quality`.
library;

import 'dart:math' as math;

import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Harte Untergrenze zwischen zwei Stationen, `hunt-generator.jsx:125`.
const double huntMinDistanceInMeters = 220;

/// Bevorzugter Abstand, der Gipfel der Gaußkurve, `:126`.
const double huntIdealDistanceInMeters = 420;

/// Breite der Gaußkurve, `:127`.
const double huntSigmaInMeters = 200;

/// Primäres Suchfenster, `:128`.
const double huntMaxPrimaryDistanceInMeters = 850;

/// Ausweichfenster, wenn im primären zu wenig steht, `:129`.
const double huntMaxFallbackDistanceInMeters = 1400;

/// Erste Station bevorzugt so nah am Startpunkt, `:236`.
const double huntFirstStopNearInMeters = 500;

/// Zweite Stufe dafür, `:237`.
const double huntFirstStopFallbackInMeters = 1000;

/// Vorletzte Station höchstens so weit vom ersten Stopp, `:281`.
const double huntPenultimateToStartInMeters = 900;

/// Letzte Station höchstens so weit vom ersten Stopp, `:286`.
const double huntLastToStartInMeters = 600;

/// Zweite Stufe dafür, `:287`.
const double huntLastToStartFallbackInMeters = 1000;

/// Zuschlag für eine Station, die eine noch nicht benutzte Rätselform
/// mitbringt, `:306`.
const double huntFreshTypeBonus = 0.3;

/// `QUALITY_WEIGHT` aus `:302`, Gold, Silber, Bronze.
///
/// Der Schlüssel ist `Fact.qualityScore`, also 1 bis 3. Ein Fakt ohne
/// Einstufung bekommt nichts, wie `|| 0` in der Quelle.
const Map<int, double> huntQualityBonusByScore = <int, double>{
  3: 0.45,
  2: 0.20,
  1: 0,
};

/// Die Gaußkurve um [huntIdealDistanceInMeters], `hunt-generator.jsx:131-134`.
///
/// Unterhalb der Mindestentfernung ist eine Station nicht wählbar; die Quelle
/// gibt dort 0 zurück, und 0 ist zugleich das Minimum der Kurve. Der Filter
/// vorher (`:293`) sortiert solche Kandidaten ohnehin schon aus, diese Zeile
/// ist die zweite Sicherung derselben Regel und wird deshalb mitgenommen.
double huntDistanceScore(double distanceInMeters) {
  if (distanceInMeters < huntMinDistanceInMeters) {
    return 0;
  }
  final double z =
      (distanceInMeters - huntIdealDistanceInMeters) / huntSigmaInMeters;
  return math.exp(-0.5 * z * z);
}

/// Baut eine spielbare Jagd aus [facts] oder gibt `null` zurück.
///
/// [facts] ist der Bestand **einer** Stadt, siehe Kopf dieser Datei. [genres]
/// enthält die Werte, die in `Fact.genre` stehen (`Geschichte`,
/// `Persönlichkeit`, …); leer heißt kein Filter.
///
/// ## [seed] und [startNear] hängen zusammen, und einer von beiden ist tot
///
/// Die Quelle sieht [seed] vor (`:139`), **setzt ihn an ihrer einzigen
/// Aufrufstelle aber nicht** (`screen-challenge.jsx:4338`, die einzige im
/// ganzen Frontend). Dieselbe Aufrufstelle übergibt **immer** einen
/// Startpunkt: sie ist der Rückruf des Startpunkt-Pickers
/// (`handleHotspotPick`, `:4331`), und der hat genau einen Ausgang:
/// `HotspotPickView` ruft `onPick(options[selectedIdx].point)` an genau einer
/// Stelle (`:3088`).
///
/// Damit läuft der Zufallszweig der ersten Station in der PWA **nie**, und mit
/// ihm liegen `huntHashStr` und `huntMulberry32` (`:18-34`) im Auslieferstand
/// brach. Derselbe Vermerk wie an den drei toten Auswahlstufen, und aus
/// demselben Grund: eine Zeile, die aussieht wie ein Nutzerpfad und keiner
/// ist, wird beim nächsten Lesen für einen gehalten.
///
/// Nachgebaut ist der Zweig trotzdem, und zwar nicht auf Vorrat: er ist die
/// einzige Möglichkeit, den Generator ohne Startpunkt-Picker überhaupt zu
/// prüfen, und der Picker ist Schritt 35.
///
/// `null` heißt: keine einzige Station bildbar, weil kein Fakt der Liste ein
/// Rätsel und eine Koordinate hat (`:226`). Eine **zu kurze** Jagd ist
/// dagegen kein Fehlschlag: die Greedy-Schleife bricht ab, sobald kein
/// Kandidat mehr in Reichweite liegt (`:298`), und liefert dann weniger als
/// [duration]`.stopCount` Stationen. Die Quelle prüft danach nur noch auf
/// „gar keine" (`screen-challenge.jsx:4347`).
///
/// ## Warum die Dauer hereinkommt und nicht die Stationszahl
///
/// Die Quelle übergibt beides getrennt: der Bildschirm rechnet die gewählte
/// Dauer in eine Stationszahl um (`screen-challenge.jsx:4332`) und gibt nur
/// diese weiter, während der Generator am Ende eine **dritte** Zahl
/// dazuschreibt (`hunt-generator.jsx:354`). Genau daraus entsteht der
/// Widerspruch, den E-45 beendet.
///
/// Hier gibt es deshalb nur eine Eingabe. Die Stationszahl ist daraus
/// abgeleitet und nicht setzbar; damit können Ansage und Länge nicht
/// auseinanderlaufen, auch nicht durch einen künftigen Aufrufer. Der Preis
/// steht in den Tests: eine Regel, die an der Position im Lauf hängt
/// (vorletzte und letzte Station), muss ihre Fakten so legen, dass die Position
/// bei fünf, sieben oder neun Stationen erreicht wird.
HuntPlan? generateHuntRoute({
  required List<Fact> facts,
  required PuzzleDifficulty difficulty,
  required HuntDuration duration,
  MapPosition? startNear,
  List<String> genres = const <String>[],
  String? seed,
}) {
  // Die einzige Stelle, an der aus der Ansage eine Länge wird.
  final int stopCount = duration.stopCount;

  // `:155-159`, ohne den Stadt-Teil: nur Fakten mit mindestens einem Rätsel
  // und einer Koordinate sind spielbar.
  List<Fact> pool = facts
      .where((Fact fact) => fact.hasPuzzles && fact.coordinates != null)
      .toList();

  // `:169-175`. Weicher Filter: greift nur, wenn danach noch genug Fakten für
  // die volle Länge übrig sind. Sonst bekäme eine Stadt mit wenigen
  // klassifizierten Fakten gar keine Jagd, statt einer thematisch unscharfen.
  if (genres.isNotEmpty) {
    final List<Fact> filtered = pool
        .where((Fact fact) => fact.genre != null && genres.contains(fact.genre))
        .toList();
    if (filtered.length >= stopCount) {
      pool = filtered;
    }
  }

  // `:177-188`, der Findability-Tier.
  //
  // **Tot im heutigen Bestand.** `FactPuzzle.findability` „steht in keinem
  // ausgelieferten Datensatz" (so dokumentiert am Feld selbst), damit liefert
  // [_findabilityOf] immer `null`, der Ausschluss trifft nie und die
  // Tier-Liste lässt alles durch. Nachgebaut, weil die Pipeline das Feld
  // setzen kann.
  //
  // Die Stufen der Auffindbarkeit tragen dieselben Wörter wie die
  // Rätselstufen; `HG_TIER` (`:183`) ist kumulativ, `mittel` erlaubt also
  // `leicht` und `mittel`. Das ist hier die Reihenfolge von
  // [PuzzleDifficulty] und wird daraus abgeleitet statt abgeschrieben.
  final Set<String> allowedFindability = PuzzleDifficulty.values
      .take(difficulty.index + 1)
      .map((PuzzleDifficulty value) => value.code)
      .toSet();
  pool = pool
      .where((Fact fact) => _findabilityOf(fact) != FactPuzzle.notFindable)
      .toList();
  final List<Fact> inTier = pool.where((Fact fact) {
    final String? findability = _findabilityOf(fact);
    return findability == null || allowedFindability.contains(findability);
  }).toList();
  if (inTier.length >= stopCount) {
    pool = inTier;
  }

  // Die Kandidatenauswahl in vier Stufen, `:190-224`. Jede Stufe baut die
  // Liste komplett neu; sie ersetzt die vorige, sie ergänzt sie nicht.

  // Stufe 1, `:193-199`: passende Stufe **und** starkes Rätsel.
  //
  // **Tot im heutigen Bestand.** `FactPuzzle.quality` „kommt im ausgelieferten
  // Bestand nicht vor", also ist `quality >= 2` nie wahr und diese Liste immer
  // leer.
  List<_Candidate> candidates = _candidates(
    pool,
    (FactPuzzle puzzle) =>
        puzzle.difficulty == difficulty &&
        puzzle.quality != null &&
        puzzle.quality! >= 2,
  );

  // Stufe 2, `:201-210`: passende Stufe und geprüfte Herkunft.
  //
  // **Tot im heutigen Bestand**, und zwar aus einem Grund, den man der Zeile
  // nicht ansieht: im gesamten Bestand steht in `confidence` ausschließlich
  // `curated`. Damit ist `confidence === 'verified'` falsch **und**
  // `!confidence` falsch, die Bedingung also nie erfüllt. Die Stufe fällt
  // nicht etwa auf „alles durchlassen" zurück, sie liefert nichts.
  if (candidates.length < stopCount) {
    candidates = _candidates(
      pool,
      (FactPuzzle puzzle) =>
          puzzle.difficulty == difficulty &&
          (puzzle.confidence == 'verified' || puzzle.confidence == null),
    );
  }

  // Stufe 3, `:212-218`: nur noch die Stufe. **Das ist der Weg, den der
  // heutige Bestand nimmt.**
  if (candidates.length < stopCount) {
    candidates = _candidates(
      pool,
      (FactPuzzle puzzle) => puzzle.difficulty == difficulty,
    );
  }

  // Stufe 4, `:220-224`: die gewünschte Stufe kommt gar nicht vor, dann jedes
  // Rätsel. Anders als die Stufen davor greift sie erst bei **null**
  // Kandidaten, nicht schon bei zu wenigen.
  if (candidates.isEmpty) {
    candidates = _candidates(pool, (FactPuzzle puzzle) => true);
  }

  if (candidates.isEmpty) {
    return null;
  }

  final double Function() nextDouble = seed == null
      ? math.Random().nextDouble
      : _mulberry32(_fnv1a(seed));

  // `:230-250`. Ohne Startpunkt zieht die Quelle eine zufällige erste Station;
  // mit Startpunkt die nächstgelegene, siehe [_nearestFirst]. **Der
  // Zufallszweig ist im Auslieferstand unerreichbar**, Begründung oben.
  final _Candidate firstCandidate;
  if (startNear != null) {
    firstCandidate = _nearestFirst(candidates, startNear);
  } else {
    firstCandidate = candidates[(nextDouble() * candidates.length).floor()];
  }

  final MapPosition start = _positionOf(firstCandidate.fact);
  final Set<FactId> used = <FactId>{firstCandidate.fact.id};
  // `null` ist ein möglicher Wert: `FactPuzzle.type` ist nullbar, und die
  // Quelle legt `undefined` genauso in ihr `usedTypes` (`:261`). Zwei Rätsel
  // ohne Typ gelten damit als dieselbe Form, in beiden Fassungen.
  final Set<String?> usedTypes = <String?>{};
  final HuntStop firstStop = _pickStop(firstCandidate, usedTypes);
  usedTypes.add(firstStop.puzzle.type);
  final List<HuntStop> stops = <HuntStop>[firstStop];

  // Die Greedy-Schleife, `:264-315`.
  for (int i = 1; i < stopCount; i++) {
    final MapPosition last = stops.last.position;
    final bool isLastStop = i == stopCount - 1;
    final bool isPenultimate = i == stopCount - 2;

    List<_Reach> reachable = <_Reach>[
      for (final _Candidate candidate in candidates)
        if (!used.contains(candidate.fact.id))
          _Reach(
            candidate: candidate,
            distance: last.distanceInMetersTo(_positionOf(candidate.fact)),
            distanceToStart: start.distanceInMetersTo(
              _positionOf(candidate.fact),
            ),
          ),
    ];

    // `:277-290`: die letzten beiden Stationen ziehen den Weg zurück zum
    // Anfang. Ohne das läuft die Jagd als Linie durch die Stadt, und der
    // Spieler steht am Ende weit von seinem Startpunkt entfernt.
    if (isPenultimate) {
      reachable = _preferOrKeep(reachable, <bool Function(_Reach)>[
        (_Reach reach) =>
            reach.distanceToStart <= huntPenultimateToStartInMeters &&
            reach.distance >= huntMinDistanceInMeters,
        (_Reach reach) => reach.distance >= huntMinDistanceInMeters,
      ]);
    }
    if (isLastStop) {
      reachable = _preferOrKeep(reachable, <bool Function(_Reach)>[
        (_Reach reach) =>
            reach.distanceToStart <= huntLastToStartInMeters &&
            reach.distance >= huntMinDistanceInMeters,
        (_Reach reach) =>
            reach.distanceToStart <= huntLastToStartFallbackInMeters &&
            reach.distance >= huntMinDistanceInMeters,
        (_Reach reach) => reach.distance >= huntMinDistanceInMeters,
      ]);
    }

    // `:292-298`. Die dritte Stufe lässt den Mindestabstand fallen: lieber
    // zwei Stationen dicht beieinander als eine Jagd, die abbricht.
    List<_Reach> inRange = reachable
        .where(
          (_Reach reach) =>
              reach.distance >= huntMinDistanceInMeters &&
              reach.distance <= huntMaxPrimaryDistanceInMeters,
        )
        .toList();
    if (inRange.isEmpty) {
      inRange = reachable
          .where(
            (_Reach reach) =>
                reach.distance >= huntMinDistanceInMeters &&
                reach.distance <= huntMaxFallbackDistanceInMeters,
          )
          .toList();
    }
    if (inRange.isEmpty) {
      inRange = reachable
          .where(
            (_Reach reach) => reach.distance <= huntMaxFallbackDistanceInMeters,
          )
          .toList();
    }
    if (inRange.isEmpty) {
      break;
    }

    // `:300-310`. Die Quelle sortiert absteigend und nimmt das erste Element.
    // `Array.prototype.sort` ist seit ES2019 stabil, `List.sort` in Dart ist
    // es **nicht**; ein Gleichstand fiele hier also anders aus als dort.
    // Deshalb ein Durchlauf, der den ersten echten Höchstwert behält.
    _Reach best = inRange.first;
    double bestScore = _score(best, usedTypes);
    for (final _Reach reach in inRange.skip(1)) {
      final double score = _score(reach, usedTypes);
      if (score > bestScore) {
        best = reach;
        bestScore = score;
      }
    }

    final HuntStop stop = _pickStop(best.candidate, usedTypes);
    stops.add(stop);
    used.add(best.candidate.fact.id);
    usedTypes.add(stop.puzzle.type);
  }

  return HuntPlan(stops: stops, difficulty: difficulty, duration: duration);
}

/// Die Auffindbarkeit eines Fakts, `hunt-generator.jsx:185`.
///
/// Die Quelle nimmt den **ersten** nicht leeren Wert über alle Rätsel des
/// Fakts und schreibt dazu, das Feld reise „pro puzzle_fit-Eintrag mit (gleich
/// auf allen Stufen eines Fakts)". Es ist also eine Eigenschaft des Ortes, die
/// nur zufällig am Rätsel steht.
String? _findabilityOf(Fact fact) {
  for (final FactPuzzle puzzle in fact.puzzles) {
    final String? findability = puzzle.findability;
    if (findability != null && findability.isNotEmpty) {
      return findability;
    }
  }
  return null;
}

/// Fakten mit mindestens einem passenden Rätsel, `:193-199` und Geschwister.
List<_Candidate> _candidates(
  List<Fact> pool,
  bool Function(FactPuzzle) matches,
) {
  final List<_Candidate> found = <_Candidate>[];
  for (final Fact fact in pool) {
    final List<FactPuzzle> puzzles = fact.puzzles.where(matches).toList();
    if (puzzles.isNotEmpty) {
      found.add(_Candidate(fact: fact, puzzles: puzzles));
    }
  }
  return found;
}

/// Die erste Station bei bekanntem Startpunkt, `:239-247`: die nächstgelegene.
///
/// ## Die Stufung der Quelle kann das Ergebnis nicht ändern
///
/// Sie liest sich, als bevorzuge sie erst alles innerhalb von 500 Metern, dann
/// alles innerhalb von 1000, und nehme erst danach irgendetwas
/// (`FIRST_STOP_NEAR_M`, `FIRST_STOP_FALLBACK_M`). Sie sortiert dafür aber
/// **aufsteigend** und greift am Ende `pool[0]`. Damit sind `near` und `mid`
/// Anfangsstücke derselben Liste: enthält `near` überhaupt etwas, dann ist das
/// globale Minimum darin, und `pool[0]` ist es. Enthält `near` nichts, gilt
/// dasselbe für `mid`. In allen drei Zweigen kommt derselbe Kandidat heraus.
///
/// Deshalb steht hier keine nachgebaute Stufung: es gibt keine Eingabe, die
/// die Zweige unterscheiden würde, und drei Zweige, die kein Test trennen
/// kann, sind drei Zweige, die niemand prüft. Die Konstanten
/// [huntFirstStopNearInMeters] und [huntFirstStopFallbackInMeters] bleiben
/// benannt, damit der Zusammenhang zur Quelle auffindbar ist.
///
/// Bei gleicher Entfernung gewinnt der **erste** Kandidat der Liste, wie bei
/// einer stabilen Sortierung. `List.sort` in Dart ist nicht stabil, deshalb
/// ein Durchlauf statt einer Sortierung.
_Candidate _nearestFirst(List<_Candidate> candidates, MapPosition startNear) {
  _Candidate nearest = candidates.first;
  double shortest = startNear.distanceInMetersTo(_positionOf(nearest.fact));
  for (final _Candidate candidate in candidates.skip(1)) {
    final double distance = startNear.distanceInMetersTo(
      _positionOf(candidate.fact),
    );
    if (distance < shortest) {
      nearest = candidate;
      shortest = distance;
    }
  }
  return nearest;
}

/// Die erste Bedingung, die überhaupt etwas übrig lässt; sonst alles.
///
/// Das Muster der Quelle an zwei wirksamen Stellen (`:281-283`, `:286-289`):
/// eine Einschränkung wird nur angewandt, solange danach noch ein Kandidat
/// steht. Eine leere Auswahl gewinnt nie.
List<_Reach> _preferOrKeep(
  List<_Reach> all,
  List<bool Function(_Reach)> preferences,
) {
  for (final bool Function(_Reach) preference in preferences) {
    final List<_Reach> filtered = all.where(preference).toList();
    if (filtered.isNotEmpty) {
      return filtered;
    }
  }
  return all;
}

/// Sweet-Spot plus Vielfalt plus Güte, `:300-307`.
double _score(_Reach reach, Set<String?> usedTypes) {
  final bool freshType = reach.candidate.puzzles.any(
    (FactPuzzle puzzle) => !usedTypes.contains(puzzle.type),
  );
  final int? qualityScore = reach.candidate.fact.qualityScore;
  final double qualityBonus = qualityScore == null
      ? 0
      : huntQualityBonusByScore[qualityScore] ?? 0;
  return huntDistanceScore(reach.distance) +
      (freshType ? huntFreshTypeBonus : 0) +
      qualityBonus;
}

/// Die Aufgabe für eine Station, `:93-108`.
///
/// Bevorzugt eine Rätselform, die es in dieser Jagd noch nicht gab; gibt es
/// keine, nimmt die Quelle ausdrücklich das erste Rätsel und wiederholt damit
/// eine Form, statt die Station fallen zu lassen.
HuntStop _pickStop(_Candidate candidate, Set<String?> usedTypes) {
  final FactPuzzle puzzle = candidate.puzzles.firstWhere(
    (FactPuzzle puzzle) => !usedTypes.contains(puzzle.type),
    orElse: () => candidate.puzzles.first,
  );
  return HuntStop(fact: candidate.fact, puzzle: puzzle);
}

MapPosition _positionOf(Fact fact) => MapPosition(
  latitude: fact.coordinates!.latitude,
  longitude: fact.coordinates!.longitude,
);

/// FNV-1a über die UTF-16-Einheiten, `hunt-generator.jsx:18-25`.
///
/// `charCodeAt` liefert UTF-16-Einheiten, [String.codeUnits] ebenfalls; ein
/// Zeichen außerhalb der Basisebene wird in beiden Fassungen als zwei
/// Einheiten gehasht.
int _fnv1a(String value) {
  int hash = 2166136261;
  for (final int unit in value.codeUnits) {
    hash ^= unit;
    hash = _imul(hash, 16777619);
  }
  return hash & 0xFFFFFFFF;
}

/// Mulberry32, `hunt-generator.jsx:27-34`.
///
/// Die Quelle lässt `seed` als Gleitkommazahl weiterwachsen und stützt sich
/// darauf, dass jede Verwendung über `^`, `|` oder `Math.imul` ohnehin auf 32
/// Bit gekürzt wird. Hier wird stattdessen bei jedem Schritt maskiert; das ist
/// dasselbe Ergebnis, solange die Summe in JavaScript exakt bleibt, und sie
/// bleibt es bis 2^53.
double Function() _mulberry32(int seed) {
  int state = seed & 0xFFFFFFFF;
  return () {
    state = (state + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ (t + _imul(t ^ (t >>> 7), t | 61))) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  };
}

/// `Math.imul`: Multiplikation, die nur die unteren 32 Bit behält.
///
/// Dart rechnet mit 64 Bit und läuft bei einem Produkt zweier 32-Bit-Zahlen
/// über; das Ergebnis stimmt trotzdem, weil der Überlauf im Zweierkomplement
/// exakt modulo 2^64 ist und die unteren 32 Bit davon unberührt bleiben.
int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

/// Ein Fakt mit den Rätseln, die die aktuelle Auswahlstufe übrig gelassen hat.
class _Candidate {
  const _Candidate({required this.fact, required this.puzzles});

  final Fact fact;
  final List<FactPuzzle> puzzles;
}

/// Ein Kandidat mit seinen beiden Entfernungen, `:269-275`.
class _Reach {
  const _Reach({
    required this.candidate,
    required this.distance,
    required this.distanceToStart,
  });

  final _Candidate candidate;
  final double distance;
  final double distanceToStart;
}
