import 'dart:async';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/presentation/map_overlay_host.dart';
import 'package:fact_app/services/diagnostics/console_diagnostic_sink.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Zweck dieser Senke ist eine einzige Zeile auf dem Gerät, und deshalb
/// prüft hier fast alles den **Wortlaut** dieser Zeile. Ein Test, der nur
/// feststellt, dass irgendetwas geschrieben wurde, würde eine Senke durchlassen,
/// die den Namen des Ereignisses verschluckt, und genau der Name ist der Grund,
/// warum es sie gibt.
void main() {
  group('ConsoleDiagnosticSink', () {
    test('schreibt Präfix, Namen und Nutzlast in eine Zeile', () {
      final lines = <String>[];
      final sink = ConsoleDiagnosticSink(write: lines.add);

      sink.report(
        DiagnosticEvent(MapOverlayHost.unknownStyleEvent, <String, String>{
          'overlay': 'facts',
          'styles': 'balloon-unbekannt',
        }),
      );

      expect(lines, hasLength(1));
      expect(
        lines.single,
        'FACT-DIAG map.overlay.unknown_style '
        'overlay=facts styles=balloon-unbekannt',
      );
    });

    test('nennt den Namen auch ohne jedes Kennwert', () {
      // Die Gegenprobe zum Format: ohne Kennwerte darf weder ein leeres
      // Klammerpaar noch ein Leerzeichen am Ende stehen, sonst greift ein
      // späterer Filter daneben.
      final lines = <String>[];

      ConsoleDiagnosticSink(write: lines.add).report(DiagnosticEvent('a.b.c'));

      expect(lines, <String>['FACT-DIAG a.b.c']);
    });

    test('sortiert die Kennwerte nach Schlüssel', () {
      // Ohne Sortierung hinge die Zeile an der Einfügereihenfolge der Map, und
      // zwei Läufe derselben App erzeugten unterschiedliche Zeilen. Die
      // Einfügereihenfolge hier ist absichtlich die umgekehrte.
      final lines = <String>[];

      ConsoleDiagnosticSink(write: lines.add).report(
        DiagnosticEvent(MapHostRegistry.missingHostEvent, <String, String>{
          'rank': '3',
          'origin': 'gpsFollow',
          'access': 'submitIntent',
        }),
      );

      expect(lines, <String>[
        'FACT-DIAG map.host.missing access=submitIntent origin=gpsFollow rank=3',
      ]);
    });

    test('meldet jedes Ereignis, auch dasselbe zweimal', () {
      // Kein Entprellen und kein Zusammenfassen: eine Senke, deren Zweck das
      // Finden eines Fehlers ist, darf nicht selbst entscheiden, welche
      // Wiederholung uninteressant ist.
      final lines = <String>[];
      final sink = ConsoleDiagnosticSink(write: lines.add);
      final event = DiagnosticEvent('a.b.c', const <String, String>{'k': 'v'});

      sink
        ..report(event)
        ..report(event);

      expect(lines, hasLength(2));
    });

    test('der Standardkanal schreibt wirklich auf die Konsole', () {
      // Der Test, der die eigentliche Zusicherung trägt. Alle anderen hier
      // spritzen einen Kanal ein und würden auch dann grün bleiben, wenn der
      // Standardkanal nichts täte. `debugPrintSynchronously` ruft intern
      // `print`, und `print` geht durch `Zone.current.print`; genau dort hängt
      // sich diese Zone ein.
      final lines = <String?>[];

      runZoned(
        () => const ConsoleDiagnosticSink().report(
          DiagnosticEvent('map.host.intent_dropped', const <String, String>{
            'cause': 'no_surface',
          }),
        ),
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) =>
              lines.add(line),
        ),
      );

      expect(lines, <String>[
        'FACT-DIAG map.host.intent_dropped cause=no_surface',
      ]);
    });

    test('eine werfende Ausgabe reißt den Aufrufer nicht mit', () {
      // `core/diagnostics/diagnostic_sink.dart` verlangt wörtlich, dass
      // `report` nie wirft. Die Meldestelle ist regelmäßig ein Zweig, in dem
      // schon etwas schiefging; sie dort ein zweites Mal scheitern zu lassen
      // wäre der schlechteste denkbare Zeitpunkt.
      final sink = ConsoleDiagnosticSink(
        write: (String line) => throw StateError('Kanal kaputt'),
      );

      expect(() => sink.report(DiagnosticEvent('a.b.c')), returnsNormally);
    });
  });

  group('diagnosticSinkForBuild', () {
    test('im Debug-Bau redet die Senke', () {
      expect(
        diagnosticSinkForBuild(debugBuild: true),
        isA<ConsoleDiagnosticSink>(),
      );
    });

    test('im Release-Bau schweigt sie', () {
      // Der Grund steht bei der Funktion: `security.md` §6 verbietet genaue
      // Koordinaten im Log, und ob eine Meldestelle sich daran hält, ist eine
      // Eigenschaft der Aufrufer und nicht der Senke.
      //
      // `same` und nicht `isA`: `SilentDiagnosticSink` ist eine Konstante, Dart
      // kanonisiert sie, und damit ist die Identität hier die schärfere
      // Zusicherung.
      expect(
        diagnosticSinkForBuild(debugBuild: false),
        same(const SilentDiagnosticSink()),
      );
    });

    test('die schweigende Wahl schreibt auch nichts', () {
      // Die Zusicherung hinter der Typprüfung oben. Ohne sie wäre "im Release
      // schweigt sie" eine Aussage über einen Klassennamen.
      final lines = <String?>[];

      runZoned(
        () => diagnosticSinkForBuild(
          debugBuild: false,
        ).report(DiagnosticEvent('a.b.c', const <String, String>{'k': 'v'})),
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) =>
              lines.add(line),
        ),
      );

      expect(lines, isEmpty);
    });
  });

  group('formatDiagnosticLine', () {
    test('beginnt mit dem Präfix, an dem im Logcat gefiltert wird', () {
      // Das Präfix ist Vertragsfläche gegenüber einem Menschen mit `adb logcat`
      // und keine Kosmetik. Wer es ändert, macht jede Anleitung falsch, die es
      // nennt.
      expect(diagnosticLinePrefix, 'FACT-DIAG');
      expect(
        formatDiagnosticLine(DiagnosticEvent('a.b.c')),
        startsWith('$diagnosticLinePrefix '),
      );
    });
  });
}
