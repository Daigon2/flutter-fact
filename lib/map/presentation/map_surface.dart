/// Die Kartenfläche: `MapLibreMap` mit dem gebackenen Stil, dahinter der
/// Karten-Host.
///
/// Dieses Widget ist bewusst dünn. Alles, was eine Entscheidung ist, liegt in
/// [MapCameraHost]; hier steht nur, was ohne Baum nicht geht: den Stil laden,
/// die Karte mounten, die Rückrufe verdrahten und den Host an- und abmelden.
///
/// ## Zwei Lücken im Paket, gegen die die Quelle etwas setzt
///
/// Sie stehen hier und nicht in `map_host.dart`, weil das die Domänenfassade
/// ist und von keinem SDK wissen darf; die Optionen der Karte werden dagegen
/// genau hier gesetzt, und hier stünde auch ihr Nachbau, wenn es einen gäbe.
/// Nachgesehen im Paket, nicht vermutet.
///
/// **1. Kein dauerhaftes Kamera-Padding, und das ist der teure Fund.**
/// `screen-map.jsx:1694` ruft `map.setPadding({ top: 320, bottom: 0, left: 0,
/// right: 0 })` und verschiebt damit den **wirksamen Kartenmittelpunkt** um
/// 320 Pixel nach unten, damit die Spielfigur im unteren Drittel steht; der
/// Kommentar der Quelle sagt es ausdrücklich. Im Paket gibt es `setPadding`
/// nicht und keine Option am Widget. `padding` kommt an genau zwei Stellen
/// vor, und keine davon leistet das: als vier Seitenabstände einer einmaligen
/// Kamerafahrt (`CameraUpdate.newLatLngBounds`,
/// `maplibre_gl_platform_interface-0.26.2/lib/src/camera.dart:106-119`) und
/// als eine Zahl, die den **erlaubten Kartenausschnitt** eingrenzt
/// (`setCameraBounds`, `maplibre_gl-0.26.2/lib/src/controller.dart:1811-1826`).
/// Wer das zweite für das erste hält, sperrt das Schieben ein, statt die
/// Kamera zu versetzen.
///
/// **Das entscheidet die Schritte 15 bis 18 mit**, denn ohne Kamera-Padding
/// muss der Versatz woanders herkommen: entweder liegen Nutzermarker und
/// Avatar nicht in der Bildmitte, sondern werden als Flutter-Widgets über der
/// Karte gesetzt, oder jedes Neuzentrieren rechnet den Mittelpunkt selbst um
/// 320 Pixel versetzt. Hier wird nichts umgangen und nichts umgebaut, der Fund
/// ist festgehalten.
///
/// **2. Keine Klammer für die Neigung.** `screen-map.jsx:1677-1678` setzt
/// `minPitch: 0` und `maxPitch: 75`; beides gibt es im Paket nicht (null
/// Treffer in beiden Paketen). Das SDK klemmt die Neigung stattdessen
/// zoomabhängig und still (`camera.dart:33-35`: „Values beyond the supported
/// range are allowed, but on applying them to a map they will be silently
/// clamped to the supported range."). Folgenlos, solange die Auto-Neigung bei
/// 58 endet.
library;

import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/presentation/map_camera_driver.dart';
import 'package:fact_app/map/presentation/map_camera_host.dart';
import 'package:fact_app/map/presentation/map_overlay_driver.dart';
import 'package:fact_app/map/presentation/map_projection_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Der gebackene Kartenstil.
///
/// Steht als Konstante an genau einer Stelle: dreimal dieselbe Zeichenkette
/// wäre dreimal eine Gelegenheit, sich zu vertippen, und ein vertippter
/// Asset-Pfad fällt erst zur Laufzeit auf.
///
/// Erzeugt von `tool/bake_map_style.dart`, Drift prüft
/// `dart run tool/bake_map_style.dart --check`. **Gebacken und nicht zur
/// Laufzeit umgefärbt**, weil `maplibre_gl 0.26.2` weder `setPaintProperty`
/// noch `setLayoutProperty` hat.
const String factMapStyleAsset = 'assets/map/fact_map_style.json';

/// Zoomstufe, über die die Karte nicht hinausgeht.
///
/// `02_Frontend/app/screen-map.jsx:1680`: `maxZoom: 20`.
const double factMapMaxZoom = 20;

/// Die Kartenfläche.
///
/// [initialCamera] kommt **von außen** und steht nicht als Literal in dieser
/// Datei. Mehrstädtigkeit ist eine globale Invariante, und die Startkamera ist
/// genau die Stelle, an der eine fest verdrahtete Stadt sich einnistet.
class MapSurface extends ConsumerStatefulWidget {
  /// Erzeugt die Kartenfläche mit der Startkamera [initialCamera].
  const MapSurface({
    required this.initialCamera,
    @visibleForTesting this.debugCreateHost,
    super.key,
  });

  /// Wo die Kamera steht, wenn die Karte erscheint.
  final MapCameraView initialCamera;

  /// Erzeugt den Host dieser Fläche. **Nur für Tests.**
  ///
  /// Ohne diesen Haken ist „die Fläche entsorgt beim Ausbauen ihren Host"
  /// nicht prüfbar: der Host entsteht im `initState`, ist von außen nirgends
  /// greifbar, und ein offen gebliebener Kamerastrom ist ein Leck **ohne
  /// sichtbares Verhalten**. Ein fehlendes `_host.dispose()` überlebte deshalb
  /// die ganze Suite. Mit einem Host, den der Test selbst mitbringt, wird aus
  /// dem Leck eine Zusicherung: der Strom ist danach geschlossen.
  ///
  /// `@visibleForTesting` ist hier kein guter Vorsatz, sondern ein Gate: ein
  /// Aufruf aus `lib/` bricht `dart analyze` mit Exit-Code 2 ab.
  ///
  /// **Und die Annotation steht zweimal da, weil einmal zu wenig war.** Mit
  /// einer Wegwerf-Datei unter `lib/` gemessen: am Feld allein bewacht sie nur
  /// das **Lesen**; ein `MapSurface(debugCreateHost: ...)` aus Produktivcode
  /// ging anstandslos durch, also genau der Missbrauch, um den es geht. Erst
  /// die Annotation am Konstruktorparameter meldet ihn.
  @visibleForTesting
  final MapCameraHost Function()? debugCreateHost;

  @override
  ConsumerState<MapSurface> createState() => _MapSurfaceState();
}

class _MapSurfaceState extends ConsumerState<MapSurface> {
  late final MapCameraHost _host;

  /// Die Registry, bei der dieser Host angemeldet ist.
  ///
  /// **Gemerkt und nicht im `dispose` nachgeschlagen**, aus demselben Grund
  /// wie in `lib/core/anchors/anchor_target.dart:29-38`: nach dem Ausbau aus
  /// dem Baum ist ein Provider-Zugriff über den Kontext nicht mehr verlässlich,
  /// und ein still fehlgeschlagenes Abmelden hinterlässt einen toten Host in
  /// der Registry.
  MapHostRegistry? _registry;

  String? _style;

  @override
  void initState() {
    super.initState();
    // `ref.read` ist hier erlaubt, eine Provider-**Mutation** wäre es nicht.
    // Genau deshalb ist die Registry ein gewöhnliches Objekt und kein
    // Notifier, siehe `map_host_providers.dart`.
    _host =
        widget.debugCreateHost?.call() ??
        MapCameraHost(diagnostics: ref.read(diagnosticSinkProvider));
    final MapHostRegistry registry = ref.read(mapHostRegistryProvider);
    registry.attach(_host);
    _registry = registry;
    reportDetached(_loadStyle(), origin: 'map.surface.load_style');
  }

  @override
  void dispose() {
    // Identitätsgeprüft: hängt bereits eine neue Kartenfläche in der Registry,
    // räumt dieses `dispose` sie nicht weg. Die Lehre aus Schritt 11.
    _registry?.detach(_host);
    _registry = null;
    _host.dispose();
    super.dispose();
  }

  Future<void> _loadStyle() async {
    final String style = await rootBundle.loadString(factMapStyleAsset);
    if (!mounted) {
      return;
    }
    setState(() => _style = style);
  }

  /// Die Karte ist da. Ab hier hat der Host eine Kamera und einen Weg zum SDK.
  ///
  /// **Läuft im Widget-Test nie**, weil ohne Plattformkanal kein Controller
  /// entsteht (`maplibre_map.dart:390-418`). Deshalb steht in dieser Methode
  /// nichts als die Verdrahtung.
  ///
  /// **Und deshalb ist genau diese Zeile die einzige des Karten-Hosts, für die
  /// es keinen Test gibt und keinen geben kann.** Dass der Host seine sieben
  /// Fassadenmethoden richtig durchreicht, ist seit Schritt 16 zugesichert
  /// (`test/map/presentation/map_camera_host_test.dart`, „Die Durchreichungen
  /// an den Überlagerungsteil" und „Die Projektion"); dass
  /// `MapLibreOverlayDriver` und `MapLibreProjectionDriver` hier auch wirklich
  /// mitgegeben werden, ist nur auf einem Gerät zu sehen. Ein Test dafür wäre
  /// ein Test gegen einen Doppelgänger dieser Methode und würde nichts
  /// belegen. Wer diese Zeile ändert, prüft sie am Gerät oder gar nicht.
  ///
  /// **Und hier hängt eine offene Messung, die über die ganze Näherungs-
  /// Animation entscheidet.** `controller.dart:1779` sagt zur Umrechnung
  /// „screen pixels (not display pixels)", und dieser Satz kann beides heißen.
  /// Liegt dort das Geräteraster statt des logischen, sitzt jeder gezeichnete
  /// Ballon um das Bildverhältnis daneben. Umgerechnet wird deshalb an genau
  /// einer Stelle, im Aufrufer der Projektion, siehe
  /// `features/discovery/presentation/fact_balloon_overlay.dart`.
  void _onMapCreated(MapLibreMapController controller) {
    _host.bindSurface(
      driver: MapLibreCameraDriver(controller),
      overlays: MapLibreOverlayDriver(controller),
      projections: MapLibreProjectionDriver(controller),
      camera: widget.initialCamera,
    );
  }

  void _onCameraMove(CameraPosition position) =>
      _host.handleCameraMove(mapCameraViewOf(position));

  void _onCameraIdle() => _host.handleCameraIdle();

  static CameraPosition _positionOf(MapCameraView view) => CameraPosition(
    target: LatLng(view.center.latitude, view.center.longitude),
    zoom: view.zoom,
    bearing: view.bearing,
    tilt: view.pitch,
  );

  @override
  Widget build(BuildContext context) {
    final String? style = _style;
    if (style == null) {
      // Solange der Stil nicht geladen ist, dieselbe Fläche wie bisher der
      // Platzhalter: `--map-bg` aus `styles.css`, über das Theme.
      return ColoredBox(color: context.factColors.mapBg);
    }

    return MapLibreMap(
      styleString: style,
      initialCameraPosition: _positionOf(widget.initialCamera),
      // **Pflicht und kein Schalter.** Ohne `trackCameraPosition` gibt es
      // überhaupt keine Kamerarückmeldung: auf Android kehrt `onCameraMove()`
      // sofort zurück und `onCameraIdle()` sendet keine Position, auf iOS
      // liefert `getCamera()` `nil`. Der ganze Host hinge dann in der Luft.
      trackCameraPosition: true,
      // **Stabile Methodenreferenzen, keine frisch erzeugten Closures.**
      // `maplibre_map.dart:406-410` liest diese beiden Rückrufe **genau
      // einmal**, bei der Erzeugung des Controllers; `didUpdateWidget` gleicht
      // nur Optionen ab. Eine Closure, die beim Bauen entsteht, wäre damit für
      // immer die erste Fassung, ohne jede Fehlermeldung.
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      // Die App zeichnet ihren eigenen Kompass im Top-Chrome
      // (`screen-map.jsx:3145-3190`). Der native läge darunter und wäre ein
      // zweiter Knopf für dieselbe Sache.
      compassEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(null, factMapMaxZoom),
    );
  }
}

/// Der Rückweg vom SDK in die Domäne.
///
/// `tilt` beim SDK, `pitch` in der Quelle und in der Domäne. Das ist die eine
/// Stelle, an der eine Verwechslung lautlos wäre, und deshalb steht diese
/// Rechnung als eigene Funktion da und nicht als private Zeile im `State`:
/// **`_onCameraMove` läuft im Widget-Test nie**, weil ohne Plattformkanal kein
/// Controller entsteht. Ein vertauschtes Paar `bearing`/`pitch` ginge also
/// durch jede Suite und fiele erst am Gerät auf, als Karte, die sich beim
/// Neigen dreht.
///
/// Der Gegenweg `_positionOf` bleibt privat: er ist über
/// `MapLibreMap.initialCameraPosition` von außen sichtbar und damit ohnehin
/// zugesichert.
@visibleForTesting
MapCameraView mapCameraViewOf(CameraPosition position) => MapCameraView(
  center: MapPosition(
    latitude: position.target.latitude,
    longitude: position.target.longitude,
  ),
  zoom: position.zoom,
  bearing: position.bearing,
  pitch: position.tilt,
);
