/// Die Entscheidung, ob eine Kameraabsicht ausgeführt wird, als reine
/// Funktion, samt der Schwellwerte, gegen die sie prüft.
///
/// ## Warum die Schwellwerte hier stehen und nicht in einer eigenen Datei
///
/// Getrennt driften sie. Jemand ändert die Totzone von 12 auf 15 Meter, und
/// der Doc-Kommentar am Gate nennt weiter die 12. Solange beides in derselben
/// Datei liegt, sieht man den Widerspruch beim Ändern.
///
/// ## Keine Uhr in der Domäne
///
/// In dieser Datei gibt es kein `DateTime.now()` und keine `Stopwatch`. Die
/// Zeit kommt als [Duration] seit einem monotonen Nullpunkt vom Aufrufer, der
/// den Nullpunkt selbst wählt. Zwei Gründe: eine Domäne, die die Uhr liest,
/// ist nicht ohne Warten testbar, und `DateTime.now()` kann rückwärts
/// springen, während eine Kamera-Karenzzeit läuft.
library;

import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_position.dart';

/// Die Schwellwerte, gegen die das Gate prüft.
///
/// Die drei belegten Zahlen der Quelle, die eine **Absicht** drosseln, stehen
/// als **statische Konstanten**: sie sind ein Katalog mit Fundstelle, aus dem
/// sich ein Aufrufer bedient, wenn er eine [MapCameraFollow] baut. Das Gate
/// liest sie nicht; es liest die Werte, die die Absicht selbst trägt. Wären es
/// Instanzfelder, gäbe es für dieselbe Schwelle zwei Quellen, und niemand
/// wüsste, welche gilt.
///
/// Instanzfeld ist genau eines: [manualMoveGrace], der einzige Schalter, den
/// die Anwendung wirklich stellt.
///
/// Eine vierte Konstante steht hier, die **nicht** aus der Quelle stammt und
/// die die Domäne sehr wohl liest: [manualBearingNoiseDegrees], die
/// Standardschwelle von [isManualBearingChange]. Sie drosselt keine Absicht,
/// sondern beantwortet die davon unabhängige Frage, ob eine Drehung vom Nutzer
/// kam. Der Absatz oben gilt für sie nicht, und ihr eigener Kommentar sagt,
/// warum.
///
/// ## Zwei belegte Zahlen der Quelle, die hier bewusst fehlen
///
/// Die Liste oben ist vollständig **für die Domäne** und unvollständig für die
/// Karte. Zwei weitere Zahlen der Quelle gehören dem Host, weil er sie
/// ausrechnet, **bevor** er überhaupt eine Absicht abgibt:
///
/// * `screen-map.jsx:1764`: `if (Math.abs(cur - target) > 2)`. Die
///   Auto-Neigung nach dem Zoomende entsteht gar nicht erst, wenn die Neigung
///   schon nah genug am Sollwert liegt. Das ist kein Urteil des Gates über
///   eine vorhandene Absicht, sondern die Frage, ob es eine gibt.
/// * `screen-map.jsx:2831`: `smoothBearing + diff * 0.25`. Die Rohpeilung des
///   Kompasses wird geglättet, bevor sie zum Ziel einer Dauerabsicht wird. Das
///   Gate sieht immer nur den geglätteten Wert; ohne die Glättung würde die
///   Winkel-Totzone von 1,5° gegen ein zappelndes Rohsignal messen.
///
/// Sie stehen hier als Verweis und nicht als Konstante, weil eine Konstante in
/// `map/domain/` behaupten würde, die Domäne rechne damit. Wer den Host baut,
/// soll sie finden, statt sie neu zu erfinden oder wegzulassen.
final class MapCameraThresholds {
  /// Erzeugt Schwellwerte. Ohne Argument gilt Lesart A, siehe
  /// [manualMoveGrace].
  const MapCameraThresholds({this.manualMoveGrace = Duration.zero});

  /// Strecken-Totzone des GPS-Folgens in Metern.
  ///
  /// `screen-map.jsx:2668`: `movedSinceCamera > 12`. Der Kommentar darüber
  /// nennt den Grund: die 1 bis 5 Hz des GPS-Stroms lösen sonst eine schon
  /// laufende 600-ms-Animation immer wieder neu aus, sichtbar als Ruckeln
  /// beim Gehen.
  static const double followDeadZoneMeters = 12;

  /// Mindestpause des GPS-Folgens zwischen zwei Ausführungen.
  ///
  /// `screen-map.jsx:2668`: `sinceLastEase > 800`, in Millisekunden.
  static const Duration followMinPause = Duration(milliseconds: 800);

  /// Winkel-Totzone des Blickrichtungs-Folgens in Grad.
  ///
  /// `screen-map.jsx:2837`: `bearingDelta > 1.5`. Ohne sie unterbricht ein
  /// 60-Hz-`setBearing` die Gesten des Nutzers und blockiert das Herauszoomen
  /// mit zwei Fingern.
  static const double bearingDeadZoneDegrees = 1.5;

  /// Ab wieviel Grad eine unerklärte Drehung als Nutzerdrehung zählt.
  ///
  /// **Nicht aus der Quelle.** Die Quelle hat für diese Frage überhaupt keine
  /// Schwelle: `screen-map.jsx:1692` entscheidet allein an `e.originalEvent`,
  /// also an der Ursache und nicht an der Größe. Diese Zahl ist reiner Schutz
  /// gegen Fließkomma-Rauschen in der Kamerarückmeldung und ersetzt nichts,
  /// was drüben stünde.
  ///
  /// **Sie ist ausdrücklich nicht [bearingDeadZoneDegrees].** Die beiden
  /// beantworten zwei verschiedene Fragen: „wie weit muss der Kompass wandern,
  /// bevor der Host nachzieht" gegen „wie weit muss der Nutzer drehen, bevor
  /// eingerastet wird". Dass beide in Grad gemessen werden, macht sie nicht zu
  /// derselben Zahl; hingen sie an einem Wert, änderte eine Anpassung der
  /// Kompassglättung stillschweigend das Einrasten mit.
  ///
  /// **Warum 0,25:** klein genug, dass jede absichtliche Zwei-Finger-Drehung
  /// sie überschreitet (die Quelle rastet ohne jede Schwelle ein, also ist
  /// jedes zu große Fenster ein Verhaltensunterschied), und groß genug gegen
  /// das Rauschen: eine Blickrichtung, die als 32-Bit-Gleitkommazahl über den
  /// Plattformkanal kommt, hat bei Werten nahe 360° eine Auflösung von rund
  /// 3e-5 Grad, also vier Größenordnungen darunter. 0,25 ist außerdem im
  /// Binärsystem exakt darstellbar, sodass ein Grenztest ohne Epsilon
  /// auskommt.
  ///
  /// Die Zahl bleibt eine gewählte und keine gemessene. Belegen ließe sie sich
  /// nur auf einem Gerät, siehe die offene Frage bei [isManualBearingChange].
  static const double manualBearingNoiseDegrees = 0.25;

  /// Wie lange das GPS-Folgen nach einer Bewegung des Nutzers pausiert.
  ///
  /// **Das ist der Schalter für genau eine offene Frage, und nicht der
  /// Schalter für Vorrangregel 2 insgesamt.** Die Frage lautet: soll das
  /// GPS-Folgen nach eigenhändigem Verschieben eine Weile aussetzen. Die
  /// Entscheidung liegt offen bei Janek.
  ///
  /// * **Lesart A, [Duration.zero], der Standard und die belegte:** die
  ///   Bedingung feuert nie. So verhält sich die PWA an dieser Stelle:
  ///   `applyPos` prüft in `screen-map.jsx:2668` allein `!m.isEasing()`, es
  ///   gibt dort keine Karenzzeit und keinen Gestenzustand. Wer die Karte
  ///   wegzieht und dann zwölf Meter läuft, dem reißt die Quelle die Karte
  ///   zurück.
  /// * **Lesart B, ein Wert größer als null:** nach eigenhändigem Verschieben
  ///   folgt die Karte für diese Zeitspanne nicht.
  ///
  /// **Der andere, quellenbelegte Teil von Vorrangregel 2 hängt nicht hier.**
  /// Er hängt an `MapCameraSituation.userIsGesturing` und an
  /// `MapCameraFollow.yieldsToUserGesture`, dem Nachbau von `userInteracting`
  /// (`:2807`). Ein Karenzzeitfenster ist kein Gestenzustand: die Quelle
  /// sperrt ab `touchstart`, also bevor sich die Kamera überhaupt bewegt hat,
  /// und gibt an `touchend` sofort wieder frei. Ein Fenster nach der letzten
  /// Bewegung sperrt am Anfang zu spät und am Ende zu lange.
  ///
  /// Der Standard ist Lesart A, weil die PWA die Verhaltensquelle ist und
  /// nicht, weil sie die angenehmere wäre. Ein Test sichert beide Lesarten zu,
  /// damit der Umschalter nicht beim ersten Versuch bricht.
  final Duration manualMoveGrace;

  @override
  bool operator ==(Object other) =>
      other is MapCameraThresholds && other.manualMoveGrace == manualMoveGrace;

  @override
  int get hashCode => manualMoveGrace.hashCode;

  @override
  String toString() => 'MapCameraThresholds(manualMoveGrace: $manualMoveGrace)';
}

/// Alles, was das Gate wissen muss, als übergebene Werte.
///
/// Der Aufrufer stellt sie zusammen; das Gate fragt nichts nach. Wird eine
/// [MapCameraFollow] bewertet, gehören [lastFollowAt] und [lastFollowCenter]
/// zu **dieser** Dauerabsicht und nicht zu irgendeiner: die beiden
/// Dauerabsichten der Quelle führen ihren Zustand ebenfalls getrennt,
/// `lastCameraPosRef` gehört allein dem GPS-Folgen
/// (`screen-map.jsx:2661-2670`).
///
/// Der Schlüssel, unter dem der Host diesen Zustand getrennt hält, ist
/// [MapCameraFollow.kind]. Nach der Herkunft zu schlüsseln wäre falsch: beide
/// bekannten Dauerabsichten sind [MapCameraIntentOrigin.discovery].
///
/// `final class`: der Typ hat zwar kein `==`, aber Unterklassen könnten
/// [isAnimating] überschreiben, und damit hinge das Urteil des Gates an der
/// Lage statt an der Regel.
final class MapCameraSituation {
  /// Erzeugt eine Lagebeschreibung.
  const MapCameraSituation({
    required this.view,
    required this.now,
    this.animationStartedAt,
    this.animationEndsAt,
    this.userIsGesturing = false,
    this.lastUnexplainedMoveAt,
    this.bearingLocked = false,
    this.lastFollowAt,
    this.lastFollowCenter,
  });

  /// Wo die Kamera gerade steht.
  final MapCameraView view;

  /// Jetzt, als Abstand zu einem monotonen Nullpunkt des Aufrufers.
  final Duration now;

  /// Wann die laufende eigene Animation begonnen hat, sonst `null`.
  final Duration? animationStartedAt;

  /// Wann die laufende eigene Animation planmäßig endet, sonst `null`.
  ///
  /// „Planmäßig", weil `maplibre_gl 0.26.2` das Ende nicht meldet:
  /// `animateCamera` liefert auf iOS immer sofort `null`
  /// (`controller.dart:416`, eigene Doku des Pakets), und `isCameraMoving`
  /// gilt für jede Bewegung, auch für das Ziehen mit dem Finger
  /// (`controller.dart:185`). Der Host muss seinen Animationszustand deshalb
  /// selbst führen, und das heißt: aus Startzeit plus Dauer rechnen.
  final Duration? animationEndsAt;

  /// Ob der Nutzer die Karte **gerade in diesem Moment** anfasst.
  ///
  /// Der Nachbau von `userInteracting` (`screen-map.jsx:2807`). Dort wird die
  /// Variable an `dragstart`, `zoomstart`, `pitchstart` und `touchstart`
  /// gesetzt (`:2810-2814`) und an `dragend`, `zoomend`, `pitchend`,
  /// `touchend` und `touchcancel` gelöscht. Genutzt wird sie in `:2837`, und
  /// der Kommentar darüber (`:2833-2834`) nennt die Folge des Weglassens:
  /// „Without this, 60Hz setBearing interrupts user gestures and blocks
  /// pinch-zoom-out."
  ///
  /// Standard `false`, weil „keine Geste" der ruhende Zustand ist. Das ist
  /// kein Vorgriff auf eine offene Frage, sondern die Abwesenheit eines
  /// Ereignisses.
  ///
  /// **Woher die Presentation das weiß, ist ihre Sache und nicht die der
  /// Domäne.** Zwei Wege stehen im Raum, und **keiner von beiden ist
  /// gemessen**:
  ///
  /// 1. Zeigerereignisse eines `Listener` über der Karte, also Anfang und Ende
  ///    der Berührung unabhängig vom Karten-SDK. Nah an der Quelle, kennt aber
  ///    keine Geste, die ohne Berührung entsteht.
  /// 2. Eine Kamerabewegung, die eintrifft, während der Host nicht steuert.
  ///    Braucht kein zusätzliches Widget, meldet den Anfang aber erst, wenn
  ///    sich die Kamera schon bewegt hat, und kennt gar kein Ende.
  ///
  /// Welcher Weg trägt, entscheidet Schritt 12 am Gerät. Der Vertrag hält nur
  /// fest, **dass** der Host es zu beantworten hat.
  ///
  /// Nicht zu verwechseln mit [lastUnexplainedMoveAt]: das ist ein Zeitpunkt
  /// in der Vergangenheit, dies ist ein Zustand mit Anfang und Ende.
  final bool userIsGesturing;

  /// Wann zuletzt eine **unerklärte** Kamerabewegung eintraf, sonst `null`.
  ///
  /// Unerklärt heißt: sie kam an, obwohl der Host selbst nicht gesteuert hat.
  /// `maplibre_gl 0.26.2` nennt dafür keine Ursache: `OnCameraMoveCallback`
  /// ist `void Function(CameraPosition)`, es gibt kein `isGesture` und keinen
  /// `onCameraMoveStarted`-Rückruf am Widget.
  ///
  /// **Ein Zeitpunkt und kein `bool`, weil er etwas anderes misst als
  /// [userIsGesturing].** Hier steht, wann der Nutzer zuletzt eingegriffen
  /// hat, dort, ob er es gerade tut. Aus einem Zeitpunkt lässt sich ein
  /// Nachlauf ableiten ([MapCameraThresholds.manualMoveGrace]), aus einem
  /// Zustand nicht; aus einem Zustand lässt sich „jetzt gerade" ablesen, aus
  /// einem Zeitpunkt nur ungenau. Deshalb sind es zwei Eingaben und nicht
  /// eine. Ein früherer Kommentar begründete den Zeitpunkt damit, ein `bool`
  /// wäre die schlechtere Wahl: das war falsch, die Quelle benutzt an der
  /// zweiten Stelle genau ein `bool`.
  final Duration? lastUnexplainedMoveAt;

  /// Ob die Blickrichtung eingerastet ist.
  ///
  /// Entspricht `manualBearingRef.current` (`screen-map.jsx:1692`). Gesetzt
  /// wird es, wenn [isManualBearingChange] wahr ist; gelöst wird es allein von
  /// einem [MapCameraCommand] mit `releasesBearingLock`.
  final bool bearingLocked;

  /// Wann die bewertete Dauerabsicht zuletzt ausgeführt wurde, sonst `null`.
  final Duration? lastFollowAt;

  /// Welchen Mittelpunkt die bewertete Dauerabsicht zuletzt angefahren hat.
  ///
  /// `null` heißt „noch nie", und dann greift die Strecken-Totzone nicht. Die
  /// Quelle rechnet an dieser Stelle mit `Infinity`
  /// (`screen-map.jsx:2660-2662`), das Ergebnis ist dasselbe.
  final MapPosition? lastFollowCenter;

  /// Ob gerade eine eigene Animation läuft.
  ///
  /// Verlangt Start **und** geplantes Ende. `now == animationEndsAt` gilt
  /// bereits als vorbei: eine Animation, die bei `t` beginnt und `d` dauert,
  /// ist bei `t + d` fertig.
  ///
  /// **Beide Halbfassungen sind `false`, und die gefährlichere ist der Start
  /// ohne Ende.** Sie ist kein konstruierter Fall: `animateCamera` liefert auf
  /// iOS sofort `null` statt zu warten (`maplibre_gl 0.26.2`,
  /// `lib/src/controller.dart:416`). Ein Host, der die Startzeit mitschreibt,
  /// die Dauer aber nicht kennt, landet genau dort. Würde das als „läuft" oder
  /// gar als „läuft ewig" gelten, unterdrückte Schritt 1 des Gates ab diesem
  /// Moment **jede** Dauerabsicht dauerhaft: die Karte folgte weder dem GPS
  /// noch dem Kompass, und nichts würde den Zustand je wieder beenden. Eine
  /// Animation, deren Ende niemand kennt, ist für dieses Gate keine.
  ///
  /// Die Umkehrung, Ende ohne Start, ist harmloser, aber ebenso `false`: sie
  /// ist ein unvollständig geführter Zustand und keine Aussage über die Karte.
  bool get isAnimating {
    final Duration? start = animationStartedAt;
    final Duration? end = animationEndsAt;
    if (start == null || end == null) {
      return false;
    }
    return now >= start && now < end;
  }
}

/// Warum eine Absicht nicht ausgeführt wurde.
///
/// Der Grund ist kein Schmuck. Er ist das, was eine Diagnosemeldung anzeigt,
/// und das, was ein Test zusichert: eine Prüfung, die nur „nicht ausgeführt"
/// verlangt, findet nicht, wenn die richtige Antwort aus dem falschen Grund
/// entsteht.
enum MapCameraSuppressionReason {
  /// Eine eigene Animation läuft noch.
  runningAnimation,

  /// Der Nutzer fasst die Karte gerade an und die Absicht weicht ihm.
  ///
  /// Eigener Grund und ausdrücklich **nicht** [manualMoveGrace]: der eine
  /// meldet eine laufende Geste (`screen-map.jsx:2837`, `!userInteracting`),
  /// der andere ein Zeitfenster danach, das die Quelle gar nicht kennt. Ein
  /// gemeinsamer Grund machte die beiden für jeden Test ununterscheidbar.
  userGesture,

  /// Die Blickrichtung ist eingerastet und die Absicht betrifft sie.
  bearingLocked,

  /// Die Karenzzeit nach der letzten unerklärten Bewegung läuft noch.
  manualMoveGrace,

  /// Die Strecke zum zuletzt angefahrenen Mittelpunkt ist zu kurz.
  distanceDeadZone,

  /// Der Winkel zur aktuellen Blickrichtung ist zu klein.
  bearingDeadZone,

  /// Seit der letzten Ausführung ist die Mindestpause nicht um.
  minPause,
}

/// Das Ergebnis der Entscheidung.
final class MapCameraVerdict {
  /// Die Absicht wird ausgeführt.
  ///
  /// [interruptsRunningAnimation] sagt, ob dabei eine laufende eigene
  /// Animation überschrieben wird. Der Host braucht das, weil
  /// `maplibre_gl 0.26.2` kein `stop()` und kein `cancel()` hat: er muss
  /// seinen eigenen Animationszustand verwerfen, sonst hielte er die
  /// abgebrochene Animation noch für laufend und würde die nächste
  /// Dauerabsicht grundlos unterdrücken.
  const MapCameraVerdict.execute({required this.interruptsRunningAnimation})
    : reason = null;

  /// Die Absicht wird unterdrückt, mit benanntem Grund.
  const MapCameraVerdict.suppressed(MapCameraSuppressionReason this.reason)
    : interruptsRunningAnimation = false;

  /// Der Grund der Unterdrückung, `null` beim Ausführen.
  final MapCameraSuppressionReason? reason;

  /// Ob beim Ausführen eine laufende Animation überschrieben wird.
  final bool interruptsRunningAnimation;

  /// Ob die Absicht ausgeführt wird.
  bool get isExecuted => reason == null;

  @override
  bool operator ==(Object other) =>
      other is MapCameraVerdict &&
      other.reason == reason &&
      other.interruptsRunningAnimation == interruptsRunningAnimation;

  @override
  int get hashCode => Object.hash(reason, interruptsRunningAnimation);

  @override
  String toString() => reason == null
      ? 'MapCameraVerdict.execute(interruptsRunningAnimation: '
            '$interruptsRunningAnimation)'
      : 'MapCameraVerdict.suppressed(${reason!.name})';
}

/// Entscheidet, ob [intent] in [situation] ausgeführt wird.
///
/// Rein, ohne Zustand, ohne Seiteneffekt und ohne Uhr.
///
/// ## Die vier Vorrangregeln
///
/// 1. **Ein [MapCameraCommand] bricht alles ab.** Er wird immer ausgeführt,
///    auch mitten in einer Animation.
/// 2. **Direkte Manipulation schlägt Automatik.** Diese Regel hat drei Teile,
///    und nur zwei davon sind belegt. Belegt: die Blickrichtung rastet ein
///    ([isManualBearingChange]), und nur ein Befehl löst sie wieder
///    (`screen-map.jsx:1692`, `:3166`, `:3182`); und eine Dauerabsicht mit
///    `yieldsToUserGesture` schweigt, solange
///    [MapCameraSituation.userIsGesturing] gilt (`:2837`). Nicht belegt: ein
///    Nachlauf nach dem Loslassen, [MapCameraThresholds.manualMoveGrace], im
///    Standard aus.
/// 3. **Eine laufende Animation gewinnt gegen eine neue Dauerabsicht**, dazu
///    Totzone und Mindestpause der Absicht selbst.
/// 4. **Unter Einmal-Absichten gewinnt die letzte**, es gibt keine
///    Warteschlange. Das entscheidet nicht diese Funktion, sondern der Host:
///    hier bekommt jede Einmal-Absicht ihr „ausführen", und die spätere
///    überschreibt die frühere Bewegung.
///
/// ## Die Reihenfolge der Prüfungen, und warum sie festgeschrieben ist
///
/// Bei einer Dauerabsicht können mehrere Gründe gleichzeitig zutreffen. Welcher
/// gemeldet wird, muss im Vertrag stehen, sonst prüft ein Test die
/// Reihenfolge der `if`-Zweige statt das zugesagte Verhalten. Die Reihenfolge
/// ist:
///
/// 1. [MapCameraSuppressionReason.runningAnimation]
/// 2. [MapCameraSuppressionReason.userGesture]
/// 3. [MapCameraSuppressionReason.bearingLocked]
/// 4. [MapCameraSuppressionReason.manualMoveGrace]
/// 5. [MapCameraSuppressionReason.distanceDeadZone]
/// 6. [MapCameraSuppressionReason.bearingDeadZone]
/// 7. [MapCameraSuppressionReason.minPause]
///
/// Zuerst der Zustand des Hosts, dann der Zustand des Nutzers, zuletzt die
/// Sparsamkeitsregeln der Absicht: von „geht grundsätzlich nicht" zu „lohnt
/// sich gerade nicht".
///
/// Die ersten drei stehen in derselben Reihenfolge wie die Bedingungen in
/// `screen-map.jsx:2837`: `!m.isEasing() && !userInteracting &&
/// !manualBearingRef.current && bearingDelta > 1.5`. Auch `applyPos` prüft
/// `!isEasing()` zuerst (`:2668`).
///
/// Nur der vierte Grund hat in der Quelle kein Gegenstück: die Karenzzeit
/// steht hinter dem Einrasten, weil sie die unbelegte Zutat ist und deshalb
/// nichts überdecken soll, was die Quelle wirklich meldet. Am Ergebnis ändert
/// die Stelle nichts, im Standard (Lesart A) trifft sie ohnehin nie zu.
MapCameraVerdict decideMapCameraIntent({
  required MapCameraIntent intent,
  required MapCameraSituation situation,
  MapCameraThresholds thresholds = const MapCameraThresholds(),
}) {
  switch (intent) {
    case MapCameraCommand():
      // Vorrangregel 1. Kein einziger Grund darf hier greifen, auch keine
      // laufende Animation: der lange Druck auf den Kompass ruft in der
      // Quelle zuerst `m.stop()` (`screen-map.jsx:3164`).
      return MapCameraVerdict.execute(
        interruptsRunningAnimation: situation.isAnimating,
      );

    case MapCameraOneShot(:final bool yieldsToRunningAnimation):
      if (yieldsToRunningAnimation && situation.isAnimating) {
        return const MapCameraVerdict.suppressed(
          MapCameraSuppressionReason.runningAnimation,
        );
      }
      return MapCameraVerdict.execute(
        interruptsRunningAnimation: situation.isAnimating,
      );

    case MapCameraFollow():
      return _decideFollow(intent, situation, thresholds);
  }
}

MapCameraVerdict _decideFollow(
  MapCameraFollow intent,
  MapCameraSituation situation,
  MapCameraThresholds thresholds,
) {
  // 1. Der Host ist beschäftigt.
  if (situation.isAnimating) {
    return const MapCameraVerdict.suppressed(
      MapCameraSuppressionReason.runningAnimation,
    );
  }

  // 2. Der Nutzer fasst die Karte gerade an. Trifft nur Dauerabsichten, die
  //    das für sich erklärt haben: das Blickrichtungs-Folgen weicht (`:2837`),
  //    das GPS-Folgen nicht (`:2668`).
  if (intent.yieldsToUserGesture && situation.userIsGesturing) {
    return const MapCameraVerdict.suppressed(
      MapCameraSuppressionReason.userGesture,
    );
  }

  // 3. Die Blickrichtung ist eingerastet. Trifft nur Absichten, die sie
  //    anfassen: das GPS-Folgen verschiebt bloß den Mittelpunkt und läuft
  //    weiter, auch wenn der Nutzer die Karte gedreht hat.
  if (situation.bearingLocked && intent.change.changesBearing) {
    return const MapCameraVerdict.suppressed(
      MapCameraSuppressionReason.bearingLocked,
    );
  }

  // 4. Die Karenzzeit nach der letzten unerklärten Bewegung. Im Standard ist
  //    `manualMoveGrace` null, dann ist diese Bedingung nie wahr. Sie ist von
  //    Schritt 2 unabhängig: der eine misst eine laufende Geste, der andere
  //    ein Zeitfenster nach der letzten unerklärten Bewegung.
  final Duration? lastManualMove = situation.lastUnexplainedMoveAt;
  if (lastManualMove != null &&
      situation.now - lastManualMove < thresholds.manualMoveGrace) {
    return const MapCameraVerdict.suppressed(
      MapCameraSuppressionReason.manualMoveGrace,
    );
  }

  // 5. Strecken-Totzone. Die Quelle schreibt `> 12`, also ist genau die
  //    Schwelle noch zu wenig. Fehlt der Absicht die Schwelle, wird nicht
  //    gemessen: `MapCameraFollow` sichert zu, dass eine Dauerabsicht ohne
  //    alle drei Schwellen durchläuft, sobald keine Animation stört.
  final MapPosition? target = intent.change.center;
  final MapPosition? lastCenter = situation.lastFollowCenter;
  final double? deadZone = intent.deadZoneMeters;
  if (target != null && lastCenter != null && deadZone != null) {
    if (lastCenter.distanceInMetersTo(target) <= deadZone) {
      return const MapCameraVerdict.suppressed(
        MapCameraSuppressionReason.distanceDeadZone,
      );
    }
  }

  // 6. Winkel-Totzone, gerechnet über den kurzen Weg.
  //
  //    **Bewusste Abweichung von der Quelle, und sie ist eine Fehlerbehebung.**
  //    Gemessen wird hier gegen die aktuelle Blickrichtung der Kamera, die
  //    Quelle misst gegen ihren eigenen `lastAppliedBearing`
  //    (`screen-map.jsx:2836`). Dieser Wert führt die tatsächliche
  //    Kartenausrichtung **nicht** mit: fortgeschrieben wird er allein im
  //    Erfolgszweig des Folgens (`:2839`). Der lange Kompassdruck setzt
  //    `manualBearingRef = false` (`:3166`) und springt danach mit `jumpTo`
  //    auf Norden (`:3168`), ohne ihn anzufassen. Stand er vorher auf 90,
  //    steht er danach immer noch auf 90, während die Karte auf 0 zeigt: das
  //    Kompass-Folgen ist dort still tot, bis die Peilung um mehr als 1,5° von
  //    dem veralteten Wert abweicht, obwohl derselbe Druck es gerade
  //    ausdrücklich wieder eingeschaltet hat. Das ist ein Defekt der Quelle
  //    und keine Absicht, und gefundene Fehler werden hier behoben und nicht
  //    mitportiert. Gegen die echte Kartenausrichtung zu messen kann per
  //    Konstruktion nicht veralten. Ein Test sichert genau diesen Fall zu.
  final double? targetBearing = intent.change.bearing;
  final double? bearingDeadZone = intent.bearingDeadZoneDegrees;
  if (targetBearing != null && bearingDeadZone != null) {
    final double delta = shortestBearingDeltaDegrees(
      situation.view.bearing,
      targetBearing,
    ).abs();
    if (delta <= bearingDeadZone) {
      return const MapCameraVerdict.suppressed(
        MapCameraSuppressionReason.bearingDeadZone,
      );
    }
  }

  // 7. Mindestpause. Die Quelle schreibt `> 800`, also ist genau die Schwelle
  //    noch zu früh.
  final Duration? minPause = intent.minPause;
  final Duration? lastFollowAt = situation.lastFollowAt;
  if (minPause != null &&
      lastFollowAt != null &&
      situation.now - lastFollowAt <= minPause) {
    return const MapCameraVerdict.suppressed(
      MapCameraSuppressionReason.minPause,
    );
  }

  return const MapCameraVerdict.execute(interruptsRunningAnimation: false);
}

/// Hat der Nutzer die Blickrichtung selbst gedreht?
///
/// Das ist der Nachbau des Wächters aus `screen-map.jsx:1692`:
///
/// ```js
/// map.on('rotatestart', (e) => { if (e && e.originalEvent) manualBearingRef.current = true; });
/// ```
///
/// **Der Zusatz `e.originalEvent` ist tragend, und er fehlte einmal.** Ein
/// programmatisches `setBearing` feuert `rotatestart` ebenfalls, nur ohne
/// Originalereignis. Ohne den Wächter schaltete das Folgen der Blickrichtung
/// sich nach dem ersten Tick selbst ab: die Karte drehte sich genau einmal und
/// fror dann ein. Der Kommentar der Quelle über der Zeile beschreibt genau
/// das.
///
/// Deshalb ist diese Regel eine reine Funktion und keine Zeile im
/// Kartenwidget: sie ist ohne Karte und ohne Flutter prüfbar, und ein Test
/// darauf ist der einzige Schutz gegen dieselbe Verwechslung.
///
/// [hostIsSteering] ist `true`, solange der Host die Bewegung selbst
/// verursacht: während einer eigenen Animation **und** unmittelbar nachdem er
/// eine sofortige Änderung gesetzt hat. Nur auf die Animation zu schauen wäre
/// derselbe Fehler noch einmal, denn das Folgen der Blickrichtung arbeitet mit
/// `setBearing`, also sofort und ohne Animation (`screen-map.jsx:2838`).
///
/// ## Offene Frage für Schritt 12: wie lang ist „unmittelbar nachdem"
///
/// Hier steht keine Zahl, und das ist eine Lücke und keine Entscheidung. Ein
/// `setBearing` erzeugt eine Kamerarückmeldung, die erst einen oder mehrere
/// Frames später eintrifft. Endet [hostIsSteering] zu früh, hält der Host
/// seine eigene Drehung für die des Nutzers und rastet bei **jedem** Tick des
/// Kompass-Folgens ein; endet es zu spät, verschluckt er eine echte
/// Zwei-Finger-Drehung, die kurz danach beginnt. Zwischen „funktioniert" und
/// „friert nach dem ersten Tick ein" liegt genau diese Zahl.
///
/// **Sie ist ohne Gerät nicht zu bestimmen.** Zu messen wäre der Abstand
/// zwischen einem `setBearing` des Hosts und der zugehörigen Rückmeldung von
/// `OnCameraMoveCallback`, auf Android und auf iOS getrennt. Die Antwort
/// gehört in den Schritt, der den Host baut, und nicht in diesen Vertrag.
///
/// **Beantwortet in Schritt 12, und der Absatz oben ist an einer Stelle
/// falsch:** „endet es zu spät, verschluckt er eine echte Zwei-Finger-Drehung
/// kurz danach" klingt nach einem Preis von wenigen hundert Millisekunden. Ein
/// Fenster, das jeder eigene Aufruf verlängert, schließt sich aber gar nicht
/// mehr, solange der Kompass schneller tickt, als es lang ist, und dann rastet
/// **nie** etwas ein. Der Host beantwortet [hostIsSteering] deshalb nicht
/// allein nach der Zeit, sondern zusätzlich daran, ob die eintreffende
/// Blickrichtung zu seinem letzten eigenen Aufruf passt; die Zahl selbst steht
/// als Schätzwert bei `MapCameraHost.steeringGrace`.
///
/// ## Bekannte Abweichung: Drehen während einer Animation
///
/// Dreht der Nutzer, **während** der Host animiert, setzt die Quelle
/// `manualBearingRef = true`: der Wächter in `:1692` fragt `isEasing()` gar
/// nicht, ihm genügt `e.originalEvent`. Diese Fassung gibt bei
/// [hostIsSteering] bedingungslos `false` zurück, rastet also nicht ein.
///
/// Die Abweichung bleibt bewusst stehen, weil ihre Voraussetzung ungeprüft
/// ist: ob eine Zwei-Finger-Drehung während einer laufenden `animateCamera`
/// bei `maplibre_gl 0.26.2` überhaupt bis zur Kamera durchkommt, ist ohne
/// Gerät nicht messbar. **Die Messung, die es klärt:** eine Animation über
/// mehrere Sekunden starten, während sie läuft mit zwei Fingern drehen und
/// beobachten, ob die Kamera der Geste folgt oder die Animation zu Ende läuft.
/// Folgt sie der Geste, muss diese Funktion einen eigenen Eingang für
/// „Drehung mit Originalereignis" bekommen; läuft die Animation durch, ist die
/// Abweichung gegenstandslos.
///
/// [deadZoneDegrees] hält Rundungszittern der Kamera von der Sperre fern und
/// ist standardmäßig [MapCameraThresholds.manualBearingNoiseDegrees]. Das ist
/// bewusst **nicht** [MapCameraThresholds.bearingDeadZoneDegrees]: die Quelle
/// hat für diese Frage überhaupt keine Schwelle, und eine geteilte Zahl würde
/// zwei unabhängige Regeln aneinanderbinden.
bool isManualBearingChange({
  required double previousBearing,
  required double newBearing,
  required bool hostIsSteering,
  double deadZoneDegrees = MapCameraThresholds.manualBearingNoiseDegrees,
}) {
  if (hostIsSteering) {
    return false;
  }
  return shortestBearingDeltaDegrees(previousBearing, newBearing).abs() >
      deadZoneDegrees;
}

/// Löst [intent] das Einrasten der Blickrichtung wieder?
///
/// Die Gegenregel zu [isManualBearingChange], und sie ist eng: **nur** ein
/// [MapCameraCommand], der es ausdrücklich sagt. In der Quelle setzen genau
/// zwei Stellen `manualBearingRef.current = false`, beide am Kompassknopf
/// (`screen-map.jsx:3166` beim langen Druck, `:3182` beim kurzen). Keine
/// Einmal-Absicht und keine Dauerabsicht tut es, auch nicht der Sky-Fall und
/// nicht das Neuzentrieren für sich genommen.
///
/// Steht als freie Funktion und nicht als überschreibbarer Getter auf
/// [MapCameraIntent]: ein Getter mit Standard `false` lädt dazu ein, ihn in
/// einer Dauerabsicht auf `true` zu setzen, und damit wäre die Sperre in dem
/// Moment weg, in dem sie gebraucht wird.
bool releasesBearingLock(MapCameraIntent intent) =>
    intent is MapCameraCommand && intent.releasesBearingLock;

/// Leert [intent] den Anker der Strecken-Totzone?
///
/// Das Gegenstück zu [releasesBearingLock] für `lastCameraPosRef`
/// (`screen-map.jsx:2659-2661`), und ebenso eng: **nur** ein
/// [MapCameraCommand], der es ausdrücklich sagt. Der lange Druck auf den
/// Kompass tut es (`:3165`), der kurze nicht (`:3182-3183`, `recenter()` in
/// `:2983-2987` fasst den Anker nicht an).
///
/// Steht als freie Funktion und nicht als Getter auf [MapCameraIntent], aus
/// demselben Grund wie [releasesBearingLock]: eine Dauerabsicht, die ihren
/// eigenen Anker löschen darf, hätte gar keine Totzone mehr.
///
/// Die Domäne führt den Anker nicht; sie sagt dem Host nur, wann er ihn zu
/// leeren hat, bevor er die nächste [MapCameraSituation] zusammenstellt.
bool clearsFollowAnchor(MapCameraIntent intent) =>
    intent is MapCameraCommand && intent.clearsFollowAnchor;

/// Winkeldifferenz von [from] nach [to] über den kurzen Weg, in Grad.
///
/// Ergebnis liegt in `[-180, 180)`, positiv heißt im Uhrzeigersinn. 359° und 1°
/// sind damit 2° auseinander und nicht 358°.
///
/// Dieselbe Rechnung wie `screen-map.jsx:2836`:
/// `((a - b + 540) % 360) - 180`.
///
/// ## Werte außerhalb von `[0, 360)`
///
/// **Zugesichert, nicht nur behauptet: die Funktion ist für jede endliche
/// Eingabe richtig, auch für negative Blickrichtungen und für Werte über
/// 360°.** Sie normalisiert deshalb nichts vorab, das `%` erledigt es bereits.
/// Der Grund ist der Rest-Operator: Darts `%` liefert bei positivem Divisor
/// immer ein nicht-negatives Ergebnis, JavaScripts `%` übernimmt dagegen das
/// Vorzeichen des Dividenden. Für `from = 1000, to = 0` rechnet Dart
/// `(-460) % 360 = 260`, also `+80°`, und das stimmt: 1000° entspricht 280°.
/// JavaScript rechnet `-100` und kommt auf `-280°`. Der Nachbau ist hier also
/// tatsächlich der robustere, und Tests führen die Fälle vor.
///
/// Nicht zugesichert ist das Verhalten für `double.nan` und die Unendlichkeiten:
/// sie ergeben `NaN`, und jeder Vergleich damit ist `false`. Für dieses Gate
/// hieße das „nicht unterdrückt" und „nicht eingerastet". Ein Wächter dagegen
/// steht bewusst nicht hier: eine Blickrichtung entsteht aus einem Kompass
/// oder aus einer Kameraabfrage, und nach ADR-002 wächst die Prüfung mit einem
/// belegten Aufrufer, der solche Werte liefert.
double shortestBearingDeltaDegrees(double from, double to) =>
    (to - from + 540) % 360 - 180;
