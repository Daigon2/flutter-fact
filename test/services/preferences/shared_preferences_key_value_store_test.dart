import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/services/preferences/shared_preferences_key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Senke, die mitschreibt, damit ein Test die Meldung lesen kann.
///
/// Bewusst hier und nicht als gemeinsames Testdoppel: die Datei prüft genau
/// zwei Dinge über Meldungen, und ein geteiltes Doppel wäre ein zweiter Ort,
/// an dem sich das Verhalten ändern kann.
class _RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}

/// Der Vendor-Adapter über `shared_preferences`.
///
/// **Was diese Datei nicht prüft, und warum:** den Zweig in `_write`, der auf
/// ein `false` als Rückgabewert von `setBool` reagiert. `SharedPreferences`
/// reicht dafür an die Plattform durch, und die Test-Plattform
/// (`InMemorySharedPreferencesStore`, gesetzt von `setMockInitialValues`)
/// antwortet immer mit `true`. Erreichbar wäre der Zweig nur über ein eigenes
/// `SharedPreferencesStorePlatform`, und das steckt in
/// `shared_preferences_platform_interface`, einem Paket, das heute nur
/// transitiv im Baum liegt. Ein weiteres Paket in `dev_dependencies` ist nach
/// `CLAUDE.md` zustimmungspflichtig und für einen Zweig dieser Größe nicht
/// beantragt. **Der Zweig bleibt damit eine Behauptung**, und das steht hier,
/// statt es zu verschweigen.
void main() {
  setUp(() {
    // Setzt zugleich die Test-Plattform und verwirft eine schon geladene
    // Instanz, siehe `shared_preferences_legacy.dart:272-285`. Ohne den Aufruf
    // in `setUp` trüge der zweite Test die Werte des ersten.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SharedPreferencesKeyValueStore> storeWith(
    Map<String, Object> values, {
    DiagnosticSink sink = const SilentDiagnosticSink(),
  }) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferencesKeyValueStore(
      await SharedPreferences.getInstance(),
      sink: sink,
    );
  }

  test('liest, was auf dem Gerät liegt', () async {
    final SharedPreferencesKeyValueStore store = await storeWith(
      <String, Object>{'flag': true, 'text': 'de'},
    );

    expect(store.readBool('flag'), isTrue);
    expect(store.readString('text'), 'de');
  });

  test('ein leerer Schlüssel liefert null', () async {
    final SharedPreferencesKeyValueStore store = await storeWith(
      <String, Object>{},
    );

    expect(store.readBool('flag'), isNull);
    expect(store.readString('text'), isNull);
  });

  test('geschrieben wird gelesen, synchron', () async {
    // Die tragende Eigenschaft des ganzen Aufbaus: nach dem Schreiben ist der
    // Wert **ohne** await zu lesen. Genau darauf steht, dass die fünf Speicher
    // synchron lesen dürfen.
    final SharedPreferencesKeyValueStore store = await storeWith(
      <String, Object>{},
    );

    await store.writeBool('flag', true);
    await store.writeString('text', 'en');

    expect(store.readBool('flag'), isTrue);
    expect(store.readString('text'), 'en');
  });

  test('löschen macht den Schlüssel leer', () async {
    final SharedPreferencesKeyValueStore store = await storeWith(
      <String, Object>{'flag': true},
    );

    await store.remove('flag');

    expect(store.readBool('flag'), isNull);
  });

  test('löschen eines unbekannten Schlüssels ist erlaubt', () async {
    final SharedPreferencesKeyValueStore store = await storeWith(
      <String, Object>{'flag': true},
    );

    await store.remove('unbekannt');

    expect(store.readBool('flag'), isTrue);
  });

  test(
    'ein falsch typisierter Wert liefert null statt einer Ausnahme',
    () async {
      // **Der teuerste Fall dieser Datei, und er ist gemessen und nicht
      // vermutet:** `SharedPreferences.getBool` castet den Wert aus dem
      // Zwischenspeicher hart (`_preferenceCache[key] as bool?`) und wirft bei
      // einem Typwechsel. Ohne das `try` in `_read` würde ein Formatwechsel auf
      // dem Gerät nicht zu einer verworfenen Präferenz, sondern zu einem Absturz
      // beim Start, denn gelesen wird in `bootstrap()` vor dem ersten Bild.
      final _RecordingSink sink = _RecordingSink();
      final SharedPreferencesKeyValueStore store = await storeWith(
        <String, Object>{'flag': 'true'},
        sink: sink,
      );

      expect(store.readBool('flag'), isNull);
      expect(sink.events.map((DiagnosticEvent event) => event.name), <String>[
        'preferences.read_failed',
      ]);
      expect(sink.events.single.attributes['key'], 'flag');
    },
  );

  test(
    'loadKeyValueStore liefert den Geräte-Speicher, wenn er da ist',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'flag': true});

      final KeyValueStore store = await loadKeyValueStore();

      expect(store, isA<SharedPreferencesKeyValueStore>());
      expect(store.readBool('flag'), isTrue);
    },
  );
}
