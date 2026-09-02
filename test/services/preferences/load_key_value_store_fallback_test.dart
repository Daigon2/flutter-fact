import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/services/preferences/shared_preferences_key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Senke, die mitschreibt.
class _RecordingSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}

/// Der Rückfall, wenn der Gerätespeicher nicht zu laden ist.
///
/// ## Warum das eine eigene Datei ist
///
/// Weil der Fall an einem **globalen** Zustand hängt:
/// `SharedPreferences.setMockInitialValues` setzt
/// `SharedPreferencesStorePlatform.instance` prozessweit. Sobald irgendein Test
/// derselben Datei das tut, ist der Plattformkanal ersetzt und
/// `getInstance()` scheitert nie mehr. Ein Test, der hier neben den anderen
/// stünde, wäre von der Deklarationsreihenfolge abhängig, und ein
/// reihenfolgeabhängiger Test ist nach `docs/engineering/testing.md` ein
/// Defekt.
///
/// `flutter test` fährt jede Testdatei in einem eigenen Isolate. Diese Datei
/// setzt nirgends eine Test-Plattform, der echte Plattformkanal bleibt stehen,
/// und ohne registrierte Plattform wirft er.
void main() {
  test('ohne Gerätespeicher entsteht der flüchtige Rückfall', () async {
    // Die Bindung wird gebraucht, damit der Plattformkanal überhaupt
    // angesprochen wird. Ohne sie scheitert der Aufruf an einer anderen Stelle,
    // und der Test bewiese dann etwas anderes als er behauptet.
    TestWidgetsFlutterBinding.ensureInitialized();
    final _RecordingSink sink = _RecordingSink();

    final KeyValueStore store = await loadKeyValueStore(sink: sink);

    // Kein `throwsA`: der Start darf hieran **nicht** scheitern. Eine App ohne
    // Präferenzspeicher ist vollständig benutzbar und fragt beim nächsten Start
    // noch einmal nach der Sprache; eine App, die deswegen nicht startet, ist
    // es nicht.
    expect(store, isA<InMemoryKeyValueStore>());
    expect(sink.events.map((DiagnosticEvent event) => event.name), <String>[
      'preferences.load_failed',
    ]);
    // Der Fehlertyp gehört in die Meldung, sonst steht auf dem Gerät nur
    // „ging nicht" und niemand weiß, ob ein Plugin fehlt oder die Platte voll
    // ist.
    expect(sink.events.single.attributes['error'], isNotEmpty);
  });

  test('der Rückfall ist benutzbar und nicht bloß vorhanden', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final KeyValueStore store = await loadKeyValueStore();
    await store.writeBool('flag', true);

    // Lesbar innerhalb der Sitzung, verloren beim nächsten Start. Genau das ist
    // der Kompromiss, und er ist hier festgeschrieben, damit niemand den
    // Rückfall später für Persistenz hält.
    expect(store.readBool('flag'), isTrue);
  });
}
