import 'dart:async';
import 'dart:math' as math;

import 'package:fact_app/features/discovery/presentation/fact_balloon_images.dart';
import 'package:fact_app/features/discovery/presentation/fact_categories.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Näherungsrechnung der Ballons.
///
/// Reine Funktion, also ohne Karte, ohne GPS und ohne Riverpod prüfbar. Genau
/// darum ist sie eine: die vier Wirkungen der Animation hängen alle an der
/// **einen** Zahl, die hier entsteht.
void main() {
  /// Der Nutzer steht am Marienplatz.
  const MapPosition user = MapPosition(latitude: 48.1372, longitude: 11.5755);

  /// Ein Punkt in [meters] Metern **nördlich** von [user].
  ///
  /// Nördlich und nicht östlich, weil die Rechnung dann exakt ist: entlang
  /// eines Meridians ist die Großkreisstrecke genau `R * Δφ`, ohne den
  /// Kosinus der Breite. Ein Grad Breite misst damit
  /// `π / 180 * 6371000 = 111194,93` Meter. Der Erdradius ist der der Quelle
  /// (`screen-map.jsx:297`), gegen den auch alle anderen Schwellen dieses
  /// Projekts geeicht sind.
  MapOverlayPoint pointAt(
    String id,
    double meters, {
    String category = 'hist',
    String state = factNotCollectedState,
  }) => MapOverlayPoint(
    id: id,
    position: MapPosition(
      latitude: user.latitude + meters * 180 / (math.pi * 6371000),
      longitude: user.longitude,
    ),
    styleId: factBalloonStyleId(category, state),
    state: state,
  );

  MapOverlay overlayOf(List<MapOverlayPoint> points) =>
      MapOverlay(id: factOverlayId, points: points);

  group('Wer in Reichweite ist', () {
    test('ohne Ortung ist niemand nah', () {
      // `screen-map.jsx:2248-2249` rechnet `pos ? haversine(...) : null` und
      // behandelt `null` als außer Reichweite. Ohne das drehte sich beim Start
      // alles, was zufällig am Nullmeridian liegt.
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[pointAt('7', 10)]),
        null,
      );

      expect(proximity.points, isEmpty);
      expect(proximity.nearest, isNull);
    });

    test('innerhalb von 150 Metern zählt, darüber nicht', () {
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[
          pointAt('drin', 149),
          pointAt('draussen', 151),
        ]),
        user,
      );

      expect(proximity.ids, <String>{'drin'});
    });

    test('der Hilfsaufbau trifft die gemeinte Entfernung', () {
      // **Ohne diese Prüfung misst jeder Test darunter etwas anderes, als er
      // behauptet.** Die Punkte entstehen aus einer eigenen Umrechnung; träfe
      // sie daneben, wären „149 Meter" in Wahrheit 160, und der Kantenfall
      // wäre keiner.
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[pointAt('probe', 100)]),
        user,
      );

      expect(proximity.points.single.distanceInMeters, closeTo(100, 0.001));
    });

    test('die Kante liegt bei 150 und nicht daneben', () {
      // Die Quelle prüft `dist < COIN_RADIUS` (`:2249`). **Der Fall
      // „ausgerechnet 150,000000" ist über Koordinaten nicht beobachtbar**,
      // dafür ist die Rundung der Gleitkommarechnung zu grob; geprüft wird
      // deshalb der Millimeter davor und dahinter. Die Grenze selbst steht als
      // `>=` im Code und ist bei der Konstanten begründet.
      expect(factProximityRadiusInMeters, 150);
      expect(
        factProximityOf(
          overlayOf(<MapOverlayPoint>[pointAt('kante', 150.001)]),
          user,
        ).points,
        isEmpty,
      );
      expect(
        factProximityOf(
          overlayOf(<MapOverlayPoint>[pointAt('kante', 149.999)]),
          user,
        ).points,
        hasLength(1),
      );
    });

    test('gesammelte Fakten sind ausgenommen', () {
      // `screen-map.jsx:2226` und `:2245-2246`: goldene Münzen animieren dort
      // allein über CSS und fallen aus beiden Schleifen. Erkannt am Feld
      // `MapOverlayPoint.state`, das genau dafür schon im Vertrag steht.
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[
          pointAt('gesammelt', 5, state: 'collected'),
          pointAt('offen', 100),
        ]),
        user,
      );

      expect(proximity.ids, <String>{'offen'});
      // **Und er wird auch nicht der nächste.** Wäre er nur von der Zeichnung
      // ausgenommen und nicht von der Suche, hüpfte niemand, obwohl ein
      // offener Fakt in Reichweite steht.
      expect(proximity.nearest?.id, 'offen');
    });

    test('ein Punkt ohne auflösbaren Kategoriestil fällt heraus', () {
      // Er ließe sich ohnehin nicht zeichnen und bleibt so in der nativen
      // Überlagerung stehen, wo ihn ein Symbol-Layer weiter zeichnet. Heute
      // unerreichbar, weil `factOverlayOf` jede Kennung selbst setzt.
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[
          MapOverlayPoint(
            id: 'fremd',
            position: user,
            styleId: 'irgendwas',
            state: factNotCollectedState,
          ),
          pointAt('offen', 100),
        ]),
        user,
      );

      expect(proximity.ids, <String>{'offen'});
    });
  });

  group('Betonung', () {
    test('sie ist 1 auf dem Fakt und 0 am Rand', () {
      // `screen-map.jsx:2254`: `t = 1 - dist / 150`.
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[pointAt('drauf', 0)]),
        user,
      );

      expect(proximity.points.single.emphasis, closeTo(1, 1e-6));
      // Der Rand selbst, ohne den Umweg über eine Koordinate: bei 150 Metern
      // ist die Betonung genau 0, und dort haben PNG und Widget dieselben
      // Maße.
      expect(
        FactProximityPoint(
          id: '1',
          position: user,
          style: factCategoryStylesByKey['hist']!,
          distanceInMeters: factProximityRadiusInMeters,
        ).emphasis,
        0,
      );
    });

    test('sie ist in der Mitte ein halb', () {
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[pointAt('mitte', 75)]),
        user,
      );

      expect(proximity.points.single.emphasis, closeTo(0.5, 1e-3));
    });

    test('sie nimmt mit der Entfernung ab', () {
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[pointAt('fern', 120), pointAt('nah', 20)]),
        user,
      );

      expect(
        proximity.points.first.emphasis,
        greaterThan(proximity.points.last.emphasis),
      );
    });
  });

  group('Der nächste', () {
    test('er steht vorn, und die Liste ist sortiert', () {
      // Die Reihenfolge ist Teil der Aussage: der Zeichner liest sie rückwärts,
      // damit der nächste obenauf liegt.
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[
          pointAt('mittel', 80),
          pointAt('nah', 12),
          pointAt('fern', 140),
        ]),
        user,
      );

      expect(
        proximity.points.map((FactProximityPoint p) => p.id).toList(),
        <String>['nah', 'mittel', 'fern'],
      );
      expect(proximity.nearest?.id, 'nah');
    });

    test('ohne jemanden in Reichweite gibt es keinen nächsten', () {
      final FactProximity proximity = factProximityOf(
        overlayOf(<MapOverlayPoint>[pointAt('weit', 900)]),
        user,
      );

      expect(proximity.nearest, isNull);
      expect(proximity.contains('weit'), isFalse);
    });
  });

  group('Zoomgrenze', () {
    test('oberhalb der Gruppierungsgrenze läuft die Animation', () {
      // Die Quelle animiert nur, was als DOM-Marker existiert, und die gibt es
      // allein für ungruppierte Features (`screen-map.jsx:2043-2045`).
      // `clusterMaxZoom: 15` heißt „bis einschließlich 15 wird gruppiert".
      expect(factOverlayGrouping.maxZoom, 15);
      expect(factAnimationRunsAt(16), isTrue);
      expect(factAnimationRunsAt(15.5), isTrue);
    });

    test('auf und unterhalb der Grenze läuft sie nicht', () {
      expect(factAnimationRunsAt(15), isFalse);
      expect(factAnimationRunsAt(14), isFalse);
      expect(factAnimationRunsAt(0), isFalse);
    });

    test('die Grenze hängt an der Gruppierung und nicht an einer Zahl', () {
      // Wer `factOverlayGrouping.maxZoom` ändert, verschiebt beide Seiten
      // mit: die gezeichneten Ballons und das Ausdünnen der nativen Liste.
      expect(
        factAnimationRunsAt(factOverlayGrouping.maxZoom),
        isFalse,
        reason: 'auf der Grenze wird noch gruppiert',
      );
      expect(factAnimationRunsAt(factOverlayGrouping.maxZoom + 0.01), isTrue);
    });
  });

  group('Der Weg vom Ortungsdienst in die Kartensprache', () {
    test('Breite bleibt Breite und Länge bleibt Länge', () {
      // **Vertauscht sähe das in jedem Widget-Test gleich aus.** Deshalb zwei
      // deutlich verschiedene Zahlen und eine eigene Prüfung.
      const DevicePosition fix = DevicePosition(
        latitude: 48.1351,
        longitude: 11.582,
        accuracyInMeters: 8,
      );

      expect(
        mapPositionOf(fix),
        const MapPosition(latitude: 48.1351, longitude: 11.582),
      );
    });

    test('die Genauigkeit bleibt beim Ortungsdienst', () {
      // `MapPosition` trägt sie nicht, und das ist Absicht: die Karte hat mit
      // der Güte einer Ortung nichts zu tun, den Filter zieht der Dienst.
      const DevicePosition sharp = DevicePosition(
        latitude: 48.1351,
        longitude: 11.582,
        accuracyInMeters: 3,
      );
      const DevicePosition blurry = DevicePosition(
        latitude: 48.1351,
        longitude: 11.582,
        accuracyInMeters: 30,
      );

      expect(mapPositionOf(sharp), mapPositionOf(blurry));
    });
  });

  group('Wertgleichheit', () {
    test('zwei gleich besetzte Nachbarschaften sind gleich', () {
      // **Nicht mit `const` gebaut**, weil Dart konstante Ausdrücke
      // kanonisiert: ein `expect(const X(...), const X(...))` wäre auch dann
      // grün, wenn `==` auf Identität reduziert wäre.
      final MapOverlay overlay = overlayOf(<MapOverlayPoint>[pointAt('7', 40)]);

      expect(
        factProximityOf(overlay, user),
        factProximityOf(overlayOf(<MapOverlayPoint>[pointAt('7', 40)]), user),
      );
    });

    test('eine andere Entfernung ist eine andere Nachbarschaft', () {
      // Ohne diese Prüfung überlebte ein `==`, das die Entfernung fallen
      // lässt, und dann bliebe der Ballon bei jedem Schritt gleich groß.
      expect(
        factProximityOf(overlayOf(<MapOverlayPoint>[pointAt('7', 40)]), user),
        isNot(
          factProximityOf(overlayOf(<MapOverlayPoint>[pointAt('7', 41)]), user),
        ),
      );
    });

    test('die leere Nachbarschaft ist gleich einer selbst gebauten leeren', () {
      expect(
        FactProximity.empty,
        factProximityOf(overlayOf(<MapOverlayPoint>[]), user),
      );
    });
  });

  group('Der Provider', () {
    // **Der Teil, den keine reine Funktion abdeckt.** Zwischen der Rechnung
    // oben und dem Zeichner liegen zwei Quellen, die unabhängig voneinander
    // eintreffen: die geladenen Fakten und die Ortung. Genau dieses Stück
    // dazwischen war bei den Schritten 15 und 16 der teuerste ungeprüfte
    // Fleck.

    ProviderContainer containerWith(
      FakeLocationService location,
      MapOverlay overlay,
    ) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(location),
          factOverlayProvider.overrideWith((Ref ref) async => overlay),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('ohne Ortung bleibt die Nachbarschaft leer', () async {
      final FakeLocationService location = FakeLocationService();
      addTearDown(location.close);
      final ProviderContainer container = containerWith(
        location,
        overlayOf(<MapOverlayPoint>[pointAt('7', 30)]),
      );
      await container.read(factOverlayProvider.future);

      expect(container.read(factProximityProvider), FactProximity.empty);
    });

    test('mit Ortung und geladenen Fakten steht der nahe darin', () async {
      final FakeLocationService location = FakeLocationService();
      addTearDown(location.close);
      final ProviderContainer container = containerWith(
        location,
        overlayOf(<MapOverlayPoint>[pointAt('nah', 30), pointAt('fern', 900)]),
      );
      await container.read(factOverlayProvider.future);
      // Ohne diesen Lesezugriff lebt der Ortungs-Notifier nicht und abonniert
      // seinen Strom nie.
      container.read(factProximityProvider);

      location.emit(
        DevicePosition(
          latitude: user.latitude,
          longitude: user.longitude,
          accuracyInMeters: 8,
        ),
      );
      await pumpEventQueue();

      expect(container.read(factProximityProvider).ids, <String>{'nah'});
    });

    test('eine zu ungenaue Ortung ändert nichts', () async {
      // Der Genauigkeitsfilter gehört dem Ortungsdienst (Schritt 13, 35 Meter);
      // hier steht nur, dass die Näherung ihn erbt statt ihn zu umgehen.
      final FakeLocationService location = FakeLocationService();
      addTearDown(location.close);
      final ProviderContainer container = containerWith(
        location,
        overlayOf(<MapOverlayPoint>[pointAt('nah', 30)]),
      );
      await container.read(factOverlayProvider.future);
      container.read(factProximityProvider);

      location.emit(
        DevicePosition(
          latitude: user.latitude,
          longitude: user.longitude,
          accuracyInMeters: 200,
        ),
      );
      await pumpEventQueue();

      expect(container.read(factProximityProvider), FactProximity.empty);
    });
  });
}

/// Ein Ortungsdienst, dessen Ausgaben der Test selbst setzt.
class FakeLocationService implements LocationService {
  /// `broadcast`, damit `close()` auch dann erfüllt wird, wenn niemand
  /// zugehört hat.
  final StreamController<DevicePosition> _controller =
      StreamController<DevicePosition>.broadcast();

  @override
  Stream<DevicePosition> positionUpdates() => _controller.stream;

  /// Schiebt eine Ortung in den Strom.
  void emit(DevicePosition position) => _controller.add(position);

  /// Schließt den Strom.
  Future<void> close() => _controller.close();
}
