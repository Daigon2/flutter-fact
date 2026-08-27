import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Die Trennlinie mit "oder" in der Mitte,
/// `02_Frontend/app/screen-auth.jsx:123-131` (`AuthDivider`).
///
/// ## Der Text ist hartcodiert, weil er in der Quelle hartcodiert ist
///
/// `screen-auth.jsx:127` schreibt `oder` direkt ins Markup, nicht über
/// `window.t`. Es gibt dafür **keinen** i18n-Schlüssel, und dieser Schritt legt
/// keinen neuen an. Auf Englisch steht hier deshalb ebenfalls "oder", genau wie
/// in der PWA. Das ist einer der belegten i18n-Löcher der Vorlage, nicht ein
/// Versehen beim Portieren.
///
/// Geteilter Baustein für Anmeldung und Registrierung.
class AuthDivider extends StatelessWidget {
  /// Erzeugt die Trennlinie.
  const AuthDivider({super.key});

  /// `margin: '14px 0'`.
  static const double verticalSpacing = 14;

  /// `gap: 12`.
  static const double gap = 12;

  /// `fontSize: 9`.
  static const double fontSize = 9;

  /// Der Text, hartcodiert wie in der Quelle.
  static const String label = 'oder';

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    final line = Expanded(
      child: SizedBox(height: 1, child: ColoredBox(color: colors.border2)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalSpacing),
      child: Row(
        children: <Widget>[
          line,
          const SizedBox(width: gap),
          Text(
            label.toUpperCase(),
            style: FactTypography.mono.copyWith(
              fontSize: fontSize,
              color: colors.ink3,
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(width: gap),
          line,
        ],
      ),
    );
  }
}
