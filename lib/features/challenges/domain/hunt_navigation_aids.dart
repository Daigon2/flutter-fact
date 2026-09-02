/// Das Navigations-Gating einer Jagd-Station nach Schwierigkeitsstufe.
///
/// ## Die Regel der Quelle
///
/// `HuntPill` in `02_Frontend/app/screen-map.jsx:1044-1051` staffelt Pfeil und
/// Distanzanzeige nach der Schwierigkeit der laufenden Jagd:
///
/// ```
/// // Navigations-Gating nach Schwierigkeit — matcht die Setup-Beschreibungen:
/// //   leicht → Pfeil + Distanz immer sichtbar
/// //   mittel → Distanz immer, kein Pfeil (selbst orientieren)
/// //   schwer → nichts; reines Rätsel, Hints geben nur Text
/// ```
///
/// [HuntNavigationAids.showsArrow] und [HuntNavigationAids.showsDistance]
/// bilden genau diese Tabelle ab. Was mit einer sichtbaren Distanz oder einem
/// sichtbaren Pfeil dann geschieht (die Peilung berechnen, den Pfeil zeichnen)
/// ist Sache der Oberfläche und eines späteren Schritts; diese Datei sagt nur,
/// **ob** überhaupt navigiert werden darf.
///
/// ## Der Fall ohne bekannte Stufe
///
/// Die Quelle liest die Stufe mit `const diff = (activeHunt &&
/// activeHunt.difficulty) || 'mittel';` (`:1049`). Eine **fehlende** Stufe
/// verhält sich für das Navigations-Gating also wie `mittel`, und
/// [HuntNavigationAids.forDifficulty] setzt das für `null` fort.
///
/// Das ist **kein** Widerspruch zu `PuzzleDifficulty`s eigener Regel „kein
/// Standardwert": jener Kommentar verbietet einen Ersatzwert im **geteilten
/// Kern**, weil dort mehrere Domänen mit unterschiedlichen Antworten säßen
/// (`puzzle-sheet.jsx:92` nimmt `mittel`, der alte Flutter-Port nahm
/// `leicht`, beides für die Münz-Berechnung). Hier ist genau der Ort, an den
/// diese Entscheidung laut jenem Kommentar gehört: `challenges/domain`, für
/// **eine** konkrete Frage, das Navigations-Gating, und für keine andere. Der
/// Ersatzwert hier sagt nichts über eine Belohnung; das ist eine eigene
/// Frage, die `puzzles` und `progression` beantworten, wenn sie ihn brauchen,
/// und mit eigenem Recht auf eine andere Antwort.
library;

import 'package:fact_app/kernel/puzzle_difficulty.dart';

/// Welche Navigationshilfen eine Jagd-Station nach ihrer Schwierigkeit zeigt.
final class HuntNavigationAids {
  const HuntNavigationAids._({
    required this.showsArrow,
    required this.showsDistance,
  });

  /// Ob ein Richtungspfeil zur Station gezeigt wird.
  ///
  /// Nur bei `leicht`. Der Pfeil selbst (Index oder Glyphe) kommt aus
  /// `huntArrowIndexFor` in `hunt_arrow.dart`; dieses Feld sagt nur, ob er
  /// überhaupt eingeblendet werden darf.
  final bool showsArrow;

  /// Ob die Entfernung zur Station gezeigt wird.
  ///
  /// Bei `leicht` und `mittel`, nicht bei `schwer`.
  final bool showsDistance;

  /// `leicht`: Pfeil und Distanz.
  static const HuntNavigationAids _leicht = HuntNavigationAids._(
    showsArrow: true,
    showsDistance: true,
  );

  /// `mittel`: nur Distanz, kein Pfeil, selbst orientieren.
  static const HuntNavigationAids _mittel = HuntNavigationAids._(
    showsArrow: false,
    showsDistance: true,
  );

  /// `schwer`: nichts, reines Rätsel.
  static const HuntNavigationAids _schwer = HuntNavigationAids._(
    showsArrow: false,
    showsDistance: false,
  );

  /// Die Navigationshilfen für [difficulty].
  ///
  /// `null` (keine bekannte Stufe) verhält sich wie [PuzzleDifficulty.mittel],
  /// siehe die Begründung am Bibliothekskopf. Das gilt **nur** hier, für das
  /// Navigations-Gating, und für keine andere Frage.
  ///
  /// Liefert eine der drei vorgefertigten `const`-Instanzen statt jedes Mal
  /// neu zu bauen. Es gibt genau drei mögliche Ergebnisse, sie sind
  /// unveränderlich, und `const` macht zwei Aufrufe mit derselben Stufe zu
  /// `identical`, ohne dass diese Klasse deshalb `==` weglassen dürfte: ein
  /// Aufrufer, der sich selbst eine Instanz baut (was der private Konstruktor
  /// verhindert) oder über einen anderen Weg an ein scheinbar gleiches Objekt
  /// kommt, verlässt sich sonst auf `identical` statt auf Wertgleichheit, und
  /// das wäre eine stille Kopplung an diese Umsetzung.
  static HuntNavigationAids forDifficulty(PuzzleDifficulty? difficulty) {
    switch (difficulty ?? PuzzleDifficulty.mittel) {
      case PuzzleDifficulty.leicht:
        return _leicht;
      case PuzzleDifficulty.mittel:
        return _mittel;
      case PuzzleDifficulty.schwer:
        return _schwer;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is HuntNavigationAids &&
      other.showsArrow == showsArrow &&
      other.showsDistance == showsDistance;

  @override
  int get hashCode => Object.hash(showsArrow, showsDistance);

  @override
  String toString() =>
      'HuntNavigationAids(arrow: $showsArrow, distance: $showsDistance)';
}
