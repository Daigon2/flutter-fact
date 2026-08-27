import 'package:fact_app/app/app.dart';
import 'package:fact_app/app/startup_failure_app.dart';
import 'package:fact_app/features/identity/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:fact_app/features/identity/data/repositories/supabase_auth_repository.dart';
import 'package:fact_app/features/identity/presentation/notifiers/auth_providers.dart';
import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:fact_app/services/supabase/supabase_initializer.dart';
import 'package:fact_app/services/supabase/supabase_providers.dart';
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

  runApp(productionProviderScope(child: const FactApp()));
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
/// ## Warum die Kette hier steht und nicht neben der Implementierung
///
/// `dependency-rules.md` gibt der App-Komposition Zugriff auf "all public
/// feature entry points and services", und nur ihr. Ein Provider neben der
/// Supabase-Implementierung wäre für `presentation` unerreichbar (Regel: kein
/// Import aus `data`) und damit eine Falle für den nächsten Aufrufer.
ProviderScope productionProviderScope({required Widget child}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWith(
        (ref) => SupabaseAuthRepository(
          SupabaseAuthRemoteDataSource(ref.watch(supabaseClientProvider).auth),
        ),
      ),
    ],
    child: child,
  );
}
