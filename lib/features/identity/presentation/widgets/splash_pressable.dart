import 'package:flutter/widgets.dart';

/// Ein antippbarer Bereich mit Knopf-Semantik, ohne eigenes Aussehen.
///
/// Die Knöpfe des Startbildschirms sind in der Quelle `<button>`-Elemente mit
/// vollständig eigenem Inline-Stil. Material-Knöpfe brächten Ripple, Elevation
/// und eine eigene Farbrolle mit, die hier alle wieder abgeschaltet werden
/// müssten. Deshalb Gestenerkennung plus [Semantics] und die Optik am Aufrufer.
///
/// Ohne [Semantics] wäre der Knopf für Screenreader ein Textblock. Das ist die
/// Rolle, die `<button>` in der Quelle mitbringt, und sie darf beim Portieren
/// nicht verlorengehen.
class SplashPressable extends StatelessWidget {
  /// [semanticLabel] entspricht `aria-label`. Ist er gesetzt, ersetzt er den
  /// Inhalt für Screenreader, so wie `aria-label` es in HTML tut.
  ///
  /// [selected] macht einen Auswahlzustand ansagbar. `null` heißt "dieser Knopf
  /// hat keinen Auswahlzustand", nicht "nicht ausgewählt".
  const SplashPressable({
    required this.onPressed,
    required this.child,
    this.semanticLabel,
    this.selected,
    super.key,
  });

  /// Was beim Tippen passiert.
  final VoidCallback onPressed;

  /// Die Optik des Knopfes.
  final Widget child;

  /// Ersatztext für Screenreader, `aria-label`.
  final String? semanticLabel;

  /// Ob dieser Knopf der ausgewählte einer Gruppe ist, oder `null`, wenn es
  /// keine Auswahl gibt.
  ///
  /// **Bewusst über die Quelle hinaus.** Die Sprachkarten in
  /// `screen-auth.jsx:340-356` zeigen ihren Zustand ausschließlich über Farbe,
  /// Rahmen und Ring; ein `aria-selected` gibt es dort nicht. Für einen
  /// Screenreader ist die Auswahl damit unsichtbar, und wer die App so bedient,
  /// kann nicht feststellen, welche Sprache gerade aktiv ist. Der Zustand hier
  /// ändert nichts Sichtbares, also auch nichts an der Parität, und der
  /// Kopfhörer-Knopf hat sein Label aus derselben Quelle bekommen.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      label: semanticLabel,
      selected: selected,
      // `aria-label` überschreibt den Inhalt, statt ihn zu ergänzen.
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        // Ohne das ist der durchsichtige Innenabstand des Knopfes nicht
        // antippbar.
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: child,
      ),
    );
  }
}
