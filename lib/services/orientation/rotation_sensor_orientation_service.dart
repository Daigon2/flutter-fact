/// Die Fassung des Orientierungsdienstes, die wirklich mit
/// `flutter_rotation_sensor` spricht.
///
/// `package:flutter_rotation_sensor` kommt in `lib/` nur unterhalb von
/// `lib/services/orientation/` vor, und Regel 24 des Prüfskripts sichert diesen
/// Zustand maschinell ab, samt der transitiven Abhängigkeit
/// `native_device_orientation` (`pubspec.lock`, Version 2.1.1), in der der
/// naheliegendste Umweg läge: das Paket bringt eine eigene
/// Gerätestellungs-API mit, und wer am Adapter vorbeigreift, landet mit hoher
/// Wahrscheinlichkeit dort. Genau dieselbe Erwägung wie bei
/// `geolocator_platform_interface` in `geolocator_location_service.dart`.
///
/// Was die Regel nicht leistet, und das ist das Wichtigere: sie prüft den
/// **Import**, nicht den Inhalt. Wohin eine Blickrichtung fließen darf, bleibt
/// Sache der Review.
library;

import 'dart:math' as math;

import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/services/orientation/device_heading.dart';
import 'package:fact_app/services/orientation/orientation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';

/// Liest die Blickrichtung über `flutter_rotation_sensor`.
class RotationSensorOrientationService implements OrientationService {
  /// Erzeugt den Dienst. [sink] nimmt jeden verworfenen Azimut auf, siehe
  /// [headingDiscardedEvent].
  const RotationSensorOrientationService({
    this.sink = const SilentDiagnosticSink(),
  });

  final DiagnosticSink sink;

  /// Name des Diagnoseereignisses für einen verworfenen Azimut.
  ///
  /// Als Konstante an der Klasse, damit ein Test ihn nicht ein zweites Mal
  /// abtippt und dabei versehentlich von der Zeichenkette abweicht, mit der
  /// dieser Dienst tatsächlich meldet.
  static const String headingDiscardedEvent = 'orientation.heading_discarded';

  /// Öffnet den Blickrichtungsstrom.
  ///
  /// ## Wie der Bezugsrahmen eingestellt wird
  ///
  /// `RotationSensor.referenceFrame` steht bereits auf
  /// `ReferenceFrame.magneticNorth`, dem Standard des Pakets: der
  /// Android-Pfad der Quelle liest `deviceorientationabsolute`, und das ist
  /// magnetometerbasiert, keine wahre Peilung. Trotzdem steht die Zuweisung
  /// hier **ausdrücklich**, statt sich auf den Standard zu verlassen. Ein
  /// künftiger Paketwechsel, der den Standard stillschweigend auf
  /// `ReferenceFrame.trueNorth` oder `ReferenceFrame.arbitrary` verschiebt,
  /// würde sonst lautlos die Richtung drehen, in der jede spätere Blickrichtung
  /// gemessen wird, und niemand sähe es an dieser Stelle.
  ///
  /// Die Zuweisung steht im Rumpf einer `async*`-Methode und läuft deshalb
  /// erst beim ersten Abonnenten, nicht beim Aufruf von [headingUpdates]
  /// selbst. Dieselbe Verzögerung wie bei
  /// `GeolocatorLocationService.positionUpdates` und aus demselben Grund: der
  /// Dienst startet nichts, bis jemand zuhört.
  ///
  /// ## Verworfene Azimute
  ///
  /// Jedes `OrientationEvent` wird über [deviceHeadingOf] in ein
  /// `DeviceHeading` übersetzt. Liefert das `null` (siehe
  /// `DeviceHeading.tryFrom`: nur bei `NaN` oder einer Unendlichkeit, was bei
  /// einem entarteten Quaternion des Sensors vorkommen kann, siehe
  /// `rotation_sensor_orientation_service_test.dart`), wird das Ereignis
  /// **übersprungen und nicht als Fehler behandelt**: ein einzelner
  /// unbrauchbarer Messwert ist kein Grund, den ganzen Strom zu beenden. Es
  /// geht als [headingDiscardedEvent] an [sink].
  ///
  /// ## Fehler des Sensors
  ///
  /// `yield*` reicht den Strom des Pakets unverändert durch. Ein Fehler des
  /// Plattformkanals kommt deshalb als Fehlerereignis bei einem Abonnenten
  /// an, **ohne** dass diese Methode ihn abfängt und ohne dass er den Strom
  /// beendet, dieselbe Zusicherung wie bei
  /// `GeolocatorLocationService.positionUpdates`. Ein `await for` an dieser
  /// Stelle wäre die falsche Wahl gewesen: es hätte den ersten Fehler des
  /// Quellstroms als Ausnahme der eigenen `async*`-Funktion behandelt, und
  /// eine geworfene Ausnahme beendet den erzeugten Strom, genau das
  /// Gegenteil der Zusicherung.
  @override
  Stream<DeviceHeading> headingUpdates() async* {
    RotationSensor.referenceFrame = ReferenceFrame.magneticNorth;
    yield* RotationSensor.orientationStream.expand(_headingOrReportDiscard);
  }

  /// Übersetzt [event] in eine [DeviceHeading] oder meldet den Verwurf.
  ///
  /// Über `Stream.expand`: eine leere `Iterable` liefert kein Element, ohne
  /// den Strom als Fehler oder Ende zu markieren, genau das Verhalten, das
  /// ein „überspringen" braucht.
  Iterable<DeviceHeading> _headingOrReportDiscard(OrientationEvent event) {
    final DeviceHeading? heading = deviceHeadingOf(event);
    if (heading == null) {
      sink.report(DiagnosticEvent(headingDiscardedEvent));
      return const Iterable<DeviceHeading>.empty();
    }
    return <DeviceHeading>[heading];
  }
}

/// Der Weg vom Paket in den eigenen Typ.
///
/// Eigene Funktion und keine private Zeile im Dienst, aus demselben Grund wie
/// bei `devicePositionOf` in `geolocator_location_service.dart`: der Weg
/// hierdurch läuft ohne Plattformkanal nie im echten Betrieb, aber
/// `OrientationEvent` hat einen offenen Konstruktor ohne Plattformbindung, und
/// diese Funktion ist deshalb ohne Gerät prüfbar, siehe die Testdatei.
///
/// `eulerAngles.azimuth` liegt laut eigener Doku des Pakets in Radiant, im
/// Bereich `[0, 2π)`, mit 0 bei Blick nach Norden und π/2 bei Blick nach
/// Osten, also im selben Drehsinn wie eine Gradzahl im Kompasssinn. Die
/// Umrechnung ist deshalb eine reine Skalierung, keine Drehung.
@visibleForTesting
DeviceHeading? deviceHeadingOf(OrientationEvent event) =>
    DeviceHeading.tryFrom(event.eulerAngles.azimuth * 180 / math.pi);
