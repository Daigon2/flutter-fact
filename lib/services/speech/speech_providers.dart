/// Der Zugang zur Sprachausgabe als Riverpod-Komposition (ADR-005).
///
/// ## Warum der Provider hier steht und nicht bei seinem Verbraucher
///
/// Dieselbe Erwägung wie bei `locationServiceProvider` und
/// `orientationServiceProvider`, dort ausführlich:
/// `docs/architecture/dependency-rules.md:109-122` nennt zwei richtige
/// Platzierungen für einen Provider, der auf einem Vertrag typisiert ist, bei
/// der Oberfläche, die ihn liest, oder neben dem Vertrag selbst. Hier gilt die
/// zweite, und diesmal ist es nicht nur absehbar, sondern schon so: die
/// Fakt-Akte liest ihn ab Schritt 25, die Karte ab Schritt 26. In
/// `features/facts/presentation/` wäre er der private Zustand eines Features,
/// an den `features/discovery` nach Regel 8 nicht herankäme.
///
/// ## Dieselbe offen benannte Spannung, zum dritten Mal
///
/// `dependency-rules.md:18-27` gesteht der Presentation „Application, Domain,
/// narrowly scoped Core" zu, und `Services` steht dort nicht. Wer diesen
/// Provider aus einer Presentation liest, importiert `lib/services/speech/`,
/// und `tool/check_architecture.dart` prüft das nicht, weil `lib/services/`
/// kein Schichtsegment trägt. D-14 hat die Spannung für den Ortungsdienst
/// bewusst offengelassen, der Orientierungsdienst hat sie unverändert
/// geerbt, und hier gilt sie fort. **Sie ist damit dreimal aufgetreten**, und
/// das ist der Punkt, an dem D-21 („was heißt narrowly scoped Core") sie
/// mitbeantworten sollte, statt sie ein viertes Mal zu wiederholen.
library;

import 'package:fact_app/services/speech/speech_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Woher die App die Sprachausgabe bekommt.
///
/// Der Standard ist [unavailableSpeechService], also Stille, dieselbe
/// Entscheidung wie bei den beiden Diensten davor und aus demselben Grund:
/// `flutter test` hat keinen Plattformkanal, ein echter
/// `FlutterTtsSpeechService` würde dort mit einer `MissingPluginException`
/// scheitern.
///
/// Die echte Fassung setzt `lib/app/bootstrap.dart` per Override ein, und
/// **dieser Provider ist der „eine Klick" aus E-15**: eine Cloud-Sprachausgabe
/// wird hier eingesetzt, nicht in die Aufrufer eingebaut.
final Provider<SpeechService> speechServiceProvider = Provider<SpeechService>(
  (ref) => unavailableSpeechService,
);
