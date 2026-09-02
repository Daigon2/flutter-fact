import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_theme.dart';
import 'package:fact_app/features/challenges/application/active_hunt_providers.dart';
import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:fact_app/features/challenges/domain/hunt_hints.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/challenges/presentation/widgets/hunt_pill.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Jagd-Pille, `HuntPill` in `02_Frontend/app/screen-map.jsx:1011-1135`.
///
/// ## Der Rahmen
///
/// `MaterialApp` mit `FactTheme` über einem `Scaffold`, dasselbe Vorbild wie
/// `hunt_start_point_view_test.dart`, damit Farben und Schriftrollen über
/// `Theme.of(context)` wirklich ankommen.
///
/// ## Wie der Jagdzustand hereinkommt
///
/// [huntRunProvider] ist ein `NotifierProvider`, sein Standard `null` (keine
/// laufende Jagd). Ein Test, der eine laufende Jagd braucht, überschreibt ihn
/// mit [_SeededHuntRunNotifier], deren `build()` den vorbereiteten [HuntRun]
/// liefert, statt `null` wie der echte Notifier. Der Schreibweg
/// (`unlockHint`, `_apply`) bleibt dabei der echte: nur der Startwert ist
/// gestellt.
void main() {
  Future<ProviderContainer> pumpPill(
    WidgetTester tester, {
    HuntRun? initialRun,
    MapPosition? userPosition,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(),
        ),
        huntRunProvider.overrideWith(() => _SeededHuntRunNotifier(initialRun)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FactTheme.light(),
          home: Scaffold(body: HuntPill(userPosition: userPosition)),
        ),
      ),
    );
    return container;
  }

  group('Ohne laufende Jagd', () {
    testWidgets('zeigt die Pille nichts', (tester) async {
      await pumpPill(tester);

      expect(
        find.descendant(
          of: find.byType(HuntPill),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  });

  group('Die eingeklappte Zeile', () {
    testWidgets('Stationszeile und Titel stimmen', (tester) async {
      final HuntRun run = HuntRun.start(_plan(stopCount: 3));

      await pumpPill(tester, initialRun: run);

      expect(find.text('STATION 1 / 3'), findsOneWidget);
      expect(find.text('Fakt 1'), findsOneWidget);
    });

    testWidgets('leicht mit Nutzerposition und Peilung: Pfeil und Distanz', (
      tester,
    ) async {
      final HuntRun run = HuntRun.start(
        _plan(stopCount: 2, difficulty: PuzzleDifficulty.leicht),
      );

      await pumpPill(
        tester,
        initialRun: run,
        userPosition: _stationPositionOf(run, offsetMeters: 400),
      );

      // Die Peilung ist **nicht** vorgegeben, sondern gerechnet: die
      // Testvorgabe setzt den Nutzer genau südlich der Station, und
      // `MapPosition.bearingInDegreesTo` liefert dafür 0, also Norden.
      expect(find.text('↑'), findsOneWidget, reason: 'Peilung 0 = Norden');
      expect(find.text('400m'), findsOneWidget);
    });

    testWidgets('mittel mit Nutzerposition und Peilung: Distanz, kein Pfeil', (
      tester,
    ) async {
      // Dieselbe Peilung wie im Leicht-Fall: überlebt die Pflichtmutation
      // "showsArrow ignorieren", zeigt dieser Test trotzdem den Pfeil.
      final HuntRun run = HuntRun.start(
        _plan(stopCount: 2, difficulty: PuzzleDifficulty.mittel),
      );

      await pumpPill(
        tester,
        initialRun: run,
        userPosition: _stationPositionOf(run, offsetMeters: 400),
      );

      expect(find.text('↑'), findsNothing);
      expect(find.text('400m'), findsOneWidget);
    });

    testWidgets('schwer mit Nutzerposition und Peilung: weder noch', (
      tester,
    ) async {
      final HuntRun run = HuntRun.start(
        _plan(stopCount: 2, difficulty: PuzzleDifficulty.schwer),
      );

      await pumpPill(
        tester,
        initialRun: run,
        userPosition: _stationPositionOf(run, offsetMeters: 400),
      );

      expect(find.text('↑'), findsNothing);
      expect(find.text('400m'), findsNothing);
    });

    testWidgets('ohne Nutzerposition keine Distanz, auch bei leicht', (
      tester,
    ) async {
      final HuntRun run = HuntRun.start(
        _plan(stopCount: 2, difficulty: PuzzleDifficulty.leicht),
      );

      await pumpPill(tester, initialRun: run);

      expect(find.text('↑'), findsNothing);
      expect(find.textContaining('m'), findsNothing);
    });

    test('die Distanzformatierung: knapp unter, genau und weit über 1000', () {
      expect(formatHuntPillDistance(999, _strings), '999m');
      expect(formatHuntPillDistance(1000, _strings), '1.0km');
      expect(formatHuntPillDistance(5000, _strings), '5.0km');
    });

    test(
      'der Pfeil zeigt die richtige Glyphe für mindestens zwei Peilungen',
      () {
        expect(huntArrowGlyphFor(0), '↑');
        expect(huntArrowGlyphFor(90), '→');
        expect(huntArrowGlyphFor(180), '↓');
      },
    );
  });

  group('Ausgeklappt', () {
    testWidgets(
      'der erste Hinweis ist offen, die anderen zeigen Knöpfe mit 20 und 30',
      (tester) async {
        final HuntRun run = HuntRun.start(_plan(stopCount: 2));

        await pumpPill(tester, initialRun: run);
        await tester.tap(find.byType(HuntPill));
        await tester.pumpAndSettle();

        // Index 0 ist frei: der Text der **nächsten** Station steht da, nicht
        // der Rückfalltext, denn Stopp 2 trägt einen eigenen ersten Hinweis.
        expect(find.text('Hinweis 2.1'), findsOneWidget);
        expect(
          find.textContaining('Tipp freischalten (−20'),
          findsOneWidget,
          reason: 'Kosten von Hinweis 2, huntHintCosts[1]',
        );
        expect(
          find.textContaining('Tipp freischalten (−30'),
          findsOneWidget,
          reason: 'Kosten von Hinweis 3, huntHintCosts[2]',
        );
        expect(huntHintCosts, <int>[
          0,
          20,
          30,
        ], reason: 'Gegenprobe der Zahlen');
      },
    );

    testWidgets(
      'ein Tipp auf einen gesperrten Hinweis schaltet ihn frei, die Kosten '
      'landen an der aktuellen Station',
      (tester) async {
        final HuntRun run = HuntRun.start(_plan(stopCount: 2));

        final ProviderContainer container = await pumpPill(
          tester,
          initialRun: run,
        );
        await tester.tap(find.byType(HuntPill));
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Tipp freischalten (−20'));
        await tester.pumpAndSettle();

        final HuntRun? after = container.read(huntRunProvider);
        expect(after, isNotNull);
        expect(after!.unlockedHintIndices, contains(1));
        expect(after.stops[0].hintCostSpent, 20);
      },
    );

    testWidgets('ein Hinweis ohne Text und gesperrt wird nicht gezeigt', (
      tester,
    ) async {
      // Stopp 2 (die nächste Station ab Stopp 1) trägt nur einen Hinweistext.
      final HuntRun run = HuntRun.start(
        _plan(stopCount: 2, secondStopHints: const <String>['Nur der erste']),
      );

      await pumpPill(tester, initialRun: run);
      await tester.tap(find.byType(HuntPill));
      await tester.pumpAndSettle();

      expect(find.text('Nur der erste'), findsOneWidget);
      expect(find.textContaining('Tipp freischalten'), findsNothing);
    });

    testWidgets(
      'an der letzten Station steht nur der Rückfallsatz, und der ist offen',
      (tester) async {
        // **Der Test hieß zuerst „gibt es keine Hinweistexte" und war grün,
        // obwohl das Verhalten falsch war.** Er prüfte nur die Abwesenheit der
        // Texte „Hinweis n.m", und die fehlen in beiden Fassungen. Die Quelle
        // fällt an der letzten Station in den else-Zweig ihres Ausdrucks
        // (`:1035-1043`) und zeigt dort sehr wohl den Rückfallsatz an Index 0.
        // Muster 22 in „Wie Tests hier blind werden" ist derselbe Fehler in
        // grün: eine Zusicherung, die zwei verschiedene Zustände nicht
        // unterscheidet.
        HuntRun run = HuntRun.start(_plan(stopCount: 2));
        run = run.skipStop(0);
        expect(run.currentStopIndex, 1, reason: 'Vorbedingung des Tests');

        await pumpPill(tester, initialRun: run);
        await tester.tap(find.byType(HuntPill));
        await tester.pumpAndSettle();

        // Der Rückfallsatz steht da, offen, weil Index 0 immer frei ist.
        expect(
          find.text('Schau dich in der Umgebung aufmerksam um.'),
          findsOneWidget,
        );
        // Und nur er: keine Texte der Stationen, keine gesperrten Knöpfe.
        expect(find.textContaining('Hinweis'), findsNothing);
        expect(find.textContaining('Tipp freischalten'), findsNothing);
        expect(find.text('—'), findsNothing);
        expect(find.text('Schließen'), findsOneWidget);
      },
    );
  });
}

/// Ein feststehendes [AppStrings] für den reinen Funktionstest der
/// Distanzformatierung, ohne Widget-Baum.
final _strings = AppStrings.of(AppLanguage.de);

/// Die Position der aktuellen Station des Laufs, um [offsetMeters] nach Norden
/// versetzt (entlang eines Meridians, wo die Großkreisdistanz exakt
/// `Erdradius * Bogenmaß` ist, ohne Rundungsfehler durch eine zweite Achse).
MapPosition _stationPositionOf(HuntRun run, {required double offsetMeters}) {
  final MapPosition station = run.currentStop.stop.position;
  final double deltaLatitude =
      (offsetMeters / MapPosition.earthRadiusInMeters) *
      180 /
      3.141592653589793;
  return MapPosition(
    latitude: station.latitude - deltaLatitude,
    longitude: station.longitude,
  );
}

/// Ein [HuntPlan] mit [stopCount] Stationen. Jede außer der letzten trägt drei
/// Hinweistexte für die **nächste** Station (`Hinweis {n}.1` bis `.3`), damit
/// ein Test an Stopp `i` sofort sieht, ob er die Hinweise von `i` oder von
/// `i + 1` bekommen hat. [secondStopHints] überschreibt die Hinweise der
/// zweiten Station, für den Fall mit fehlendem Text.
HuntPlan _plan({
  required int stopCount,
  PuzzleDifficulty difficulty = PuzzleDifficulty.leicht,
  List<String>? secondStopHints,
}) {
  return HuntPlan(
    stops: <HuntStop>[
      for (int i = 1; i <= stopCount; i++)
        HuntStop(
          fact: _fact(
            i,
            hints: i == 2 && secondStopHints != null
                ? secondStopHints
                : <String>['Hinweis $i.1', 'Hinweis $i.2', 'Hinweis $i.3'],
          ),
          puzzle: _puzzle(),
        ),
    ],
    difficulty: difficulty,
    duration: HuntDuration.thirty,
  );
}

Fact _fact(int id, {required List<String> hints}) => Fact(
  id: FactId(id),
  content: FactText(title: 'Fakt $id'),
  coordinates: FactCoordinates(latitude: 48.0 + id, longitude: 11.0 + id),
  puzzles: <FactPuzzle>[_puzzle()],
  stationHints: hints,
);

FactPuzzle _puzzle() => const FactPuzzle(
  question: 'Wie viele Löwen bewachen das Tor?',
  type: 'inschrift',
  difficulty: PuzzleDifficulty.leicht,
  confidence: 'curated',
);

/// Liefert [initial] als Startwert statt `null`, siehe den Dateikopf.
class _SeededHuntRunNotifier extends HuntRunNotifier {
  _SeededHuntRunNotifier(this.initial);

  final HuntRun? initial;

  @override
  HuntRun? build() => initial;
}
