/// Die Fassung des Ortungsdienstes, die wirklich mit `geolocator` spricht.
///
/// Der einzige Ort in `lib/`, an dem `package:geolocator` vorkommt. Dass das so
/// bleibt, sichert heute **keine** Regel des Prüfskripts ab: Regel 20 gilt
/// wörtlich nur für `package:maplibre_gl`, und die Domänen-Sperre („Regel 4:
/// Domain darf keine Geräte-SDK importieren") greift nur in einer Domäne. Ein
/// Import in `features/*/presentation/` liefe durch. Gemessen mit einer
/// Wegwerf-Probe am 29.08.2026, siehe den Bericht zu Schritt 13.
library;

import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Liest die Position über `geolocator`.
class GeolocatorLocationService implements LocationService {
  /// Erzeugt den Dienst. Er startet nichts, bis jemand zuhört.
  ///
  /// ## Warum die beiden Berechtigungsschritte hereingereicht werden
  ///
  /// **`Geolocator` ist statisch, und damit wäre der einzige Zweig dieser
  /// Datei ohne Gerät unprüfbar.** Nachgemessen am 29.08.2026: das ganze
  /// `await _ensurePermission();` aus [positionUpdates] zu löschen, ließ alle
  /// 1177 Tests grün. Auf dem Gerät wäre die Folge kein Fehler, sondern
  /// Stille: der Strom liefert ohne Freigabe nur einen
  /// `PermissionDeniedException`, und die Karte stünde für immer auf der
  /// Rückfallstadt.
  ///
  /// Dieselbe Naht wie die Uhr `now` im Karten-Host und der `MapCameraDriver`
  /// unter ihm: ein Standard, der in der App gilt, und ein Parameter, den nur
  /// ein Test setzt. `@visibleForTesting` steht am **Parameter** und nicht am
  /// Feld, weil es an einem Feld nur das Lesen bewacht: ein Konstruktoraufruf
  /// aus `lib/` liefe sonst anstandslos durch, gemessen in Schritt 12.
  const GeolocatorLocationService({
    @visibleForTesting
    Future<LocationPermission> Function() checkPermission =
        Geolocator.checkPermission,
    @visibleForTesting
    Future<LocationPermission> Function() requestPermission =
        Geolocator.requestPermission,
  }) : _checkPermission = checkPermission,
       _requestPermission = requestPermission;

  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;

  /// Wie der Strom eingestellt wird.
  ///
  /// Drei Dinge der Quelle sind Parität und keine Beliebigkeit, jedes mit
  /// Begründung im Quellkommentar `screen-map.jsx:2738-2741`:
  ///
  /// * **Höchste Genauigkeit.** `enableHighAccuracy: true` (`:2748`) entspricht
  ///   [LocationAccuracy.best], dem Standard des Pakets. Ausgeschrieben und
  ///   nicht weggelassen, weil ein Standard, auf den man sich verlässt, beim
  ///   nächsten Paketwechsel still ein anderer sein kann.
  /// * **Kein Streckenfilter.** [LocationSettings.distanceFilter] bleibt `0`,
  ///   also „melde jede Bewegung". **Ausdrücklich nicht 12**: die Quelle setzt
  ///   an ihrer Ortungsquelle überhaupt keinen Filter, und die 12 Meter sind
  ///   die Totzone der **Kamera** (`:2668`, nachgebaut in
  ///   `MapCameraThresholds.followDeadZoneMeters`). Wer sie hier noch einmal
  ///   einträgt, lässt dieselbe Schwelle zweimal wirken und verliert dabei
  ///   jede Ortung, die der Audio-Beacon und das Geofencing später brauchen.
  /// * **Kein Zeitlimit.** Siehe unten.
  ///
  /// ## Was in der Quelle steht und hier fehlt
  ///
  /// **`timeout: 10000` (`:2748`) hat kein Gegenstück.**
  /// [LocationSettings.timeLimit] wirft laut eigener Doku eine
  /// `TimeoutException` auf den Strom, und ein Fehler beendet den Strom des
  /// Pakets. Die Quelle ruft dagegen nur ihren Fehlerzweig (`:2747`), der die
  /// Suchanzeige ausblendet, und `watchPosition` **sucht weiter**. Ein
  /// `timeLimit` wäre also nicht dieselbe Regel, sondern die härtere: die App
  /// gäbe die Ortung nach zehn Sekunden endgültig auf. Deshalb steht hier
  /// keines. Was dadurch fehlt, ist allein die Rückmeldung „ich suche noch",
  /// und die hat in Schritt 13 ohnehin keinen Empfänger; sie gehört zum
  /// Nutzermarker (`gpsSearching`, Schritt 16).
  ///
  /// **`maximumAge: 0` (`:2748`) braucht kein Gegenstück.** Der Strom des
  /// Pakets liefert ausschließlich frische Ortungen; einen zwischengespeicherten
  /// Wert gäbe es nur über `getLastKnownPosition`, und das ruft hier niemand.
  ///
  /// Bewusst kein `AndroidSettings` und kein `AppleSettings`: die Quelle setzt
  /// genau drei Optionen, und keine davon ist plattformabhängig. Eine
  /// plattformspezifische Einstellung wäre eine Entscheidung ohne Fundstelle.
  ///
  /// `@visibleForTesting`, damit ein Test die drei Werte festnageln kann, ohne
  /// ein Gerät zu brauchen. Der Zugriff aus `lib/` bleibt auf diese Datei
  /// beschränkt, alles andere bricht `dart analyze` ab.
  @visibleForTesting
  static const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );

  /// Öffnet den Ortungsstrom, nachdem die Berechtigung geklärt ist.
  ///
  /// ## Warum die Berechtigung hier erfragt wird
  ///
  /// Im Browser fragt `watchPosition` selbst, sichtbar als Dialog. Auf Android
  /// und iOS ist das ein eigener Schritt, und ohne ihn liefert der Strom nur
  /// einen `PermissionDeniedException`. Erfragt wird ausschließlich der
  /// **Vordergrund** (`ACCESS_FINE_LOCATION` und `ACCESS_COARSE_LOCATION` im
  /// Manifest, `NSLocationWhenInUseUsageDescription` in der `Info.plist`),
  /// bewusst kein Hintergrundzugriff.
  ///
  /// **Der Fehlerfall bleibt ein Fehler auf dem Strom** und wird nicht in „nie
  /// eine Position" übersetzt. Wer die Berechtigung verweigert, soll das später
  /// angezeigt bekommen können; ein Strom, der einfach schweigt, wäre von einem
  /// Gerät ohne Empfang nicht unterscheidbar. Der Typ dieses Fehlers ist
  /// **kein Vertrag**: [LocationService] sagt nur zu, dass Fehler zugestellt
  /// werden, und der einzige heutige Empfänger meldet den Typnamen an die
  /// Diagnose, ohne ihn zu prüfen.
  @override
  Stream<DevicePosition> positionUpdates() async* {
    await _ensurePermission();
    yield* Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).map(devicePositionOf);
  }

  /// Fragt die Freigabe genau dann, wenn sie noch offen ist.
  ///
  /// **Nur bei [LocationPermission.denied], und `deniedForever` gehört
  /// ausdrücklich nicht dazu.** Nach der dauerhaften Ablehnung öffnet iOS
  /// keinen Dialog mehr, und `geolocator` gibt die Ablehnung sofort zurück;
  /// ein Fragen auf Verdacht wäre ein Aufruf, der nie etwas ändert. Wer schon
  /// zugestimmt hat, wird nicht noch einmal gefragt.
  Future<void> _ensurePermission() async {
    final LocationPermission current = await _checkPermission();
    if (current == LocationPermission.denied) {
      await _requestPermission();
    }
  }
}

/// Der Weg vom Paket in den eigenen Typ.
///
/// Eigene Funktion und keine private Zeile im Dienst, aus demselben Grund wie
/// bei `mapCameraViewOf` in `map/presentation/map_surface.dart`: der Weg
/// hierdurch läuft ohne Plattformkanal nie, ein vertauschtes Paar
/// `latitude`/`longitude` käme also durch jede Suite und fiele erst am Gerät
/// auf, als Karte, die nach Somalia fliegt.
@visibleForTesting
DevicePosition devicePositionOf(Position position) => DevicePosition(
  latitude: position.latitude,
  longitude: position.longitude,
  accuracyInMeters: position.accuracy,
);
