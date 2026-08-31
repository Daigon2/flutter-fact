import 'dart:convert';

import 'package:fact_app/features/challenges/domain/active_hunt_store.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der flüchtige Speicher der laufenden Jagd, Vorgabe und Testdoppel in einem.
void main() {
  /// Eine gültige Jagd an der [stationOrdinal]-ten Station.
  ///
  /// Über [ActiveHunt.tryFrom], weil der Konstruktor privat ist. Genau das
  /// macht die Vorbedingung von [ActiveHuntStore.writeActiveHunt] haltbar:
  /// hier kommt keine ungültige Jagd in den Speicher, weil es keine gibt.
  ActiveHunt huntAt(int stationOrdinal) => ActiveHunt.tryFrom(
    stationOrdinal: stationOrdinal,
    stationCount: 7,
    stationTitle: 'Station $stationOrdinal',
    stationLatitude: 48.1467,
    stationLongitude: 11.5661,
    purchasedHintCount: 0,
    duration: HuntDuration.sixty,
  )!;

  test('ohne Jagd ist der Speicher leer', () {
    expect(InMemoryActiveHuntStore().readActiveHunt(), isNull);
  });

  test('eine vorgesetzte Jagd wird gelesen', () {
    final ActiveHunt hunt = huntAt(3);

    final InMemoryActiveHuntStore store = InMemoryActiveHuntStore(hunt: hunt);

    expect(identical(store.readActiveHunt(), hunt), isTrue);
  });

  test('geschrieben wird gelesen', () async {
    final InMemoryActiveHuntStore store = InMemoryActiveHuntStore();

    await store.writeActiveHunt(huntAt(2));

    expect(store.readActiveHunt(), huntAt(2));
  });

  test('ein zweiter Schreibvorgang ersetzt den ersten', () async {
    // Drei Schreibvorgänge und nicht zwei, siehe Muster 20: bei zwei sind „der
    // letzte gewinnt" und „der erste bleibt" nicht in jeder Fassung
    // unterscheidbar, wenn der Anfangszustand leer ist. Erst der dritte trennt
    // „ersetzen" von „nur den ersten behalten".
    final InMemoryActiveHuntStore store = InMemoryActiveHuntStore();

    await store.writeActiveHunt(huntAt(1));
    await store.writeActiveHunt(huntAt(2));
    await store.writeActiveHunt(huntAt(3));

    expect(store.readActiveHunt(), huntAt(3));
  });

  test('löschen macht den Speicher leer', () async {
    final InMemoryActiveHuntStore store = InMemoryActiveHuntStore(
      hunt: huntAt(4),
    );

    await store.clearActiveHunt();

    expect(store.readActiveHunt(), isNull);
  });

  test('löschen ist idempotent', () async {
    final InMemoryActiveHuntStore store = InMemoryActiveHuntStore();

    await store.clearActiveHunt();
    await store.clearActiveHunt();

    expect(store.readActiveHunt(), isNull);
  });

  test('nach dem Löschen kann wieder eine Jagd beginnen', () async {
    final InMemoryActiveHuntStore store = InMemoryActiveHuntStore(
      hunt: huntAt(1),
    );

    await store.clearActiveHunt();
    await store.writeActiveHunt(huntAt(5));

    expect(store.readActiveHunt(), huntAt(5));
  });

  test('der flüchtige Speicher überlebt sich selbst nicht', () async {
    // Das ist der bekannte, gewollte Zustand: der Vertrag steht, die Technik
    // fehlt, und ADR-007s Produktvorgabe ist damit **nicht** erfüllt. Ein
    // zweiter Speicher ist hier der Ersatz für einen App-Neustart.
    final InMemoryActiveHuntStore firstRun = InMemoryActiveHuntStore();
    await firstRun.writeActiveHunt(huntAt(3));

    final InMemoryActiveHuntStore secondRun = InMemoryActiveHuntStore();

    expect(firstRun.readActiveHunt(), isNotNull);
    expect(secondRun.readActiveHunt(), isNull);
  });

  test('eine persistente Umsetzung braucht nur diese drei Methoden', () async {
    // Die Probe ist der Punkt: eine Umsetzung, die ihre Nutzlast über
    // `toPayload`, `jsonEncode`, `jsonDecode` und `tryFromPayload` schickt,
    // kommt ohne eigenes Wissen über die Felder aus. Genau so soll die spätere
    // Fassung in `challenges/data` aussehen, nur mit einem echten
    // Gerätespeicher anstelle der Zeichenkette hier. **Sie wird verworfen,
    // wenn die Nutzlast unlesbar ist**, und reparieren kann sie nichts, weil
    // sie die Felder nicht kennt.
    //
    // Die Zeichenkette und nicht die Abbildung ist Absicht: ein
    // Schlüssel-Wert-Speicher hält Text, und erst dadurch prüft dieser Test
    // die Stelle, an der Punkt 3 des Vertrags hängt. `jsonEncode` steht in
    // `writeActiveHunt` **ohne** `try`, und das hält nur, weil keine Jagd eine
    // nicht-endliche Lage tragen kann.
    final _PayloadActiveHuntStore store = _PayloadActiveHuntStore();

    expect(store.readActiveHunt(), isNull);

    await store.writeActiveHunt(huntAt(6));
    expect(store.readActiveHunt(), huntAt(6));

    // Eine fremde Fassung: lesbares JSON, unbrauchbarer Inhalt.
    store.raw = '{"v":99,"stationOrdinal":6}';
    expect(store.readActiveHunt(), isNull);

    // Gar kein JSON. Hier wirft `jsonDecode`, und **das** ist die Stelle, an
    // der eine Umsetzung ein `try` braucht: auf der Leseseite, nicht auf der
    // Schreibseite.
    store.raw = 'kaputt';
    expect(store.readActiveHunt(), isNull);

    await store.clearActiveHunt();
    expect(store.readActiveHunt(), isNull);
  });
}

/// Eine Umsetzung, die nur mit der Nutzlast arbeitet.
///
/// Steht für die spätere Fassung in `challenges/data`: sie hält einen Rohwert,
/// wie ihn ein Gerätespeicher liefert, und kennt kein einziges Feld der Jagd.
class _PayloadActiveHuntStore implements ActiveHuntStore {
  /// Der Rohwert, wie er auf der Platte läge: Text oder nichts.
  String? raw;

  @override
  ActiveHunt? readActiveHunt() {
    final String? text = raw;
    if (text == null) {
      return null;
    }
    try {
      return ActiveHunt.tryFromPayload(jsonDecode(text));
    } on FormatException {
      // Die Quelle macht es genauso und verwirft still, wenn `JSON.parse`
      // scheitert (`storage.jsx:6-11`).
      return null;
    }
  }

  @override
  Future<void> writeActiveHunt(ActiveHunt hunt) async {
    // **Ohne `try`, und das ist eine Aussage über den Typ.** `jsonEncode` wirft
    // einen `JsonUnsupportedObjectError` für `NaN` und die beiden
    // Unendlichkeiten, und keine davon kann in einer Jagd stehen: der
    // Konstruktor ist privat, `ActiveHunt.tryFrom` verwirft sie. Deshalb kann
    // `writeActiveHunt` sein „wirft nicht" halten, ohne die Prüfregeln ein
    // zweites Mal aufzuschreiben.
    raw = jsonEncode(hunt.toPayload());
  }

  @override
  Future<void> clearActiveHunt() async {
    raw = null;
  }
}
