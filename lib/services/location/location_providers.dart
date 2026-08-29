/// Der Zugang zum Ortungsdienst als Riverpod-Komposition (ADR-005).
///
/// ## Warum der Provider hier steht und nicht bei seinem Verbraucher
///
/// `docs/architecture/dependency-rules.md:109-122` nennt zwei richtige
/// Platzierungen für einen Provider, der auf einem **Vertrag** typisiert ist:
/// bei der Oberfläche, die ihn liest (`authRepositoryProvider`, das laut E-32
/// zu kopierende Muster), oder neben dem Vertrag selbst
/// (`core/diagnostics/diagnostics_providers.dart`, dort ausdrücklich ebenfalls
/// als richtig bezeichnet). Hier gilt die zweite: der Ortungsstrom bekommt
/// absehbar mehr als einen Verbraucher, nämlich Audio-Beacon und Geofencing
/// (`screen-map.jsx:2692` und folgende), und in
/// `features/discovery/presentation/` wäre er der private Zustand eines
/// Features, an den die anderen nicht herankommen.
///
/// ## Eine Spannung, die hier bewusst offen benannt wird
///
/// Die Tabelle in `dependency-rules.md:18-27` gibt der Presentation
/// „Application, Domain, narrowly scoped Core". **`Services` steht dort
/// nicht.** Wer diesen Provider aus `features/discovery/presentation/` liest,
/// importiert `lib/services/location/`, und das prüft
/// `tool/check_architecture.dart` nicht: `lib/services/` trägt kein
/// Schichtsegment, es gilt also keine der Schichtregeln.
///
/// Der vollständig geschichtete Weg wäre möglich und ist verworfen worden: ein
/// Vertrag in `discovery/domain/`, eine Umsetzung in `discovery/data/`, die
/// diesen Dienst umhüllt, wie es
/// `features/facts/data/datasources/remote/supabase_fact_remote_data_source.dart`
/// mit `services/supabase/` tut. Er kostet drei Dateien **und einen vierten
/// Geo-Typ** in `discovery/domain/`, weil eine Domäne nichts aus `services/`
/// importieren darf (Gate 6). Genau diesen vierten Typ soll die offene
/// Entscheidung D-9 loswerden, nicht vermehren.
///
/// **Der Auslöser, ab dem der geschichtete Weg richtig wird:** sobald aus dem
/// Standort mehr wird als ein durchgereichter Messwert, also die erste
/// fachliche Regel darauf (Geofencing entscheidet, ob ein Fakt sammelbar ist).
/// Dann gehört der Vertrag in eine Domäne, und dieser Dienst wird das, was
/// `services/supabase/` heute ist: der Vendor-Teil darunter.
library;

import 'package:fact_app/services/location/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Woher die App die Position des Geräts bekommt.
///
/// Der Standard ist [unavailableLocationService], also **ein Strom, der nichts
/// liefert**. Das ist dieselbe Entscheidung wie bei `authRepositoryProvider`
/// und aus demselben Grund: `flutter test` hat keinen Plattformkanal, ein
/// echter `geolocator` würde dort mit einer `MissingPluginException` scheitern.
/// Und der Standard fällt zur sicheren Seite aus, er kann keine Position
/// erfinden.
///
/// Die echte Fassung setzt `lib/app/bootstrap.dart` per Override ein.
final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((ref) => unavailableLocationService);
