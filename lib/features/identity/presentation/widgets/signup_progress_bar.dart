import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:flutter/widgets.dart';

/// Die zweiteilige Fortschrittsleiste der Registrierung,
/// `02_Frontend/app/screen-auth.jsx:768-772`.
///
/// ## Beide Segmente sind statisch
///
/// Das erste ist immer rot, das zweite immer leer. Es gibt keinen Zustand, der
/// sie umschaltet, und keinen zweiten Schritt, zu dem der Balken führen würde:
/// die Registrierung ist ein einziges Formular. In der Quelle ist das ein
/// Versprechen der Optik ("Schritt 1 von 2"), das die Umsetzung nicht hält.
/// Nachgebaut, weil es sichtbarer Teil des Bildschirms ist; ein zweiter Schritt
/// wäre neues Verhalten und braucht eine Entscheidung.
///
/// Deshalb nimmt dieses Widget auch keinen Parameter: ein `step`-Argument, das
/// nur einen Wert annehmen kann, wäre ein Vorbau ohne Aufrufer.
class SignupProgressBar extends StatelessWidget {
  /// Erzeugt die Leiste.
  const SignupProgressBar({super.key});

  /// `padding: '14px 20px 0'`.
  static const EdgeInsets padding = EdgeInsets.only(
    left: 20,
    right: 20,
    top: 14,
  );

  /// `height: 5` je Segment.
  static const double segmentHeight = 5;

  /// `borderRadius: 3`.
  static const double cornerRadius = 3;

  /// `gap: 5`.
  static const double gap = 5;

  /// `boxShadow: '0 0 8px rgba(232,56,13,0.5)'` am ersten Segment.
  ///
  /// Literal und kein Token: die Quelle schreibt die Farbe inline hin. `--red-
  /// glow` hätte 0.38, das ist ein anderer Wert.
  static const Color glowColor = Color.fromRGBO(232, 56, 13, 0.5);

  /// Weichzeichnung des Scheins.
  static const double glowBlur = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.red,
                borderRadius: const BorderRadius.all(
                  Radius.circular(cornerRadius),
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: glowColor, blurRadius: glowBlur),
                ],
              ),
              child: const SizedBox(height: segmentHeight),
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: DecoratedBox(
              // `tok.card2`, also `--surface-3`.
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: const BorderRadius.all(
                  Radius.circular(cornerRadius),
                ),
              ),
              child: const SizedBox(height: segmentHeight),
            ),
          ),
        ],
      ),
    );
  }
}
