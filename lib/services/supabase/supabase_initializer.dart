import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Startet den Supabase-Client.
///
/// Aufrufer ist `app/bootstrap.dart`, vor dem ersten Frame. Diese Datei nimmt
/// die Verdrahtung bewusst nicht selbst vor: `lib/app/` gehört in dieser
/// Arbeitsteilung nicht zu diesem Schritt. Solange der Aufruf fehlt, wirft
/// `supabaseClientProvider` beim ersten Zugriff, und die Meldung sagt warum.
///
/// [config] wird zuerst geprüft. Ein fehlender `--dart-define`-Wert scheitert
/// hier mit [SupabaseConfigurationError] und nicht irgendwann später mit einem
/// unverständlichen Netzwerkfehler.
///
/// Mehrfachaufruf ist ungefährlich: `Supabase.initialize` erkennt eine bereits
/// laufende Instanz und kehrt zurück, ohne sie neu aufzusetzen.
Future<void> initializeSupabase(SupabaseConfig config) async {
  config.ensureUsable();
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
  );
}
