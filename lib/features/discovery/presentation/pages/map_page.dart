import 'dart:async';

import 'package:fact_app/features/discovery/presentation/map_camera_intents.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Karten-Bildschirm (`02_Frontend/app/screen-map.jsx`).
///
/// Unter dem Top-Chrome liegt seit Schritt 12 die echte Karte, seit Schritt 13
/// bewegt sie sich. Wem die Kamera gehört, ist seit dem 28.08.2026 entschieden:
/// dem Host unter `lib/map/`. Dieses Feature steuert sie nicht, es gibt über
/// `map/domain/` Absichten ab.
///
/// ## Warum die Karte hereingereicht wird und nicht hier entsteht
///
/// [mapSurface] kommt von außen, obwohl es hier bequemer wäre, das Widget
/// selbst zu bauen. **Regel 18 des Prüfskripts lässt das nicht zu**, und zwar
/// gemessen und nicht vermutet: ein Import von
/// `package:fact_app/map/presentation/...` aus einem Feature bricht den
/// Architektur-Check mit Exit-Code 1 ab. Das ist genau die Grenze, die die
/// Kamerahoheit des Hosts absichert.
///
/// Der Ausweg ist derselbe wie bei der Audio-Präferenz auf dem
/// Startbildschirm: ein Kompositions-Adapter auf App-Ebene (Regel 10 der
/// `dependency-rules.md`). `MapRoute.build` in `lib/app/routing/app_routes.dart`
/// setzt die Kartenfläche ein, und `discovery` erfährt nicht, woraus sie
/// besteht. Von `maplibre_gl` steht in diesem Verzeichnis deshalb kein
/// einziger Import, was Regel 20 zusätzlich absichert. Erlaubt und vorgesehen
/// ist dagegen der Weg über `map/application/`: [mapHostProvider] ist auf den
/// Vertrag `MapHost` typisiert und hat kein `attach`.
///
/// ## Der Bildschirm ist der Kurier, nicht der Fahrer
///
/// Vier Fragen kann nur ein Widget beantworten, und deshalb hängt dieser
/// Bildschirm an einem `State` statt an einem Notifier:
///
/// 1. **Lebt die Karte schon?** Der Host verwirft jede Absicht, die vor der
///    Karte eintrifft, und meldet sie als `map.host.intent_dropped`. Der erste
///    GPS-Fix kann früher kommen, und dann gäbe es die Eröffnungsanimation nie.
///    Also wird sie aufgehoben und nachgeholt, siehe [_deliverPendingSkyFall].
/// 2. **Ist der eigene Tab-Zweig sichtbar?** Siehe [_branchIsActive].
/// 3. **Wo steht die Kamera gerade?** Das Neuzentrieren rechnet mit
///    `max(aktueller Zoom, 15)` (`screen-map.jsx:2985`).
/// 4. **Wohin blickt die Karte?** Die Kompassnadel dreht gegen die
///    Kartenblickrichtung (`:1792`), und die ändert sich, während dieser
///    Bildschirm längst steht.
///
/// ## Die Platzhalterwerte, und warum sie so und nicht anders lauten
///
/// Drei Zahlen und ein Name gehören Domänen, die es noch nicht gibt. Keine
/// davon ist erfunden; jede ist der Wert, den die PWA bei frischem Zustand
/// selbst anzeigt:
///
/// | Wert | Herkunft |
/// |---|---|
/// | [placeholderCoins] | `storage.jsx:45`, `load('coins', 0)` |
/// | [placeholderLevel] | `storage.jsx:229-236` mit XP 0 ergibt `FACT_LEVELS[0]` |
/// | [placeholderLevelPercent] | dieselbe Rechnung: `(0 - 0) / (50 - 0) * 100` |
/// | [placeholderCityName] | `screen-map.jsx:3008`, `CITIES[0]` ohne Kartenmitte |
///
/// Sie verschwinden, sobald `features/progression` und `features/city`
/// entstehen. Bis dahin steht hier ausdrücklich ein Platzhalter und keine
/// stille Annahme. **Die Stadt-Pille bewegt in Schritt 13 nur die Kamera**,
/// ihren Text zieht sie weiterhin aus dem Platzhalter: `detectCity` über die
/// Kartenmitte (`screen-map.jsx:310-322`, `:2992-3008`) gehört `features/city`.
class MapPage extends ConsumerStatefulWidget {
  /// Erzeugt den Karten-Bildschirm mit der Kartenfläche [mapSurface].
  const MapPage({required this.mapSurface, super.key});

  /// Die Kartenfläche, die unter dem Top-Chrome liegt.
  ///
  /// Verpflichtend und nicht `null`-fähig: ein Standard wäre eine leere Fläche,
  /// und eine Karte, die aus Versehen fehlt, sähe dann genauso aus wie eine,
  /// die noch lädt.
  final Widget mapSurface;

  /// Münzstand ohne `features/progression`.
  static const int placeholderCoins = 0;

  /// Levelnummer ohne `features/progression`.
  static const int placeholderLevel = 1;

  /// Fortschritt im Level ohne `features/progression`, in Prozent.
  static const double placeholderLevelPercent = 0;

  /// Stadtname ohne Kartenmitte und ohne `features/city`.
  ///
  /// Das ist die Rückfallstadt der Quelle, nicht eine fest verdrahtete
  /// Annahme: `detectCity` läuft über zwölf Städte (`screen-map.jsx:310-322`),
  /// und ohne Kartenmitte und ohne GPS nimmt der Bildschirm die erste
  /// (`:3006-3008`). Mehrstädtigkeit bleibt damit erhalten, [MapTopChrome]
  /// bekommt den Namen von außen.
  static const String placeholderCityName = 'München';

  /// Wo die Karte steht, bis der erste GPS-Fix kommt.
  ///
  /// Dieselbe Rückfallposition wie oben, aus derselben Zeile:
  /// `screen-map.jsx:1668` nimmt `cachedPos || { lat: 48.1351, lng: 11.5820 }`
  /// und setzt damit `center`, `zoom: 14`, `pitch: 35` und `bearing: 0`
  /// (`:1669-1682`). Sie steht hier und nicht im Karten-Host: der Host hat
  /// keine Stadt, und eine Startkamera in seinem Code wäre genau die fest
  /// verdrahtete Annahme, die Mehrstädtigkeit verbietet.
  ///
  /// **Der `cachedPos`-Teil fehlt und bleibt bewusst weg**, siehe
  /// `map_camera_intents.dart`, „Was hier bewusst fehlt". Sobald es dauerhafte
  /// Speicherung gibt, kommt der Wert von dort und diese Konstante fällt weg.
  static const MapCameraView placeholderCamera = MapCameraView(
    center: MapPosition(latitude: 48.1351, longitude: 11.582),
    zoom: 14,
    bearing: 0,
    pitch: 35,
  );

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  /// Ob der Sky-Fall schon abgegeben wurde.
  ///
  /// Der Riegel `skyFallDone` der Quelle (`screen-map.jsx:1726-1729`). Er steht
  /// hier und nicht im Notifier, weil er erst umgelegt wird, wenn die Absicht
  /// wirklich abgegeben werden **konnte**: liegt keine Karte, bleibt er unten
  /// und der Sky-Fall wird nachgeholt.
  bool _skyFallDone = false;

  /// Ob die Karte lebt, also schon einmal eine Kamera gemeldet hat.
  ///
  /// **Gemerkt statt nachgefragt.** `MapHost.camera` ginge auch, meldet aber
  /// bei jedem Zugriff ohne eingeklinkten Host `map.host.missing`
  /// (`map_host_providers.dart`), und das ist als Verdrahtungsfehler gedacht,
  /// nicht als Normalfall jedes Startvorgangs. Der Strom sagt dasselbe, ohne
  /// etwas zu melden: `MapCameraHost.bindSurface` schiebt die Startkamera
  /// hinein, sobald `onMapCreated` gelaufen ist.
  bool _mapIsAlive = false;

  /// Ob der eigene Tab-Zweig gerade angezeigt wird.
  ///
  /// ## Warum es diese Sperre gibt
  ///
  /// **Der Tabwechsel entsorgt diesen Bildschirm nicht.** `go_router 18.0.0`
  /// legt jeden Zweig in `Offstage` innerhalb eines `IndexedStack`
  /// (`go_router-18.0.0/lib/src/route.dart:1630-1634`), und `RenderOffstage`
  /// legt sein Kind trotzdem aus. Ohne Gegenmaßnahme zöge die Karte im
  /// Hintergrund mit jedem GPS-Fix weiter, und der Nutzer käme auf einen
  /// Bildschirm zurück, der sich ohne sein Zutun bewegt hat.
  ///
  /// Die Sperre sitzt auf der **abgebenden** Seite und nicht im Host: der Host
  /// bedient vier Features, und ob eines davon gerade sichtbar ist, weiß nur
  /// dieses selbst. In der Quelle gibt es dafür keine Vorlage, sie kennt keine
  /// Tabs.
  ///
  /// Der Schalter liegt schon im Baum: dieselbe Zeile von `go_router` wickelt
  /// den Zweig zusätzlich in ein `TickerMode`. [TickerMode.valuesOf] stellt
  /// dabei eine Abhängigkeit her, dieser `State` bekommt den Wechsel also über
  /// [didChangeDependencies] mit. `TickerMode.of` wäre der ältere Weg und ist
  /// seit 3.35.0-0.0.pre veraltet.
  ///
  /// **Der Ortungsstrom läuft weiter**, nur die Kamera folgt nicht, siehe
  /// `notifiers/user_location_providers.dart`.
  bool _branchIsActive = true;

  /// Die Blickrichtung der Karte in Grad, wie die Kompassnadel sie braucht.
  ///
  /// Der Startwert ist die Blickrichtung der Startkamera und keine erfundene
  /// Null: bis `bindSurface` die erste Kamera meldet, steht die Karte
  /// nachweislich dort ([MapPage.placeholderCamera]).
  ///
  /// **Gehalten und nicht bei jedem Bild neu gefragt.** Der Kamerastrom liefert
  /// auf dem Gerät bis zu 60 Ausgaben je Sekunde; neu gebaut wird nur, wenn
  /// sich die Blickrichtung wirklich geändert hat, siehe [_onCameraChange].
  /// Die Quelle macht dasselbe an einem eigenen Ereignis: `map.on('rotate')`
  /// (`screen-map.jsx:1790-1793`).
  double _bearingDegrees = MapPage.placeholderCamera.bearing;

  StreamSubscription<MapCameraView>? _cameraSubscription;

  @override
  void initState() {
    super.initState();
    // Vor der Kartenfläche, und das ist nicht beliebig: `MapSurface` ist ein
    // Kind dieses Bildschirms, sein `initState` läuft also später, und
    // `bindSurface` noch einmal später. Ein Abonnement, das erst danach
    // entstünde, verpasste die einzige Ausgabe, die „die Karte lebt" bedeutet,
    // und der Sky-Fall bliebe für immer liegen.
    _cameraSubscription = ref
        .read(mapHostProvider)
        .cameraChanges
        .listen(_onCameraChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isActive = TickerMode.valuesOf(context).enabled;
    if (isActive == _branchIsActive) {
      return;
    }
    _branchIsActive = isActive;
    if (isActive) {
      // Der Zweig wird wieder sichtbar: ein liegengebliebener Sky-Fall ist
      // jetzt fällig. Ein liegengebliebenes GPS-Folgen dagegen nicht, es holt
      // sich der nächste Fix mit einem neueren Wert.
      _deliverPendingSkyFall();
    }
  }

  @override
  void dispose() {
    unawaited(_cameraSubscription?.cancel());
    _cameraSubscription = null;
    super.dispose();
  }

  /// Die Karte hat sich gemeldet.
  ///
  /// Zwei Dinge hängen daran, und nur eines davon einmalig: die **erste**
  /// Ausgabe bedeutet „die Karte lebt", **jede** trägt die aktuelle
  /// Blickrichtung für die Kompassnadel. Neu gebaut wird nur bei einer echten
  /// Drehung; ein Schwenk oder ein Zoom ändert die Blickrichtung nicht, und
  /// beide sind auf dem Gerät der Normalfall.
  void _onCameraChange(MapCameraView view) {
    if (!_mapIsAlive) {
      _mapIsAlive = true;
      _deliverPendingSkyFall();
    }
    if (view.bearing != _bearingDegrees) {
      setState(() => _bearingDegrees = view.bearing);
    }
  }

  /// Eine neue Ortung ist angekommen.
  ///
  /// Genau **eine** Absicht je Ortung, wie in der Quelle: der erste Fix löst
  /// den Sky-Fall aus (`screen-map.jsx:2622`), jeder weitere das GPS-Folgen
  /// (`:2653-2676`). Der Zweig `isFirst` dort trennt beide.
  void _onLocationChange(UserLocationState? previous, UserLocationState next) {
    if (next.acceptedFixes == (previous?.acceptedFixes ?? 0)) {
      return;
    }
    if (!_skyFallDone) {
      _deliverPendingSkyFall();
      return;
    }
    final DevicePosition? fix = next.fix;
    if (fix == null || !_canSteer) {
      return;
    }
    ref
        .read(mapHostProvider)
        .submitIntent(userPositionFollowIntent(mapPositionOf(fix)));
  }

  /// Gibt den Sky-Fall ab, sobald er abgegeben werden kann.
  ///
  /// Drei Auslöser rufen das: eine neue Ortung, die erste Kamerameldung und
  /// das Sichtbarwerden des Zweigs. Welcher zuerst kommt, ist offen, und
  /// deshalb steht die vollständige Bedingung an einer Stelle statt an dreien.
  ///
  /// **Er passiert genau einmal.** [_skyFallDone] wird gesetzt, bevor die
  /// Absicht abgegeben wird; ein zweiter Auslöser im selben Zug fände den
  /// Riegel schon oben.
  ///
  /// Abgegeben wird auf die **neueste** Ortung und nicht auf die erste. Die
  /// Quelle hat diesen Fall nicht, weil sie den Sky-Fall nie aufhebt; wer eine
  /// Minute nach dem ersten Fix zurück auf die Karte wechselt, soll dorthin
  /// fallen, wo er steht, und nicht dorthin, wo er stand.
  void _deliverPendingSkyFall() {
    if (_skyFallDone || !_canSteer) {
      return;
    }
    final DevicePosition? fix = ref.read(userLocationProvider).fix;
    if (fix == null) {
      return;
    }
    _skyFallDone = true;
    ref.read(mapHostProvider).submitIntent(skyFallIntent(mapPositionOf(fix)));
  }

  /// Ob eine Absicht jetzt überhaupt etwas bewirken kann.
  bool get _canSteer => _mapIsAlive && _branchIsActive;

  /// Wo die Kamera steht, oder `null`, solange keine Karte lebt.
  ///
  /// Die Abfrage von [_mapIsAlive] steht davor, damit ohne Karte kein
  /// `map.host.missing` entsteht, siehe dort.
  MapCameraView? get _camera =>
      _mapIsAlive ? ref.read(mapHostProvider).camera : null;

  /// Die letzte Ortung als Kartenpunkt, oder `null`.
  MapPosition? get _target {
    final DevicePosition? fix = ref.read(userLocationProvider).fix;
    return fix == null ? null : mapPositionOf(fix);
  }

  /// Tipp auf die Stadt-Pille: neuzentrieren (`screen-map.jsx:3106`).
  void _onCityTap() {
    final MapCameraView? camera = _camera;
    final MapPosition? target = _target;
    if (camera == null || target == null) {
      return;
    }
    ref
        .read(mapHostProvider)
        .submitIntent(recenterIntent(target: target, currentZoom: camera.zoom));
  }

  /// Kurzer Druck auf den Kompass (`screen-map.jsx:3175-3185`).
  ///
  /// Auch ohne Ortung ein Befehl, weil er das Einrasten der Blickrichtung
  /// unbedingt löst; die Begründung steht bei [compassTapIntent].
  void _onCompassTap() {
    final MapCameraView? camera = _camera;
    if (camera == null) {
      return;
    }
    ref
        .read(mapHostProvider)
        .submitIntent(
          compassTapIntent(currentZoom: camera.zoom, target: _target),
        );
  }

  /// Langer Druck auf den Kompass: harter Reset (`screen-map.jsx:3158-3172`).
  void _onCompassLongPress() {
    if (_camera == null) {
      return;
    }
    ref
        .read(mapHostProvider)
        .submitIntent(compassLongPressIntent(target: _target));
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(mapModeProvider);
    ref.listen(userLocationProvider, _onLocationChange);
    // **Nur die Frage, ob es überhaupt eine Ortung gibt, und nicht welche.**
    // Ohne `select` baute sich das ganze Top-Chrome bei jeder Ortung neu, also
    // bis zu fünfmal je Sekunde, obwohl sich daran nichts ändert.
    final bool hasFix = ref.watch(
      userLocationProvider.select((state) => state.fix != null),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.mapSurface,
        MapTopChrome(
          cityName: MapPage.placeholderCityName,
          coins: MapPage.placeholderCoins,
          level: MapPage.placeholderLevel,
          levelPercent: MapPage.placeholderLevelPercent,
          mode: mode,
          onModeSelected: ref.read(mapModeProvider.notifier).select,
          // `null`, solange es keine Ortung gibt: dann zeigt die Quelle nicht
          // einmal einen Zeiger (`cursor: userPos ? pointer : default`,
          // `screen-map.jsx:3112`), und `recenter` kehrte ohnehin sofort
          // zurück (`:2978-2979`).
          onCityTap: hasFix ? _onCityTap : null,
          // Der Kompass ist immer bedienbar, auch ohne Ortung: beide Gesten
          // lösen unbedingt das Einrasten der Blickrichtung (`:3166`, `:3182`),
          // und der lange Druck stellt zusätzlich Neigung und Blickrichtung
          // zurück, auch ohne Position (`:3170`).
          onCompassTap: _onCompassTap,
          onCompassLongPress: _onCompassLongPress,
          // Die Nadel dreht gegen die Kartenblickrichtung (`:1792`), und die
          // kommt aus dem Kamerastrom, den dieser Bildschirm ohnehin
          // abonniert. **Der Gerätekompass gehört nicht dazu**: die Karte
          // seiner Ausrichtung folgen zu lassen (`:2805-2840`) ist Schritt 14
          // und braucht ein Sensorpaket, das es hier nicht gibt.
          bearingDegrees: _bearingDegrees,
          // `isDark` bleibt beim Standard `false`, weil `mapDark` in der
          // Quelle nie `true` wird, siehe `MapTopChrome.isDark`.
        ),
      ],
    );
  }
}

/// Der Weg vom Ortungsdienst in die Kartensprache.
///
/// **Die Umrechnung passiert beim Verbraucher und nicht im Dienst.** Der
/// Ortungsdienst kennt keine Karte: gäbe er `MapPosition` heraus, hätte der
/// Karten-Host den Aufenthaltsort des Nutzers in seiner Vertragsfläche, und
/// das ist mit E-07 eine Sicherheitsfrage. Zwei Wertobjekte für denselben
/// Punkt sind der Preis dafür, siehe `DevicePosition`, dritte Instanz der
/// Geo-Typ-Sperre, und die offene Entscheidung D-9.
///
/// Öffentlich und nicht privat, damit ein Test die Richtung festnageln kann:
/// vertauschte Breite und Länge sähen in jedem Widget-Test gleich aus.
MapPosition mapPositionOf(DevicePosition fix) =>
    MapPosition(latitude: fix.latitude, longitude: fix.longitude);
