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
