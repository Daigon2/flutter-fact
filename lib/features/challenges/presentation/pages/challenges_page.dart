import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platzhalter für den Challenge-Bildschirm
/// (`02_Frontend/app/screen-challenge.jsx`).
///
/// Existiert nur, damit der Zweig `/challenges` der Shell etwas anzeigt. Phase
/// 2 ersetzt den Inhalt dieser Datei vollständig.
class ChallengesPage extends ConsumerWidget {
  /// Erzeugt den Platzhalter.
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Text(ref.watch(appStringsProvider).text('tab.challenge')),
    );
  }
}
