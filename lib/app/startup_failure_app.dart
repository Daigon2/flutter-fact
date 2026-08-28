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
      // `Material` und nicht `ColoredBox`, und das ist keine Kosmetik. Am
      // 28.08.2026 auf dem Emulator gesehen, nicht im Test: beide Texte trugen
      // eine gelbe Doppellinie. Das ist Flutters Notsignal für Text ohne
      // `Material`-Vorfahren. `MaterialApp` legt unter der App einen
      // `DefaultTextStyle` mit genau dieser Dekoration (`_errorTextStyle` in
      // `material/app.dart`); erst ein `Material` ersetzt ihn durch den
      // Textstil des Themes. Ein `ColoredBox` tut das nicht. Die beiden Stile
      // unten setzen Farbe und Größe, aber keine `decoration`, deshalb
      // überlebt sie den Merge.
      //
      // Warum nicht `Scaffold`: der bringt eine ganze Maschinerie mit, die
      // selbst scheitern kann (ScaffoldMessenger, Drawer-Controller, Geometrie
      // für AppBar, FAB und BottomSheet), und genau das will der Kopfkommentar
      // hier vermeiden. Außerdem nähme er seine Fläche aus
      // `Theme.of(context).scaffoldBackgroundColor`, also aus dem hellen
      // Standard-Theme, weil diese `MaterialApp` bewusst kein `FactTheme`
      // installiert. `Material` ist das kleinste Widget, das beides zugleich
      // ist: Material-Vorfahre und Hintergrundfläche.
      home: Material(
        color: FactColors.dark.bg,
        // Der Basisstil ausdrücklich und nicht Materials Vorgabe. Gemessen:
        // ohne diese Zeile erben beide Texte aus `theme.textTheme.bodyMedium`
        // ein `letterSpacing: 0.25` und ein `height` von rund 1.43, das sie
        // vorher nicht hatten. E-38 nimmt genau diese Laufweite aus FACT-Text heraus, und
        // `FactTheme` tut das auch, aber hier greift es nicht: diese
        // `MaterialApp` installiert bewusst kein `FactTheme`, also stünde
        // Materials Standard-Geometrie da. Der Wert selbst überschreibt
        // nichts, was die beiden Stile unten setzen.
        textStyle: FactTypography.bodyText.copyWith(
          color: FactColors.dark.ink2,
        ),
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
