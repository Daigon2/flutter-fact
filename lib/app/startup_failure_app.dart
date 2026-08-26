import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';

/// Vollbild-Meldung, wenn der Start abgebrochen ist, bevor die App überhaupt
/// laufen konnte.
///
/// Warum ein Bildschirm und kein Absturz: siehe die Begründung in
/// `app/bootstrap.dart`.
///
/// ## Warum der Text nicht aus `AppStrings` kommt
///
/// Zwei Gründe, beide belegbar. Erstens ist das dieselbe Sorte Text wie
/// `SupabaseConfig.missingRequirements`, und dort steht die Entscheidung schon:
/// technische Diagnose für Entwickler, kein Oberflächentext. Zweitens entstehen
/// die 716 Schlüssel je Sprache mit `tool/generate_i18n.dart` aus
/// `02_Frontend/app/translations.jsx`. Ein hier erfundener Schlüssel hätte dort
/// keine Entsprechung und würde beim nächsten Lauf des Werkzeugs verschwinden.
///
/// Der Bildschirm erscheint nur in einem Build ohne `--dart-define`. Ein
/// solcher Build ist für Nutzer ohnehin unbrauchbar.
class StartupFailureApp extends StatelessWidget {
  /// [problem] ist die technische Meldung, typischerweise
  /// `SupabaseConfigurationError.toString()`.
  const StartupFailureApp({required this.problem, super.key});

  /// Was den Start verhindert hat.
  final String problem;

  @override
  Widget build(BuildContext context) {
    // Bewusst ohne Routing, ohne Riverpod und ohne Lokalisierung: was hier
    // läuft, soll von möglichst wenig abhängen, das selbst kaputt sein könnte.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: FactColors.dark.bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'FACT konnte nicht starten',
                  style: FactTypography.heading.copyWith(
                    fontSize: 22,
                    color: FactColors.dark.red,
                  ),
                ),
                const SizedBox(height: 16),
                // Auswählbar, damit der Befehl aus der Meldung kopierbar ist.
                SelectableText(
                  problem,
                  style: FactTypography.mono.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: FactColors.dark.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
