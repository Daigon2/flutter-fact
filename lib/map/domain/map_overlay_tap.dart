/// Der Tipp auf eine Gruppe einer Überlagerung.
///
/// ## Warum das keine Wertgleichheit hat
///
/// `MapCameraIntent` begründet in seinem Kopfkommentar, Abschnitt „Warum keine
/// Absicht Wertgleichheit hat" (`map_camera_intent.dart`), warum eine Absicht
/// eine **Nachricht** ist und kein Wert: zwei GPS-Folgeabsichten mit demselben
/// Ziel, eine Sekunde auseinander abgegeben, sind zwei verschiedene
/// Ereignisse, und ein `==`, das sie gleichsetzt, lädt zur Entdopplung ein.
///
/// Genau dieselbe Begründung gilt hier. Ein Tipp auf dieselbe Stelle derselben
/// Gruppe, eine Sekunde auseinander, sind zwei Tipps und kein wiederholter:
/// der Nutzer hat zweimal angetippt, vielleicht weil beim ersten Mal nichts
/// geschah. Ein `==`, das beide für gleich hält, würde den zweiten Tipp als
/// „schon gehabt" lesen lassen, und genau das ist der Fehler, den
/// `MapCameraIntent` für Absichten ausdrücklich vermeidet. [MapOverlayGroupTap]
/// folgt derselben Regel und aus demselben Grund.
library;

import 'package:fact_app/map/domain/map_position.dart';

/// Ein Tipp auf eine Gruppe der Überlagerung [overlayId].
final class MapOverlayGroupTap {
  /// Erzeugt einen Tipp.
  const MapOverlayGroupTap({required this.overlayId, required this.position});

  /// Welche Überlagerung getroffen wurde.
  final String overlayId;

  /// Wo auf der Karte getippt wurde.
  ///
  /// **Nicht der Mittelpunkt der Gruppe**, sondern die Stelle, auf die der
  /// Finger traf. Das SDK liefert dem Host ohnehin nur diese Stelle, nicht die
  /// Gruppe selbst, siehe `MapOverlayHost.handleFeatureTapped`.
  final MapPosition position;

  /// Ohne die Zahlen, siehe `MapPosition.toString()` und
  /// `docs/engineering/security.md` §6: ein Tipp trifft in aller Regel in der
  /// Nähe der Nutzerposition, und die darf nicht ins Log.
  @override
  String toString() => 'MapOverlayGroupTap($overlayId, position: $position)';
}

/// Ein Tipp auf einen **einzelnen** Punkt der Überlagerung [overlayId].
///
/// ## Warum das ein eigener Typ ist und nicht ein Feld an [MapOverlayGroupTap]
///
/// Die beiden tragen verschiedene Aussagen. Ein Gruppen-Tipp sagt „hier liegen
/// mehrere, öffne sie", ein Punkt-Tipp sagt „genau dieser eine". Ein
/// gemeinsamer Typ mit nullbarer [pointId] verschöbe die Unterscheidung in
/// eine `if`-Abfrage bei jedem Verbraucher, und der erste, der sie vergisst,
/// behandelt eine Gruppe wie einen Fakt.
///
/// Wertgleichheit hat auch dieser Typ nicht, aus derselben Begründung wie
/// [MapOverlayGroupTap]: zweimal auf denselben Ballon getippt sind zwei Tipps.
final class MapOverlayPointTap {
  /// Erzeugt einen Punkt-Tipp.
  const MapOverlayPointTap({
    required this.overlayId,
    required this.pointId,
    required this.position,
  });

  /// Welche Überlagerung getroffen wurde.
  final String overlayId;

  /// Die Kennung des getroffenen Punktes, also `MapOverlayPoint.id`.
  ///
  /// **Verlässlich, weil sie oben im Merkmal steht und nicht unter
  /// `properties`.** `overlayGeoJson` legt sie dorthin, und der Kopfkommentar
  /// dort begründet, warum: der Antipp-Rückruf des SDK reicht `properties`
  /// gar nicht mit, eine Kennung unter `properties.id` käme als die
  /// Zeichenkette `"null"` an. Für ein von MapLibre selbst erzeugtes
  /// **Gruppen**-Merkmal gilt genau das, und deshalb trägt
  /// [MapOverlayGroupTap] bewusst keine Kennung.
  final String pointId;

  /// Wo auf der Karte getippt wurde.
  ///
  /// **Nicht die Koordinate des Punktes**, sondern die Stelle, auf die der
  /// Finger traf; das SDK liefert nur diese. Wer die Koordinate des Punktes
  /// braucht, schlägt sie über [pointId] in seiner eigenen Überlagerung nach.
  /// Der Unterschied ist keine Feinheit: eine Entfernungsregel, die mit der
  /// Fingerstelle rechnet statt mit dem Fakt, ist um die halbe Ballonbreite
  /// falsch, und das sind auf Zoom 16 einige Meter.
  final MapPosition position;

  /// Ohne die Zahlen, siehe [MapOverlayGroupTap.toString].
  @override
  String toString() =>
      'MapOverlayPointTap($overlayId, point: $pointId, position: $position)';
}
