import 'package:fact_app/features/challenges/application/active_hunt_providers.dart';
import 'package:fact_app/features/challenges/domain/active_hunt_store.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
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
    purchasedHintCount: 1,
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
    'ein Schreibvorgang am Speicher erreicht den Leseprovider nicht',
    () async {
      // **Das ist eine festgehaltene Grenze und kein gewünschtes Verhalten.**
      // Wer in Schritt 36 die Phasenmaschine baut und dabei nur in den
      // Speicher schreibt, ändert den Spielstand, ohne dass die Karte davon
      // erfährt: kein Fehler, keine Meldung, nur eine Station, die stehen
      // bleibt. Der Ausweg ist ein `Notifier`, der den Zustand besitzt, setzt
      // und **danach** speichert, wie `FirstLaunchNotifier` es tut.
      //
      // Wird dieser Test rot, weil Schritt 36 genau das eingezogen hat, ist er
      // erledigt und darf weg.
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
}

/// Zählt die Lesezugriffe, sonst wie [InMemoryActiveHuntStore].
class _RecordingActiveHuntStore implements ActiveHuntStore {
  _RecordingActiveHuntStore(this._hunt);

  /// Wie oft [readActiveHunt] gerufen wurde.
  int reads = 0;

  ActiveHunt? _hunt;

  @override
  ActiveHunt? readActiveHunt() {
    reads++;
    return _hunt;
  }

  @override
  Future<void> writeActiveHunt(ActiveHunt hunt) async {
    _hunt = hunt;
  }

  @override
  Future<void> clearActiveHunt() async {
    _hunt = null;
  }
}
