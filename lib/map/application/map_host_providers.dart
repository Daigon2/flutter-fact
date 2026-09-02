/// Der Weg, auf dem ein Feature an den Karten-Host kommt, und die Stelle, an
/// der der Host sich einklinkt.
///
/// ## Zwei Provider auf dasselbe Objekt, und die Grenze hängt am Typ
///
/// [mapHostProvider] ist auf `MapHost` typisiert und für Features gedacht.
/// [mapHostRegistryProvider] ist auf [MapHostRegistry] typisiert und wird nur
/// aus `lib/map/presentation/` gelesen. Beide liefern **dasselbe Objekt**.
///
/// Es sind deshalb zwei und nicht einer, weil `MapHost` kein [MapHostRegistry.attach]
/// hat: ein Feature, das nur [mapHostProvider] sieht, **kann** sich nicht als
/// Host eintragen, und das verhindert der Übersetzer und nicht eine Konvention.
/// Ein einzelner Provider auf [MapHostRegistry] mit dem Kommentar „bitte nur
/// Absichten abgeben" wäre eine Bitte, und der erste Schritt, in dem jemand
/// schnell die Kamera braucht, wäre der letzte, in dem sie eingehalten wird.
/// Eine neue Prüfregel im Skript braucht es dafür nicht.
///
/// ## Warum die Registry ein gewöhnliches Objekt ist und kein Notifier
///
/// Ein- und Ausklinken passiert im `initState` und im `dispose` des
/// Kartenwidgets, und **an beiden Stellen ist eine Provider-Mutation
/// verboten**: `_debugAssertNotificationAllowed`
/// (`riverpod-3.4.2/lib/src/core/element.dart:871`) wirft „Tried to modify a
/// provider while the widget tree was building", und die Meldung nennt beide
/// ausdrücklich (`flutter_riverpod-3.4.2/lib/src/core/provider_scope.dart:381-385`).
/// In Debug bricht es, im Release passiert es still, was schlimmer ist.
///
/// Der übliche Ausweg, ein `addPostFrameCallback`, hat einen Preis, den man
/// nicht sieht: die Karte steht bereits, der Host ist aber noch nicht
/// eingetragen, und **jede Absicht in diesem Fenster fällt auf den untätigen
/// Standard**. Ein veränderliches Objekt hinter einem `Provider` hat dieses
/// Fenster nicht, weil nichts benachrichtigt werden muss.
///
/// Dieses Repository hat dieselbe Entscheidung aus demselben Grund schon
/// einmal getroffen, siehe `lib/core/anchors/anchor_registry.dart:4-9`.
/// **ADR-005 verbietet die globale statische Registry, nicht diese:** hier
/// erzeugt und besitzt der Provider das Objekt, es stirbt mit seinem Scope, und
/// es gibt kein `static`-Feld.
library;

import 'dart:async';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_camera_intent.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nimmt Absichten entgegen und reicht sie an den eingeklinkten Host weiter.
///
/// ## Warum die Registry selbst ein [MapHost] ist
///
/// Sie könnte auch nur `MapHost? get host` anbieten. Dass sie stattdessen
/// selbst die Fassade erfüllt, löst zwei Dinge auf einmal:
///
/// 1. **Ein Feature hält nie einen veralteten Host.** Wer sich den Host einmal
///    holt und merkt, hält ihn über einen Bildschirmwechsel hinweg fest. Über
///    die Registry gibt es diesen Zeiger gar nicht erst.
/// 2. **Ein Abonnement auf [cameraChanges] überlebt den Wechsel des Hosts.**
///    Der Strom gehört der Registry, nicht dem Host; sie leitet nur weiter.
///    Ein Feature, das direkt am Host abonniert hätte, hielte nach dem
///    Abmelden und Wiederanmelden ein totes Abonnement, und zwar ohne Fehler:
///    der Strom wäre einfach still.
final class MapHostRegistry implements MapHost {
  /// Erzeugt eine leere Registry. [diagnostics] bekommt jede verlorene Absicht.
  MapHostRegistry({required this._diagnostics});

  /// Gemeldet, wenn etwas den Host braucht und keiner eingeklinkt ist.
  ///
  /// Getrennt von [suppressedEvent], und das ist der Punkt: „niemand hat
  /// zugehört" ist ein Verdrahtungsfehler, „der Host hat abgelehnt" ist der
  /// geplante Betrieb. Ein gemeinsamer Name macht die beiden in jeder späteren
  /// Auswertung ununterscheidbar, und die Trennung kostet jetzt eine Zeile.
  static const String missingHostEvent = 'map.host.missing';

  /// Gemeldet, wenn der eingeklinkte Host eine Absicht unterdrückt.
  ///
  /// Der Name steht hier und nicht beim Host, damit die beiden Ereignisse
  /// nebeneinander stehen und niemand ein drittes erfindet, das dasselbe
  /// meint. Gesendet wird er in `lib/map/presentation/`.
  static const String suppressedEvent = 'map.host.intent_suppressed';

  final DiagnosticSink _diagnostics;

  /// Der Strom gehört der Registry und nicht dem Host, siehe Klassenkommentar.
  ///
  /// `broadcast`, weil mehrere Features gleichzeitig zusehen dürfen und keiner
  /// von ihnen den Strom für die anderen verbraucht.
  final StreamController<MapCameraView> _cameraChanges =
      StreamController<MapCameraView>.broadcast();

  /// Der Strom der Gruppen-Tipps, aus demselben Grund wie [_cameraChanges]:
  /// er gehört der Registry und überlebt einen Wechsel des Hosts.
  final StreamController<MapOverlayGroupTap> _groupTaps =
      StreamController<MapOverlayGroupTap>.broadcast();

  /// Der Strom der Punkt-Tipps, aus demselben Grund wie [_groupTaps]: er
  /// gehört der Registry und überlebt einen Wechsel des Hosts.
  final StreamController<MapOverlayPointTap> _pointTaps =
      StreamController<MapOverlayPointTap>.broadcast();

  MapHost? _host;
  StreamSubscription<MapCameraView>? _subscription;
  StreamSubscription<MapOverlayGroupTap>? _groupTapsSubscription;
  StreamSubscription<MapOverlayPointTap>? _pointTapsSubscription;

  /// Die zuletzt registrierten Bilder, nach Stil-Kennung.
  ///
  /// ## Warum die Registry das aufhebt, obwohl der Host es auch tut
  ///
  /// **Weil die beiden zwei verschiedene Lücken schließen.** Die Reihenfolge
  /// beim Start ist gemessen und nicht vermutet:
  ///
  /// 1. `MapPage.didChangeDependencies` läuft, **bevor** die Kartenfläche als
  ///    Kind überhaupt gebaut ist. Zu diesem Zeitpunkt hängt kein Host in der
  ///    Registry. Ohne diesen Zwischenspeicher wären die zwölf Ballonbilder
  ///    weg, und der Symbol-Layer zeichnete später nichts, ohne Fehler.
  /// 2. `MapSurface.initState` klinkt den Host ein, die Karte selbst kommt erst
  ///    mit `onMapCreated`. Diese zweite Lücke schließt der Host mit seinem
  ///    eigenen Zwischenspeicher.
  ///
  /// Dazu kommt der Wechsel des Hosts: die Registry überlebt ihn, siehe den
  /// Klassenkommentar zum Kamerastrom. Ein Feature, das seine Bilder einmal
  /// registriert hat, soll sie nach einem Wechsel nicht erneut zeichnen müssen.
  ///
  /// Zwei Zwischenspeicher für dasselbe wären eine zweite Wahrheit, wenn beide
  /// unabhängig geschrieben würden. Werden sie nicht: hier steht, **was das
  /// Feature will**, dort, **was auf diese eine Karte gehört**, und der Weg
  /// führt immer von hier nach dort.
  final Map<String, MapOverlayImage> _images = <String, MapOverlayImage>{};

  /// Die zuletzt gesetzten Überlagerungen, nach Kennung. Siehe [_images].
  final Map<String, MapOverlay> _overlays = <String, MapOverlay>{};

  /// Klinkt [host] ein. Ein bereits eingeklinkter wird ersetzt.
  ///
  /// „Der letzte gewinnt" ist dieselbe Antwort wie in
  /// `AnchorRegistry.register`, und aus demselben Grund: beim Wechsel zweier
  /// Bildschirme hängen kurzzeitig beide im Baum, und der neuere ist der
  /// sichtbare.
  void attach(MapHost host) {
    if (identical(_host, host)) {
      return;
    }
    unawaited(_subscription?.cancel());
    unawaited(_groupTapsSubscription?.cancel());
    unawaited(_pointTapsSubscription?.cancel());
    _host = host;
    _subscription = host.cameraChanges.listen(_cameraChanges.add);
    _groupTapsSubscription = host.groupTaps.listen(_groupTaps.add);
    _pointTapsSubscription = host.pointTaps.listen(_pointTaps.add);
    // Bilder vor Überlagerungen: ein Symbol-Layer ohne sein Bild zeichnet
    // nichts, und zwar ohne Fehlermeldung.
    if (_images.isNotEmpty) {
      host.registerOverlayImages(_images.values.toList());
    }
    for (final MapOverlay overlay in _overlays.values) {
      host.setOverlay(overlay);
    }
  }

  /// Klinkt [host] aus, aber nur, wenn er wirklich der eingeklinkte ist.
  ///
  /// **Die Identitätsprüfung ist eine bereits bezahlte Lehre aus Schritt 11.**
  /// Beim Tourende meldete die neue Tab-Leiste ihre Anker an, **bevor** die
  /// alte entsorgt war. Ein `detach` ohne Prüfung ersetzt in dieser Lage den
  /// frisch eingetragenen Host wieder durch den untätigen Standard, und die
  /// Karte ist danach still tot: kein Fehler, keine Meldung, nur keine
  /// Kamerabewegung mehr. `lib/core/anchors/anchor_target.dart:29-38` und
  /// `:68-75` zeigen die Fassung, die trägt, samt dem Grund, warum der
  /// Aufrufer sich die Registry merkt, statt sie im `dispose` nachzuschlagen.
  ///
  /// Gibt zurück, ob wirklich ausgeklinkt wurde.
  bool detach(MapHost host) {
    if (!identical(_host, host)) {
      return false;
    }
    unawaited(_subscription?.cancel());
    unawaited(_groupTapsSubscription?.cancel());
    unawaited(_pointTapsSubscription?.cancel());
    _subscription = null;
    _groupTapsSubscription = null;
    _pointTapsSubscription = null;
    _host = null;
    return true;
  }

  /// Schließt den Strom. Ruft der Provider beim Entsorgen seines Scopes.
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_groupTapsSubscription?.cancel());
    unawaited(_pointTapsSubscription?.cancel());
    _subscription = null;
    _groupTapsSubscription = null;
    _pointTapsSubscription = null;
    _host = null;
    _images.clear();
    _overlays.clear();
    unawaited(_cameraChanges.close());
    unawaited(_groupTaps.close());
    unawaited(_pointTaps.close());
  }

  @override
  MapCameraView? get camera {
    final MapHost? host = _host;
    if (host == null) {
      _reportMissing('camera');
      return null;
    }
    return host.camera;
  }

  /// Meldet jede Kamerabewegung, auch über einen Wechsel des Hosts hinweg.
  ///
  /// **Ohne Host ist dieser Strom still und meldet das nicht.** Das ist der
  /// eine Zugriff, bei dem nichts verloren geht: das Abonnement bleibt gültig
  /// und bekommt seine Werte, sobald eine Karte steht. Ein Ereignis dafür wäre
  /// kein Fehlerhinweis, sondern der Normalfall jedes Bildschirmaufbaus, und
  /// ein Ereignis, das im Normalbetrieb feuert, liest nach der dritten Woche
  /// niemand mehr.
  @override
  Stream<MapCameraView> get cameraChanges => _cameraChanges.stream;

  /// Reicht die Größe der Kartenfläche durch. **Ohne Host meldet das genau
  /// wie [camera] einen fehlenden Host**, aus demselben Grund: `null` wäre
  /// sonst nicht von „Karte steht, aber noch ungemessen" zu unterscheiden.
  @override
  MapViewport? get viewport {
    final MapHost? host = _host;
    if (host == null) {
      _reportMissing('viewport');
      return null;
    }
    return host.viewport;
  }

  /// Meldet jeden Gruppen-Tipp, auch über einen Wechsel des Hosts hinweg.
  ///
  /// Dieselbe Bauart wie [cameraChanges] und aus demselben Grund: der Strom
  /// gehört der Registry, ein Feature hält also nie ein Abonnement, das nach
  /// einem Kartenwechsel still bleibt. **Ohne Host ist er still und meldet
  /// das nicht**, wie [cameraChanges]: ein Ereignis dafür wäre der Normalfall
  /// jedes Bildschirmaufbaus.
  @override
  Stream<MapOverlayGroupTap> get groupTaps => _groupTaps.stream;

  /// Meldet jeden Punkt-Tipp, auch über einen Wechsel des Hosts hinweg.
  ///
  /// Dieselbe Bauart und dieselbe Begründung wie [groupTaps]. **Ohne Host ist
  /// er still und meldet das nicht.**
  @override
  Stream<MapOverlayPointTap> get pointTaps => _pointTaps.stream;

  @override
  void submitIntent(MapCameraIntent intent) {
    final MapHost? host = _host;
    if (host == null) {
      _reportMissing('submitIntent', intent: intent);
      return;
    }
    host.submitIntent(intent);
  }

  /// Merkt sich die Bilder und reicht sie durch, wenn ein Host da ist.
  ///
  /// **Ohne Host geht hier nichts verloren, und deshalb wird auch nichts
  /// gemeldet.** Das ist der Unterschied zu [submitIntent]: eine Absicht ist
  /// ein Ereignis und verfällt, ein Bild ist Zustand und wartet. Ein Ereignis
  /// im Normalbetrieb jedes Startvorgangs liest nach der dritten Woche
  /// niemand mehr, und dieser Fall ist der Normalbetrieb, siehe [_images].
  @override
  void registerOverlayImages(List<MapOverlayImage> images) {
    for (final MapOverlayImage image in images) {
      _images[image.styleId] = image;
    }
    _host?.registerOverlayImages(images);
  }

  /// Merkt sich die Überlagerung und reicht sie durch. Siehe
  /// [registerOverlayImages].
  @override
  void setOverlay(MapOverlay overlay) {
    _overlays[overlay.id] = overlay;
    _host?.setOverlay(overlay);
  }

  @override
  void removeOverlay(String overlayId) {
    _overlays.remove(overlayId);
    _host?.removeOverlay(overlayId);
  }

  /// Reicht durch. **Ohne Host kommt lauter `null` zurück, ohne Meldung.**
  ///
  /// Das ist die dritte Antwort dieser Klasse auf „kein Host", und sie folgt
  /// derselben Trennlinie: eine Absicht ist ein Ereignis und **verfällt**,
  /// also wird sie gemeldet; ein Bild ist Zustand und **wartet**, also nicht.
  /// Eine Projektion ist eine **Frage**, und die richtige Antwort auf „wo
  /// liegt das auf einer Karte, die es nicht gibt" ist „nirgends". Der
  /// Aufrufer fragt im nächsten Kameratakt erneut, und ein Ereignis im
  /// Normalbetrieb jedes Startvorgangs liest nach der dritten Woche niemand
  /// mehr.
  @override
  Future<List<MapScreenPoint?>> projectToScreen(List<MapPosition> positions) {
    final MapHost? host = _host;
    if (host == null) {
      return Future<List<MapScreenPoint?>>.value(
        List<MapScreenPoint?>.filled(positions.length, null),
      );
    }
    return host.projectToScreen(positions);
  }

  /// Meldet den fehlenden Host.
  ///
  /// Nur flache Zeichenketten, wie [DiagnosticEvent] es verlangt, und **keine
  /// Koordinaten**: `docs/engineering/security.md` §6 verbietet genaue
  /// Standortangaben im Log, und der Mittelpunkt einer Absicht ist regelmäßig
  /// die Nutzerposition.
  void _reportMissing(String access, {MapCameraIntent? intent}) {
    _diagnostics.report(
      DiagnosticEvent(missingHostEvent, <String, String>{
        'access': access,
        if (intent != null) 'origin': intent.origin.name,
        if (intent != null) 'rank': '${intent.rank}',
      }),
    );
  }
}

/// Die Registry, gelesen ausschließlich von `lib/map/presentation/`.
///
/// Wer hier landet, weil er die Kamera bewegen will, ist falsch: dafür gibt es
/// [mapHostProvider] und eine Absicht.
final Provider<MapHostRegistry> mapHostRegistryProvider =
    Provider<MapHostRegistry>((ref) {
      final registry = MapHostRegistry(
        diagnostics: ref.watch(diagnosticSinkProvider),
      );
      ref.onDispose(registry.dispose);
      return registry;
    });

/// Der Karten-Host, wie ein Feature ihn sieht.
///
/// Immer vorhanden und nie `null`: steht keine Karte, nimmt die Registry die
/// Absicht entgegen und meldet, dass niemand zugehört hat. Ein Feature muss
/// deshalb nirgends prüfen, ob es schon eine Karte gibt.
final Provider<MapHost> mapHostProvider = Provider<MapHost>(
  (ref) => ref.watch(mapHostRegistryProvider),
);
