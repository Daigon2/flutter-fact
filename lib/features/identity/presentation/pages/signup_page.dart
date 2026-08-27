import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platzhalter für die Registrierung (`02_Frontend/app/screen-auth.jsx:569-810`).
///
/// Existiert nur, damit der erste Knopf des Startbildschirms ein Ziel hat.
/// Schritt 10 von 50 ersetzt den Inhalt dieser Datei vollständig, samt Formular,
/// Fehlerbehandlung und dem Setzen der Erstlauf-Merkung nach erfolgreicher
/// Registrierung. Nichts hier ausbauen: was wächst, wächst in der echten Umsetzung.
class SignupPage extends ConsumerWidget {
  /// Erzeugt den Platzhalter.
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Text(
          ref.watch(appStringsProvider).text('splash.createAccountCta'),
        ),
      ),
    );
  }
}
