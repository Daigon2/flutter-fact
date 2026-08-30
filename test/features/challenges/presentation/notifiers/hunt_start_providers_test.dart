import 'dart:async';

import 'package:fact_app/features/challenges/presentation/notifiers/hunt_start_providers.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `huntUserPositionProvider` muss `autoDispose` tragen, siehe Kopf des
/// Providers.
///
/// ## Was ohne diese Datei unentdeckt bliebe
///
/// Der Startpunkt-Picker abonniert mit diesem Provider einen **zweiten**
/// Ortungsstrom, neben dem des Kartenbildschirms. Ohne `autoDispose` läuft
/// dieser zweite Strom bis zum Ende der Sitzung weiter, auch nachdem der
/// Picker längst geschlossen ist, ohne sichtbares Verhalten und ohne
/// scheiternden Test: `flutter test` prüft sonst nirgends nach, ob ein
/// Provider seinen Strom wieder loslässt.
void main() {
  test('ohne Zuhörer schließt der Provider den zugrundeliegenden Ortungsstrom '
      'wieder', () async {
    final _CountingLocationService service = _CountingLocationService();
    addTearDown(service.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final ProviderSubscription<AsyncValue<Object?>> subscription = container
        .listen(huntUserPositionProvider, (previous, next) {});
    await pumpEventQueue();

    expect(service.opened, 1, reason: 'der Strom wird beim Lesen abonniert');
    expect(
      service.closed,
      0,
      reason: 'solange jemand zusieht, bleibt der Strom offen',
    );

    subscription.close();
    // `autoDispose` entsorgt den Provider erst im nächsten Mikrotask-Umlauf,
    // nicht synchron beim `close()` des letzten Zuhörers.
    await pumpEventQueue();

    expect(
      service.closed,
      1,
      reason:
          'ohne `autoDispose` liefe der zweite Ortungsstrom bis Sitzungsende '
          'weiter',
    );
  });
}

/// Ein Ortungsdienst, der zählt, wie oft sein Strom geöffnet und wie oft er
/// wieder geschlossen wurde.
///
/// Die Zähler hängen an `onListen` und `onCancel` des zurückgegebenen Stroms
/// selbst, nicht an [positionUpdates]: `.where` und `.map` im Provider geben
/// ein Abbrechen unverändert an die Quelle weiter, und genau das wird hier
/// geprüft.
class _CountingLocationService implements LocationService {
  int opened = 0;
  int closed = 0;

  /// Als Feld und nicht als lokale Variable in [positionUpdates]: sonst meldet
  /// der Analyzer `close_sinks`, weil er `close()` nur innerhalb derselben
  /// Funktion sucht. [close] schließt ihn, für den Fall, dass `autoDispose`
  /// selbst einmal nicht greift.
  late final StreamController<DevicePosition> _controller =
      StreamController<DevicePosition>(
        onListen: () => opened++,
        onCancel: () => closed++,
      );

  @override
  Stream<DevicePosition> positionUpdates() => _controller.stream;

  Future<void> close() => _controller.close();
}
