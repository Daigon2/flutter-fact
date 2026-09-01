/// Der Vertrag des Orientierungsdienstes: die Blickrichtung des Geräts, roh
/// und ungeglättet.
///
/// ## Warum das in `services/` liegt und nicht in einem Feature
///
/// `docs/architecture/domain-map.md:171-182` zählt unterstützende technische
/// Fähigkeiten auf, die keine eigene Geschäftsdomäne sind, darunter den
/// `geolocation provider`, in derselben Aufzählung wie `map rendering`. Ein
/// Kompasssensor ist dieselbe Art Fähigkeit wie die dort genannten: eine
/// Gerätefunktion ohne eigene Fachlichkeit. Er steht nicht wörtlich in der
/// Liste, aus demselben Grund, aus dem `shared_preferences` es vor dem
/// 31.08.2026 nicht tat, siehe `shared_preferences_key_value_store.dart`: die
/// Liste nennt, was das Projekt zum jeweiligen Zeitpunkt schon gebraucht hat,
/// kein Paket im Voraus. Der Ort ist deshalb derselbe wie beim Ortungsdienst,
/// `lib/services/location/`, und aus derselben Erwägung: kein Widget, kein
/// Zustand, den man ansehen könnte, siehe `lib/features/README.md`, „Vendor-
/// Adapter ohne Oberfläche".
///
/// ## Was dieser Dienst ausdrücklich nicht tut: glätten
///
/// [OrientationService.headingUpdates] liefert jede Blickrichtung, die der
/// Kompass meldet, roh und ungefiltert. Die Glättung, mit der die Karte einer
/// zappelnden Blickrichtung folgt, ist Kartenverhalten und steht in
/// `lib/map/domain/bearing_smoothing.dart`, nicht hier.
///
/// Der Grund ist derselbe wie bei `locationAccuracyLimitInMeters` in
/// `location_service.dart`: eine Glättung im Vendor-Adapter liefe nur auf
/// einem Gerät mit echtem Sensor, und eine Rechnung, die kein Test ohne
/// Plattformkanal erreicht, ist beim nächsten Umbau weg, ohne dass es jemand
/// bemerkt. `bearing_smoothing.dart` ist reines Dart und ohne Gerät prüfbar;
/// dorthin gehört die Glättung, damit sie eine Regel bleibt und keine
/// Behauptung.
library;

import 'package:fact_app/services/orientation/device_heading.dart';

/// Woher die App die Blickrichtung des Geräts bekommt.
///
/// `abstract interface class`: ein versehentliches `extends` geht damit nicht
/// durch, und jeder Doppelgänger im Test schreibt sichtbar
/// `implements OrientationService`. Dasselbe Muster wie [LocationService] in
/// `location_service.dart`.
abstract interface class OrientationService {
  /// Jede Blickrichtung des Geräts, ungefiltert und ungeglättet.
  ///
  /// Ein Fehler wird als Fehlerereignis zugestellt und beendet den Strom nicht
  /// von sich aus, dieselbe Zusicherung wie bei
  /// `LocationService.positionUpdates`.
  Stream<DeviceHeading> headingUpdates();
}

/// Der untätige Standard: ein Strom, der nie etwas liefert.
///
/// Dasselbe Muster wie `unavailableLocationService` in `location_service.dart`
/// und aus demselben Grund: der Standard eines Providers muss ohne
/// Plattformkanal auskommen, sonst fällt jeder Widget-Test über eine
/// `MissingPluginException`.
const OrientationService unavailableOrientationService =
    _UnavailableOrientationService();

final class _UnavailableOrientationService implements OrientationService {
  const _UnavailableOrientationService();

  /// Ein leerer Strom, der sofort endet.
  ///
  /// **Nicht ein Strom, der ewig offen bleibt.** Ein Abonnent sähe zwischen
  /// beidem keinen Unterschied, aber ein offener Strom hielte in jedem Test
  /// eine Zeitüberschreitung offen, die niemand sucht. Dieselbe Begründung wie
  /// bei `_UnavailableLocationService.positionUpdates`.
  @override
  Stream<DeviceHeading> headingUpdates() => const Stream<DeviceHeading>.empty();
}
