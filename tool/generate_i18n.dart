// Erzeugt die Dart-Sprach-Maps aus der PWA-Quelle.
//
// Die PWA unter `02_Frontend/app/` ist die Verhaltensquelle für alle Texte.
// Dieses Skript liest sie und schreibt `lib/app/localization/generated/`.
// Abschreiben ist verboten: kommen in der PWA Schlüssel dazu, läuft das Skript
// erneut und der Diff zeigt genau, was sich geändert hat.
//
// Aufruf:
//   dart run tool/generate_i18n.dart
//   dart run tool/generate_i18n.dart --source "<Pfad zu 02_Frontend/app>"
//   dart run tool/generate_i18n.dart --check
//
// `--check` schreibt nichts und endet mit Exit-Code 1, sobald die Dateien im
// Repository von der Quelle abweichen.
//
// Zusätzlich prüft das Skript in **beiden** Betriebsarten die handgepflegte
// Ergänzung `lib/app/localization/app_strings_supplement.dart` gegen: jeder
// Schlüssel dort muss in der PWA fehlen. Bekommt die Quelle einen davon, endet
// das Skript mit Exit-Code 1 und nennt ihn. Siehe E-39 in REBUILD_STATUS.md.
//
// Und, ebenfalls in **beiden** Betriebsarten: jeder `t('schluessel', lang)`-
// Aufruf im übrigen JSX muss einen Schlüssel benutzen, den es in einer
// Sprachtabelle oder in der Ergänzung gibt. Ohne diese Prüfung ist ein
// fehlender Schlüssel für das Werkzeug unsichtbar, denn `window.t` gibt bei
// einem fehlenden Schlüssel laut `translations.jsx:1600-1605` den Schlüssel
// selbst zurück, und der steht dann wörtlich auf dem Bildschirm. Genau diese
// Lücke hat E-28 durchgelassen. Siehe REBUILD_STATUS.md.
//
// Der Quellpfad wird in dieser Reihenfolge bestimmt:
//   1. `--source`
//   2. Umgebungsvariable FACT_PWA_APP_DIR
//   3. der in CLAUDE.md dokumentierte Standardpfad
//
// In das Lese-Repository wird nie geschrieben.

import 'dart:io';

/// Standardpfad des PWA-Verzeichnisses, siehe CLAUDE.md, Abschnitt
/// "Reference repository (read-only)". Nur Lesezugriff.
const _defaultSourceDir =
    r'C:\Users\Janek Postpischil\OneDrive\DokumenteClaudeSortierung\Documents'
    r'\01_Persönliches\12_Claude\Claude Code\Fact\02_Frontend\app';

/// Zielverzeichnis der erzeugten Dateien, relativ zur Projektwurzel.
const _outputDir = 'lib/app/localization/generated';

/// Handgepflegte Ergänzungs-Map, siehe E-39 in REBUILD_STATUS.md.
///
/// Sie liegt bewusst **außerhalb** von [_outputDir]: dieses Skript schreibt
/// sie nie, es prüft sie nur gegen.
const _supplementFile = 'lib/app/localization/app_strings_supplement.dart';

/// Zwei Schlüssel der PWA tragen eine Liste statt eines Textes. Sie landen in
/// einer eigenen Map, damit die Text-Map typisiert `Map<String, String>` bleibt.
const _knownListKeys = <String>{'creator.steps', 'profil.levelTitles'};

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
  final config = _readConfig(sourceDir, report);
  final tables = _readTables(sourceDir, config, report);

  _checkParity(tables, report);
  // Vor beiden Betriebsarten, nicht nur vor dem Schreiben: sonst merkt der
  // überflüssig gewordene Ergänzungs-Eintrag nur, wer gerade neu erzeugt.
  _checkSupplement(tables);
  _checkSourceUsage(sourceDir, tables);

  final files = _renderFiles(tables, config);

  if (options.checkOnly) {
    final drifted = _findDrift(files);
    report.print();
    if (drifted.isEmpty) {
      stdout.writeln('i18n-Check: erzeugte Dateien stimmen mit der Quelle.');
      return;
    }
    stderr.writeln(
      'i18n-Check: ${drifted.length} Datei bzw. Dateien weichen von der '
      'Quelle ab:',
    );
    for (final path in drifted) {
      stderr.writeln('  $path');
    }
    stderr.writeln('Erneut erzeugen: dart run tool/generate_i18n.dart');
    exit(1);
  }

  _writeFiles(files);
  _formatFiles(files.keys.toList());
  report.print();
  _printSummary(tables, files);
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

/// Sammelt alles, was an der Quelle auffällt. Das Skript reparariert nichts
/// still, es berichtet.
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

// ── Konfiguration aus i18n-config.jsx ────────────────────────────────────────

class _I18nConfig {
  const _I18nConfig({
    required this.activeLanguages,
    required this.defaultLanguage,
    required this.fallbackLanguage,
  });

  final List<String> activeLanguages;
  final String defaultLanguage;
  final String fallbackLanguage;
}

_I18nConfig _readConfig(Directory sourceDir, _Report report) {
  final file = File(
    '${sourceDir.path}${Platform.pathSeparator}i18n-config.jsx',
  );
  if (!file.existsSync()) {
    _fail('i18n-config.jsx nicht gefunden unter ${file.path}');
  }
  final source = file.readAsStringSync();

  final activeMatch = RegExp(r'active\s*:\s*\[([^\]]*)\]').firstMatch(source);
  if (activeMatch == null) {
    _fail('i18n-config.jsx: `active` nicht gefunden.');
  }
  final active = activeMatch
      .group(1)!
      .split(',')
      .map((part) => part.trim().replaceAll(RegExp("^['\"]|['\"]\$"), ''))
      .where((part) => part.isNotEmpty)
      .toList();

  final defaultLanguage = _readConfigString(source, 'default');
  final fallbackLanguage = _readConfigString(source, 'fallback');

  if (!active.contains(fallbackLanguage)) {
    report.note(
      'i18n-config.jsx: fallback "$fallbackLanguage" ist nicht in `active`.',
    );
  }

  return _I18nConfig(
    activeLanguages: active,
    defaultLanguage: defaultLanguage,
    fallbackLanguage: fallbackLanguage,
  );
}

String _readConfigString(String source, String field) {
  final match = RegExp('$field\\s*:\\s*\'([a-z]+)\'').firstMatch(source);
  if (match == null) {
    _fail('i18n-config.jsx: `$field` nicht gefunden.');
  }
  return match.group(1)!;
}

// ── Sprachtabellen einlesen ──────────────────────────────────────────────────

/// Eine Sprache mit ihren Texten und Listen, in Quell-Reihenfolge.
class _LanguageTable {
  _LanguageTable(this.code);

  final String code;
  final Map<String, String> texts = <String, String>{};
  final Map<String, List<String>> lists = <String, List<String>>{};
}

Map<String, _LanguageTable> _readTables(
  Directory sourceDir,
  _I18nConfig config,
  _Report report,
) {
  final separator = Platform.pathSeparator;
  final translations = _readSourceFile(
    '${sourceDir.path}${separator}translations.jsx',
  );
  final audio = _readSourceFile(
    '${sourceDir.path}${separator}audio-strings.jsx',
  );

  final tables = <String, _LanguageTable>{};

  for (final code in config.activeLanguages) {
    final table = _LanguageTable(code);

    final block = _findObjectAfter(
      translations,
      RegExp('\\b$code\\s*:\\s*\\{'),
    );
    if (block == null) {
      report.note('translations.jsx: kein Block für Sprache "$code".');
      tables[code] = table;
      continue;
    }
    _absorb(
      _parseObjectLiteral(translations, block, 'translations.jsx'),
      table,
      'translations.jsx',
      report,
    );

    // audio-strings.jsx hängt sich per Object.assign an dieselben Tabellen.
    final variable = 'audio${code[0].toUpperCase()}${code.substring(1)}';
    final audioBlock = _findObjectAfter(
      audio,
      RegExp('const\\s+$variable\\s*=\\s*\\{'),
    );
    if (audioBlock == null) {
      report.note('audio-strings.jsx: `$variable` nicht gefunden.');
    } else {
      _absorb(
        _parseObjectLiteral(audio, audioBlock, 'audio-strings.jsx'),
        table,
        'audio-strings.jsx',
        report,
      );
    }

    tables[code] = table;
  }

  return tables;
}

_SourceFile _readSourceFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    _fail('Quelldatei nicht gefunden: $path');
  }
  return _SourceFile(path, file.readAsStringSync());
}

/// Übernimmt geparste Einträge in die Tabelle und meldet Doppelungen sowie
/// unerwartete Werttypen.
void _absorb(
  List<_Entry> entries,
  _LanguageTable table,
  String origin,
  _Report report,
) {
  for (final entry in entries) {
    final value = entry.value;
    if (value is String) {
      if (table.texts.containsKey(entry.key) &&
          table.texts[entry.key] != value) {
        report.note(
          '$origin:${entry.line}: "${entry.key}" (${table.code}) '
          'überschreibt einen abweichenden früheren Wert.',
        );
      } else if (table.texts.containsKey(entry.key)) {
        report.note(
          '$origin:${entry.line}: "${entry.key}" (${table.code}) ist doppelt '
          'mit gleichem Wert.',
        );
      }
      table.texts[entry.key] = value;
      continue;
    }

    if (value is List<String>) {
      if (!_knownListKeys.contains(entry.key)) {
        report.note(
          '$origin:${entry.line}: "${entry.key}" (${table.code}) ist neu als '
          'Listen-Schlüssel. _knownListKeys im Generator ergänzen.',
        );
      }
      table.lists[entry.key] = value;
      continue;
    }

    report.note(
      '$origin:${entry.line}: "${entry.key}" (${table.code}) hat einen '
      'unerwarteten Werttyp und wird übersprungen.',
    );
  }
}

// ── Paritätsprüfung ──────────────────────────────────────────────────────────

final _placeholderPattern = RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}');

void _checkParity(Map<String, _LanguageTable> tables, _Report report) {
  final allTextKeys = <String>{};
  final allListKeys = <String>{};
  for (final table in tables.values) {
    allTextKeys.addAll(table.texts.keys);
    allListKeys.addAll(table.lists.keys);
  }

  for (final key in allTextKeys.toList()..sort()) {
    for (final table in tables.values) {
      if (!table.texts.containsKey(key)) {
        report.note('Parität: "$key" fehlt in Sprache "${table.code}".');
      }
    }
  }
  for (final key in allListKeys.toList()..sort()) {
    for (final table in tables.values) {
      if (!table.lists.containsKey(key)) {
        report.note('Parität: Liste "$key" fehlt in Sprache "${table.code}".');
      }
    }
  }

  // Platzhalter müssen über alle Sprachen deckungsgleich sein, sonst rendert
  // eine Sprache eine Lücke oder eine rohe Klammer.
  final reference = tables.values.firstOrNull;
  if (reference == null) {
    return;
  }
  for (final key in reference.texts.keys) {
    final expected = _placeholders(reference.texts[key]!);
    for (final table in tables.values) {
      final actual = _placeholders(table.texts[key] ?? '');
      if (!_sameSet(expected, actual)) {
        report.note(
          'Platzhalter: "$key" hat in "${reference.code}" $expected, in '
          '"${table.code}" $actual.',
        );
      }
    }
  }

  for (final table in tables.values) {
    for (final entry in table.texts.entries) {
      if (entry.value.isEmpty) {
        report.note('Leerer Wert: "${entry.key}" (${table.code}).');
      }
    }
  }
}

Set<String> _placeholders(String value) =>
    _placeholderPattern.allMatches(value).map((m) => m.group(0)!).toSet();

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

// ── Gegenprüfung der handgepflegten Ergänzung ────────────────────────────────

/// Marker, ab dem in [_supplementFile] nach Schlüsseln gesucht wird.
const _supplementMarker = 'supplementTextsByLanguage =';

/// Ein Schlüssel der PWA trägt immer einen Namensraum mit Punkt, etwa
/// `tour.stepCounter`. Erkannt wird ein solcher String, auf den ein Doppelpunkt
/// folgt, also genau eine Map-Zeile.
final _supplementKeyPattern = RegExp(
  r"'([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)'\s*:",
);

/// Jeder String, auf den ein Doppelpunkt folgt. Dient nur der Gegenprobe zu
/// [_supplementKeyPattern]: ein Schlüssel ohne Punkt würde sonst still durch
/// die Prüfung fallen und die Ergänzung ungeprüft lassen.
final _supplementAnyKeyPattern = RegExp(r"'([^']*)'\s*:");

/// Stellt sicher, dass jeder Ergänzungs-Schlüssel in der PWA **fehlt**.
///
/// Die Ergänzung ist eine Notlösung für Texte, die die PWA anzeigt, ohne sie
/// als Schlüssel zu führen. Sobald die Quelle einen davon bekommt, ist der
/// lokale Eintrag überflüssig und wird zur zweiten Wahrheit. Deshalb endet das
/// Skript hier hart statt still.
void _checkSupplement(Map<String, _LanguageTable> tables) {
  final keys = _readSupplementKeys();

  final found = <String, List<String>>{};
  for (final key in keys) {
    for (final table in tables.values) {
      if (table.texts.containsKey(key) || table.lists.containsKey(key)) {
        (found[key] ??= <String>[]).add(table.code);
      }
    }
  }

  if (found.isEmpty) {
    stdout.writeln(
      'Ergänzung: ${keys.length} Schlüssel in $_supplementFile, '
      'keiner davon in der PWA.',
    );
    return;
  }

  stderr.writeln(
    'Ergänzung: ${found.length} Schlüssel steht bzw. stehen jetzt in der PWA '
    'und kommt damit aus der Quelle:',
  );
  for (final entry in found.entries) {
    stderr.writeln('  ${entry.key} (Sprache ${entry.value.join(', ')})');
  }
  stderr.writeln(
    'Diesen Eintrag bzw. diese Einträge in $_supplementFile löschen. '
    'AppStrings zieht den erzeugten Wert ohnehin vor, der Text stimmt also '
    'schon jetzt; die Ergänzung ist nur noch tote Doppelung.',
  );
  exit(1);
}

/// Liest die Schlüssel aus [_supplementFile].
///
/// Kein Parser, sondern ein Muster über den Quelltext ab [_supplementMarker].
/// Das reicht, weil die Datei nur Map-Literale enthält, und es hält den
/// Generator frei von einer Abhängigkeit auf den Analyzer. Ganzzeilige
/// Kommentare fallen vorher weg, damit ein im Kommentar genannter Schlüssel
/// keine falsche Meldung auslöst.
Set<String> _readSupplementKeys() {
  final file = File(_supplementFile);
  if (!file.existsSync()) {
    _fail(
      'Ergänzungsdatei nicht gefunden: $_supplementFile. Sie gehört zum '
      'Projekt, siehe E-39 in REBUILD_STATUS.md.',
    );
  }

  final source = file
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  final start = source.indexOf(_supplementMarker);
  if (start == -1) {
    _fail(
      '$_supplementFile: "$_supplementMarker" nicht gefunden. Ohne diesen '
      'Anker weiß der Generator nicht, welche Schlüssel er gegen die PWA '
      'prüfen soll, und würde eine leere Ergänzung vortäuschen.',
    );
  }
  final body = source.substring(start);

  final all = _supplementAnyKeyPattern
      .allMatches(body)
      .map((m) => m.group(1)!)
      .toSet();
  final keys = _supplementKeyPattern
      .allMatches(body)
      .map((m) => m.group(1)!)
      .toSet();

  final unexpected = all.difference(keys);
  if (unexpected.isNotEmpty) {
    _fail(
      '$_supplementFile: ${unexpected.map((k) => '"$k"').join(', ')} sieht '
      'nicht wie ein PWA-Schlüssel aus. Die tragen immer einen Namensraum mit '
      'Punkt. Ungeprüft stehen lassen kommt nicht in Frage, deshalb Abbruch.',
    );
  }

  return keys;
}

// ── Gegenprüfung der JSX-Aufrufstellen ───────────────────────────────────────

/// Erkennt `t('...')`, `window.t('...')` und `window.t?.('...')` mit einem
/// echten Zeichenketten-Literal in einfachen Anführungszeichen als Argument.
///
/// Der Lookbehind schließt Aufrufe aus, die zufällig auch auf „t(" enden,
/// etwa `shortcut('...')` oder `delight('...')`. Nur ein Treffer, auf den
/// direkt `,` oder `)` folgt, zählt als vollständiger Schlüssel: folgt
/// stattdessen `+`, ist der Aufruf zusammengesetzt (`t('cat.' + x, lang)`),
/// und der ganze Schlüssel steht nicht im Quelltext. Ein Test würde ihn sonst
/// als „cat." melden, ein Schlüssel, den es nie geben kann.
final _sourceCallPattern = RegExp(
  r"(?<![A-Za-z0-9_.])(?:window\.t\?\.|window\.t|t)\(\s*'((?:[^'\\]|\\.)*)'\s*(?=[,)])",
);

/// Ein Schlüssel der PWA trägt immer einen Namensraum mit Punkt, siehe
/// [_supplementKeyPattern]. Gegenprobe dazu: ein Treffer ohne Punkt ist kein
/// PWA-Schlüssel und wird hier bewusst nicht geprüft.
bool _looksLikeNamespacedKey(String key) => key.contains('.');

/// Sicherungskopien sind kein laufender Code, ihre Schlüssel sagen nichts
/// über die heutige PWA. Im echten Bestand: `screen-map.original.jsx`
/// (Namensmuster `.original.`) und `_old_göttingen-data.jsx.bak` (Endung
/// `.bak`).
bool _isBackupFile(String name) =>
    name.contains('.original.') || name.endsWith('.bak');

/// Die beiden Wörterbücher selbst zählen nicht als Aufrufstellen, sie sind
/// die Quelle, gegen die geprüft wird.
bool _isDictionaryFile(String name) =>
    name == 'translations.jsx' || name == 'audio-strings.jsx';

/// Bekannte Lücken zwischen einem JSX-Aufruf und den Wörterbüchern. Beide
/// liegen im anderen Repository und sind von hier nicht behebbar; ein harter
/// Abbruch ohne diese Liste wäre sinnlos, weil das Werkzeug dann ab dem
/// ersten Lauf dauerhaft rot wäre für etwas, das hier niemand beheben kann.
/// Jeder weitere Eintrag braucht eine eigene E-Nummer, siehe
/// REBUILD_STATUS.md, und Rücksprache, bevor er hier landet.
const _knownMissingSourceKeys = <String>{
  'audio.dialog.volumeHint', // E-28
  'group.join.title', // E-63
};

/// Entfernt Zeilen- und Blockkommentare aus JS-Quelltext, ohne Zustände in
/// String-Literalen zu verwechseln. Ein naives Entfernen ab dem ersten `//`
/// würde eine URL wie `'http://…'` mitten im String kappen und den Rest der
/// Zeile falsch als Kommentar behandeln.
///
/// Entfernte Abschnitte werden durch dieselbe Anzahl Zeilenumbrüche ersetzt,
/// damit Zeilennummern in Fehlermeldungen weiterhin auf die richtige Zeile
/// der Originaldatei zeigen.
///
/// Kennt keine `${…}`-Interpolation in Template-Strings: ein `//` oder `/*`
/// innerhalb eines interpolierten Ausdrucks würde fälschlich als Teil des
/// Strings gelten. Im echten Bestand kommt das nicht vor, siehe die
/// Gegenprobe am echten Bestand in REBUILD_STATUS.md.
String _stripComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (char == "'" || char == '"' || char == '`') {
      final quote = char;
      buffer.write(char);
      i++;
      while (i < source.length) {
        final c = source[i];
        buffer.write(c);
        if (c == r'\' && i + 1 < source.length) {
          i++;
          buffer.write(source[i]);
          i++;
          continue;
        }
        // **Der Zustand darf keine Zeile überleben.** Ein `'` oder `"`
        // schließt in JavaScript spätestens am Zeilenende; steht bis dahin
        // kein zweites, war das erste gar kein Anfang einer Zeichenkette,
        // sondern Text. Genau das kommt im JSX ständig vor, als Minutenzeichen
        // (`{min}'`) oder als typografisches Anführungszeichen im Fließtext.
        //
        // Ohne diesen Abbruch **kaskadiert** so ein Zeichen: der Scanner hält
        // die Zeichenkette bis zum nächsten gleichen Zeichen offen, oft erst
        // Zeilen später, und in der Zwischenzeit ist seine Parität verschoben.
        // Ein `//` in einer echten Zeichenkette gilt dann als Zeilenkommentar,
        // und alles bis Zeilenende fällt weg, samt einem `t()`-Aufruf darin.
        // Am 02.09.2026 an einer Wegwerf-Datei ausgelöst: ein fehlender
        // Schlüssel verschwand **still**, und still ist genau der Fehler,
        // gegen den diese ganze Prüfung gebaut ist.
        //
        // Das Zurücksetzen macht den Fehler örtlich: ein verlesenes Zeichen
        // verdirbt höchstens seine eigene Zeile. Für ` gilt es nicht, ein
        // Template-Literal darf mehrzeilig sein.
        if (quote != '`' && c == '\n') {
          i++;
          break;
        }
        i++;
        if (c == quote) {
          break;
        }
      }
      continue;
    }
    if (char == '/' && i + 1 < source.length && source[i + 1] == '/') {
      final end = source.indexOf('\n', i);
      i = end == -1 ? source.length : end;
      continue;
    }
    if (char == '/' && i + 1 < source.length && source[i + 1] == '*') {
      final end = source.indexOf('*/', i + 2);
      if (end == -1) {
        break;
      }
      final removed = source.substring(i, end + 2);
      buffer.write('\n' * '\n'.allMatches(removed).length);
      i = end + 2;
      continue;
    }
    buffer.write(char);
    i++;
  }
  return buffer.toString();
}

/// Ein Fund: ein Aufruf im JSX, dessen Schlüssel weder in einer Sprachtabelle
/// noch in der Ergänzung noch in [_knownMissingSourceKeys] steht.
class _SourceMiss {
  const _SourceMiss({
    required this.file,
    required this.line,
    required this.key,
  });

  final String file;
  final int line;
  final String key;
}

/// Prüft jeden `t()`-Aufruf im übrigen JSX gegen die Sprachtabellen.
///
/// Ein Aufruf, dessen Schlüssel in keiner Sprache und nicht in der Ergänzung
/// steht, ist ein Fund: die PWA zeigt an dieser Stelle im Ernstfall den
/// Schlüssel selbst an. Die Gegenprüfung aus E-39 deckt das nicht ab, sie
/// läuft in die andere Richtung und meldet Ergänzungs-Schlüssel, die es in
/// der PWA inzwischen gibt.
void _checkSourceUsage(
  Directory sourceDir,
  Map<String, _LanguageTable> tables,
) {
  final knownKeys = <String>{};
  for (final table in tables.values) {
    knownKeys.addAll(table.texts.keys);
    knownKeys.addAll(table.lists.keys);
  }
  final supplementKeys = _readSupplementKeys();

  final files =
      sourceDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.jsx'))
          .where((file) {
            final name = file.path.split(Platform.pathSeparator).last;
            return !_isDictionaryFile(name) && !_isBackupFile(name);
          })
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final checkedKeys = <String>{};
  final missing = <_SourceMiss>[];
  final matchedKnownGaps = <String>{};

  for (final file in files) {
    final name = file.path.split(Platform.pathSeparator).last;
    final text = _stripComments(file.readAsStringSync());
    for (final match in _sourceCallPattern.allMatches(text)) {
      final key = match.group(1)!;
      if (!_looksLikeNamespacedKey(key)) {
        continue;
      }
      checkedKeys.add(key);
      if (knownKeys.contains(key) || supplementKeys.contains(key)) {
        continue;
      }
      if (_knownMissingSourceKeys.contains(key)) {
        matchedKnownGaps.add(key);
        continue;
      }
      missing.add(
        _SourceMiss(file: name, line: _lineOf(text, match.start), key: key),
      );
    }
  }

  if (missing.isNotEmpty) {
    stderr.writeln(
      'Quellnutzung: ${missing.length} Aufruf bzw. Aufrufe im JSX benutzen '
      'einen Schlüssel, der in keiner Sprachtabelle und keiner Ergänzung '
      'steht:',
    );
    for (final miss in missing) {
      stderr.writeln('  ${miss.file}:${miss.line}: "${miss.key}"');
    }
    stderr.writeln(
      'Entweder fehlt der Schlüssel wirklich in der PWA (eine neue E-Nummer '
      'anfragen und den Schlüssel dann in _knownMissingSourceKeys eintragen) '
      'oder das Muster hat einen Fehlalarm gefunden.',
    );
    exit(1);
  }

  // Genau wie bei _checkSupplement ein harter Abbruch statt einer bloßen
  // Meldung: eine Liste bekannter Lücken, die niemand zwingt, aktuell zu
  // halten, verrottet irgendwann lautlos und bewacht dann nichts mehr.
  final staleKnownGaps = _knownMissingSourceKeys.difference(matchedKnownGaps);
  if (staleKnownGaps.isNotEmpty) {
    stderr.writeln(
      'Quellnutzung: ${staleKnownGaps.length} Eintrag bzw. Einträge in '
      '_knownMissingSourceKeys sind veraltet:',
    );
    for (final key in staleKnownGaps.toList()..sort()) {
      stderr.writeln('  $key');
    }
    stderr.writeln(
      'Entweder steht der Schlüssel jetzt in einer Sprachtabelle, oder er '
      'kommt im JSX nicht mehr vor. In beiden Fällen aus '
      '_knownMissingSourceKeys entfernen.',
    );
    exit(1);
  }

  stdout.writeln(
    'Quellnutzung: ${checkedKeys.length} benutzte Schlüssel mit Namensraum '
    'geprüft, ${_knownMissingSourceKeys.length} bekannte Lücke bzw. Lücken '
    'davon unverändert.',
  );
}

// ── Dart-Dateien erzeugen ────────────────────────────────────────────────────

Map<String, String> _renderFiles(
  Map<String, _LanguageTable> tables,
  _I18nConfig config,
) {
  final files = <String, String>{};

  for (final table in tables.values) {
    files['$_outputDir/app_strings_${table.code}.g.dart'] = _renderLanguageFile(
      table,
    );
  }
  files['$_outputDir/app_strings_index.g.dart'] = _renderIndexFile(
    tables,
    config,
  );

  return files;
}

String _renderLanguageFile(_LanguageTable table) {
  final suffix = _pascal(table.code);
  final buffer = StringBuffer()
    ..writeln(_header())
    ..writeln(
      '// Sprache: ${table.code}. ${table.texts.length} Texte, '
      '${table.lists.length} Listen.',
    )
    ..writeln()
    ..writeln('/// Alle Texte der Sprache `${table.code}`.')
    ..writeln('///')
    ..writeln('/// Die Schlüssel sind exakt die der PWA, damit beim Portieren')
    ..writeln('/// eines Screens die Zuordnung zur Verhaltensquelle erhalten')
    ..writeln('/// bleibt. Reihenfolge wie in der Quelle.')
    ..writeln('const Map<String, String> appTexts$suffix = <String, String>{');

  for (final entry in table.texts.entries) {
    buffer.writeln('  ${_dartString(entry.key)}: ${_dartString(entry.value)},');
  }

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('/// Listenwerte der Sprache `${table.code}`.')
    ..writeln('///')
    ..writeln('/// Die PWA hinterlegt für diese Schlüssel ein Array statt')
    ..writeln('/// eines Textes.')
    ..writeln(
      'const Map<String, List<String>> appTextLists$suffix = '
      '<String, List<String>>{',
    );

  for (final entry in table.lists.entries) {
    final items = entry.value.map(_dartString).join(', ');
    buffer.writeln('  ${_dartString(entry.key)}: <String>[$items],');
  }

  buffer.writeln('};');
  return buffer.toString();
}

String _renderIndexFile(
  Map<String, _LanguageTable> tables,
  _I18nConfig config,
) {
  final codes = tables.keys.toList();
  final buffer = StringBuffer()..writeln(_header());

  for (final code in codes) {
    buffer.writeln(
      "import 'package:fact_app/app/localization/generated/"
      "app_strings_$code.g.dart';",
    );
  }

  buffer
    ..writeln()
    ..writeln('/// Sprachen, die die PWA ausliefert (`I18N.active`).')
    ..writeln(
      'const List<String> generatedLanguageCodes = <String>['
      '${codes.map(_dartString).join(', ')}];',
    )
    ..writeln()
    ..writeln('/// Startsprache vor der ersten Wahl (`I18N.default`).')
    ..writeln(
      'const String generatedDefaultLanguageCode = '
      '${_dartString(config.defaultLanguage)};',
    )
    ..writeln()
    ..writeln('/// Sprache, die einspringt, wenn ein Schlüssel fehlt')
    ..writeln('/// (`I18N.fallback`).')
    ..writeln(
      'const String generatedFallbackLanguageCode = '
      '${_dartString(config.fallbackLanguage)};',
    )
    ..writeln()
    ..writeln('/// Texttabellen nach Sprachkürzel.')
    ..writeln(
      'const Map<String, Map<String, String>> generatedTextsByLanguage = '
      '<String, Map<String, String>>{',
    );
  for (final code in codes) {
    buffer.writeln('  ${_dartString(code)}: appTexts${_pascal(code)},');
  }
  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('/// Listentabellen nach Sprachkürzel.')
    ..writeln(
      'const Map<String, Map<String, List<String>>> '
      'generatedTextListsByLanguage = '
      '<String, Map<String, List<String>>>{',
    );
  for (final code in codes) {
    buffer.writeln('  ${_dartString(code)}: appTextLists${_pascal(code)},');
  }
  buffer.writeln('};');

  return buffer.toString();
}

String _header() =>
    '// GENERIERT von tool/generate_i18n.dart. Nicht von Hand bearbeiten.\n'
    '//\n'
    '// Quelle, nur lesend:\n'
    '//   02_Frontend/app/translations.jsx  (window.I18n.strings)\n'
    '//   02_Frontend/app/audio-strings.jsx (audioDe, audioEn)\n'
    '//   02_Frontend/app/i18n-config.jsx   (aktive Sprachen, Fallback)\n'
    '//\n'
    '// Erneut erzeugen: dart run tool/generate_i18n.dart';

String _pascal(String code) => code[0].toUpperCase() + code.substring(1);

/// Schreibt [value] als einfach gequotetes Dart-Literal. Umlaute und Emoji
/// bleiben als echte Zeichen stehen, die Datei wird als UTF-8 geschrieben.
String _dartString(String value) {
  final buffer = StringBuffer("'");
  for (final rune in value.runes) {
    switch (rune) {
      case 0x5C: // Backslash
        buffer.write(r'\\');
      case 0x27: // Apostroph
        buffer.write(r"\'");
      case 0x24: // Dollar, sonst Dart-Interpolation
        buffer.write(r'\$');
      case 0x0A:
        buffer.write(r'\n');
      case 0x0D:
        buffer.write(r'\r');
      case 0x09:
        buffer.write(r'\t');
      default:
        if (rune < 0x20 || rune == 0x7F) {
          buffer.write('\\u{${rune.toRadixString(16)}}');
        } else {
          buffer.write(String.fromCharCode(rune));
        }
    }
  }
  return (buffer..write("'")).toString();
}

// ── Schreiben, Formatieren, Vergleichen ──────────────────────────────────────

void _writeFiles(Map<String, String> files) {
  for (final entry in files.entries) {
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    // Dart schreibt standardmäßig UTF-8, damit landen ä, ö, ü und ß korrekt.
    file.writeAsStringSync(entry.value);
  }
}

/// Lässt `dart format` über die erzeugten Dateien laufen. Das Gate
/// `dart format --set-exit-if-changed .` prüft auch generierten Code, also
/// formatiert der Generator selbst statt zu raten, wo umgebrochen wird.
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
/// Der Vergleich läuft über eine formatierte Kopie in einem Temp-Verzeichnis.
/// Ein Vergleich auf der Rohfassung würde scheitern, weil `dart format` mehr
/// als Leerraum ändert: es bricht lange Listenliterale um und setzt dabei ein
/// zusätzliches Komma nach dem letzten Element.
List<String> _findDrift(Map<String, String> files) {
  final temp = Directory.systemTemp.createTempSync('fact_i18n_check');
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

String _lineEndings(String source) => source.replaceAll('\r\n', '\n');

void _printSummary(
  Map<String, _LanguageTable> tables,
  Map<String, String> files,
) {
  stdout.writeln('i18n erzeugt:');
  for (final table in tables.values) {
    stdout.writeln(
      '  ${table.code}: ${table.texts.length} Texte, '
      '${table.lists.length} Listen',
    );
  }
  for (final path in files.keys) {
    stdout.writeln('  geschrieben: $path');
  }
}

// ── Mini-Parser für JS-Objektliterale ────────────────────────────────────────

class _SourceFile {
  const _SourceFile(this.path, this.text);

  final String path;
  final String text;
}

class _Entry {
  const _Entry({required this.key, required this.value, required this.line});

  final String key;
  final Object value;
  final int line;
}

/// Sucht [marker] und liefert den Index der öffnenden Klammer am Trefferende.
int? _findObjectAfter(_SourceFile file, RegExp marker) {
  final match = marker.firstMatch(file.text);
  if (match == null) {
    return null;
  }
  return file.text.lastIndexOf('{', match.end);
}

/// Liest das Objektliteral, das bei [openIndex] beginnt.
///
/// Der Parser kennt Strings und Kommentare. Das ist keine Spielerei: Werte wie
/// `'{n} Fakten'` enthalten Klammern, ein naives Zählen von `{` und `}` würde
/// mitten im Text abbrechen.
List<_Entry> _parseObjectLiteral(
  _SourceFile file,
  int openIndex,
  String origin,
) {
  final text = file.text;
  final entries = <_Entry>[];
  var i = openIndex + 1;

  while (true) {
    i = _skipTrivia(text, i);
    if (i >= text.length) {
      _fail('$origin: Objektliteral endet unerwartet.');
    }
    if (text[i] == '}') {
      return entries;
    }
    if (text[i] == ',') {
      i++;
      continue;
    }

    final lineNumber = _lineOf(text, i);
    final key = _readKey(text, i, origin);
    i = _skipTrivia(text, key.next);
    if (i >= text.length || text[i] != ':') {
      _fail('$origin:$lineNumber: Doppelpunkt nach "${key.value}" erwartet.');
    }
    i = _skipTrivia(text, i + 1);

    final value = _readValue(text, i, origin, lineNumber);
    entries.add(_Entry(key: key.value, value: value.value, line: lineNumber));
    i = value.next;
  }
}

int _skipTrivia(String text, int start) {
  var i = start;
  while (i < text.length) {
    final char = text[i];
    if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
      i++;
      continue;
    }
    if (char == '/' && i + 1 < text.length) {
      final next = text[i + 1];
      if (next == '/') {
        final end = text.indexOf('\n', i);
        i = end == -1 ? text.length : end + 1;
        continue;
      }
      if (next == '*') {
        final end = text.indexOf('*/', i + 2);
        if (end == -1) {
          return text.length;
        }
        i = end + 2;
        continue;
      }
    }
    return i;
  }
  return i;
}

class _Read<T> {
  const _Read(this.value, this.next);

  final T value;
  final int next;
}

_Read<String> _readKey(String text, int start, String origin) {
  final char = text[start];
  if (char == "'" || char == '"') {
    return _readStringLiteral(text, start, origin);
  }
  final identifier = RegExp(
    r'[A-Za-z_$][A-Za-z0-9_$]*',
  ).matchAsPrefix(text, start);
  if (identifier == null) {
    _fail('$origin:${_lineOf(text, start)}: Schlüssel erwartet.');
  }
  return _Read(identifier.group(0)!, identifier.end);
}

_Read<Object> _readValue(
  String text,
  int start,
  String origin,
  int lineNumber,
) {
  final char = text[start];
  if (char == "'" || char == '"') {
    final read = _readStringLiteral(text, start, origin);
    return _Read<Object>(read.value, read.next);
  }
  if (char == '[') {
    final items = <String>[];
    var i = start + 1;
    while (true) {
      i = _skipTrivia(text, i);
      if (i >= text.length) {
        _fail('$origin:$lineNumber: Array endet unerwartet.');
      }
      if (text[i] == ']') {
        return _Read<Object>(items, i + 1);
      }
      if (text[i] == ',') {
        i++;
        continue;
      }
      final read = _readStringLiteral(text, i, origin);
      items.add(read.value);
      i = read.next;
    }
  }
  _fail(
    '$origin:$lineNumber: nur String- und Array-Werte werden unterstützt, '
    'gefunden "$char".',
  );
}

_Read<String> _readStringLiteral(String text, int start, String origin) {
  final quote = text[start];
  if (quote != "'" && quote != '"') {
    _fail('$origin:${_lineOf(text, start)}: String-Literal erwartet.');
  }
  final buffer = StringBuffer();
  var i = start + 1;
  while (i < text.length) {
    final char = text[i];
    if (char == quote) {
      return _Read(buffer.toString(), i + 1);
    }
    if (char == r'\') {
      i++;
      if (i >= text.length) {
        break;
      }
      final escape = text[i];
      switch (escape) {
        case 'n':
          buffer.write('\n');
        case 'r':
          buffer.write('\r');
        case 't':
          buffer.write('\t');
        case 'b':
          buffer.write('\b');
        case 'f':
          buffer.write('\f');
        case 'v':
          buffer.write('\v');
        case '0':
          buffer.write('\u0000');
        case 'u':
          final hex = text.substring(i + 1, i + 5);
          buffer.writeCharCode(int.parse(hex, radix: 16));
          i += 4;
        case 'x':
          final hex = text.substring(i + 1, i + 3);
          buffer.writeCharCode(int.parse(hex, radix: 16));
          i += 2;
        case '\n':
          // Zeilenfortsetzung im JS-String, erzeugt kein Zeichen.
          break;
        default:
          buffer.write(escape);
      }
      i++;
      continue;
    }
    buffer.write(char);
    i++;
  }
  _fail('$origin:${_lineOf(text, start)}: String-Literal nicht geschlossen.');
}

int _lineOf(String text, int index) {
  var line = 1;
  for (var i = 0; i < index && i < text.length; i++) {
    if (text[i] == '\n') {
      line++;
    }
  }
  return line;
}

Never _fail(String message) {
  stderr.writeln('generate_i18n: $message');
  exit(1);
}
