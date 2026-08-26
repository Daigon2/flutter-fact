import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platzhalter für die gesammelten Fakten
/// (`02_Frontend/app/screen-wallet.jsx`).
///
/// Existiert nur, damit der Zweig `/collection` der Shell etwas anzeigt. Phase
/// 1 ersetzt den Inhalt dieser Datei vollständig.
class CollectionPage extends ConsumerWidget {
  /// Erzeugt den Platzhalter.
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(child: Text(ref.watch(appStringsProvider).text('tab.facts')));
  }
}
