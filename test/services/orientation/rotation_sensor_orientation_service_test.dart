import 'dart:math' as math;

import 'package:fact_app/services/orientation/device_heading.dart';
import 'package:fact_app/services/orientation/rotation_sensor_orientation_service.dart';
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';
import 'package:flutter_test/flutter_test.dart';

/// `deviceHeadingOf`, die Umrechnung eines `OrientationEvent` in eine
/// [DeviceHeading], und die Konstante des Diagnoseereignisses.
///
/// ## Was hier ausdrücklich ungeprüft bleibt, und warum
///
/// `RotationSensorOrientationService.headingUpdates` selbst kommt in dieser
/// Datei nicht vor. `RotationSensor` aus `flutter_rotation_sensor` ist ein
/// `@sealed` versiegelter Typ, dessen sämtliche Mitglieder statisch sind, ganz
/// ohne Konstruktor: anders als bei `GeolocatorLocationService`, wo die beiden
/// Berechtigungsschritte als Funktionsparameter hereingereicht und damit in
/// einem Test ersetzt werden können, gibt es hier keine vergleichbare Naht.
/// Sowohl das Lesen von `RotationSensor.orientationStream` als auch das
/// Setzen von `RotationSensor.referenceFrame` rufen unmittelbar einen
/// `MethodChannel` beziehungsweise ein `EventChannel` der Plattform auf, siehe
/// `RotationSensorMethodChannel` im Paket. Ein Test ohne Gerät und ohne
/// Plattformkanal-Mock kann deshalb weder beobachten, dass der Bezugsrahmen
/// wirklich auf `ReferenceFrame.magneticNorth` gesetzt wird, noch dass ein
/// Fehler des Kanals als Fehlerereignis ankommt und den Strom nicht beendet,
/// noch dass ein verworfener Azimut tatsächlich als
/// `RotationSensorOrientationService.headingDiscardedEvent` bei der
/// `DiagnosticSink` ankommt, wenn er aus einem echten Abonnement stammt. Ein
/// Test, der stattdessen nur `_headingOrReportDiscard` isoliert von der
/// Methode aufriefe, prüfte nur sich selbst und keine echte Verdrahtung, und
/// genau das ist die Art Test, die hier ausdrücklich nicht erfunden wird.
///
/// Geprüft wird stattdessen [deviceHeadingOf], die reine Übersetzung eines
/// `OrientationEvent` in eine [DeviceHeading]. `OrientationEvent` und
/// `Quaternion` haben offene Konstruktoren ohne Plattformbindung, und die
/// Rechnung von Quaternion zu Eulerwinkel ist reine Mathematik im Paket
/// selbst; sie ist deshalb ohne Gerät und ohne Plattformkanal-Mock erreichbar.
void main() {
  test('Blick nach Norden ergibt 0 Grad', () {
    // Die Ausgangslage des Pakets: die Identität als Quaternion entspricht
    // keiner Drehung, und Norden ist per Definition 0.
    final event = OrientationEvent(
      quaternion: Quaternion.identity(),
      accuracy: -1,
      timestamp: 0,
    );

    expect(deviceHeadingOf(event), DeviceHeading.tryFrom(0));
  });

  test('Blick nach Osten ergibt ungefähr 90 Grad', () {
    // Über den Umweg des Pakets selbst gebaut: Eulerwinkel zu Rotationsmatrix
    // zu Quaternion ist derselbe Weg, den ein echtes `OrientationEvent`
    // rückwärts durchläuft. Die Toleranz trägt der Float32-Speicherung der
    // Matrix- und Quaternion-Klassen Rechnung, siehe `Matrix3` und
    // `Quaternion` im Paket, beide auf `Float32List` gestützt.
    final matrix = EulerAngles(math.pi / 2, 0, 0).toRotationMatrix();
    final event = OrientationEvent(
      quaternion: matrix.toQuaternion(),
      accuracy: -1,
      timestamp: 0,
    );

    expect(deviceHeadingOf(event)!.degrees, closeTo(90, 0.001));
  });

  test('Blick nach Westen ergibt ungefähr 270 Grad', () {
    final matrix = EulerAngles(3 * math.pi / 2, 0, 0).toRotationMatrix();
    final event = OrientationEvent(
      quaternion: matrix.toQuaternion(),
      accuracy: -1,
      timestamp: 0,
    );

    expect(deviceHeadingOf(event)!.degrees, closeTo(270, 0.001));
  });

  test('ein entartetes Quaternion wird verworfen statt einer Ausnahme', () {
    // Ein Quaternion mit einer nicht-endlichen Komponente ist kein
    // konstruierter Fall: er entsteht, wenn der Sensor selbst einen
    // unbrauchbaren Messwert liefert. Die Rechnung des Pakets bricht dabei
    // nicht ab, sondern trägt die `NaN` bis zum Azimut weiter, siehe
    // `Matrix3.toRotationMatrix` und `Matrix3.toEulerAngles`. Genau dieser
    // Fall ist der Grund, warum `deviceHeadingOf` `null` zurückgeben können
    // muss, statt sich auf einen stets gültigen Azimuten zu verlassen.
    final event = OrientationEvent(
      quaternion: Quaternion(double.nan, 0, 0, 1),
      accuracy: -1,
      timestamp: 0,
    );

    expect(deviceHeadingOf(event), isNull);
  });

  test('das Diagnoseereignis heißt orientation.heading_discarded', () {
    expect(
      RotationSensorOrientationService.headingDiscardedEvent,
      'orientation.heading_discarded',
    );
  });
}
