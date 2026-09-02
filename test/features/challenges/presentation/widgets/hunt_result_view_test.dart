import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_result_view.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Ergebnisbildschirm, `HuntResultScreen` in
/// `02_Frontend/app/screen-challenge.jsx:2952-2977`. Schritt 39.
void main() {
  Future<void> pumpResult(
    WidgetTester tester, {
    required HuntRun run,
    VoidCallback? onClose,
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
            body: HuntResultView(run: run, onClose: onClose ?? () {}),
          ),
        ),
      ),
    );
  }

  final AppStrings strings = AppStrings.of(AppLanguage.de);

  testWidgets(
    'zeigt Punkte, die Anzahl gelöster Stationen und den Zeitplatzhalter',
    (WidgetTester tester) async {
      // Drei Stationen: eine gelöst mit 150 Punkten, eine übersprungen, eine
      // eingesammelt. `isFinished` verlangt das hier nicht (das prüft die
      // Verzweigung in `challenges_page_test.dart`), dieses Widget zeigt nur
      // an, was im Lauf steht.
      HuntRun run = HuntRun.start(_plan(stopCount: 3));
      run = run.solveStop(0, pointsAwarded: 150, hintUsed: false);
      run = run.skipStop(1);
      run = run.collectStop(2);

      await pumpResult(tester, run: run);

      expect(find.text('150'), findsOneWidget, reason: 'Punktzahl');
      expect(
        find.text(
          strings.text(
            'challenge.huntResult.solvedCount',
            params: <String, String>{'solved': '1', 'total': '3'},
          ),
        ),
        findsOneWidget,
        reason: 'gelöste Stationen',
      );
      expect(
        find.text(
          strings.text(
            'challenge.huntResult.timeLine',
            params: <String, String>{
              'time': strings.text('challenge.huntResult.timePlaceholder'),
            },
          ),
        ),
        findsOneWidget,
        reason: 'Zeitzeile mit Platzhalter',
      );
    },
  );

  testWidgets('zeigt die Überschrift und die Punkte-Beschriftung', (
    WidgetTester tester,
  ) async {
    await pumpResult(tester, run: HuntRun.start(_plan(stopCount: 1)));

    expect(
      find.text(strings.text('challenge.huntResult.title')),
      findsOneWidget,
    );
    expect(
      find.text(strings.text('challenge.huntResult.pointsLabel').toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('„Fertig" ruft onClose', (WidgetTester tester) async {
    bool closed = false;
    await pumpResult(
      tester,
      run: HuntRun.start(_plan(stopCount: 1)),
      onClose: () => closed = true,
    );

    await tester.tap(find.byKey(HuntResultView.closeKey));
    await tester.pump();

    expect(closed, isTrue);
  });
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
