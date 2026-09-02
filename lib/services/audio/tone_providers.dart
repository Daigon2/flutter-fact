/// Der Zugang zur Tonwiedergabe als Riverpod-Komposition (ADR-005).
///
/// Warum der Provider neben dem Vertrag steht und nicht bei seinem
/// Verbraucher, steht bei `speechServiceProvider` und dort schon zum dritten
/// Mal; die Erwägung ist unverändert. Dieselbe offen benannte Spannung um
/// „narrowly scoped Core" gilt auch hier und ist damit **viermal** aufgetreten
/// (D-21).
library;

import 'package:fact_app/services/audio/tone_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Woher die App kurze Klänge bekommt.
///
/// Der Standard ist [unavailableToneService], also Stille, aus demselben
/// Grund wie bei den drei Diensten davor: `flutter test` hat keinen
/// Plattformkanal. Die echte Fassung setzt `lib/app/bootstrap.dart` per
/// Override ein.
final Provider<ToneService> toneServiceProvider = Provider<ToneService>(
  (ref) => unavailableToneService,
);
