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
/// ## Fünf der sechs Anker sind gebaut
///
/// Seit dem Top-Chrome des Kartenbildschirms melden [coins], [modeFactFinder],
/// [modeTour] und [compass] sich über `AnchorTarget` an
/// (`presentation/widgets/map_top_chrome.dart`). Seit `discovery_balloon_anchor.dart`
/// meldet sich auch [balloon] so an, nur eben nicht über ein sichtbares
/// Hüllwidget, sondern über ein unsichtbares `AnchorTarget` an der Stelle, die
/// dieselbe Auswahlregel wie die Quelle berechnet. Übrig bleibt [userMarker];
/// er hängt an Schritt 18 und E-10, siehe [knownMissing].
///
/// Wer ihn baut, umschließt das Widget mit `AnchorTarget` **und** streicht die
/// Kennung aus [knownMissing]. Der Test
/// `test/features/discovery/presentation/discovery_anchors_test.dart` nagelt
/// die Liste fest und schlägt dabei an.
abstract final class DiscoveryAnchors {
  /// Ein Fakt-Ballon auf der Karte.
  ///
  /// Sonderfall in der Quelle: Ballons tragen kein `data-tour-anchor`, die PWA
  /// sucht stattdessen den MapLibre-Marker, der der Rahmenmitte am nächsten
  /// liegt, und nimmt bei Fehlanzeige ein festes Ersatzrechteck
  /// (`screen-tour.jsx:193-222`, selbst nachgezählt, siehe
  /// `discovery_balloon_anchor.dart`). Für die App heißt das: [balloon] wird
  /// von keinem sichtbaren Hüllwidget angemeldet, sondern von
  /// `DiscoveryBalloonAnchor`, das dieselbe Auswahlregel nachbildet und ein
  /// unsichtbares `AnchorTarget` an die berechnete Stelle setzt.
  static const AnchorId balloon = AnchorId('balloon');

  /// Der eigene Avatar-Marker.
  ///
  /// Ebenfalls ein Sonderfall der Quelle: identifiziert über die innere
  /// CSS-Klasse `.arrow-shell` statt über ein Attribut
  /// (`screen-tour.jsx:226-242`).
  static const AnchorId userMarker = AnchorId('user-marker');

  /// Die Coin-Anzeige, `screen-map.jsx:708`.
  static const AnchorId coins = AnchorId('coins');

  /// Der Knopf "Fact Finder" im Modus-Umschalter, `screen-map.jsx:3216-3217`.
  ///
  /// Das Tutorial fragt ihn **nicht** ab. Er wird trotzdem angemeldet, aus
  /// demselben Grund wie die vier Tab-Anker in `ShellTab`: der Umschalter
  /// zeichnet beide Knöpfe gleich, und eine Ausnahme für einen von zweien wäre
  /// eine Sonderregel ohne Nutzen.
  static const AnchorId modeFactFinder = AnchorId('mode-fact-finder');

  /// Der Knopf "Tour" im Modus-Umschalter.
  ///
  /// Die Quelle baut den Namen aus der Knopfkennung zusammen,
  /// `'mode-' + modeBtn.id` (`screen-map.jsx:3217`). Gemeint ist der obere
  /// Umschalter des Kartenbildschirms, **nicht** `ModeBar` aus
  /// `chrome.jsx:150-207`; die Unterscheidung steht in `map_mode.dart`.
  static const AnchorId modeTour = AnchorId('mode-tour');

  /// Der Kompass-Knopf, `screen-map.jsx:3154`.
  static const AnchorId compass = AnchorId('compass');

  /// Alle Kennungen des Kartenbildschirms.
  ///
  /// Die Reihenfolge folgt der des Tutorials (`screen-tour.jsx:140-169`);
  /// [modeFactFinder] steht dort nicht und ist deshalb vor seinem Nachbarn
  /// [modeTour] eingeschoben, wo der Umschalter ihn zeichnet.
  static const List<AnchorId> values = <AnchorId>[
    balloon,
    userMarker,
    coins,
    modeFactFinder,
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
  /// Heute ist das noch [userMarker]. Er wartet auf Schritt 18 und E-10: den
  /// Marker selbst gibt es im Code noch gar nicht, und die Quelle sucht ihn
  /// über eine innere CSS-Klasse, `.arrow-shell` (`screen-tour.jsx:226-242`).
  ///
  /// [balloon] stand hier bis `discovery_balloon_anchor.dart`: die Quelle
  /// sucht dafür den Marker nächst der Rahmenmitte
  /// (`screen-tour.jsx:193-222`), und das kann kein sichtbares Hüllwidget
  /// anmelden. `DiscoveryBalloonAnchor` löst das mit einem unsichtbaren
  /// `AnchorTarget` an der berechneten Stelle, siehe dort.
  ///
  /// [coins], [modeFactFinder], [modeTour] und [compass] stehen seit dem
  /// Top-Chrome nicht mehr hier. Löst einer von ihnen nicht auf, schlägt der
  /// `assert` in `AnchorRegistry.rectOf` an, und genau das ist gewollt.
  ///
  /// `final` und nicht `const`: eine konstante Menge darf keine Elemente
  /// enthalten, die `==` überschreiben (`const_set_element_not_primitive_
  /// equality`), und genau das tut [AnchorId]. `Set.unmodifiable` ersetzt die
  /// verlorene Unveränderlichkeit.
  ///
  /// Absichtlich **nicht** aus [values] abgeleitet: [values] bleibt
  /// vollständig, diese Menge schrumpft mit jedem gebauten Widget.
  static final Set<AnchorId> knownMissing = Set<AnchorId>.unmodifiable(
    <AnchorId>[userMarker],
  );
}
