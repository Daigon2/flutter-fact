// Architektur-Grenzen maschinell prüfen.
//
// Deckt die neun Prüfungen aus docs/engineering/quality-gates.md, Abschnitt
// "Custom boundary checks", und die harten Regeln aus
// docs/architecture/dependency-rules.md ab.
//
// Aufruf: dart run tool/check_architecture.dart
// Exit-Code 1 bei jedem Verstoß, damit CI und die lokalen Gates scheitern.
// Funde der Stufe Severity.hinweis werden gemeldet, brechen den Lauf aber
// nicht ab.
//
// Warum ein eigenes Skript und nicht riverpod_lint über custom_lint?
// riverpod_lint ist mit dem aktuellen Abhängigkeitsstand nicht auflösbar. Die
// nachgeprüfte Kette:
//
//   riverpod_lint 3.1.8         verlangt analyzer ^13.0.0
//   flutter_test (aus dem SDK)  pinnt test_api 0.7.11 und matcher 0.12.19 und
//                               zwingt test damit in einen Bereich mit
//                               analyzer >=8.0.0 <13.0.0
//   supabase_flutter            versperrt den Ausweg über ältere
//                               test-Versionen (supabase 2.16.1 ->
//                               realtime_client 2.13.0 ->
//                               web_socket_channel ^3.0.3)
//   riverpod_lint >=3.1.4-dev.1 verlangt analyzer_plugin ^0.14.0,
//   custom_lint >=0.7.4         verlangt analyzer_plugin ^0.13.0 (Konflikt)
//
// riverpod_annotation ist im Projekt gar nicht vorhanden und an dem Konflikt
// unbeteiligt.
//
// Dieses Skript ersetzt riverpod_lint nicht. Es deckt einen anderen Teil ab:
// Feature- und Schichtgrenzen, die der Analyzer nicht kennt. Drei Regeln aus
// dependency-rules.md (7, 12, 13), die riverpod_lint teilweise erwischt hätte,
// sind hier textuell nachgebaut und deshalb gröber als eine echte
// Syntaxanalyse.
//
// Bewusst offene Lücken
// ---------------------
// Vier Fälle meldet das Skript absichtlich nicht. Sie stehen hier, damit
// niemand sie für ein Versehen hält und still "nachbessert":
//
//  1. Benannte Konstruktoren umgehen Regel 7 (`FactRepository.remote()`).
//     Hinter dem Namen steht ein Punkt statt einer Klammer, deshalb greift
//     `_instantiationPattern` nicht. Ein breiteres Muster würde jeden
//     statischen Factory-Helfer und jeden Zugriff auf eine Konstante desselben
//     Typs treffen und damit korrekten Code melden.
//  2. Direktiven werden nur am Zeilenanfang erkannt (`_directivePattern`).
//     `dart format` erzeugt nie etwas anderes, und das Format-Gate läuft in
//     derselben Pipeline. Eine zweite Direktive in derselben Zeile bleibt
//     deshalb unsichtbar.
//  3. `.go(variable)` wird nicht gemeldet, nur `.go('/literal')`. Genau so
//     sieht ADR-004-konformer Code aus, weil die typisierte Route den Pfad
//     liefert. Ein Verbot würde also überwiegend korrekten Code melden.
//  4. Regel 10 (Cross-Feature nur über einen öffentlichen Vertrag) bleibt
//     Review-Sache. Ein Import von `features/x/domain/` kann der öffentliche
//     Vertrag selbst sein oder dessen Umgehung, und beides sieht im Quelltext
//     gleich aus. Textuell ist das nicht unterscheidbar, deshalb prüft das
//     Skript nur fremdes `presentation/` und `data/` (Regel 8 und 9).

import 'dart:io';

/// Der Paketname aus pubspec.yaml. Gebraucht, um relative Importe auf ihre
/// `package:`-Form abzubilden.
const _packageName = 'fact_app';

/// Wie hart ein Fund gewertet wird.
enum Severity {
  /// Regelbruch. Der Lauf endet mit Exit-Code 1.
  verstoss,

  /// Wird gemeldet, bricht den Lauf aber nicht ab.
  hinweis,
}

/// Ein verbotener Import, ausgedrückt als Regex auf dem Import-Pfad.
class Ban {
  const Ban(this.pattern, this.rule, {this.severity = Severity.verstoss});

  final String pattern;
  final String rule;
  final Severity severity;
}

/// Eine Schicht plus die für sie verbotenen Importe.
class LayerRule {
  const LayerRule({
    required this.name,
    required this.pathMatch,
    required this.bans,
  });

  final String name;
  final RegExp pathMatch;
  final List<Ban> bans;
}

/// Reine Dart-Pakete, die die Domäne benutzen darf.
///
/// Die Tabelle in docs/architecture/dependency-rules.md sagt für Domain
/// wörtlich "Dart SDK and approved pure-Dart primitives only". Eine
/// Verbotsliste kann diesen Satz nicht abbilden: jedes Paket, an das niemand
/// gedacht hat, wäre eine offene Tür. Deshalb entscheidet über `package:`-
/// Importe in der Domäne eine Erlaubnisliste, siehe [_isAllowedDomainImport].
///
/// Aufnahmebedingung für einen Eintrag, alle drei müssen erfüllt sein:
///
///  1. Das Paket steht als direkte Abhängigkeit in pubspec.yaml. Ein
///     transitives Paket ist kein Vertrag, es kann jederzeit verschwinden.
///  2. Es ist rein Dart: kein Flutter-Bezug, kein Plattformkanal, kein
///     Vendor-SDK, keine Ein- und Ausgabe.
///  3. Es beschreibt Fachlichkeit oder eine Sprachprimitive, keine
///     Infrastruktur. Infrastruktur gehört hinter einen Domain-Vertrag, also
///     nach data oder services.
///
/// Stand heute leer, und das ist kein Versehen. Gegen pubspec.yaml geprüft:
/// flutter, flutter_localizations, flutter_riverpod, flutter_svg, geolocator,
/// go_router, maplibre_gl und supabase_flutter sind Flutter-gebunden oder
/// Vendor-SDKs, build_runner, flutter_lints, flutter_test und
/// go_router_builder sind Werkzeuge aus dev_dependencies. Keines davon
/// qualifiziert.
///
/// Ein neuer Eintrag ist eine Architekturentscheidung, nicht eine
/// Skriptänderung: er gehört mit Begründung in denselben Pull Request wie das
/// Paket selbst.
const _domainAllowedPackages = <String>[];

/// Gate 2, 3 und 6 sowie dependency-rules 1 bis 4: die Domäne bleibt
/// technikfrei und kennt nur das Dart-SDK und reine Dart-Primitive.
///
/// Diese Liste ist trotz der Erlaubnisliste nicht überflüssig. Sie liefert für
/// die häufigen Fälle die genaue Regelnummer, und ein Leser, der wissen will,
/// warum sein Import abgelehnt wurde, ist mit "Regel 3: Domain darf Supabase
/// nicht importieren" besser bedient als mit dem allgemeinen Satz aus
/// [_isAllowedDomainImport]. Trifft eines dieser Verbote, unterbleibt die
/// allgemeine Meldung, damit kein Import doppelt gemeldet wird.
const _domainBans = <Ban>[
  Ban(r'^package:flutter/', 'Regel 1: Domain darf Flutter nicht importieren'),
  Ban(r'^package:flutter_', 'Regel 1: Domain darf Flutter nicht importieren'),
  Ban(r'^package:riverpod', 'Regel 2: Domain darf Riverpod nicht importieren'),
  Ban(r'^package:supabase', 'Regel 3: Domain darf Supabase nicht importieren'),
  Ban(r'^package:go_router', 'Regel 4: Domain darf kein Routing importieren'),
  Ban(
    r'^package:shared_preferences',
    'Regel 4: Domain darf keine Storage-SDK importieren',
  ),
  Ban(
    r'^package:geolocator',
    'Regel 4: Domain darf keine Geräte-SDK importieren',
  ),
  Ban(
    r'^package:maplibre',
    'Regel 4: Domain darf keine Karten-SDK importieren',
  ),
  // Gate 6 aus quality-gates.md nennt als Verstoß "Feature-domain imports
  // from core". Die Tabelle in dependency-rules.md bestätigt das: nur
  // Presentation und Application dürfen eng abgegrenztes Core benutzen.
  Ban(
    r'^package:fact_app/core/',
    'Gate 6: Feature-Domain darf nicht aus core importieren, nur '
        'Presentation und Application dürfen eng abgegrenztes core nutzen',
  ),
  Ban(r'/data/', 'Import-Policy: domain darf nicht auf data zeigen'),
  Ban(
    r'/presentation/',
    'Import-Policy: domain darf nicht auf presentation zeigen',
  ),
];

/// Gate 1: kein Supabase unterhalb von presentation.
///
/// Gate 1 nennt `features/**/presentation`. Geprüft wird trotzdem jedes
/// `presentation`-Segment unterhalb von `lib/` (siehe [_presentationPath]).
/// Ein `lib/shared/presentation/` ist dieselbe Schicht mit derselben Regel,
/// und ein Muster, das nur innerhalb von Features greift, würde diesen Fall
/// stillschweigend erlauben.
const _presentationBans = <Ban>[
  Ban(
    r'^package:supabase',
    'Regel 5: Presentation darf Supabase nicht direkt aufrufen',
  ),
  Ban(
    r'^package:sqflite',
    'Regel 6: Presentation darf lokale Datenbank nicht direkt aufrufen',
  ),
];

const _applicationBans = <Ban>[
  Ban(r'^package:flutter/', 'Application bleibt frei von Flutter'),
  Ban(r'^package:supabase', 'Application spricht nicht mit Vendor-SDKs'),
  Ban(
    r'/data/',
    'Application kennt nur Domain-Verträge, keine data-Implementierung',
  ),
  Ban(r'/presentation/', 'Application zeigt nicht auf presentation'),
];

const _dataBans = <Ban>[
  Ban(
    r'/presentation/',
    'Import-Policy: data darf nicht auf presentation zeigen',
  ),
];

/// Regel 11: core kennt keine Feature-Domäne.
const _coreBans = <Ban>[
  Ban(
    r'^package:fact_app/features/',
    'Regel 11: core darf keine Feature-Domäne kennen',
  ),
  Ban(r'^package:supabase', 'core bleibt vendorfrei'),
];

/// `dart:developer` ist ein Grenzfall. Gate 9 nennt wörtlich nur `print()`,
/// und `log()` ist in einer Debug-Sitzung ein legitimes Werkzeug. Trotzdem
/// soll der Logging-Vertrag aus core die einzige Ausgabe im Feature-Code sein.
/// Deshalb Hinweis statt Verstoß: die Meldung erinnert an den Vertrag,
/// blockiert aber keinen Merge, für den es keine dokumentierte Regel gibt.
const _featureBans = <Ban>[
  Ban(
    r'^dart:developer',
    'Logging-Vertrag: dart:developer umgeht die Logging-Schnittstelle aus '
        'core. Wenn das bleiben soll, gehört es in einen ADR',
    severity: Severity.hinweis,
  ),
];

/// Gate 7: ADR-005 verbietet ein zweites DI-System, projektweit.
const _globalBans = <Ban>[
  Ban(r'^package:get_it', 'ADR-005: GetIt ist ausgeschlossen'),
  Ban(r'^package:injectable', 'ADR-005: injectable ist ausgeschlossen'),
];

// Schichtmuster
// -------------
// Eine Schicht wird an einem Pfadsegment erkannt, das genau `domain`,
// `application`, `presentation` oder `data` heißt. Zwischen dem Feature und
// der Schicht darf beliebige Struktur liegen, deshalb `(?:[^/]+/)*`:
// `lib/features/tours/karte/domain/entities/x.dart` ist Domäne des Features
// `tours`. Vorher verlangten die Muster die Schicht direkt unter dem Feature,
// womit eine Unterstruktur aus allen Mustern fiel und Gate 2, 3 und 6 dort
// wirkungslos waren.
//
// Weil `[^/]+` kein `/` überqueren kann, steht die Position vor `domain/`
// immer direkt hinter einem Schrägstrich. Das Segment muss also exakt `domain`
// lauten: `presentation/domain_helpers/` und `tours/subdomain/` treffen
// bewusst nicht.

/// Domäne eines Features, auch unterhalb einer Unterstruktur.
final _domainPath = RegExp(r'^lib/features/[^/]+/(?:[^/]+/)*domain/');

/// Application-Schicht eines Features, auch unterhalb einer Unterstruktur.
final _applicationPath = RegExp(r'^lib/features/[^/]+/(?:[^/]+/)*application/');

/// Data-Schicht eines Features, auch unterhalb einer Unterstruktur.
final _dataPath = RegExp(r'^lib/features/[^/]+/(?:[^/]+/)*data/');

final _layers = <LayerRule>[
  LayerRule(name: 'domain', pathMatch: _domainPath, bans: _domainBans),
  LayerRule(
    name: 'application',
    pathMatch: _applicationPath,
    bans: _applicationBans,
  ),
  LayerRule(
    name: 'presentation',
    pathMatch: _presentationPath,
    bans: _presentationBans,
  ),
  LayerRule(name: 'data', pathMatch: _dataPath, bans: _dataBans),
  LayerRule(name: 'core', pathMatch: RegExp(r'^lib/core/'), bans: _coreBans),
  LayerRule(
    name: 'features',
    pathMatch: RegExp(r'^lib/features/'),
    bans: _featureBans,
  ),
  // Gate 7 gilt projektweit, nicht nur im Produktionscode. Ein GetIt-Container
  // in einem Test, einem Integrationstest oder einem Werkzeugskript ist
  // derselbe Regelbruch.
  LayerRule(
    name: 'projektweit',
    pathMatch: RegExp(r'^(?:lib|test|integration_test|tool)/'),
    bans: _globalBans,
  ),
];

/// Verzeichnisse, die eingelesen werden.
///
/// In `lib/` laufen alle Prüfungen. In `test/`, `integration_test/` und
/// `tool/` greifen nur die Import-Verbote, deren Schichtmuster dort passt,
/// praktisch also Gate 7. Bewusst ausgenommen sind dort die Prüfungen auf
/// Ausgabe und Navigation: Werkzeugskripte dürfen `dart:io` benutzen und auf
/// die Konsole schreiben (dieses Skript selbst tut das), und Widget-Tests
/// navigieren legitim.
///
/// `integration_test/` steht mit in der Liste, weil Gate 7 projektweit gilt.
/// Das Verzeichnis existiert derzeit nicht, ein fehlendes Verzeichnis wird
/// beim Einlesen übersprungen.
const _scannedDirectories = <String>['lib', 'test', 'integration_test', 'tool'];

/// Geschäftsbegriffe, die laut Regel 11 nicht in core auftauchen dürfen.
const _forbiddenCoreConcepts = <String>[
  'fact',
  'tour',
  'challenge',
  'collection',
  'profile',
  'progression',
  'puzzle',
  'city',
];

/// Verzeichnis, in dem Route-Strings und die Navigator-API erlaubt sind
/// (ADR-004: Routing-Infrastruktur).
const _routingHome = 'lib/app/routing/';

/// Presentation-Schicht, überall unterhalb von `lib/`.
///
/// Bewusst nicht an `features/` gebunden: `lib/shared/presentation/` ist
/// dieselbe Schicht, und Gate 1 dort nicht greifen zu lassen wäre eine Lücke,
/// die keine Regel deckt. Wie bei den übrigen Schichtmustern zählt ein Segment,
/// das exakt `presentation` heißt.
final _presentationPath = RegExp(r'^lib/(?:[^/]+/)*presentation/');

/// Gate 8: rohe Navigation mit einem Route-String.
/// Trifft `context.go('/x')`, `.push('/x')`, `.goNamed('x')` und die Varianten
/// über `GoRouter.of(context)`.
///
/// Bewusst nicht erfasst: `.go(pathVariable)` mit einer Variable statt einem
/// Literal. Genau so sieht ADR-004-konformer Code aus, weil die typisierte
/// Route den Pfad liefert. Ein Verbot würde also korrekten Code melden.
final _rawNavPattern = RegExp(
  '\\.(?:go|push|replace|pushReplacement|goNamed|pushNamed|'
  'replaceNamed|pushReplacementNamed)\\s*\\(\\s*[\'"]',
);

/// Gate 8 und ADR-004: die rohe Navigator-API umgeht go_router vollständig.
/// ADR-004 hat "Navigator API directly" ausdrücklich verworfen. Erfasst jeden
/// statischen Zugriff auf `Navigator`, also `Navigator.of(context).push(...)`,
/// `Navigator.push`, `Navigator.pushNamed` und die übrigen.
final _navigatorApiPattern = RegExp(
  r'(?<![\w$.])Navigator\s*\.\s*[A-Za-z_]\w*',
);

/// Gate 9: Ausgabe im Produktionscode.
///
/// Erfasst `print(...)`, `debugPrint(...)` und die Tear-off-Form ohne Klammern
/// (`final f = print;`). `debugPrint` steht mit drin, weil Gate 9 sonst zwar
/// buchstabengetreu erfüllt, als Logging-Disziplin aber wirkungslos ist.
final _printPattern = RegExp(r'(?<![\w$.])(?:print|debugPrint)(?![\w$])');

/// Regel 7: ein Konstruktoraufruf eines Namens, der auf Repository, DataSource
/// oder Client endet. Typannotationen und Provider-Deklarationen treffen das
/// Muster nicht, weil dort keine öffnende Klammer direkt hinter dem Namen
/// steht.
final _instantiationPattern = RegExp(
  r'(?<![\w$.])(_?[A-Z]\w*(?:Repository|DataSource|Client))\s*\(',
);

/// Regel 12: Deklaration einer Notifier-Ableitung. Trifft
/// `extends Notifier<T>`, `extends AsyncNotifier<T>`, `extends StateNotifier<T>`
/// und die generierte Form `extends _$FooNotifier`.
final _notifierDeclarationPattern = RegExp(
  r'(?<![\w$])class\s+[\w$]+[^{;]*?\bextends\s+[\w$]*Notifier\b',
);

/// Regel 12: Navigationsaufruf, unabhängig davon, ob der Pfad ein Literal ist.
/// In einem Notifier ist auch die typisierte Navigation falsch, deshalb ist
/// dieses Muster breiter als `_rawNavPattern`.
final _navigationSignalPattern = RegExp(
  r'(?<![\w$.])(?:context|Navigator|GoRouter|router|_router)\s*\.\s*'
  r'(?:of\s*\(|(?:go|goNamed|push|pushNamed|pushReplacement|'
  r'pushReplacementNamed|replace|replaceNamed|pop|maybePop|popUntil)\b)',
);

/// Regel 13: Typen, die in einem Repository-Vertrag nichts zu suchen haben.
final _contractBans = <RegExp, String>{
  RegExp(r'Map\s*<\s*String\s*,\s*dynamic\s*>'):
      'Regel 13: Repository-Vertrag liefert keine JSON-Map, sondern ein '
      'Domain-Modell',
  RegExp(r'(?<![\w$.])AsyncValue\b'):
      'Regel 13: Repository-Vertrag liefert kein AsyncValue, das ist '
      'Presentation-Zustand',
  RegExp(r'(?<![\w$.])_?[A-Z]\w*Dto\b'):
      'Regel 13: Repository-Vertrag kennt keine DTOs, DTOs bleiben in data',
};

final _featurePattern = RegExp(r'^lib/features/([^/]+)/');
final _crossFeaturePattern = RegExp(
  r'package:fact_app/features/([^/]+)/(presentation|data)/',
);

/// Findet Direktiven am Zeilenanfang im strukturellen Quelltext. Das
/// URI-Literal darf in einer anderen Zeile stehen, deshalb wird ab hier bis
/// zum Semikolon gelesen (siehe [SourceView.directives]).
final _directivePattern = RegExp(
  r'^[ \t]*(?:import|export)\b',
  multiLine: true,
);

class Violation {
  const Violation({
    required this.file,
    required this.line,
    required this.detail,
    required this.rule,
    this.severity = Severity.verstoss,
  });

  final String file;
  final int line;
  final String detail;
  final String rule;
  final Severity severity;

  @override
  String toString() =>
      '$file:$line\n    gefunden: $detail\n    verletzt: $rule';
}

// ---------------------------------------------------------------------------
// Quelltext-Aufbereitung
// ---------------------------------------------------------------------------

/// Ein halboffener Bereich im Quelltext.
class SourceRange {
  const SourceRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int offset) => offset >= start && offset < end;
}

/// Ein String-Literal samt Inhalt.
class StringLiteral extends SourceRange {
  const StringLiteral(super.start, super.end, this.value);

  /// Inhalt zwischen den Anführungszeichen, unverändert übernommen.
  final String value;
}

/// Eine `import`- oder `export`-Direktive mit allen ihren URI-Literalen.
/// Ein bedingter Import hat zwei, deshalb eine Liste.
class Directive {
  const Directive(this.uris);

  final List<StringLiteral> uris;
}

/// Derselbe Quelltext in zwei Sichten plus die Stellen der String-Literale.
///
/// Der Grund: Gate 8 zielt genau auf String-Literale, ein Treffer in einem
/// Kommentar ist aber ein Fehlalarm. Ganze Zeilen zu überspringen, wenn sie
/// wie ein Kommentar aussehen, hat beides falsch gemacht. Deshalb wird der
/// Quelltext einmal überflogen und danach gezielt gefragt.
class SourceView {
  SourceView._(
    this.source,
    this.withoutComments,
    this.codeOnly,
    this._literals,
    this._interpolations,
    this._lineStarts,
  );

  factory SourceView.parse(String source) => _Masker(source).run();

  /// Unveränderter Quelltext, nur für Meldungstexte.
  final String source;

  /// Kommentare durch Leerzeichen ersetzt, String-Literale erhalten.
  /// Grundlage der Musterprüfungen.
  final String withoutComments;

  /// Zusätzlich sind String-Inhalte ersetzt. Grundlage für Struktursuchen, bei
  /// denen ein Semikolon oder eine Klammer in einem Literal stören würde.
  final String codeOnly;

  final List<StringLiteral> _literals;
  final List<SourceRange> _interpolations;
  final List<int> _lineStarts;
  List<Directive>? _directiveCache;

  /// Alle `import`- und `export`-Direktiven der Datei.
  ///
  /// Gelesen wird vom Schlüsselwort bis zum Semikolon, damit mehrzeilige
  /// Direktiven und bedingte Importe vollständig erfasst sind. Jedes
  /// URI-Literal zählt, nicht nur das erste.
  List<Directive> get directives => _directiveCache ??= _findDirectives();

  List<Directive> _findDirectives() {
    final result = <Directive>[];
    for (final match in _directivePattern.allMatches(codeOnly)) {
      final end = codeOnly.indexOf(';', match.end);
      if (end < 0) {
        continue;
      }
      final uris = _literals
          .where((l) => l.start >= match.start && l.start < end)
          .toList();
      if (uris.isNotEmpty) {
        result.add(Directive(uris));
      }
    }
    return result;
  }

  /// 1-basierte Zeilennummer einer Position.
  int lineAt(int offset) {
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + 1;
  }

  /// Die Originalzeile einer Position, ohne Rand-Leerzeichen.
  String lineText(int offset) {
    final index = lineAt(offset) - 1;
    final start = _lineStarts[index];
    final end = index + 1 < _lineStarts.length
        ? _lineStarts[index + 1]
        : source.length;
    return source.substring(start, end).trim();
  }

  /// Liegt die Position im Inhalt eines String-Literals? Der Code in einer
  /// Interpolation zählt nicht dazu, dort steht echter Code.
  bool insideLiteral(int offset) {
    if (!_literals.any((l) => l.contains(offset))) {
      return false;
    }
    return !_interpolations.any((r) => r.contains(offset));
  }

  /// Alle Treffer eines Musters, ohne die in Kommentaren und String-Literalen.
  Iterable<RegExpMatch> matches(RegExp pattern, {SourceRange? within}) {
    return pattern
        .allMatches(withoutComments)
        .where((m) => !insideLiteral(m.start))
        .where((m) => within == null || within.contains(m.start));
  }
}

const int _space = 0x20;
const int _lf = 0x0a;
const int _cr = 0x0d;

/// Überfliegt den Quelltext einmal und blendet Kommentare und String-Inhalte
/// aus. Bewusst kein echter Parser: das Skript darf keine Pakete brauchen,
/// `analyzer` wäre eine Entscheidung der Stufe 3.
class _Masker {
  _Masker(this.source)
    : _withoutComments = List<int>.of(source.codeUnits),
      _codeOnly = List<int>.of(source.codeUnits);

  final String source;
  final List<int> _withoutComments;
  final List<int> _codeOnly;
  final List<StringLiteral> _literals = <StringLiteral>[];
  final List<SourceRange> _interpolations = <SourceRange>[];

  SourceView run() {
    _scanCode(0, inInterpolation: false);
    final lineStarts = <int>[0];
    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == _lf) {
        lineStarts.add(i + 1);
      }
    }
    return SourceView._(
      source,
      String.fromCharCodes(_withoutComments),
      String.fromCharCodes(_codeOnly),
      _literals,
      _interpolations,
      lineStarts,
    );
  }

  /// Zeilenumbrüche bleiben stehen, damit Zeilennummern und `^` in Mustern
  /// weiter stimmen.
  void _blank(List<int> buffer, int index) {
    final unit = source.codeUnitAt(index);
    if (unit != _lf && unit != _cr) {
      buffer[index] = _space;
    }
  }

  void _blankBoth(int index) {
    _blank(_withoutComments, index);
    _blank(_codeOnly, index);
  }

  /// Läuft über Code. Steht [inInterpolation], endet der Lauf an der
  /// schließenden Klammer der Interpolation und gibt deren Index zurück.
  int _scanCode(int start, {required bool inInterpolation}) {
    var i = start;
    var braces = 0;
    while (i < source.length) {
      final c = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';
      if (c == '/' && next == '/') {
        i = _scanLineComment(i);
        continue;
      }
      if (c == '/' && next == '*') {
        i = _scanBlockComment(i);
        continue;
      }
      if (c == "'" || c == '"') {
        i = _scanString(i, i, raw: false);
        continue;
      }
      if (c == 'r' && (next == "'" || next == '"')) {
        i = _scanString(i, i + 1, raw: true);
        continue;
      }
      if (inInterpolation) {
        if (c == '{') {
          braces++;
        } else if (c == '}') {
          if (braces == 0) {
            return i;
          }
          braces--;
        }
      }
      i++;
    }
    return i;
  }

  int _scanLineComment(int start) {
    var i = start;
    while (i < source.length && source[i] != '\n') {
      _blankBoth(i);
      i++;
    }
    return i;
  }

  /// Dart erlaubt geschachtelte Blockkommentare, deshalb die Tiefe.
  int _scanBlockComment(int start) {
    var i = start;
    var depth = 0;
    while (i < source.length) {
      if (source.startsWith('/*', i)) {
        depth++;
        _blankBoth(i);
        _blankBoth(i + 1);
        i += 2;
        continue;
      }
      if (source.startsWith('*/', i)) {
        depth--;
        _blankBoth(i);
        _blankBoth(i + 1);
        i += 2;
        if (depth <= 0) {
          return i;
        }
        continue;
      }
      _blankBoth(i);
      i++;
    }
    return i;
  }

  /// Liest ein String-Literal ab [literalStart] (also inklusive eines `r`) mit
  /// dem Anführungszeichen an [quoteAt] und merkt es sich als Literal.
  int _scanString(int literalStart, int quoteAt, {required bool raw}) {
    final quote = source[quoteAt];
    final terminator = source.startsWith(quote * 3, quoteAt)
        ? quote * 3
        : quote;
    final multiline = terminator.length == 3;
    var i = quoteAt + terminator.length;
    for (var k = literalStart; k < i; k++) {
      _blank(_codeOnly, k);
    }
    final content = StringBuffer();

    while (i < source.length) {
      if (!multiline && source[i] == '\n') {
        // Unbeendetes einzeiliges Literal. In gültigem Dart gibt es das nicht,
        // hier bricht der Lauf ab, statt den Rest der Datei auszublenden.
        break;
      }
      if (!raw && source[i] == r'\' && i + 1 < source.length) {
        _blank(_codeOnly, i);
        _blank(_codeOnly, i + 1);
        content.write(source.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (!raw && source.startsWith(r'${', i)) {
        _blank(_codeOnly, i);
        _blank(_codeOnly, i + 1);
        var close = _scanCode(i + 2, inInterpolation: true);
        _interpolations.add(SourceRange(i + 2, close));
        if (close < source.length) {
          _blank(_codeOnly, close);
          close += 1;
        }
        content.write(source.substring(i, close));
        i = close;
        continue;
      }
      if (source.startsWith(terminator, i)) {
        for (var k = 0; k < terminator.length; k++) {
          _blank(_codeOnly, i + k);
        }
        i += terminator.length;
        _literals.add(StringLiteral(literalStart, i, content.toString()));
        return i;
      }
      _blank(_codeOnly, i);
      content.write(source[i]);
      i++;
    }
    _literals.add(StringLiteral(literalStart, i, content.toString()));
    return i;
  }
}

// ---------------------------------------------------------------------------
// Ablauf
// ---------------------------------------------------------------------------

void main() {
  if (!Directory('lib').existsSync()) {
    stderr.writeln('lib/ nicht gefunden. Aus der Projektwurzel aufrufen.');
    exit(2);
  }

  final files = <File>[];
  for (final name in _scannedDirectories) {
    final directory = Directory(name);
    if (!directory.existsSync()) {
      continue;
    }
    files.addAll(
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    );
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  final violations = <Violation>[];
  for (final file in files) {
    final posixPath = file.path.replaceAll(r'\', '/');
    final view = SourceView.parse(file.readAsStringSync());

    violations.addAll(_checkImports(posixPath, view));
    if (!posixPath.startsWith('lib/')) {
      continue;
    }
    violations
      ..addAll(_checkCoreConcepts(posixPath))
      ..addAll(_checkRawNavigation(posixPath, view))
      ..addAll(_checkNavigatorApi(posixPath, view))
      ..addAll(_checkOutput(posixPath, view))
      ..addAll(_checkInstantiation(posixPath, view))
      ..addAll(_checkNotifierNavigation(posixPath, view))
      ..addAll(_checkRepositoryContracts(posixPath, view));
  }

  _report(violations, files.length);
}

/// Bildet relative Importe auf ihre `package:`-Form ab.
///
/// Ohne das greifen die Schicht- und Feature-Verbote nur bei einer von zwei
/// gleichwertigen Schreibweisen, und `import '../../challenges/data/x.dart'`
/// wäre eine offene Tür.
String _resolveImport(String posixPath, String uri) {
  if (uri.contains(':')) {
    return uri;
  }
  final lastSlash = posixPath.lastIndexOf('/');
  final directory = lastSlash < 0 ? '' : posixPath.substring(0, lastSlash);
  final segments = <String>[];
  for (final segment in <String>[...directory.split('/'), ...uri.split('/')]) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      continue;
    }
    segments.add(segment);
  }
  final resolved = segments.join('/');
  if (resolved.startsWith('lib/')) {
    return 'package:$_packageName/${resolved.substring('lib/'.length)}';
  }
  return resolved;
}

/// Enthält [path] ein Pfadsegment, das genau [segment] heißt?
///
/// Segmentweise statt per `contains`, damit `data_sources/` nicht als `data`
/// und `domain_helpers/` nicht als `domain` durchgeht.
bool _hasSegment(String path, String segment) =>
    path.split('/').contains(segment);

/// Zeigt [resolved] in die Schicht [layer] des Features [ownFeature]?
bool _pointsIntoOwnFeatureLayer(
  String ownFeature,
  String resolved,
  String layer,
) {
  final prefix = 'package:$_packageName/features/$ownFeature/';
  if (!resolved.startsWith(prefix)) {
    return false;
  }
  return _hasSegment(resolved.substring(prefix.length), layer);
}

/// Darf die Domäne des Features [ownFeature] den Import [resolved] haben?
///
/// Erlaubt ist genau das, was die Tabelle in
/// docs/architecture/dependency-rules.md der Domäne zugesteht:
///
///  * `dart:`-Importe, also das Dart-SDK;
///  * die eigene Feature-Domäne, egal ob absolut oder relativ geschrieben
///    (relative Importe sind hier schon zu ihrer `package:`-Form aufgelöst);
///  * die geprüften reinen Dart-Pakete aus [_domainAllowedPackages].
///
/// Alles andere ist ein Verstoß. Erlaubnisliste statt Verbotsliste, weil eine
/// Verbotsliste diese Tabellenzeile strukturell nicht abbilden kann.
bool _isAllowedDomainImport(String? ownFeature, String resolved) {
  if (resolved.startsWith('dart:')) {
    return true;
  }
  if (ownFeature != null &&
      _pointsIntoOwnFeatureLayer(ownFeature, resolved, 'domain')) {
    return true;
  }
  for (final package in _domainAllowedPackages) {
    if (resolved == 'package:$package' ||
        resolved.startsWith('package:$package/')) {
      return true;
    }
  }
  return false;
}

/// Prüft alle Direktiven einer Datei gegen Schicht- und Feature-Grenzen.
List<Violation> _checkImports(String posixPath, SourceView view) {
  final found = <Violation>[];
  // Das eigene Feature ist das erste Segment hinter `features/`, unabhängig
  // von jeder Unterstruktur darunter. Daran hängt die Cross-Feature-Prüfung.
  final ownFeature = _featurePattern.firstMatch(posixPath)?.group(1);
  final activeLayers = _layers
      .where((l) => l.pathMatch.hasMatch(posixPath))
      .toList();
  final istDomaene = _domainPath.hasMatch(posixPath);
  final istPresentation = _presentationPath.hasMatch(posixPath);

  for (final directive in view.directives) {
    for (final uri in directive.uris) {
      final resolved = _resolveImport(posixPath, uri.value);
      final detail = resolved == uri.value
          ? uri.value
          : '${uri.value} (aufgelöst: $resolved)';
      final lineNo = view.lineAt(uri.start);
      var domaeneSchonGemeldet = false;

      for (final layer in activeLayers) {
        for (final ban in layer.bans) {
          if (RegExp(ban.pattern).hasMatch(resolved)) {
            if (layer.name == 'domain') {
              domaeneSchonGemeldet = true;
            }
            found.add(
              Violation(
                file: posixPath,
                line: lineNo,
                detail: detail,
                rule: '[${layer.name}] ${ban.rule}',
                severity: ban.severity,
              ),
            );
          }
        }
      }

      // Die Erlaubnisliste der Domäne fängt alles auf, was kein Verbot
      // namentlich kennt: sqflite, http, hive, aber auch
      // `package:fact_app/app/` und `package:fact_app/services/`.
      if (istDomaene &&
          !domaeneSchonGemeldet &&
          !_isAllowedDomainImport(ownFeature, resolved)) {
        found.add(
          Violation(
            file: posixPath,
            line: lineNo,
            detail: detail,
            rule:
                '[domain] Domain-Erlaubnisliste: die Domäne darf nur das '
                'Dart-SDK, die eigene Feature-Domäne und geprüfte reine '
                'Dart-Pakete importieren (dependency-rules.md, Tabelle '
                '"Allowed layer dependencies"). Technik gehört hinter einen '
                'Domain-Vertrag, also nach data oder services',
          ),
        );
      }

      if (ownFeature == null) {
        continue;
      }
      // Gate 4 und 5: fremdes presentation oder data.
      final cross = _crossFeaturePattern.firstMatch(resolved);
      if (cross != null && cross.group(1) != ownFeature) {
        final target = cross.group(1);
        final layer = cross.group(2);
        found.add(
          Violation(
            file: posixPath,
            line: lineNo,
            detail: detail,
            rule: layer == 'presentation'
                ? 'Regel 8: Feature darf presentation von "$target" nicht '
                      'importieren'
                : 'Regel 9: Feature darf data von "$target" nicht importieren',
          ),
        );
      }

      // Die Tabelle erlaubt Presentation nur Application, Domain und eng
      // abgegrenztes Core. Das eigene `data/` steht nicht in der Zeile.
      // Geprüft wird nur das eigene Feature: fremdes `data/` meldet schon
      // Regel 9, und zwei Meldungen für denselben Import helfen niemandem.
      if (istPresentation &&
          _pointsIntoOwnFeatureLayer(ownFeature, resolved, 'data')) {
        found.add(
          Violation(
            file: posixPath,
            line: lineNo,
            detail: detail,
            rule:
                'Import-Policy: presentation darf nicht auf data zeigen, auch '
                'nicht auf das eigene. Zugriff läuft über Application oder '
                'einen Domain-Vertrag',
          ),
        );
      }
    }
  }

  return found;
}

/// Regel 11: unterhalb von core darf kein Geschäftsbegriff im Pfad stehen,
/// weder im Dateinamen noch in einem Verzeichnisnamen.
List<Violation> _checkCoreConcepts(String posixPath) {
  const prefix = 'lib/core/';
  if (!posixPath.startsWith(prefix)) {
    return const [];
  }
  final relative = posixPath.substring(prefix.length);
  final tokens = relative
      .split(RegExp(r'[/_.]'))
      .where((t) => t.isNotEmpty && t != 'dart')
      .toList();

  for (final concept in _forbiddenCoreConcepts) {
    if (tokens.contains(concept) || tokens.contains('${concept}s')) {
      return [
        Violation(
          file: posixPath,
          line: 1,
          detail: relative,
          rule: 'Regel 11: core darf das Konzept "$concept" nicht besitzen',
        ),
      ];
    }
  }
  return const [];
}

/// Gate 8: ADR-004 verbietet rohe Route-Strings außerhalb von app/routing.
List<Violation> _checkRawNavigation(String posixPath, SourceView view) {
  if (posixPath.startsWith(_routingHome)) {
    return const [];
  }
  return view
      .matches(_rawNavPattern)
      .map(
        (m) => Violation(
          file: posixPath,
          line: view.lineAt(m.start),
          detail: view.lineText(m.start),
          rule:
              'ADR-004: keine rohen Route-Strings außerhalb '
              '$_routingHome, typisierte Route verwenden',
        ),
      )
      .toList();
}

/// Gate 8: die rohe Navigator-API umgeht go_router.
List<Violation> _checkNavigatorApi(String posixPath, SourceView view) {
  if (posixPath.startsWith(_routingHome)) {
    return const [];
  }
  return view
      .matches(_navigatorApiPattern)
      .map(
        (m) => Violation(
          file: posixPath,
          line: view.lineAt(m.start),
          detail: view.lineText(m.start),
          rule:
              'ADR-004: die Navigator-API umgeht go_router. Navigation läuft '
              'über eine typisierte Route, Infrastruktur nur in $_routingHome',
        ),
      )
      .toList();
}

/// Gate 9: keine direkte Ausgabe im Produktionscode.
List<Violation> _checkOutput(String posixPath, SourceView view) {
  return view
      .matches(_printPattern)
      .map(
        (m) => Violation(
          file: posixPath,
          line: view.lineAt(m.start),
          detail: view.lineText(m.start),
          rule:
              'Gate 9: kein print() oder debugPrint() im Produktionscode, '
              'Logging-Vertrag aus core verwenden',
        ),
      )
      .toList();
}

/// Regel 7: Widgets instanziieren keine Repositories oder Vendor-Clients.
///
/// Geprüft wird presentation und application. ADR-005 formuliert die Regel als
/// "Widgets/notifiers do not instantiate repositories or vendor clients", und
/// ein Notifier liegt je nach Reifegrad des Features in der einen oder der
/// anderen Schicht. Nur presentation zu prüfen hätte die Regel davon abhängig
/// gemacht, wo der Notifier gerade wohnt.
List<Violation> _checkInstantiation(String posixPath, SourceView view) {
  final String schicht;
  if (_presentationPath.hasMatch(posixPath)) {
    schicht = 'presentation';
  } else if (_applicationPath.hasMatch(posixPath)) {
    schicht = 'application';
  } else {
    return const [];
  }
  return view
      .matches(_instantiationPattern)
      .map(
        (m) => Violation(
          file: posixPath,
          line: view.lineAt(m.start),
          detail: m.group(1)!,
          rule:
              'Regel 7: $schicht instanziiert keine Repositories, '
              'DataSources oder Vendor-Clients. Abhängigkeit über einen '
              'Provider beziehen (ADR-005)',
        ),
      )
      .toList();
}

/// Regel 12: Notifier navigieren nicht.
///
/// Geprüft wird nur der Rumpf der Notifier-Klasse. Ein Widget in derselben
/// Datei darf navigieren, sonst wäre das ein Fehlalarm.
List<Violation> _checkNotifierNavigation(String posixPath, SourceView view) {
  final found = <Violation>[];
  final declarations = _notifierDeclarationPattern.allMatches(view.codeOnly);
  for (final declaration in declarations) {
    final bodyStart = view.codeOnly.indexOf('{', declaration.end);
    if (bodyStart < 0) {
      continue;
    }
    final body = SourceRange(
      bodyStart,
      _matchingBrace(view.codeOnly, bodyStart),
    );
    for (final m in view.matches(_navigationSignalPattern, within: body)) {
      found.add(
        Violation(
          file: posixPath,
          line: view.lineAt(m.start),
          detail: view.lineText(m.start),
          rule:
              'Regel 12: Notifier navigieren nicht. Navigation gehört in die '
              'Presentation, die auf den Zustand reagiert (ADR-004)',
        ),
      );
    }
  }
  return found;
}

/// Findet die schließende Klammer zu der öffnenden bei [openIndex].
int _matchingBrace(String codeOnly, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < codeOnly.length; i++) {
    final c = codeOnly[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }
  return codeOnly.length;
}

/// Regel 13: Repository-Verträge liefern keine DTOs, JSON-Maps oder AsyncValue.
List<Violation> _checkRepositoryContracts(String posixPath, SourceView view) {
  if (!posixPath.contains('/domain/repositories/')) {
    return const [];
  }
  final found = <Violation>[];
  for (final entry in _contractBans.entries) {
    for (final m in view.matches(entry.key)) {
      found.add(
        Violation(
          file: posixPath,
          line: view.lineAt(m.start),
          detail: view.lineText(m.start),
          rule: entry.value,
        ),
      );
    }
  }
  return found;
}

void _report(List<Violation> all, int filesChecked) {
  final violations = all.where((v) => v.severity == Severity.verstoss).toList();
  final hints = all.where((v) => v.severity == Severity.hinweis).toList();

  if (violations.isEmpty) {
    stdout.writeln('Architektur-Check: $filesChecked Dateien, keine Verstöße.');
  } else {
    stdout.writeln(
      'Architektur-Check: ${violations.length} Verstoß bzw. Verstöße in '
      '$filesChecked Dateien.\n',
    );
    for (final v in violations) {
      stdout.writeln('  $v\n');
    }
  }

  if (hints.isNotEmpty) {
    stdout.writeln(
      '\n${hints.length} Hinweis bzw. Hinweise, die den Lauf nicht abbrechen:\n',
    );
    for (final h in hints) {
      stdout.writeln('  $h\n');
    }
  }

  if (violations.isEmpty && hints.isEmpty) {
    return;
  }

  stdout.writeln(
    'Regelquellen: docs/architecture/dependency-rules.md, '
    'docs/engineering/quality-gates.md, '
    'docs/decisions/adr/ADR-004-go-router-typed-navigation.md, '
    'docs/decisions/adr/ADR-005-riverpod-dependency-injection.md',
  );
  if (violations.isNotEmpty) {
    exit(1);
  }
}
