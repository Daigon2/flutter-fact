import 'dart:convert';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/challenges/data/key_value_active_hunt_store.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:flutter_test/flutter_test.dart';

/// Senke, die mitschreibt.
class _RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}

/// Der persistente Speicher der laufenden Jagd.
///
/// Der einzige der fünf, bei dem das flüchtige Verhalten nicht unbequem, sondern
/// falsch war: es kostete einen Spielstand. ADR-007 schließt genau das als
/// Produktvorgabe aus.
void main() {
  /// Eine gültige Jagd an der [stationOrdinal]-ten Station.
  ///
  /// Über `ActiveHunt.tryFrom`, weil der Konstruktor privat ist. Genau daran
  /// hängt, dass `writeActiveHunt` ohne `try` auskommt.
  ActiveHunt huntAt(int stationOrdinal) => ActiveHunt.tryFrom(
    stationOrdinal: stationOrdinal,
    stationCount: 7,
    stationTitle: 'Station $stationOrdinal',
    stationLatitude: 48.1467,
    stationLongitude: 11.5661,
    purchasedHintCount: 0,
    duration: HuntDuration.sixty,
  )!;

  test('ohne gespeicherte Jagd bleibt es null', () {
    final _RecordingSink sink = _RecordingSink();

    final ActiveHunt? restored = KeyValueActiveHuntStore(
      InMemoryKeyValueStore(),
      sink: sink,
    ).readActiveHunt();

    expect(restored, isNull);
    // **Und ohne Meldung.** Keine laufende Jagd ist der Normalzustand jedes
    // Nutzers. Wer ihn meldet, füllt die Senke bei jedem Start mit einer
    // Nichtmeldung und macht die echten unauffindbar.
    expect(sink.events, isEmpty);
  });

  test('eine geschriebene Jagd übersteht einen neuen Speicher', () async {
    // Das ist die Aussage, um die es hier geht, und sie ist absichtlich über
    // **zwei** Speicher-Objekte auf demselben Gerätespeicher gebaut: ein
    // Objekt, das seinen eigenen Zustand hält, käme durch einen Test mit nur
    // einem durch, und genau das tat die flüchtige Umsetzung.
    final KeyValueStore preferences = InMemoryKeyValueStore();
    await KeyValueActiveHuntStore(preferences).writeActiveHunt(huntAt(3));

    final ActiveHunt? restored = KeyValueActiveHuntStore(
      preferences,
    ).readActiveHunt();

    expect(restored, huntAt(3));
  });

  test('ein zweiter Schreibvorgang ersetzt den ersten', () async {
    // Drei und nicht zwei, wie im Vertragstest: bei zwei sind „der letzte
    // gewinnt" und „der erste bleibt" bei leerem Anfangszustand nicht
    // unterscheidbar.
    final KeyValueStore preferences = InMemoryKeyValueStore();
    final KeyValueActiveHuntStore store = KeyValueActiveHuntStore(preferences);

    await store.writeActiveHunt(huntAt(1));
    await store.writeActiveHunt(huntAt(2));
    await store.writeActiveHunt(huntAt(3));

    expect(store.readActiveHunt(), huntAt(3));
  });

  test('geschrieben wird unter den Schlüssel der Quelle', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();

    await KeyValueActiveHuntStore(preferences).writeActiveHunt(huntAt(3));

    expect(preferences.readString('fact_active_challenge'), isNotNull);
  });

  test('geschrieben wird die Nutzlast der Domäne, als JSON', () async {
    // Nicht bloß „irgendetwas steht da". Ohne diese Zusicherung käme eine
    // Umsetzung durch, die ein eigenes Format erfindet, und dann gäbe es zwei
    // Orte, an denen die Form der Jagd definiert ist.
    final KeyValueStore preferences = InMemoryKeyValueStore();

    await KeyValueActiveHuntStore(preferences).writeActiveHunt(huntAt(3));

    expect(
      jsonDecode(preferences.readString(KeyValueActiveHuntStore.storageKey)!),
      huntAt(3).toPayload(),
    );
  });

  test('löschen macht den Speicher leer', () async {
    final KeyValueStore preferences = InMemoryKeyValueStore();
    final KeyValueActiveHuntStore store = KeyValueActiveHuntStore(preferences);
    await store.writeActiveHunt(huntAt(3));

    await store.clearActiveHunt();

    expect(store.readActiveHunt(), isNull);
    expect(preferences.readString(KeyValueActiveHuntStore.storageKey), isNull);
  });

  test('löschen ohne gespeicherte Jagd ist erlaubt', () async {
    final KeyValueActiveHuntStore store = KeyValueActiveHuntStore(
      InMemoryKeyValueStore(),
    );

    await store.clearActiveHunt();

    expect(store.readActiveHunt(), isNull);
  });

  test('eine Zeichenkette, die kein JSON ist, wird verworfen und gemeldet', () {
    // Der Defekt des Gerätespeichers, nicht der Nutzlast. Der Vertrag erlaubt
    // dafür ausdrücklich ein `try`, und der Rückgabewert muss `null` sein und
    // keine Ausnahme: gelesen wird beim Start, vor dem ersten Bild.
    final _RecordingSink sink = _RecordingSink();
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueActiveHuntStore.storageKey: 'kein json',
    });

    final ActiveHunt? restored = KeyValueActiveHuntStore(
      preferences,
      sink: sink,
    ).readActiveHunt();

    expect(restored, isNull);
    expect(sink.events.map((DiagnosticEvent event) => event.name), <String>[
      KeyValueActiveHuntStore.discardedEventName,
    ]);
  });

  test('gültiges JSON mit falscher Form wird verworfen und gemeldet', () {
    // Der zweite Weg zu `null`, und er läuft durch dieselbe eine Meldung. Die
    // Prüfung selbst steht in `ActiveHunt.tryFromPayload`; dieser Test hält
    // fest, dass die Umsetzung sie **benutzt** statt eine eigene zu haben.
    final _RecordingSink sink = _RecordingSink();
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueActiveHuntStore.storageKey: jsonEncode(<String, Object>{
        'v': ActiveHunt.payloadVersion,
        'stationOrdinal': 3,
      }),
    });

    final ActiveHunt? restored = KeyValueActiveHuntStore(
      preferences,
      sink: sink,
    ).readActiveHunt();

    expect(restored, isNull);
    expect(sink.events.map((DiagnosticEvent event) => event.name), <String>[
      KeyValueActiveHuntStore.discardedEventName,
    ]);
  });

  test('eine Nutzlast der falschen Fassung wird verworfen', () {
    // Der Fall, für den `payloadVersion` überhaupt da ist. Er kommt beim
    // nächsten Schritt: das Hinweis-Feld wird von einer Anzahl auf Indizes
    // umgestellt, und dann trifft genau dieser Zweig jede Jagd, die vorher
    // gespeichert wurde.
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueActiveHuntStore.storageKey: jsonEncode(<String, Object>{
        ...huntAt(3).toPayload().map(
          (String key, Object? value) => MapEntry<String, Object>(key, value!),
        ),
        'v': ActiveHunt.payloadVersion + 1,
      }),
    });

    expect(KeyValueActiveHuntStore(preferences).readActiveHunt(), isNull);
  });

  test('ohne eigene Senke wird nichts ausgegeben und nichts geworfen', () {
    // Die Vorgabe ist die stumme Senke. Ein Speicher, der ohne Senke wirft
    // oder druckt, verstieße gegen Gate 9 und gegen den Vertrag der Senke.
    final KeyValueStore preferences = InMemoryKeyValueStore(<String, Object>{
      KeyValueActiveHuntStore.storageKey: 'kein json',
    });

    expect(KeyValueActiveHuntStore(preferences).readActiveHunt(), isNull);
  });
}
