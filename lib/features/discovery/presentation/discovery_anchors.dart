import 'package:fact_app/core/anchors/anchor_id.dart';

/// Die Ankerkennungen des Kartenbildschirms.
///
/// ## Warum die Kennungen hier stehen und nicht in `core/anchors/`
///
/// E-27 (`REBUILD_STATUS.md`) trennt beides: `core/anchors/` besitzt den
/// Mechanismus, die Kennungen gehören der Oberfläche, die das Widget zeichnet.
/// Eine Datei `lib/core/anchors/anchor_ids.dart` mit `coins` und `compass`
/// darin käme durch Regel 11 des Prüfskripts, weil `_checkCoreConcepts` in
/// `tool/check_architecture.dart` nur den Pfad zerlegt und den Inhalt nie
/// ansieht, und würde trotzdem genau das verletzen, was E-27 verhindern soll.
///
/// ## Ein Anker gehört der Oberfläche, nicht den Daten darin
///
/// Das ist die Regel, an der [coins] hängt. Coins sind laut
/// `lib/features/README.md` fachlich Sache von `progression`. Der Anker steht
/// trotzdem hier, weil ihn der **Kartenbildschirm** zeichnet
/// (`02_Frontend/app/screen-map.jsx:708`). Anders herum bräuchte ein
/// Leuchtring einen feature-übergreifenden Vertrag darüber, wo eine fremde
/// Oberfläche gerade ihre Zahl hinlegt, und das ist ein Vertrag, den niemand
/// haben will.
///
/// ## Heute meldet keines dieser Widgets einen Anker an
///
/// Der Kartenbildschirm ist ein Platzhalter (`presentation/pages/map_page.dart`).
/// Die Kennungen stehen trotzdem schon hier, weil das Tutorial sie abfragt und
/// paritätstreu ohne Pfeil und Ring weiterzeichnen muss, statt den Schritt zu
/// überspringen (`screen-tour.jsx:244-255`). Siehe [knownMissing].
///
/// Wer in Phase 2 einen dieser Anker baut, umschließt das Widget mit
/// `AnchorTarget` **und** streicht die Kennung aus [knownMissing]. Der Test
/// `test/features/discovery/presentation/discovery_anchors_test.dart` nagelt
/// die Liste fest und schlägt dabei an.
abstract final class DiscoveryAnchors {
  /// Ein Fakt-Ballon auf der Karte.
  ///
  /// Sonderfall in der Quelle: Ballons tragen kein `data-tour-anchor`, die PWA
  /// sucht stattdessen den MapLibre-Marker, der der Rahmenmitte am nächsten
  /// liegt, und nimmt bei Fehlanzeige ein festes Ersatzrechteck
  /// (`screen-tour.jsx:193-224`). Für die App heißt das: [balloon] wird von
  /// keinem Hüllwidget angemeldet, sondern von der Kartenschicht selbst
  /// berechnet, sobald es sie gibt.
  static const AnchorId balloon = AnchorId('balloon');

  /// Der eigene Avatar-Marker.
  ///
  /// Ebenfalls ein Sonderfall der Quelle: identifiziert über die innere
  /// CSS-Klasse `.arrow-shell` statt über ein Attribut
  /// (`screen-tour.jsx:226-242`).
  static const AnchorId userMarker = AnchorId('user-marker');

  /// Die Coin-Anzeige, `screen-map.jsx:708`.
  static const AnchorId coins = AnchorId('coins');

  /// Der Knopf "Tour" im Modus-Umschalter.
  ///
  /// Die Quelle baut den Namen aus der Knopfkennung zusammen,
  /// `'mode-' + modeBtn.id` (`screen-map.jsx:3217`).
  static const AnchorId modeTour = AnchorId('mode-tour');

  /// Der Kompass-Knopf, `screen-map.jsx:3154`.
  static const AnchorId compass = AnchorId('compass');

  /// Alle fünf Kennungen in der Reihenfolge, in der das Tutorial sie abfragt.
  static const List<AnchorId> values = <AnchorId>[
    balloon,
    userMarker,
    coins,
    modeTour,
    compass,
  ];

  /// Anker, die es heute bekanntermaßen noch nicht gibt.
  ///
  /// Diese Menge geht an den `AnchorScope` in `lib/app/app.dart` und wirkt
  /// ausschließlich in Debug-`assert`s. Sie trennt den harmlosen Fall
  /// ("Widget noch nicht gebaut") vom teuren ("Kennung vertippt"), die im
  /// Ergebnis beide gleich aussehen, nämlich als `null` aus
  /// `AnchorRegistry.rectOf`.
  ///
  /// Heute sind das alle fünf. Die Menge schrumpft in Phase 2 auf leer.
  ///
  /// `final` und nicht `const`: eine konstante Menge darf keine Elemente
  /// enthalten, die `==` überschreiben (`const_set_element_not_primitive_
  /// equality`), und genau das tut [AnchorId]. `Set.unmodifiable` ersetzt die
  /// verlorene Unveränderlichkeit.
  ///
  /// Absichtlich **nicht** aus [values] abgeleitet. Beide Listen sind heute
  /// gleich und sollen es nicht bleiben: [values] bleibt vollständig, diese
  /// Menge schrumpft mit jedem gebauten Widget.
  static final Set<AnchorId> knownMissing = Set<AnchorId>.unmodifiable(
    <AnchorId>[balloon, userMarker, coins, modeTour, compass],
  );
}
