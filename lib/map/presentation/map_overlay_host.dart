/// Der Teil des Karten-Hosts, der Überlagerungen führt: welche Bilder
/// registriert sind, welche Überlagerungen liegen, und wie beides in Quellen
/// und Layer des SDK übersetzt wird.
///
/// ## Warum das ein eigenes Objekt ist
///
/// Derselbe Grund wie bei `MapCameraHost`: **im Widget-Test entsteht nie ein
/// `MapLibreMapController`**, und alles, was in einem `State` läge, wäre
/// ausschließlich auf einem Gerät prüfbar. Hier wiegt das schwerer als bei der
/// Kamera, denn die Fehler dieses Schritts sind lautlos. Eine Quelle ohne
/// Gruppierung sieht aus wie eine mit vielen Punkten. Eine Kennung unter
/// `properties` statt oben sieht aus wie gar nichts, bis jemand tippt. Ein
/// fehlendes `minzoom` sieht aus wie eine Karte, die beim Herauszoomen
/// zuwuchert.
///
/// ## Zustand, nicht Ereignis
///
/// Eine Kameraabsicht, die vor der Karte eintrifft, lässt der Host fallen und
/// meldet das. Eine Überlagerung, die vor der Karte eintrifft, **bleibt
/// liegen** und wird beim Binden aufgelegt. Der Unterschied steht im Vertrag
/// (`map/domain/map_overlay.dart`) und ist der Grund, warum dieses Objekt
/// überhaupt Zustand hält: die Fakten kommen aus dem Netz, die Karte aus dem
/// Baum, und welches von beidem zuerst da ist, entscheidet niemand.
///
/// ## Warum das Aussehen der Gruppen hier liegt und nicht im Vertrag
///
/// Es gibt heute genau eine gruppierte Überlagerung, und in der
/// Verhaltensquelle genau ein Aussehen für Gruppen
/// (`02_Frontend/app/screen-map.jsx:1954-2029`). Stünden die Farben im
/// Vertrag, trüge `map/domain/` Design, und das nächste Feature müsste eine
/// Palette mitliefern, um überhaupt einen Punkt setzen zu können.
///
/// **Der Auslöser, ab dem das nicht mehr trägt:** eine zweite gruppierte
/// Überlagerung, die anders aussehen soll. Dann gehört das Aussehen in den
/// Vertrag oder in eine benannte Vorlage, und nicht in ein `if` über die
/// Überlagerungskennung.
library;

import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/presentation/map_overlay_driver.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Führt Bilder und Überlagerungen einer Karte.
class MapOverlayHost {
  /// Erzeugt einen Führer ohne Karte.
  MapOverlayHost({DiagnosticSink diagnostics = const SilentDiagnosticSink()})
    : _diagnostics = diagnostics;

  /// Gemeldet, wenn ein Punkt auf ein Bild zeigt, das niemand registriert hat.
  ///
  /// **Das ist der einzige Schutz, den ein Vertrag mit freien Zeichenketten
  /// haben kann.** MapLibre zeichnet für eine unbekannte `icon-image`-Kennung
  /// gar nichts, ohne Fehler und ohne Warnung; ohne diese Meldung wäre eine
  /// vertippte Kategorie eine leere Karte ohne jeden Hinweis.
  static const String unknownStyleEvent = 'map.overlay.unknown_style';

  final DiagnosticSink _diagnostics;

  /// Die registrierten Bilder, nach [MapOverlayImage.styleId].
  final Map<String, MapOverlayImage> _images = <String, MapOverlayImage>{};

  /// Die gesetzten Überlagerungen, nach [MapOverlay.id].
  final Map<String, MapOverlay> _overlays = <String, MapOverlay>{};

  /// Für welche Überlagerungen Quelle und Layer im SDK wirklich stehen.
  ///
  /// Getrennt von [_overlays], weil die beiden auseinanderfallen dürfen: eine
  /// Überlagerung, die vor der Karte gesetzt wurde, steht in [_overlays] und
  /// nicht hier. Ohne die Trennung müsste `setOverlay` raten, ob es die Quelle
  /// anlegen oder nur ihre Daten austauschen soll.
  final Set<String> _installed = <String>{};

  MapOverlayDriver? _driver;

  /// Die Kette der SDK-Aufrufe, siehe [_enqueue].
  Future<void> _work = Future<void>.value();

  /// Welche Bilder registriert sind. Nur für Tests.
  @visibleForTesting
  List<String> get debugRegisteredStyleIds => _images.keys.toList();

  /// Welche Überlagerungen im SDK stehen. Nur für Tests.
  @visibleForTesting
  List<String> get debugInstalledOverlayIds => _installed.toList();

  /// Wartet, bis alle abgekoppelten SDK-Aufrufe durch sind. Nur für Tests.
  ///
  /// Es gibt diesen Zugang, weil die Reihenfolge der Aufrufe die eigentliche
  /// Zusicherung ist: eine Quelle muss vor ihren Layern stehen. Ohne ihn
  /// müsste ein Test auf `pumpEventQueue` hoffen und wäre von der Anzahl der
  /// Mikrotasks abhängig, also von einem Implementierungsdetail.
  @visibleForTesting
  Future<void> get debugSettled => _work;

  /// Die Karte steht: ab jetzt geht alles ans SDK.
  ///
  /// Zuerst die Bilder, dann die Überlagerungen. Die Reihenfolge ist tragend:
  /// ein Symbol-Layer ohne sein Bild zeichnet nichts.
  void bindSurface(MapOverlayDriver driver) {
    _driver = driver;
    _installed.clear();
    for (final MapOverlayImage image in _images.values) {
      _pushImage(image);
    }
    for (final MapOverlay overlay in _overlays.values) {
      _install(overlay);
    }
  }

  /// Die Karte ist weg. Bilder und Überlagerungen bleiben, das SDK nicht.
  ///
  /// [_installed] wird geleert, weil die Quellen mit der Karte verschwinden.
  /// Bliebe der Eintrag stehen, hielte der nächste [setOverlay] die Quelle für
  /// vorhanden und schöbe Daten in etwas, das es nicht gibt.
  void unbindSurface() {
    _driver = null;
    _installed.clear();
  }

  /// Registriert Bilder und schiebt sie zur Karte, wenn eine steht.
  void registerImages(List<MapOverlayImage> images) {
    for (final MapOverlayImage image in images) {
      _images[image.styleId] = image;
      _pushImage(image);
    }
  }

  /// Legt [overlay] auf oder tauscht die Daten einer schon liegenden aus.
  void setOverlay(MapOverlay overlay) {
    _reportUnknownStyles(overlay);
    _overlays[overlay.id] = overlay;
    if (_driver == null) {
      return;
    }
    if (_installed.contains(overlay.id)) {
      _enqueue('map.overlay.update', (MapOverlayDriver driver) async {
        await driver.setGeoJsonSource(
          overlaySourceId(overlay.id),
          overlayGeoJson(overlay),
        );
      });
      return;
    }
    _install(overlay);
  }

  /// Nimmt die Überlagerung [overlayId] herunter. Unbekannt heißt: nichts tun.
  void removeOverlay(String overlayId) {
    _overlays.remove(overlayId);
    if (!_installed.remove(overlayId)) {
      return;
    }
    _enqueue('map.overlay.remove', (MapOverlayDriver driver) async {
      // Erst die Layer, dann die Quelle. Umgekehrt hinge ein Layer an einer
      // Quelle, die es nicht mehr gibt.
      for (final String layerId in overlayLayerIds(overlayId)) {
        await driver.removeLayer(layerId);
      }
      await driver.removeSource(overlaySourceId(overlayId));
    });
  }

  /// Vergisst alles. Ruft der Karten-Host beim Entsorgen.
  void dispose() {
    unbindSurface();
    _images.clear();
    _overlays.clear();
  }

  // ---------------------------------------------------------------------------
  // Innenleben
  // ---------------------------------------------------------------------------

  void _pushImage(MapOverlayImage image) {
    if (_driver == null) {
      return;
    }
    _enqueue('map.overlay.image', (MapOverlayDriver driver) async {
      await driver.addImage(image.styleId, image.bytes);
    });
  }

  /// Legt Quelle und Layer an.
  ///
  /// Die Reihenfolge der Layer ist die Zeichenreihenfolge: der zuletzt
  /// angelegte liegt oben. Sie folgt der Quelle
  /// (`screen-map.jsx:1954-2029`): Grundkreis, weicher Mittelkreis, Glanz,
  /// Zahl. Die einzelnen Punkte kommen zuletzt, damit ein Ballon nicht hinter
  /// einer Gruppe verschwindet.
  void _install(MapOverlay overlay) {
    _installed.add(overlay.id);
    _enqueue('map.overlay.install', (MapOverlayDriver driver) async {
      final String sourceId = overlaySourceId(overlay.id);
      await driver.addSource(sourceId, overlaySourceProperties(overlay));

      if (overlay.grouping != null) {
        for (final MapOverlayGroupLayer layer in overlayGroupCircleLayers(
          overlay.id,
        )) {
          await driver.addCircleLayer(
            sourceId,
            layer.layerId,
            layer.properties,
            minzoom: overlay.minZoom,
            maxzoom: overlay.maxZoom,
            filter: groupFilter,
          );
        }
        await driver.addSymbolLayer(
          sourceId,
          overlayGroupCountLayerId(overlay.id),
          overlayGroupCountProperties(),
          minzoom: overlay.minZoom,
          maxzoom: overlay.maxZoom,
          filter: groupFilter,
        );
      }

      await driver.addSymbolLayer(
        sourceId,
        overlayPointLayerId(overlay.id),
        overlayPointProperties(),
        minzoom: overlay.minZoom,
        maxzoom: overlay.maxZoom,
        // Ohne Gruppierung trägt kein Feature `point_count`, der Filter ist
        // dann für jedes wahr. Er steht trotzdem, weil er sonst genau in dem
        // Moment fehlte, in dem eine Überlagerung gruppiert wird.
        filter: singlePointFilter,
      );
    });
  }

  /// Meldet jeden Punkt, dessen Bild niemand registriert hat.
  ///
  /// Gemeldet wird **je Kennung einmal** und nicht je Punkt: 600 Fakten
  /// derselben unbekannten Kategorie sind ein Fehler, nicht 600.
  void _reportUnknownStyles(MapOverlay overlay) {
    final Set<String> unknown = <String>{};
    for (final MapOverlayPoint point in overlay.points) {
      if (!_images.containsKey(point.styleId)) {
        unknown.add(point.styleId);
      }
    }
    if (unknown.isEmpty) {
      return;
    }
    final List<String> sorted = unknown.toList()..sort();
    _diagnostics.report(
      DiagnosticEvent(unknownStyleEvent, <String, String>{
        'overlay': overlay.id,
        'styles': sorted.join(','),
      }),
    );
  }

  /// Hängt einen SDK-Vorgang hinten an die Kette.
  ///
  /// ## Warum eine Kette und nicht einfach `await`
  ///
  /// Die öffentlichen Methoden sind synchron, weil ihre Aufrufer es sind: ein
  /// Feature setzt eine Überlagerung und wartet nicht. Die SDK-Aufrufe darunter
  /// sind es nicht, und ihre **Reihenfolge ist tragend**: eine Quelle muss vor
  /// ihren Layern stehen, ein Bild vor dem Layer, der es benutzt. Zwei
  /// unabhängig gestartete Ketten könnten sich überholen, und das Ergebnis
  /// wäre eine Karte, die je nach Laufzeit anders aussieht.
  ///
  /// **Ein Fehlschlag beendet die Kette nicht.** Er wird über
  /// [reportDetached] gemeldet und danach abgefangen: bliebe er stehen, wäre
  /// jeder spätere Vorgang mit ihm gescheitert, und ein einziger fehlerhafter
  /// Layer legte die Karte für den Rest der Sitzung still.
  void _enqueue(String origin, Future<void> Function(MapOverlayDriver) step) {
    final Future<void> next = _work.then<void>((_) async {
      final MapOverlayDriver? driver = _driver;
      if (driver == null) {
        // Die Karte ist verschwunden, während der Vorgang in der Kette stand.
        return;
      }
      await step(driver);
    });
    _work = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    reportDetached(next, origin: origin);
  }
}

// -----------------------------------------------------------------------------
// Kennungen
// -----------------------------------------------------------------------------

/// Die Kennung der Quelle einer Überlagerung.
///
/// Abgeleitet und nicht frei wählbar: zwei Namen für dieselbe Sache sind zwei
/// Gelegenheiten, sich zu vertippen, und ein vertippter Quellenname fällt erst
/// als leere Karte auf.
String overlaySourceId(String overlayId) => '$overlayId.source';

/// Die Kennungen der Gruppen-Layer, in Zeichenreihenfolge.
///
/// Entspricht `fact-clusters`, `fact-clusters-mid` und `fact-clusters-shine`
/// (`screen-map.jsx:1956`, `:1972`, `:1988`).
List<String> overlayGroupCircleLayerIds(String overlayId) => <String>[
  '$overlayId.groups',
  '$overlayId.groups-mid',
  '$overlayId.groups-shine',
];

/// Die Kennung des Layers mit der Anzahl je Gruppe (`fact-cluster-count`).
String overlayGroupCountLayerId(String overlayId) => '$overlayId.group-count';

/// Die Kennung des Layers mit den einzelnen Punkten.
String overlayPointLayerId(String overlayId) => '$overlayId.points';

/// Alle Layer einer Überlagerung, in Zeichenreihenfolge.
List<String> overlayLayerIds(String overlayId) => <String>[
  ...overlayGroupCircleLayerIds(overlayId),
  overlayGroupCountLayerId(overlayId),
  overlayPointLayerId(overlayId),
];

// -----------------------------------------------------------------------------
// GeoJSON und Quelle
// -----------------------------------------------------------------------------

/// Die Eigenschaft, unter der der Zustand eines Punktes im GeoJSON steht.
const String overlayStateProperty = 'state';

/// Die Eigenschaft, unter der die Stil-Kennung eines Punktes im GeoJSON steht.
const String overlayStyleProperty = 'style';

/// Übersetzt eine Überlagerung in eine GeoJSON-`FeatureCollection`.
///
/// ## Die Kennung steht oben und nicht unter `properties`
///
/// Das ist die eine Zeile dieses Schritts, die man nicht sehen kann und die
/// später teuer wird. Der Antipp-Rückruf von `maplibre_gl 0.26.2` liefert dem
/// Aufrufer nur `id`, `layerId` und die beiden Positionen; die `properties`
/// des Features kommen gar nicht mit. Eine Kennung unter
/// `properties.id` ist damit beim Antippen **nicht erreichbar**, und was
/// ankommt, ist die Zeichenkette `"null"`, ohne Ausnahme und ohne Warnung.
///
/// Die Verhaltensquelle legt sie genau dorthin (`screen-map.jsx:1896`:
/// `properties: { id: f.id ?? f.nr, ... }`), weil sie ihre Ballons als
/// DOM-Elemente baut und die Eigenschaften selbst in der Hand hat. Wer das
/// GeoJSON eins zu eins übernimmt, erbt den Fehler.
///
/// `promoteId` löst das nicht: es wirkt laut eigener Doku des Pakets nur im
/// Web (`controller.dart:440-444`).
///
/// **Das Antippen selbst ist in diesem Schritt ausdrücklich nicht gebaut.**
/// Die Kennung liegt trotzdem von Anfang an richtig, weil sie später zu
/// verschieben hieße, die Daten aller Punkte neu zu schreiben, während der
/// Fehler sich als „das Antippen geht nicht" zeigt und nicht als „die Kennung
/// liegt falsch".
Map<String, dynamic> overlayGeoJson(MapOverlay overlay) => <String, dynamic>{
  'type': 'FeatureCollection',
  'features': <Map<String, dynamic>>[
    for (final MapOverlayPoint point in overlay.points)
      <String, dynamic>{
        'type': 'Feature',
        'id': point.id,
        'geometry': <String, dynamic>{
          'type': 'Point',
          // GeoJSON zählt Länge vor Breite (RFC 7946 §3.1.1), die Domäne
          // umgekehrt. Das ist die eine Stelle, an der die Vertauschung
          // lautlos wäre: Punkte lägen dann irgendwo in Somalia, und im
          // Widget-Test sähe niemand etwas davon.
          'coordinates': <double>[
            point.position.longitude,
            point.position.latitude,
          ],
        },
        'properties': <String, dynamic>{
          overlayStyleProperty: point.styleId,
          overlayStateProperty: point.state,
        },
      },
  ],
};

/// Die Quelleneigenschaften einer Überlagerung.
///
/// **`cluster`, `clusterMaxZoom` und `clusterRadius` gibt es nur auf diesem
/// Weg.** `addGeoJsonSource` reicht auf Android allein `withSynchronousUpdate`
/// durch (`MapLibreMapController.java:448`) und gruppiert deshalb **nie**,
/// ohne Fehlermeldung. Der `SourcePropertyConverter` setzt die drei Felder auf
/// beiden Plattformen um (`SourcePropertyConverter.java:82-95`).
///
/// **`clusterMaxZoom` verliert auf Android seine Nachkommastellen.**
/// `Convert.toInt` ist `((Number) o).intValue()` (`Convert.java:101-103`), also
/// Abschneiden und nicht Runden. Der Typ hier ist [double], weil das Paket ihn
/// so führt; ankommen dürfen trotzdem nur ganze Zoomstufen. Steht bei
/// [MapOverlayGrouping.maxZoom].
GeojsonSourceProperties overlaySourceProperties(MapOverlay overlay) {
  final MapOverlayGrouping? grouping = overlay.grouping;
  return GeojsonSourceProperties(
    data: overlayGeoJson(overlay),
    cluster: grouping != null,
    clusterMaxZoom: grouping?.maxZoom,
    // Der Standard des Pakets ist 50 (`source_properties.dart:517`; `:514`
    // ist `buffer = 128`). Ohne
    // Gruppierung ist der Wert bedeutungslos, und ihn dann zu setzen wäre eine
    // Zahl ohne Aussage.
    clusterRadius: grouping?.radiusInScreenPixels ?? 50,
  );
}

// -----------------------------------------------------------------------------
// Layer
// -----------------------------------------------------------------------------

/// Filtert auf Gruppen: nur Features, die eine Anzahl tragen.
///
/// `point_count` setzt MapLibre selbst an jede Gruppe
/// (`source_properties.dart:445-452`). Gleiche Bedingung wie
/// `screen-map.jsx:1960`.
const List<Object> groupFilter = <Object>['has', 'point_count'];

/// Filtert auf einzelne Punkte: alles, was keine Gruppe ist.
///
/// Gegenstück zu [groupFilter], gleiche Bedingung wie `screen-map.jsx:2044`.
const List<Object> singlePointFilter = <Object>[
  '!',
  <Object>['has', 'point_count'],
];

/// Der Radius einer Gruppe, gestuft nach ihrer Anzahl.
///
/// `screen-map.jsx:1918-1925`, unverändert übernommen.
const List<Object> _groupRadius = <Object>[
  'step',
  <Object>['get', 'point_count'],
  24,
  20,
  30,
  50,
  38,
  100,
  46,
  200,
  54,
];

/// Ein Kreis-Layer einer Gruppe: seine Kennung und sein Aussehen.
///
/// Zusammen und nicht als zwei parallele Listen, damit eine hinzugefügte Stufe
/// nicht an einer Stelle vergessen werden kann.
@immutable
class MapOverlayGroupLayer {
  /// Erzeugt die Zuordnung.
  const MapOverlayGroupLayer(this.layerId, this.properties);

  /// Die Kennung des Layers.
  final String layerId;

  /// Sein Aussehen.
  final CircleLayerProperties properties;
}

/// Die drei Kreis-Layer einer Gruppe, in Zeichenreihenfolge.
///
/// Übernommen aus `screen-map.jsx:1954-2002`. Die Farbstufen bleiben in der
/// FACT-Palette, und `addCircleLayer` bildet `circle-blur`,
/// `circle-translate` und `circle-stroke-*` eins zu eins ab
/// (`layer_properties.dart`, `CircleLayerProperties`).
List<MapOverlayGroupLayer> overlayGroupCircleLayers(String overlayId) {
  final List<String> ids = overlayGroupCircleLayerIds(overlayId);
  return <MapOverlayGroupLayer>[
    MapOverlayGroupLayer(
      ids[0],
      const CircleLayerProperties(
        circleColor: <Object>[
          'step',
          <Object>['get', 'point_count'],
          '#C9740A',
          20,
          '#A04210',
          50,
          '#7A1B0A',
          100,
          '#5A1208',
          200,
          '#3A0A04',
        ],
        circleRadius: _groupRadius,
        circleStrokeWidth: 4,
        circleStrokeColor: 'rgba(255,255,255,0.95)',
        circleOpacity: 1,
      ),
    ),
    MapOverlayGroupLayer(
      ids[1],
      const CircleLayerProperties(
        circleColor: <Object>[
          'step',
          <Object>['get', 'point_count'],
          '#F39C0E',
          20,
          '#E8380D',
          50,
          '#B83A2E',
          100,
          '#8E1F0A',
          200,
          '#6B1A0A',
        ],
        circleRadius: <Object>['*', _groupRadius, 0.92],
        circleBlur: 0.35,
        circleStrokeWidth: 0,
        circleOpacity: 1,
      ),
    ),
    MapOverlayGroupLayer(
      ids[2],
      const CircleLayerProperties(
        circleColor: <Object>[
          'step',
          <Object>['get', 'point_count'],
          '#FFD27A',
          20,
          '#F39C0E',
          50,
          '#E8380D',
          100,
          '#C82A0A',
          200,
          '#A82508',
        ],
        circleRadius: <Object>['*', _groupRadius, 0.72],
        circleTranslate: <double>[-2, -3],
        circleBlur: 0.9,
        circleStrokeWidth: 0,
        circleOpacity: 1,
      ),
    ),
  ];
}

/// Die Beschriftung mit der Anzahl je Gruppe.
///
/// `screen-map.jsx:2003-2029`, unverändert übernommen.
///
/// **Ungeprüft und deshalb hier vermerkt:** diese Beschriftung ist die erste
/// im ganzen Projekt, die wirklich Glyphen anfordert. Der gebackene Stil hat
/// dafür einen Endpunkt (`assets/map/fact_map_style.json:18`), der bisher nie
/// beansprucht wurde, weil in ihm alle Beschriftungen ausgeblendet sind. Ob
/// `Noto Sans Bold` dort ausgeliefert wird, ist ohne Gerät nicht zu
/// beantworten; fehlt die Schrift, bleiben die Kreise stehen und die Zahlen
/// weg.
SymbolLayerProperties overlayGroupCountProperties() =>
    const SymbolLayerProperties(
      textField: '{point_count_abbreviated}',
      textFont: <String>['Noto Sans Bold'],
      textSize: <Object>[
        'step',
        <Object>['get', 'point_count'],
        14,
        20,
        16,
        50,
        18,
        100,
        20,
        200,
        22,
      ],
      textAllowOverlap: true,
      textColor: '#ffffff',
      textHaloColor: 'rgba(0,0,0,0.25)',
      textHaloWidth: 1,
    );

/// Die Zoom-Skalierung der einzelnen Punkte, als Ausdruck.
///
/// Die Quelle rechnet sie in JavaScript aus (`screen-map.jsx:1799`):
///
/// ```js
/// const mapGetScale = z => Math.max(0.42, Math.min(1.25, (z - 11) / 6));
/// ```
///
/// Das ist eine reine Funktion des Zooms, also genau das, was ein
/// `interpolate`-Ausdruck ohne einen einzigen Kanalaufruf leistet. Die beiden
/// Stützstellen sind die Knickpunkte der Klammer und nicht gewählt:
/// `(z - 11) / 6` erreicht 0,42 bei `z = 13,52` und 1,25 bei `z = 18,5`.
/// Außerhalb der Stützstellen hält MapLibre den jeweiligen Randwert, und
/// genau das tun `Math.max` und `Math.min` auch.
///
/// ## Die Zahl stimmt, der Operand ist ein anderer
///
/// **`icon-size` skaliert das ganze Bild, die Quelle skaliert nur den Kopf.**
/// `screen-map.jsx:2185` setzt `scale()` auf `.coin-float-wrap`, und die
/// umschließt in `coinMakeEl` allein den Kopf (`:1844-1861`); Stiel und
/// Bodenschatten liegen außerhalb und behalten ihre 50 beziehungsweise 7
/// Pixel. Hier trägt ein Bild alle drei Teile, der Faktor greift also auf
/// alles.
///
/// Sichtbar wird der Unterschied beim Herauszoomen: auf Zoom 13,5 hängt in der
/// Quelle ein kleiner Kopf an einem vollen Stiel, hier schrumpft der Stiel mit.
/// Das ist eine bewusst in Kauf genommene Abweichung und keine Übernahme: den
/// Kopf allein zu skalieren hieße, je Zoomstufe ein eigenes Bild zu zeichnen.
const List<Object> overlayPointSizeExpression = <Object>[
  'interpolate',
  <Object>['linear'],
  <Object>['zoom'],
  13.52,
  0.42,
  18.5,
  1.25,
];

/// Das Aussehen der einzelnen Punkte.
///
/// ## `icon-image` liest die Eigenschaft, statt sie abzubilden
///
/// **Bewusste Abweichung von der Vorgabe, einen `match`-Ausdruck zu benutzen.**
/// Der tragende Grund ist einer und nur einer: ein `match` kostet eine Liste
/// aller Kategorien, und die müsste in `lib/map/` stehen und mit jeder neuen
/// Kategorie mitwachsen. Genau diese Grenze hält Regel 18 frei; eine Liste
/// hier wäre der Griff darüber, und sie wäre die Sorte Doppelpflege, die man
/// beim nächsten Mal vergisst.
///
/// **Eine frühere Fassung hat zusätzlich behauptet, ein `match` mit leerem
/// Standardausgang verhalte sich „Zeichen für Zeichen" wie dieses `get`. Das
/// stimmt nicht.** Für eine unbekannte Kennung liefert `get` die Zeichenkette
/// selbst, `match` die leere; gleich ist allein, dass MapLibre in beiden Fällen
/// nichts zeichnet. Der Unterschied ist sogar einer zugunsten des `get`: die
/// native Meldung nennt dann die gesuchte Kennung beim Namen.
///
/// Der Schutz gegen eine unbekannte Kennung ist deshalb nicht der Ausdruck,
/// sondern [MapOverlayHost.unknownStyleEvent]. Das Feature bildet unbekannte
/// Kategorien seinerseits schon auf `hist` ab und meldet das ebenfalls; der
/// Ausdruck sieht sie also gar nicht.
///
/// ## `icon-allow-overlap` ist Parität und keine Bequemlichkeit
///
/// Die Quelle setzt für jeden einzelnen Punkt einen DOM-Marker
/// (`screen-map.jsx:2187`), und DOM-Marker verdrängen einander nie. Ohne
/// diesen Schalter blendet MapLibre kollidierende Symbole aus, und in einer
/// dicht besetzten Altstadt verschwände die Hälfte der Ballons, ohne dass
/// jemand einen Fehler sähe.
///
/// ## Der Punkt sitzt unten
///
/// `icon-anchor: bottom` setzt die Unterkante des Bildes auf die Koordinate,
/// wie `new mapboxgl.Marker({ element: el, anchor: 'bottom' })` in
/// `screen-map.jsx:2187`.
/// Der Kopf des Ballons schwebt darüber, am Boden steht sein Schatten.
SymbolLayerProperties overlayPointProperties() => const SymbolLayerProperties(
  iconImage: <Object>['get', overlayStyleProperty],
  iconSize: overlayPointSizeExpression,
  iconAnchor: 'bottom',
  iconAllowOverlap: true,
);
