import 'dart:async';

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Standortzustand des Kartenbildschirms.
///
/// Hier steht die eine Entscheidung, die der Zustand selbst trifft: ist eine
/// Ortung genau genug. Alles Weitere prüft `pages/map_page_test.dart`.
void main() {
  late FakeLocationService service;
  late RecordingDiagnosticSink diagnostics;

  setUp(() {
    service = FakeLocationService();
    diagnostics = RecordingDiagnosticSink();
  });

  tearDown(() async {
    await service.close();
  });

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(service),
        diagnosticSinkProvider.overrideWithValue(diagnostics),
      ],
    );
    // Ohne das bleibt das Abonnement auf dem Ortungsstrom offen.
    addTearDown(container.dispose);
    return container;
  }

  DevicePosition fix({
    double latitude = 48.1351,
    double longitude = 11.582,
    double accuracy = 8,
  }) => DevicePosition(
    latitude: latitude,
    longitude: longitude,
    accuracyInMeters: accuracy,
  );

  test('der Standard ist der untätige Dienst', () {
    // Ohne Override liefert nichts eine Position: `flutter test` hat keinen
    // Plattformkanal, und ein echter `geolocator` scheiterte hier mit einer
    // `MissingPluginException`.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(locationServiceProvider),
      same(unavailableLocationService),
    );
    expect(container.read(userLocationProvider).fix, isNull);
  });

  test('vor der ersten Ortung ist der Zustand leer', () {
    final container = newContainer();

    expect(container.read(userLocationProvider).fix, isNull);
    expect(container.read(userLocationProvider).acceptedFixes, 0);
    expect(
      service.subscriptions,
      1,
      reason: 'der Strom wird beim Aufbau des Zustands abonniert',
    );
  });

  group('Der 35-Meter-Filter, screen-map.jsx:2744', () {
    test('genau 35 Meter kommen durch', () async {
      final container = newContainer();
      container.read(userLocationProvider);

      service.emit(fix(accuracy: 35));
      await pumpEventQueue();

      expect(container.read(userLocationProvider).fix, fix(accuracy: 35));
      expect(container.read(userLocationProvider).acceptedFixes, 1);
    });

    test('35,000001 Meter kommen nicht durch', () async {
      final container = newContainer();
      container.read(userLocationProvider);

      service.emit(fix(accuracy: 35.000001));
      await pumpEventQueue();

      expect(container.read(userLocationProvider).fix, isNull);
      expect(
        container.read(userLocationProvider).acceptedFixes,
        0,
        reason: 'eine verworfene Ortung zählt nicht mit',
      );
    });

    test('eine grobe Ortung überschreibt eine gute nicht', () async {
      // Der eigentliche Zweck des Filters: die Aufwärmfolge Funkzelle, WLAN,
      // GPS liefert grobe und gute Ortungen durcheinander. Fiele die gute
      // danach wieder heraus, sprünge die Karte, und genau das verhindert der
      // Kommentar der Quelle bei `:2740-2741`.
      final container = newContainer();
      container.read(userLocationProvider);

      service.emit(fix(accuracy: 5));
      service.emit(fix(latitude: 48.2, longitude: 11.7, accuracy: 1200));
      await pumpEventQueue();

      expect(container.read(userLocationProvider).fix, fix(accuracy: 5));
      expect(container.read(userLocationProvider).acceptedFixes, 1);
    });
  });

  test('die zweite Ortung ersetzt die erste und zählt weiter', () async {
    final container = newContainer();
    container.read(userLocationProvider);

    service.emit(fix());
    service.emit(fix(latitude: 48.2));
    await pumpEventQueue();

    expect(container.read(userLocationProvider).fix, fix(latitude: 48.2));
    expect(container.read(userLocationProvider).acceptedFixes, 2);
  });

  test('zwei Ortungen an derselben Stelle sind zwei Ereignisse', () async {
    // **Der Grund, warum `UserLocationState` keine Wertgleichheit hat.**
    // Riverpod benachrichtigt nur bei `previous != next`; mit einem `==` über
    // die Felder verschwände die zweite Ortung lautlos, und mit ihr der Anlass,
    // die Kamera nachzuziehen. Wer stehen bleibt, bekommt genau diesen Fall
    // fünfmal in der Sekunde.
    final container = newContainer();
    final states = <UserLocationState>[];
    container.listen(
      userLocationProvider,
      (previous, next) => states.add(next),
      fireImmediately: false,
    );

    service.emit(fix());
    service.emit(fix());
    await pumpEventQueue();

    expect(states, hasLength(2));
    expect(container.read(userLocationProvider).acceptedFixes, 2);
  });

  group('Ein Fehler auf dem Strom', () {
    test('meldet den Typnamen und keine Koordinaten', () async {
      final container = newContainer();
      container.read(userLocationProvider);

      service.emitError(const FormatException('geheim: 48.1351, 11.582'));
      await pumpEventQueue();

      expect(diagnostics.events, hasLength(1));
      final event = diagnostics.events.single;
      expect(event.name, UserLocationNotifier.streamErrorEvent);
      expect(event.attributes['type'], 'FormatException');
      expect(
        event.attributes.values.join(' '),
        isNot(contains('48.1351')),
        reason:
            'die Meldung des Vendors kann Koordinaten tragen, und '
            'security.md §6 verbietet sie im Log',
      );
    });

    test('nimmt die letzte Ortung nicht zurück', () async {
      final container = newContainer();
      container.read(userLocationProvider);

      service.emit(fix());
      service.emitError(StateError('kein Empfang'));
      await pumpEventQueue();

      expect(container.read(userLocationProvider).fix, fix());
    });

    test('beendet den Strom nicht', () async {
      // `listen` ohne `cancelOnError` lässt das Abonnement stehen. Die Quelle
      // hält es genauso: ihr Fehlerzweig (`:2747`) blendet nur die Suchanzeige
      // aus, `watchPosition` sucht weiter.
      final container = newContainer();
      container.read(userLocationProvider);

      service.emitError(StateError('kurz weg'));
      service.emit(fix());
      await pumpEventQueue();

      expect(container.read(userLocationProvider).fix, fix());
    });
  });

  test('das Entsorgen beendet das Abonnement', () async {
    final container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(service)],
    );
    container.read(userLocationProvider);
    await pumpEventQueue();
    expect(service.hasListener, isTrue);

    container.dispose();
    await pumpEventQueue();

    expect(
      service.hasListener,
      isFalse,
      reason: 'sonst liefe der Ortungsdienst nach dem Bildschirm weiter',
    );
  });
}

/// Ein Ortungsdienst, dessen Ausgaben der Test selbst setzt.
class FakeLocationService implements LocationService {
  /// **`broadcast` und nicht der einfache Regler**, und das ist keine
  /// Kosmetik: `StreamController.close()` eines einfachen Reglers, dem nie
  /// jemand zugehört hat, wird **nie erfüllt**. Ein `await` darauf im
  /// `tearDown` lässt jeden Test hängen, der diesen Dienst gar nicht benutzt.
  final StreamController<DevicePosition> _controller =
      StreamController<DevicePosition>.broadcast();

  /// Wie oft [positionUpdates] gerufen wurde.
  int subscriptions = 0;

  /// Ob jemand zuhört.
  bool get hasListener => _controller.hasListener;

  @override
  Stream<DevicePosition> positionUpdates() {
    subscriptions++;
    return _controller.stream;
  }

  /// Schiebt eine Ortung in den Strom.
  void emit(DevicePosition position) => _controller.add(position);

  /// Schiebt einen Fehler in den Strom.
  void emitError(Object error) => _controller.addError(error);

  /// Schließt den Strom.
  Future<void> close() => _controller.close();
}

/// Sammelt die Diagnose-Ereignisse dieses Tests.
class RecordingDiagnosticSink implements DiagnosticSink {
  /// Alles, was gemeldet wurde, in der Reihenfolge des Eingangs.
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void report(DiagnosticEvent event) => events.add(event);
}
