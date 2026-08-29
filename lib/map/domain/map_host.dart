/// Die veröffentlichte Fassade des Karten-Hosts.
///
/// ## Warum eine Fassade in der Domäne liegt, obwohl das sonst falsch wäre
///
/// Regel 18 des Prüfskripts (`tool/check_architecture.dart:236-240`) macht
/// `map/domain/` zur **einzigen öffentlichen Fläche** des Hosts: ein Feature,
/// das `map/presentation/` oder `map/data/` importiert, wird gemeldet. Es gibt
/// also keinen zweiten Ort, an dem dieser Vertrag stehen könnte.
///
/// **Das ist ausdrücklich nicht das Muster von `AuthRepository`.** Dort liegt
/// der Vertrag in der Domäne, weil die Domäne ihn selbst braucht, um ihre
/// Arbeit zu tun; die Implementierung in `data/` ist die umgekehrte
/// Abhängigkeit (Abhängigkeitsumkehr). Diese Fassade braucht in `map/domain/`
/// **niemand**: keine Funktion dieses Verzeichnisses ruft sie auf. Sie liegt
/// hier allein, weil Regel 18 keinen anderen Platz lässt.
///
/// Wer die beiden verwechselt, zieht die falsche Lehre und legt die nächste
/// Fassade nach `features/tours/domain/`, wo sie nichts zu suchen hat.
///
/// ## Hier steht nur, was ein Feature nicht selbst kann
///
/// Eine Fassade zieht Methoden an. Jede, die dazukommt, macht den Host zu
/// einem Dienstleister für Dinge, die das Feature selbst entscheiden sollte.
/// Der Prüfstein ist eng: kommt hin, was ohne die Karte gar nicht geht, also
/// der Kamerazustand und die Bitte um eine Kamerabewegung. Nicht hin kommt,
/// was ein Feature aus dem Kamerazustand selbst ableiten kann, etwa welche
/// Stadt in der Mitte liegt oder welche Fakten in der Nähe sind. Dieser eine
/// Satz ist der einzige billige Schutz davor.
library;

import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_overlay.dart';

/// Was ein Feature vom Karten-Host sehen darf.
///
/// `abstract interface class` und nicht `abstract class`: ein versehentliches
/// `extends` geht damit nicht durch, und jeder Fake in einem Test schreibt
/// sichtbar `implements MapHost`.
abstract interface class MapHost {
  /// Wo die Kamera gerade steht, oder `null`, solange keine Karte steht.
  ///
  /// `null` ist der Normalfall beim Start und nicht ein Fehler: die Karte
  /// entsteht erst, wenn das Widget gebaut und das SDK bereit ist.
  MapCameraView? get camera;

  /// Meldet jede Kamerabewegung, sobald die Karte steht.
  ///
  /// [Stream] ist hier die **einzige** erlaubte reaktive Primitive. Ein
  /// `ValueListenable` wäre Flutter, ein Provider wäre Riverpod, und beides
  /// verbietet die Domäne (`tool/check_architecture.dart`, Regel 1 und 2).
  /// `Stream` stammt aus `dart:async` und ist über `dart:core` sichtbar, ein
  /// eigener Import wäre überflüssig.
  ///
  /// Es gibt heute einen Aufrufer dafür, das ist kein Vorrat:
  /// `lib/features/discovery/presentation/pages/map_page.dart:45-52` zeigt den
  /// Stadtnamen aus der **Kartenmitte** an, nicht aus dem GPS. In der Quelle
  /// läuft `detectCity` dafür über zwölf Städte
  /// (`02_Frontend/app/screen-map.jsx:310-322`), und der Kommentar dort sagt
  /// warum: wer nach Rom schiebt, soll „Rom" sehen, ohne etwas auszuwählen.
  /// Mehrstädtigkeit hängt also direkt an diesem Strom.
  ///
  /// **Vor der Anzeige ist dieser Strom auf einen abgeleiteten Wert zu
  /// verdichten.** Er meldet jeden Bewegungsschritt, auf Android und iOS also
  /// bis zu einmal je Bild. Wer ihn direkt in einem Widget beobachtet, baut die
  /// Stadt-Pille bei jedem Schritt neu, obwohl sich der Stadtname beim Schieben
  /// über eine Straße nie ändert. Zu verdichten ist auf das, was angezeigt
  /// wird, also auf die erkannte Stadt, und erst dieser Wert gehört in den
  /// Aufbau der Oberfläche.
  Stream<MapCameraView> get cameraChanges;

  /// Gibt eine Absicht ab.
  ///
  /// Bewusst ohne Rückgabewert: der Host entscheidet mit
  /// `decideMapCameraIntent`, ob die Absicht ausgeführt wird, und ein Feature
  /// hat aus dieser Antwort nichts zu folgern. Wer sie doch auswertet, baut
  /// die Kamerahoheit Stück für Stück zurück ins Feature.
  ///
  /// **Offen und hier absichtlich nicht entschieden:** eine Absicht kann
  /// abgegeben werden, **bevor** eine Karte gemountet ist. In Schritt 12
  /// taucht das sofort auf, weil der Sky-Fall am ersten GPS-Fix hängt und
  /// nicht am Kartenwidget (`screen-map.jsx:1743-1747` merkt sich die Funktion
  /// in einem Ref und ruft sie später). Drei Möglichkeiten stehen im Raum: die
  /// Absicht fallen lassen, die letzte aufheben und beim Mounten nachholen,
  /// oder alle aufheben. Die Quelle löst es für ihren einen Fall mit
  /// „aufheben und nachholen", verallgemeinert das aber nicht. Welche Antwort
  /// gilt, gehört in den Schritt, der den Host baut, nicht in diesen Vertrag.
  ///
  /// **Beantwortet in Schritt 12, und zwar mit „fallen lassen":** der Host
  /// verwirft eine Absicht, die vor der Karte eintrifft, und meldet sie als
  /// eigenes Diagnose-Ereignis. Der Sky-Fall, der einzige belegte Fall für
  /// „aufheben und nachholen", entsteht erst in einem späteren Schritt; bis
  /// dahin wäre die Warteschlange Vorrat, den niemand prüft (ADR-002). Die
  /// Begründung und der Auslöser für eine Änderung stehen bei
  /// `MapCameraHost.submitIntent`.
  void submitIntent(MapCameraIntent intent);

  /// Registriert die Bilder, mit denen Punkte gezeichnet werden.
  ///
  /// **Vor [setOverlay] zu rufen, und der Grund ist ein lautloser Ausfall:**
  /// ein Symbol-Layer, dessen `icon-image` auf eine unbekannte Kennung zeigt,
  /// zeichnet gar nichts, ohne Fehler. Der Host meldet eine unbekannte
  /// Kennung deshalb als Diagnose-Ereignis; das ist der einzige Schutz, den
  /// ein Vertrag mit freien Zeichenketten haben kann, siehe [MapOverlayPoint].
  ///
  /// Ein zweiter Aufruf mit derselben [MapOverlayImage.styleId] ersetzt das
  /// Bild. Bereits registrierte Bilder bleiben, bis der Host stirbt: sie
  /// hängen an der Karte, nicht an einer Überlagerung, und dieselben zwölf
  /// Kategorienbilder tragen jede weitere Überlagerung mit.
  void registerOverlayImages(List<MapOverlayImage> images);

  /// Legt [overlay] auf die Karte oder ersetzt eine gleichnamige.
  ///
  /// **Anders als [submitIntent] geht hier nichts verloren.** Eine Absicht ist
  /// ein Ereignis und verfällt, eine Überlagerung ist Zustand: kommt sie an,
  /// bevor die Karte steht, hält der Host sie fest und legt sie auf, sobald es
  /// eine Karte gibt. Die Begründung steht bei [MapOverlay].
  void setOverlay(MapOverlay overlay);

  /// Nimmt die Überlagerung mit der Kennung [overlayId] wieder herunter.
  ///
  /// Eine unbekannte Kennung ist kein Fehler und tut nichts: das Aufräumen
  /// eines Bildschirms, der nie eine Überlagerung gesetzt hat, soll nicht
  /// melden müssen, ob er es getan hat.
  void removeOverlay(String overlayId);
}
