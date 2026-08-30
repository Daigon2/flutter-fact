/// Was der Startpunkt-Picker aus der Umgebung braucht: die Position des
/// Nutzers.
///
/// ## Warum das nicht `userLocationProvider` ist
///
/// Den gibt es schon, in
/// `features/discovery/presentation/notifiers/user_location_providers.dart`,
/// und er ist für dieses Feature **unerreichbar**: Regel 8 verbietet jedem
/// Feature den Import aus dem `presentation` eines anderen. Der Weg, der offen
/// steht, ist derselbe, den `discovery` selbst geht: `locationServiceProvider`
/// aus `lib/services/location/` lesen. Das ist mit D-14 ausdrücklich
/// bestätigt und heute an vier Stellen der Bestand.
///
/// ## Die Schwelle wiederholt sich nicht, die Anmeldung am Strom schon
///
/// Die 35 Meter aus `screen-map.jsx:2744` stehen **einmal** im Projekt, in
/// [isAccurateEnough]; dieser Provider ruft dieselbe Funktion wie
/// `UserLocationNotifier`. Was sich wiederholt, ist das Abonnement:
/// `LocationService.positionUpdates()` liefert bei jedem Aufruf einen neuen
/// Strom, und solange der Picker offen ist, laufen zwei Ortungsströme.
///
/// **Deshalb `autoDispose`.** `StreamProvider` ist in `riverpod 3.4.2`
/// standardmäßig `isAutoDispose = false`
/// (`riverpod-3.4.2/lib/src/providers/stream_provider.dart:96`), ein einmal
/// gelesener Strom liefe also bis zum Ende der Sitzung weiter, auch nachdem
/// der Picker längst zu ist. `StreamProvider.autoDispose` ist in dieser
/// Fassung ein Builder und liefert wieder einen `StreamProvider`, nur mit
/// `isAutoDispose: true` (`riverpod-3.4.2/lib/src/builder.dart:591-608`);
/// deshalb steht am Feld kein eigener Typ. Der Strom endet, sobald ihn
/// niemand mehr ansieht.
///
/// Der Vertrag des Dienstes nennt den Auslöser für den nächsten Schritt selbst
/// („der zweite Verbraucher", `location_service.dart`): der gemeinsame Filter
/// gehört dann zwischen Dienst und Verbraucher, und
/// `UserLocationNotifier` zieht mit um. Das ist eine Änderung an `discovery`
/// und gehört nicht in einen Schritt, der `challenges` baut; hier steht sie
/// als benannte offene Kante.
library;

import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Position des Nutzers, so wie der Startpunkt-Picker sie braucht.
///
/// `AsyncLoading`, solange keine genaue Ortung da ist. Der Picker behandelt
/// das wie die Quelle: ohne Position entfällt „Hier wo ich bin", und die
/// Hotspots stehen unsortiert in Dateireihenfolge
/// (`screen-challenge.jsx:3012`).
///
/// Ein Fehler auf dem Strom kommt als `AsyncError` heraus und wird vom Picker
/// wie „keine Position" behandelt. Anders als beim Kartenbildschirm gibt es
/// hier nichts zu bewahren: es gibt keine vorherige Ortung, die stehen bleiben
/// könnte.
final StreamProvider<MapPosition> huntUserPositionProvider =
    StreamProvider.autoDispose<MapPosition>(
      (Ref ref) => ref
          .watch(locationServiceProvider)
          .positionUpdates()
          .where(isAccurateEnough)
          .map(
            (DevicePosition position) => MapPosition(
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          ),
    );
