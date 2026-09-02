import 'dart:async';
import 'dart:math' as math;

import 'package:fact_app/app/routing/app_routes.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/features/discovery/presentation/discovery_balloon_anchor.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_collect_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_group_expand.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/features/discovery/presentation/map_camera_intents.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_beacon_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/discovery/presentation/widgets/map_top_chrome.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/bearing_smoothing.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_position_rect.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/domain/map_viewport.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/orientation/device_heading.dart';
import 'package:fact_app/services/orientation/orientation_providers.dart';
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
/// **Was beim Antippen eines einzelnen Ballons passiert, steht bewusst nicht
/// hier.** Es steht in `fact_collect_overlay.dart`, seit Schritt 20; dieser
/// Bildschirm setzt das Widget nur ein und liefert die drei Dinge, die die
/// Komposition angehen: die angezeigte Münzzahl, wohin der Sammel-Rückruf
/// geht und wie das Fakt-Blatt geöffnet wird. **Der Tipp auf eine Gruppe
/// dagegen hat seit Schritt 15 Block 3 einen Empfänger hier**, [_onGroupTap]:
/// er fährt die Kamera auf ein Rechteck, das die eigenen, genäherten
/// Gruppenmitglieder umschließt.
///
/// ## Seit Schritt 17 liegen die nahen Fakten nicht mehr nativ
///
/// `FactBalloonOverlay` zeichnet die Handvoll Fakten innerhalb von 150 Metern
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
  const MapPage({
    required this.mapSurface,
    this.huntOverlay,
    this.now,
    super.key,
  });

  /// Die Kartenfläche, die unter dem Top-Chrome liegt.
  ///
  /// Verpflichtend und nicht `null`-fähig: ein Standard wäre eine leere Fläche,
  /// und eine Karte, die aus Versehen fehlt, sähe dann genauso aus wie eine,
  /// die noch lädt.
  final Widget mapSurface;

  /// Die Jagd-Pille der laufenden Solo-Jagd, `HuntPill` in
  /// `screen-map.jsx:1011-1135`, Schritt 37.
  ///
  /// **Nullbar, und das ist der Gegensatz zu [mapSurface] und aus demselben
  /// Grund bewusst.** [mapSurface] ist verpflichtend, weil ein Standard dafür
  /// eine leere Fläche wäre und eine fehlende Karte optisch nicht von einer
  /// ladenden zu unterscheiden ist. Für das Jagd-Overlay gilt das Gegenteil:
  /// **kein** Overlay ist der weit überwiegende Normalzustand dieses
  /// Bildschirms, denn die allermeiste Zeit läuft gar keine Jagd. `HuntPill`
  /// zeigt sich in diesem Fall selbst nicht (siehe seinen Kopfkommentar), ein
  /// `null` hier ist also keine Notlösung, sondern deckt sich mit dem, was das
  /// Widget ohnehin täte. Ein Pflichtparameter zwänge jeden Aufrufer ohne
  /// laufende Jagd, trotzdem ein Widget zu bauen (und via `challenges`
  /// aufzulösen), nur um es sofort nichts zeichnen zu lassen.
  final Widget? huntOverlay;

  /// Die Uhr des Kompass-Wachhunds, siehe `_MapPageState._now`.
  ///
  /// `null` im echten Betrieb: dann legt der Zustand selbst eine laufende
  /// [Stopwatch] an. Ein Test setzt einen eigenen Rückgabewert, um die
  /// verstrichene Zeit ohne echtes Warten vorzuspulen, dasselbe Muster wie
  /// `now` bei `MapCameraHost`.
  final Duration Function()? now;

  /// Münzstand ohne `features/progression`.
  static const int placeholderCoins = 0;

  /// Levelnummer ohne `features/progression`.
  static const int placeholderLevel = 1;

  /// Fortschritt im Level ohne `features/progression`, in Prozent.
  static const double placeholderLevelPercent = 0;

  /// Die Zahl, die der Münzflug beim Sammeln anzeigt.
  ///
  /// ## Warum sie hier steht und nicht im Widget
  ///
  /// Weil sie zur Ökonomie gehört und die gehört `features/progression`,
  /// genau wie [placeholderCoins] darüber. `FactCollectBurst.coinAmount` ist
  /// **erforderlich**, damit niemand versehentlich eine stille
  /// Voreinstellung erbt; entschieden wird die Zahl also hier, an derselben
  /// Stelle wie die anderen Platzhalter dieser Domäne.
  ///
  /// ## Woher die 10 kommt, und was daran unangenehm ist
  ///
  /// Gemessen am 02.09.2026, drei Zahlen für dasselbe Ereignis:
  ///
  /// | Zahl | Fundstelle |
  /// |---|---|
  /// | 12 | die Anzeige der Quelle, `screen-map.jsx:1196` |
  /// | 50 | was der Solo-Sammelweg wirklich bucht, `app.jsx:712` und `:714` |
  /// | 10 | `collect_fact_validated`, `supabase-schema.sql:125` und `:127` |
  ///
  /// **Gewählt ist die 10**, und zwar nicht, weil sie die Anzeige der Quelle
  /// wäre (die ist 12 und stimmt mit keiner Buchung überein, das ist die
  /// Anzeigehälfte von E-06), sondern weil sie die einzige **serverseitig**
  /// entschiedene ist. Die 50 kommt aus dem Zweig, in dem der Client den
  /// Betrag selbst bestimmt, und genau diesen Zweig verwirft der Neubau
  /// ausdrücklich („der Client bestimmt nie einen gutgeschriebenen Betrag",
  /// E-06, und „der Server ist die einzige Wahrheit", E-49).
  ///
  /// **Die Wahl ist damit nicht abgeschlossen.** `collect_fact_validated` hat
  /// in der ganzen Referenz **keinen Aufrufer**; die 10 ist heute toter Code.
  /// Welche Zahl der Neubau gutschreibt, hängt am Belohnungsjournal (J-C) und
  /// ist eine offene Entscheidung. Bis sie fällt, zeigt diese Zeile die
  /// serverseitige Zahl an und keine erfundene.
  static const int collectCoinAmount = 10;

  /// Gemeldet, wenn gesammelt wurde und **die Münzen** niemand verbucht hat.
  ///
  /// ## Warum ein Diagnose-Ereignis und nicht schlicht nichts
  ///
  /// Weil „nichts" von „vergessen" nicht zu unterscheiden wäre. Der
  /// Sammel-Rückruf feuert an der richtigen Stelle und zur richtigen Zeit,
  /// nur nimmt die Buchung niemand an: das Buchungsjournal aus J-C ist eine
  /// Entscheidung der Stufe 3, es gibt weder Tabelle noch RPC dafür. Dieses
  /// Ereignis ist die ehrliche Markierung dieser Naht, und es ist die Stelle,
  /// an der die Buchung angeschlossen wird.
  ///
  /// **Seit dem 02.09.2026 ist es nur noch die halbe Naht.** Bis dahin
  /// passierte beim Sammeln überhaupt nichts, was den Start überlebt; seit
  /// `CollectedFactsStore` geht der Fakt in die Sammlung. Offen ist allein
  /// die Gutschrift. Wer den Namen dieses Ereignisses liest, soll nicht mehr
  /// glauben, das Sammeln selbst käme nicht an.
  ///
  /// **Es feuert nicht im Sekundentakt**, anders als die Ereignisse, die
  /// dieses Repository sonst bewusst vermeidet: höchstens einmal je
  /// gesammeltem Fakt.
  static const String unbookedCollectEvent = 'discovery.collect.unbooked';

  /// Gemeldet, wenn eine Fakt-Kennung aus der Überlagerung keine Zahl ist.
  ///
  /// Ein Verdrahtungsfehler und kein Normalfall, siehe [_MapPageState._onOpenFact].
  /// Die Kennung darf hier ins Log, denn sie ist genau das Kaputte; eine
  /// Koordinate steht nicht daneben.
  static const String unreadableFactIdEvent = 'discovery.collect.unreadable_id';

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
  ///
  /// **Der Kompass läuft aus derselben Erwägung weiter mit, seit Schritt 14
  /// Teil 2.** [_headingSubscription] bleibt bestehen und [_compassWatchdog]
  /// tickt unbedingt weiter, auch während dieser Zweig unsichtbar ist; nur
  /// [compassBearingFollowIntent] geht nicht an den Host, solange [_canSteer]
  /// `false` ist, siehe [_onHeading]. Die Nebenwirkung, die das in Kauf
  /// nimmt: der Sensor bleibt an und [_smoothedBearing] läuft weiter, auch
  /// während der Nutzer einen anderen Reiter ansieht. Der Gewinn ist derselbe
  /// wie beim GPS: kommt der Nutzer zurück, folgt die Karte sofort einer
  /// eingelebten Richtung statt eines kaltgestarteten Werts, der erst wieder
  /// anlaufen müsste, und der Wachhund zeigt beim Zurückkommen den wahren
  /// Stand, keine künstliche Pause, die nur am Tabwechsel lag. Der
  /// Gegenkandidat, das Abonnement beim Verstecken abzubauen, spart den
  /// Sensor, kostet aber genau diesen kalten Neustart der Glättung.
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

  /// Die geglättete Kompass-Blickrichtung, siehe [SmoothedBearing.towards].
  ///
  /// **Startwert 0, aus zwei Gründen und nicht nur, weil die Quelle so
  /// beginnt.** `let smoothBearing = 0;` (`screen-map.jsx:2805`) ist der
  /// Startwert dort, aber ein Nachbau, der nur deshalb 0 wählt, hätte hier
  /// keine eigene Begründung, sondern nur die abgeschriebene. Die zweite,
  /// eigene: [MapPage.placeholderCamera.bearing] ist ebenfalls 0, die
  /// Startkamera zeigt also bereits genau dorthin, wo diese Glättung
  /// beginnt. Ein anderer Startwert liefe der sichtbaren Kamera von der
  /// ersten Sekunde an hinterher, ohne dass ein einziger Kopfwert das
  /// verlangt hätte.
  SmoothedBearing _smoothedBearing = SmoothedBearing(
    MapPage.placeholderCamera.bearing,
  );

  /// Zuhörer auf rohe Kopfwerte des Kompasses, siehe [_onHeading].
  StreamSubscription<DeviceHeading>? _headingSubscription;

  /// Wann der letzte Kopfwert einging, gemessen mit [_now].
  ///
  /// Bekommt in [initState] schon vor dem ersten Kopfwert einen Startwert,
  /// dieselbe „Baseline, damit der Wachhund nicht sofort anschlägt" wie
  /// `compassLastEventRef.current = Date.now()` bei der Registrierung der
  /// Quelle (`screen-map.jsx:2858`). Ohne sie wäre der Kompass in der Sekunde
  /// zwischen Bildschirmstart und erstem Sensorwert fälschlich „tot".
  Duration? _lastHeadingAt;

  /// Der Wachhund-Takt, `screen-map.jsx:2846-2853`: alle 2 Sekunden geprüft,
  /// ob seit [_lastHeadingAt] mehr als [compassStaleAfter] vergangen ist,
  /// siehe [_checkCompassAlive].
  Timer? _compassWatchdog;

  /// Ob der Kompass gerade als tot gilt, siehe [_checkCompassAlive]. Geht an
  /// [MapTopChrome.isCompassDead].
  bool _isCompassDead = false;

  /// Jetzt, als Abstand zu einem monotonen Nullpunkt. Nur der Wachhund
  /// braucht das, um zu messen, wie lange der letzte Kopfwert her ist.
  ///
  /// ## Warum eine [Duration] und keine [DateTime]
  ///
  /// Dieselbe Erwägung wie in `map_camera_gate.dart` und
  /// `map/presentation/map_camera_host.dart`: eine Uhr, die rückwärts
  /// springen kann, ist für eine Karenzzeit die falsche Uhr. Anders als dort
  /// hat `map_page.dart` selbst noch kein eigenes Muster dafür, aber
  /// `MapCameraHost` hat exakt eines, für exakt dieselbe Aufgabenklasse
  /// (`Duration Function()? now`, Standard eine laufende [Stopwatch]), und es
  /// ist bereits geprüft: `map_camera_host_test.dart` steuert es über einen
  /// `TestClock`, ohne echtes Warten. Diese Datei übernimmt das Muster
  /// unverändert, statt ein zweites, eigenes zu erfinden.
  ///
  /// **Das ist die eine Stelle, an der diese Datei von der wörtlichen Vorgabe
  /// abweicht, `DateTime.now` als Standard zu nehmen, und der Grund ist
  /// mehr als Geschmack:** `DateTime.now()` springt bei `tester.pump(Duration)`
  /// nicht mit vor, `fake_async` (das dahinterliegt) verspult nur `Timer`,
  /// `Future.delayed` und `Stopwatch`, nicht die Wanduhr. Ein Wachhund-Test
  /// gegen `DateTime.now()` bräuchte entweder `package:clock` (ein neues
  /// Paket, freigabepflichtig) oder echtes Warten (von `.claude/rules/tests.md`
  /// verboten). Der `Duration`-Weg braucht beides nicht.
  late final Duration Function() _now;

  /// Zuhörer auf Gruppen-Tipps, siehe [_onGroupTap].
  ///
  /// Ein eigenes Abonnement und kein zweiter Zweig in [_onCameraChange]:
  /// `MapHost.groupTaps` ist ein eigener Strom, vier Features teilen sich
  /// ihn, und dieser Bildschirm filtert selbst auf [factOverlayId].
  StreamSubscription<MapOverlayGroupTap>? _groupTapSubscription;

  /// Ob gerade eine Projektion für einen Gruppen-Tipp unterwegs ist.
  ///
  /// Die dritte Stelle mit demselben Zusammenfassungs-Muster wie
  /// `discovery_balloon_anchor.dart` (`_selectionInFlight`) und
  /// `fact_balloon_overlay.dart` (`_projectionInFlight`), hier aber mit einem
  /// Unterschied in der Auswertung, siehe [_onGroupTap]: dort darf eine
  /// veraltete Antwort noch gelten, weil sie nur einen Bildschirmzustand neu
  /// zeichnet, den die nächste Antwort ohnehin gleich wieder überschreibt.
  /// Hier gibt eine Antwort eine **einmalige** Kameraabsicht ab
  /// (`MapCameraOneShot`, „es gibt keine Warteschlange"), und die nimmt
  /// niemand zurück: kommt die Antwort auf einen älteren Tipp erst nach der
  /// eines neueren zurück, überschriebe ihre Absicht die frische, und die
  /// Kamera führe auf die falsche Gruppe zurück. Nicht die zweite Anfrage ist
  /// dabei das Problem, sondern die veraltete Antwort auf die erste.
  bool _groupTapInFlight = false;

  /// Der jüngste Gruppen-Tipp, der während einer laufenden Anfrage eintraf.
  ///
  /// Es gibt keine Warteschlange: trifft während der laufenden Anfrage noch
  /// ein zweiter und danach ein dritter Tipp ein, verwirft der dritte den
  /// zweiten hier, nicht umgekehrt. Bei Einmal-Absichten gewinnt die letzte.
  MapOverlayGroupTap? _pendingGroupTap;

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
  /// Ein Fakt in Reichweite wird von `FactBalloonOverlay` als Widget über der
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

    // Aus demselben Grund vor der Kartenfläche wie das Abonnement oben: ein
    // Tipp, der vor diesem Aufruf einträfe, wäre für immer verpasst.
    _groupTapSubscription = ref
        .read(mapHostProvider)
        .groupTaps
        .listen(_onGroupTap);

    // Der Kompass, seit Schritt 14 Teil 2. Keine Reihenfolge-Zwangslage wie
    // bei den beiden Strömen oben: `OrientationService` hängt an keinem Kind
    // dieses Bildschirms, ein später eintreffender erster Kopfwert geht nicht
    // verloren, er wartet einfach auf sein Abonnement.
    _now = widget.now ?? _stopwatchClock();
    _lastHeadingAt = _now();
    _headingSubscription = ref
        .read(orientationServiceProvider)
        .headingUpdates()
        .listen(_onHeading);
    _compassWatchdog = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkCompassAlive(),
    );

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

    // **Nur halten, nicht lesen.** `FactBeaconNotifier` gibt es für seine
    // Wirkung: er hört am Ortungsstrom und macht bei Nähe ein Geräusch. Ein
    // Provider, den niemand liest, entsteht in Riverpod nie, und dann bliebe
    // der Audio-Beacon still, ohne Fehler und ohne Meldung. Diese Zeile ist
    // sein einziger Halter.
    //
    // Der leere Rückruf ist Absicht: an seiner Zählung hängt hier nichts,
    // und ein `watch` baute diesen Bildschirm bei jedem Hinweiston neu.
    ref.listenManual(factBeaconProvider, (int? previous, int next) {});
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
    unawaited(_groupTapSubscription?.cancel());
    _groupTapSubscription = null;
    unawaited(_headingSubscription?.cancel());
    _headingSubscription = null;
    _compassWatchdog?.cancel();
    _compassWatchdog = null;
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

  /// Ein roher Kopfwert des Kompasses ist da, `screen-map.jsx:2817-2843`.
  ///
  /// Drei Dinge passieren, und nur eines davon bedingt:
  ///
  /// 1. [_lastHeadingAt] wird **unbedingt** nachgeführt, der Wachhund-Puls.
  /// 2. War der Kompass als tot markiert, wird das **hier** zurückgenommen,
  ///    nicht erst beim nächsten Takt des Wachhunds: `if (compassDead)
  ///    setCompassDead(false);` steht in der Quelle im Kopfwert-Zweig
  ///    (`:2828`), nicht im Zwei-Sekunden-Takt.
  /// 3. Die Glättung zieht in Richtung [heading], **immer**, siehe
  ///    [_smoothedBearing].
  ///
  /// Erst danach die eine bedingte Wirkung: die Absicht geht nur an den Host,
  /// wenn [_canSteer] gilt. Läuft der Bildschirm im unsichtbaren Zweig oder
  /// ohne lebende Karte, bleiben Glättung und Zeitstempel trotzdem aktuell,
  /// siehe die Begründung bei [_branchIsActive].
  ///
  /// **`setState` nur, wenn sich [_isCompassDead] wirklich ändert.** Ein
  /// Strom, der bis zu 60 Mal je Sekunde einen neuen Kopfwert liefert, darf
  /// nicht bei jedem einzelnen den ganzen Bildschirm neu bauen; dieselbe
  /// Zusicherung wie bei [_onCameraChange] für `view.bearing`, nur auf der
  /// Zeitachse statt auf der Winkelachse. Die Glättung selbst braucht kein
  /// `setState`: [_smoothedBearing] wird nirgends direkt gezeichnet, sie geht
  /// nur in die nächste Absicht ein.
  void _onHeading(DeviceHeading heading) {
    _lastHeadingAt = _now();
    if (_isCompassDead) {
      setState(() => _isCompassDead = false);
    }
    _smoothedBearing = _smoothedBearing.towards(heading.degrees);
    if (!_canSteer) {
      return;
    }
    ref
        .read(mapHostProvider)
        .submitIntent(
          compassBearingFollowIntent(bearing: _smoothedBearing.degrees),
        );
  }

  /// Der Wachhund-Takt, `screen-map.jsx:2846-2853`: prüft alle 2 Sekunden, ob
  /// der Kompass seit mehr als [compassStaleAfter] keinen Kopfwert mehr
  /// geliefert hat, und meldet das Ergebnis an [MapTopChrome.isCompassDead].
  ///
  /// **`setState` nur bei echter Änderung**, aus demselben Grund wie in
  /// [_onHeading]: ein Takt, der bei jedem Aufruf neu baut, obwohl sich am
  /// Ergebnis nichts geändert hat, ist derselbe Fehler wie ein 60-Hz-Strom
  /// ohne Totzone, nur langsamer.
  void _checkCompassAlive() {
    final Duration? lastHeadingAt = _lastHeadingAt;
    final bool dead =
        lastHeadingAt != null &&
        isCompassStale(sinceLastHeading: _now() - lastHeadingAt);
    if (dead == _isCompassDead) {
      return;
    }
    setState(() => _isCompassDead = dead);
  }

  /// Ein Tipp auf eine Gruppe, `screen-map.jsx:2439-2459`.
  ///
  /// ## Vier Features teilen sich `groupTaps`
  ///
  /// Verarbeitet wird nur ein Tipp auf die **eigene** Überlagerung, siehe
  /// [factOverlayId]. Ein Tipp auf eine fremde Gruppe geht diesen Bildschirm
  /// nichts an.
  ///
  /// ## Die Kandidaten sind die wirklich nativ liegenden Punkte
  ///
  /// Nicht `_latestOverlay` selbst, sondern
  /// `factOverlayWithout(_latestOverlay!, _animatedIds).points`, dieselbe
  /// Übersetzung, die [_deliverOverlay] auch an den Host schickt. Die
  /// ausgeblendeten, lebenden Ballons sind Flutter-Widgets über der Karte und
  /// stecken in **keiner** nativen Gruppe; die volle Liste zöge Punkte ins
  /// Rechteck, die MapLibre gar nicht zusammengefasst hat.
  ///
  /// ## Die Näherung, mitprojiziert im selben Aufruf
  ///
  /// Die Kandidatenpositionen und die getippte Stelle gehen in **einem**
  /// `projectToScreen`-Aufruf hinaus, damit beide Seiten im selben
  /// Bildschirmraster landen; siehe `fact_group_expand.dart`,
  /// `selectGroupMembers`, für die Auswahlregel selbst und ihre
  /// Fehlerrichtung.
  ///
  /// ## Nie zwei Anfragen gleichzeitig, und die veraltete Antwort zählt nicht
  ///
  /// Läuft schon eine Anfrage, wird ein neuer Tipp nur in [_pendingGroupTap]
  /// gemerkt und erst nach der laufenden verarbeitet, siehe
  /// [_groupTapInFlight] für die Begründung. Trifft dabei ein dritter Tipp
  /// ein, verwirft er den zweiten, denn bei Einmal-Absichten gewinnt die
  /// letzte, nicht die erste.
  ///
  /// Kommt die Antwort auf einen Tipp zurück, während schon ein neuerer
  /// gemerkt ist, entsteht aus dieser Antwort **keine** Absicht mehr: sie
  /// gehört zu einem Tipp, den der Nutzer bereits hinter sich gelassen hat,
  /// und eine `MapCameraOneShot`-Absicht kann niemand zurücknehmen. Ohne
  /// diese Prüfung führe die Kamera kurz auf die richtige Gruppe und dann,
  /// sobald die veraltete Antwort eintrifft, wieder auf die falsche zurück.
  ///
  /// ## Nach der Unterbrechung
  ///
  /// `projectToScreen` liefert ein `Future`; nach dem `await` wird geprüft, ob
  /// dieser `State` noch lebt (`mounted`) und ob der Host noch eine Fläche
  /// kennt (`host.viewport`, erneut gelesen und nicht der Stand von vor dem
  /// Aufruf). Ohne beide Prüfungen könnte eine `setState`-freie, aber
  /// trotzdem falsche Absicht bei einem längst entsorgten Bildschirm
  /// abgegeben werden.
  ///
  /// Findet die Näherung keinen einzigen Punkt, entsteht keine Absicht,
  /// siehe [groupTapFoundNoMembersEvent] für die Begründung, warum das
  /// trotzdem gemeldet wird.
  void _onGroupTap(MapOverlayGroupTap tap) {
    if (tap.overlayId != factOverlayId) {
      return;
    }
    if (_groupTapInFlight) {
      _pendingGroupTap = tap;
      return;
    }
    final MapOverlay? overlay = _latestOverlay;
    if (overlay == null) {
      return;
    }
    final MapHost host = ref.read(mapHostProvider);
    if (host.viewport == null) {
      // Vor dem ersten Layout der Kartenfläche entsteht keine Absicht: ohne
      // Fläche kann `rectFitZoom` nicht rechnen, siehe dort.
      return;
    }
    final List<MapOverlayPoint> candidates = factOverlayWithout(
      overlay,
      _animatedIds,
    ).points;
    if (candidates.isEmpty) {
      return;
    }

    _groupTapInFlight = true;
    reportDetached(
      host
          .projectToScreen(<MapPosition>[
            for (final MapOverlayPoint point in candidates) point.position,
            tap.position,
          ])
          .then((List<MapScreenPoint?> located) {
            final MapViewport? viewport = host.viewport;
            if (!mounted || viewport == null) {
              return;
            }
            if (_pendingGroupTap != null) {
              // Während diese Anfrage unterwegs war, ist schon ein neuerer
              // Tipp eingetroffen. Diese Antwort gehört zum veralteten Tipp,
              // siehe [_groupTapInFlight]; sie löst keine Absicht mehr aus,
              // das übernimmt gleich die Anfrage zum gemerkten Tipp.
              return;
            }
            final MapScreenPoint? tapAt = located.last;
            if (tapAt == null) {
              return;
            }
            final List<MapOverlayPoint> selected = selectGroupMembers(
              candidates: candidates,
              candidateScreenPositions: located.sublist(0, candidates.length),
              tapScreenPosition: tapAt,
              radiusInStylePixels: factOverlayGrouping.radiusInScreenPixels,
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            if (selected.isEmpty) {
              ref
                  .read(diagnosticSinkProvider)
                  .report(DiagnosticEvent(groupTapFoundNoMembersEvent));
              return;
            }
            final MapPositionRect rect = MapPositionRect.enclosingOrNull(
              <MapPosition>[
                for (final MapOverlayPoint point in selected) point.position,
              ],
            )!;
            host.submitIntent(
              groupExpandIntent(rect: rect, viewport: viewport),
            );
          })
          .whenComplete(() {
            _groupTapInFlight = false;
            if (!mounted) {
              return;
            }
            final MapOverlayGroupTap? pending = _pendingGroupTap;
            if (pending != null) {
              _pendingGroupTap = null;
              _onGroupTap(pending);
            }
          }),
      origin: 'discovery.group_tap',
    );
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

  /// Es wurde gesammelt, `onCollectFact` in `screen-map.jsx:3069`.
  ///
  /// Zwei Dinge sind hier eine Zeile auseinander und im Neubau ausdrücklich
  /// getrennt, genau wie in `app.jsx:709-712`:
  ///
  ///  1. **Der Fakt geht in die Sammlung**, dauerhaft. Das ist der Teil, den
  ///     der Client entscheiden darf: *was* er gefunden hat.
  ///  2. **Die Münzen werden nicht verbucht.** Das ist der Teil, den er nicht
  ///     entscheiden darf, siehe [MapPage.unbookedCollectEvent].
  ///
  /// **Eine nicht lesbare Kennung sammelt nichts**, dieselbe Regel wie in
  /// [_onOpenFact] und aus demselben Grund: die Kennungen setzt
  /// `factOverlayOf` selbst aus `Fact.id`, ein Fehlschlag wäre also ein
  /// Verdrahtungsfehler. Er wird dort gemeldet, wo er auffällt, und nicht
  /// zweimal; deshalb steht hier keine eigene Meldung. Der Rückfall ist
  /// unterschiedlich: die Akte bleibt zu, die Sammlung bleibt unverändert,
  /// und die Animation läuft in beiden Fällen, weil sie schon lief.
  void _onFactCollected(String factId) {
    final int? id = int.tryParse(factId);
    if (id != null) {
      // `read` und nicht `watch`: das ist ein Befehl aus einem Rückruf und
      // keine Abhängigkeit dieses Bildes. Das Ergebnis wird bewusst nicht
      // abgewartet, der Vertrag verspricht, dass es nicht wirft.
      reportDetached(
        ref.read(collectedFactsProvider.notifier).collect(FactId(id)),
        origin: 'discovery.collect.persist',
      );
    }
    ref
        .read(diagnosticSinkProvider)
        .report(
          // **Ohne die Fakt-Kennung**, und das ist keine Sparsamkeit:
          // zusammen mit der öffentlich bekannten Koordinate dieses Fakts
          // wäre sie eine genaue Standortspur, und `security.md` §6 verbietet
          // genau das. Dass gesammelt wurde, ist die ganze Aussage, die
          // dieses Ereignis tragen muss.
          DiagnosticEvent(MapPage.unbookedCollectEvent),
        );
  }

  /// Das Fakt-Blatt öffnen, `onSelectFact` in `screen-map.jsx:3075`.
  ///
  /// ## Der einzige Einstieg in `FactRoute`, und er trägt die Bedingung
  ///
  /// `app_routes.dart` hält an der Route fest, dass die Akte niemals ohne
  /// räumliche Nähe erreichbar sein darf, mit dem Wortlaut des Fixes aus der
  /// Quelle. Dieser Aufruf ist der erste und einzige Einstieg, und er liegt
  /// hinter `decideFactTap`: hierher kommt nur, wer innerhalb des
  /// Sammelradius getippt hat, mit einer Ortung. Wer einen zweiten Einstieg
  /// legt, muss dieselbe Bedingung mitbringen.
  ///
  /// Die Kennung kommt als Zeichenkette aus der Überlagerung, weil GeoJSON
  /// nur Zeichenketten trägt; hier wird sie in die Zahl der Route
  /// zurückverwandelt. **Ein nicht lesbarer Wert öffnet nichts**, statt mit
  /// einem `!` abzustürzen: die Kennungen setzt `factOverlayOf` selbst aus
  /// `Fact.id`, ein Fehlschlag wäre also ein Verdrahtungsfehler und keine
  /// Nutzereingabe, und ein Absturz auf der Karte wäre die teuerste Art, ihn
  /// zu melden.
  void _onOpenFact(String factId) {
    final int? id = int.tryParse(factId);
    if (id == null) {
      ref
          .read(diagnosticSinkProvider)
          .report(
            DiagnosticEvent(MapPage.unreadableFactIdEvent, <String, String>{
              'factId': factId,
            }),
          );
      return;
    }
    FactRoute(factId: id).go(context);
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
        // dazwischen verschöbe jeden Ballon und jede Münze. Und unter dem
        // Top-Chrome, damit ein wachsender Ballon nicht über die Stadt-Pille
        // läuft.
        //
        // `FactCollectOverlay` enthält `FactBalloonOverlay`, es steht hier
        // also nicht zusätzlich. Warum die beiden zusammengehören, steht im
        // Kopf von `fact_collect_overlay.dart`: ein naher Ballon liegt nicht
        // nativ, sein Tipp kommt deshalb aus dem Zeichner und nicht aus
        // `MapHost.pointTaps`.
        FactCollectOverlay(
          coinAmount: MapPage.collectCoinAmount,
          onCollected: _onFactCollected,
          onOpenFact: _onOpenFact,
        ),
        // Meldet den Tutorial-Anker `DiscoveryAnchors.balloon` an, ohne selbst
        // etwas zu zeichnen; siehe `discovery_balloon_anchor.dart`. Nach
        // `FactBalloonOverlay`, damit beide dieselbe Kartenfläche als
        // Bezugspunkt für ihre Bildschirmlagen haben.
        const DiscoveryBalloonAnchor(),
        // Die Jagd-Pille, `screen-map.jsx:1011-1135`: über der Tab-Leiste und
        // unter dem Top-Chrome, wie die Quelle sie zeigt. **Vor**
        // `MapTopChrome` im Baum, damit das Chrome bei einer zufälligen
        // Überlappung sichtbar bleibt (Malreihenfolge = Reihenfolge im Baum,
        // wie im Klassenkommentar von `MapTopChrome` begründet).
        //
        // `bottom: calc(max(24px, env(safe-area-inset-bottom, 0px)) + 70px)`,
        // `left/right: 12`, `:1074`. Übernommen ist die Rechnung der Quelle
        // wörtlich und nicht ein Bezug auf `FloatingTabBar`: die Pille kennt
        // die Maße der schwebenden Tab-Leiste nicht, und beide sind
        // unabhängig voneinander gegen die sichere Fläche bemessen.
        //
        // **Eine gemessene Abweichung in der Malreihenfolge, und sie ist
        // bewusst offen gelassen.** Die Quelle staffelt: Ballons im
        // Kartencontainer auf `zIndex:0` (`:3086`), Jagd-Pille auf 50
        // (`:1074`), Mini-Vorschau auf 60 (`:3845`), Münzflug auf 70
        // (`:1183`). Hier liegt die Pille **über** Vorschau und Münzflug,
        // weil `FactCollectOverlay` beide zusammen mit den Ballons trägt und
        // die Ballons unten bleiben müssen. Sichtbar wird der Unterschied nur,
        // wenn eine Jagd läuft **und** der Nutzer einen fernen Ballon
        // antippt: die Vorschau (unten 110, Höhe rund 72) und die Pille
        // (unten 94, Höhe 60) überlappen dann, und die Pille verdeckt sie.
        //
        // Jede der drei Auflösungen kostet mehr, als sie hier einbringt: ein
        // dritter Registry-Zwischenspeicher für den Ballon-Tipp, ein
        // `GlobalKey` auf einen öffentlichen `State`, oder ein Widget-Schlitz
        // in `FactCollectOverlay`, dessen einziger Zweck die Malreihenfolge
        // wäre. Die Behebung ist später ein Parameter; solange steht sie
        // hier, gemessen, statt unbemerkt zu sein.
        if (widget.huntOverlay != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: math.max(24, MediaQuery.paddingOf(context).bottom) + 70,
            child: widget.huntOverlay!,
          ),
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
          // Die Nadel dreht weiterhin gegen die **Kartenblickrichtung**
          // (`:1792`) und nicht gegen den Rohwert des Kompasses; das ist ein
          // Unterschied und keine Doppelung mit dem Kompass-Folgen seit
          // Schritt 14 Teil 2. Der Gerätekompass (`:2805-2840`, [_onHeading])
          // lässt die Karte seiner Richtung folgen, aber nur, wenn die
          // Winkel-Totzone und das Gate es zulassen; wie weit die Karte
          // wirklich gedreht hat, kommt unverändert aus dem Kamerastrom, den
          // dieser Bildschirm ohnehin abonniert, und genau den zeigt die
          // Nadel.
          bearingDegrees: _bearingDegrees,
          // Der Wachhund meldet einen toten Kompass, siehe
          // [_checkCompassAlive].
          isCompassDead: _isCompassDead,
          // `isDark` bleibt beim Standard `false`, weil `mapDark` in der
          // Quelle nie `true` wird, siehe `MapTopChrome.isDark`.
        ),
      ],
    );
  }

  /// Die Standarduhr des Kompass-Wachhunds: eine laufende [Stopwatch], die
  /// dieser Zustand selbst anlegt. Wortgleiches Vorbild:
  /// `MapCameraHost._stopwatchClock` in `map/presentation/map_camera_host.dart`.
  static Duration Function() _stopwatchClock() {
    final Stopwatch watch = Stopwatch()..start();
    return () => watch.elapsed;
  }
}
