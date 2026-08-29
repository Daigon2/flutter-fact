import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod ist der einzige DI-Mechanismus (ADR-005). Der Provider steht neben
/// dem Vertrag, den er bereitstellt, wie `docs/architecture/project-structure.md`
/// es verlangt.

/// Aktive Diagnose-Senke.
///
/// Standard ist [SilentDiagnosticSink]. Wer eine echte Senke anschließt, legt
/// die Implementierung unter `lib/services/` ab und überschreibt diesen
/// Provider im Bootstrap. Kein Aufrufer muss dafür angefasst werden.
///
/// Seit dem 29.08.2026 gibt es diese Senke: `ConsoleDiagnosticSink` in
/// `lib/services/diagnostics/`, im Debug-Bau eingesetzt von
/// `lib/app/bootstrap.dart`. Der Standard hier bleibt trotzdem still, weil
/// `core` nichts aus `services` kennen darf und weil jeder Test, der keine
/// eigene Senke einsetzt, sonst auf die Konsole schriebe.
final diagnosticSinkProvider = Provider<DiagnosticSink>(
  (ref) => const SilentDiagnosticSink(),
);
