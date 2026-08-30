import 'package:fact_app/features/challenges/domain/value_objects/hunt_duration.dart';
import 'package:fact_app/features/challenges/presentation/widgets/challenge_setup_view.dart';
import 'package:fact_app/features/facts/domain/value_objects/fact_puzzle_difficulty.dart';
import 'package:flutter/material.dart';

/// Der Challenge-Reiter, `02_Frontend/app/screen-challenge.jsx`.
///
/// Zeigt den Assistenten. Mehr kann dieser Reiter heute nicht: die Quelle
/// wechselt nach dem Assistenten auf den Startpunkt-Picker (`:4325`), und
/// solange eine Jagd läuft, zeigt sie statt des Assistenten den Pause- oder
/// den Ergebnisbildschirm (`:4292-4317`). Beides ist noch nicht gebaut.
///
/// ## Die drei Rückrufe sind bewusst leer
///
/// Sie sind der einzige Ort, an dem der Assistent die App berührt, und alle
/// drei führen in Teile, die es nicht gibt: „Starten" in den Startpunkt-Picker
/// (Schritt 35), „Gruppe" und „Mit Code beitreten" in den Koop-Unterbau, von
/// dem im Neubau nichts existiert.
///
/// Ein Rückruf, der hier schon irgendwohin zeigte, müsste sich ein Ziel
/// ausdenken. Deshalb steht hier nichts, und
/// `test/features/challenges/presentation/pages/challenges_page_test.dart`
/// hält fest, dass nichts passiert: das ist heute die richtige Zusicherung
/// und wird zu der Stelle, die auffällt, sobald jemand Schritt 35 baut, ohne
/// sie zu verdrahten.
///
/// Deshalb ist die Seite ein `StatelessWidget` und kein `ConsumerWidget`: sie
/// liest keinen Provider. Der Assistent darunter tut es und ist deshalb einer.
/// Ein `ref`, das niemand benutzt, sieht nach Anbindung aus, wo keine ist.
class ChallengesPage extends StatelessWidget {
  /// Erzeugt die Seite.
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChallengeSetupView(
      onStart:
          (
            FactPuzzleDifficulty difficulty,
            HuntDuration duration,
            List<String> genreCodes,
          ) {
            // Schritt 35: Startpunkt wählen, dann `generateHuntRoute` rufen.
          },
      onGroupSelected: () {
        // Der Gruppenpfad braucht Koop-Sitzungen in Supabase.
      },
      onJoinRequested: () {
        // Der Beitritt mit Code prüft ihn gegen den Server.
      },
    );
  }
}
