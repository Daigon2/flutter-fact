// Prüft tool/generate_i18n.dart über eine eigene, winzige Ersatz-PWA in
// temporären Verzeichnissen, nach dem Vorbild von
// `generate_curated_data_test.dart`.
//
// **Warum keine echte PWA.** `HANDOFF.md` verlangt ausdrücklich, dass
// `flutter test` auch ohne Zugang zum Lese-Repository durchläuft. Ein Test,
// der die echte `translations.jsx` bräuchte, würde genau das verletzen. Die
// Ersatzdateien hier sind frei erfunden und haben keine Verbindung zu echten
// PWA-Inhalten.
//
// **Zwei temporäre Verzeichnisse.** `pwa` steht für `02_Frontend/app/` und
// wird über `--source` eingesetzt. `project` steht für die Projektwurzel: das
// Werkzeug schreibt die erzeugten Dateien relativ zum Arbeitsverzeichnis
// (`lib/app/localization/generated/`) und liest die handgepflegte Ergänzung
// ebenso relativ (`lib/app/localization/app_strings_supplement.dart`,
// `_supplementFile` im Werkzeug). Der Prozess läuft deshalb mit
// `workingDirectory: project.path`, und `setUp` legt dort eine eigene,
// winzige Ergänzungsdatei an. Das ist sauber, weil `_readSupplementKeys` die
// Datei nur als Text mit Mustern liest, nicht als Dart kompiliert: der Inhalt
// muss aussehen wie die echte Datei (`AppLanguage.<code>: <String, String>{`
// als Kartenkopf, `'schluessel': 'wert',` als Zeile), aber nicht wirklich
// gültiges Dart sein.
//
// **Die Liste bekannter Lücken bleibt echt.** `_knownMissingSourceKeys` im
// Werkzeug ist eine feste Konstante mit den beiden echten Einträgen
// `audio.dialog.volumeHint` (E-28) und `group.join.title` (E-63) und wird von
// hier aus nicht parametrisiert. Jeder Testfall, der ohne Fund durchlaufen
// soll, braucht deshalb einen Aufruf für **beide** Schlüssel irgendwo im
// JSX, sonst meldet das Werkzeug die Liste selbst als veraltet. `setUp`
// schreibt dafür `known-gaps.jsx` mit genau diesen zwei Aufrufen; einzelne
// Tests lassen die Datei unverändert, außer der Test, der die
// Veraltungs-Meldung selbst prüft.
//
// **Was diese Datei nicht abdeckt:** `_checkParity` (Paritäts- und
// Platzhalterprüfung über mehrere Sprachen, hier läuft nur `de`),
// `_checkSupplement`s eigene Veraltungsmeldung (die Ergänzung wird hier nur
// als Randbedingung für die neue Prüfung gebraucht), das genaue
// Render-Format der erzeugten Dateien (`_renderLanguageFile`,
// `_renderIndexFile`), Sonderzeichen- und UTF-8-Behandlung beim Schreiben,
// und Fehlerpfade von `_readConfig` (fehlende oder kaputte
// `i18n-config.jsx`). Diese Aspekte hatte das Werkzeug schon vor dieser
// Datei ungetestet; sie zu schließen ist eine andere Aufgabe.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory pwa;
  late Directory project;

  const configSource = '''
window.I18N = {
  active: ['de'],
  default: 'de',
  fallback: 'de',
};
''';

  const defaultTranslations = '''
window.I18n = {
  strings: {
    de: {
      'vorhanden.schluessel': 'Wert',
    },
  },
};
''';

  const audioSource = '''
(function() {
  const audioDe = {};
})();
''';

  const supplementSource = '''
const Map<AppLanguage, Map<String, String>> supplementTextsByLanguage =
    <AppLanguage, Map<String, String>>{
  AppLanguage.de: <String, String>{
    'ergaenzung.schluessel': 'Wert',
  },
};
''';

  // Hält die beiden echten Einträge aus `_knownMissingSourceKeys` frisch,
  // siehe Kopfkommentar. Ohne diese Datei würde jeder sonst stille Testfall
  // an der Veraltungsprüfung scheitern.
  const knownGapsSource = '''
function irrelevant(lang) {
  t('audio.dialog.volumeHint', lang);
  t('group.join.title', lang);
}
''';

  void writeSource(String name, String content) {
    File(
      '${pwa.path}${Platform.pathSeparator}$name',
    ).writeAsStringSync(content);
  }

  void writeTranslations(String content) =>
      writeSource('translations.jsx', content);

  setUp(() {
    pwa = Directory.systemTemp.createTempSync('fact_i18n_pwa');
    project = Directory.systemTemp.createTempSync('fact_i18n_project');

    writeSource('i18n-config.jsx', configSource);
    writeTranslations(defaultTranslations);
    writeSource('audio-strings.jsx', audioSource);
    writeSource('known-gaps.jsx', knownGapsSource);

    final supplementFile = File(
      '${project.path}/lib/app/localization/app_strings_supplement.dart',
    );
    supplementFile.parent.createSync(recursive: true);
    supplementFile.writeAsStringSync(supplementSource);
  });

  tearDown(() {
    if (pwa.existsSync()) {
      pwa.deleteSync(recursive: true);
    }
    if (project.existsSync()) {
      project.deleteSync(recursive: true);
    }
  });

  _Run run(List<String> args) =>
      _runTool(project, <String>[...args, '--source', pwa.path]);

  group('Quellnutzung: fehlende, vorhandene und ergänzte Schlüssel', () {
    test('ein Aufruf ohne Eintrag bricht mit Exit-Code 1 ab und nennt Datei '
        'und Schlüssel', () {
      writeSource('screen-test.jsx', "const x = t('fehlt.komplett', lang);\n");

      final result = run(<String>[]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('screen-test.jsx'));
      expect(result.stderr, contains('fehlt.komplett'));
    });

    test('derselbe Schlüssel im Wörterbuch bleibt still', () {
      writeSource(
        'screen-test.jsx',
        "const x = t('vorhanden.schluessel', lang);\n",
      );

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
    });

    test('derselbe Schlüssel in der Ergänzung bleibt still', () {
      writeSource(
        'screen-test.jsx',
        "const x = t('ergaenzung.schluessel', lang);\n",
      );

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
    });
  });

  group('Quellnutzung: Kommentare zählen nicht', () {
    test('ein Schlüssel nur in einem Zeilenkommentar bleibt still', () {
      writeSource(
        'screen-test.jsx',
        "// t('nur.kommentar', lang) fällt weg, weil er nie aufgerufen wird\n",
      );

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
    });

    test(
      'Gegenprobe: derselbe Schlüssel außerhalb des Kommentars macht rot',
      () {
        writeSource('screen-test.jsx', "const x = t('nur.kommentar', lang);\n");

        final result = run(<String>[]);
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('nur.kommentar'));
      },
    );

    test('ein Schlüssel nur in einem Blockkommentar bleibt still', () {
      writeSource(
        'screen-test.jsx',
        "/* t('block.kommentar', lang) fällt weg */\n",
      );

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
    });

    test('Gegenprobe: derselbe Schlüssel außerhalb des Blockkommentars macht '
        'rot', () {
      writeSource('screen-test.jsx', "const x = t('block.kommentar', lang);\n");

      final result = run(<String>[]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('block.kommentar'));
    });
  });

  group('Quellnutzung: ein Apostroph im JSX-Text kaskadiert nicht', () {
    // Am 02.09.2026 von einer unabhängigen Prüfung gefunden und hier
    // festgenagelt. Der Kommentar-Entferner hielt eine mit `'` begonnene
    // Zeichenkette über Zeilen offen. Ein Minutenzeichen (`{min}'`) oder ein
    // typografisches Anführungszeichen im JSX-Text verschob damit seine
    // Parität, und ein `//` in einer echten Zeichenkette galt danach als
    // Zeilenkommentar. Der Aufruf dahinter fiel **still** weg, und still ist
    // genau der Fehler, gegen den diese Prüfung gebaut ist.

    test('ein Minutenzeichen im Text verschluckt den Aufruf der nächsten '
        'Zeile nicht', () {
      writeSource(
        'screen-test.jsx',
        "function A() { return <div>{min}'</div>; }\n"
            "const url = 'https://example.com/x'; "
            "const b = t('fehlt.hier', lang);\n",
      );

      final result = run(<String>[]);

      // Die zweite Zeile trägt beides: eine echte Zeichenkette mit `//`
      // darin, die **nicht** als Kommentar zählen darf, und den Aufruf
      // dahinter, der gefunden werden muss.
      expect(result.exitCode, isNot(0), reason: result.stdout.toString());
      expect(result.stderr, contains('fehlt.hier'));
    });

    test('eine echte Zeichenkette mit // darin bleibt geschützt', () {
      // Die Gegenrichtung, ohne die der Test auch mit einem Entferner grün
      // wäre, der Zeichenketten gar nicht mehr kennt: dann würde `//` in der
      // URL wieder als Kommentar gelten und den Aufruf kappen.
      writeSource(
        'screen-test.jsx',
        "const url = 'https://example.com/x'; "
            "const b = t('fehlt.zwei', lang);\n",
      );

      final result = run(<String>[]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('fehlt.zwei'));
    });

    test('ein Template-Literal darf weiterhin über Zeilen gehen', () {
      // Das Zurücksetzen gilt nur für `'` und `"`, ein Backtick-Literal ist
      // mehrzeilig erlaubt. **Diese Fassung ist die zweite:** die erste legte
      // den Aufruf hinter das Literal, und dort fand ihn auch ein Scanner, der
      // beim Backtick genauso zurücksetzt. Sie prüfte also nichts, und eine
      // Mutation hat das belegt, statt dass es jemand geahnt hätte.
      //
      // Scharf wird es nur mit einem `//` **im** Literal: bleibt der Zustand
      // über die Zeile stehen, ist das Text und der Aufruf darin überlebt das
      // Entfernen. Setzt er zurück, beginnt Zeile zwei ausserhalb einer
      // Zeichenkette, `//` gilt als Kommentar, und der Aufruf fällt weg.
      writeSource(
        'screen-test.jsx',
        'const s = `Zeile eins\n'
            "  // t('im.literal', lang)\n"
            '  Zeile drei`;\n',
      );

      final result = run(<String>[]);
      expect(result.exitCode, isNot(0), reason: result.stdout.toString());
      expect(result.stderr, contains('im.literal'));
    });
  });

  group('Quellnutzung: zusammengesetzte Aufrufe und Schlüssel ohne Punkt', () {
    test('ein zusammengesetzter Aufruf mit Pluszeichen bleibt still', () {
      writeSource(
        'screen-test.jsx',
        "const x = t('praefix.' + suffix, lang);\n",
      );

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
    });

    test('Gegenprobe: derselbe Präfix als vollständiger Schlüssel ohne Eintrag '
        'macht rot', () {
      writeSource('screen-test.jsx', "const x = t('praefix.fest', lang);\n");

      final result = run(<String>[]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('praefix.fest'));
    });

    test('ein Schlüssel ohne Punkt bleibt still', () {
      writeSource('screen-test.jsx', "const x = t('ohnepunkt', lang);\n");

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
    });
  });

  group('Quellnutzung: Sicherungsdateien zählen nicht', () {
    test('eine Sicherungsdatei mit `.original.` im Namen bleibt still', () {
      writeSource(
        'irgendwas.original.jsx',
        "const x = t('fehlt.in.sicherung', lang);\n",
      );

      final result = run(<String>[]);
      expect(result.exitCode, 0, reason: result.stderr);
    });

    test('Gegenprobe: dieselbe Datei ohne `.original.` im Namen macht rot', () {
      writeSource(
        'irgendwas.jsx',
        "const x = t('fehlt.in.sicherung', lang);\n",
      );

      final result = run(<String>[]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('fehlt.in.sicherung'));
    });
  });

  test('alle drei Aufrufformen werden erkannt', () {
    writeSource(
      'screen-test.jsx',
      "const a = t('form.plain', lang);\n"
          "const b = window.t('form.window', lang);\n"
          "const c = window.t?.('form.windowopt', lang);\n",
    );

    final result = run(<String>[]);
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('form.plain'));
    expect(result.stderr, contains('form.window'));
    expect(result.stderr, contains('form.windowopt'));
  });

  test(
    'ein veralteter Eintrag in der Liste bekannter Lücken wird gemeldet',
    () {
      // group.join.title (E-63) steht jetzt im Wörterbuch: der Eintrag in
      // `_knownMissingSourceKeys` ist damit tot, obwohl `known-gaps.jsx`
      // (aus setUp) den Schlüssel weiterhin aufruft.
      writeTranslations('''
window.I18n = {
  strings: {
    de: {
      'vorhanden.schluessel': 'Wert',
      'group.join.title': 'Session-Code eingeben',
    },
  },
};
''');

      final result = run(<String>[]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('group.join.title'));
      expect(result.stderr, contains('veraltet'));
    },
  );

  group('Bestehendes Verhalten, unverändert durch die neue Prüfung', () {
    test(
      '--check wird rot, wenn erzeugte Dateien von der Quelle abweichen',
      () {
        writeSource(
          'screen-test.jsx',
          "const x = t('vorhanden.schluessel', lang);\n",
        );

        final generate = run(<String>[]);
        expect(
          generate.exitCode,
          0,
          reason: 'stdout: ${generate.stdout}\nstderr: ${generate.stderr}',
        );

        // Ein zweiter Schlüssel kommt in die Quelle, ohne dass die erzeugten
        // Dateien neu geschrieben werden.
        writeTranslations('''
window.I18n = {
  strings: {
    de: {
      'vorhanden.schluessel': 'Wert',
      'zusatz.schluessel': 'Zusatz',
    },
  },
};
''');

        final check = run(<String>['--check']);
        expect(check.exitCode, isNot(0));
        expect(check.stderr, contains('weichen von der Quelle ab'));
      },
    );

    test('ein fehlendes Quellverzeichnis bricht mit Exit-Code 2 und einer '
        'Anleitung ab', () {
      final result = _runTool(project, <String>[
        '--source',
        '${pwa.path}${Platform.pathSeparator}nicht-vorhanden',
      ]);

      expect(result.exitCode, 2);
      expect(result.stderr, contains('nicht gefunden'));
      expect(result.stderr, contains('--source'));
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
    <String>['${Directory.current.path}/tool/generate_i18n.dart', ...args],
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
/// Vorgehen wie in `generate_curated_data_test.dart`.
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
