import 'dart:async';

import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/features/discovery/presentation/map_camera_intents.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Karten-Bildschirm (`02_Frontend/app/screen-map.jsx`).
///
/// Unter dem Top-Chrome liegt seit Schritt 12 die echte Karte, seit Schritt 13
/// bewegt sie sich, und seit Schritt 15 liegen die Fakten darauf. Wem die Karte
/// gehört, ist seit dem 28.08.2026 entschieden: dem Host unter `lib/map/`.
/// Dieses Feature steuert weder Kamera noch Layer, es gibt über `map/domain/`
/// Absichten ab und legt Überlagerungen auf.
///
/// ## Was dieser Bildschirm mit den Fakten tut, und was nicht
///
/// Er ist auch hier Kurier. Geladen werden sie von
/// `notifiers/fact_overlay_providers.dart`, übersetzt von `fact_overlay.dart`,
/// gezeichnet von `fact_balloon_images.dart`. Hier stehen nur die drei Dinge,
/// die ein Widget beitragen muss: **wann** die Bilder entstehen (dafür braucht
/// es das Bildverhältnis des Bildschirms), **dass** die fertige Überlagerung
/// den Weg zum Host findet, und **in welcher Reihenfolge** beides geschieht.
///
/// ## Die Reihenfolge ist eine Zusage, kein Zufall
///
/// `MapHost.registerOverlayImages` verlangt ausdrücklich, vor `setOverlay`
/// gerufen zu werden, und der Grund ist eine Meldung: der Host meldet jede
/// Stil-Kennung, für die kein Bild registriert ist, als
/// `map.overlay.unknown_style`. **Dieser Bildschirm hat die Zusage bis zum
/// 29.08.2026 gebrochen.** Die Bilder entstehen asynchron in
/// [_ensureBalloonImages], die Überlagerung kommt unabhängig davon aus dem
/// Netz; kamen die Fakten zuerst, feuerte die Meldung mit allen zwölf
/// Kategorien auf einmal, und ein „doch alles da" gibt es hinterher nicht.
/// Damit war der einzige Schutz gegen eine wirklich vertippte Kennung ein
/// Fehlalarm bei jedem Start.
///
/// Behoben wird es **hier** und nicht im Host, weil hier die Reihenfolge
/// entsteht. Der Host könnte stattdessen erst beim Einklinken prüfen, das
/// verschiebt das Problem nur: auch dann können Bilder danach eintreffen, und
/// die Meldung hätte wieder einen Zeitpunkt, den niemand kontrolliert. Der
/// Bildschirm dagegen weiß genau, wann er fertig ist. Die Überlagerung wartet
/// deshalb in [_latestOverlay], bis die Bilder angemeldet sind, siehe
/// [_deliverOverlay]. Dass dabei nichts verloren geht, ist derselbe Gedanke wie
/// beim Sky-Fall eine Zeile weiter unten.
///
/// **Was beim Antippen eines Ballons passiert, steht bewusst nicht hier.** Der
/// Punkt-Tipp hat bis Schritt 21 keinen Empfänger, und das Aufklappen einer
/// Gruppe hängt an einer offenen technischen Entscheidung. Ein Strom auf
/// Vorrat wäre Zustand, den niemand prüft.
///
/// ## Seit Schritt 17 liegen die nahen Fakten nicht mehr nativ
///
/// [FactBalloonOverlay] zeichnet die Handvoll Fakten innerhalb von 150 Metern
/// als Flutter-Widgets über der Karte, mit Größe, Glühen und Drehung. Dieser
/// Bildschirm trägt davon genau ein Stück: er **nimmt sie aus der nativen
/// Punktliste heraus**, solange sie leben, siehe [_animatedIds]. Ohne das
/// stünde jeder nahe Ballon doppelt da, einmal lebend und einmal als stehendes
/// Bild darunter.
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
/// Fünf Fragen kann nur ein Widget beantworten, und deshalb hängt dieser
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
/// 5. **Wie fein löst der Bildschirm auf?** Die Ballonbilder entstehen zur
///    Laufzeit, und ein Bild für ein 3x-Gerät muss dreifach aufgelöst sein.
///    `MediaQuery` gibt es nur mit einem `BuildContext`.
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

  /// Für welches Bildverhältnis die Ballonbilder schon gezeichnet wurden.
  ///
  /// `null` heißt „noch keine". Gemerkt, weil [didChangeDependencies] bei jeder
  /// Änderung der Umgebung erneut läuft, auch bei einem Tabwechsel: ohne diese
  /// Marke entstünden zwölf Bilder je Wechsel.
  double? _balloonPixelRatio;

  /// Ob die Ballonbilder beim Host angemeldet sind.
  ///
  /// Der Riegel vor [_deliverOverlay], siehe die Reihenfolge im
  /// Klassenkommentar. Er fällt genau einmal und geht nicht wieder zu: ein
  /// zweiter Durchgang mit anderem Bildverhältnis **ersetzt** Bilder, er nimmt
  /// keine weg.
  bool _balloonImagesRegistered = false;

  /// Die zuletzt geladene Überlagerung, oder `null`, solange keine geladen ist.
  ///
  /// Wird nach dem Ablegen **nicht** geleert, anders als ein Riegel: kommt
  /// später ein zweiter Satz Bilder (anderes Bildverhältnis), legt
  /// [_deliverOverlay] dieselbe Überlagerung noch einmal auf. Das ist gewollt,
  /// der Host ersetzt eine gleichnamige, und ein Symbol-Layer, dessen Bilder
  /// gewechselt haben, soll sie auch benutzen.
  MapOverlay? _latestOverlay;

  /// Ob die Näherungs-Animation bei der aktuellen Zoomstufe läuft.
  ///
  /// Ein `bool` und nicht die Zoomstufe selbst, und das ist der Unterschied
  /// zwischen einem Neuaufbau je Kamerabild und einem beim Überqueren einer
  /// Zoomgrenze. Die Zahl selbst braucht dieser Bildschirm nicht, sie gehört
  /// dem Zeichner.
  bool _animationRuns = false;

  /// Die Fakten, die gerade **nicht** nativ liegen, weil sie leben.
  ///
  /// ## Warum die native Liste überhaupt schrumpft
  ///
  /// Ein Fakt in Reichweite wird von [FactBalloonOverlay] als Widget über der
  /// Karte gezeichnet. Bliebe er zusätzlich im Symbol-Layer, stünde er
  /// doppelt da: einmal lebend, einmal als stehendes Bild darunter. Der
  /// Unterschied fällt genau dann auf, wenn er wächst, also im auffälligsten
  /// Moment.
  ///
  /// ## Warum das hier steht und nicht im Zeichner
  ///
  /// Weil die Überlagerung diesem Bildschirm gehört: er hält die Reihenfolge
  /// „erst Bilder, dann Punkte" ein, und die ist eine Zusage von
  /// `MapHost.registerOverlayImages`. Zwei Absender für dieselbe Überlagerung
  /// wären zwei Wahrheiten.
  ///
  /// **Der Preis ist ein Bild Versatz, und der ist bekannt.** Zeichner und
  /// Bildschirm hören beide auf den Kamerastrom und auf `factProximityProvider`
  /// und wenden beide dieselbe Regel [factAnimationRunsAt] an; welcher zuerst
  /// dran ist, entscheidet niemand. Der native Weg ist ohnehin asynchron, ein
  /// gemeinsamer Zeitpunkt wäre also auch mit einem gemeinsamen Zustand nicht
  /// zu haben.
  Set<String> _animatedIds = const <String>{};

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

    // **`listenManual` und nicht `ref.listen` im `build`, und der Grund ist
    // `fireImmediately`.** `ref.listen` kennt den Schalter in
    // `flutter_riverpod 3.4.2` nicht (`widget_ref.dart:227-232`), es meldet nur
    // **Änderungen**. Ein Bildschirm, der neu entsteht, während die Fakten
    // längst geladen sind, bekäme also nie eine Ausgabe und legte nie eine
    // Überlagerung auf. `listenManual` hat den Schalter
    // (`widget_ref.dart:249-255`) und räumt sich beim Entsorgen des Widgets
    // selbst auf, ein `close()` im `dispose` ist ausdrücklich nicht nötig.
    //
    // Und es ist ein Zuhören und kein `watch`: die Fakten ändern an diesem
    // Widget nichts, sie gehen an den Karten-Host. Ein `watch` baute das ganze
    // Top-Chrome neu, sobald 600 Fakten eintreffen.
    ref.listenManual(
      factOverlayProvider,
      _onFactOverlay,
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **Vor der Zweigprüfung, weil die früh zurückkehrt.** Die Ballonbilder
    // hängen am Bildverhältnis des Bildschirms, und das steht erst hier zur
    // Verfügung; ein `initState` hat noch keine `MediaQuery`.
    _ensureBalloonImages(MediaQuery.devicePixelRatioOf(context));

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

  /// Zeichnet die zwölf Ballons und meldet sie beim Karten-Host an.
  ///
  /// ## Warum das hier passiert und nicht im Karten-Host
  ///
  /// Weil hier die Kategorien bekannt sind. `lib/map/` darf nicht wissen, was
  /// eine Fakt-Kategorie ist (Regel 18); es bekommt fertige Bytes unter einer
  /// Stil-Kennung. Und weil nur ein Widget das Bildverhältnis des Bildschirms
  /// kennt: ein Bild für ein 3x-Gerät muss dreifach aufgelöst sein.
  ///
  /// ## Der Host ist zu diesem Zeitpunkt noch nicht eingeklinkt
  ///
  /// [didChangeDependencies] läuft, **bevor** die Kartenfläche als Kind gebaut
  /// ist, und erst deren `initState` klinkt den Host ein. Verloren geht
  /// trotzdem nichts: `MapHostRegistry` hebt Bilder und Überlagerungen auf und
  /// reicht sie beim Einklinken weiter, Bilder zuerst. Das ist dort begründet
  /// und ist der Grund, warum hier kein `addPostFrameCallback` steht.
  ///
  /// **Scheitert das Zeichnen, bleibt die Überlagerung liegen**, und das ist
  /// die richtige Seite: ohne Bilder zeichnet ein Symbol-Layer ohnehin nichts,
  /// eine aufgelegte Überlagerung wäre also unsichtbar und erzeugte zusätzlich
  /// zwölf Meldungen über unbekannte Kennungen. Der Fehlschlag selbst geht
  /// über [reportDetached] laut heraus.
  void _ensureBalloonImages(double pixelRatio) {
    if (_balloonPixelRatio == pixelRatio) {
      return;
    }
    _balloonPixelRatio = pixelRatio;
    // Vor der Unterbrechung gelesen: nach einem `await` ist `ref` nur noch
    // gültig, solange dieser `State` lebt, und die Registry ist ohnehin
    // dieselbe.
    final MapHost host = ref.read(mapHostProvider);
    reportDetached(
      buildFactBalloonImages(pixelRatio: pixelRatio).then((
        List<MapOverlayImage> drawn,
      ) {
        if (!mounted) {
          return;
        }
        host.registerOverlayImages(drawn);
        _balloonImagesRegistered = true;
        _deliverOverlay();
      }),
      origin: 'discovery.fact_balloons',
    );
  }

  /// Die Fakten sind da: auf die Karte damit.
  ///
  /// Ein Fehlschlag wird hier **nicht** in eine leere Überlagerung übersetzt.
  /// Eine leere Karte sähe aus wie eine Stadt ohne Fakten, und `FactRepository`
  /// trennt beides ausdrücklich. Was der Bildschirm einem Nutzer stattdessen
  /// zeigt, entscheidet der Schritt, der die Fehleranzeige baut; bis dahin
  /// bleibt der Fehlschlag im `AsyncValue` stehen, wo ihn jeder sieht, der ihn
  /// braucht.
  void _onFactOverlay(
    AsyncValue<MapOverlay>? previous,
    AsyncValue<MapOverlay> next,
  ) {
    final MapOverlay? overlay = next.value;
    if (overlay == null) {
      return;
    }
    _latestOverlay = overlay;
    _deliverOverlay();
  }

  /// Legt die wartende Überlagerung auf, sobald die Bilder angemeldet sind.
  ///
  /// Zwei Auslöser rufen das, und welcher zuerst kommt, entscheidet niemand:
  /// die geladenen Fakten und die fertig gezeichneten Bilder. Deshalb steht die
  /// vollständige Bedingung an einer Stelle statt an zweien, genau wie bei
  /// [_deliverPendingSkyFall].
  ///
  /// **Es gibt keinen Riegel wie beim Sky-Fall**, und das ist der Unterschied
  /// zwischen Ereignis und Zustand: eine Absicht wird einmal abgegeben, eine
  /// Überlagerung darf sich ändern. Der Host ersetzt eine gleichnamige.
  void _deliverOverlay() {
    final MapOverlay? overlay = _latestOverlay;
    if (overlay == null || !_balloonImagesRegistered) {
      return;
    }
    ref
        .read(mapHostProvider)
        .setOverlay(factOverlayWithout(overlay, _animatedIds));
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
    final bool runs = factAnimationRunsAt(view.zoom);
    if (runs != _animationRuns) {
      _animationRuns = runs;
      _syncAnimatedIds();
    }
    if (view.bearing != _bearingDegrees) {
      setState(() => _bearingDegrees = view.bearing);
    }
  }

  /// Gleicht ab, welche Fakten aus der nativen Liste fallen.
  ///
  /// Zwei Auslöser, und welcher zuerst kommt, entscheidet niemand: eine neue
  /// Ortung und das Überqueren der Gruppierungsgrenze. Deshalb steht die
  /// vollständige Bedingung an einer Stelle statt an zweien, genau wie bei
  /// [_deliverPendingSkyFall] und [_deliverOverlay].
  ///
  /// **Ohne Änderung passiert nichts.** Jeder Aufruf von `setOverlay` schiebt
  /// das vollständige GeoJSON über den Plattformkanal; bei fünf Ortungen je
  /// Sekunde wäre das fünfmal je Sekunde die ganze Sammlung, ohne dass sich
  /// etwas geändert hätte.
  void _syncAnimatedIds() {
    final Set<String> next = _animationRuns
        ? ref.read(factProximityProvider).ids
        : const <String>{};
    if (setEquals(next, _animatedIds)) {
      return;
    }
    _animatedIds = next;
    _deliverOverlay();
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
    // **Zuhören und nicht beobachten.** Wer in Reichweite ist, ändert an
    // diesem Bildschirm nichts Sichtbares; es entscheidet allein darüber,
    // welche Punkte nativ liegen. Ein `watch` baute das ganze Top-Chrome bei
    // jeder Ortung neu.
    ref.listen(factProximityProvider, (
      FactProximity? previous,
      FactProximity next,
    ) {
      _syncAnimatedIds();
    });
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
        // **Unmittelbar über der Kartenfläche und im selben `Stack`.** Die
        // Bildschirmlagen, die das Karten-SDK liefert, zählen ab der linken
        // oberen Ecke **der Karte** (`controller.dart:1779`); ein Rahmen
        // dazwischen verschöbe jeden Ballon. Und unter dem Top-Chrome, damit
        // ein wachsender Ballon nicht über die Stadt-Pille läuft.
        const FactBalloonOverlay(),
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
