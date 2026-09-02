import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_pause_view.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Pause-Bildschirm, `HuntPauseScreen` in
/// `02_Frontend/app/screen-challenge.jsx:2797-2895`. Schritt 39.
///
/// ## Der Rahmen
///
/// `MaterialApp` mit `FactTheme` über einem `Scaffold`, dasselbe Vorbild wie
/// `hunt_start_point_view_test.dart`. [HuntRun], Stadtname und beide
/// Rückrufe kommen als Parameter herein, `huntRunProvider` bleibt
/// unangetastet: nur `AppStrings` kommt über Riverpod.
void main() {
  Future<void> pumpPause(
    WidgetTester tester, {
    required HuntRun run,
    VoidCallback? onBackToMap,
    VoidCallback? onAbort,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languagePreferenceStoreProvider.overrideWithValue(
            InMemoryLanguagePreferenceStore(),
          ),
        ],
        child: MaterialApp(
          theme: FactTheme.light(),
          home: Scaffold(
            body: HuntPauseView(
              run: run,
              cityName: 'München',
              onBackToMap: onBackToMap ?? () {},
              onAbort: onAbort ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  final AppStrings strings = AppStrings.of(AppLanguage.de);

  group('Die drei Kacheln', () {
    testWidgets('zählen nur gelöste Stationen, nicht eingesammelte und nicht '
        'übersprungene', (WidgetTester tester) async {
      // Fünf Stationen, drei verschiedene Nicht-Ausgangszustände auf
      // einmal: gelöst, übersprungen und eingesammelt. Ohne diese
      // Mischung wäre der Test blind für die Verwechslung von `solved`
      // mit `collected`, siehe die Mutationsprobe im Bericht.
      final HuntRun run = _mixedRun();

      await pumpPause(tester, run: run);

      expect(find.text('1/5'), findsOneWidget, reason: 'Stops-Kachel');
      expect(find.text('100'), findsOneWidget, reason: 'Punkte-Kachel');
      expect(
        find.text(strings.text('challenge.huntPause.timePlaceholder')),
        findsOneWidget,
        reason: 'Zeit-Kachel',
      );
    });

    testWidgets('zeigen die Beschriftungen Stops, Punkte und Zeit', (
      WidgetTester tester,
    ) async {
      await pumpPause(tester, run: _mixedRun());

      expect(
        find.text(strings.text('challenge.huntPause.stopsLabel').toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(
          strings.text('challenge.huntPause.pointsLabel').toUpperCase(),
        ),
        findsOneWidget,
      );
      expect(
        find.text(strings.text('challenge.huntPause.timeLabel').toUpperCase()),
        findsOneWidget,
      );
    });
  });

  group('Die Stationsliste', () {
    testWidgets(
      'nur die gelöste Station zeigt ihren echten Titel, die anderen einen '
      'Ersatztext',
      (WidgetTester tester) async {
        final HuntRun run = _mixedRun();

        await pumpPause(tester, run: run);

        // Anwesenheit des Titels an der gelösten Station …
        expect(find.text('Fakt 1'), findsOneWidget);
        // … und Abwesenheit an jeder anderen, **plus** der jeweils richtige
        // Ersatztext: ein Test, der nur die Abwesenheit des Titels prüft,
        // unterscheidet „nichts" nicht von „etwas anderem".
        expect(find.text('Fakt 2'), findsNothing);
        expect(find.text('Fakt 3'), findsNothing);
        expect(find.text('Fakt 4'), findsNothing);
        expect(find.text('Fakt 5'), findsNothing);
        expect(find.text('Station 2 · übersprungen'), findsOneWidget);
        expect(find.text('Station 3 · aktuell'), findsOneWidget);
        // Station 4 ist „collected", visuell wie eine ausstehende Station.
        expect(find.text('Station 4'), findsOneWidget);
        expect(find.text('Station 5'), findsOneWidget);
      },
    );

    testWidgets('nur die gelöste Station zeigt +N Punkte', (
      WidgetTester tester,
    ) async {
      await pumpPause(tester, run: _mixedRun());

      expect(find.text('+100'), findsOneWidget);
      expect(find.textContaining('+'), findsOneWidget);
    });
  });

  group('Die Knöpfe', () {
    testWidgets('„Zurück zur Karte" ruft onBackToMap', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await pumpPause(
        tester,
        run: HuntRun.start(_plan(stopCount: 1)),
        onBackToMap: () => tapped = true,
      );

      await tester.tap(find.byKey(HuntPauseView.backToMapKey));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
      '„Hunt abbrechen" ruft onAbort nicht sofort, sondern erst nach der '
      'Rückfrage',
      (WidgetTester tester) async {
        bool aborted = false;
        await pumpPause(
          tester,
          run: HuntRun.start(_plan(stopCount: 1)),
          onAbort: () => aborted = true,
        );

        await tester.tap(find.byKey(HuntPauseView.abortButtonKey));
        await tester.pump();
        expect(aborted, isFalse, reason: 'noch keine Bestätigung');
        expect(
          find.text(strings.text('challenge.huntPause.abortConfirmMessage')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(HuntPauseView.confirmAbortKey));
        await tester.pump();

        expect(aborted, isTrue);
      },
    );

    testWidgets('„Doch weiterspielen" schließt die Rückfrage ohne onAbort', (
      WidgetTester tester,
    ) async {
      bool aborted = false;
      await pumpPause(
        tester,
        run: HuntRun.start(_plan(stopCount: 1)),
        onAbort: () => aborted = true,
      );

      await tester.tap(find.byKey(HuntPauseView.abortButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(HuntPauseView.cancelAbortKey));
      await tester.pump();

      expect(aborted, isFalse);
      expect(
        find.text(strings.text('challenge.huntPause.abortConfirmMessage')),
        findsNothing,
      );
    });
  });
}

/// Ein [HuntRun] über fünf Stationen mit vier verschiedenen Zuständen:
/// Station 1 gelöst (100 Punkte), Station 2 übersprungen, Station 3 die
/// aktuelle (noch ausstehend), Station 4 eingesammelt (aber nicht gelöst),
/// Station 5 schlicht ausstehend.
HuntRun _mixedRun() {
  HuntRun run = HuntRun.start(_plan(stopCount: 5));
  run = run.solveStop(0, pointsAwarded: 100, hintUsed: false);
  run = run.skipStop(1);
  run = run.collectStop(3);
  expect(run.currentStopIndex, 2, reason: 'Vorbedingung der Testdaten');
  return run;
}

HuntPlan _plan({required int stopCount}) {
  return HuntPlan(
    stops: <HuntStop>[
      for (int i = 1; i <= stopCount; i++)
        HuntStop(fact: _fact(i), puzzle: _puzzle()),
    ],
    difficulty: PuzzleDifficulty.leicht,
    duration: HuntDuration.thirty,
  );
}

Fact _fact(int id) => Fact(
  id: FactId(id),
  content: FactText(title: 'Fakt $id'),
  coordinates: FactCoordinates(latitude: 48.0 + id, longitude: 11.0),
  puzzles: <FactPuzzle>[_puzzle()],
);

FactPuzzle _puzzle() => const FactPuzzle(
  question: 'Wie viele Löwen bewachen das Tor?',
  type: 'inschrift',
  confidence: 'curated',
);
