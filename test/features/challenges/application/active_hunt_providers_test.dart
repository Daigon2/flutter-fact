import 'package:fact_app/features/challenges/application/active_hunt_providers.dart';
import 'package:fact_app/features/challenges/application/hunt_plan.dart';
import 'package:fact_app/features/challenges/application/hunt_run.dart';
import 'package:fact_app/features/challenges/domain/active_hunt_store.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/entities/fact_puzzle.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/kernel/puzzle_difficulty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Lesezugang zur laufenden Jagd, wie `discovery` ihn bekommt.
void main() {
  /// Eine gültige Jagd an der [stationOrdinal]-ten Station, über
  /// [ActiveHunt.tryFrom], weil der Konstruktor privat ist.
  ActiveHunt huntAt(int stationOrdinal) => ActiveHunt.tryFrom(
    stationOrdinal: stationOrdinal,
    stationCount: 7,
    stationTitle: 'Station $stationOrdinal',
    stationLatitude: 48.1467,
    stationLongitude: 11.5661,
    unlockedHintIndices: const <int>[],
    difficulty: null,
    duration: HuntDuration.sixty,
  )!;

  ProviderContainer plainContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  ProviderContainer containerWith(ActiveHuntStore store) {
    final ProviderContainer container = ProviderContainer(
      overrides: [activeHuntStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('ohne Override steht ein flüchtiger Speicher bereit', () {
    // Derselbe untätige Standard wie bei den vier bestehenden Speichern: die
    // App läuft ohne Override, nur ohne Dauerhaftigkeit.
    expect(
      plainContainer().read(activeHuntStoreProvider),
      isA<InMemoryActiveHuntStore>(),
    );
  });

  test('ohne laufende Jagd liefert der Leseprovider null', () {
    expect(plainContainer().read(activeHuntProvider), isNull);
  });

  test('eine gespeicherte Jagd kommt beim Leseprovider an', () {
    final ProviderContainer container = containerWith(
      InMemoryActiveHuntStore(hunt: huntAt(3)),
    );

    expect(container.read(activeHuntProvider), huntAt(3));
  });

  test('der Override aus bootstrap() bindet eine fremde Umsetzung', () {
    // Das ist der Weg, auf dem die persistente Fassung aus `challenges/data`
    // später eingehängt wird, ohne dass diese Datei sich ändert.
    final _RecordingActiveHuntStore store = _RecordingActiveHuntStore(
      huntAt(5),
    );
    final ProviderContainer container = containerWith(store);

    expect(container.read(activeHuntProvider), huntAt(5));
    expect(identical(container.read(activeHuntStoreProvider), store), isTrue);
  });

  test('der Leseprovider fragt den Speicher genau einmal', () {
    // Nicht Sparsamkeit ist der Punkt, sondern die Ursache des Tests darunter:
    // ein `Provider` merkt sich sein Ergebnis.
    final _RecordingActiveHuntStore store = _RecordingActiveHuntStore(
      huntAt(2),
    );
    final ProviderContainer container = containerWith(store);

    container.read(activeHuntProvider);
    container.read(activeHuntProvider);
    container.read(activeHuntProvider);

    expect(store.reads, 1);
  });

  test(
    'ein Schreibvorgang direkt am Speicher, am Notifier vorbei, erreicht den '
    'Leseprovider weiterhin nicht',
    () async {
      // **Bis Schritt 36 stand hier wörtlich:** „Das ist eine festgehaltene
      // Grenze und kein gewünschtes Verhalten. Wer in Schritt 36 die
      // Phasenmaschine baut und dabei nur in den Speicher schreibt, ändert
      // den Spielstand, ohne dass die Karte davon erfährt [...]. Der Ausweg
      // ist ein `Notifier`, der den Zustand besitzt, setzt und danach
      // speichert [...]. Wird dieser Test rot, weil Schritt 36 genau das
      // eingezogen hat, ist er erledigt und darf weg."
      //
      // Er ist nicht rot geworden, und das ist richtig so: dieser Test
      // schreibt ohne laufende Jagd direkt in den Speicher, **ohne** den
      // inzwischen existierenden [HuntRunNotifier] zu benutzen. Genau dieser
      // Griff bleibt stumm, und das ist jetzt **kein Defekt mehr, sondern der
      // Grund, warum es [HuntRunNotifier] gibt**: wer den Speicher direkt
      // beschreibt, statt über den Notifier zu gehen, umgeht den Besitzer des
      // Zustands, und der Übersetzer kann das nicht verhindern, siehe den
      // Kopfkommentar von [activeHuntProvider]. Der Gegenbeweis, dass ein
      // Schreibvorgang **über** den Notifier sehr wohl ankommt, steht in der
      // Gruppe `HuntRunNotifier` weiter unten
      // ('ein Beobachter wird benachrichtigt, wenn ein Befehl den Zustand
      // ändert').
      final InMemoryActiveHuntStore store = InMemoryActiveHuntStore();
      final ProviderContainer container = containerWith(store);
      var updates = 0;
      container.listen(activeHuntProvider, (_, _) => updates++);

      expect(container.read(activeHuntProvider), isNull);
      await store.writeActiveHunt(huntAt(4));

      expect(container.read(activeHuntProvider), isNull);
      expect(updates, 0);

      // Und der Gegenbeweis, dass der Provider nichts eigenes festhält: nach
      // einer Entwertung liest er den Speicher erneut.
      container.invalidate(activeHuntProvider);
      expect(container.read(activeHuntProvider), huntAt(4));
    },
  );

  group('HuntRunNotifier', () {
    test('build() liefert null, keine laufende Jagd beim Start', () {
      expect(plainContainer().read(huntRunProvider), isNull);
    });

    test('start setzt den Zustand und schreibt die gestartete Jagd', () async {
      final _RecordingActiveHuntStore store = _RecordingActiveHuntStore();
      final ProviderContainer container = containerWith(store);
      final HuntPlan plan = _plan(3);

      await container.read(huntRunProvider.notifier).start(plan);

      final HuntRun? run = container.read(huntRunProvider);
      expect(run, isNotNull);
      expect(run!.currentStopIndex, 0);
      // Nicht nur „es wurde geschrieben", sondern genau das, was der Lauf
      // selbst als sein Lesemodell ausgibt.
      expect(store.writes, hasLength(1));
      expect(store.writes.single, run.toActiveHunt());
      expect(store.writes.single.stationOrdinal, 1);
      expect(store.writes.single.stationCount, 3);
    });

    test('solveStop schreibt erneut, mit einer vorgerückten Station als '
        'Ergebnis', () async {
      final _RecordingActiveHuntStore store = _RecordingActiveHuntStore();
      final HuntRunNotifier notifier = containerWith(
        store,
      ).read(huntRunProvider.notifier);

      await notifier.start(_plan(3));
      await notifier.solveStop(0, pointsAwarded: 10, hintUsed: false);

      expect(store.writes, hasLength(2));
      expect(store.writes[0].stationOrdinal, 1);
      expect(store.writes[1].stationOrdinal, 2);
    });

    test(
      'unlockHint schreibt ebenfalls erneut, aber mit einem anderen Ergebnis '
      'als solveStop: die Station bleibt stehen, nur die Hinweisliste ändert '
      'sich',
      () async {
        // Der Gegenpunkt zum Test darüber, siehe Auftrag: „schreibt
        // irgendwas" darf hier nicht durchgehen, deshalb zwei Befehle mit
        // unterschiedlich geformtem Ergebnis und nicht zweimal derselbe.
        final _RecordingActiveHuntStore store = _RecordingActiveHuntStore();
        final HuntRunNotifier notifier = containerWith(
          store,
        ).read(huntRunProvider.notifier);

        await notifier.start(_plan(3));
        await notifier.unlockHint(1);

        expect(store.writes, hasLength(2));
        expect(store.writes[0].unlockedHintIndices, isEmpty);
        expect(store.writes[0].stationOrdinal, 1);
        expect(store.writes[1].unlockedHintIndices, <int>[1]);
        expect(store.writes[1].stationOrdinal, 1);
      },
    );

    test('end() setzt den Zustand auf null und löscht im Speicher', () async {
      final _RecordingActiveHuntStore store = _RecordingActiveHuntStore();
      final ProviderContainer container = containerWith(store);
      final HuntRunNotifier notifier = container.read(huntRunProvider.notifier);
      await notifier.start(_plan(2));

      await notifier.end();

      expect(container.read(huntRunProvider), isNull);
      expect(store.clears, 1);
      expect(store.readActiveHunt(), isNull);
    });

    test(
      'ein Befehl ohne laufende Jagd tut nichts und schreibt nicht',
      () async {
        final _RecordingActiveHuntStore store = _RecordingActiveHuntStore();
        final ProviderContainer container = containerWith(store);
        final HuntRunNotifier notifier = container.read(
          huntRunProvider.notifier,
        );

        // Alle sechs Befehle, keiner darf werfen und keiner darf schreiben.
        await notifier.unlockHint(1);
        await notifier.solveStop(0, pointsAwarded: 10, hintUsed: false);
        await notifier.skipStop(0);
        await notifier.collectStop(0);
        await notifier.end();

        expect(container.read(huntRunProvider), isNull);
        expect(store.writes, isEmpty);
        expect(store.clears, 0);
      },
    );

    test('activeHuntProvider liefert bei laufender Jagd den Wert aus dem '
        'Notifier, auch wenn im Speicher etwas anderes steht', () async {
      // **Gemessen, nicht angenommen:** eine frühere Fassung dieses Tests
      // ließ den Notifier in denselben Speicher schreiben, den er hinterher
      // ausliest, und prüfte danach nur diesen einen, gemeinsamen Speicher.
      // Da [HuntRunNotifier.start] selbst in ihn schreibt, stand dort zufällig
      // schon derselbe Wert, den auch der Notifier hält, und eine Mutante, die
      // die Rangfolge umdreht und `activeHuntProvider` immer aus dem Speicher
      // lesen lässt, überlebte trotzdem: der Speicher enthielt ja die richtige
      // Antwort, nur aus dem falschen Grund. Deshalb steht hier jetzt ein
      // zweiter, am Notifier vorbei gerichteter Schreibzugriff, der den
      // Speicher **nach** dem Start bewusst auf einen anderen Wert setzt, für
      // eine Divergenz, die nicht von selbst verschwindet.
      final InMemoryActiveHuntStore store = InMemoryActiveHuntStore();
      final ProviderContainer container = containerWith(store);

      await container.read(huntRunProvider.notifier).start(_plan(3));
      await store.writeActiveHunt(huntAt(6));

      final ActiveHunt? value = container.read(activeHuntProvider);
      expect(value, isNot(huntAt(6)));
      expect(value!.stationOrdinal, 1);
      expect(value.stationCount, 3);
    });

    test('ein Beobachter von activeHuntProvider wird benachrichtigt, wenn ein '
        'Befehl den Zustand ändert', () async {
      // Das ist die Zusicherung, um die es in diesem Auftrag geht: der Weg
      // über den Notifier benachrichtigt, anders als der direkte
      // Schreibzugriff im Test oben.
      //
      // `container.pump()` ist kein Umweg um dieses Verhalten, sondern die
      // dafür vorgesehene Wartestelle: Riverpod 3 sammelt Benachrichtigungen
      // an Beobachter (nicht den Wert selbst, siehe `container.read` weiter
      // oben und unten) bis zum Ende der laufenden Ereignisschleife
      // (`ProviderScheduler`, `scheduler.dart`), damit mehrere Änderungen im
      // selben Durchlauf nur eine Neuzeichnung auslösen. `pump()` wartet
      // genau auf dieses Ende.
      final ProviderContainer container = containerWith(
        _RecordingActiveHuntStore(),
      );
      var updates = 0;
      container.listen(activeHuntProvider, (_, _) => updates++);
      final HuntRunNotifier notifier = container.read(huntRunProvider.notifier);

      expect(container.read(activeHuntProvider), isNull);

      await notifier.start(_plan(2));
      await container.pump();
      expect(updates, 1);
      expect(container.read(activeHuntProvider)!.stationOrdinal, 1);

      await notifier.solveStop(0, pointsAwarded: 5, hintUsed: false);
      await container.pump();
      expect(updates, 2);
      expect(container.read(activeHuntProvider)!.stationOrdinal, 2);
    });
  });
}

/// Zählt Lese-, Schreib- und Löschzugriffe, sonst wie
/// [InMemoryActiveHuntStore].
///
/// Vor Schritt 36 zählte diese Klasse nur Lesezugriffe (siehe die Tests oben,
/// die genau das noch prüfen). Seit [HuntRunNotifier] existiert und bei jeder
/// Zustandsänderung schreibt, zeichnet sie zusätzlich jeden Schreib- und
/// Löschvorgang auf: die Tests in der Gruppe `HuntRunNotifier` müssen prüfen,
/// **was** geschrieben wurde, nicht nur, dass irgendetwas geschrieben wurde.
class _RecordingActiveHuntStore implements ActiveHuntStore {
  _RecordingActiveHuntStore([this._hunt]);

  /// Wie oft [readActiveHunt] gerufen wurde.
  int reads = 0;

  /// Jede über [writeActiveHunt] gespeicherte Jagd, in Aufrufreihenfolge.
  final List<ActiveHunt> writes = <ActiveHunt>[];

  /// Wie oft [clearActiveHunt] gerufen wurde.
  int clears = 0;

  ActiveHunt? _hunt;

  @override
  ActiveHunt? readActiveHunt() {
    reads++;
    return _hunt;
  }

  @override
  Future<void> writeActiveHunt(ActiveHunt hunt) async {
    writes.add(hunt);
    _hunt = hunt;
  }

  @override
  Future<void> clearActiveHunt() async {
    clears++;
    _hunt = null;
  }
}

/// Ein [HuntPlan] mit [stopCount] Stationen, genau wie in `hunt_run_test.dart`:
/// nur der Fortschritt eines Laufs wird hier geprüft, nicht die Auswahl des
/// Generators.
HuntPlan _plan(int stopCount) {
  return HuntPlan(
    stops: <HuntStop>[
      for (int i = 1; i <= stopCount; i++)
        HuntStop(fact: _fact(i), puzzle: _puzzle()),
    ],
    difficulty: PuzzleDifficulty.leicht,
    duration: HuntDuration.thirty,
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
