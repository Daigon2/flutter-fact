import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Phasenmaschine der laufenden Jagd, `app.jsx:903-960`.
///
/// ## Warum hier keine Zeit und kein Zufall vorkommt
///
/// [HuntRun] ist rein: derselbe Aufruf auf demselben Ausgangswert liefert
/// immer dasselbe Ergebnis. Jeder Test hier braucht deshalb nur einen
/// [HuntPlan] und eine Folge von Übergängen, keine Uhr, keinen Zufall.
void main() {
  group('start', () {
    test('setzt alle Stationen auf pending, Zeiger auf 0, Punkte auf 0, '
        'Hinweisliste leer', () {
      final HuntRun run = HuntRun.start(_plan(3));

      expect(
        run.stops.every(
          (HuntRunStop stop) => stop.status == HuntStopStatus.pending,
        ),
        isTrue,
      );
      expect(run.currentStopIndex, 0);
      expect(run.points, 0);
      expect(run.unlockedHintIndices, isEmpty);
    });
  });

  group('Lösen', () {
    test('Lösen der ersten Station schaltet auf die zweite weiter, addiert die '
        'Punkte, setzt den Status', () {
      final HuntRun run = HuntRun.start(_plan(3));

      final HuntRun after = run.solveStop(
        0,
        pointsAwarded: 50,
        hintUsed: false,
      );

      expect(after.stops[0].status, HuntStopStatus.solved);
      expect(after.stops[0].pointsAwarded, 50);
      expect(after.stops[0].hintUsed, isFalse);
      expect(after.currentStopIndex, 1);
      expect(after.points, 50);
    });

    test(
      'der Abzug: zwei Hinweise (20 und 30), 50 Punkte ergeben 0, nicht -50',
      () {
        final HuntRun run = HuntRun.start(_plan(2)).unlockHint(1).unlockHint(2);

        final HuntRun after = run.solveStop(
          0,
          pointsAwarded: 50,
          hintUsed: true,
        );

        expect(after.stops[0].pointsAwarded, 0);
        expect(after.points, 0);
      },
    );

    test('liegen die Hinweiskosten über den Punkten, bleibt es bei 0, nicht '
        'negativ', () {
      // Kosten 20 + 30 = 50, Punkte nur 10: ohne die Untergrenze bei null
      // käme hier -40 heraus.
      final HuntRun run = HuntRun.start(_plan(2)).unlockHint(1).unlockHint(2);

      final HuntRun after = run.solveStop(0, pointsAwarded: 10, hintUsed: true);

      expect(after.stops[0].pointsAwarded, 0);
      expect(after.points, 0);
    });

    test('derselbe Abzug, mit 100 Punkten bleiben 50', () {
      final HuntRun run = HuntRun.start(_plan(2)).unlockHint(1).unlockHint(2);

      final HuntRun after = run.solveStop(
        0,
        pointsAwarded: 100,
        hintUsed: true,
      );

      expect(after.stops[0].pointsAwarded, 50);
      expect(after.points, 50);
    });

    test('der Abzug wirkt nur auf die Station, an der die Hinweise gekauft '
        'wurden', () {
      // Hinweis 1 kostet 20 Coins, gekauft an Station 0. Nach dem Lösen von
      // Station 0 setzt das Weiterschalten die Hinweisliste zurück, Station
      // 1 startet also ohne jeden Abzug.
      final HuntRun run = HuntRun.start(_plan(2)).unlockHint(1);

      final HuntRun afterFirst = run.solveStop(
        0,
        pointsAwarded: 50,
        hintUsed: true,
      );
      final HuntRun afterSecond = afterFirst.solveStop(
        1,
        pointsAwarded: 50,
        hintUsed: false,
      );

      expect(afterFirst.stops[0].pointsAwarded, 30);
      expect(afterSecond.stops[1].pointsAwarded, 50);
    });
  });

  group('Überspringen', () {
    test('schaltet ebenso weiter wie das Lösen', () {
      final HuntRun run = HuntRun.start(_plan(3));

      final HuntRun after = run.skipStop(0);

      expect(after.stops[0].status, HuntStopStatus.skipped);
      expect(after.currentStopIndex, 1);
    });

    test('eine übersprungene Station wird nicht wieder angelaufen, auch wenn '
        'sie vor der aktuellen liegt', () {
      final HuntRun run = HuntRun.start(_plan(4));

      final HuntRun afterSkip = run.skipStop(0);
      final HuntRun afterSolve1 = afterSkip.solveStop(
        1,
        pointsAwarded: 10,
        hintUsed: false,
      );
      final HuntRun afterSolve2 = afterSolve1.solveStop(
        2,
        pointsAwarded: 10,
        hintUsed: false,
      );

      // Der Zeiger stand nach jedem Schritt hinter Station 0, sie ist also
      // bei jedem Suchlauf schon außer Reichweite gewesen. Ihr Status
      // bleibt trotzdem `skipped` und nicht etwa erneut `pending`.
      expect(afterSolve2.stops[0].status, HuntStopStatus.skipped);
      expect(afterSolve2.currentStopIndex, 3);
    });
  });

  group('Zeiger am Ende', () {
    test('nach der letzten Station bleibt der Zeiger stehen', () {
      final HuntRun run = HuntRun.start(_plan(2));

      final HuntRun afterFirst = run.solveStop(
        0,
        pointsAwarded: 10,
        hintUsed: false,
      );
      final HuntRun afterLast = afterFirst.solveStop(
        1,
        pointsAwarded: 10,
        hintUsed: false,
      );

      expect(afterFirst.currentStopIndex, 1);
      expect(afterLast.currentStopIndex, 1);
    });

    test('die Suche nach der nächsten Station beginnt erst nach dem gelösten '
        'Index, nicht am Anfang', () {
      // Station 0 bleibt hier bewusst pending: gelöst wird Station 2,
      // während der Zeiger noch auf Station 1 steht. Eine Suche, die vorn
      // beginnt statt bei Index 2, träfe zuerst die pending Station 0 (oder
      // 1) und setzte den Zeiger fälschlich zurück statt vorwärts auf 3.
      final HuntRun run = HuntRun.start(_plan(4)).skipStop(0);
      expect(run.currentStopIndex, 1);

      final HuntRun after = run.solveStop(
        2,
        pointsAwarded: 10,
        hintUsed: false,
      );

      expect(after.currentStopIndex, 3);
    });
  });

  group('isFinished', () {
    test('wird wahr, wenn alle Stationen gelöst sind', () {
      final HuntRun run = HuntRun.start(_plan(2))
          .solveStop(0, pointsAwarded: 10, hintUsed: false)
          .solveStop(1, pointsAwarded: 10, hintUsed: false);

      expect(run.isFinished, isTrue);
    });

    test(
      'wird wahr, wenn eine Station übersprungen und der Rest gelöst ist',
      () {
        final HuntRun run = HuntRun.start(
          _plan(2),
        ).skipStop(0).solveStop(1, pointsAwarded: 10, hintUsed: false);

        expect(run.isFinished, isTrue);
      },
    );

    test('bleibt falsch, wenn eine Station nur eingesammelt ist', () {
      final HuntRun run = HuntRun.start(
        _plan(2),
      ).solveStop(0, pointsAwarded: 10, hintUsed: false).collectStop(1);

      expect(run.isFinished, isFalse);
    });
  });

  group('Hinweise', () {
    test('der Hinweiszustand wird beim Weiterschalten zurückgesetzt', () {
      final HuntRun run = HuntRun.start(_plan(2)).unlockHint(1);
      expect(run.unlockedHintIndices, <int>[1]);

      final HuntRun after = run.solveStop(0, pointsAwarded: 50, hintUsed: true);

      expect(after.unlockedHintIndices, isEmpty);
    });

    test('zweimal derselbe Hinweis ändert Liste und Kosten nicht', () {
      final HuntRun run = HuntRun.start(_plan(1)).unlockHint(1);

      final HuntRun again = run.unlockHint(1);

      expect(again.unlockedHintIndices, run.unlockedHintIndices);
      expect(again.stops[0].hintCostSpent, run.stops[0].hintCostSpent);
    });

    test('der erste Hinweis ist gratis und taucht nicht in der Liste auf', () {
      final HuntRun run = HuntRun.start(_plan(1)).unlockHint(0);

      expect(run.unlockedHintIndices, isEmpty);
      expect(run.stops[0].hintCostSpent, 0);
    });

    test('ein Index außerhalb des Bereichs wirft', () {
      final HuntRun run = HuntRun.start(_plan(1));

      expect(() => run.unlockHint(3), throwsRangeError);
    });
  });

  group('Unveränderlichkeit', () {
    test('die zurückgegebenen Listen sind unveränderlich', () {
      final HuntRun run = HuntRun.start(_plan(2)).unlockHint(1);

      expect(() => run.stops.add(run.stops.first), throwsUnsupportedError);
      expect(() => run.unlockedHintIndices.add(99), throwsUnsupportedError);
    });

    test(
      'jeder Übergang liefert ein neues Objekt, das alte bleibt unverändert',
      () {
        final HuntRun run = HuntRun.start(_plan(2));

        final HuntRun afterSolve = run.solveStop(
          0,
          pointsAwarded: 10,
          hintUsed: false,
        );
        expect(identical(run, afterSolve), isFalse);
        expect(run.currentStopIndex, 0);
        expect(run.points, 0);
        expect(run.stops[0].status, HuntStopStatus.pending);

        final HuntRun afterUnlock = run.unlockHint(1);
        expect(identical(run, afterUnlock), isFalse);
        expect(run.unlockedHintIndices, isEmpty);

        final HuntRun afterSkip = run.skipStop(0);
        expect(identical(run, afterSkip), isFalse);
        expect(run.stops[0].status, HuntStopStatus.pending);

        final HuntRun afterCollect = run.collectStop(0);
        expect(identical(run, afterCollect), isFalse);
        expect(run.stops[0].status, HuntStopStatus.pending);
      },
    );
  });

  group('toActiveHunt', () {
    test('an Station 3 von 7 ergibt stationOrdinal 3, den richtigen Titel und '
        'die richtige Lage, und trägt die freigeschalteten Indizes', () {
      final HuntPlan plan = _plan(7);
      HuntRun run = HuntRun.start(plan);
      run = run.solveStop(0, pointsAwarded: 10, hintUsed: false);
      run = run.solveStop(1, pointsAwarded: 10, hintUsed: false);
      run = run.unlockHint(1);

      final ActiveHunt? activeHunt = run.toActiveHunt();

      expect(activeHunt, isNotNull);
      expect(activeHunt!.stationOrdinal, 3);
      expect(activeHunt.stationCount, 7);
      expect(activeHunt.stationTitle, plan.stops[2].fact.canonicalTitle);
      expect(activeHunt.stationLatitude, plan.stops[2].position.latitude);
      expect(activeHunt.stationLongitude, plan.stops[2].position.longitude);
      expect(activeHunt.unlockedHintIndices, <int>[1]);
      expect(activeHunt.difficulty, plan.difficulty);
      expect(activeHunt.duration, plan.duration);
    });
  });
}

/// Ein [HuntPlan] mit [stopCount] Stationen, für Tests, die nur den
/// Fortschritt eines Laufs prüfen und nicht die Auswahl des Generators.
HuntPlan _plan(
  int stopCount, {
  PuzzleDifficulty difficulty = PuzzleDifficulty.leicht,
  HuntDuration duration = HuntDuration.thirty,
}) {
  return HuntPlan(
    stops: <HuntStop>[
      for (int i = 1; i <= stopCount; i++)
        HuntStop(fact: _fact(i), puzzle: _puzzle()),
    ],
    difficulty: difficulty,
    duration: duration,
  );
}

/// Ein Fakt mit Kennung [id] und einer Koordinate, die sich von jeder anderen
/// in [_plan] unterscheidet, damit ein vertauschter Index auffällt.
Fact _fact(int id) => Fact(
  id: FactId(id),
  content: FactText(title: 'Fakt $id'),
  coordinates: FactCoordinates(latitude: 48.0 + id, longitude: 11.0 + id),
  puzzles: <FactPuzzle>[_puzzle()],
);

FactPuzzle _puzzle() => const FactPuzzle(
  question: 'Wie viele Löwen bewachen das Tor?',
  type: 'inschrift',
  difficulty: PuzzleDifficulty.leicht,
  confidence: 'curated',
);
