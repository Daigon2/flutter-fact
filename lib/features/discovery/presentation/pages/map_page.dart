import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platzhalter für den Karten-Bildschirm (`02_Frontend/app/screen-map.jsx`).
///
/// Existiert nur, damit der Zweig `/map` der Shell etwas anzeigt. Phase 1
/// ersetzt den Inhalt dieser Datei vollständig. Nichts hier ausbauen: was
/// wächst, wächst in der echten Umsetzung.
class MapPage extends ConsumerWidget {
  /// Erzeugt den Platzhalter.
  const MapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(child: Text(ref.watch(appStringsProvider).text('tab.map')));
  }
}
