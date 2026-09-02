import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/onboarding/key_value_tour_store.dart';
import 'package:fact_app/app/onboarding/onboarding_providers.dart';
import 'package:fact_app/app/startup_failure_app.dart';
import 'package:fact_app/core/diagnostics/diagnostics_providers.dart';
import 'package:fact_app/core/preferences/key_value_store.dart';
import 'package:fact_app/features/challenges/application/active_hunt_providers.dart';
import 'package:fact_app/features/challenges/data/key_value_active_hunt_store.dart';
import 'package:fact_app/features/facts/application/collected_facts_providers.dart';
import 'package:fact_app/features/facts/application/fact_providers.dart';
import 'package:fact_app/features/facts/data/key_value_collected_facts_store.dart';
import 'package:fact_app/features/facts/data/repositories/supabase_fact_repository.dart';
import 'package:fact_app/features/identity/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:fact_app/features/identity/data/key_value_first_launch_store.dart';
import 'package:fact_app/features/identity/data/repositories/supabase_auth_repository.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/features/identity/presentation/notifiers/first_launch_providers.dart';
import 'package:fact_app/features/settings/application/audio_mode_providers.dart';
import 'package:fact_app/features/settings/data/key_value_audio_mode_store.dart';
import 'package:fact_app/features/settings/data/key_value_language_preference_store.dart';
import 'package:fact_app/services/audio/audioplayers_tone_service.dart';
import 'package:fact_app/services/audio/tone_providers.dart';
import 'package:fact_app/services/diagnostics/console_diagnostic_sink.dart';
import 'package:fact_app/services/location/geolocator_location_service.dart';
import 'package:fact_app/services/location/location_providers.dart';
import 'package:fact_app/services/preferences/shared_preferences_key_value_store.dart';
import 'package:fact_app/services/speech/flutter_tts_speech_service.dart';
import 'package:fact_app/services/speech/speech_providers.dart';
import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:fact_app/services/supabase/supabase_initializer.dart';
import 'package:fact_app/services/supabase/supabase_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Einziger Startpunkt der App. Alles, was vor dem ersten Frame passieren muss
/// (Supabase-Init, Locale-Laden, Fehler-Handler), gehört hierher und nicht in
/// einen Widget-Konstruktor.
///
/// ## Was ohne Supabase-Konfiguration passiert
///
/// Die App startet **nicht**. Statt dessen erscheint [StartupFailureApp] mit
/// der Meldung aus [SupabaseConfigurationError], die den vollständigen
/// `--dart-define`-Befehl enthält.
///
/// Die beiden verworfenen Alternativen und warum:
///
/// - *Harter Abbruch*, also die Ausnahme aus `bootstrap` herauslassen. Die
///   Meldung landet dann nur auf der Konsole. Auf einem angeschlossenen Gerät
///   sieht man sie, in einem Release-Build, über TestFlight oder auf dem Handy
///   eines Kollegen nicht. Sichtbar wäre nur eine App, die beim Start
///   verschwindet. Das ist dieselbe Information wie vorher, nur schlechter
///   auffindbar.
/// - *Trotzdem starten* und Supabase später scheitern lassen. Genau davor
///   warnt `services/supabase/supabase_providers.dart`: aus einem Startfehler
///   würde eine leere Faktenliste, und der eigentliche Grund verschwindet.
///
/// Gefangen wird ausschließlich [SupabaseConfigurationError]. Jeder andere
/// Fehler beim Start bleibt ein Absturz, weil er nichts ist, wofür es eine
/// vorbereitete Erklärung gibt.
///
/// `flutter test` ist davon nicht betroffen: Widget-Tests bauen `FactApp`
/// direkt und rufen `bootstrap` nie, sehen also die Standardimplementierungen
/// der Feature-Provider statt der Overrides aus [productionProviderScope].
/// `supabaseClientProvider` wird erst beim ersten Lesen ausgewertet, also nur in
/// Tests, die ihn selbst überschreiben. Ohne `--dart-define` laufen die Tests
/// deshalb unverändert.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeSupabase(SupabaseConfig.fromEnvironment);
  } on SupabaseConfigurationError catch (error) {
    runApp(StartupFailureApp(problem: error.toString()));
    return;
  }

  // Der Gerätespeicher wird **einmal** geladen, vor `runApp`. Das ist die
  // Bedingung dafür, dass die fünf Speicher synchron lesen dürfen: ihre
  // Verträge begründen das je einzeln, und die Begründung lautet überall, dass
  // `bootstrap()` vorlädt und den Provider überschreibt.
  //
  // Die Senke wird hier ein zweites Mal gebaut und ist trotzdem dieselbe:
  // `diagnosticSinkForBuild` liefert eine `const`-Instanz, Dart kanonisiert
  // sie, und `productionProviderScope` bekommt damit identisch dasselbe Objekt.
  // Ohne die Senke hier wäre ein gescheiterter Ladevorgang die einzige Stelle
  // des Starts, die niemandem etwas sagt.
  final KeyValueStore preferences = await loadKeyValueStore(
    sink: diagnosticSinkForBuild(debugBuild: kDebugMode),
  );

  runApp(
    productionProviderScope(preferences: preferences, child: const FactApp()),
  );
}

/// Die `ProviderScope` der laufenden App: [child] plus alles, was der Betrieb
/// anders macht als der Test.
///
/// ## Warum das eine benannte Funktion ist und nicht inline in [bootstrap]
///
/// Damit ein Test sie prüfen kann. Die Standardimplementierungen der Feature-
/// Provider sind absichtlich still und untätig (`unavailableAuthRepository`),
/// und ein stiller Standard ohne Netz ist ein Risiko: fehlt der Override hier,
/// startet die App, sieht heil aus, und niemand kann sich anmelden. Der Test
/// dazu steht in `test/app/bootstrap_test.dart` und liest `overrides` aus dem
/// Ergebnis.
///
/// Zurückgegeben wird die ganze `ProviderScope` und nicht die Liste: der Typ
/// `Override` ist aus `flutter_riverpod 3.4.2` **nicht exportiert**
/// (`flutter_riverpod.dart`, `show`-Liste), eine Funktion mit dem Rückgabetyp
/// `List<Override>` ist also nicht schreibbar. Über das Feld
/// `ProviderScope.overrides` kommt ein Test trotzdem an die Liste.
///
/// ## Warum `overrideWith` und nicht `overrideWithValue`
///
/// `overrideWithValue` bräuchte die Instanz **jetzt**, und die braucht
/// `supabaseClientProvider`, der `Supabase.instance.client` liest. Der Wert
/// würde also beim Start ausgewertet, statt beim ersten Zugriff. `overrideWith`
/// bleibt faul: solange niemand die Anmeldung anfasst, entsteht nichts.
/// Vorbild ist `factRemoteDataSourceProvider`.
///
/// ## Warum [preferences] ein Pflichtparameter ist
///
/// Weil ein Standardwert hier genau den Ausfall baute, gegen den diese Funktion
/// samt Test überhaupt existiert. Ein `KeyValueStore preferences =
/// InMemoryKeyValueStore()` wäre bequem und würde bedeuten: wer den Aufruf in
/// [bootstrap] einmal falsch ergänzt, bekommt eine App, die startet, heil
/// aussieht und sich nichts merkt. Dasselbe Muster wie bei
/// `unavailableAuthRepository`, nur ohne Fehlermeldung.
///
/// Der Preis ist, dass jeder Testaufruf den Speicher mitgeben muss. Das ist der
/// richtige Preis: er ist einmal zu zahlen und im Test sichtbar.
///
/// ## Warum die Kette hier steht und nicht neben der Implementierung
///
/// `dependency-rules.md` gibt der App-Komposition Zugriff auf "all public
/// feature entry points and services", und nur ihr. Ein Provider neben der
/// Supabase-Implementierung wäre für `presentation` unerreichbar (Regel: kein
/// Import aus `data`) und damit eine Falle für den nächsten Aufrufer.
ProviderScope productionProviderScope({
  required Widget child,
  required KeyValueStore preferences,
}) {
  return ProviderScope(
    overrides: [
      // Ohne diesen Override bleibt `SilentDiagnosticSink` stehen, und die
      // nimmt jedes Ereignis an und verwirft es. Das ist der teuerste stille
      // Ausfall der drei hier, weil er die anderen unsichtbar macht: eine
      // verworfene Kameraabsicht, eine unbekannte Stil-Kennung und eine
      // gescheiterte Projektion melden sich alle nur über diese Senke.
      //
      // `overrideWithValue` und nicht `overrideWith`: die Senke braucht weder
      // Supabase noch sonst einen Provider, es gibt also nichts, was faul
      // bleiben müsste.
      diagnosticSinkProvider.overrideWithValue(
        diagnosticSinkForBuild(debugBuild: kDebugMode),
      ),
      authRepositoryProvider.overrideWith(
        (ref) => SupabaseAuthRepository(
          SupabaseAuthRemoteDataSource(ref.watch(supabaseClientProvider)),
        ),
      ),
      // Ohne diesen Override bleibt der Standard stehen, und der liefert nie
      // eine Position: die Karte stünde für immer auf der Rückfallstadt, ohne
      // Fehler und ohne Meldung. Das ist derselbe stille Ausfall wie bei der
      // Anmeldung, deshalb prüft `test/app/bootstrap_test.dart` auch diesen
      // Eintrag.
      locationServiceProvider.overrideWith(
        (ref) => const GeolocatorLocationService(),
      ),
      // Der Sprachdienst, und ohne diesen Override ist der Audio-Modus
      // wieder ein Schalter ohne Wirkung: `unavailableSpeechService`
      // schweigt, ohne Fehler und ohne Meldung. Dasselbe Muster wie beim
      // Ortungsdienst zwei Zeilen darüber, deshalb steht auch dieser Eintrag
      // in `test/app/bootstrap_test.dart`.
      //
      // **Mit `ref.onDispose`**, anders als die Dienste davor. Die beiden
      // anderen halten nichts, was aufzuräumen wäre; dieser hält einen
      // Ereignisstrom und die laufende Sprachausgabe. Ohne das Aufräumen
      // spricht die App nach dem Entsorgen ihrer Scope weiter.
      speechServiceProvider.overrideWith((ref) {
        final FlutterTtsSpeechService service = FlutterTtsSpeechService();
        ref.onDispose(service.dispose);
        return service;
      }),
      // Der Hinweiston des Audio-Modus. Ohne diesen Override bleibt der
      // Beacon stumm und spricht nur; mit `ref.onDispose` aus demselben
      // Grund wie beim Sprachdienst, der Adapter hält einen Plattform-Spieler.
      toneServiceProvider.overrideWith((ref) {
        final AudioplayersToneService service = AudioplayersToneService();
        ref.onDispose(service.dispose);
        return service;
      }),
      // Der Standard `unavailableFactRepository` wirft, statt eine leere Liste
      // zu liefern, und genau deshalb ist dieser Override kein stiller Ausfall
      // mehr, sondern ein sichtbarer. Er steht trotzdem im Test, weil ohne ihn
      // die Karte leer bliebe und der Fehler erst am Gerät sichtbar würde.
      //
      // `overrideWith` und nicht `overrideWithValue`, wie oben: der Provider
      // daneben braucht den Supabase-Client, und der entsteht erst beim ersten
      // Zugriff.
      factRepositoryProvider.overrideWith(
        (ref) => ref.watch(supabaseFactRepositoryProvider),
      ),
      // Die sechs Speicher. Ohne diese Overrides bleiben die flüchtigen
      // Standards stehen, und dann tut die App vier Unbequemlichkeiten und
      // **zwei** echte Schäden: Startbildschirm, Tutorial, Sprachauswahl und
      // Audio-Modus kämen bei jedem Start zurück, eine laufende Jagd wäre
      // nach einem Neustart weg, und **die eingesammelten Fakten wären es
      // auch**. Den Jagd-Fall schließt ADR-007 als Produktvorgabe aus, und
      // der Sammel-Fall ist derselbe Schaden an der Kernhandlung der App:
      // man geht hin, sammelt, und am nächsten Tag war man nie dort.
      //
      // Jeder der sechs Verträge hat diesen Weg vorgeschrieben: „Wer später
      // persistiert, lädt in `bootstrap()` vor und überschreibt den Provider
      // mit einer gefüllten Implementierung." Dies ist diese Stelle.
      //
      // `overrideWithValue` und nicht `overrideWith` bei den ersten vier: die
      // Instanzen brauchen nur [preferences], das schon geladen ist. Es gibt
      // nichts, was faul bleiben müsste.
      firstLaunchStoreProvider.overrideWithValue(
        KeyValueFirstLaunchStore(preferences),
      ),
      tourStoreProvider.overrideWithValue(KeyValueTourStore(preferences)),
      audioModeStoreProvider.overrideWithValue(
        KeyValueAudioModeStore(preferences),
      ),
      languagePreferenceStoreProvider.overrideWithValue(
        KeyValueLanguagePreferenceStore(preferences),
      ),
      // Die letzten zwei brauchen `overrideWith`, und zwar nicht aus
      // Faulheit, sondern weil sie die Diagnosesenke brauchen. Über
      // `ref.watch` bekommen sie die **überschriebene** Senke aus dem Eintrag
      // ganz oben; eine hier direkt gebaute wäre eine zweite Wahrheit
      // darüber, wohin Meldungen gehen.
      activeHuntStoreProvider.overrideWith(
        (ref) => KeyValueActiveHuntStore(
          preferences,
          sink: ref.watch(diagnosticSinkProvider),
        ),
      ),
      collectedFactsStoreProvider.overrideWith(
        (ref) => KeyValueCollectedFactsStore(
          preferences,
          sink: ref.watch(diagnosticSinkProvider),
        ),
      ),
    ],
    child: child,
  );
}
