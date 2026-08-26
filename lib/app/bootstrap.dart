import 'package:fact_app/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Einziger Startpunkt der App. Alles, was vor dem ersten Frame passieren muss
/// (Supabase-Init, Locale-Laden, Fehler-Handler), gehört hierher und nicht in
/// einen Widget-Konstruktor.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: FactApp()));
}
