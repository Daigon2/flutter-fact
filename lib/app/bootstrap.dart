import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/startup_failure_app.dart';
import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:fact_app/services/supabase/supabase_initializer.dart';
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
/// direkt und rufen `bootstrap` nie. `supabaseClientProvider` wird erst beim
/// ersten Lesen ausgewertet, also nur in Tests, die ihn selbst überschreiben.
/// Ohne `--dart-define` laufen die Tests deshalb unverändert.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeSupabase(SupabaseConfig.fromEnvironment);
  } on SupabaseConfigurationError catch (error) {
    runApp(StartupFailureApp(problem: error.toString()));
    return;
  }

  runApp(const ProviderScope(child: FactApp()));
}
