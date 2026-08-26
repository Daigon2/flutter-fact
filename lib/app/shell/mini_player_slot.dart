import 'package:flutter/widgets.dart';

/// Reservierter Platz für den Audio-Mini-Player, direkt über der Tab-Leiste.
///
/// Heute leer und ohne Höhe. Der Zweck ist die Stelle, nicht der Inhalt: Phase
/// 3 füllt dieses Widget und muss dafür weder `AppShell` noch die Tab-Leiste
/// anfassen.
///
/// ## Maße aus der Quelle
///
/// `02_Frontend/app/mini-player.jsx:25-42`:
///
/// - Höhe 52
/// - horizontal 8px Rand (`calc(100vw - 16px)`)
/// - `borderRadius: 14`
/// - `boxShadow: '0 8px 24px rgba(0,0,0,0.18)'`
/// - `backdropFilter: blur(10px)`
/// - Fläche dunkel `rgba(20,20,20,0.95)`, hell `rgba(255,255,255,0.96)`
/// - Innenabstand `0 12px`, `gap: 10`
/// - Knopf 36x36, Radius 18, Fläche `--stamp`
/// - Titel Nunito 800, 13px, `letterSpacing: -0.005em`
/// - `state.fact == null` blendet den Player komplett aus (Zeile 14)
///
/// ## Eine bewusste Abweichung
///
/// In der PWA schwebt der Player über dem Inhalt (`position: absolute`,
/// `bottom: 64`, `zIndex: 200`) und überlappt dabei die oberen 14 Pixel der
/// Tab-Leiste, die von 14 bis 78 reicht. Hier sitzt der Platz statt dessen als
/// Zeile über der Leiste im unteren Rahmen des `Scaffold`.
///
/// Grund: so zählt seine Höhe automatisch in den unteren Freiraum, den
/// scrollende Seiten bekommen (siehe `AppShell`). Ein überlagernder Player
/// verdeckt sonst die letzte Zeile jeder Liste, und jede künftige Seite müsste
/// von ihm wissen. Wer die Überlappung der PWA doch will, ändert das in
/// `AppShell` und nicht in jeder Seite.
class MiniPlayerSlot extends StatelessWidget {
  /// Erzeugt den leeren Platz.
  const MiniPlayerSlot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
