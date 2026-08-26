import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platzhalter für den Profil-Bildschirm
/// (`02_Frontend/app/screen-profil.jsx`).
///
/// Existiert nur, damit der Zweig `/profile` der Shell etwas anzeigt. Phase 2
/// ersetzt den Inhalt dieser Datei vollständig.
class ProfilePage extends ConsumerWidget {
  /// Erzeugt den Platzhalter.
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Text(ref.watch(appStringsProvider).text('tab.profil')),
    );
  }
}
