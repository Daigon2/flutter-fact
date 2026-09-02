/// Das Sammel-Erlebnis: was ein Tipp auf einen einzelnen Fakt-Ballon auslöst.
/// Schritt 20.
///
/// ## Der Ablauf, `screen-map.jsx:2110-2145` und `:3056-3078`
///
/// 1. Ein Tipp kommt an, entweder auf einen lebenden Ballon
///    ([FactBalloonOverlay]) oder über `MapHost.pointTaps` auf einen nativen
///    Punkt.
/// 2. [decideFactTap] entscheidet: innerhalb des Radius sammeln, sonst nur die
///    Vorschau. **Ohne Ortung immer die Vorschau.**
/// 3. Beim Sammeln: die Vorschau verschwindet, der Sammel-Rückruf feuert
///    **sofort**, die Bildschirmlage des Ballons wird geholt, die Münzen
///    fliegen, und nach 1400 Millisekunden ist die Animation weg und das
///    Fakt-Blatt offen.
///
/// ## Warum dieses Widget die Ballon-Überlagerung enthält
///
/// Weil beide Wege hier zusammenlaufen müssen. **Ein Fakt innerhalb von 150
/// Metern liegt nicht nativ**: `map_page.dart` nimmt ihn mit
/// `factOverlayWithout` aus der Punktliste, damit er nicht doppelt dasteht.
/// Damit meldet `MapHost.pointTaps` ihn nicht, es gibt im SDK kein Merkmal
/// mehr, das man treffen könnte. Genau diese Fakten sind aber die, bei denen
/// gesammelt wird. Ein Sammel-Erlebnis, das nur an `pointTaps` hängt, wäre im
/// Normalfall unerreichbar und funktionierte allein unterhalb der
/// Gruppierungsgrenze; das ist beim Bauen aufgefallen und nicht abgeleitet,
/// siehe `factAnimationRunsAt`.
///
/// Der Tipp auf einen **nahen** Ballon kommt deshalb aus
/// [FactBalloonOverlay.onBalloonTap], der auf einen **fernen** aus dem Strom.
/// Beide gehen durch dieselbe Regel, damit es nicht zwei Wahrheiten gibt.
///
/// ## Was hier bewusst fehlt
///
/// **Die Buchung.** Die Belohnungsregel ist am 02.09.2026 entschieden (je
/// Nutzer und Fakt zwei Anlässe, jeder einmal für immer) und verlangt ein
/// Buchungsjournal, also eine neue Tabelle und damit eine Entscheidung der
/// Stufe 3 (J-C in `REBUILD_STATUS.md`). Gebaut ist das Erlebnis, nicht die
/// Buchung: [FactCollectOverlay.onCollected] feuert an der richtigen Stelle
/// und zur richtigen Zeit, und was daran hängt, entscheidet der Aufrufer. Der
/// fehlende Vertrag ist hier benannt und nicht erfunden.
///
/// **Der Tour-Zweig** (`:2120-2127`), siehe `fact_collect_decision.dart`.
///
/// **Das automatische Öffnen bei 18 Metern** (`:1470-1490`). Das ist ein
/// eigener Auslöser am Ortungsstrom und nicht am Tipp; es gehört nicht in
/// diesen Schritt.
library;

import 'dart:async';

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_balloon_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_collect_burst.dart';
import 'package:fact_app/features/discovery/presentation/fact_collect_decision.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/features/discovery/presentation/fact_teaser_card.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/map/application/map_host_providers.dart';
import 'package:fact_app/map/domain/map_host.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_overlay_tap.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/map/domain/map_screen_point.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wie lange zwischen dem Tipp und dem Fakt-Blatt liegt,
/// `setTimeout(..., 1400)` in `screen-map.jsx:3076`.
///
/// **Länger als der Münzflug selbst** ([factCollectBurstDuration], 1250
/// Millisekunden). Die 150 Millisekunden Rest sind eine ruhige Pause, bevor
/// das Blatt aufgeht, und keine Reserve für die Animation.
const Duration factCollectRevealDelay = Duration(milliseconds: 1400);

/// Das Sammel-Erlebnis, siehe den Bibliothekskopf.
class FactCollectOverlay extends ConsumerStatefulWidget {
  /// Erzeugt die Überlagerung.
  const FactCollectOverlay({
    required this.coinAmount,
    required this.onCollected,
    required this.onOpenFact,
    this.nextDouble,
    super.key,
  });

  /// Die Zahl, die im Münzflug aufsteigt.
  ///
  /// **Erforderlich**, und die Begründung samt der drei gemessenen,
  /// widersprüchlichen Zahlen steht an [FactCollectBurst.coinAmount].
  final int coinAmount;

  /// Feuert, sobald gesammelt wird, **vor** der Animation und vor dem Blatt.
  ///
  /// ## Die Reihenfolge ist die Aussage
  ///
  /// Die Quelle setzt die Animation, ruft `onCollectFact` und legt erst dann
  /// den 1400-Millisekunden-Zeitgeber (`:3068-3077`). Dass die Buchung
  /// **nicht** am Ende der Animation hängt, ist der Punkt: der Nutzer könnte
  /// in dieser Sekunde den Bildschirm wechseln, die App könnte abgeschossen
  /// werden, und ein Sammeln, das erst danach zählte, wäre verloren.
  ///
  /// Was daran hängt, entscheidet der Aufrufer. Heute hängt daran keine
  /// Buchung, siehe den Bibliothekskopf.
  final void Function(String factId) onCollected;

  /// Öffnet das Fakt-Blatt, [factCollectRevealDelay] nach dem Tipp.
  ///
  /// **Ein Rückruf und keine Navigation an dieser Stelle.** Die Route liegt in
  /// `lib/app/routing/app_routes.dart` und trägt dort die Näherungsbedingung
  /// als ausdrückliche Regel; wer sie von hier aus selbst aufriefe, hätte zwei
  /// Stellen, an denen die Bedingung stehen muss. Der Aufrufer navigiert, und
  /// ein Test liest hier ab, **wann** und **womit**.
  final void Function(String factId) onOpenFact;

  /// Die Zufallsquelle der Fluglängen, siehe [FactCollectBurst.nextDouble].
  final double Function()? nextDouble;

  @override
  ConsumerState<FactCollectOverlay> createState() => _FactCollectOverlayState();
}

class _FactCollectOverlayState extends ConsumerState<FactCollectOverlay> {
  StreamSubscription<MapOverlayPointTap>? _pointTapSubscription;

  /// Ob gerade gesammelt wird.
  ///
  /// Die Sperre aus `screen-map.jsx:1474` (`if (collectAnim) return;`): läuft
  /// schon eine Animation, tut ein zweiter Tipp nichts.
  ///
  /// **Ein eigenes Feld und nicht `_burst != null`**, und der Unterschied ist
  /// ein Zeitfenster. `_burst` entsteht erst, wenn die Projektion antwortet,
  /// also einen Umlauf über den Plattformkanal später; in dieser Lücke wäre
  /// die Sperre offen und ein schneller zweiter Tipp käme durch. In der Quelle
  /// gibt es diese Lücke nicht, weil `mapInst.project` dort synchron ist.
  bool _collecting = false;

  /// Der laufende Münzflug, oder `null`.
  _FactBurst? _burst;

  /// Die stehende Vorschau, oder `null`.
  _FactTeaser? _teaser;

  Timer? _revealTimer;

  /// Die zuletzt geladene Überlagerung, oder `null`.
  ///
  /// ## Warum die hier liegt und nicht bei jedem Tipp gelesen wird
  ///
  /// **Gemessen beim ersten Testlauf, und es hat jeden Punkt-Tipp
  /// verschluckt.** `ref.read(factOverlayProvider)` auf einen
  /// [FutureProvider], den sonst niemand hält, gibt **`AsyncLoading`**
  /// zurück: der Abruf startet mit dem Lesen und ist im selben Zug nicht
  /// fertig. Der Empfänger fand damit nie einen Punkt und kehrte still
  /// zurück.
  ///
  /// In der App fiele das nicht auf, weil `map_page.dart` denselben Provider
  /// ohnehin mit `listenManual` hält. Genau darauf zu bauen wäre eine stille
  /// Abhängigkeit von der Reihenfolge zweier Widgets, und dieses hier braucht
  /// die Überlagerung für seine eigene Aufgabe.
  MapOverlay? _latestOverlay;

  /// Die zuletzt angenommene Ortung, oder `null`.
  ///
  /// ## Warum auch die gehalten wird, und nicht beim Tipp gelesen
  ///
  /// **Dieselbe gemessene Falle wie bei [_latestOverlay], nur schlimmer.**
  /// `UserLocationNotifier` klinkt sich erst am Ortungsdienst ein, wenn ihn
  /// jemand liest; ein `ref.read` **im Augenblick des Tipps** legt ihn also
  /// gerade erst an, und `fix` ist dann `null`, obwohl das Gerät längst
  /// Ortungen liefert. Die Regel entschiede damit „ohne Ortung" und zeigte
  /// nur die Vorschau, und zwar dauerhaft: es gäbe **kein** Sammeln, nie.
  ///
  /// In der App fiele es nicht auf, weil `map_page.dart` denselben Provider
  /// mit `ref.listen` hält. Ein Sammel-Erlebnis, das nur funktioniert, solange
  /// ein anderes Widget zufällig zuhört, ist keins.
  ///
  /// **Gehalten und nicht beobachtet**, weil `UserLocationState` bewusst keine
  /// Wertgleichheit hat: ein `watch` baute dieses Widget bei jeder Ortung neu,
  /// also bis zu fünfmal je Sekunde, obwohl sich nichts Sichtbares ändert.
  DevicePosition? _fix;

  @override
  void initState() {
    super.initState();
    // Vor der Kartenfläche im Baum, aus demselben Grund wie in `map_page.dart`
    // und `fact_balloon_overlay.dart`: ein Tipp, der vor diesem Aufruf
    // einträfe, wäre für immer verpasst.
    _pointTapSubscription = ref
        .read(mapHostProvider)
        .pointTaps
        .listen(_onPointTap);

    // **`listenManual` mit `fireImmediately` und nicht `ref.listen` im
    // `build`.** `ref.listen` kennt den Schalter in `flutter_riverpod 3.4.2`
    // nicht und meldet nur Änderungen; ein Widget, das entsteht, während die
    // Fakten längst geladen sind, bekäme also nie eine Ausgabe. Dieselbe
    // Begründung wie in `map_page.dart`, dort ausführlich. `listenManual`
    // räumt sich beim Entsorgen selbst auf.
    ref.listenManual(factOverlayProvider, (
      AsyncValue<MapOverlay>? previous,
      AsyncValue<MapOverlay> next,
    ) {
      _latestOverlay = next.value ?? _latestOverlay;
    }, fireImmediately: true);

    // Die Ortung, aus dem Grund an [_fix]. `fireImmediately`, weil dieses
    // Widget nach einem Tabwechsel neu entstehen kann, während längst eine
    // Ortung vorliegt.
    ref.listenManual(userLocationProvider, (
      UserLocationState? previous,
      UserLocationState next,
    ) {
      _fix = next.fix;
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    unawaited(_pointTapSubscription?.cancel());
    _pointTapSubscription = null;
    _revealTimer?.cancel();
    _revealTimer = null;
    super.dispose();
  }

  /// Ein Tipp auf einen nativen Punkt.
  ///
  /// Verarbeitet wird nur die **eigene** Überlagerung, wie bei den
  /// Gruppen-Tipps in `map_page.dart`: vier Features teilen sich diesen Strom.
  ///
  /// **Die Koordinate des Fakts kommt aus der Überlagerung und nicht aus dem
  /// Tipp.** `MapOverlayPointTap.position` ist die Stelle, auf die der Finger
  /// traf, und das ist bei einem 40 Pixel breiten Ballon nicht dieselbe
  /// Stelle. Eine Entfernungsregel, die mit der Fingerstelle rechnet, ist um
  /// die halbe Ballonbreite falsch.
  void _onPointTap(MapOverlayPointTap tap) {
    if (tap.overlayId != factOverlayId) {
      return;
    }
    final MapOverlay? overlay = _latestOverlay;
    if (overlay == null) {
      return;
    }
    for (final MapOverlayPoint point in overlay.points) {
      if (point.id == tap.pointId) {
        _handleTap(
          factId: point.id,
          factPosition: point.position,
          style: factBalloonCategoryOf(point.styleId),
        );
        return;
      }
    }
    // Eine Kennung, die die eigene Überlagerung nicht kennt. Kein Fehler und
    // keine Meldung: zwischen dem Auflegen der Punkte und dem Tipp kann die
    // Überlagerung gewechselt haben, und ein Tipp auf einen Punkt, den es
    // nicht mehr gibt, ist dann der Normalfall.
  }

  /// Ein Tipp auf einen lebenden Ballon.
  ///
  /// Er ist per Definition in Reichweite, [decideFactTap] wird trotzdem
  /// gefragt: zwei Wege mit zwei Regeln wären zwei Gelegenheiten, sich zu
  /// widersprechen, und die Abweichung sähe aus wie ein Ballon, der manchmal
  /// nicht sammelt.
  void _onBalloonTap(FactProximityPoint point) => _handleTap(
    factId: point.id,
    factPosition: point.position,
    style: point.style,
  );

  /// Die Regel anwenden und verzweigen, `screen-map.jsx:2129-2145`.
  void _handleTap({
    required String factId,
    required MapPosition factPosition,
    required FactCategoryStyle? style,
  }) {
    if (_collecting) {
      return;
    }
    final DevicePosition? fix = _fix;
    final FactTapDecision decision = decideFactTap(
      user: fix == null ? null : mapPositionOf(fix),
      fact: factPosition,
    );
    if (decision.collects) {
      // `setTeaserFactRef.current?.(null)` vor `triggerCollect` (`:2132`):
      // wer sammelt, soll nicht gleichzeitig die Vorschau eines anderen
      // Fakts vor sich haben.
      setState(() => _teaser = null);
      _startCollect(factId: factId, factPosition: factPosition);
      return;
    }
    setState(() {
      _teaser = _FactTeaser(
        factId: factId,
        distanceInMeters: decision.distanceInMeters,
        // `CAT[teaserFact.catKey] || CAT['hist']` (`:3850`): derselbe
        // Rückfall wie in der Quelle, und derselbe wie in `factOverlayOf`.
        style: style ?? factCategoryStylesByKey[fallbackFactCategoryKey]!,
      );
    });
  }

  /// `triggerCollect`, `screen-map.jsx:3057-3078`.
  ///
  /// Drei Dinge passieren **sofort**, und nur eines später:
  ///
  /// 1. Die Sperre geht zu, siehe [_collecting].
  /// 2. [FactCollectOverlay.onCollected] feuert. Die Begründung, warum das
  ///    nicht ans Ende der Animation gehört, steht dort.
  /// 3. Der Zeitgeber läuft, gemessen **ab dem Tipp**. Er wartet nicht auf die
  ///    Projektion: eine Karte, die auf ihre Antwort eine halbe Sekunde
  ///    braucht, soll das Fakt-Blatt nicht um eine halbe Sekunde verschieben.
  ///
  /// Erst danach, und asynchron, kommt die Bildschirmlage. Die Quelle rechnet
  /// sie synchron (`mapInst.project` in einem `try/catch`) und nimmt bei einem
  /// Fehlschlag `0/0` statt abzubrechen (`:3059-3067`). Hier ist es ein Umlauf
  /// über den Plattformkanal, der Rückfall ist derselbe: **eine Animation an
  /// der falschen Stelle ist besser als kein Sammeln**, denn das Fakt-Blatt
  /// hängt an derselben Handlung.
  void _startCollect({
    required String factId,
    required MapPosition factPosition,
  }) {
    _collecting = true;
    widget.onCollected(factId);
    _revealTimer?.cancel();
    _revealTimer = Timer(factCollectRevealDelay, () => _reveal(factId));

    final MapHost host = ref.read(mapHostProvider);
    reportDetached(
      host.projectToScreen(<MapPosition>[factPosition]).then((
        List<MapScreenPoint?> located,
      ) {
        if (!mounted || !_collecting) {
          return;
        }
        final MapScreenPoint? at = located.isEmpty ? null : located.first;
        // Die Projektion liefert Gerätepixel, `Positioned` rechnet in
        // logischen. Begründung und Gerätemessung stehen an
        // `FactBalloonOverlay._balloonAt`.
        final double pixelRatio = MediaQuery.devicePixelRatioOf(context);
        // **Ein gespiegelter Punkt zählt wie keiner.** Seine Zahlen sehen
        // gültig aus und liegen geometrisch nirgends, siehe
        // `MapScreenPoint.isInFrontOfCamera`; die Münzen flögen dann von
        // einer Stelle los, an der nichts steht.
        final Offset origin = at == null || !at.isInFrontOfCamera
            ? Offset.zero
            : Offset(
                at.xInScreenPixels / pixelRatio,
                at.yInScreenPixels / pixelRatio,
              );
        setState(() => _burst = _FactBurst(factId: factId, origin: origin));
      }),
      origin: 'discovery.collect.projection',
    );
  }

  /// Nach [factCollectRevealDelay]: Animation weg, Blatt auf (`:3074-3077`).
  ///
  /// Die Reihenfolge ist die der Quelle, `setCollectAnim(null)` vor
  /// `onSelectFact`. **Und die Sperre fällt hier**, nicht früher: sie hängt
  /// dort an `collectAnim`, und das wird genau in dieser Zeile geleert.
  void _reveal(String factId) {
    _revealTimer = null;
    setState(() {
      _burst = null;
      _collecting = false;
    });
    widget.onOpenFact(factId);
  }

  @override
  Widget build(BuildContext context) {
    final _FactBurst? burst = _burst;
    final _FactTeaser? teaser = _teaser;
    return Stack(
      // **`expand` und nicht der Standard**, aus demselben Grund wie in
      // `fact_balloon_overlay.dart`: ein Stapel mit lauter gesetzten Kindern
      // nimmt sonst die kleinste erlaubte Größe an und schneidet hart.
      fit: StackFit.expand,
      children: <Widget>[
        FactBalloonOverlay(onBalloonTap: _onBalloonTap),
        if (burst != null)
          FactCollectBurst(
            // Ein Schlüssel je Fakt: ein zweiter Sammelvorgang bekommt eine
            // frische Animation und nicht den weitergelaufenen Zustand der
            // vorigen. Ohne ihn behielte Flutter denselben `State`, und die
            // Münzen des zweiten Fluges starteten mitten in der Bewegung.
            key: ValueKey<String>('collect-burst-${burst.factId}'),
            origin: burst.origin,
            coinAmount: widget.coinAmount,
            nextDouble: widget.nextDouble,
          ),
        if (teaser != null)
          Positioned(
            left: FactTeaserCard.horizontalInset,
            right: FactTeaserCard.horizontalInset,
            bottom: FactTeaserCard.bottomOffset,
            child: _teaserCard(teaser),
          ),
      ],
    );
  }

  /// Setzt die Vorschau aus Sprache, Faktenliste und Entscheidung zusammen.
  ///
  /// Der Titel kommt aus [allFactsProvider] und nicht aus einem eigenen
  /// Abruf: die Überlagerung stammt aus derselben Liste, sie liegt also
  /// bereits im Speicher. Ein `FutureProvider.family` je angetipptem Fakt
  /// fragte dieselben Daten ein zweites Mal.
  Widget _teaserCard(_FactTeaser teaser) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final List<Fact>? facts = ref.watch(allFactsProvider).value;
    final Fact? fact = facts
        ?.where((Fact f) => '${f.id.value}' == teaser.factId)
        .firstOrNull;
    final double? distance = teaser.distanceInMeters;
    return FactTeaserCard(
      style: teaser.style,
      title:
          fact
              ?.contentFor(
                language.code,
                fallbackLanguageCode: AppLanguage.fallback.code,
              )
              .title ??
          '',
      // `🔒 ${dist} ${t('map.away', lang)}` gegen die Zeile ohne Ortung
      // (`:3855-3858`). Das Schlosszeichen steht in der Quelle in beiden
      // Zweigen, im zweiten als Teil des Textes selbst, siehe die
      // Ergänzungs-Map.
      distanceLine: distance == null
          ? strings.text('map.teaser.locationUnknown')
          : '🔒 ${formatFactTeaserDistance(distance)} '
                '${strings.text('map.away')}',
      hint: strings.text('map.walkToCollect'),
      onClose: () => setState(() => _teaser = null),
    );
  }
}

/// Der laufende Münzflug: welcher Fakt, und wo auf dem Bildschirm.
class _FactBurst {
  const _FactBurst({required this.factId, required this.origin});

  final String factId;
  final Offset origin;
}

/// Die stehende Vorschau.
class _FactTeaser {
  const _FactTeaser({
    required this.factId,
    required this.distanceInMeters,
    required this.style,
  });

  final String factId;

  /// `null` heißt **ohne Ortung**, siehe [FactTapDecision.distanceInMeters].
  final double? distanceInMeters;

  final FactCategoryStyle style;
}
