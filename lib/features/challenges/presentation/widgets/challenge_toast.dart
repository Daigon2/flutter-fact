import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Die kurze Meldung über dem Challenge-Reiter, `chalToast` in
/// `02_Frontend/app/screen-challenge.jsx:4408-4421`.
///
/// ## Warum es sie überhaupt gibt
///
/// Sie ist der Weg der Quelle, dem Nutzer einen Fehlschlag zu sagen, ohne ihn
/// aus dem Ablauf zu werfen. Gebraucht wird sie ab Schritt 35 für genau einen
/// Fall: der Routengenerator findet keine einzige Station, und der Nutzer
/// landet wieder im Assistenten (`:4347-4352`). Ohne Meldung sähe das aus wie
/// ein Knopf, der nichts tut.
///
/// Die drei anderen Aufrufer der Quelle (`:4429`, `:4433`, `:4437`) gehören
/// zum Gruppenpfad und existieren im Neubau nicht.
///
/// ## Kein `SnackBar`
///
/// Materials `SnackBar` sitzt unten, bringt eigene Farben, eine eigene
/// Einblendung und eine Aktionszeile mit. Diese Meldung sitzt oben, ist
/// mittig, hat einen goldenen Rand und keine Aktion. Der Nachbau ist kürzer
/// als das Zurechtbiegen.
class ChallengeToast extends StatelessWidget {
  /// Erzeugt die Meldung.
  const ChallengeToast({required this.message, super.key});

  /// Wie lange sie steht, `setTimeout(..., 2800)`, `:4166`.
  static const Duration visibleFor = Duration(milliseconds: 2800);

  /// `animation: 'factToastIn 0.25s ease-out'`, `:4417`.
  static const Duration fadeIn = Duration(milliseconds: 250);

  /// `top: 64`, `:4410`.
  ///
  /// Gemessen ab der Oberkante des Rahmens, und der beginnt in der PWA am
  /// oberen Bildschirmrand. Im Neubau ist das die Oberkante des Reiterinhalts;
  /// die Shell legt darüber nichts.
  static const double topOffset = 64;

  /// `maxWidth: 'calc(100% - 40px)'`, `:4416`.
  static const double horizontalInset = 20;

  /// `background: 'rgba(20,8,6,0.92)'`, `:4411`.
  static const Color background = Color.fromRGBO(20, 8, 6, 0.92);

  /// `border: '1px solid rgba(245,197,24,0.4)'`, `:4414`.
  static const Color borderColor = Color.fromRGBO(245, 197, 24, 0.4);

  /// `color: '#FDF5E8'`, `:4411`.
  static const Color textColor = Color(0xFFFDF5E8);

  /// Der Text.
  final String message;

  @override
  Widget build(BuildContext context) {
    // Der Startpunkt der Einblendung, `@keyframes factToastIn` in
    // `index.html:45`: zehn Pixel tiefer, auf 92 Prozent, unsichtbar.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: ChallengeToast.fadeIn,
      curve: Curves.easeOut,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ChallengeToast.background,
          // `borderRadius: 14`, `:4412`.
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: ChallengeToast.borderColor),
          boxShadow: const <BoxShadow>[
            // `0 8px 24px rgba(0,0,0,0.45)`, `:4415`.
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.45),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Padding(
          // `padding: '12px 18px'`, `:4412`.
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            // `fontFamily: 'Nunito', fontWeight: 800, fontSize: 13`, `:4413`.
            style: FactTypography.heading.copyWith(
              fontSize: 13,
              color: ChallengeToast.textColor,
            ),
          ),
        ),
      ),
    );
  }
}
