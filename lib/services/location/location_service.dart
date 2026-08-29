/// Der Vertrag des Ortungsdienstes und die eine Schwelle, gegen die jede
/// Ortung geprüft wird.
///
/// ## Warum das in `services/` liegt und nicht in einem Feature
///
/// `docs/architecture/domain-map.md:153-156` führt den `geolocation provider`
/// ausdrücklich unter „The following are **not** business domains", in
/// derselben Liste wie `map rendering`. Genau dieser Absatz hält fest, dass aus
/// `map rendering` am 28.08.2026 `lib/map/` wurde. Der Standort gehört damit
/// nicht `discovery`, sondern nach `lib/services/`, dem Ort für Vendor-Adapter
/// **ohne Oberfläche** (`lib/features/README.md`, „Was bewusst kein Feature
/// ist", zweiter Punkt). Vorbild im Bestand ist `lib/services/supabase/`.
///
/// Der Unterschied zu `lib/map/` steht in derselben Aufzählung: der Karten-Host
/// bringt eine eigene Oberfläche mit, dieser Dienst nicht. Er hat kein Widget
/// und keinen Zustand, den man ansehen könnte.
library;

import 'package:fact_app/services/location/device_position.dart';

/// Schlechteste Genauigkeit, die noch benutzt wird, in Metern.
///
/// `02_Frontend/app/screen-map.jsx:2744`: `if (p.coords.accuracy > 35) return;`.
/// **Echt größer**, genau 35 Meter werden also durchgelassen.
///
/// Der Kommentar der Quelle darüber (`:2740-2741`) nennt den Zweck: „Drop
/// everything worse than 35m so the marker never jumps during the cell→WiFi→GPS
/// warm-up sequence at cold-start." Ohne die Schwelle landet der Sky-Fall auf
/// einer groben Funkzellen-Ortung und die Karte springt danach weg.
const double locationAccuracyLimitInMeters = 35;

/// Ob [position] genau genug ist, um benutzt zu werden.
///
/// Die Umkehrung von `screen-map.jsx:2744`, also `<=` statt `>`.
bool isAccurateEnough(DevicePosition position) =>
    position.accuracyInMeters <= locationAccuracyLimitInMeters;

/// Woher die App die Position des Geräts bekommt.
///
/// ## Eine einzige Quelle, und das ist Parität
///
/// Es gibt hier bewusst kein „hol mir einmal die aktuelle Position". Die Quelle
/// benutzt allein `navigator.geolocation.watchPosition`
/// (`screen-map.jsx:2742-2749`), und der Kommentar darüber (`:2738-2739`) sagt
/// warum: „Single position source — no parallel getCurrentPosition race that
/// causes the sky-fall to land on a coarse cell/WiFi fix and then jump to real
/// GPS." Ein zusätzliches `getCurrentPosition` wäre also nicht bequemer,
/// sondern der beschriebene Fehler.
///
/// ## Der Strom endet nicht mit dem Kartenbildschirm
///
/// Wer ihn abonniert, entscheidet selbst, wann er ihn wieder loslässt. Der
/// Kartenbildschirm hört auf, der Kamera zu folgen, wenn sein Tab unsichtbar
/// ist; **den Strom lässt er trotzdem laufen**. Grund: er trägt später den
/// Audio-Beacon (`screen-map.jsx:2692-2700`) und das Geofencing, und ein Strom,
/// der beim Tabwechsel abreißt, bricht beide.
///
/// `abstract interface class`: ein versehentliches `extends` geht damit nicht
/// durch, und jeder Doppelgänger im Test schreibt sichtbar
/// `implements LocationService`.
abstract interface class LocationService {
  /// Jede Ortung des Geräts, ungefiltert.
  ///
  /// **Ungefiltert heißt: auch ungenaue.** Die Schwelle aus
  /// [locationAccuracyLimitInMeters] wendet der Verbraucher an, nicht der
  /// Dienst, damit sie ohne Plattformkanal prüfbar bleibt: eine Filterung im
  /// Vendor-Adapter liefe nur auf einem Gerät, und ein Filter, den kein Test
  /// erreicht, ist beim nächsten Umbau weg.
  ///
  /// **Der Auslöser, ab dem das umzudrehen ist:** der zweite Verbraucher. Wenn
  /// Audio-Beacon oder Geofencing denselben Strom abonnieren, wiederholt sich
  /// die Schwelle, und dann gehört sie in einen gemeinsamen Filter zwischen
  /// Dienst und Verbrauchern statt in jeden einzelnen.
  ///
  /// Ein Fehler wird als Fehlerereignis zugestellt und beendet den Strom nicht
  /// von sich aus. Die Quelle verhält sich genauso: ihr Fehlerzweig
  /// (`screen-map.jsx:2747`) blendet nur die Suchanzeige aus, `watchPosition`
  /// läuft weiter.
  Stream<DevicePosition> positionUpdates();
}

/// Der untätige Standard: ein Strom, der nie etwas liefert.
///
/// Dasselbe Muster wie `unavailableAuthRepository` in
/// `features/identity/domain/repositories/auth_repository.dart`: der Standard
/// eines Providers muss ohne Plattformkanal auskommen, sonst fällt jeder
/// Widget-Test über eine `MissingPluginException`. Und er fällt zur sicheren
/// Seite aus, er kann keine Position erfinden.
///
/// Kleingeschrieben referenziert, wie dort: Regel 7 des Prüfskripts meldet in
/// `presentation` jeden Konstruktoraufruf einer Klasse, deren Name auf
/// `Repository`, `DataSource` oder `Client` endet. `LocationService` endet auf
/// keines davon, die Schreibweise ist hier also Gleichklang und keine
/// Notwendigkeit.
const LocationService unavailableLocationService =
    _UnavailableLocationService();

final class _UnavailableLocationService implements LocationService {
  const _UnavailableLocationService();

  /// Ein leerer Strom, der sofort endet.
  ///
  /// **Nicht ein Strom, der ewig offen bleibt.** Ein Abonnent sähe zwischen
  /// beidem keinen Unterschied, aber ein offener Strom hielte in jedem Test
  /// eine Zeitüberschreitung offen, die niemand sucht.
  @override
  Stream<DevicePosition> positionUpdates() =>
      const Stream<DevicePosition>.empty();
}
