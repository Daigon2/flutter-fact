import 'package:fact_app/services/supabase/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Zugang zu Supabase als Riverpod-Komposition (ADR-005). Der Vendor-Client
/// lebt laut ADR-001 in der Datenschicht und in `services/`, nirgends sonst.

/// Die Konfiguration dieses Builds.
///
/// Überschreibbar: Tests und ein späterer Stage-Schalter setzen hier eigene
/// Werte ein, ohne `--dart-define` zu brauchen.
final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => SupabaseConfig.fromEnvironment,
);

/// Der laufende Supabase-Client.
///
/// Setzt voraus, dass `initializeSupabase` im Bootstrap gelaufen ist. Ohne das
/// wirft der erste Zugriff. Das ist gewollt: ein stiller Ersatz-Client würde
/// Fehler in eine leere Faktenliste verwandeln, und genau das soll dieser
/// Schritt verhindern.
///
/// Tests überschreiben diesen Provider und berühren `Supabase.instance` nie.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final config = ref.watch(supabaseConfigProvider);
  config.ensureUsable();
  return Supabase.instance.client;
});
