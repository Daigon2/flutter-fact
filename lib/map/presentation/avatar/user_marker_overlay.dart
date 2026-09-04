/// Der Nutzermarker: Pulsring und 3D-Figur, geografisch auf der Karte,
/// `02_Frontend/app/screen-map.jsx:655-682` und `:1768-1775`.
///
/// Schritt 18. **Vor diesem Schritt zeigte die Karte den eigenen Standort
/// überhaupt nicht** — nachgesehen und nicht vermutet: es gab kein
/// `myLocationEnabled`, und `DiscoveryAnchors.userMarker` hatte seit dem
/// Tutorial einen Anker ohne Gegenstand. Der Avatar ist also nicht der Ersatz
/// für eine 2D-Figur, er ist der erste.
///
/// ## Geografisch und nicht in der Bildmitte
///
/// Die Quelle hängt den Marker als `mapboxgl.Marker` an eine Koordinate
/// (`:1772`, mit dem Kommentar „moves with map pan like all other markers").
/// Das ist der Unterschied, den man sofort sieht: schiebt man die Karte weg,
/// bleibt die Figur an ihrem Ort stehen, statt in der Mitte zu kleben.
///
/// Umgesetzt wie bei den Ballons in Reichweite: eine Projektion je
/// Kamerameldung, **nie zwei gleichzeitig**, und die Antwort setzt die
/// Bildschirmlage. Die Begründung für dieses Zusammenfassen steht im Kopf von
/// `fact_balloon_overlay.dart`.
///
/// ## Warum das eine zweite Projektionsanfrage ist und keine gemeinsame
///
/// Naheliegend wäre, die eigene Koordinate in denselben Stapel zu legen, den
/// die Ballons ohnehin schicken: ein Kanalumlauf statt zwei. Dagegen steht,
/// dass die beiden **verschieden lange leben**. Die Ballons projizieren nur,
/// solange etwas innerhalb von 150 Metern liegt; der Avatar muss stehen,
/// sobald es eine Ortung gibt. Zusammengelegt hinge die Figur daran, ob
/// gerade ein Fakt in der Nähe ist, und stünde in einer leeren Gegend still.
///
/// Der Preis ist ein Stapelaufruf über **einen** Punkt je Kamerameldung. Die
/// Warnung im Kopf der Ballons galt 600 Punkten und einer Warteschlange, die
/// nie leer wird; hier greift dieselbe Sperre gegen die Warteschlange, und die
/// Nutzlast ist ein Punkt.
///
/// ## Der Pulsring liegt in Flutter und nicht im WebView
///
/// Die Vorlage des eingefrorenen Ports hat ihn als CSS-Keyframe **im**
/// WebView. Hier zeichnet ihn Flutter, und der Grund ist nicht Geschmack: eine
/// CSS-Animation kann `MediaQuery.disableAnimations` nicht lesen. Wer im
/// Betriebssystem „Bewegung reduzieren" einschaltet, bekommt von Flutter eine
/// Antwort und von einer Keyframe-Regel keine. Nebenbei kostet ein WebView von
/// 72 mal 100 Punkten weniger als einer von 118 mal 118.
///
/// ## Was fehlt, und zwar mit Grund
///
/// **Die Entfernungspille über der Figur** (`:658-669`). Sie zeigt die
/// Entfernung zum **nächsten Fakt** und sonst drei Punkte (`:2974`). Zwei
/// Dinge fehlen dafür: ein Provider „welcher Fakt ist der nächste" (heute
/// rechnen das der Audio-Beacon und das Selbstsammeln jeder für sich) und eine
/// Formatierung für Entfernungen, die es im Neubau noch nicht gibt. Das zweite
/// ist eine Entscheidung über Einheiten und Wortlaut und keine Zeile Code.
/// Beides gehört zusammen und in einen eigenen Schritt.
///
/// **Die Einflug-Animation** (`touristDropIn`, im Wirt der Vorlage). Sie
/// gehört zum ersten GPS-Empfang, also zu demselben Moment, den `skyFall` auf
/// der Kameraseite behandelt. Wer sie baut, baut sie mit jener zusammen, sonst
/// fliegt die Figur ein, während die Kamera noch woanders steht.
/// ## Warum die Datei in `map/presentation/` liegt und nicht im Feature
///
/// Der erste Entwurf lag in `features/discovery/presentation/`, und der
/// Architektur-Check hat ihn abgelehnt: **Regel 18** lässt einem Feature vom
/// Karten-Host nur `map/domain/` sehen. Der Marker braucht aber die Figur, und
/// die liegt wegen Regel 19 in `map/presentation/avatar/`.
///
/// Also liegt er dort, und die **Nutzerposition kommt von außen herein**. Das
/// ist keine neue Bauform, sondern die, die `app_routes.dart` schon zweimal
/// benutzt: `mapSurface` wird dem Kartenbildschirm hereingereicht, und
/// `HuntPill` bekommt seine `userPosition` auf demselben Weg, weil
/// `challenges` das `presentation` von `discovery` nicht sehen darf. Regel 10
/// nennt das ausdrücklich „an app-level composition adapter".
///
/// Der Gewinn ist nicht nur formal: dieses Widget kennt weder einen Provider
/// für den Standort noch ein Feature. Es bekommt eine Koordinate und zeichnet
/// eine Figur.
library;

import 'dart:async';

import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_camera.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/map/presentation/avatar/avatar_look.dart';
import 'package:fact_app/map/presentation/avatar/avatar_motion.dart';
import 'package:fact_app/map/presentation/avatar/avatar_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Zeichnet den eigenen Standort als Figur mit Pulsring.
class UserMarkerOverlay extends ConsumerStatefulWidget {
  /// Erzeugt die Überlagerung für [position].
  ///
  /// [position] ist `null`, solange es keine Ortung gibt. Dann zeichnet das
  /// Widget nichts, genau wie die Quelle den Marker bis zum ersten echten
  /// GPS-Wert auf `display: none` hält.
  const UserMarkerOverlay({this.position, super.key});

  /// Die Kennung des Markers, für Tests.
  static const Key markerKey = Key('user-marker');

  /// Die Kennung des Pulsrings, für Tests.
  static const Key pulseKey = Key('user-marker-pulse');

  /// Die eigene Koordinate, `null` ohne Ortung.
  final MapPosition? position;

  @override
  ConsumerState<UserMarkerOverlay> createState() => _UserMarkerOverlayState();
}

class _UserMarkerOverlayState extends ConsumerState<UserMarkerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  StreamSubscription<MapCameraView>? _cameraSubscription;

  /// Wo die Figur auf dem Bildschirm steht, `null` vor der ersten Projektion.
  MapScreenPoint? _screen;

  /// Die Ortung, gegen die die nächste gemessen wird.
  MapPosition? _previous;

  /// Bis wann die Figur läuft.
  DateTime? _walkUntil;

  /// Der Zeitgeber, der nach Ablauf des Laufens einen Bildaufbau anfordert.
  Timer? _walkTimer;

  bool _projectionInFlight = false;
  bool _projectionPending = false;

  @override
  void initState() {
    super.initState();
    // **Läuft nicht von Anfang an**, siehe [_syncPulse]. Ohne Ortung gibt es
    // keinen Marker, und ein Ring, den niemand sieht, fordert trotzdem jedes
    // Bild an.
    _pulse = AnimationController(vsync: this, duration: avatarPulseDuration);
    // Vor der Kartenfläche im Baum, dieselbe Begründung wie bei den Ballons:
    // ein Abonnement, das später entstünde, verpasste die erste
    // Kamerameldung.
    _cameraSubscription = ref
        .read(mapHostProvider)
        .cameraChanges
        .listen((MapCameraView _) => _requestProjection());
    final MapPosition? position = widget.position;
    if (position != null) {
      _onFix(position);
    }
  }

  @override
  void didUpdateWidget(UserMarkerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final MapPosition? position = widget.position;
    // **Der Vergleich mit `oldWidget` und nicht mit `_previous`.** `_previous`
    // ist die Ortung, gegen die gemessen wird, und die wird von [_onFix]
    // selbst gesetzt; sie hier zu lesen hieße, jede Ortung zweimal zu zählen.
    if (position != null && position != oldWidget.position) {
      _onFix(position);
    }
  }

  @override
  void dispose() {
    unawaited(_cameraSubscription?.cancel());
    _cameraSubscription = null;
    _walkTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Eine neue Ortung ist eingetroffen.
  ///
  /// Drei Dinge hängen daran, und sie sind absichtlich getrennt: die Strecke
  /// entscheidet über das Laufen (`avatar_motion.dart`), die Koordinate über
  /// die Bildschirmlage, und der Zeitgeber sorgt dafür, dass das Stehenbleiben
  /// auch ohne weitere Ortung sichtbar wird.
  void _onFix(MapPosition current) {
    final DateTime now = DateTime.now();
    final DateTime? walkUntil = avatarWalkUntil(
      current: current,
      now: now,
      previous: _previous,
      walkUntil: _walkUntil,
    );
    _previous = current;

    if (walkUntil != _walkUntil) {
      _walkUntil = walkUntil;
      _armWalkTimer(now);
    }
    _requestProjection();
  }

  /// Stellt den Zeitgeber auf das Ende des Laufens.
  ///
  /// **Nötig, weil das Stehenbleiben kein Ereignis ist.** Läuft die Figur und
  /// kommt keine weitere Ortung, gibt es nichts, was einen Bildaufbau
  /// anstößt; die Figur liefe weiter, obwohl `avatarAnimationAt` längst `idle`
  /// sagt. Der Zeitgeber ist also nicht die Regel, sondern nur der Wecker.
  void _armWalkTimer(DateTime now) {
    _walkTimer?.cancel();
    final DateTime? until = _walkUntil;
    if (until == null) {
      return;
    }
    final Duration remaining = until.difference(now);
    if (remaining <= Duration.zero) {
      return;
    }
    _walkTimer = Timer(remaining, () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// Lässt den Pulsring laufen, solange der Marker sichtbar ist, und stellt
  /// ihn sonst ab.
  ///
  /// ## Das ist kein Sparen, sondern eine behobene Blockade
  ///
  /// Ein `AnimationController.repeat()` wird **nie fertig**, und
  /// `pumpAndSettle` wartet darauf, dass nichts mehr aussteht. Ein Ring, der
  /// immer läuft, lässt damit **jeden** Test hängen, der die App aufbaut, und
  /// nicht nur die dieses Widgets: gemessen am 04.09.2026 waren es 88
  /// Fehlschläge in der ganzen Suite, alle mit „pumpAndSettle timed out" und
  /// keiner mit einem Hinweis auf den Avatar.
  ///
  /// Dieselbe Sperre und derselbe Grund wie bei `_syncTicker` in
  /// `fact_balloon_overlay.dart`, dort für den Akku: ein laufender Taktgeber
  /// fordert jedes Bild an, auch wenn er nichts tut.
  void _syncPulse() {
    final bool shouldRun = _screen != null;
    if (shouldRun == _pulse.isAnimating) {
      return;
    }
    if (shouldRun) {
      // `repeat` gibt ein `TickerFuture` zurück, das nie fertig wird. Kein
      // `reportDetached`: das würde auf etwas warten, das per Bauart nicht
      // eintritt.
      unawaited(_pulse.repeat());
    } else {
      _pulse.stop();
    }
  }

  /// Fragt die Bildschirmlage der eigenen Koordinate ab.
  ///
  /// Dieselbe Sperre wie bei den Ballons: läuft eine Anfrage, wird die nächste
  /// gemerkt und erst nach der Antwort geschickt. Die Freigabe steht in
  /// `whenComplete` und nicht im Erfolgszweig, weil sonst eine **einzige**
  /// gescheiterte Projektion den Marker dauerhaft festkleben ließe.
  void _requestProjection() {
    final MapPosition? position = _previous;
    if (position == null) {
      return;
    }
    if (_projectionInFlight) {
      _projectionPending = true;
      return;
    }
    _projectionInFlight = true;
    final MapHost host = ref.read(mapHostProvider);
    reportDetached(
      host
          .projectToScreen(<MapPosition>[position])
          .then((List<MapScreenPoint?> located) {
            if (!mounted) {
              return;
            }
            final MapScreenPoint? at = located.isEmpty ? null : located.first;
            // **Ein gespiegelter Punkt bekommt keine Figur.** Seine Lage sieht
            // gültig aus und liegt geometrisch nirgends; dieselbe Prüfung wie
            // bei den Ballons.
            setState(() {
              _screen = at != null && at.isInFrontOfCamera ? at : null;
            });
            _syncPulse();
          })
          .whenComplete(() {
            _projectionInFlight = false;
            if (!mounted) {
              return;
            }
            if (_projectionPending) {
              _projectionPending = false;
              _requestProjection();
            }
          }),
      origin: 'discovery.user_marker.projection',
    );
  }

  @override
  Widget build(BuildContext context) {
    final MapScreenPoint? at = _screen;
    if (at == null) {
      // **Nichts, solange es keine Ortung gibt**, genau wie die Quelle: der
      // Marker steht dort auf `display: none`, bis der erste echte GPS-Wert
      // kommt (`:1771`). Eine Figur an einer geratenen Koordinate wäre
      // schlimmer als keine.
      return const SizedBox.shrink();
    }

    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    // Die Lagen des Karten-SDK sind **Geräte-Pixel**, die von Flutter
    // logische. Ohne diese Teilung sitzt die Figur auf einem Telefon mit
    // dreifacher Dichte dreimal zu weit rechts und unten.
    final double left =
        at.xInScreenPixels / devicePixelRatio - avatarMarkerWidth / 2;
    final double top =
        at.yInScreenPixels / devicePixelRatio - avatarMarkerHeight;

    return Positioned(
      left: left,
      top: top,
      width: avatarMarkerWidth,
      height: avatarMarkerHeight,
      child: IgnorePointer(
        child: RepaintBoundary(
          key: UserMarkerOverlay.markerKey,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              _Pulse(controller: _pulse),
              SizedBox(
                width: avatarFigureWidth,
                height: avatarFigureHeight,
                // **Die Animation kommt von hier und nicht aus dem Kind.**
                // Der Taktgeber des Rings feuert sechzigmal je Sekunde, und
                // er erreicht nur den `AnimatedBuilder` im Ring; dieser
                // Aufbau läuft je Ortung. `AvatarView` merkt vom Pulsschlag
                // also nichts.
                child: ref.watch(avatarFigureBuilderProvider)(
                  avatarAnimationAt(_walkUntil, DateTime.now()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Der Pulsring unter der Figur (`screen-map.jsx:670-677`).
class _Pulse extends StatelessWidget {
  const _Pulse({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    // **Steht die Bewegung im Betriebssystem auf „reduziert", pulst nichts.**
    // Der Ring ist Zierrat; wer ihn abgeschaltet hat, bekommt den Standort
    // trotzdem, nur ohne die wandernde Welle. Genau das kann die CSS-Fassung
    // der Vorlage nicht.
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: avatarPulseBottomOffset,
      width: avatarPulseDiameter,
      height: avatarPulseDiameter,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          final double t = controller.value;
          return Opacity(
            // `ease-out` der Quelle, hier als Kurve auf denselben Verlauf.
            opacity: _lerp(
              avatarPulseOpacityFrom,
              avatarPulseOpacityTo,
              Curves.easeOut.transform(t),
            ),
            child: Transform.scale(
              scale: _lerp(
                avatarPulseScaleFrom,
                avatarPulseScaleTo,
                Curves.easeOut.transform(t),
              ),
              child: child,
            ),
          );
        },
        child: const DecoratedBox(
          key: UserMarkerOverlay.pulseKey,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: avatarPulseColors,
              stops: avatarPulseStops,
            ),
          ),
        ),
      ),
    );
  }

  static double _lerp(double from, double to, double t) =>
      from + (to - from) * t;
}
