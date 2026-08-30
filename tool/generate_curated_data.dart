// Erzeugt Dart-Konstanten aus den **kuratierten Datendateien** der PWA.
//
// Aufruf:
//   dart run tool/generate_curated_data.dart
//   dart run tool/generate_curated_data.dart --source "<Pfad zu 02_Frontend/app>"
//   dart run tool/generate_curated_data.dart --check
//
// `--check` schreibt nichts und endet mit Exit-Code 1, sobald eine erzeugte
// Datei im Repository von der Quelle abweicht. Ohne Zugang zum Lese-Repository
// endet das Skript mit Exit-Code 2 und einer Anleitung, genau wie
// `tool/generate_i18n.dart`.
//
// ── Was eine kuratierte Datendatei ist ──────────────────────────────────────
//
// Die PWA hat neben den Faktdaten eine Handvoll Dateien, die redaktionell
// gepflegt sind und **kein** Gegenstück in Supabase haben. Sie sind zu klein
// für eine Tabelle, zu gross für einen Literalblock im Widget, und der Neubau
// braucht sie alle:
//
//   hunt-hotspots.js    45 Zeilen   Startpunkt-Picker, Schritt 35
//   damals-heute.jsx   112 Zeilen   Schritt 24
//   wallet-colors.jsx  155 Zeilen   Schritte 45, 46, 49
//   hunt-routes.jsx    229 Zeilen   Tourplaner, und Schritt 34 hat sie deshalb
//                                   ausgelassen
//   city-intros.jsx    747 Zeilen   Stadt-Intros
//
// Dieses Skript ist der Weg für alle. Heute steht **eine** Quelle in
// [_curatedSources]; die zweite kostet einen Eintrag dort plus eine
// Render-Funktion, keinen zweiten Aufruf im Gate-Block und kein zweites
// Werkzeug. Das ist der Grund für die Registrierung: fünf Werkzeuge mit fünf
// `--check`-Aufrufen vergisst nach dem dritten Mal jemand.
//
// ── Wo die erzeugten Daten liegen, und warum dort ───────────────────────────
//
// In der `application/`-Schicht des Features, dem die Daten gehören, unter
// `generated/`. Drei Regeln lassen keinen anderen Ort zu:
//
//   * Regel 17: `presentation` darf kein `data`-Verzeichnis lesen, auch nicht
//     das eigene. Eine kuratierte Datei unter `features/x/data/` wäre für den
//     Bildschirm unerreichbar, der sie braucht.
//   * Regel 11: unterhalb von `core/` darf kein Geschäftsbegriff stehen. Ein
//     gemeinsames `lib/core/curated/` ist damit maschinell verboten, sobald es
//     Hotspots, Routen oder Wallet-Farben trägt.
//   * Regel 10: über die Feature-Grenze geht nur ein öffentlicher Domänen-
//     oder Application-Vertrag. `hunt-routes.jsx` braucht später `tours`, und
//     `application/` ist der Ort, an dem das legal ist. `domain/` wäre es
//     nicht: Gate 6 lässt eine Feature-Domäne nur das Dart-SDK und die eigene
//     Domäne importieren, und `MapPosition` fällt schon darunter.
//
// Vorbild ist `lib/app/localization/generated/`: erzeugte Dateien sind
// **eingecheckt**, damit `flutter test` ohne Zugang zum Lese-Repository läuft.
// Das Werkzeug ist nur nötig, wenn sich die PWA ändert.
//
// ── Wie Drift bemerkt wird ─────────────────────────────────────────────────
//
// Durch `--check` gegen die **PWA selbst**, nicht gegen eine Kopie unter
// `tool/`. Das ist der Unterschied zu `tool/bake_map_style.dart`, und er hat
// einen Grund: dessen Ausgangsstil kommt aus dem **Netz**, und ein Werkzeug,
// das lädt, erzeugt still bei jedem Lauf etwas anderes. Die PWA liegt lokal
// und ist versioniert; eine zweite Kopie hier würde genau die Änderung
// verstecken, die zu sehen wäre.
//
// Das ist bei `hunt-hotspots.js` keine graue Theorie. Ihr eigener Kopf sagt:
// „MANUAL fallback — wird später von `04_Datenpipeline/scripts/
// compute_hotspots.py` automatisch generiert/überschrieben." Wenn dieses
// Skript dort einmal läuft, soll `--check` es melden und nicht eine Kopie im
// Neubau die alten Zahlen konservieren.
//
// ── Was das Werkzeug ausdrücklich nicht entscheidet ────────────────────────
//
// **Die Stadt-Identität (E-11).** Die Datendateien der PWA sind nicht
// einheitlich verschlüsselt: `hunt-hotspots.js` und `hunt-routes.jsx` benutzen
// den deutschen Anzeigenamen (`"München"`), `wallet-colors.jsx` benutzt
// Kleinschreibung mit Umlauten (`münchen`, Kommentar dort: „keys = lowercase,
// mit Umlauten, wie `detectCity()` sie liefert"), und `facts.city` in der
// Datenbank trägt eine dritte Schreibweise. Drei Formen derselben Stadt.
//
// Dieses Skript schreibt den Schlüssel deshalb **wörtlich ab** und normalisiert
// nichts. Wer normalisiert, entscheidet E-11 im Werkzeug, wo es niemand sucht.
// Die Normalisierung passiert an genau einer Stelle in Dart, siehe
// `lib/features/challenges/application/hunt_hotspot.dart`.

import 'dart:io';

/// Standardpfad des PWA-Verzeichnisses, siehe CLAUDE.md, Abschnitt
/// "Reference repository (read-only)". Nur Lesezugriff.
const _defaultSourceDir =
    r'C:\Users\Janek Postpischil\OneDrive\DokumenteClaudeSortierung\Documents'
    r'\01_Persönliches\12_Claude\Claude Code\Fact\02_Frontend\app';

/// Eine kuratierte Datendatei und das, was aus ihr wird.
class _CuratedSource {
  const _CuratedSource({
    required this.sourceFile,
    required this.outputPath,
    required this.render,
  });

  /// Dateiname in `02_Frontend/app/`.
  final String sourceFile;

  /// Zieldatei, relativ zur Projektwurzel.
  final String outputPath;

  /// Baut den Dart-Quelltext aus dem Inhalt der Quelldatei.
  final String Function(String source, _Report report) render;
}

/// Alle kuratierten Quellen. Eine neue kostet einen Eintrag und eine
/// Render-Funktion.
const _curatedSources = <_CuratedSource>[
  _CuratedSource(
    sourceFile: 'hunt-hotspots.js',
    outputPath:
        'lib/features/challenges/application/generated/hunt_hotspots.g.dart',
    render: _renderHuntHotspots,
  ),
];

void main(List<String> args) {
  final options = _Options.parse(args);
  if (options == null) {
    exit(2);
  }

  final sourceDir = Directory(options.sourceDir);
  if (!sourceDir.existsSync()) {
    stderr
      ..writeln('PWA-Quelle nicht gefunden: ${options.sourceDir}')
      ..writeln(
        'Pfad über --source oder FACT_PWA_APP_DIR setzen. '
        'Das Lese-Repository liegt außerhalb dieses Projekts.',
      );
    exit(2);
  }

  final report = _Report();
  final files = <String, String>{};
  for (final source in _curatedSources) {
    final file = File(
      '${sourceDir.path}${Platform.pathSeparator}${source.sourceFile}',
    );
    if (!file.existsSync()) {
      stderr.writeln('Quelldatei nicht gefunden: ${file.path}');
      exit(2);
    }
    files[source.outputPath] = source.render(file.readAsStringSync(), report);
  }

  if (options.checkOnly) {
    final drifted = _findDrift(files);
    report.print();
    if (drifted.isEmpty) {
      stdout.writeln(
        'Kuratierte Daten: ${files.length} Datei bzw. Dateien stimmen mit '
        'der Quelle.',
      );
      return;
    }
    stderr.writeln(
      'Kuratierte Daten: ${drifted.length} Datei bzw. Dateien weichen von '
      'der Quelle ab:',
    );
    for (final path in drifted) {
      stderr.writeln('  $path');
    }
    stderr.writeln('Erneut erzeugen: dart run tool/generate_curated_data.dart');
    exit(1);
  }

  _writeAndFormat(files);
  report.print();
  for (final path in files.keys) {
    stdout.writeln('geschrieben: $path');
  }
}

// ── Optionen ─────────────────────────────────────────────────────────────────

class _Options {
  const _Options({required this.sourceDir, required this.checkOnly});

  static _Options? parse(List<String> args) {
    var sourceDir =
        Platform.environment['FACT_PWA_APP_DIR'] ?? _defaultSourceDir;
    var checkOnly = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--check') {
        checkOnly = true;
      } else if (arg == '--source') {
        if (i + 1 >= args.length) {
          stderr.writeln('--source erwartet einen Pfad.');
          return null;
        }
        sourceDir = args[++i];
      } else if (arg.startsWith('--source=')) {
        sourceDir = arg.substring('--source='.length);
      } else {
        stderr.writeln('Unbekanntes Argument: $arg');
        return null;
      }
    }

    return _Options(sourceDir: sourceDir, checkOnly: checkOnly);
  }

  final String sourceDir;
  final bool checkOnly;
}

// ── Befunde ──────────────────────────────────────────────────────────────────

/// Sammelt alles, was an der Quelle auffällt. Wie bei `generate_i18n.dart`
/// repariert das Skript nichts still, es berichtet.
class _Report {
  final List<String> _notes = <String>[];

  void note(String message) => _notes.add(message);

  void print() {
    if (_notes.isEmpty) {
      stdout.writeln('Quellprüfung: keine Auffälligkeiten.');
      return;
    }
    stdout.writeln('Quellprüfung: ${_notes.length} Befund bzw. Befunde.');
    for (final note in _notes) {
      stdout.writeln('  - $note');
    }
  }
}

// ── hunt-hotspots.js ─────────────────────────────────────────────────────────

/// Baut `hunt_hotspots.g.dart` aus `window.HUNT_HOTSPOTS`.
///
/// Übernommen werden `name`, `lat`, `lng` und `density`, jedes wörtlich. Die
/// Abbildung von `density` auf eine Beschriftung passiert **nicht** hier: sie
/// steht in `hunt_start_options.dart` und ist dort mit Tests festgenagelt.
/// Ein Werkzeug, das sie vornähme, würde die einzige interessante Rechnung
/// dieser Datei in einen ungetesteten Zweig verschieben.
String _renderHuntHotspots(String source, _Report report) {
  final value = _JsLiteral.read(source, 'window.HUNT_HOTSPOTS');
  if (value is! Map<String, Object?>) {
    _fail('hunt-hotspots.js: `window.HUNT_HOTSPOTS` ist kein Objekt.');
  }

  final rows = StringBuffer();
  final densities = <String, int>{};
  var cities = 0;
  var hotspots = 0;

  for (final entry in value.entries) {
    final list = entry.value;
    if (list is! List<Object?>) {
      _fail('hunt-hotspots.js: "${entry.key}" trägt keine Liste.');
    }
    cities++;
    rows.writeln('  ${_dartString(entry.key)}: <HuntHotspotRecord>[');
    for (final raw in list) {
      if (raw is! Map<String, Object?>) {
        _fail('hunt-hotspots.js: "${entry.key}" enthält einen Nicht-Eintrag.');
      }
      final name = raw['name'];
      final lat = raw['lat'];
      final lng = raw['lng'];
      final density = raw['density'];
      if (name is! String || lat is! num || lng is! num || density is! String) {
        _fail(
          'hunt-hotspots.js: unvollständiger Eintrag in "${entry.key}": $raw',
        );
      }
      hotspots++;
      densities[density] = (densities[density] ?? 0) + 1;
      rows.writeln(
        '    (name: ${_dartString(name)}, '
        'latitude: ${_dartDouble(lat)}, '
        'longitude: ${_dartDouble(lng)}, '
        'density: ${_dartString(density)}),',
      );
    }
    rows.writeln('  ],');
  }

  report
    ..note('hunt-hotspots.js: $cities Städte, $hotspots Hotspots übernommen.')
    ..note(
      'hunt-hotspots.js: Dichtestufen '
      '${densities.entries.map((e) => '${e.key}=${e.value}').join(', ')}.',
    );

  return '''
${_fileHeaderComment('hunt-hotspots.js')}
/// Ein Hotspot, wörtlich wie in der Quelle.
///
/// `density` bleibt die rohe Zeichenkette (`sehr hoch`, `hoch`, `mittel`).
/// Ihre Abbildung auf eine Beschriftung steht in `hunt_start_options.dart`
/// und ist dort mit Tests festgenagelt.
typedef HuntHotspotRecord = ({
  String name,
  double latitude,
  double longitude,
  String density,
});

/// Die Hotspots je Stadt. Der Schlüssel ist **wörtlich der aus der Quelle**,
/// also der deutsche Anzeigename. Nicht normalisiert: das passiert an genau
/// einer Stelle in `hunt_hotspot.dart`, siehe E-11.
const Map<String, List<HuntHotspotRecord>> huntHotspotRecordsByCityName =
    <String, List<HuntHotspotRecord>>{
$rows};
''';
}

// ── Gemeinsames ──────────────────────────────────────────────────────────────

String _fileHeaderComment(String sourceFile) =>
    '''
// ERZEUGT von tool/generate_curated_data.dart aus
// 02_Frontend/app/$sourceFile. Nicht von Hand bearbeiten.
//
// Drift prüfen: dart run tool/generate_curated_data.dart --check
// Neu erzeugen: dart run tool/generate_curated_data.dart
''';

String _dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      // Ohne diese Zeile lässt ein rohes `\r` in der Quelle ein Dart-Literal
      // entstehen, das über eine Zeile hinausreicht: kein gültiges
      // einzeiliges Dart und ein Fall für `_formatFiles`, der erst nach
      // `_writeFiles` läuft, siehe dort.
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n')
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

/// Zahlen kommen als `double` heraus, damit `latitude` und `longitude` nicht
/// je nach Schreibweise in der Quelle einmal `int` und einmal `double` sind.
String _dartDouble(num value) {
  final text = value.toString();
  return text.contains('.') || text.contains('e') ? text : '$text.0';
}

void _writeFiles(Map<String, String> files) {
  for (final entry in files.entries) {
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }
}

/// Formatiert [files] in einer temporären Kopie und schreibt sie erst danach
/// an ihren echten Ort in `lib/`.
///
/// **Die Reihenfolge ist die Behebung, nicht nur eine Randnotiz.** Vorher
/// schrieb `_writeFiles` zuerst nach `lib/`, und `_formatFiles` lief erst
/// danach darüber. Scheiterte das Format, etwa weil `_dartString` ein
/// Steuerzeichen durchgelassen hat, stand die kaputte Datei bereits im
/// Arbeitsverzeichnis, obwohl das Werkzeug mit Exit-Code 1 abbrach. Jetzt
/// scheitert das Formatieren, solange nur die temporäre Kopie existiert, und
/// `lib/` bleibt unangetastet.
void _writeAndFormat(Map<String, String> files) {
  final temp = Directory.systemTemp.createTempSync('fact_curated_write');
  try {
    final tempFiles = <String, File>{};
    for (final entry in files.entries) {
      final name = entry.key.split('/').last;
      tempFiles[entry.key] = File('${temp.path}${Platform.pathSeparator}$name')
        ..writeAsStringSync(entry.value);
    }

    _formatFiles(tempFiles.values.map((file) => file.path).toList());

    _writeFiles(<String, String>{
      for (final entry in tempFiles.entries)
        entry.key: entry.value.readAsStringSync(),
    });
  } finally {
    temp.deleteSync(recursive: true);
  }
}

/// Lässt `dart format` über die erzeugten Dateien laufen, wie
/// `generate_i18n.dart`: das Gate formatiert auch erzeugten Code.
void _formatFiles(List<String> paths) {
  final result = Process.runSync(Platform.resolvedExecutable, [
    'format',
    ...paths,
  ]);
  if (result.exitCode != 0) {
    stderr
      ..writeln('dart format ist auf den erzeugten Dateien gescheitert:')
      ..writeln(result.stdout)
      ..writeln(result.stderr);
    exit(1);
  }
}

/// Vergleicht die Dateien im Repository mit dem, was die Quelle gerade ergibt.
///
/// Über eine formatierte Kopie im Temp-Verzeichnis, aus demselben Grund wie in
/// `generate_i18n.dart`: `dart format` ändert mehr als Leerraum.
List<String> _findDrift(Map<String, String> files) {
  final temp = Directory.systemTemp.createTempSync('fact_curated_check');
  try {
    final candidates = <String, File>{};
    for (final entry in files.entries) {
      final name = entry.key.split('/').last;
      final candidate = File('${temp.path}${Platform.pathSeparator}$name')
        ..writeAsStringSync(entry.value);
      candidates[entry.key] = candidate;
    }
    _formatFiles(candidates.values.map((f) => f.path).toList());

    final drifted = <String>[];
    for (final entry in candidates.entries) {
      final current = File(entry.key);
      if (!current.existsSync()) {
        drifted.add(entry.key);
        continue;
      }
      if (_lineEndings(current.readAsStringSync()) !=
          _lineEndings(entry.value.readAsStringSync())) {
        drifted.add(entry.key);
      }
    }
    return drifted;
  } finally {
    temp.deleteSync(recursive: true);
  }
}

/// `core.autocrlf` steht in diesem Repository auf `true`; verglichen wird auf
/// LF normalisiert.
String _lineEndings(String value) => value.replaceAll('\r\n', '\n');

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

// ── Ein winziger Leser für JS-Objektliterale ─────────────────────────────────
//
// Die kuratierten Dateien sind JSON-nah, aber kein JSON: Schlüssel stehen
// teils ohne Anführungszeichen, Zeichenketten teils in einfachen, es gibt
// Zeilen- und Blockkommentare und abschließende Kommata. `jsonDecode` scheitert
// an jedem dieser Punkte. Dieser Leser deckt genau das ab, was in
// `hunt-hotspots.js`, `hunt-routes.jsx`, `wallet-colors.jsx` und
// `damals-heute.jsx` vorkommt, und **wirft** bei allem anderen, statt zu raten.

/// Liest das Objektliteral hinter einer Zuweisung wie `window.HUNT_HOTSPOTS =`.
class _JsLiteral {
  _JsLiteral(this._source, this._index);

  final String _source;
  int _index;

  /// Findet [assignment] und liest den Wert dahinter.
  ///
  /// **Übergeht Fundstellen in Kommentaren.** Steht `window.HUNT_HOTSPOTS`
  /// in einer `//`-Zeile oder einem `/* */`-Block oberhalb der echten
  /// Zuweisung, fand `indexOf` bisher den Kommentar zuerst, das `=` dahinter
  /// gehörte oft noch zu einer anderen Zeile, und das Ergebnis war ein
  /// stilles „0 Hotspots" statt eines Abbruchs.
  static Object? read(String source, String assignment) {
    var at = source.indexOf(assignment);
    while (at >= 0 && _isInsideComment(source, at)) {
      at = source.indexOf(assignment, at + assignment.length);
    }
    if (at < 0) {
      _fail('Zuweisung nicht gefunden (nur in Kommentaren?): $assignment');
    }
    final equals = source.indexOf('=', at + assignment.length);
    if (equals < 0) {
      _fail('Kein `=` hinter $assignment.');
    }
    return _JsLiteral(source, equals + 1)._value();
  }

  /// Grobe, aber für die kuratierten Dateien ausreichende Prüfung: steht
  /// [index] in einem `//`-Rest der Zeile oder in einem offenen `/* */`?
  static bool _isInsideComment(String source, int index) {
    final lineStart = source.lastIndexOf('\n', index) + 1;
    final lineComment = source.indexOf('//', lineStart);
    if (lineComment >= 0 && lineComment < index) {
      return true;
    }
    final blockStart = source.lastIndexOf('/*', index);
    if (blockStart < 0) {
      return false;
    }
    final blockEnd = source.indexOf('*/', blockStart);
    return blockEnd < 0 || blockEnd > index;
  }

  Object? _value() {
    _skipIrrelevant();
    if (_index >= _source.length) {
      _fail('Unerwartetes Ende der Datei.');
    }
    final c = _source[_index];
    if (c == '{') {
      return _object();
    }
    if (c == '[') {
      return _array();
    }
    if (c == '"' || c == "'" || c == '`') {
      return _string();
    }
    if (_source.startsWith('true', _index)) {
      _index += 4;
      return true;
    }
    if (_source.startsWith('false', _index)) {
      _index += 5;
      return false;
    }
    if (_source.startsWith('null', _index)) {
      _index += 4;
      return null;
    }
    return _number();
  }

  Map<String, Object?> _object() {
    final result = <String, Object?>{};
    _index++; // {
    while (true) {
      _skipIrrelevant();
      if (_index >= _source.length) {
        _fail('Objekt nicht geschlossen.');
      }
      if (_source[_index] == '}') {
        _index++;
        return result;
      }
      final key = _source[_index] == '"' || _source[_index] == "'"
          ? _string()
          : _identifier();
      _skipIrrelevant();
      if (_index >= _source.length || _source[_index] != ':') {
        _fail('Kein `:` nach dem Schlüssel "$key".');
      }
      _index++;
      // Ein doppelter Schlüssel überschriebe sonst still den ersten Eintrag,
      // und die erzeugte Tabelle hätte lautlos eine Stadt bzw. einen Hotspot
      // weniger, als die Quelle wirklich trägt.
      if (result.containsKey(key)) {
        _fail('Doppelter Schlüssel "$key".');
      }
      result[key] = _value();
      _skipIrrelevant();
      if (_index < _source.length && _source[_index] == ',') {
        _index++;
      }
    }
  }

  List<Object?> _array() {
    final result = <Object?>[];
    _index++; // [
    while (true) {
      _skipIrrelevant();
      if (_index >= _source.length) {
        _fail('Liste nicht geschlossen.');
      }
      if (_source[_index] == ']') {
        _index++;
        return result;
      }
      result.add(_value());
      _skipIrrelevant();
      if (_index < _source.length && _source[_index] == ',') {
        _index++;
      }
    }
  }

  String _string() {
    final quote = _source[_index];
    _index++;
    final buffer = StringBuffer();
    while (_index < _source.length) {
      final c = _source[_index];
      if (c == r'\') {
        _index++;
        if (_index >= _source.length) {
          break;
        }
        final escaped = _source[_index];
        buffer.write(switch (escaped) {
          'n' => '\n',
          't' => '\t',
          'r' => '\r',
          _ => escaped,
        });
        _index++;
        continue;
      }
      if (c == quote) {
        _index++;
        return buffer.toString();
      }
      buffer.write(c);
      _index++;
    }
    _fail('Zeichenkette nicht geschlossen.');
  }

  String _identifier() {
    final start = _index;
    while (_index < _source.length &&
        RegExp(r'[A-Za-z0-9_$]').hasMatch(_source[_index])) {
      _index++;
    }
    if (start == _index) {
      _fail('Schlüssel erwartet an Position $_index.');
    }
    return _source.substring(start, _index);
  }

  num _number() {
    final start = _index;
    while (_index < _source.length &&
        RegExp('[-+0-9.eE]').hasMatch(_source[_index])) {
      _index++;
    }
    final text = _source.substring(start, _index);
    final parsed = num.tryParse(text);
    if (parsed == null) {
      _fail('Keine Zahl: "$text"');
    }
    return parsed;
  }

  /// Überspringt Leerraum, `//`-Zeilen und `/* */`-Blöcke.
  void _skipIrrelevant() {
    while (_index < _source.length) {
      final c = _source[_index];
      if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
        _index++;
        continue;
      }
      if (_source.startsWith('//', _index)) {
        final end = _source.indexOf('\n', _index);
        _index = end < 0 ? _source.length : end + 1;
        continue;
      }
      if (_source.startsWith('/*', _index)) {
        final end = _source.indexOf('*/', _index);
        _index = end < 0 ? _source.length : end + 2;
        continue;
      }
      return;
    }
  }
}
