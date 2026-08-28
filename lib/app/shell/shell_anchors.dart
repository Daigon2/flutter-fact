import 'package:fact_app/core/anchors/anchor_id.dart';

/// Anker der App-Shell, die keinem einzelnen Tab gehören.
///
/// Die Kennungen der vier Tabs stehen bei `ShellTab`, weil sie zu je einem
/// Knopf gehören. Was hier steht, gehört der Shell als Ganzes.
///
/// ## Warum es diesen Anker gibt, obwohl die PWA ihn nicht kennt
///
/// Er ist **kein Ziel des Tutorials**. `screen-tour.jsx` zeigt nie auf die
/// Leiste als Ganzes, und `chrome.jsx` setzt dort auch kein
/// `data-tour-anchor`. Er ist eine Messstelle: das untere Tutorial-Chrome
/// (Punktreihe und Tipp-Hinweis) liegt seit der Entscheidung vom 28.08.2026
/// **über** der Leiste, und wie hoch die Leiste ist, hängt von der
/// Systemschriftgröße ab. Gemessen am 28.08.2026: 64 Pixel Pille bei
/// Skalierung 1.0, 94 bei 2.0, weil die Beschriftung "Challenge" dann
/// zweizeilig wird.
///
/// Die Anker-Registry ist im Projekt der vorhandene Weg, das Rechteck eines
/// fremden Widgets zu erfragen, ohne dass eines der beiden das andere kennt.
/// Ein zweiter Mechanismus dafür wäre dieselbe Sache noch einmal.
abstract final class ShellAnchors {
  /// Der untere Rahmen der Shell: Mini-Player-Platz und schwebende Tab-Leiste.
  ///
  /// Bewusst der ganze Rahmen und nicht nur die Leiste: gewinnt der
  /// Mini-Player in Phase 3 seine Höhe, weicht das Tutorial-Chrome ihm ohne
  /// weitere Änderung aus.
  static const AnchorId bottomBar = AnchorId('shell-bottom-bar');
}
