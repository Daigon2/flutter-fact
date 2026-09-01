/// Der Zugang zum Orientierungsdienst als Riverpod-Komposition (ADR-005).
///
/// ## Warum der Provider hier steht und nicht bei seinem Verbraucher
///
/// Dieselbe Erwägung wie bei `locationServiceProvider` in
/// `location_providers.dart`: `docs/architecture/dependency-rules.md:109-122`
/// nennt zwei richtige Platzierungen für einen Provider, der auf einem
/// Vertrag typisiert ist, bei der Oberfläche, die ihn liest, oder neben dem
/// Vertrag selbst. Hier gilt wie dort die zweite: die Blickrichtung wird
/// heute von der Karte gebraucht (Schritt 14), absehbar aber auch von
/// anderem, das sich an einer Richtung orientiert, und in
/// `features/discovery/presentation/` wäre der Provider der private Zustand
/// eines Features, an den ein zweiter Verbraucher nicht herankäme.
///
/// ## Dieselbe offen benannte Spannung
///
/// `location_providers.dart` hält fest, dass `dependency-rules.md:18-27` der
/// Presentation „Application, Domain, narrowly scoped Core" zugesteht und
/// `Services` dort nicht auftaucht. Dieselbe Spannung gilt hier unverändert:
/// wer diesen Provider aus einer Presentation liest, importiert
/// `lib/services/orientation/`, und `tool/check_architecture.dart` prüft das
/// nicht, weil `lib/services/` kein Schichtsegment trägt. D-14 hat diese
/// Spannung für den Ortungsdienst bewusst offengelassen statt sie zu
/// verstecken; sie gilt für den Orientierungsdienst aus identischer
/// Begründung fort, und eine zweite Entscheidung dafür wäre eine Wiederholung
/// derselben.
library;

import 'package:fact_app/services/orientation/orientation_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Woher die App die Blickrichtung des Geräts bekommt.
///
/// Der Standard ist `unavailableOrientationService`, ein Strom, der nichts
/// liefert, dieselbe Entscheidung wie bei `locationServiceProvider` und aus
/// demselben Grund: `flutter test` hat keinen Plattformkanal, eine echte
/// `RotationSensorOrientationService` würde dort mit einer
/// `MissingPluginException` scheitern.
///
/// Die echte Fassung setzt `lib/app/bootstrap.dart` per Override ein.
final Provider<OrientationService> orientationServiceProvider =
    Provider<OrientationService>((ref) => unavailableOrientationService);
