import 'dart:async';
import 'dart:math' as math;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/features/discovery/presentation/fact_audio_beacon.dart';
import 'package:fact_app/features/discovery/presentation/fact_overlay.dart';
import 'package:fact_app/features/discovery/presentation/map_mode.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_beacon_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/fact_overlay_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/map_mode_providers.dart';
import 'package:fact_app/features/discovery/presentation/notifiers/user_location_providers.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/domain/collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/entities/fact.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_coordinates.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_text.dart';
import 'package:fact_app/features/settings/application/audio_mode_providers.dart';
import 'package:fact_app/features/settings/domain/audio_mode_store.dart';
import 'package:fact_app/map/domain/map_overlay.dart';
import 'package:fact_app/map/domain/map_position.dart';
import 'package:fact_app/services/audio/tone_providers.dart';
import 'package:fact_app/services/audio/tone_service.dart';
import 'package:fact_app/services/location/device_position.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:fact_app/services/speech/speech_providers.dart';
import 'package:fact_app/services/speech/speech_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Auslöser des Audio-Beacons.
///
/// **Ohne Widget und ohne echte Zeit.** Die Uhr der Fünf-Sekunden-Sperre ist
/// ein Provider, den dieser Test überschreibt; das ist der ganze Grund, warum
/// sie einer ist.
void main() {
  const MapPosition user = MapPosition(latitude: 48.1372, longitude: 11.5756);

  MapPosition northOf(double meters) => MapPosition(
    latitude: user.latitude + meters * 180 / (math.pi * 6371000),
    longitude: user.longitude,
  );

  MapOverlayPoint pointAt(String id, double meters) => MapOverlayPoint(
    id: id,
    position: northOf(meters),
    styleId: 'hist-uncollected',
    state: 'uncollected',
  );

  Fact factWith(int id, String title) => Fact(
    id: FactId(id),
    content: FactText(title: title, category: 'Historisch'),
    coordinates: const FactCoordinates(latitude: 48.1372, longitude: 11.5756),
  );

  late _FakeLocationService location;
  late _RecordingToneService tone;
  late _RecordingSpeechService speech;
  late _TestClock clock;

  setUp(() {
    location = _FakeLocationService();
    tone = _RecordingToneService();
    speech = _RecordingSpeechService();
    clock = _TestClock();
  });

  tearDown(() async {
    await location.close();
    speech.close();
  });

  ProviderContainer newContainer({
    List<MapOverlayPoint> points = const <MapOverlayPoint>[],
    List<Fact> facts = const <Fact>[],
    bool audioMode = true,
    MapMode mode = MapMode.factFinder,
    List<FactId> collected = const <FactId>[],
    AppLanguage language = AppLanguage.de,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        toneServiceProvider.overrideWithValue(tone),
        speechServiceProvider.overrideWithValue(speech),
        factBeaconClockProvider.overrideWithValue(clock.call),
        audioModeStoreProvider.overrideWithValue(
          InMemoryAudioModeStore(enabled: audioMode),
        ),
        collectedFactsStoreProvider.overrideWithValue(
          InMemoryCollectedFactsStore(collected),
        ),
        mapModeProvider.overrideWith(() => _FixedMapModeNotifier(mode)),
        languagePreferenceStoreProvider.overrideWithValue(
          InMemoryLanguagePreferenceStore(language),
        ),
        factOverlayProvider.overrideWith(
          (ref) async => MapOverlay(id: factOverlayId, points: points),
        ),
        allFactsProvider.overrideWith((ref) async => facts),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Baut den Notifier auf und lässt die Überlagerung eintreffen.
  Future<void> start(ProviderContainer container) async {
    container.read(factBeaconProvider);
    // `factOverlayProvider` ist ein `FutureProvider`; ohne dieses Warten ist
    // sein Wert beim ersten Fix noch `AsyncLoading`, und der Scan kehrt still
    // zurück. Genau das passiert am Gerät auch, deshalb steht der Fall unten
    // als eigener Test.
    await container.read(factOverlayProvider.future);
    // **Und die Faktenliste dazu.** Am Gerät hängt die Überlagerung an
    // `allFactsProvider`, ein geladenes Overlay heißt dort also auch
    // geladene Fakten. Dieser Test überschreibt die Überlagerung direkt
    // und durchtrennt damit die Kette; ohne diese Zeile wäre der Titel in
    // der Ansage leer, und der Test prüfte den Rückfall statt der Regel.
    await container.read(allFactsProvider.future);
  }

  /// Schiebt eine Ortung in den Strom und lässt sie ankommen.
  Future<void> emitFix(ProviderContainer container) async {
    // Halten, sonst klinkt sich `UserLocationNotifier` gar nicht am Dienst
    // ein und die Meldung fällt ins Leere.
    container.read(userLocationProvider);
    location.emit(
      DevicePosition(
        latitude: user.latitude,
        longitude: user.longitude,
        // Unter der 35-Meter-Schranke, sonst verwirft `UserLocationNotifier`.
        accuracyInMeters: 10,
      ),
    );
    await pumpEventQueue();
  }

  group('wann der Ton kommt', () {
    test('ein naher Fakt löst Ton und Ansage aus', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await start(container);

      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, <String>['audio/beacon.mp3']);
      expect(container.read(factBeaconProvider), 1);
    });

    test('der Ton kommt vor der Ansage, mit Pause dazwischen', () async {
      // Die Quelle wartet 300 Millisekunden, damit der Ton nicht in den
      // ersten Wörtern untergeht.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await start(container);

      await emitFix(container);
      await pumpEventQueue();
      expect(tone.played, hasLength(1));
      expect(
        speech.spoken,
        isEmpty,
        reason: 'die Ansage wartet noch auf die 300 Millisekunden',
      );

      await Future<void>.delayed(factBeaconSpeechDelay);
      await pumpEventQueue();

      expect(speech.spoken, hasLength(1));
    });

    test('die Ansage nennt Titel, Entfernung und Uhrzeit', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await start(container);

      await emitFix(container);
      await Future<void>.delayed(factBeaconSpeechDelay);
      await pumpEventQueue();

      // `audio.beacon.prompt`, genau nördlich also zwölf Uhr.
      expect(
        speech.spoken.single,
        AppStrings.of(AppLanguage.de).text(
          'audio.beacon.prompt',
          params: const <String, String>{
            'titel': 'Alter Peter',
            'distance': '40',
            'clock': '12',
          },
        ),
      );
    });

    test('auf Englisch geht das englische Kennzeichen mit', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
        language: AppLanguage.en,
      );
      await start(container);

      await emitFix(container);
      await Future<void>.delayed(factBeaconSpeechDelay);
      await pumpEventQueue();

      expect(speech.languageTags, <String>['en-US']);
    });

    test('ein Fakt außerhalb der Reichweite löst nichts aus', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 400)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await start(container);

      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, isEmpty);
    });
  });

  group('die drei Sperren', () {
    test('ohne Audio-Modus bleibt es still', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
        audioMode: false,
      );
      await start(container);

      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, isEmpty);
    });

    test('in einem anderen Kartenmodus bleibt es still', () async {
      // `modeRef.current === "fact-finder"`. Im Tour-Modus hat die Quelle einen
      // eigenen Zweig, der Phase 6 braucht und hier fehlt.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
        mode: MapMode.tour,
      );
      await start(container);

      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, isEmpty);
    });

    test('ohne geladene Überlagerung bleibt es still', () async {
      // Am Gerät der Normalfall der ersten Sekunden: die Ortung ist da, die
      // Fakten sind noch unterwegs.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
      );
      container.read(factBeaconProvider);
      // **Kein `await` auf die Überlagerung**, das ist der Punkt.

      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, isEmpty);
    });

    test('ein gesammelter Fakt löst nichts aus', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
        collected: const <FactId>[FactId(7)],
      );
      await start(container);

      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, isEmpty);
    });
  });

  group('die Fünf-Sekunden-Sperre', () {
    test('zwei Fakten in Reichweite geben nur einen Ton', () async {
      // Die Sperre steht **vor** der Suche: höchstens ein Ton je Fenster,
      // nicht einer je Fakt.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40), pointAt('3', 80)],
        facts: <Fact>[factWith(7, 'Erster'), factWith(3, 'Zweiter')],
      );
      await start(container);

      await emitFix(container);
      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, hasLength(1));
    });

    test('nach fünf Sekunden kommt der zweite dran', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40), pointAt('3', 80)],
        facts: <Fact>[factWith(7, 'Erster'), factWith(3, 'Zweiter')],
      );
      await start(container);
      await emitFix(container);
      await pumpEventQueue();

      clock.advance(factBeaconInterval);
      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, hasLength(2));
      expect(container.read(factBeaconProvider), 2);
    });

    test('eine Millisekunde zu früh reicht nicht', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40), pointAt('3', 80)],
        facts: <Fact>[factWith(7, 'Erster'), factWith(3, 'Zweiter')],
      );
      await start(container);
      await emitFix(container);
      await pumpEventQueue();

      clock.advance(factBeaconInterval - const Duration(milliseconds: 1));
      await emitFix(container);
      await pumpEventQueue();

      expect(tone.played, hasLength(1));
    });
  });

  group('die Stereo-Verteilung geht mit', () {
    test('ein Fakt genau im Norden klingt mittig', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await start(container);

      await emitFix(container);
      await pumpEventQueue();

      expect(tone.balances.single, closeTo(0, 0.001));
    });

    test('ein Fakt im Osten klingt rechts', () async {
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[
          MapOverlayPoint(
            id: '7',
            position: MapPosition(
              latitude: user.latitude,
              longitude: user.longitude + 0.0005,
            ),
            styleId: 'hist-uncollected',
            state: 'uncollected',
          ),
        ],
        facts: <Fact>[factWith(7, 'Alter Peter')],
      );
      await start(container);

      await emitFix(container);
      await pumpEventQueue();

      expect(tone.balances.single, closeTo(1, 0.001));
    });
  });

  group('ein Fakt ohne Titel', () {
    test('sagt trotzdem Entfernung und Uhrzeit', () async {
      // Die Überlagerung und die Faktenliste sind zwei Provider; ein Punkt
      // ohne passenden Fakt ist möglich. Ein erfundener Ersatztext wäre die
      // schlechtere Antwort.
      final ProviderContainer container = newContainer(
        points: <MapOverlayPoint>[pointAt('7', 40)],
      );
      await start(container);

      await emitFix(container);
      await Future<void>.delayed(factBeaconSpeechDelay);
      await pumpEventQueue();

      expect(speech.spoken.single, contains('40'));
      expect(speech.spoken.single, isNot(contains('{titel}')));
    });
  });
}

/// Eine von Hand vorspulbare Uhr, wie `TestClock` in `map_page_test.dart`.
class _TestClock {
  Duration _now = Duration.zero;

  Duration call() => _now;

  void advance(Duration by) => _now += by;
}

/// Ein Kartenmodus, der feststeht.
class _FixedMapModeNotifier extends MapModeNotifier {
  _FixedMapModeNotifier(this._mode);

  final MapMode _mode;

  @override
  MapMode build() => _mode;
}

/// Ein Ortungsdienst, dessen Ortungen der Test setzt.
class _FakeLocationService implements LocationService {
  final StreamController<DevicePosition> _controller =
      StreamController<DevicePosition>.broadcast();

  @override
  Stream<DevicePosition> positionUpdates() => _controller.stream;

  void emit(DevicePosition position) => _controller.add(position);

  Future<void> close() => _controller.close();
}

/// Eine Tonwiedergabe, die mitschreibt.
class _RecordingToneService implements ToneService {
  final List<String> played = <String>[];
  final List<double> balances = <double>[];

  @override
  Future<void> playTone(String assetPath, {double balance = 0}) async {
    played.add(assetPath);
    balances.add(balance);
  }
}

/// Eine Sprachausgabe, die mitschreibt.
class _RecordingSpeechService implements SpeechService {
  final StreamController<SpeechState> _states =
      StreamController<SpeechState>.broadcast();

  final List<String> spoken = <String>[];
  final List<String> languageTags = <String>[];

  void close() => _states.close();

  @override
  Stream<SpeechState> stateUpdates() => _states.stream;

  @override
  Future<void> speak({
    required String text,
    required String languageTag,
    double rate = defaultSpeechRate,
  }) async {
    spoken.add(text);
    languageTags.add(languageTag);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}
}
