import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aufnahmeregel 4 aus ADR-008, maschinell.
///
/// ## Warum dieser Test existiert
///
/// ADR-008 stellt vier Aufnahmeregeln für den geteilten Kern auf, und nur die
/// zweite (reines Dart) prüft `tool/check_architecture.dart` als Regel 23. Die
/// unabhängige Architekturprüfung am 31.08.2026 hat daraus den richtigen Schluss
/// gezogen: **Regel 1, 3 und 4 waren Ritual und keine Kontrolle.** Nichts hätte
/// einen künftigen Commit gehindert, einen Typ in `lib/kernel/` zu legen, ohne
/// ADR-008 anzufassen.
///
/// Für **Regel 4** gibt es eine billige maschinelle Näherung, und das ist dieser
/// Test: jeder Typ, der unter `lib/kernel/` deklariert ist, muss in der
/// Inhaltstabelle von ADR-008 stehen, und jeder Eintrag der Tabelle muss es
/// geben. Damit ist das Hinzufügen eines Typs **ohne** Entscheidung ein roter
/// Test statt einer stillen Änderung.
///
/// **Was dieser Test ausdrücklich nicht prüft:** ob ein Typ in den Kern
/// *gehört*. Regel 1 (zwei Domänen brauchen ihn) und Regel 3 (kein
/// rollengebundenes Verhalten) bleiben Review-Sache, denn beide sind Aussagen
/// über Bedeutung. Wer sie maschinell prüfen wollte, bekäme eine Prüfung, die
/// „zwei Importe existieren" mit „zwei Domänen brauchen es" verwechselt, und das
/// wäre schlechter als eine offene Review-Pflicht: es sähe wie eine Kontrolle
/// aus.
///
/// ## Die Gegenrichtung ist genauso wichtig
///
/// Ein Eintrag in der Tabelle ohne Typ im Kern ist eine veraltete Tabelle, und
/// eine veraltete Tabelle ist die einzige Buchführung dieses Kopplungskanals.
/// Deshalb prüft der zweite Test sie in die andere Richtung.
void main() {
  /// Alle Typnamen, die unter `lib/kernel/` auf oberster Ebene deklariert sind.
  ///
  /// Bewusst mit einem Muster über den Quelltext und nicht mit einem Parser: der
  /// Kern ist absichtlich klein, das Muster ist an dieser Größe nachvollziehbar,
  /// und ein Parser wäre eine Abhängigkeit für eine Handvoll Dateien. Das Muster
  /// ist am Zeilenanfang verankert, damit es keine verschachtelte Deklaration
  /// und keinen Klassennamen aus einem Kommentar trifft.
  Set<String> declaredKernelTypes() {
    final RegExp declaration = RegExp(
      r'^(?:'
      r'(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*'
      r'class|enum|mixin|typedef|extension\s+type'
      r')\s+([A-Z]\w*)',
      multiLine: true,
    );
    final Set<String> found = <String>{};
    final Directory kernel = Directory('${Directory.current.path}/lib/kernel');
    for (final FileSystemEntity entity in kernel.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      for (final RegExpMatch match in declaration.allMatches(
        entity.readAsStringSync(),
      )) {
        found.add(match.group(1)!);
      }
    }
    return found;
  }

  /// Die Typnamen aus der Inhaltstabelle von ADR-008.
  ///
  /// Gelesen wird die erste Spalte jeder Tabellenzeile, die einen Namen in
  /// Rückwärtsstrichen trägt. Die Trennzeile `|---|` und die Kopfzeile fallen
  /// dadurch von selbst weg, ohne dass der Test die Tabellenform kennen muss.
  Set<String> typesNamedInAdr() {
    final String adr = File(
      '${Directory.current.path}/docs/decisions/adr/ADR-008-shared-kernel.md',
    ).readAsStringSync();
    final RegExp row = RegExp(r'^\|\s*`(\w+)`\s*\|', multiLine: true);
    return row.allMatches(adr).map((RegExpMatch m) => m.group(1)!).toSet();
  }

  test('jeder Typ im Kern steht in der Inhaltstabelle von ADR-008', () {
    final Set<String> declared = declaredKernelTypes();
    // Die Gegenprobe zur Gegenprobe: findet das Muster überhaupt etwas? Ohne
    // diese Zusicherung wäre der Test bei einem kaputten Muster grün, und zwar
    // dauerhaft und lautlos, weil eine leere Menge jede Teilmengenprüfung
    // erfüllt. Genau dieses Muster steht in „Wie Tests hier blind werden".
    expect(declared, isNotEmpty);

    expect(
      declared.difference(typesNamedInAdr()),
      isEmpty,
      reason:
          'Ein Typ liegt im geteilten Kern, ohne in ADR-008 zu stehen. '
          'Aufnahmeregel 4 verlangt, dass ein Eintrag eine Entscheidung ist '
          'und keine Datei: die Inhaltstabelle des ADR gehört in denselben '
          'Commit. Wer den Typ dort nicht rechtfertigen kann, hat die Antwort '
          'auf die Frage, ob er in den Kern gehört.',
    );
  });

  test('jeder Eintrag der Inhaltstabelle liegt wirklich im Kern', () {
    // Die andere Richtung, und sie ist nicht symmetrisch im Wert: ein Eintrag
    // ohne Typ heißt, dass die einzige Buchführung dieses Kopplungskanals
    // veraltet ist. Ein Leser, der dem ADR glaubt, plant dann mit einem Typ,
    // den es nicht gibt.
    final Set<String> named = typesNamedInAdr();
    expect(named, isNotEmpty);

    expect(
      named.difference(declaredKernelTypes()),
      isEmpty,
      reason:
          'ADR-008 nennt einen Typ, den es unter lib/kernel/ nicht gibt. '
          'Entweder ist er umbenannt oder entfernt worden, dann gehört die '
          'Tabelle nachgezogen, oder er wurde nie gebaut, dann gehört er '
          'nicht in eine Tabelle mit der Überschrift "Contents".',
    );
  });

  test('die Tabelle nennt heute genau die zwei entschiedenen Typen', () {
    // Die schärfste der drei Zusicherungen, und die einzige, die bei einem
    // gewollten Wachstum absichtlich anschlägt. Sie ist der Ort, an dem ADR-008s
    // eigener Review-Auslöser „the kernel grows past a handful of types" zuerst
    // sichtbar wird, und deshalb steht die Zahl hier und nicht nur in Prosa.
    expect(typesNamedInAdr(), <String>{'PuzzleDifficulty', 'PuzzleOperand'});
  });
}
