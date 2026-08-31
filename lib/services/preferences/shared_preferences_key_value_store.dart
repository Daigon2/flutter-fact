/// Der einzige Ort in `lib/`, an dem `shared_preferences` vorkommt.
///
/// Durchgesetzt als Regel 22 in `docs/architecture/dependency-rules.md`, geprüft
/// von `tool/check_architecture.dart`. Vorbild sind die Regeln 19 bis 21, die
/// dasselbe für WebView, Karten- und Geo-SDK tun: kein Verbot, eine Zuweisung.
///
/// `lib/features/README.md` gibt `services/` als Ort für „Vendor-Adapter ohne
/// Oberfläche". Ein Präferenzspeicher ist genau das.
///
/// Das Paket war bis zum 31.08.2026 nur eine transitive Abhängigkeit von
/// `supabase_flutter` (`pubspec.lock`, `shared_preferences 2.5.5`). Es in
/// `pubspec.yaml` zu heben war nach `CLAUDE.md` zustimmungspflichtig und ist am
/// 31.08.2026 von Janek freigegeben worden, gemeinsam mit fünf anderen Paketen.
/// Neuer Code kommt dadurch nicht in den Bau, er war schon drin.
library;

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lädt den Gerätespeicher **einmal** und liefert einen synchron lesbaren
/// [KeyValueStore].
///
/// Das ist der Grund, warum `bootstrap()` ein `await` vor dem ersten Bild
/// braucht: alle fünf Speicher lesen synchron, und dafür müssen die Werte vorher
/// da sein.
///
/// ## Was passiert, wenn der Gerätespeicher nicht zu laden ist
///
/// Es entsteht ein [InMemoryKeyValueStore], und der Fehlschlag geht an [sink].
/// Die App startet also, merkt sich aber nichts.
///
/// Die Alternative wäre, den Start abzubrechen wie bei fehlender
/// Supabase-Konfiguration. Sie ist verworfen, und der Unterschied ist der
/// Grund: ohne Supabase gibt es keine Fakten und damit keine App, ohne
/// Präferenzspeicher gibt es eine vollständig benutzbare App, die beim nächsten
/// Start die Sprache noch einmal fragt. Einen Start daran scheitern zu lassen,
/// wäre teurer als der Verlust.
///
/// **Still ist es trotzdem nicht.** Ohne die Meldung an [sink] wäre das der
/// stille Ausfall, gegen den `test/app/bootstrap_test.dart` das Projekt an vier
/// Stellen absichert: eine App, die heil aussieht und nichts behält.
Future<KeyValueStore> loadKeyValueStore({
  DiagnosticSink sink = const SilentDiagnosticSink(),
}) async {
  try {
    return SharedPreferencesKeyValueStore(
      await SharedPreferences.getInstance(),
      sink: sink,
    );
  } on Object catch (error) {
    // Absichtlich `Object` und nicht `Exception`: die Plattformkanäle melden
    // ihre Fehler als `PlatformException`, ältere Fassungen auch als
    // `MissingPluginException`, und ein `Error` aus der Bindung wäre hier
    // genauso wenig ein Grund, die App nicht zu starten.
    sink.report(
      DiagnosticEvent('preferences.load_failed', <String, String>{
        'error': error.runtimeType.toString(),
      }),
    );
    return InMemoryKeyValueStore();
  }
}

/// [KeyValueStore] über `shared_preferences`.
///
/// Lesen geht gegen den Zwischenspeicher, den `SharedPreferences.getInstance()`
/// gefüllt hat, und ist deshalb synchron möglich. Schreiben geht an die
/// Plattform und kann scheitern.
final class SharedPreferencesKeyValueStore implements KeyValueStore {
  /// [preferences] ist die geladene Instanz, [sink] nimmt Fehlschläge auf.
  ///
  /// Der Weg hierher ist [loadKeyValueStore]. Der Konstruktor bleibt öffentlich,
  /// damit ein Test mit `SharedPreferences.setMockInitialValues` gegen die echte
  /// Umsetzung prüfen kann statt nur gegen den Rückfall.
  SharedPreferencesKeyValueStore(
    this._preferences, {
    DiagnosticSink sink = const SilentDiagnosticSink(),
  }) : _sink = sink;

  final SharedPreferences _preferences;
  final DiagnosticSink _sink;

  @override
  bool? readBool(String key) => _read<bool>(key, _preferences.getBool);

  @override
  String? readString(String key) => _read<String>(key, _preferences.getString);

  @override
  Future<void> writeBool(String key, bool value) =>
      _write(key, () => _preferences.setBool(key, value));

  @override
  Future<void> writeString(String key, String value) =>
      _write(key, () => _preferences.setString(key, value));

  @override
  Future<void> remove(String key) =>
      _write(key, () => _preferences.remove(key));

  /// Liest über [getter] und macht aus jedem Fehlschlag ein `null`.
  ///
  /// Der Zwischenspeicher wirft normalerweise nicht, aber `getBool` wirft
  /// sehr wohl, wenn unter dem Schlüssel ein Wert anderen Typs liegt: intern ist
  /// es ein `as`-Cast. Genau dieser Fall entsteht bei einem Formatwechsel, und
  /// der Vertrag von [KeyValueStore.readBool] verlangt dafür `null` statt einer
  /// Ausnahme.
  T? _read<T>(String key, T? Function(String key) getter) {
    try {
      return getter(key);
    } on Object catch (error) {
      _sink.report(
        DiagnosticEvent('preferences.read_failed', <String, String>{
          'key': key,
          'error': error.runtimeType.toString(),
        }),
      );
      return null;
    }
  }

  /// Schreibt über [operation] und meldet jeden Fehlschlag, ohne zu werfen.
  ///
  /// Zwei Arten von Fehlschlag, und beide werden gemeldet: eine Ausnahme aus dem
  /// Plattformkanal, und ein `false` als Rückgabewert. Das `false` ist der
  /// leisere der beiden und wäre ohne diese Prüfung nicht zu sehen.
  Future<void> _write(String key, Future<bool> Function() operation) async {
    try {
      if (await operation()) {
        return;
      }
      _sink.report(
        DiagnosticEvent('preferences.write_rejected', <String, String>{
          'key': key,
        }),
      );
    } on Object catch (error) {
      _sink.report(
        DiagnosticEvent('preferences.write_failed', <String, String>{
          'key': key,
          'error': error.runtimeType.toString(),
        }),
      );
    }
  }
}
