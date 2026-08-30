// Prüft tool/generate_curated_data.dart über eine eigene, winzige
// Ersatz-PWA in einem temporären Verzeichnis, nach dem Vorbild von
// `bake_map_style_test.dart`.
//
// **Warum keine echte PWA.** `HANDOFF.md` verlangt ausdrücklich, dass
// `flutter test` auch ohne Zugang zum Lese-Repository durchläuft: „Ohne
// Zugang dorthin bricht es mit einer Anleitung ab, und `flutter test` läuft
// trotzdem durch." Ein Test, der die echte `hunt-hotspots.js` braucht, würde
// genau das verletzen. Die Ersatzdatei hier ist frei erfunden und hat keine
// Verbindung zur echten Datenpflege.
//
// Diese Datei fehlte bis zur Review von Schritt 35 ganz: anders als
// `tool/bake_map_style.dart`, für das `bake_map_style_test.dart` ausdrücklich
// prüft, dass `--check` rot wird, hatte dieses Werkzeug keine eigene
// Testdatei.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory pwa;
  late Directory project;

  setUp(() {
    pwa = Directory.systemTemp.createTempSync('fact_curated_pwa');
    project = Directory.systemTemp.createTempSync('fact_curated_project');
  });

  tearDown(() {
    if (pwa.existsSync()) {
      pwa.deleteSync(recursive: true);
    }
    if (project.existsSync()) {
      project.deleteSync(recursive: true);
    }
  });

  void writeHotspots(String content) {
    File(
      '${pwa.path}${Platform.pathSeparator}hunt-hotspots.js',
    ).writeAsStringSync(content);
  }

  const outputRelativePath =
      'lib/features/challenges/application/generated/hunt_hotspots.g.dart';

  File output() => File('${project.path}/$outputRelativePath');

  _Run run(List<String> args) =>
      _runTool(project, <String>[...args, '--source', pwa.path]);

  const validSource = '''
window.HUNT_HOTSPOTS = {
  "Teststadt": [
    { name: "Marktplatz", lat: 48.1, lng: 11.5, density: "hoch" }
  ]
};
''';

  test('erzeugt die Datei, und --check ist danach grün', () {
    writeHotspots(validSource);

    final generate = run(<String>[]);
    expect(
      generate.exitCode,
      0,
      reason: 'stdout: ${generate.stdout}\nstderr: ${generate.stderr}',
    );
    expect(output().existsSync(), isTrue);
    expect(output().readAsStringSync(), contains('Teststadt'));

    final check = run(<String>['--check']);
    expect(
      check.exitCode,
      0,
      reason: 'stdout: ${check.stdout}\nstderr: ${check.stderr}',
    );
  });

  test('--check ist rot, sobald sich die Quelle geändert hat', () {
    writeHotspots(validSource);
    expect(run(<String>[]).exitCode, 0);

    // Ein zweiter Hotspot kommt dazu: die eingecheckte Datei stimmt jetzt
    // nicht mehr mit der (neuen) Quelle überein.
    writeHotspots('''
window.HUNT_HOTSPOTS = {
  "Teststadt": [
    { name: "Marktplatz", lat: 48.1, lng: 11.5, density: "hoch" },
    { name: "Zweiter Platz", lat: 48.2, lng: 11.6, density: "mittel" }
  ]
};
''');

    final check = run(<String>['--check']);
    expect(check.exitCode, isNot(0));
    expect(check.stderr, contains('weichen von der Quelle ab'));
    expect(check.stderr, contains(outputRelativePath));
  });

  group('Drei Funde der Review von Schritt 35', () {
    test(
      'ein doppelter Stadtschlüssel bricht ab, statt still zu überschreiben',
      () {
        // Ohne die Prüfung verschwände „Teststadt" mit dem Wert „A" lautlos,
        // und die erzeugte Tabelle hätte einen Hotspot weniger, als in der
        // Quelle wirklich steht.
        writeHotspots('''
window.HUNT_HOTSPOTS = {
  "Teststadt": [{ name: "A", lat: 1, lng: 1, density: "hoch" }],
  "Teststadt": [{ name: "B", lat: 2, lng: 2, density: "hoch" }]
};
''');

        final result = run(<String>[]);
        expect(result.exitCode, 1);
        expect(result.stderr, contains('Doppelter Schlüssel'));
        expect(output().existsSync(), isFalse);
      },
    );

    test('liest nicht aus einem Kommentar oberhalb der echten Zuweisung', () {
      // Genau der Fund der Review: eine Kommentarzeile, die zufällig
      // denselben Zuweisungstext trägt wie der echte Code darunter. Ohne
      // die Behebung fände `indexOf` die erste, harmlose Stelle, läse dort
      // ein leeres Objekt und meldete „0 Hotspots" statt abzubrechen oder
      // die echte Zuweisung zu lesen.
      writeHotspots('''
// Alte Fassung: window.HUNT_HOTSPOTS = {};
window.HUNT_HOTSPOTS = {
  "Teststadt": [{ name: "A", lat: 1, lng: 1, density: "hoch" }]
};
''');

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('1 Städte, 1 Hotspots'));
      expect(output().readAsStringSync(), contains("'A'"));
    });

    test('ein \\r im Namen wird escaped, statt eine kaputte Datei zu '
        'hinterlassen', () {
      // Vorher fehlte `\r` in `_dartString`; ein rohes `\r` in der Quelle
      // ergab ein Dart-Literal, das über eine Zeile hinausreicht, `dart
      // format` scheiterte, und weil `_writeFiles` vorher lief, stand die
      // kaputte Datei schon im Projekt, obwohl das Werkzeug abbrach.
      writeHotspots(
        'window.HUNT_HOTSPOTS = {\n'
        '  "Teststadt": [\n'
        '    { name: "Zeile eins\rZeile zwei", lat: 1, lng: 1, '
        'density: "hoch" }\n'
        '  ]\n'
        '};\n',
      );

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
      expect(output().readAsStringSync(), contains(r'Zeile eins\rZeile'));
    });
  });
}

class _Run {
  const _Run(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}

_Run _runTool(Directory project, List<String> args) {
  final result = Process.runSync(
    _dartPath(),
    <String>[
      '${Directory.current.path}/tool/generate_curated_data.dart',
      ...args,
    ],
    workingDirectory: project.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return _Run(
    result.exitCode,
    result.stdout as String,
    result.stderr as String,
  );
}

/// Findet die Dart-Kommandozeile. Unter `flutter test` ist
/// `Platform.resolvedExecutable` der flutter_tester, nicht Dart. Dasselbe
/// Vorgehen wie in `bake_map_style_test.dart` und `check_architecture_test.dart`.
String _dartPath() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final suffix = Platform.isWindows ? '.exe' : '';
    final candidate = File('$root/bin/cache/dart-sdk/bin/dart$suffix');
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }
  if (Platform.resolvedExecutable.contains('dart-sdk')) {
    return Platform.resolvedExecutable;
  }
  return Platform.isWindows ? 'dart.exe' : 'dart';
}
