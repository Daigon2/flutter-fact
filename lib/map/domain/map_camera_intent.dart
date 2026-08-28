/// Absichten, die ein Feature beim Karten-Host abgibt.
///
/// Der Host besitzt die Kamera (`lib/features/README.md`, „Was bewusst kein
/// Feature ist", Entscheidung vom 28.08.2026). Ein Feature sagt deshalb nicht
/// „bewege die Kamera dorthin", sondern gibt eine Absicht ab; ob sie
/// ausgeführt wird, entscheidet `map_camera_gate.dart`.
///
/// ## Die drei Sorten und ihr Rang
///
/// | Rang | Sorte | Bedeutung |
/// |---|---|---|
/// | 1 | [MapCameraCommand] | ausdrücklicher Nutzerbefehl, bricht alles ab |
/// | 2 | *(keine Absicht)* | direkte Manipulation durch den Nutzer |
/// | 3 | [MapCameraOneShot] | einmalige Bewegung, die letzte gewinnt |
/// | 4 | [MapCameraFollow] | Dauerabsicht, weicht allem darüber |
///
/// **Rang 2 fehlt hier mit Absicht.** Der Nutzer, der die Karte mit dem Finger
/// zieht, gibt keine Absicht ab: `maplibre_gl 0.26.2` liefert dafür gar kein
/// Ereignis, das ihn als Ursache ausweisen würde. `OnCameraMoveCallback` ist
/// `void Function(CameraPosition)`, ohne Ursache und ohne `isGesture`, und
/// `isCameraMoving` gilt für jede Bewegung. Direkte Manipulation ist deshalb
/// **Zustand am Gate** und keine Absicht: `MapCameraSituation.userIsGesturing`
/// für „der Finger liegt gerade auf der Karte",
/// `MapCameraSituation.lastUnexplainedMoveAt` für „zuletzt kam eine Bewegung
/// an, obwohl der Host nicht gesteuert hat". Wer hier eine vierte Sorte dafür
/// nachrüstet, hat den Grund nicht gelesen.
///
/// ## Was hier bewusst fehlt: eine Rücknahme
///
/// Es gibt keine Möglichkeit, eine [MapCameraFollow] wieder abzumelden. Das
/// ist kein Versehen: in der Quelle gibt es dafür heute keinen Aufrufer. Die
/// beiden Dauerabsichten laufen, solange der Kartenbildschirm lebt, und der
/// einzige echte Abschaltfall ist das Einrasten der Blickrichtung
/// (`screen-map.jsx:1692`). Das ist Zustand am Gate und keine Rücknahme: die
/// Absicht bleibt bestehen, sie wird nur unterdrückt.
///
/// **Der Auslöser, ab dem es die Rücknahme braucht:** das erste Feature, das
/// eine Dauerabsicht wirklich beendet, also das **Tourende in Phase 6**. Ab
/// dort läuft eine Tour-Folgeabsicht weiter, obwohl niemand sie mehr will, und
/// erst dann ist die Rücknahme belegter Bedarf statt Vorrat (ADR-002).
///
/// ## Warum keine Absicht Wertgleichheit hat
///
/// `MapCameraChange` und `MapCameraView` haben `==` und `hashCode`, keine
/// Absicht hat sie. Das ist Absicht und kein vergessener Schritt: eine
/// Absicht ist eine **Nachricht** und kein Wert. Zwei GPS-Folgeabsichten mit
/// demselben Ziel, eine Sekunde auseinander abgegeben, sind zwei verschiedene
/// Ereignisse, und ein `==`, das sie gleichsetzt, lädt genau zu der
/// Entdopplung ein, die Vorrangregel 4 verbietet („die letzte gewinnt", nicht
/// „die zweite gleiche fällt weg"). Verglichen wird deshalb der Inhalt, also
/// `intent.change`, und nie die Absicht selbst.
library;

import 'package:fact_app/map/domain/map_camera.dart';

/// Wer eine Absicht abgibt.
///
/// Vier Features teilen sich eine Karte. Ohne diese Angabe wäre ein Konflikt
/// zwischen zwei Dauerabsichten nur *beobachtbar* („die Karte ruckelt") und
/// nicht *diagnostizierbar* („die Tour-Folgeabsicht und das GPS-Folgen ziehen
/// gegeneinander").
///
/// Hier stehen nur die Herkünfte, für die es in der Verhaltensquelle heute
/// wirklich eine Kamerabewegung gibt. `challenges` und `collection` fehlen
/// deshalb: `screen-map.jsx` enthält keinen einzigen Kameraaufruf, der ihnen
/// gehört. Sie kommen dazu, wenn sie einen bekommen, und nicht vorher.
enum MapCameraIntentOrigin {
  /// Der Kartenbildschirm selbst: Sky-Fall (`screen-map.jsx:1732`),
  /// Stadt-Cluster (`:2363`), Cluster aufklappen (`:2447`), neuer Fakt live
  /// (`:2547`), Neuzentrieren (`:2983`), harter Reset (`:3168`), GPS-Folgen
  /// (`:2671`) und das Folgen der Blickrichtung (`:2838`).
  discovery,

  /// Tourstart (`screen-map.jsx:2795`), ausgelöst von `tourReady`.
  tours,

  /// Der Host aus eigenem Antrieb: die Auto-Neigung nach dem Zoomende
  /// (`screen-map.jsx:1755-1764`) reagiert auf die Kamera selbst und gehört
  /// keinem Feature. Ohne diesen Wert müsste sie sich als `discovery`
  /// ausgeben, und die Diagnose würde lügen.
  mapHost,
}

/// Welche Dauerabsicht gemeint ist.
///
/// Der Schlüssel, unter dem der Host `lastFollowAt` und `lastFollowCenter`
/// führt, siehe [MapCameraFollow.kind]. Getrennt von
/// [MapCameraIntentOrigin], weil die Herkunft sagt, **wer** etwas will, und
/// diese Aufzählung, **was** gewollt wird. Beide Werte hier sind
/// [MapCameraIntentOrigin.discovery], daran sieht man den Unterschied.
///
/// Hier stehen nur Dauerabsichten, die es in der Verhaltensquelle wirklich
/// gibt. Die Tour-Folgeabsicht der Phase 6 fehlt deshalb noch.
enum MapCameraFollowKind {
  /// Die Karte folgt der Nutzerposition (`screen-map.jsx:2665-2675`).
  ///
  /// Totzone 12 m, Mindestpause 800 ms, weicht keiner Geste.
  userPosition,

  /// Die Blickrichtung folgt dem Kompass (`screen-map.jsx:2834-2839`).
  ///
  /// Winkel-Totzone 1,5°, keine Pause, weicht einer Geste.
  compassBearing,
}

/// Eine Absicht, die Kamera zu bewegen.
sealed class MapCameraIntent {
  /// Für Unterklassen.
  const MapCameraIntent({
    required this.change,
    required this.motion,
    required this.origin,
  });

  /// Was sich ändern soll.
  final MapCameraChange change;

  /// Wie die Änderung stattfindet.
  final MapCameraMotion motion;

  /// Wer die Absicht abgegeben hat.
  final MapCameraIntentOrigin origin;

  /// Der Rang aus der Tabelle im Kopf dieser Datei, kleiner heißt stärker.
  ///
  /// Steht als Wert und nicht nur im Kommentar da, damit ein Test die
  /// Vorrangfolge zusichern kann, ohne die Reihenfolge von `switch`-Zweigen im
  /// Gate nachzubauen. Rang 2 kommt nicht vor, siehe Kopf der Datei.
  int get rank;
}

/// Rang 1: ein ausdrücklicher Nutzerbefehl.
///
/// Wird **immer** ausgeführt, auch mitten in einer laufenden Animation. In der
/// Quelle sind das die beiden Kompass-Gesten: der lange Druck ruft `m.stop()`
/// und danach `jumpTo` (`screen-map.jsx:3164-3170`), der kurze Druck
/// zentriert neu (`:3182-3183`). Beide brechen ab, was gerade läuft.
///
/// `maplibre_gl 0.26.2` hat kein `stop()` und kein `cancel()`. Der Abbruch
/// entsteht dort dadurch, dass der Host die neue Bewegung setzt und seinen
/// eigenen Animationszustand verwirft; das Gate meldet das über
/// `MapCameraVerdict.interruptsRunningAnimation`.
final class MapCameraCommand extends MapCameraIntent {
  /// Erzeugt einen Nutzerbefehl.
  const MapCameraCommand({
    required super.change,
    required super.motion,
    required super.origin,
    required this.releasesBearingLock,
    required this.clearsFollowAnchor,
  });

  /// Ob dieser Befehl das Einrasten der Blickrichtung wieder löst.
  ///
  /// Absichtlich **ohne Standardwert**. Beide Befehle der Quelle setzen
  /// `manualBearingRef.current = false` (`screen-map.jsx:3166` und `:3182`),
  /// ein Standard `false` wäre also für beide bekannten Fälle falsch. Ein
  /// Standard `true` wäre umgekehrt eine Verallgemeinerung aus zwei Fällen,
  /// die niemand belegt hat. Deshalb muss jeder Aufrufer sich entscheiden.
  final bool releasesBearingLock;

  /// Ob dieser Befehl den Anker der Strecken-Totzone leert.
  ///
  /// Der Anker ist der zuletzt von einer Dauerabsicht angefahrene Mittelpunkt,
  /// den der Host als `MapCameraSituation.lastFollowCenter` weitergibt. Die
  /// Quelle hält ihn in `lastCameraPosRef` (`screen-map.jsx:2659-2661`).
  ///
  /// **Die Domäne hat keinen Zustand.** Dieses Feld leert nichts, es sagt dem
  /// Host, was **er** zu leeren hat, bevor er die nächste Lage zusammenstellt.
  /// Wer hier eine Wirkung erwartet, sucht sie in der falschen Schicht.
  ///
  /// Ohne dieses Feld unterdrückt das Gate nach dem harten Reset den nächsten
  /// GPS-Fix mit der Strecken-Totzone, während die Quelle ihn ausführt: sie
  /// rechnet dort wieder mit `Infinity` (`:2660-2662`), weil `:3165` den Anker
  /// gerade auf `null` gesetzt hat.
  ///
  /// Absichtlich **ohne Standardwert**, aus demselben Grund wie
  /// [releasesBearingLock], nur mit umgekehrtem Befund: die zwei bekannten
  /// Befehle sind sich hier **uneinig**. Der lange Druck löscht beides
  /// (`:3165` und `:3166`), der kurze Druck löscht nur das Einrasten (`:3182`)
  /// und ruft dann `recenter()` (`:2983-2987`), das den Anker nicht anfasst.
  /// Jeder Standard wäre für einen der beiden falsch.
  final bool clearsFollowAnchor;

  @override
  int get rank => 1;
}

/// Rang 3: eine einmalige Bewegung.
///
/// Unter mehreren Einmal-Absichten gewinnt die letzte, es gibt keine
/// Warteschlange. Beispiele der Quelle: Sky-Fall (`screen-map.jsx:1732`),
/// Stadt-Cluster (`:2363`), Cluster aufklappen (`:2447`), neuer Fakt live
/// (`:2547`), Tourstart (`:2795`), Neuzentrieren (`:2983`).
final class MapCameraOneShot extends MapCameraIntent {
  /// Erzeugt eine einmalige Absicht.
  const MapCameraOneShot({
    required super.change,
    required super.motion,
    required super.origin,
    this.yieldsToRunningAnimation = false,
  });

  /// Ob diese Absicht einer laufenden Animation weicht.
  ///
  /// **Standard ist `false`**, weil das für sechs der sieben Einmal-Absichten
  /// der Quelle gilt: sie überschreiben, was gerade läuft.
  ///
  /// Genau eine setzt es auf `true`, die Auto-Neigung nach dem Zoomende:
  /// `map.on('zoomend', () => { if (map.isEasing()) return; ... })`
  /// (`screen-map.jsx:1761`). Der Grund steht im Kommentar darüber: eine
  /// laufende `flyTo`/`easeTo` setzt die Neigung selbst, und die Automatik
  /// würde ihr ins Steuer greifen.
  ///
  /// Dieses Feld existiert, damit das Gate ohne Sonderfall auskommt. Die
  /// Alternative wäre ein `if` im Gate, das die Auto-Neigung an ihrer Herkunft
  /// erkennt, und das wäre schlechter: eine zweite Absicht mit derselben
  /// Eigenschaft müsste dann das Gate ändern statt ihr eigenes Feld zu setzen.
  final bool yieldsToRunningAnimation;

  @override
  int get rank => 3;
}

/// Rang 4: eine Dauerabsicht, die immer wieder neue Werte nachschiebt.
///
/// Zwei davon gibt es in der Quelle, und sie sind sich in **jedem** Punkt
/// uneinig. Deshalb trägt jede Absicht ihre eigenen Schwellen mit, statt sie
/// sich vom Gate geben zu lassen:
///
/// | Dauerabsicht | [kind] | Totzone | Mindestpause | weicht einer Geste | Fundstelle |
/// |---|---|---|---|---|---|
/// | GPS-Folgen | `userPosition` | 12 m | 800 ms | nein | `screen-map.jsx:2665-2675` |
/// | Blickrichtung folgt Kompass | `compassBearing` | 1,5° | keine | ja | `screen-map.jsx:2834-2839` |
///
/// Die belegten Zahlen selbst stehen als benannte Konstanten in
/// `MapCameraThresholds`, damit sie nicht in jedem Aufrufer erneut auftauchen.
final class MapCameraFollow extends MapCameraIntent {
  /// Erzeugt eine Dauerabsicht.
  ///
  /// Sind [deadZoneMeters], [bearingDeadZoneDegrees] und [minPause] alle
  /// `null`, wird die Absicht ausgeführt, sobald keine Animation läuft. Das
  /// ist erlaubt und heißt „diese Dauerabsicht bremst sich nicht selbst".
  const MapCameraFollow({
    required this.kind,
    required super.change,
    required super.motion,
    required super.origin,
    required this.yieldsToUserGesture,
    this.deadZoneMeters,
    this.bearingDeadZoneDegrees,
    this.minPause,
  });

  /// Welche Dauerabsicht das ist, und damit ihre Identität.
  ///
  /// ## Warum die Herkunft dafür nicht reicht
  ///
  /// `MapCameraSituation.lastFollowAt` und `MapCameraSituation.lastFollowCenter`
  /// gehören laut Vertrag zu **dieser** Dauerabsicht und nicht zu irgendeiner.
  /// Der Host muss sie also je Dauerabsicht getrennt führen, und dafür braucht
  /// er einen Schlüssel. Nach [origin] zu schlüsseln ist **beweisbar falsch**:
  /// das GPS-Folgen (`screen-map.jsx:2665-2675`) und das Folgen der
  /// Blickrichtung (`:2834-2839`) sind beide [MapCameraIntentOrigin.discovery]
  /// und teilten sich damit einen Platz. Die Totzone der einen würde die andere
  /// bremsen, und zwar lautlos.
  ///
  /// ## Warum eine geschlossene Aufzählung und keine freie Zeichenkette
  ///
  /// Eine Zeichenkette ist ein Schlüssel, den man vertippen kann, und ein
  /// Tippfehler sieht wie eine neue Dauerabsicht aus: sie hätte einen eigenen,
  /// immer leeren Zustand und liefe deshalb ohne jede Totzone. Die Aufzählung
  /// prüft der Übersetzer, und sie zwingt jeden, der eine dritte Dauerabsicht
  /// hinzunimmt, einmal hierher zu schauen. In Phase 6 kommt die Tour dazu:
  /// das ist eine Zeile hier, und der Übersetzer zeigt jede Stelle, die darauf
  /// reagieren muss.
  ///
  /// ## Was diese Aufzählung nicht kann
  ///
  /// Sie unterscheidet **Sorten**, keine Instanzen. Heute ist das dasselbe: von
  /// jeder Sorte läuft höchstens eine. Sobald zwei Dauerabsichten derselben
  /// Sorte gleichzeitig laufen sollen, etwa zwei Touren nebeneinander, muss
  /// daraus ein Wertobjekt mit Sorte und Instanz werden. Das ist der Auslöser,
  /// und er steht hier, damit ihn niemand suchen muss.
  ///
  /// Absichtlich **ohne Standardwert**: welcher der beiden bekannten Werte der
  /// Standard sein sollte, ist nicht beantwortbar, und ein falsch geerbter
  /// Schlüssel ist genau der Fehler, den dieses Feld verhindert.
  final MapCameraFollowKind kind;

  /// Ob diese Dauerabsicht schweigt, solange der Nutzer die Karte anfasst.
  ///
  /// Gemeint ist der Gestenzustand, nicht die Karenzzeit danach: siehe
  /// `MapCameraSituation.userIsGesturing`. Die beiden sind zwei verschiedene
  /// Eingaben und messen zwei verschiedene Dinge.
  ///
  /// Absichtlich **ohne Standardwert**, aus demselben Grund wie
  /// [MapCameraCommand.releasesBearingLock]: die zwei bekannten Dauerabsichten
  /// sind sich uneinig.
  ///
  /// * Das Folgen der Blickrichtung **weicht**: `screen-map.jsx:2837` prüft
  ///   `!userInteracting`, und der Kommentar darüber (`:2833-2834`) nennt die
  ///   Folge des Weglassens: „Without this, 60Hz setBearing interrupts user
  ///   gestures and blocks pinch-zoom-out."
  /// * Das GPS-Folgen **weicht nicht**: `applyPos` prüft in `:2668` allein
  ///   `!m.isEasing()`. `userInteracting` ist dort gar nicht erreichbar, es
  ///   ist eine lokale Variable im Closure des Kompass-Effekts (`:2807`).
  ///
  /// Ein Standard wäre für eine der beiden falsch, und aus zwei Fällen auf
  /// alle künftigen zu schließen ist genau der Fehler, den dieses Feld behebt.
  final bool yieldsToUserGesture;

  /// Strecken-Totzone in Metern, `null` heißt „keine Streckenprüfung".
  ///
  /// Gemessen wird gegen den Mittelpunkt der **zuletzt ausgeführten**
  /// Dauerabsicht, nicht gegen die aktuelle Kartenmitte. Das ist die
  /// Rechnung der Quelle: `lastCameraPosRef` (`screen-map.jsx:2661`) hält den
  /// zuletzt selbst angefahrenen Punkt, damit ein Verschieben durch den Nutzer
  /// die Totzone nicht zurücksetzt.
  final double? deadZoneMeters;

  /// Winkel-Totzone in Grad, `null` heißt „keine Winkelprüfung".
  final double? bearingDeadZoneDegrees;

  /// Mindestpause seit der letzten Ausführung, `null` heißt „keine Pause".
  ///
  /// Das Folgen der Blickrichtung hat keine: die vier Bedingungen in
  /// `screen-map.jsx:2837` sind `!isEasing()`, `!userInteracting`,
  /// `!manualBearingRef` und die Winkel-Totzone, und keine davon ist eine
  /// Pause. Das GPS-Folgen hat 800 ms (`:2668`).
  final Duration? minPause;

  @override
  int get rank => 4;
}
