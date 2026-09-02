/// Der Auslöser des Audio-Beacons: die Ortung. Schritt 26.
///
/// ## Warum ein Notifier und kein Zweig im Kartenbildschirm
///
/// Weil hier nichts zu zeichnen ist. `map_page.dart` ist der Ort für alles,
/// was die Karte bewegt; dieser Ablauf bewegt nichts, er hört zu und macht
/// Geräusche. Als Notifier ist er ohne Widget-Test prüfbar, und die
/// Merkzustände der Hysterese leben so lange, wie der Kartenbildschirm lebt,
/// und nicht länger.
///
/// **Gehalten werden muss er trotzdem.** Ein Provider, den niemand liest,
/// entsteht nie. `map_page.dart` hält ihn mit einem `listenManual`, und das
/// ist die einzige Zeile, die dort dazukommt.
///
/// ## Der zweite Verbraucher des Ortungsstroms, und die Schwelle bleibt eine
///
/// `location_service.dart` hält fest, dass die Genauigkeitsschwelle beim
/// Verbraucher liegt und nicht im Dienst, und benennt den Auslöser, ab dem
/// das umzudrehen wäre: „Wenn Audio-Beacon oder Geofencing denselben Strom
/// abonnieren, wiederholt sich die Schwelle." **Dieser Auslöser ist jetzt da,
/// und er greift trotzdem nicht:** dieser Notifier hört nicht am Dienst,
/// sondern an `userLocationProvider`, der die Schwelle schon angewandt hat.
/// Die Zahl steht damit weiter an genau einer Stelle.
library;

import 'dart:async';

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/core/async/detached_work.dart';
import 'package:fact_app/features/discovery/presentation/fact_audio_beacon.dart';
import 'package:fact_app/features/discovery/presentation/fact_proximity.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/application/fact_speech_providers.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/settings/application/audio_mode_providers.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/services/audio/tone_providers.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/speech/speech_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Der Pfad des Hinweistons, wie er in `pubspec.yaml` steht.
///
/// **Ohne `assets/`**, weil `audioplayers` seinen eigenen Präfix davorsetzt;
/// die Begründung steht am Adapter.
const String factBeaconAsset = 'audio/beacon.mp3';

/// Die Uhr der Fünf-Sekunden-Sperre.
///
/// **Eine laufende `Stopwatch` und nicht `DateTime.now`.** Dieselbe Erwägung
/// wie beim Kompass-Wachhund in `map_page.dart`, dort ausführlich: `DateTime`
/// springt bei `tester.pump(Duration)` nicht mit vor, weil `fake_async` nur
/// Zeitgeber und `Stopwatch` verspult, und ein Test gegen die Wanduhr bräuchte
/// echtes Warten. Ein Test überschreibt diesen Provider.
final Provider<Duration Function()> factBeaconClockProvider =
    Provider<Duration Function()>((ref) {
      final Stopwatch watch = Stopwatch()..start();
      return () => watch.elapsed;
    });

/// Wie oft der Hinweiston seit dem Aufbau angesagt wurde.
///
/// **Der Zustand ist eine Zählung, und das ist ehrlicher als er aussieht.**
/// Dieser Notifier existiert für seine Wirkung, nicht für seinen Wert; ein
/// Ton und eine Ansage sind nichts, was ein Widget lesen könnte. Die Zählung
/// ist das Einzige, woran ein Test von außen sieht, dass etwas passiert ist,
/// ohne die beiden Dienste zu befragen, und sie ist der Anker für den
/// nächsten Verbraucher, falls einer kommt (etwa ein Puls auf dem Ballon).
final factBeaconProvider = NotifierProvider<FactBeaconNotifier, int>(
  FactBeaconNotifier.new,
);

/// Löst den Hinweiston aus, wenn man einem Fakt nahe kommt.
class FactBeaconNotifier extends Notifier<int> {
  /// Die Merkzustände der Hysterese, siehe `fact_audio_beacon.dart`.
  Map<String, FactBeaconState> _states = <String, FactBeaconState>{};

  /// Wann zuletzt angesagt wurde, oder `null`.
  Duration? _lastAnnouncement;

  @override
  int build() {
    // **Ohne `fireImmediately`, und beides hat einen Grund.** Die Quelle
    // sucht allein im Ortungs-Handler (`screen-map.jsx:2650` und `:2692`),
    // eine schon vorliegende Ortung löst dort also auch nichts aus. Und ein
    // sofortiges Feuern liefe **im Aufbau dieses Providers**, wo Riverpod das
    // Setzen des Zustands verbietet; genau diese Falle hat am 02.09.2026 in
    // `fact_page.dart` zugeschlagen.
    ref.listen<UserLocationState>(
      userLocationProvider,
      (UserLocationState? previous, UserLocationState next) => _onFix(next),
    );
    return 0;
  }

  /// Eine neue Ortung, `screen-map.jsx:2690-2718`.
  ///
  /// Die Reihenfolge der Bedingungen ist die der Quelle, und sie ist von
  /// billig nach teuer sortiert: erst zwei Schalter, dann die Uhr, und erst
  /// zuletzt der Lauf über alle Fakten. Bei fünf Ortungen je Sekunde ist das
  /// der Unterschied zwischen einer Handvoll Vergleiche und einer
  /// Wurzelrechnung je Fakt.
  void _onFix(UserLocationState location) {
    final DevicePosition? fix = location.fix;
    if (fix == null) {
      return;
    }
    if (!ref.read(audioModeProvider)) {
      return;
    }
    // `modeRef.current === 'fact-finder'` (`:2692`). Im Tour-Modus hat die
    // Quelle einen eigenen Zweig, der hier fehlt (Phase 6), und im
    // Challenge-Modus schweigt sie.
    if (ref.read(mapModeProvider) != MapMode.factFinder) {
      return;
    }
    final Duration now = ref.read(factBeaconClockProvider)();
    final Duration? last = _lastAnnouncement;
    if (last != null && now - last < factBeaconInterval) {
      return;
    }
    final MapOverlay? overlay = ref.read(factOverlayProvider).value;
    if (overlay == null) {
      return;
    }
    final List<FactId> collected = ref.read(collectedFactsProvider);
    final FactBeaconScan scan = scanForFactBeacon(
      user: mapPositionOf(fix),
      candidates: overlay.points,
      isCollected: (String factId) => _isCollected(factId, collected),
      states: _states,
    );
    _states = scan.states;
    final MapOverlayPoint? target = scan.target;
    if (target == null) {
      return;
    }
    _lastAnnouncement = now;
    state = state + 1;
    reportDetached(
      _announce(
        target: target,
        bearing: scan.bearing!,
        distanceInMeters: mapPositionOf(
          fix,
        ).distanceInMetersTo(target.position),
      ),
      origin: 'discovery.beacon.announce',
    );
  }

  /// Ton, kurze Pause, Ansage.
  ///
  /// Die Reihenfolge und die Pause sind die der Quelle
  /// (`audio-player.jsx:330-357`): erst der Ton, dann 300 Millisekunden,
  /// damit er nicht in den ersten Wörtern untergeht, dann der Satz.
  ///
  /// **Gesprochen wird über den Dienst und nicht über `factSpeechProvider`.**
  /// Der Unterschied ist der Fehler, den die Quelle an dieser Stelle gemacht
  /// hat: sie schiebt für die Ansage eine Fakt-Attrappe in ihren Spieler, und
  /// ihr eigener Kommentar nennt die Folge, „made MiniPlayer pop up with an
  /// empty title for every beacon". Eine Ansage ist kein vorgelesener Fakt;
  /// der Kopfhörer-Knopf in der Akte darf davon nichts mitbekommen.
  Future<void> _announce({
    required MapOverlayPoint target,
    required double bearing,
    required double distanceInMeters,
  }) async {
    await ref
        .read(toneServiceProvider)
        .playTone(factBeaconAsset, balance: factBeaconBalanceOf(bearing));
    await Future<void>.delayed(factBeaconSpeechDelay);
    if (!ref.mounted) {
      return;
    }
    final AppStrings strings = ref.read(appStringsProvider);
    final String title = _titleOf(target.id);
    await ref
        .read(speechServiceProvider)
        .speak(
          text: strings.text(
            'audio.beacon.prompt',
            params: <String, String>{
              'titel': title,
              'distance': '${distanceInMeters.round()}',
              'clock': '${factBeaconClockOf(bearing)}',
            },
          ),
          languageTag: speechLanguageTagFor(ref.read(appLanguageProvider).code),
        );
  }

  /// Der Titel zu einer Kennung, oder eine leere Zeichenkette.
  ///
  /// Die Quelle nimmt `fact.titel` unbesehen; hier kann der Fakt fehlen, weil
  /// die Überlagerung und die Faktenliste zwei Provider sind. Ein leerer
  /// Titel sagt dann „{distance} Meter, auf {clock}", und das ist immer noch
  /// eine brauchbare Ansage. Ein erfundener Ersatztext wäre es nicht.
  String _titleOf(String factId) {
    final int? numeric = int.tryParse(factId);
    if (numeric == null) {
      return '';
    }
    final List<Fact> facts = ref.read(allFactsProvider).value ?? const <Fact>[];
    for (final Fact fact in facts) {
      if (fact.id.value == numeric) {
        return fact
                .contentFor(
                  ref.read(appLanguageProvider).code,
                  fallbackLanguageCode: 'de',
                )
                .title ??
            '';
      }
    }
    return '';
  }

  bool _isCollected(String factId, List<FactId> collected) {
    final int? numeric = int.tryParse(factId);
    return numeric != null && collected.contains(FactId(numeric));
  }
}
