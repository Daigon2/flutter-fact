import 'dart:async';
import 'dart:convert';

import 'package:fact_app/app/bootstrap.dart';
import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/language_preference_store.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/onboarding/key_value_tour_store.dart';
import 'package:fact_app/app/onboarding/onboarding_providers.dart';
import 'package:fact_app/app/onboarding/tour_store.dart';
import 'package:fact_app/core/diagnostics/diagnostic_sink.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/challenges/application/active_hunt_providers.dart';
import 'package:fact_app/features/challenges/data/key_value_active_hunt_store.dart';
import 'package:fact_app/features/challenges/domain/active_hunt_store.dart';
import 'package:fact_app/features/challenges/domain/entities/active_hunt.dart';
import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/data/key_value_collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/collected_facts_store.dart';
import 'package:fact_app/features/facts/domain/repositories/fact_repository.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_id.dart';
import 'package:fact_app/features/identity/data/key_value_first_launch_store.dart';
import 'package:fact_app/features/identity/domain/first_launch_store.dart';
import 'package:fact_app/features/identity/domain/repositories/auth_repository.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:fact_app/features/settings/data/key_value_audio_mode_store.dart';
import 'package:fact_app/features/settings/data/key_value_language_preference_store.dart';
import 'package:fact_app/features/settings/domain/audio_mode_store.dart';
import 'package:fact_app/features/settings/presentation/notifiers/audio_mode_providers.dart';
import 'package:fact_app/services/diagnostics/console_diagnostic_sink.dart';
import 'package:fact_app/services/location/geolocator_location_service.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/location/location_service.dart';
import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:fact_app/services/supabase/supabase_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Baut die Scope des Betriebs mit einem flüchtigen Gerätespeicher.
///
/// [productionProviderScope] verlangt den Speicher seit dem 31.08.2026, und
/// zwar ohne Standardwert: ein Standard dort wäre genau der stille Ausfall, den
/// diese Datei überall sonst nachweist. Der Preis ist dieser Helfer.
ProviderScope _scope({
  KeyValueStore? preferences,
  Widget child = const SizedBox.shrink(),
}) => productionProviderScope(
  preferences: preferences ?? InMemoryKeyValueStore(),
  child: child,
);

/// Die Overrides des Betriebs.
///
/// Dieser Test ist das Netz unter dem stillen Standard. `authRepositoryProvider`
/// liefert ohne Override [unavailableAuthRepository], also einen Zustand, in dem
/// sich niemand anmelden kann und **nichts** danach aussieht: keine Ausnahme,
/// kein Log, ein Bildschirm, der einfach "Fehler beim Anmelden" sagt. Fehlt der
/// Override in `bootstrap.dart`, fällt genau das erst auf einem Gerät auf.
void main() {
  group('productionProviderScope', () {
    test('bindet authRepositoryProvider an die Supabase-Umsetzung', () {
      // Nachgewiesen über die Wirkung statt über die Identität des
      // `Override`-Objekts: mit dem Override braucht das Repository die
      // Supabase-Konfiguration, ohne ihn nicht. Genau daran ist zu erkennen,
      // dass nicht mehr der untätige Standard antwortet.
      final scope = _scope();
      final container = ProviderContainer(
        overrides: [
          ...scope.overrides,
          // Erzwingt die fehlende Konfiguration, damit der Test nicht davon
          // abhängt, ob jemand `--dart-define` gesetzt hat.
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: '', publishableKey: ''),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Geprüft wird der Text und nicht der Typ: Riverpod 3 verpackt einen
      // Fehler aus einem Provider in `ProviderException`, und dieser Typ ist
      // aus `flutter_riverpod 3.4.2` nicht exportiert. Die Meldung von
      // `SupabaseConfigurationError` steht darin.
      expect(
        () => container.read(authRepositoryProvider),
        throwsA(
          isA<Object>().having(
            (error) => error.toString(),
            'toString',
            allOf(
              contains('Supabase ist nicht konfiguriert'),
              contains(SupabaseConfig.urlVariable),
            ),
          ),
        ),
      );
    });

    test('ohne die Overrides bleibt der untätige Standard', () {
      // Die Gegenprobe. Ohne sie könnte der Test oben auch grün sein, wenn der
      // Standard selbst Supabase anfassen würde.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(authRepositoryProvider),
        same(unavailableAuthRepository),
      );
    });

    test('bindet diagnosticSinkProvider an die meldende Senke', () {
      // Der teuerste stille Ausfall der vier hier, weil er die anderen
      // unsichtbar macht: ohne diesen Override bleibt `SilentDiagnosticSink`
      // stehen, und dann verschwinden eine verworfene Kameraabsicht, eine
      // unbekannte Stil-Kennung und eine gescheiterte Projektion spurlos.
      // Genau daran ist der erste Kartenlauf am Emulator blind gewesen.
      final scope = _scope();
      final container = ProviderContainer(overrides: scope.overrides);
      addTearDown(container.dispose);

      // `flutter test` läuft im Debug-Bau, `kDebugMode` ist hier also wahr.
      // Wer `diagnosticSinkForBuild` in `bootstrap.dart` mit einem festen
      // `false` aufruft, fällt hier auf.
      expect(
        container.read(diagnosticSinkProvider),
        isA<ConsoleDiagnosticSink>(),
      );
    });

    test('die eingesetzte Senke gibt Namen und Nutzlast aus', () {
      // Die Zusicherung hinter der Typprüfung. Ohne sie wäre "die Senke ist
      // eingesetzt" eine Aussage über einen Klassennamen, und eine
      // `ConsoleDiagnosticSink`, deren Ausgabekanal ins Leere zeigt, käme
      // damit durch.
      final scope = _scope();
      final container = ProviderContainer(overrides: scope.overrides);
      addTearDown(container.dispose);
      final sink = container.read(diagnosticSinkProvider);
      final lines = <String?>[];

      runZoned(
        () => sink.report(
          DiagnosticEvent('map.overlay.unknown_style', const <String, String>{
            'overlay': 'facts',
          }),
        ),
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) =>
              lines.add(line),
        ),
      );

      expect(lines, <String>[
        'FACT-DIAG map.overlay.unknown_style overlay=facts',
      ]);
    });

    test('ohne die Overrides bleibt die stumme Senke', () {
      // Die Gegenprobe. `same` und nicht `isA`: Dart kanonisiert die
      // Konstante, die Identität ist hier also die schärfere Zusicherung.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(diagnosticSinkProvider),
        same(const SilentDiagnosticSink()),
      );
    });

    test('bindet locationServiceProvider an die geolocator-Umsetzung', () {
      // Derselbe stille Ausfall wie bei der Anmeldung, nur eine Ebene weiter:
      // ohne diesen Override liefert der Standard nie eine Position, die Karte
      // bliebe für immer auf der Rückfallstadt stehen, und es gäbe weder einen
      // Fehler noch ein Log. Auffallen würde es erst auf einem Gerät.
      final scope = _scope();
      final container = ProviderContainer(overrides: scope.overrides);
      addTearDown(container.dispose);

      expect(
        container.read(locationServiceProvider),
        isA<GeolocatorLocationService>(),
      );
    });

    test('ohne die Overrides liefert der Ortungsdienst nichts', () {
      // Die Gegenprobe, wie oben. `same` und nicht `isA`: der Standard ist eine
      // Konstante, damit ein Test ihn identifizieren kann.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(locationServiceProvider),
        same(unavailableLocationService),
      );
    });

    test('bindet factRepositoryProvider an die Supabase-Umsetzung', () {
      // Seit Schritt 15 hängt die Karte daran. Nachgewiesen wieder über die
      // Wirkung: mit dem Override braucht das Repository die
      // Supabase-Konfiguration, ohne ihn nicht.
      final scope = _scope();
      final container = ProviderContainer(
        overrides: [
          ...scope.overrides,
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: '', publishableKey: ''),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(factRepositoryProvider),
        throwsA(
          isA<Object>().having(
            (error) => error.toString(),
            'toString',
            contains('Supabase ist nicht konfiguriert'),
          ),
        ),
      );
    });

    test('ohne die Overrides scheitert jeder Faktenabruf sichtbar', () {
      // Die Gegenprobe. **Und der Grund, warum der Standard hier wirft statt
      // eine leere Liste zu liefern:** eine leere Faktenliste ist von einer
      // Stadt ohne Fakten nicht zu unterscheiden, ein fehlender Override wäre
      // also eine leere Karte ohne jede Meldung.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(factRepositoryProvider),
        same(unavailableFactRepository),
      );
    });

    // ── Die fünf Speicher ─────────────────────────────────────────────
    //
    // Geprüft wird jeweils über die **Wirkung** und nicht über den Typ: der
    // vorgesetzte Speicher trägt einen Wert, und der muss durch den Provider
    // hindurch ankommen. Eine Typprüfung allein käme auch dann durch, wenn
    // `bootstrap.dart` einen frisch gebauten, leeren Speicher übergäbe, und
    // genau das wäre der Fehler, der auf dem Gerät wie „nichts wird
    // gespeichert" aussieht.

    test('bindet firstLaunchStoreProvider an den übergebenen Speicher', () {
      final container = ProviderContainer(
        overrides: _scope(
          preferences: InMemoryKeyValueStore(<String, Object>{
            KeyValueFirstLaunchStore.storageKey: true,
          }),
        ).overrides,
      );
      addTearDown(container.dispose);

      expect(container.read(firstLaunchStoreProvider).hasLaunched(), isTrue);
    });

    test('bindet tourStoreProvider an den übergebenen Speicher', () {
      final container = ProviderContainer(
        overrides: _scope(
          preferences: InMemoryKeyValueStore(<String, Object>{
            KeyValueTourStore.storageKey: true,
          }),
        ).overrides,
      );
      addTearDown(container.dispose);

      expect(container.read(tourStoreProvider).hasSeenTour(), isTrue);
    });

    test('bindet audioModeStoreProvider an den übergebenen Speicher', () {
      final container = ProviderContainer(
        overrides: _scope(
          preferences: InMemoryKeyValueStore(<String, Object>{
            KeyValueAudioModeStore.storageKey: true,
          }),
        ).overrides,
      );
      addTearDown(container.dispose);

      expect(container.read(audioModeStoreProvider).isEnabled(), isTrue);
    });

    test(
      'bindet languagePreferenceStoreProvider an den übergebenen Speicher',
      () {
        final container = ProviderContainer(
          overrides: _scope(
            preferences: InMemoryKeyValueStore(<String, Object>{
              KeyValueLanguagePreferenceStore.storageKey: 'en',
            }),
          ).overrides,
        );
        addTearDown(container.dispose);

        expect(
          container.read(languagePreferenceStoreProvider).readLanguage(),
          AppLanguage.en,
        );
      },
    );

    test('bindet activeHuntStoreProvider an den übergebenen Speicher', () {
      // Der teuerste der fünf: ohne diesen Override ist eine laufende Jagd
      // nach einem Neustart weg, und genau das schließt ADR-007 als
      // Produktvorgabe aus.
      final ActiveHunt hunt = ActiveHunt.tryFrom(
        stationOrdinal: 3,
        stationCount: 7,
        stationTitle: 'Station 3',
        stationLatitude: 48.1467,
        stationLongitude: 11.5661,
        unlockedHintIndices: const <int>[],
        difficulty: null,
        duration: HuntDuration.sixty,
      )!;
      final container = ProviderContainer(
        overrides: _scope(
          preferences: InMemoryKeyValueStore(<String, Object>{
            KeyValueActiveHuntStore.storageKey: jsonEncode(hunt.toPayload()),
          }),
        ).overrides,
      );
      addTearDown(container.dispose);

      expect(container.read(activeHuntStoreProvider).readActiveHunt(), hunt);
    });

    test('bindet collectedFactsStoreProvider an den übergebenen Speicher', () {
      // Der zweite echte Schaden neben der Jagd: ohne diesen Override ist die
      // Sammlung nach einem Neustart weg, und das trifft die Kernhandlung der
      // App. Man geht hin, sammelt, und am nächsten Tag war man nie dort.
      final container = ProviderContainer(
        overrides: _scope(
          preferences: InMemoryKeyValueStore(<String, Object>{
            KeyValueCollectedFactsStore.storageKey: '[7,3]',
          }),
        ).overrides,
      );
      addTearDown(container.dispose);

      expect(
        container.read(collectedFactsStoreProvider).readCollectedFacts(),
        const <FactId>[FactId(7), FactId(3)],
      );
    });

    test('der Sammel-Speicher meldet an die überschriebene Senke', () {
      // Der zweite von zwei Einträgen mit `overrideWith` statt
      // `overrideWithValue`, aus demselben Grund wie der Jagd-Speicher: er
      // liest die Diagnosesenke. Ohne `ref.watch` bekäme er eine zweite,
      // selbst gebaute, und ein verworfener Eintrag wäre auf dem Gerät nicht
      // zu sehen.
      final container = ProviderContainer(
        overrides: _scope(
          preferences: InMemoryKeyValueStore(<String, Object>{
            KeyValueCollectedFactsStore.storageKey: 'kein json',
          }),
        ).overrides,
      );
      addTearDown(container.dispose);
      final lines = <String?>[];

      final List<FactId> restored = runZoned(
        () => container.read(collectedFactsStoreProvider).readCollectedFacts(),
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) =>
              lines.add(line),
        ),
      );

      expect(restored, isEmpty);
      final String expected =
          'FACT-DIAG ${KeyValueCollectedFactsStore.discardedEventName} '
          '${KeyValueCollectedFactsStore.discardedCountField}=1';
      expect(lines, <String>[expected]);
    });

    test('ohne die Overrides bleiben alle sechs Speicher flüchtig', () {
      // Die Gegenprobe zu den sechs Tests darüber, in einem. Ohne sie könnten
      // sie auch grün sein, wenn die Standards selbst schon persistierten.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(firstLaunchStoreProvider),
        isA<InMemoryFirstLaunchStore>(),
      );
      expect(container.read(tourStoreProvider), isA<InMemoryTourStore>());
      expect(
        container.read(audioModeStoreProvider),
        isA<InMemoryAudioModeStore>(),
      );
      expect(
        container.read(languagePreferenceStoreProvider),
        isA<InMemoryLanguagePreferenceStore>(),
      );
      expect(
        container.read(activeHuntStoreProvider),
        isA<InMemoryActiveHuntStore>(),
      );
      expect(
        container.read(collectedFactsStoreProvider),
        isA<InMemoryCollectedFactsStore>(),
      );
    });

    test('der Jagd-Speicher meldet an die überschriebene Senke', () {
      // Der einzige der fünf, der `overrideWith` statt `overrideWithValue`
      // braucht, weil er die Diagnosesenke liest. Ohne `ref.watch` bekäme er
      // eine zweite, selbst gebaute Senke, und eine verworfene Nutzlast wäre
      // auf dem Gerät nicht zu sehen. Nachgewiesen über die erzeugte Zeile.
      final container = ProviderContainer(
        overrides: _scope(
          preferences: InMemoryKeyValueStore(<String, Object>{
            KeyValueActiveHuntStore.storageKey: 'kein json',
          }),
        ).overrides,
      );
      addTearDown(container.dispose);
      final lines = <String?>[];

      final ActiveHunt? restored = runZoned(
        () => container.read(activeHuntStoreProvider).readActiveHunt(),
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) =>
              lines.add(line),
        ),
      );

      expect(restored, isNull);
      expect(lines, <String>[
        'FACT-DIAG ${KeyValueActiveHuntStore.discardedEventName}',
      ]);
    });

    test('wertet Supabase beim Aufbau noch nicht aus', () {
      // `overrideWith` und nicht `overrideWithValue`: Letzteres bräuchte die
      // Instanz sofort, und die braucht `supabaseClientProvider`, der
      // `Supabase.instance.client` liest. Der Aufbau der Scope allein darf
      // deshalb nichts auswerten, sonst scheitert der Start, bevor
      // `bootstrap()` seine eigene Fehlermeldung zeigen kann.
      expect(() => _scope(), returnsNormally);
    });

    test('reicht das Kind unverändert durch', () {
      const child = SizedBox.shrink();

      expect(_scope(child: child).child, same(child));
    });
  });
}
