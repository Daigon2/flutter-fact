import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Die Fehlerbox über dem Formular,
/// `02_Frontend/app/screen-auth.jsx:150-157` (`AuthError`).
///
/// Sitzt als **erstes** Element im Formularblock, nicht neben dem Feld, das den
/// Fehler ausgelöst hat: die Quelle führt genau eine Fehlermeldung für den
/// ganzen Bildschirm.
///
/// Die drei Farben stehen als Literale und nicht als Tokens: die Quelle schreibt
/// sie inline hin, sie kommen nicht aus `useAuthTokens`. Nur die Textfarbe ist
/// ein Token (`t.red`).
///
/// Geteilter Baustein für Anmeldung und Registrierung.
class AuthErrorBox extends StatelessWidget {
  /// Erzeugt die Fehlerbox.
  const AuthErrorBox({required this.message, super.key});

  /// `margin: '0 0 14px'`.
  static const double bottomSpacing = 14;

  /// `padding: '10px 14px'`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );

  /// `borderRadius: 12`.
  static const double cornerRadius = 12;

  /// `fontSize: 13`.
  static const double fontSize = 13;

  /// `background: 'rgba(232,56,13,0.08)'`.
  static const Color background = Color.fromRGBO(232, 56, 13, 0.08);

  /// `border: '1px solid rgba(232,56,13,0.2)'`.
  static const Color borderColor = Color.fromRGBO(232, 56, 13, 0.2);

  /// Der Text. Kommt aus `AppStrings`, nie vom Backend.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomSpacing),
      child: Container(
        padding: padding,
        decoration: const BoxDecoration(
          color: background,
          borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
          border: Border.fromBorderSide(BorderSide(color: borderColor)),
        ),
        child: Text(
          message,
          style: FactTypography.bodyText.copyWith(
            fontSize: fontSize,
            color: context.factColors.red,
          ),
        ),
      ),
    );
  }
}
