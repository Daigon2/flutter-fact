import 'dart:async';

import 'package:flutter/foundation.dart';

/// Startet [work], wartet nicht darauf, und **meldet** einen Fehler daraus.
///
/// ## Warum es das gibt
///
/// `docs/engineering/flutter.md:151` verlangt beides: "Detached work must use an
/// explicit helper **and error reporting**." Ein `unawaited(...)` allein erfüllt
/// nur die erste Hälfte. Der Fehler landet dann in der Zone, wird von niemandem
/// gelesen, und im Release-Build ist er vollständig weg.
///
/// Der Fall, um den es geht, ist der Schreibvorgang hinter einer Präferenz:
/// die Oberfläche folgt sofort, gespeichert wird im Hintergrund. Scheitert das
/// Speichern, ist der Zustand im Speicher richtig und auf der Platte falsch.
/// Ohne Meldung merkt das niemand, bis der Nutzer die App neu startet und seine
/// Einstellung weg ist. Genau diese Lücke war in `splash_page.dart` und im
/// Audio-Dialog offen.
///
/// ## Was es ausdrücklich nicht tut
///
/// - **Es unterdrückt nichts.** Der Fehler wird gemeldet, nicht geschluckt
///   (`docs/engineering/flutter.md:88`: Widgets dürfen Fehler nicht still
///   verschlucken). Im Test schlägt der Lauf dadurch fehl, was gewollt ist.
/// - **Es wiederholt nicht.** "Never retry indefinitely" (§7). Wer einen
///   Wiederholungsversuch braucht, baut ihn dort, wo die Bedeutung des Fehlers
///   bekannt ist.
/// - **Es entscheidet nicht, wie es dem Nutzer gezeigt wird.** Ob ein
///   fehlgeschlagenes Speichern eine Meldung verdient, hängt am Aufrufer.
///
/// ## Warum `FlutterError.reportError` und nicht `DiagnosticSink`
///
/// `DiagnosticSink` aus `core/diagnostics` nimmt **erwartete** technische
/// Ereignisse mit Namen und Kennwerten. Hier geht es um eine unerwartete
/// Ausnahme mit Stapelspur, also um denselben Kanal, in dem auch ein Fehler aus
/// `build` landet. `FlutterError.onError` ist dieser Kanal: in Tests bricht er
/// den Lauf ab, und ein späteres Crash-Reporting hängt sich an genau dieser
/// Stelle ein, ohne dass ein Aufrufer angefasst wird. Ein zweiter Weg für
/// Ausnahmen wäre ein zweiter Ort, an dem man nachsehen muss.
///
/// Der Helfer liegt in `core`, weil ihn drei Aufrufer in zwei Features brauchen
/// und er keinen Fachbegriff kennt (Regel 11). Er nimmt bewusst kein
/// `BuildContext` und keinen `Ref`: sonst wäre er nicht in einem Notifier oder
/// einem Service verwendbar.
///
/// [origin] benennt die Aufrufstelle, punktiert und stabil, etwa
/// `settings.audio_mode.enable`. Er steht in der Fehlermeldung und ist das
/// einzige, woran man später erkennt, welcher der abgekoppelten Vorgänge
/// gescheitert ist. Deshalb verpflichtend.
void reportDetached(Future<void> work, {required String origin}) {
  // `then` mit `onError` und nicht `catchError`: so bleibt der statische Typ
  // erhalten, und die Stapelspur kommt als zweites Argument mit, statt aus
  // einem `dynamic`-Aufruf rekonstruiert werden zu müssen ("Preserve stack
  // traces", ENG-FLUTTER §7).
  unawaited(
    work.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'fact_app',
            context: ErrorDescription('in abgekoppelter Arbeit aus "$origin"'),
          ),
        );
      },
    ),
  );
}
