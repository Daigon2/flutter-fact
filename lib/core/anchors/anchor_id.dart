import 'package:flutter/foundation.dart' show immutable;

/// Der Name eines Ankers, also einer Stelle der Oberfläche, auf die etwas
/// zeigen kann.
///
/// ## Warum ein eigener Typ und nicht `String`
///
/// Ein Anker wird an einer Stelle angemeldet und an einer ganz anderen
/// abgefragt. Zwischen beiden liegt nichts als eine Zeichenkette, und ein
/// Tippfehler darin sieht genauso aus wie ein Anker, den es noch nicht gibt.
/// Der eigene Typ macht wenigstens die Absicht sichtbar und verhindert, dass
/// eine beliebige Zeichenkette versehentlich als Anker durchgeht.
///
/// Er beseitigt den Tippfehler nicht. Dagegen hilft nur, dass jede Kennung
/// **einmal** als `static const` bei ihrer Oberfläche steht und nie an der
/// Abfragestelle neu geschrieben wird.
///
/// ## Hier steht keine einzige konkrete Kennung
///
/// Das ist die Bedingung aus E-27 (`REBUILD_STATUS.md`) und aus Regel 11 der
/// `dependency-rules.md`: `core/anchors/` besitzt den Mechanismus, die
/// Kennungen gehören der Oberfläche, die das Widget zeichnet. `tab-wallet`
/// steht deshalb bei der Tab-Leiste in `lib/app/shell/`, `coins` bei der Karte
/// in `lib/features/discovery/presentation/`.
///
/// Das Prüfskript sichert das **nicht** ab. `_checkCoreConcepts` in
/// `tool/check_architecture.dart` zerlegt nur den Dateipfad und sieht den
/// Inhalt nie: eine Datei `lib/core/anchors/anchor_ids.dart` voller
/// Fachkennungen käme sauber durch das Gate. Hier hält die Review, nicht die
/// Maschine.
///
/// ## [value] ist der Name aus der PWA
///
/// Die Quelle schreibt ihn als `data-tour-anchor` ins DOM
/// (`02_Frontend/app/screen-tour.jsx:244`). Die Werte werden unverändert
/// übernommen, damit ein Vergleich zwischen PWA und App ohne Übersetzungstabelle
/// möglich bleibt.
/// ## Eine Menge von Kennungen kann nicht `const` sein
///
/// Dart verbietet in einem konstanten `Set` jedes Element, dessen Typ `==`
/// überschreibt (`const_set_element_not_primitive_equality`). Ein
/// `const {AnchorId('a')}` ist also kein Tippfehler-Problem, sondern schlicht
/// unmöglich. Wer eine feste Menge braucht, nimmt
/// `static final ... = Set.unmodifiable(<AnchorId>[...])`. Eine einzelne
/// Kennung bleibt `const`, und eine **leere** konstante Menge auch.
@immutable
class AnchorId {
  /// Erzeugt eine Kennung aus ihrem Namen.
  const AnchorId(this.value);

  /// Der Name des Ankers, identisch mit dem `data-tour-anchor` der PWA.
  final String value;

  @override
  bool operator ==(Object other) => other is AnchorId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AnchorId($value)';
}
