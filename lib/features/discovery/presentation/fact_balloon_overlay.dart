/// Die lebenden Ballons: die Handvoll Fakten innerhalb von 150 Metern, als
/// Flutter-Widgets über der Karte.
///
/// ## Warum das überhaupt Flutter ist und nicht nativ bleibt
///
/// Die naheliegende Lösung wäre gewesen, Größe und Glühen über eine
/// Merkmalseigenschaft an den Symbol-Layer zu geben und nur die Drehung
/// darüber zu legen. **Das geht nicht, und der Bruch liegt bei der Größe:**
/// `icon-size` skaliert **das ganze Bild**, die Quelle vergrößert aber nur den
/// Kopf (`screen-map.jsx:2257-2258` fasst ausschließlich `.coin-head` an).
/// Stiel (`:1862`, 50 px) und Bodenschatten behalten ihre Maße. Ein
/// `icon-size` von 1,85 machte aus dem Stiel 92 Pixel und höbe den Kopf fast
/// doppelt so hoch über seine Koordinate.
///
/// Die Punkte in Reichweite verlassen deshalb die native Überlagerung
/// (`factOverlayWithout`) und werden hier gezeichnet. **Alles außerhalb bleibt
/// exakt so nativ wie zuvor**, und das ist der Grund, warum diese Lösung
/// weniger kostet und nicht mehr: kein zusammengesetzter Zoom-und-Eigenschaft-
/// Ausdruck, kein Neubau von 600 Merkmalen im GPS-Takt über den
/// Plattformkanal, und kein Zusatz am Kartenvertrag außer der Projektion
/// selbst.
///
/// ## Was hier je Bild passiert und was ausdrücklich nicht
///
/// Je **Bild** ändern sich genau zwei Zahlen, und beide brauchen weder Karte
/// noch GPS: der Drehwinkel und das Auf-und-ab (`fact_balloon_motion.dart`).
///
/// Je **Ortung** ändert sich, wer nah ist und wie stark
/// (`fact_proximity.dart`).
///
/// Je **Kamerabild** ändert sich, wo die Punkte auf dem Bildschirm liegen.
/// **Steht die Kamera, bleibt jede Bildschirmlage gültig**, und dann läuft nur
/// noch die Drehung, eine reine Transformation an Ort und Stelle. Bewegt sie
/// sich, geht **eine** Projektion je Kamerameldung heraus, und **nie zwei
/// gleichzeitig**: die nächste erst nach der Antwort, siehe
/// [_requestProjection]. Ohne dieses Zusammenfassen baut sich bei 60
/// Meldungen je Sekunde eine Warteschlange auf, die nie leer wird.
///
/// ## Warum der Aufbau je Bild vertretbar ist
///
/// Dieses Widget baut sich mit jedem Bild neu auf, solange etwas nah ist. Das
/// widerspricht der Entscheidung von Janek nicht, denn die galt 600 Punkten:
/// hier sind es die, die innerhalb von 150 Metern liegen **und** nicht
/// gruppiert sind, in einer dichten Altstadt eine Handvoll. Ein
/// [RepaintBoundary] je Ballon hält das Neuzeichnen bei dieser Handvoll.
/// Steht nichts in Reichweite, läuft der Taktgeber gar nicht, siehe
/// [_syncTicker]: ein Ticker ohne Arbeit fordert trotzdem jedes Bild an und
/// kostet Akku.
///
/// ## Was bewusst fehlt
///
/// Das goldene Aussehen (es gibt weder Auslöser noch Bild) und das
/// automatische Einsammeln bei 18 Metern.
///
/// **Das Antippen ist seit Schritt 20 da**, siehe [FactBalloonOverlay.onBalloonTap].
/// Der Kommentar hier nannte dafür bis dahin Schritt 21, und das war falsch:
/// Schritt 21 hat die Fakt-Akte gebaut und ausdrücklich **ohne** Einstieg,
/// mit dem Vermerk „Öffnen darf sie erst Schritt 20". Ein naher Ballon ist
/// genau der Fall, in dem gesammelt wird, er gehört also hierher und nicht
/// dorthin.
///
/// **Der Tutorial-Anker `balloon` stand bis zum 31.08.2026 auch hier**, mit dem
/// Vermerk, er zeige auf den Marker nächst der **Rahmenmitte** und nicht nächst
/// dem Nutzer und müsse auch ohne Ortung existieren. Genau deshalb ist er
/// **nicht** hier gelandet, sondern in `discovery_balloon_anchor.dart`: diese
/// Datei kennt nur, was innerhalb von 150 Metern liegt, der Anker braucht aber
/// auch die fernen Punkte und einen Rückfall ohne jeden Ballon.
///
/// **Der atmende Bodenschatten ist zur Hälfte gebaut, und die Trennlinie ist
/// belegt.** `coinShadowNear` gehört zum Hüpfen: `screen-map.jsx:2300-2303`
/// schaltet es zusammen mit `coinFloatNear` ein, `:2304-2308` beide zusammen
/// wieder aus, beide 2,2 Sekunden. Das ist gebaut, siehe
/// [factBalloonFloatProgress].
///
/// **Der statische `coinShadowFar` bleibt weg**, denn der ist eine vergessene
/// Rückstellung. `screen-map.jsx:1866` setzt ihn fest, und der RAF schaltet ihn
/// nur ab, wenn vorher `nearAnim` gesetzt war (`:2316-2320`). Jeder Ballon, der
/// **nie** in Reichweite war, atmet dort dauerhaft; jeder, der einmal nah war
/// und wieder weg ist, atmet danach **nie wieder**. Zwei Ballons nebeneinander
/// verhalten sich verschieden, je nachdem, wo der Nutzer einmal stand.
library;

import 'dart:async';

import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_motion.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Überlagerung der lebenden Ballons.
///
/// Sie deckt genau die Fläche der Karte ab und muss deshalb **im selben
/// `Stack` wie die Kartenfläche** liegen: die Bildschirmlagen, die das SDK
/// liefert, sind „relative to the top left of the map (not of the whole
/// screen)" (`maplibre_gl 0.26.2`, `controller.dart:1779`). Ein Rahmen
/// dazwischen verschöbe jeden Ballon um dessen Höhe.
class FactBalloonOverlay extends ConsumerStatefulWidget {
  /// Erzeugt die Überlagerung.
  const FactBalloonOverlay({this.onBalloonTap, super.key});

  /// Was ein Tipp auf einen lebenden Ballon auslöst.
  ///
  /// ## Warum dieser Weg überhaupt gebraucht wird
  ///
  /// **Ein naher Ballon liegt nicht mehr nativ.** `map_page.dart` nimmt ihn
  /// mit `factOverlayWithout` aus der Punktliste, solange er lebt, damit er
  /// nicht doppelt dasteht. Damit meldet `MapHost.pointTaps` ihn auch nicht:
  /// im SDK gibt es kein Merkmal mehr, das man treffen könnte. Genau die
  /// Fakten innerhalb von 150 Metern sind aber die, bei denen gesammelt wird.
  /// Ohne diesen Rückruf wäre der Sammelweg im **Normalfall** unerreichbar,
  /// und erreichbar nur unterhalb der Gruppierungsgrenze, wo die Ballons
  /// nativ bleiben (siehe `factAnimationRunsAt`).
  ///
  /// ## `null` heißt: diese Fläche verschluckt nichts
  ///
  /// Ohne Rückruf liegt die ganze Überlagerung wie bisher in einem
  /// [IgnorePointer], jede Geste gehört der Karte. Mit Rückruf wird **nur**
  /// die Fläche jedes einzelnen Ballons berührbar, nicht der Stapel: ein
  /// [Stack] ohne getroffenes Kind nimmt an dieser Stelle nichts an, ein
  /// Schwenk zwischen zwei Ballons erreicht also weiter die Karte.
  final void Function(FactProximityPoint point)? onBalloonTap;

  @override
  ConsumerState<FactBalloonOverlay> createState() => _FactBalloonOverlayState();
}

class _FactBalloonOverlayState extends ConsumerState<FactBalloonOverlay>
    with SingleTickerProviderStateMixin {
  /// Der Taktgeber der Drehung und des Auf-und-ab.
  ///
  /// **Ein `Ticker` und kein `Timer`**, und das erledigt zwei Dinge nebenbei:
  /// er hängt an den Bildern der Anzeige statt an einer Wanduhr, und
  /// `TickerMode` stellt ihn im unsichtbaren Tab-Zweig von selbst ab. Genau
  /// diese Verpackung legt `go_router 18.0.0` um jeden Zweig seiner Shell
  /// (`route.dart:1630-1634`).
  late final Ticker _ticker;

  /// Der Winkelzähler, der einen Neuaufbau überlebt.
  final FactBalloonSpin _spin = FactBalloonSpin();

  StreamSubscription<MapCameraView>? _cameraSubscription;

  /// Die Zoomstufe der Karte, oder `null`, solange keine Karte lebt.
  double? _zoom;

  /// Wie lange der Taktgeber schon läuft, für das Auf-und-ab.
  Duration _elapsed = Duration.zero;

  /// Der Stand des Taktgebers beim vorigen Bild.
  Duration _lastTick = Duration.zero;

  /// Wo die lebenden Ballons auf dem Bildschirm liegen.
  ///
  /// Ein fehlender Eintrag heißt „gerade nicht zeichenbar" und ist kein
  /// Fehler. Zwei Gründe führen dazu, und der Vertrag hält sie auseinander:
  /// die Projektion liefert für diesen Punkt gar keine Lage (`null`), oder sie
  /// liefert eine, die hinter der Kamera liegt
  /// (`MapScreenPoint.isInFrontOfCamera` ist `false`). Der zweite Fall ist bei
  /// 58 Grad Neigung der Normalfall für alles jenseits des Horizonts, und
  /// seine Zahlen sehen gültig aus: er ist eine Spiegelung, siehe dort.
  Map<String, MapScreenPoint> _screen = const <String, MapScreenPoint>{};

  /// Wer gerade lebend gezeichnet wird.
  ///
  /// **Ein Zwischenspeicher und kein Provider-Zugriff je Bild**, und der Grund
  /// ist gemessen: der Bildrückruf läuft weiter, während der Testrahmen
  /// seinen `ProviderContainer` schon entsorgt hat, und ein `ref.read` bricht
  /// dann mit „Tried to read a provider from a ProviderContainer that was
  /// already disposed" ab. Auf dem Gerät ist dasselbe der Wechsel des
  /// Bildschirms. Aktualisiert wird er an denselben zwei Stellen wie der
  /// Taktgeber, siehe [_syncTicker].
  List<FactProximityPoint> _animated = const <FactProximityPoint>[];

  bool _projectionInFlight = false;
  bool _projectionPending = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // Vor der Kartenfläche im Baum, genau wie beim Kartenbildschirm: dessen
    // `initState` läuft früher als das der Fläche, und `bindSurface` noch
    // später. Ein Abonnement, das erst danach entstünde, verpasste die erste
    // Kamerameldung und damit die einzige, die „die Karte lebt" bedeutet.
    _cameraSubscription = ref
        .read(mapHostProvider)
        .cameraChanges
        .listen(_onCameraChange);
  }

  @override
  void dispose() {
    unawaited(_cameraSubscription?.cancel());
    _cameraSubscription = null;
    _ticker.dispose();
    super.dispose();
  }

  /// Die Karte hat sich bewegt.
  ///
  /// Zwei Dinge hängen daran: die Bildschirmlagen sind veraltet, und die
  /// Zoomstufe entscheidet über Größe und darüber, ob überhaupt gezeichnet
  /// wird. Neu gebaut wird nur bei einer echten Zoomänderung; ein Schwenk
  /// erreicht die Oberfläche über die neue Projektion.
  void _onCameraChange(MapCameraView view) {
    if (_zoom != view.zoom) {
      setState(() => _zoom = view.zoom);
      // Vor der Projektion, weil sie den Zwischenspeicher liest: eine neue
      // Zoomstufe kann die Liste von leer auf besetzt kippen.
      _syncTicker();
    }
    _requestProjection();
  }

  /// Ein Bild ist vergangen.
  ///
  /// Der Winkel wächst um das, was seit dem letzten Bild wirklich vergangen
  /// ist, und nicht um einen festen Betrag: „Grad je Bild" ist der Fehler der
  /// Quelle, siehe `fact_balloon_motion.dart`.
  void _onTick(Duration elapsed) {
    final Duration delta = elapsed - _lastTick;
    _lastTick = elapsed;
    setState(() {
      _elapsed = elapsed;
      _spin.advance(_animated, delta);
    });
  }

  /// Wer gerade lebend gezeichnet wird.
  ///
  /// Zwei Bedingungen, und die zweite ist die Parität: ohne Karte gibt es
  /// keine Zoomstufe, und unterhalb der Gruppierungsgrenze animiert auch die
  /// Quelle nicht, siehe [factAnimationRunsAt].
  List<FactProximityPoint> _pointsToDraw(FactProximity proximity) {
    final double? zoom = _zoom;
    if (zoom == null || !factAnimationRunsAt(zoom)) {
      return const <FactProximityPoint>[];
    }
    return proximity.points;
  }

  /// Fragt die Bildschirmlagen aller lebenden Ballons an, **eine Anfrage auf
  /// einmal**.
  ///
  /// Läuft schon eine, wird nur gemerkt, dass danach noch eine fällig ist;
  /// mehrere gemerkte Anfragen sind eine. Der Grund steht im Kopf dieser
  /// Datei: bei 60 Kamerameldungen je Sekunde und einem Umlauf über den
  /// Plattformkanal je Meldung liefe die Warteschlange voll, und die Ballons
  /// zeigten immer weiter zurückliegende Stellungen.
  ///
  /// **Freigegeben wird in `whenComplete` und nicht in `then`, und der
  /// Unterschied ist der Ausfall des ganzen Bauteils.** Stünde die Freigabe im
  /// Erfolgszweig, bliebe [_projectionInFlight] nach einer **einzigen**
  /// gescheiterten Projektion dauerhaft `true`, und danach ginge nie wieder
  /// eine hinaus: die Ballons klebten an ihren alten Bildschirmstellen,
  /// während sich die Karte darunter bewegt. `MapHost.projectToScreen` sagt
  /// zwar zu, nicht zu werfen, aber eine Zusage ist kein `catchError`, und der
  /// Weg dorthin führt über einen Plattformkanal.
  void _requestProjection() {
    if (_projectionInFlight) {
      _projectionPending = true;
      return;
    }
    final List<FactProximityPoint> points = _animated;
    if (points.isEmpty) {
      if (_screen.isNotEmpty) {
        setState(() => _screen = const <String, MapScreenPoint>{});
      }
      return;
    }

    _projectionInFlight = true;
    final MapHost host = ref.read(mapHostProvider);
    reportDetached(
      host
          .projectToScreen(<MapPosition>[
            for (final FactProximityPoint point in points) point.position,
          ])
          .then((List<MapScreenPoint?> located) {
            if (!mounted) {
              return;
            }
            final Map<String, MapScreenPoint> screen =
                <String, MapScreenPoint>{};
            for (int i = 0; i < points.length && i < located.length; i++) {
              final MapScreenPoint? at = located[i];
              // **Ein gespiegelter Punkt bekommt keinen Eintrag**, und damit
              // keinen Ballon: seine Lage sieht gültig aus und liegt
              // geometrisch nirgends, siehe [_screen]. Bis zum 31.08.2026
              // stand hier nur die `null`-Prüfung und der Rest als Prosa.
              if (at != null && at.isInFrontOfCamera) {
                screen[points[i].id] = at;
              }
            }
            setState(() => _screen = screen);
          })
          .whenComplete(() {
            _projectionInFlight = false;
            if (!mounted) {
              return;
            }
            // Auch nach einem Fehlschlag: die gemerkte Kamerameldung ist
            // weiterhin unbeantwortet, und sie zu verwerfen hieße, den
            // Stillstand um eine Runde zu verlängern.
            if (_projectionPending) {
              _projectionPending = false;
              _requestProjection();
            }
          }),
      origin: 'discovery.fact_balloons.projection',
    );
  }

  /// Startet den Taktgeber, wenn es etwas zu bewegen gibt, und stellt ihn
  /// sonst ab.
  ///
  /// **Ein laufender Ticker fordert jedes Bild an**, auch wenn er nichts tut.
  /// Ohne dieses Abstellen liefe die Anzeige dauerhaft auf 60 Bildern je
  /// Sekunde, obwohl kein Fakt in der Nähe ist, und das kostet Akku, den
  /// niemand sieht.
  ///
  /// Beim Abstellen fallen die Winkel weg. Das ist dieselbe Rückstellung wie
  /// beim Verlassen der Reichweite (`screen-map.jsx:2312`); dass sie hier auch
  /// beim Herauszoomen greift, ist eine Ergänzung ohne Vorbild in der Quelle,
  /// die keine Zoomgrenze für ihre Animation kennt.
  ///
  /// **Ausdrücklich nicht aus `build` gerufen, und das ist gemessen.**
  /// `Ticker.start` legt über `SchedulerBinding.scheduleFrameCallback` einen
  /// Bildrückruf an, und das bricht während der Aufbauphase mit einer
  /// Zusicherung ab. Gerufen wird deshalb an den zwei Stellen, an denen sich
  /// die Antwort überhaupt ändern kann: bei einer neuen Zoomstufe und bei
  /// einer neuen Nachbarschaft. Beide laufen außerhalb des Bildaufbaus.
  void _syncTicker() {
    final List<FactProximityPoint> points = _pointsToDraw(
      ref.read(factProximityProvider),
    );
    _animated = points;
    if (points.isNotEmpty) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        // `start()` gibt eine `TickerFuture` zurück, die erst beim Anhalten
        // erfüllt wird. Hier gibt es nichts abzuwarten, und `reportDetached`
        // wäre falsch: ein angehaltener Ticker ist kein Fehler.
        unawaited(_ticker.start());
      }
      return;
    }
    if (_ticker.isActive) {
      _ticker.stop();
      _spin.advance(const <FactProximityPoint>[], Duration.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    // **Zuhören und nicht nur beobachten:** ändert sich, wer in Reichweite
    // ist, braucht der Neue sofort eine Bildschirmlage. Ohne das erschiene er
    // erst bei der nächsten Kamerabewegung, also unter Umständen gar nicht.
    ref.listen(factProximityProvider, (
      FactProximity? previous,
      FactProximity next,
    ) {
      // **Erst der Taktgeber, dann die Projektion**, und die Reihenfolge ist
      // tragend: `_syncTicker` schreibt den Zwischenspeicher, aus dem die
      // Projektion ihre Punkte nimmt. Andersherum fragte sie mit der alten
      // Liste, und ein neu in Reichweite gekommener Ballon bekäme seine
      // Bildschirmlage erst bei der nächsten Kamerabewegung, also für einen
      // stehenden Nutzer nie.
      _syncTicker();
      _requestProjection();
    });

    final FactProximity proximity = ref.watch(factProximityProvider);
    final List<FactProximityPoint> points = _pointsToDraw(proximity);

    final double? zoom = _zoom;
    if (points.isEmpty || zoom == null) {
      return const SizedBox.shrink();
    }

    final double scale = factBalloonZoomScale(zoom);
    final String? nearestId = proximity.nearest?.id;
    // Die Projektion liefert Gerätepixel, `Positioned` rechnet in logischen.
    // Begründung und Messung stehen an [_balloonAt].
    final double pixelRatio = MediaQuery.devicePixelRatioOf(context);

    final Widget stack = Stack(
      // **`expand` und nicht der Standard.** Ein `Stack`, dessen Kinder alle
      // gesetzt sind, nimmt sonst die **kleinste** erlaubte Größe an, und er
      // beschneidet hart: unter losen Zwängen wäre die Fläche null mal null
      // und jeder Ballon weggeschnitten. Heute bekommt sie feste Zwänge vom
      // Stapel des Kartenbildschirms; diese Zeile hält die Aussage auch
      // dann, wenn sie einmal woanders hängt.
      fit: StackFit.expand,
      children: <Widget>[
        // Rückwärts, damit der nächste Ballon zuletzt gezeichnet wird und
        // damit obenauf liegt: `FactProximity.points` ist aufsteigend nach
        // Entfernung sortiert.
        for (final FactProximityPoint point in points.reversed)
          if (_screen[point.id] case final MapScreenPoint at)
            _balloonAt(
              point,
              at,
              scale,
              isNearest: point.id == nearestId,
              pixelRatio: pixelRatio,
            ),
      ],
    );
    if (widget.onBalloonTap == null) {
      // **Kein Empfänger für Berührungen**, siehe [onBalloonTap]: dann darf
      // diese Fläche keine Geste verschlucken, die der Karte gehört.
      return IgnorePointer(child: stack);
    }
    return stack;
  }

  /// Setzt einen Ballon an seine Bildschirmlage.
  ///
  /// **Die Unterkante sitzt auf dem Punkt**, mittig. Das ist dieselbe
  /// Verankerung wie `icon-anchor: bottom` im Symbol-Layer und wie
  /// `new mapboxgl.Marker({ anchor: 'bottom' })` in `screen-map.jsx:2187`;
  /// wäre sie hier eine andere, sprängen die Ballons an der
  /// 150-Meter-Grenze.
  ///
  /// **Und das sind die einzigen zwei Zeilen, die eine Bildschirmlage des SDK
  /// benutzen.** Das ist Absicht: `controller.dart:1779` sagt „screen pixels
  /// (not display pixels)", und dieser Satz kann beides heißen.
  ///
  /// **Am 30.08.2026 am Gerät gemessen: es ist das Geräteraster**, deshalb
  /// steht die Division hier. **Seit `discovery_balloon_anchor.dart` gibt es
  /// eine zweite, benannte und begründete Stelle**: der `balloon`-Anker der
  /// Tutorial-Führung nimmt denselben rohen Kartenpunkt entgegen und kann ihn
  /// nicht über diesen Zeichner beziehen, ohne Regel 18 zu verletzen. Zwei
  /// Stellen sind eine bewusste Entscheidung und keine stille Verdopplung,
  /// siehe die Begründung dort. Belegt ist die Umrechnung selbst nicht
  /// über einen Bildvergleich, sondern über die projizierte **Kameramitte**:
  /// sie kommt auf (540,75 | 1200,94) heraus, bei einer Kartenfläche von
  /// 1080 × 2400 Gerätepixeln und einem Skalierungsfaktor von 2,625. Die Mitte
  /// der Fläche liegt bei (540 | 1200). Damit sind Maßstab und Ursprung in
  /// einem Messsatz geklärt: der Faktor ist [MediaQuery.devicePixelRatioOf],
  /// einen Versatz gibt es nicht, und die Lage bezieht sich auf die
  /// Kartenfläche und nicht auf das Fenster. Zahlen in `REBUILD_STATUS.md`
  /// unter „Ungefragter Fund A".
  ///
  /// **Ohne die Division stand jeder Ballon um den Faktor 2,625 zu weit von
  /// der linken oberen Ecke entfernt**, also umso weiter daneben, je weiter er
  /// von dieser Ecke weg war. In der Bildmitte waren das rund 250 logische
  /// Pixel.
  Widget _balloonAt(
    FactProximityPoint point,
    MapScreenPoint at,
    double scale, {
    required bool isNearest,
    required double pixelRatio,
  }) {
    final void Function(FactProximityPoint)? onBalloonTap = widget.onBalloonTap;
    final FactBalloonMetrics metrics = FactBalloonMetrics(
      emphasis: point.emphasis,
    );
    final Size size = metrics.size * scale;
    return Positioned(
      key: ValueKey<String>(point.id),
      left: at.xInScreenPixels / pixelRatio - size.width / 2,
      top: at.yInScreenPixels / pixelRatio - size.height,
      width: size.width,
      height: size.height,
      // **`HitTestBehavior.opaque`, und ohne sie ginge fast nichts.** Ein
      // `CustomPaint` hat kein eigenes Trefferverhalten: es zeichnet, ohne
      // sich für Berührungen zuständig zu erklären. Ein `GestureDetector`
      // ohne diesen Wert reagierte deshalb nirgends. Dieselbe Lehre wie bei
      // der Jagd-Pille, dort ohne Zeichenfläche und nur neben dem Text.
      //
      // Die berührbare Fläche ist das Rechteck des Ballons, nicht seine
      // gemalte Form. Das ist gröber als die Quelle (dort ist es der
      // DOM-Knoten mit `border-radius`), und die Richtung ist die richtige:
      // ein Tipp knapp neben dem Kopf sammelt, statt die Karte zu
      // verschieben. Zu klein wäre schlimmer, denn dann wüsste der Nutzer
      // nicht, warum sein Tipp nichts tut.
      child: GestureDetector(
        onTap: onBalloonTap == null ? null : () => onBalloonTap(point),
        behavior: onBalloonTap == null
            ? HitTestBehavior.deferToChild
            : HitTestBehavior.opaque,
        child: RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: FactBalloonPainter(
              style: point.style,
              metrics: metrics,
              scale: scale,
              spinDegrees: _spin.angleOf(point.id),
              // **Nur der nächste hüpft**, siehe `FactProximity.nearest`.
              floatProgress: isNearest ? factBalloonFloatProgress(_elapsed) : 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeichnet einen lebenden Ballon.
///
/// Er malt nichts selbst: [paintFactBalloon] ist derselbe Pinsel, mit dem die
/// Bildfabrik ihre PNG zeichnet. Hier kommt nur die Zoom-Skalierung dazu, und
/// die muss sein: nativ wendet MapLibre `overlayPointSizeExpression` auf jedes
/// Symbol an, und ein gezeichneter Ballon, der das nicht täte, spränge beim
/// Überqueren der 150-Meter-Grenze. Auf Zoom 16 steht der Faktor bei 0,833 und
/// nicht bei 1.
@immutable
class FactBalloonPainter extends CustomPainter {
  /// Erzeugt den Zeichner.
  const FactBalloonPainter({
    required this.style,
    required this.metrics,
    required this.scale,
    required this.spinDegrees,
    required this.floatProgress,
  });

  /// Farbe und Zeichen der Kategorie.
  final FactCategoryStyle style;

  /// Die Maße bei der aktuellen Betonung.
  final FactBalloonMetrics metrics;

  /// Die Zoom-Skalierung, siehe [factBalloonZoomScale].
  final double scale;

  /// Der aufgelaufene Drehwinkel in Grad.
  final double spinDegrees;

  /// Der Stand des Hüpfens, 0 am Boden und 1 im Scheitel.
  ///
  /// **Eine Zahl für zwei Wirkungen**, siehe [paintFactBalloon]: der Kopf
  /// steigt, und der Bodenschatten schrumpft und verblasst mit ihm.
  final double floatProgress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(scale);
    paintFactBalloon(
      canvas,
      style,
      metrics: metrics,
      spinDegrees: spinDegrees,
      floatProgress: floatProgress,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(FactBalloonPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.metrics != metrics ||
      oldDelegate.scale != scale ||
      oldDelegate.spinDegrees != spinDegrees ||
      oldDelegate.floatProgress != floatProgress;
}
