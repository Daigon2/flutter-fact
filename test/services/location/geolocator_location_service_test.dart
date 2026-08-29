import 'package:fact_app/services/location/geolocator_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Die Einstellungen des Ortungsstroms und die Umrechnung aus dem Paket.
///
/// **Der Strom selbst kommt hier nicht vor.** Ohne Plattformkanal gibt es
/// keinen `geolocator`, und ein Test, der ihn abonnierte, prüfte eine
/// `MissingPluginException`. Prüfbar sind die beiden Teile, die keine
/// Plattform brauchen, und sie sind genau die, an denen ein Fehler lautlos
/// wäre.
void main() {
  // **Nötig, seit ein Test wirklich abonniert.** Hinter `getPositionStream`
  // steckt ein `EventChannel`, und der greift beim Zuhören auf den
  // `BinaryMessenger` der Bindung zu. Ohne diese Zeile bricht der Test mit
  // „Binding has not yet been initialized" ab, und zwar bevor er irgendetwas
  // über die Berechtigung aussagt. Ein Plugin wird damit nicht gefunden; der
  // Kanal antwortet nicht, und genau das ist hier richtig.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Die Einstellungen des Stroms', () {
    test('der Streckenfilter ist 0 und ausdrücklich nicht 12', () {
      // **Der teuerste denkbare Tippfehler in dieser Datei.** Die 12 Meter aus
      // `screen-map.jsx:2668` sind die Totzone der **Kamera**, nicht des
      // Ortungsdienstes; die Quelle setzt an `watchPosition`
      // (`:2742-2749`) überhaupt keinen Streckenfilter. Stünde hier 12, wirkte
      // dieselbe Schwelle zweimal, und Audio-Beacon und Geofencing bekämen
      // später einen ausgedünnten Strom, ohne dass jemand danach sucht.
      expect(GeolocatorLocationService.locationSettings.distanceFilter, 0);
      expect(
        GeolocatorLocationService.locationSettings.distanceFilter,
        isNot(12),
      );
    });

    test('höchste Genauigkeit, wie `enableHighAccuracy: true`', () {
      // `screen-map.jsx:2748`.
      expect(
        GeolocatorLocationService.locationSettings.accuracy,
        LocationAccuracy.best,
      );
    });

    test('kein Zeitlimit', () {
      // `timeout: 10000` der Quelle (`:2748`) ist **nicht** übernommen:
      // `timeLimit` beendet den Strom mit einer `TimeoutException`, während
      // die Quelle nur ihren Fehlerzweig ruft und weitersucht. Die Abweichung
      // ist in `geolocator_location_service.dart` begründet, und dieser Test
      // hält fest, dass sie eine Entscheidung war und kein Vergessen.
      expect(GeolocatorLocationService.locationSettings.timeLimit, isNull);
    });
  });

  group('Die Berechtigung', () {
    // **Ohne die Naht im Konstruktor wäre hier gar nichts prüfbar.**
    // `Geolocator` ist statisch, ein Test ohne Gerät kommt an
    // `checkPermission` nicht heran, und nachgemessen am 29.08.2026 überlebte
    // das Löschen des ganzen Aufrufs alle 1177 Tests. Auf dem Gerät wäre die
    // Folge kein Fehler, sondern Stille.
    late List<String> calls;

    GeolocatorLocationService serviceWith(LocationPermission current) {
      return GeolocatorLocationService(
        checkPermission: () async {
          calls.add('check');
          return current;
        },
        requestPermission: () async {
          calls.add('request');
          return LocationPermission.whileInUse;
        },
      );
    }

    setUp(() => calls = <String>[]);

    test('wird erst erfragt, wenn jemand zuhört', () async {
      // Ein `async*` läuft nicht beim Aufruf an, sondern beim Abonnieren. Das
      // ist der Unterschied zwischen „die App fragt beim Start nach dem
      // Standort" und „sie fragt, wenn die Karte ihn braucht".
      final stream = serviceWith(
        LocationPermission.whileInUse,
      ).positionUpdates();

      expect(calls, isEmpty);

      final subscription = stream.listen(
        (_) {},
        // Ohne Plattformkanal liefert `geolocator` hier einen Fehler. Er
        // gehört nicht zum Prüfgegenstand und darf den Test nicht umreißen.
        onError: (Object _) {},
      );
      await pumpEventQueue();
      expect(calls, <String>['check']);

      await subscription.cancel();
    });

    test('eine offene Frage wird gestellt', () async {
      final subscription = serviceWith(
        LocationPermission.denied,
      ).positionUpdates().listen((_) {}, onError: (Object _) {});
      await pumpEventQueue();

      expect(calls, <String>['check', 'request']);

      await subscription.cancel();
    });

    test('eine beantwortete Frage wird nicht wiederholt', () async {
      // **`deniedForever` gehört ausdrücklich dazu.** Nach der dauerhaften
      // Ablehnung öffnet das Betriebssystem keinen Dialog mehr; ein Fragen
      // auf Verdacht wäre ein Aufruf, der nie etwas ändert.
      for (final permission in <LocationPermission>[
        LocationPermission.whileInUse,
        LocationPermission.always,
        LocationPermission.deniedForever,
      ]) {
        calls = <String>[];
        final subscription = serviceWith(
          permission,
        ).positionUpdates().listen((_) {}, onError: (Object _) {});
        await pumpEventQueue();

        expect(calls, <String>['check'], reason: permission.name);

        await subscription.cancel();
      }
    });
  });

  group('Die Umrechnung aus dem Paket', () {
    test('Breite, Länge und Genauigkeit landen an ihrem Platz', () {
      // Drei Zahlen, die sich nicht ähneln: vertauschte Felder fallen damit
      // auf. Gleiche Werte prüften nichts.
      final position = Position(
        latitude: 48.1351,
        longitude: 11.582,
        timestamp: DateTime.utc(2026, 8, 29),
        accuracy: 7.5,
        altitude: 519,
        altitudeAccuracy: 3,
        heading: 90,
        headingAccuracy: 5,
        speed: 1.4,
        speedAccuracy: 0.5,
      );

      final converted = devicePositionOf(position);

      expect(converted.latitude, 48.1351);
      expect(converted.longitude, 11.582);
      expect(converted.accuracyInMeters, 7.5);
    });
  });
}
