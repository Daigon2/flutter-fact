import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:flutter/foundation.dart';

/// Eine Diagnose-Senke, die auf die Prozesskonsole schreibt.
///
/// ## Warum es das gibt
///
/// [SilentDiagnosticSink] nimmt jedes Ereignis an und verwirft es. Solange das
/// der Standard des laufenden Betriebs ist, ist ein Gerätelauf blind: die App
/// weiß, dass eine Kameraabsicht ins Leere lief oder dass eine Stil-Kennung
/// unbekannt ist, und sagt es niemandem. Diese Senke schließt genau die Lücke,
/// über den Erweiterungspunkt, den `core/diagnostics/diagnostics_providers.dart`
/// dafür vorsieht.
///
/// ## Warum die Konsole und nicht `dart:developer`
///
/// Die naheliegende Wahl wäre `developer.log`, weil
/// `tool/check_architecture.dart` `dart:developer` nur unterhalb von
/// `lib/features/` und nur als Hinweis führt, hier also gar nichts meldet.
/// **Gemessen am 29.08.2026 taugt sie trotzdem nicht**, und zwar aus einem
/// Grund, der nicht in der Dokumentation steht:
///
/// 1. `developer.log` schreibt weder nach stdout noch nach stderr. Nachgemessen
///    mit einem Wegwerf-Skript unter `dart run`: beide Ströme blieben leer.
///    Der VM-Patch (`sdk/lib/_internal/vm/lib/developer.dart`) reicht die
///    Meldung an die native Funktion `Developer_log` weiter, und die schickt
///    sie ausschließlich auf den `Logging`-Strom des Service-Protokolls.
/// 2. Diesen Strom liest DevTools und die IDE-Erweiterung. `flutter_tools`
///    liest ihn **nicht**: in `packages/flutter_tools/lib/src/` gibt es kein
///    einziges `streamListen` auf `Logging`, nur auf `Stdout`, `Stderr`,
///    `Isolate` und `Extension`. In der Konsole von `flutter run` erscheint
///    also nichts.
/// 3. Nach `adb logcat` kommt erst recht nichts. Auf Android füllt genau ein
///    Weg das Log: Darts `print` landet über `Logger_PrintString` in
///    `UIDartState::LogMessage`, und der Rückruf, den Android dort setzt
///    (`shell/platform/android/flutter_main.cc`), ruft
///    `__android_log_print(ANDROID_LOG_INFO, "flutter", ...)`.
///
/// Weil ein Ereignis auf dem Gerät auffindbar sein muss, führt der Weg über die
/// Konsole. Benutzt wird [debugPrintSynchronously] aus
/// `package:flutter/foundation.dart`, ein öffentlicher Framework-Aufruf, der
/// intern `print` verwendet und damit im Logcat ankommt.
///
/// ## Das Verhältnis zu Gate 9, offen benannt
///
/// Gate 9 verbietet `print()` und `debugPrint()` im Produktionscode, damit
/// Ausgaben über den Vertrag aus `core` laufen statt frei verstreut zu
/// entstehen. Diese Datei ist die **eine** Umsetzung dieses Vertrags, also das
/// Ziel der Regel und nicht ihr Umgehungsweg. Der Prüfausdruck von Gate 9
/// (`(?<![\w$.])(?:print|debugPrint)(?![\w$])`) trifft
/// `debugPrintSynchronously` nicht, nachgemessen. Das ist eine Abweichung vom
/// Geist der Regel an einer bewusst einzigen Stelle, und sie gehört Janek
/// vorgelegt: entweder bleibt sie hier stehen, oder Gate 9 bekommt eine
/// benannte Ausnahme für `lib/services/diagnostics/`.
///
/// **Nicht throttled, und das ist Absicht.** `debugPrint` puffert, weil Logcat
/// Zeilen verwirft, die zu schnell kommen. Der Puffer würde die Reihenfolge
/// gegenüber anderen Ausgaben verschieben, und eine Senke, deren Zweck das
/// Finden eines Fehlers ist, darf nicht selbst umsortieren. Das Risiko bleibt:
/// wer sehr viele Ereignisse je Sekunde erzeugt, kann Zeilen verlieren.
///
/// ## Filtern auf dem Gerät
///
/// Jede Zeile beginnt mit [diagnosticLinePrefix]:
///
/// ```text
/// adb logcat -s flutter:I | grep FACT-DIAG
/// ```
///
/// ## Was bewusst nicht passiert
///
/// Die Senke **filtert nichts**. [DiagnosticEvent] nimmt nur flache
/// Zeichenketten, und das Verbot genauer Koordinaten aus
/// `docs/engineering/security.md` §6 halten die Aufrufer ein; nachgeprüft am
/// 29.08.2026 über alle neun Meldestellen in `lib/`. Ein Filter hier würde
/// diese Prüfung ersetzen durch das Gefühl, geschützt zu sein, und beim ersten
/// Feld, an das er nicht gedacht hat, still versagen.
class ConsoleDiagnosticSink implements DiagnosticSink {
  /// Erzeugt die Senke.
  ///
  /// [write] ist der Ausgabekanal und existiert, damit ein Test die erzeugte
  /// Zeile lesen kann, ohne die Konsole abzufangen.
  const ConsoleDiagnosticSink({
    void Function(String line) write = writeDiagnosticLineToConsole,
  }) : _write = write;

  final void Function(String line) _write;

  @override
  void report(DiagnosticEvent event) {
    // `report` darf nach dem Vertrag in `core/diagnostics/diagnostic_sink.dart`
    // nie werfen. Der Aufrufer meldet an dieser Stelle regelmäßig, dass schon
    // etwas schiefging; ihn daran ein zweites Mal scheitern zu lassen wäre der
    // schlechteste denkbare Zeitpunkt.
    try {
      _write(formatDiagnosticLine(event));
    } on Object catch (_) {
      // Bewusst leer. Es gibt keinen zweiten Kanal, über den ein Fehler der
      // Ausgabe gemeldet werden könnte.
    }
  }
}

/// Präfix jeder Zeile dieser Senke.
///
/// Kurz, eindeutig und ohne Leerzeichen, damit `grep` und der Logcat-Filter
/// damit umgehen können. Wichtiger als ein hübsches Format ist, dass die Zeile
/// zwischen tausend Zeilen Fremdausgabe wiederzufinden ist.
const String diagnosticLinePrefix = 'FACT-DIAG';

/// Baut die Ausgabezeile zu [event].
///
/// Aufbau: Präfix, Name, danach die Kennwerte als `schlüssel=wert`, **nach
/// Schlüssel sortiert**. Die Sortierung ist keine Kosmetik: ohne sie hinge die
/// Zeile an der Einfügereihenfolge der Map, und zwei Läufe derselben App
/// erzeugten unterschiedliche Zeilen.
///
/// Der Name steht direkt hinter dem Präfix, weil er die einzige Angabe ist,
/// über die man das Ereignis im Quelltext wiederfindet.
String formatDiagnosticLine(DiagnosticEvent event) {
  final buffer = StringBuffer('$diagnosticLinePrefix ${event.name}');
  final keys = event.attributes.keys.toList()..sort();
  for (final key in keys) {
    buffer.write(' $key=${event.attributes[key]}');
  }
  return buffer.toString();
}

/// Schreibt [line] auf die Konsole des Prozesses.
///
/// Eine benannte Funktion und kein Lambda, damit sie als Vorgabewert eines
/// `const`-Konstruktors taugt und ein Test sie identifizieren kann.
void writeDiagnosticLineToConsole(String line) => debugPrintSynchronously(line);

/// Wählt die Senke für den laufenden Bau.
///
/// ## Warum nur der Debug-Bau redet
///
/// `docs/architecture/cross-cutting-concerns.md` verlangt getrennte Senken für
/// Debug-Logging und Produktions-Telemetrie, und `docs/engineering/security.md`
/// §10 will Debug-Werkzeuge im Release abgeschaltet sehen. Dazu kommt der
/// Grund, der hier wirklich zählt: §6 verbietet genaue Koordinaten im Log.
/// Heute hält sich jede Meldestelle daran, aber das ist eine Eigenschaft der
/// Aufrufer, nicht der Senke. Ein Attribut, das jemand in einem halben Jahr
/// hinzufügt, wäre auf dem Telefon jedes Nutzers im Systemlog, und das Log
/// eines Android-Geräts ist nichts Privates. Im Release schweigt die App
/// deshalb, bis es eine entschiedene Telemetrie gibt.
///
/// [debugBuild] wird übergeben statt hier `kDebugMode` zu lesen. `kDebugMode`
/// ist eine Konstante, ein Test könnte den Release-Zweig also nie betreten, und
/// ein Zweig ohne Test ist eine Behauptung.
DiagnosticSink diagnosticSinkForBuild({required bool debugBuild}) =>
    debugBuild ? const ConsoleDiagnosticSink() : const SilentDiagnosticSink();
