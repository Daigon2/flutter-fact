/// Ausgabe-Vertrag für technische Ereignisse.
///
/// Warum es das gibt: `docs/engineering/quality-gates.md` Gate 9 verbietet
/// `print()` und `debugPrint()` im Produktionscode, und ein Logging-Paket wäre
/// eine Entscheidung der Stufe 3 nach `docs/ai/escalation.md`. Also steht hier
/// nur die Schnittstelle, und die Standardimplementierung tut nichts.
///
/// Regel 11 aus `docs/architecture/dependency-rules.md`: unter `core/` steht
/// kein Fachbegriff. Der Aufrufer liefert Name und Attribute als Zeichenketten,
/// dieser Vertrag kennt weder Fakt noch Rätsel noch Stadt.
///
/// `docs/architecture/cross-cutting-concerns.md`, Abschnitt Logging, verbietet
/// Tokens, private Profildaten, ganze Backend-Antworten und genaue
/// Standortspuren. Deshalb nimmt [DiagnosticEvent] ausschließlich flache
/// Zeichenketten. Wer eine Rohantwort loggen will, muss dafür erst diesen
/// Vertrag ändern, und das fällt in der Prüfung auf.
library;

/// Ein einzelnes technisches Ereignis.
///
/// [name] ist ein stabiler, punktierter Bezeichner wie
/// `facts.mapping_defects`. [attributes] trägt kurze Kennwerte, typischerweise
/// Zähler und Feldnamen.
class DiagnosticEvent {
  /// [attributes] wird kopiert und unveränderlich gemacht, damit ein Aufrufer
  /// das Ereignis nach dem Absenden nicht mehr verändern kann.
  DiagnosticEvent(this.name, [Map<String, String> attributes = const {}])
    : attributes = Map<String, String>.unmodifiable(attributes);

  /// Stabiler Bezeichner des Ereignisses.
  final String name;

  /// Kennwerte des Ereignisses, unveränderlich.
  final Map<String, String> attributes;

  @override
  String toString() => 'DiagnosticEvent($name, $attributes)';
}

/// Senke, an die technische Ereignisse gehen.
abstract interface class DiagnosticSink {
  /// Nimmt [event] an. Darf nie werfen: eine kaputte Senke ist kein Grund,
  /// den Aufrufer scheitern zu lassen.
  void report(DiagnosticEvent event);
}

/// Standardsenke: nimmt an und verwirft.
///
/// Bewusst kein Puffer und keine Ausgabe. Solange kein Ziel entschieden ist
/// (Crash-Reporting, strukturiertes Logging), ist Schweigen ehrlicher als eine
/// halbe Implementierung. Tests setzen eine eigene Senke ein.
class SilentDiagnosticSink implements DiagnosticSink {
  /// Erzeugt die stille Senke.
  const SilentDiagnosticSink();

  @override
  void report(DiagnosticEvent event) {}
}
