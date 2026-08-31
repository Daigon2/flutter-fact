/// Der Karten-Host: er führt den Zustand, den `maplibre_gl 0.26.2` nicht
/// hergibt, und entscheidet mit der Domäne über jede Kameraabsicht.
///
/// ## Warum das ein eigenes Objekt ist und kein `State`
///
/// **Im Widget-Test entsteht nie ein `MapLibreMapController`.**
/// `MapLibreMap.build` gibt auf Android eine Plattform-Ansicht zurück
/// (`method_channel_maplibre_gl.dart:133-185`), ohne Plattformkanal läuft
/// `onPlatformViewCreated` nie, und damit erzeugt `maplibre_map.dart:390-418`
/// keinen Controller. Läge die Buchführung im `State` des Kartenwidgets, wäre
/// sie ausschließlich auf einem Gerät prüfbar: kein Test könnte zeigen, dass
/// `null` von `animateCamera` den Animationszustand stehen lässt, und genau
/// daran hängt auf iOS, ob die Karte überhaupt noch dem GPS folgt.
///
/// Dieses Objekt kennt deshalb kein Flutter-Widget und keinen `BuildContext`.
/// Es spricht über [MapCameraDriver] mit dem SDK und bekommt seine Zeit als
/// Funktion. Beides ist im Test ersetzbar.
library;

import 'dart:async';
import 'dart:math';

import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_gate.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:fact_app/map/presentation/map_auto_pitch.dart';
import 'package:fact_app/map/presentation/map_camera_driver.dart';
import 'package:fact_app/map/presentation/map_overlay_driver.dart';
import 'package:fact_app/map/presentation/map_overlay_host.dart';
import 'package:fact_app/map/presentation/map_projection_driver.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Was eine Dauerabsicht zuletzt getan hat.
///
/// Zwei Felder, die **getrennt** gelöscht werden: der lange Druck auf den
/// Kompass setzt in der Quelle `lastCameraPosRef.current = null`
/// (`screen-map.jsx:3165`) und lässt `lastCameraAtRef` unangetastet. Ein
/// gemeinsames Löschen wäre eine stille Verhaltensänderung.
@immutable
class _FollowRun {
  const _FollowRun({required this.at, this.center});

  /// Wann diese Dauerabsicht zuletzt ausgeführt wurde.
  final Duration at;

  /// Welchen Mittelpunkt sie zuletzt angefahren hat, oder `null`.
  ///
  /// `null` bei einer Dauerabsicht, die den Mittelpunkt gar nicht anfasst: das
  /// Folgen der Blickrichtung hat in der Quelle keinen Anker, und einen zu
  /// erfinden hieße, seiner Totzone eine Messung unterzuschieben, die es dort
  /// nicht gibt.
  final MapPosition? center;
}

/// Der letzte eigene Aufruf ans SDK: bis wann er zählt und wohin er zielte.
///
/// **Zwei Felder in einem Objekt, weil sie nur gemeinsam eine Aussage
/// ergeben.** „Bis 700 ms" allein beantwortet die Frage nicht, ob eine
/// eintreffende Bewegung vom Host kommt, siehe [MapCameraHost.steeringGrace];
/// erst zusammen mit „und ich habe auf 50° gezielt" wird daraus eine. Getrennt
/// als zwei nullbare Felder gäbe es Zustände, die es nicht gibt (Fenster ohne
/// Ziel), und einen Zweig im Code, den kein Test je erreicht.
@immutable
class _Steering {
  const _Steering({required this.until, required this.bearing});

  /// Bis zu diesem Zeitpunkt gilt eine passende Bewegung als eigene.
  final Duration until;

  /// Die Blickrichtung, die der Host zuletzt selbst gesetzt hat.
  final double bearing;
}

/// Führt Kamerazustand und Kameraabsichten einer Karte.
///
/// Lebt vom Mounten des Kartenwidgets bis zu dessen Entsorgen und wird über
/// `MapHostRegistry.attach` bekannt gemacht. Die Karte selbst kommt später:
/// bis [bindSurface] gerufen wurde, gibt es keine Kamera und keine
/// SDK-Verbindung.
///
/// ## Die Überlagerungen führt er nicht selbst
///
/// Seit Schritt 15 verlangt `MapHost` außer der Kamera auch Punkte und Bilder.
/// Dieses Objekt beantwortet die drei Methoden, **entscheidet aber nichts
/// davon**: es reicht sie an [MapOverlayHost] weiter, der seinen eigenen
/// Zustand und seine eigene Naht zum SDK hat. Die beiden teilen sich nichts
/// außer der Karte, und ihre Regeln sind gegensätzlich (Absicht verfällt,
/// Überlagerung bleibt liegen); in einem Objekt vermischt wären sie schwerer
/// zu lesen als in zweien.
///
/// **Der Name ist damit enger als die Aufgabe**, und das bleibt vorerst so:
/// `MapSurfaceHost` wäre die richtige Bezeichnung, die Umbenennung ist reine
/// Kosmetik über acht Dateien und gehört nicht in denselben Schritt wie die
/// Sache selbst.
class MapCameraHost implements MapHost {
  /// Erzeugt einen Host ohne Karte.
  ///
  /// [now] ist die Uhr, siehe [_now]. [thresholds] reicht der Host unverändert
  /// an das Gate weiter.
  MapCameraHost({
    DiagnosticSink diagnostics = const SilentDiagnosticSink(),
    MapCameraThresholds thresholds = const MapCameraThresholds(),
    Duration Function()? now,
  }) : _diagnostics = diagnostics,
       _thresholds = thresholds,
       _now = now ?? _stopwatchClock(),
       _overlays = MapOverlayHost(diagnostics: diagnostics);

  /// Gemeldet, wenn eine Absicht eintrifft, bevor eine Karte steht.
  static const String droppedEvent = 'map.host.intent_dropped';

  /// Gemeldet, wenn eine Projektion nicht auswertbar zurückkommt.
  ///
  /// Getrennt von [droppedEvent] und von `MapHostRegistry.missingHostEvent`,
  /// aus demselben Grund wie deren Trennung untereinander: „das SDK hat
  /// geantwortet, aber falsch" ist ein anderer Befund als „niemand hat
  /// zugehört", und ein gemeinsamer Name macht beide in jeder späteren
  /// Auswertung ununterscheidbar. **Ohne Karte feuert er ausdrücklich nicht**,
  /// das ist der Normalfall jedes Startvorgangs.
  static const String projectionFailedEvent = 'map.projection.failed';

  /// Wie lange nach einem eigenen SDK-Aufruf eintreffende Kamerabewegungen als
  /// eigene gelten.
  ///
  /// **Diese Zahl ist gewählt und nicht gemessen.** Ein `setBearing` erzeugt
  /// eine Rückmeldung, die erst einen oder mehrere Frames später eintrifft;
  /// endet das Fenster zu früh, hält der Host seine eigene Drehung für die des
  /// Nutzers und rastet bei jedem Tick des Kompass-Folgens ein.
  ///
  /// 200 ms sind rund zwölf Bilder bei 60 Hz, also reichlich für den Umweg
  /// über den Plattformkanal, und kürzer als jede menschliche Geste, die auf
  /// eine Kamerabewegung folgt. Zu messen wäre der Abstand zwischen einem
  /// eigenen Aufruf und der zugehörigen Rückmeldung, auf Android und iOS
  /// getrennt. **Bis dahin ist das ein Schätzwert, der so gekennzeichnet
  /// bleibt.**
  ///
  /// ## Was ein zu langes Fenster kostet, und was es ausdrücklich nicht kostet
  ///
  /// Ein früherer Kommentar an dieser Stelle sagte, ein zu spät endendes
  /// Fenster verschlucke „eine echte Zwei-Finger-Drehung kurz danach". Das
  /// stand für einen bekannten Preis von 200 ms und war **falsch**: das
  /// Fenster verlängert sich mit jedem eigenen Aufruf, und ein Kompass-Folgen
  /// tickt schneller, als es lang ist. Solange es folgt, wäre das Fenster
  /// **dauerhaft** offen und die Blickrichtung gar nicht mehr einrastbar,
  /// also genau in der Lage, in der Vorrangregel 2 gebraucht wird.
  ///
  /// Deshalb ist die Frage „steuert der Host gerade" seit dieser Behebung
  /// nicht mehr allein eine Frage der Zeit, siehe [_hostIsSteering]: eine
  /// Drehung, die **nicht** zu dem passt, was der Host zuletzt selbst gesetzt
  /// hat, gilt trotz offenem Fenster als Drehung des Nutzers. Was ein zu
  /// langes Fenster weiterhin verschluckt, ist ein Schieben oder Zoomen des
  /// Nutzers unmittelbar nach einem eigenen Aufruf.
  static const Duration steeringGrace = Duration(milliseconds: 200);

  final DiagnosticSink _diagnostics;
  final MapCameraThresholds _thresholds;

  /// Der Teil, der Bilder und Überlagerungen führt. Siehe Klassenkommentar.
  final MapOverlayHost _overlays;

  /// Jetzt, als Abstand zu einem monotonen Nullpunkt.
  ///
  /// ## Warum hier keine `DateTime.now()` und kein neues Paket steht
  ///
  /// Die Domäne rechnet ausdrücklich mit einer monotonen [Duration] und nicht
  /// mit Wanduhrzeit (`map_camera_gate.dart`, „Keine Uhr in der Domäne"):
  /// `DateTime.now()` kann rückwärts springen, während eine Karenzzeit läuft.
  /// `package:clock` wäre ein neues Paket, also freigabepflichtig, und liefert
  /// genau die Wanduhrzeit, die hier ausgeschlossen ist.
  ///
  /// **Und es entsteht bewusst kein `lib/core/time/`**, obwohl
  /// `docs/architecture/project-structure.md:38` das Verzeichnis vorsieht: es
  /// gäbe genau einen Aufrufer. Die Wachstumsregel dieses Projekts (ADR-002)
  /// verlangt einen belegten zweiten, bevor etwas nach `core` wandert.
  ///
  /// **Ungeprüft und deshalb hier vermerkt:** eine [Stopwatch] zählt auf iOS
  /// vermutlich nicht weiter, während das Gerät schläft. Bei Fenstern von
  /// 800 ms ist das folgenlos, und im Zweifel fällt es zur richtigen Seite
  /// aus: nach dem Aufwachen wirkt eine Pause kürzer als sie war, die Karte
  /// wartet also eher zu lange als zu kurz.
  final Duration Function() _now;

  /// Meldet jede Kamerabewegung. Siehe [cameraChanges].
  ///
  /// `broadcast`, aus demselben Grund wie `MapOverlayHost._groupTaps`
  /// (`map_overlay_host.dart:98-117`, dort ausführlich mit den Fundstellen):
  /// diesen Strom abonniert zur Laufzeit genau ein Hörer,
  /// `MapHostRegistry.attach` (`map_host_providers.dart:149`), nicht
  /// mehrere. `attach` kehrt nur bei einem bereits eingeklinkten,
  /// identischen Host früh zurück, `detach` löst nur die Kennung, ohne den
  /// Host selbst anzufassen. Die Folge `attach(a)`, `detach(a)`,
  /// `attach(a)` hört damit zweimal auf denselben Strom, und ohne
  /// `broadcast` wirft das zweite `listen`, auch nach einem `cancel` des
  /// ersten. Siehe die Probe „überlebt attach, detach, attach mit demselben
  /// Host" in `map_host_providers_test.dart`.
  final StreamController<MapCameraView> _cameraChanges =
      StreamController<MapCameraView>.broadcast();

  MapCameraDriver? _driver;
  MapCameraView? _camera;

  /// Die zuletzt gemeldete Größe der Kartenfläche, oder `null`, siehe
  /// [viewport].
  MapViewport? _viewport;

  /// Die Naht, über die Koordinaten zu Bildschirmlagen werden.
  MapProjectionDriver? _projections;

  Duration? _animationStartedAt;
  Duration? _animationEndsAt;

  /// Zählt jede gestartete Animation mit.
  ///
  /// Die Antwort von [MapCameraDriver.animate] trifft asynchron ein, und bis
  /// dahin kann längst eine neue Animation laufen. Ohne diese Marke würde die
  /// späte Antwort einer abgebrochenen Animation den Zustand der aktuellen
  /// löschen, und die nächste Dauerabsicht liefe mitten in die laufende
  /// Bewegung.
  int _animationToken = 0;

  _Steering? _steering;
  bool _userIsGesturing = false;
  Duration? _lastUnexplainedMoveAt;
  bool _bearingLocked = false;
  double? _zoomAtLastRest;

  final Map<MapCameraFollowKind, _FollowRun> _followRuns =
      <MapCameraFollowKind, _FollowRun>{};

  /// Ob die Blickrichtung eingerastet ist. Nur für Tests.
  @visibleForTesting
  bool get debugBearingLocked => _bearingLocked;

  /// Ob der Nutzer die Karte gerade anfasst. Nur für Tests.
  @visibleForTesting
  bool get debugUserIsGesturing => _userIsGesturing;

  /// Wann zuletzt eine unerklärte Bewegung eintraf. Nur für Tests.
  @visibleForTesting
  Duration? get debugLastUnexplainedMoveAt => _lastUnexplainedMoveAt;

  /// Das geplante Ende der laufenden Animation, sonst `null`. Nur für Tests.
  ///
  /// Es gibt diesen Zugang, weil „der Animationszustand ist gelöscht" sonst
  /// nicht von „die Animation ist nur abgelaufen" zu unterscheiden wäre. Beide
  /// sehen an jedem Urteil des Gates gleich aus, und genau die Unterscheidung
  /// ist der Kern von Fakt 5 zu `animateCamera`.
  @visibleForTesting
  Duration? get debugAnimationEndsAt => _animationEndsAt;

  /// Der Anker der Strecken-Totzone einer Dauerabsicht. Nur für Tests.
  @visibleForTesting
  MapPosition? debugFollowAnchor(MapCameraFollowKind kind) =>
      _followRuns[kind]?.center;

  /// Der Teil, der Bilder und Überlagerungen führt. Nur für Tests.
  ///
  /// Es gibt diesen Zugang, weil die Durchreichungen dieses Objekts sonst
  /// nur über ein erneutes [bindSurface] beobachtbar wären, und nach [dispose]
  /// ist das nicht mehr möglich: der Kamerastrom ist dann geschlossen und
  /// [bindSurface] würde werfen. Ein `dispose`, das den Überlagerungsteil
  /// vergisst, wäre ohne ihn unprüfbar.
  @visibleForTesting
  MapOverlayHost get debugOverlays => _overlays;

  /// Die Karte steht: ab jetzt gibt es eine Kamera und einen Weg zum SDK.
  ///
  /// Ruft das Kartenwidget aus `onMapCreated`. [camera] ist die Startkamera,
  /// die dem Widget mitgegeben wurde: `maplibre_gl` meldet ohne eine Bewegung
  /// nichts, und ohne einen Startwert wäre [camera] bis zur ersten Geste des
  /// Nutzers `null`, obwohl die Karte längst steht.
  ///
  /// [overlays] ist die zweite Naht zum SDK und bewusst optional: ein Test, der
  /// nur die Kamera prüft, soll keinen Überlagerungs-Doppelgänger mitbringen
  /// müssen. Fehlt sie, bleiben gesetzte Überlagerungen liegen, bis eine Karte
  /// mit Naht kommt; verloren geht nichts.
  ///
  /// **Und deshalb löst ein Binden ohne [overlays] die alte Naht ausdrücklich.**
  /// Ohne diese Zeile gälte die Zusage oben nur beim ersten Mal: ein zweites
  /// [bindSurface] ohne Überlagerungen tauschte den Kamera-Treiber aus und
  /// ließe die Naht der **alten** Karte stehen, der Host schriebe also weiter
  /// in Quellen, die zu einer Karte gehören, die es nicht mehr gibt. Der Fall
  /// ist heute nicht erreichbar, `MapSurface` gibt immer beides mit; er steht
  /// hier, weil eine Zusage, die nur unter einer ungeschriebenen Bedingung
  /// gilt, später als belegt gelesen wird.
  void bindSurface({
    required MapCameraDriver driver,
    required MapCameraView camera,
    MapOverlayDriver? overlays,
    MapProjectionDriver? projections,
  }) {
    _driver = driver;
    _camera = camera;
    _zoomAtLastRest = camera.zoom;
    if (overlays != null) {
      _overlays.bindSurface(overlays);
    } else {
      _overlays.unbindSurface();
    }
    // Dieselbe Zusage wie bei [overlays] und aus demselben Grund: ein zweites
    // Binden ohne Projektionsnaht darf nicht die Naht der **alten** Karte
    // stehen lassen.
    _projections = projections;
    _cameraChanges.add(camera);
  }

  /// Die Karte ist weg. Der Host lebt weiter und verwirft Absichten wieder.
  ///
  /// **Löscht auch [_viewport], anders als [bindSurface].** Eine Fläche ohne
  /// Karte ist keine Aussage über irgendetwas: die nächste Karte kann in einem
  /// ganz anderen Teil des Baums entstehen. `MapSurface` meldet die zuletzt
  /// gemessene Größe deshalb beim nächsten Binden erneut, aus ihrem eigenen
  /// `State` heraus und nicht aus einem `LayoutBuilder`-Aufbau, der zwischen
  /// Entsorgen und Neuaufbau gar nicht erneut läuft.
  void unbindSurface() {
    _driver = null;
    _camera = null;
    _viewport = null;
    _zoomAtLastRest = null;
    _clearAnimation();
    _steering = null;
    _userIsGesturing = false;
    _projections = null;
    _overlays.unbindSurface();
  }

  /// Schließt den Kamerastrom. Ruft das Kartenwidget beim Entsorgen.
  void dispose() {
    unbindSurface();
    _overlays.dispose();
    unawaited(_cameraChanges.close());
  }

  // ---------------------------------------------------------------------------
  // Rückrufe des SDK
  // ---------------------------------------------------------------------------

  /// Das SDK meldet eine Kamerabewegung.
  ///
  /// **Hier entsteht „der Nutzer hat angefasst".** `maplibre_gl 0.26.2` nennt
  /// keine Ursache: `OnCameraMoveCallback` ist
  /// `void Function(CameraPosition)`, und die Ursache, die Android auf dem
  /// Kanal wirklich sendet, wirft `method_channel_maplibre_gl.dart:48-49` weg
  /// (`onCameraMoveStartedPlatform(null)`). iOS sendet sie gar nicht erst. Der
  /// Umweg über die **unerklärte Bewegung** ist deshalb alternativlos: eine
  /// Bewegung, die eintrifft, während der Host nicht selbst steuert, war der
  /// Nutzer.
  void handleCameraMove(MapCameraView view) {
    final MapCameraView? previous = _camera;
    _camera = view;
    _cameraChanges.add(view);
    _expireAnimation(view);

    if (_hostIsSteering(view)) {
      return;
    }

    // Löschweg 3 des Animationszustands: es bewegt sich etwas, das der Host
    // nicht verursacht hat, also ist seine eigene Bewegung vorbei.
    _clearAnimation();
    _userIsGesturing = true;
    _lastUnexplainedMoveAt = _now();

    if (previous != null &&
        isManualBearingChange(
          previousBearing: previous.bearing,
          newBearing: view.bearing,
          // An dieser Stelle steuert der Host nachweislich nicht, sonst wäre
          // oben schon zurückgekehrt worden.
          hostIsSteering: false,
        )) {
      _bearingLocked = true;
    }
  }

  /// Das SDK meldet, dass die Kamera zur Ruhe gekommen ist.
  ///
  /// Der Rückruf trägt keine Kameraangabe: `OnCameraIdleCallback` ist
  /// `void Function()` (`maplibre_gl 0.26.2`, `lib/src/controller.dart:61`).
  /// Der Host arbeitet deshalb mit der zuletzt gemeldeten Kamera, die vor
  /// jedem Stillstand über [handleCameraMove] eingetroffen ist.
  void handleCameraIdle() {
    // Löschweg 2: die Karte steht still, also läuft auch keine eigene
    // Animation mehr, egal was ihr geplantes Ende sagt.
    _clearAnimation();
    // Das einzige Ende, das das SDK für eine Geste hergibt.
    _userIsGesturing = false;

    final MapCameraView? view = _camera;
    if (view == null) {
      return;
    }

    final double? previousRestZoom = _zoomAtLastRest;
    _zoomAtLastRest = view.zoom;
    if (previousRestZoom == null || previousRestZoom == view.zoom) {
      // Kein Zoom-Ende, sondern ein Schwenk oder eine Drehung.
      return;
    }

    final MapCameraOneShot? autoPitch = mapAutoPitchIntent(view);
    if (autoPitch != null) {
      submitIntent(autoPitch);
    }
  }

  /// `MapSurface` meldet die gemessene Größe der Kartenfläche.
  ///
  /// Ruft `MapSurface` aus dem `builder` seines `LayoutBuilder`, **nicht** nur
  /// aus `_onMapCreated`: das Layout der Fläche steht schon, bevor die Karte
  /// gemountet ist, und ändert sich unabhängig von jeder Kamerabewegung, etwa
  /// bei einer Drehung des Geräts.
  ///
  /// **Hält den Wert nur, ohne selbst zu vergleichen.** Ob sich die Größe
  /// wirklich geändert hat, entscheidet `MapSurface`, bevor sie ruft: sie hält
  /// die zuletzt gemeldete Größe in ihrem eigenen `State`, weil sie sie auch
  /// beim erneuten Binden ohne neuen Aufbau braucht (siehe dort). Eine zweite
  /// Prüfung hier wäre nur eine zweite Kopie desselben Vergleichs.
  void handleViewportChange(MapViewport viewport) {
    _viewport = viewport;
  }

  /// Das SDK meldet einen Tipp. Ruft die Kartenfläche aus
  /// `controller.onFeatureTapped.add(...)`.
  ///
  /// Reicht durch, siehe Klassenkommentar: die Zuordnung des getroffenen
  /// Layers zu einer Überlagerung gehört [MapOverlayHost], der besitzt die
  /// Kennungen.
  void handleFeatureTapped({required String layerId, required LatLng at}) =>
      _overlays.handleFeatureTapped(layerId: layerId, at: at);

  // ---------------------------------------------------------------------------
  // MapHost
  // ---------------------------------------------------------------------------

  @override
  MapCameraView? get camera => _camera;

  @override
  Stream<MapCameraView> get cameraChanges => _cameraChanges.stream;

  @override
  MapViewport? get viewport => _viewport;

  @override
  Stream<MapOverlayGroupTap> get groupTaps => _overlays.groupTaps;

  /// Nimmt eine Absicht an, fragt das Gate und führt aus oder meldet.
  ///
  /// ## Absichten vor der ersten Karte werden fallen gelassen
  ///
  /// Der Vertrag in `map_host.dart` hält diese Frage ausdrücklich offen und
  /// nennt drei Antworten: fallen lassen, die letzte aufheben und nachholen,
  /// oder alle aufheben. **Hier ist es „fallen lassen", mit eigenem
  /// Diagnose-Ereignis.**
  ///
  /// Der Grund ist der Bestand an Aufrufern: der einzige belegte Fall für
  /// „aufheben und nachholen" ist der Sky-Fall, der sich in der Quelle in
  /// einem Ref merkt und später gerufen wird (`screen-map.jsx:1743-1747`).
  /// Den gibt es in diesem Schritt nicht. Eine Warteschlange auf Vorrat wäre
  /// Zustand, den niemand prüft, und ADR-002 lässt die Struktur mit dem
  /// belegten Bedarf wachsen.
  ///
  /// **Der Auslöser, ab dem das zu ändern ist:** die erste Absicht, die
  /// zuverlässig vor dem Mounten der Karte entsteht. Dann ist die Antwort
  /// „die letzte aufheben und beim Binden nachholen", und die Stelle dafür ist
  /// [bindSurface].
  @override
  void submitIntent(MapCameraIntent intent) {
    final MapCameraDriver? driver = _driver;
    final MapCameraView? view = _camera;
    if (driver == null || view == null) {
      _report(droppedEvent, intent, <String, String>{'cause': 'no_surface'});
      return;
    }

    _expireAnimation(view);

    final MapCameraVerdict verdict = decideMapCameraIntent(
      intent: intent,
      situation: _situationFor(view, intent),
      thresholds: _thresholds,
    );

    final MapCameraSuppressionReason? reason = verdict.reason;
    if (reason != null) {
      _report(MapHostRegistry.suppressedEvent, intent, <String, String>{
        'reason': reason.name,
      });
      return;
    }

    _execute(driver, intent, view, verdict);
  }

  /// Reicht durch, siehe Klassenkommentar.
  @override
  void registerOverlayImages(List<MapOverlayImage> images) =>
      _overlays.registerImages(images);

  /// Reicht durch, siehe Klassenkommentar.
  @override
  void setOverlay(MapOverlay overlay) => _overlays.setOverlay(overlay);

  /// Reicht durch, siehe Klassenkommentar.
  @override
  void removeOverlay(String overlayId) => _overlays.removeOverlay(overlayId);

  /// Rechnet Koordinaten in Bildschirmlagen um. Siehe `MapHost`.
  ///
  /// ## Vier Fälle, und drei davon sind Ausfälle des Pakets
  ///
  /// 1. **Keine Karte.** Ohne Naht gibt es keine Kamera, also auch keine
  ///    Bildschirmlage. Kommt als lauter `null` zurück, ohne Meldung: das ist
  ///    der Normalfall jedes Startvorgangs, genau wie bei einer Überlagerung,
  ///    die vor der Karte eintrifft.
  /// 2. **Die Antwort ist zu kurz.** Die Kanalfassung baut ihre Liste stumpf
  ///    aus einer `Float64List`, zwei Zahlen je Punkt
  ///    (`method_channel_maplibre_gl.dart:598-613`). Kommt von der Plattform
  ///    ein kürzeres Feld, wäre eine elementweise Zuordnung **verschoben**,
  ///    und jeder Ballon säße auf der Koordinate seines Nachbarn. Deshalb wird
  ///    die ganze Antwort verworfen und gemeldet, statt sie halb zu benutzen.
  /// 3. **Eine Zahl, die keine ist.** Ein Punkt hinter dem Horizont ist bei
  ///    58 Grad Neigung ein realer Fall, und das Paket widerspricht sich, was
  ///    dann kommt (`controller.dart:1784` gegen `:1785`). `NaN` und
  ///    `Infinity` fallen deshalb einzeln als `null` heraus.
  /// 4. **Der Kanal wirft.** Kommt als lauter `null` zurück und wird gemeldet.
  ///
  /// **Gemeldet und nicht geworfen.** Ein Aufrufer, der 60-mal je Sekunde
  /// projiziert, kann mit einer Ausnahme nichts anfangen; er zeichnet dann
  /// eben nichts, und der nächste Kameratakt versucht es erneut.
  @override
  Future<List<MapScreenPoint?>> projectToScreen(
    List<MapPosition> positions,
  ) async {
    final List<MapScreenPoint?> nothing = List<MapScreenPoint?>.filled(
      positions.length,
      null,
    );
    final MapProjectionDriver? projections = _projections;
    if (projections == null || positions.isEmpty) {
      return nothing;
    }

    final List<Point<num>> screen;
    try {
      screen = await projections.toScreenLocationBatch(
        positions.map(
          (MapPosition position) =>
              LatLng(position.latitude, position.longitude),
        ),
      );
    } on Object catch (error) {
      _diagnostics.report(
        DiagnosticEvent(projectionFailedEvent, <String, String>{
          'count': '${positions.length}',
          'reason': error.runtimeType.toString(),
        }),
      );
      return nothing;
    }

    if (screen.length != positions.length) {
      _diagnostics.report(
        DiagnosticEvent(projectionFailedEvent, <String, String>{
          'count': '${positions.length}',
          'reason': 'length:${screen.length}',
        }),
      );
      return nothing;
    }

    return <MapScreenPoint?>[
      for (final Point<num> point in screen)
        if (point.x.isFinite && point.y.isFinite)
          MapScreenPoint(
            xInScreenPixels: point.x.toDouble(),
            yInScreenPixels: point.y.toDouble(),
          )
        else
          null,
    ];
  }

  // ---------------------------------------------------------------------------
  // Innenleben
  // ---------------------------------------------------------------------------

  void _execute(
    MapCameraDriver driver,
    MapCameraIntent intent,
    MapCameraView view,
    MapCameraVerdict verdict,
  ) {
    if (releasesBearingLock(intent)) {
      _bearingLocked = false;
    }
    if (clearsFollowAnchor(intent)) {
      _clearFollowAnchors();
    }

    if (_touchesNothing(intent.change)) {
      // **Eine Änderung, die nichts ändert, fasst die Kamera nicht an.** Das
      // ist keine Abkürzung, sondern der Vertrag: `MapCameraChange` sagt
      // ausdrücklich, alle vier Felder `null` heiße „nichts tun", und „der
      // Host hat nichts zu tun" (`map/domain/map_camera.dart`).
      //
      // **Was ein Aufruf hier anrichtet, und zwar ohne jede Ortung.** Ein
      // `jump` auf `_resolve(leere Änderung, view)` setzt die Kamera auf die
      // zuletzt gemeldete Stellung. Läuft gerade eine Animation, ist das ihre
      // **Zwischenstellung**, und die Bewegung friert dort ein. Der belegte
      // Fall ist der Kompass-Tipp ohne Ortungsfreigabe: der Nutzer zoomt,
      // `handleCameraIdle` gibt die Auto-Neigung ab (300 ms, ohne jeden
      // Ortsbezug), er tippt in diesem Fenster den Kompass, und die Neigung
      // bliebe auf halbem Weg stehen. Die Quelle macht dort **gar keinen**
      // Kameraaufruf (`screen-map.jsx:3175-3185`, `recenter` kehrt ohne
      // Position sofort zurück), ihr `easeTo` läuft zu Ende.
      //
      // **Vorrangregel 1 bleibt unangetastet.** Der Befehl wird ausgeführt,
      // seine Nebenwirkungen sind oben schon passiert; es gibt nur nichts zu
      // bewegen. Deshalb bleibt hier auch der Animationszustand stehen: das
      // Verwerfen ist die Ersatzhandlung für das fehlende `stop()` des
      // Pakets, und wo keine neue Bewegung gesetzt wird, ist auch nichts
      // abgebrochen worden. Ein gelöschter Zustand hieße dagegen „es läuft
      // nichts", während das SDK weiter animiert, und die nächste
      // Dauerabsicht liefe mitten hinein.
      //
      // Aus demselben Grund entsteht kein [_FollowRun]: eine Dauerabsicht,
      // die nichts bewegt hat, darf die nächste nicht mit ihrer Mindestpause
      // ausbremsen. Erreichbar ist das heute nicht, beide Sorten bringen eine
      // Änderung mit.
      return;
    }

    if (verdict.interruptsRunningAnimation) {
      // `maplibre_gl 0.26.2` hat weder `stop()` noch `cancel()`. Der Abbruch
      // besteht darin, die neue Bewegung zu setzen und den eigenen
      // Animationszustand zu verwerfen; bliebe er stehen, hielte der Host die
      // abgebrochene Animation für laufend und unterdrückte grundlos.
      _clearAnimation();
    }

    final MapCameraView target = _resolve(intent.change, view);
    final Duration now = _now();

    switch (intent.motion) {
      case MapCameraAnimated(:final Duration duration):
        _animationStartedAt = now;
        _animationEndsAt = now + duration;
        _steerTo(now + duration + steeringGrace, target.bearing);
        final int token = ++_animationToken;
        reportDetached(
          driver
              .animate(target, duration)
              .then((bool? result) => _onAnimationResult(token, result)),
          origin: 'map.host.animate',
        );
      case MapCameraImmediate():
        _steerTo(now + steeringGrace, target.bearing);
        reportDetached(driver.jump(target), origin: 'map.host.jump');
    }

    if (intent is MapCameraFollow) {
      _followRuns[intent.kind] = _FollowRun(
        at: now,
        // Nur eine Dauerabsicht, die den Mittelpunkt wirklich anfasst, setzt
        // den Anker. Sonst bliebe der alte stehen, wie in der Quelle.
        //
        // **Mit den heutigen zwei Sorten ist der Rückfall nicht erreichbar**,
        // und das steht hier, damit niemand ihn für geprüft hält: das
        // GPS-Folgen bringt immer einen Mittelpunkt mit, das Folgen der
        // Blickrichtung nie, sein Anker ist also stets schon `null`. Der Fall
        // „dieselbe Sorte einmal mit und einmal ohne Mittelpunkt" entsteht
        // erst mit einer dritten Dauerabsicht. Der Rückfall bleibt trotzdem
        // stehen, weil ihn zu entfernen die Regel der Quelle aus dem Code
        // nähme und der nächste Aufrufer sie neu erfinden müsste.
        center: intent.change.center ?? _followRuns[intent.kind]?.center,
      );
    }
  }

  /// Die Antwort von [MapCameraDriver.animate] ist da.
  ///
  /// **`null` löscht nichts.** Auf iOS liefert `animateCamera` immer sofort
  /// `null` (`maplibre_gl 0.26.2`, `lib/src/controller.dart:409-416`), das ist
  /// also keine Aussage über die Animation, sondern ihre Abwesenheit. Wer
  /// `null` wie `false` behandelt, löscht auf iOS den Animationszustand im
  /// selben Atemzug, in dem er ihn gesetzt hat: jede Dauerabsicht liefe dann
  /// mitten in die laufende Bewegung.
  ///
  /// `true` und `false` löschen beide, denn beide heißen „nicht mehr am
  /// Laufen": erfolgreich beendet oder abgebrochen.
  void _onAnimationResult(int token, bool? result) {
    if (result == null || token != _animationToken) {
      return;
    }
    _clearAnimation();
  }

  MapCameraSituation _situationFor(
    MapCameraView view,
    MapCameraIntent? intent,
  ) {
    final _FollowRun? run = intent is MapCameraFollow
        ? _followRuns[intent.kind]
        : null;
    return MapCameraSituation(
      view: view,
      now: _now(),
      animationStartedAt: _animationStartedAt,
      animationEndsAt: _animationEndsAt,
      userIsGesturing: _userIsGesturing,
      lastUnexplainedMoveAt: _lastUnexplainedMoveAt,
      bearingLocked: _bearingLocked,
      lastFollowAt: run?.at,
      lastFollowCenter: run?.center,
    );
  }

  /// Ob die Bewegung, die gerade eintrifft, vom Host kommt.
  ///
  /// Zwei Quellen: eine laufende eigene Animation, und das kurze Fenster nach
  /// einem eigenen Aufruf ([steeringGrace]). Die Frage „läuft eine Animation"
  /// beantwortet ausschließlich `MapCameraSituation.isAnimating`, damit die
  /// Regel nicht an zwei Stellen steht und auseinanderlaufen kann.
  ///
  /// ## Warum das Fenster allein nicht reicht
  ///
  /// **Ein Fenster, das jeder eigene Aufruf verlängert, schließt sich nie,
  /// solange der Host folgt.** Das Blickrichtungs-Folgen arbeitet mit
  /// `MapCameraImmediate` und tickt so schnell, wie der Kompass liefert; bei
  /// einem Tick alle 100 ms stünde hier dauerhaft `true`, [handleCameraMove]
  /// kehrte vor [isManualBearingChange] zurück, und eine echte
  /// Zwei-Finger-Drehung rastete **nie** ein. Vorrangregel 2 wäre genau in der
  /// Lage außer Kraft, für die es sie gibt: der Nutzer übernimmt die Karte,
  /// **während** der Kompass sie dreht. Die Quelle rastet dort bedingungslos
  /// ein, `screen-map.jsx:1692` fragt allein `e.originalEvent`.
  ///
  /// Deshalb prüft das offene Fenster zusätzlich, ob die eintreffende
  /// Blickrichtung zu der passt, die der Host zuletzt selbst gesetzt hat.
  /// Weicht sie um mehr als das Rundungszittern ab, hat sie kein eigener
  /// Aufruf verursacht, und sie gilt als Bewegung des Nutzers.
  ///
  /// **Gemessen wird nur die Blickrichtung, und das ist Absicht.** Das Fenster
  /// gibt es für die verzögerte Rückmeldung eines `setBearing`; Mittelpunkt
  /// und Zoom eines Nutzers im selben Moment bleiben verschluckt, wie bisher.
  /// Sie so zu prüfen hieße, drei Toleranzen zu erfinden, für die es keine
  /// Fundstelle gibt.
  ///
  /// **Die Toleranz ist [MapCameraThresholds.manualBearingNoiseDegrees], und
  /// das ist eine Wahl.** Sie beantwortet hier dieselbe Frage wie dort, „ist
  /// diese Drehung Rauschen oder echt", deshalb dieselbe Zahl statt einer
  /// neuen erfundenen. **Ungeprüft und ohne Gerät nicht zu klären:** ob das
  /// SDK nach einem `moveCamera` wirklich die gesetzte Blickrichtung
  /// zurückmeldet. Käme sie um mehr als 0,25 Grad verändert zurück, hielte der
  /// Host seinen eigenen Sprung für eine Nutzerdrehung und rastete ein. Zu
  /// messen ist das zusammen mit [steeringGrace], im selben Gerätelauf.
  ///
  /// Während einer **laufenden Animation** bleibt es beim bedingungslosen
  /// `true`: dort steht die Kamera zwischen Start und Ziel, ein Vergleich mit
  /// dem Ziel wäre bei jedem Zwischenbild falsch. Das ist die bekannte
  /// Abweichung, die `isManualBearingChange` beschreibt, und sie bleibt
  /// bewusst stehen.
  bool _hostIsSteering(MapCameraView view) {
    if (_situationFor(view, null).isAnimating) {
      return true;
    }
    final _Steering? steering = _steering;
    if (steering == null || _now() >= steering.until) {
      return false;
    }
    return shortestBearingDeltaDegrees(steering.bearing, view.bearing).abs() <=
        MapCameraThresholds.manualBearingNoiseDegrees;
  }

  /// Schreibt fest, bis wann und wohin der Host zuletzt selbst gesteuert hat.
  ///
  /// Das Ende wird verlängert und nie verkürzt: eine Animation über zwei
  /// Sekunden darf ein Sprung, der währenddessen dazwischenfährt, nicht auf
  /// 200 ms zusammenstreichen. Die Blickrichtung dagegen ist immer die des
  /// **letzten** Aufrufs, denn nur sie sagt etwas darüber, was das SDK gleich
  /// zurückmelden wird.
  void _steerTo(Duration until, double bearing) {
    final _Steering? current = _steering;
    _steering = _Steering(
      until: current == null || until > current.until ? until : current.until,
      bearing: bearing,
    );
  }

  /// Löschweg 1: die mitgegebene Dauer ist um.
  void _expireAnimation(MapCameraView view) {
    if (_animationEndsAt == null) {
      return;
    }
    if (!_situationFor(view, null).isAnimating) {
      _clearAnimation();
    }
  }

  void _clearAnimation() {
    _animationStartedAt = null;
    _animationEndsAt = null;
  }

  /// Leert die Anker aller Dauerabsichten, lässt die Zeitpunkte stehen.
  ///
  /// Genau das tut der lange Druck auf den Kompass: `screen-map.jsx:3165`
  /// setzt `lastCameraPosRef.current = null` und fasst `lastCameraAtRef` nicht
  /// an. Ohne das unterdrückte das Gate den nächsten GPS-Fix mit der
  /// Strecken-Totzone, während die Quelle ihn ausführt.
  void _clearFollowAnchors() {
    for (final MapCameraFollowKind kind in _followRuns.keys.toList()) {
      _followRuns[kind] = _FollowRun(at: _followRuns[kind]!.at);
    }
  }

  /// Ob diese Änderung die Kamera überhaupt anfasst.
  ///
  /// Die Frage steht hier und nicht in der Domäne: sie ist keine Regel über
  /// Absichten, sondern die Antwort des Hosts darauf, wann er das SDK ruft.
  /// [MapCameraChange] selbst hält den Fall bereits fest, siehe dort.
  static bool _touchesNothing(MapCameraChange change) =>
      change.center == null &&
      change.zoom == null &&
      change.bearing == null &&
      change.pitch == null;

  /// Füllt die Lücken einer [MapCameraChange] mit dem Ist-Zustand.
  ///
  /// `null` heißt „unverändert lassen", nicht „auf null setzen". Der Fehler
  /// wäre lautlos: eine Absicht, die nur die Neigung angibt, zöge die Karte
  /// sonst zusätzlich auf Zoom 0 und Norden.
  static MapCameraView _resolve(MapCameraChange change, MapCameraView view) =>
      MapCameraView(
        center: change.center ?? view.center,
        zoom: change.zoom ?? view.zoom,
        bearing: change.bearing ?? view.bearing,
        pitch: change.pitch ?? view.pitch,
      );

  /// Meldet eine verlorene oder unterdrückte Absicht.
  ///
  /// Nur flache Zeichenketten, und **keine Koordinaten**:
  /// `docs/engineering/security.md` §6 verbietet genaue Standortangaben im
  /// Log, und der Mittelpunkt einer Absicht ist regelmäßig die Nutzerposition.
  void _report(
    String name,
    MapCameraIntent intent,
    Map<String, String> attributes,
  ) {
    _diagnostics.report(
      DiagnosticEvent(name, <String, String>{
        'origin': intent.origin.name,
        'rank': '${intent.rank}',
        if (intent is MapCameraFollow) 'follow': intent.kind.name,
        ...attributes,
      }),
    );
  }

  /// Die Standarduhr: eine laufende [Stopwatch], die dieses Objekt selbst
  /// anlegt.
  static Duration Function() _stopwatchClock() {
    final Stopwatch watch = Stopwatch()..start();
    return () => watch.elapsed;
  }
}
