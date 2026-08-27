import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Die positive Meldung über dem Formular,
/// `02_Frontend/app/screen-auth.jsx:498-504`.
///
/// Das Gegenstück zu `AuthErrorBox`: gleiche Maße, gleiche Schrift, grün statt
/// rot, mit einem Häkchen vorweg. In der Quelle ist es kein eigenes Bauteil,
/// sondern der Block, der auf der Anmeldung die Bestätigung des
/// Passwort-Links zeigt.
///
/// ## Warum es diese Box im Neubau überhaupt gibt
///
/// Weil die Registrierung einen Satz zu zeigen hat, der in der Quelle in der
/// **roten Fehlerbox** landet: `signup.confirmEmailHint` ("Fast geschafft! Bitte
/// E-Mail bestätigen — wir haben dir einen Link gesendet."). Die Quelle hat dort
/// nur eine Zustandsvariable für Meldungen (`setError`), und deshalb bekommt ein
/// Erfolg die Optik eines Fehlers. Das ist keine Absicht, sondern eine
/// Einschränkung der Umsetzung, und sie ist hier nicht nachgebaut. Die Maße
/// stammen aus der Quelle, nur eben von der grünen Box statt der roten.
///
/// Die drei Farben stehen als Literale und nicht als Tokens, wie in der Quelle:
/// es gibt kein grünes Token in `FactColors`, und der Reset-Block schreibt sie
/// inline hin.
class AuthNoticeBox extends StatelessWidget {
  /// Erzeugt die Meldung.
  const AuthNoticeBox({required this.message, super.key});

  /// `margin: '0 0 14px'`, wie bei der Fehlerbox.
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

  /// `background: 'rgba(34,197,94,0.08)'`.
  static const Color background = Color.fromRGBO(34, 197, 94, 0.08);

  /// `border: '1px solid rgba(34,197,94,0.25)'`.
  static const Color borderColor = Color.fromRGBO(34, 197, 94, 0.25);

  /// `color: '#16A34A'`.
  static const Color textColor = Color(0xFF16A34A);

  /// Das Zeichen vor dem Text, in der Quelle als `✓ ` hartcodiert. Kein
  /// i18n-Schlüssel, keine Grafik.
  static const String prefix = '✓ ';

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
          '$prefix$message',
          style: FactTypography.bodyText.copyWith(
            fontSize: fontSize,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
