import 'dart:ui' as ui;

import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:flutter/widgets.dart';

/// Die beiden durchscheinenden Knöpfe unter dem Hauptknopf des
/// Startbildschirms.
///
/// Zwei benannte Konstruktoren statt sechs Parametern am Aufrufort: so stehen
/// die Zahlen aus der Quelle an einer Stelle und die Aufrufe bleiben lesbar.
///
/// Beide haben in der Quelle **keinen** `:active`-Zustand, anders als `.btn`.
/// Hier sinkt deshalb nichts ein.
class SplashGhostButton extends StatelessWidget {
  /// "Anmelden", `screen-auth.jsx:380-389`.
  const SplashGhostButton.secondary({
    required this.label,
    required this.onPressed,
    super.key,
  }) : padding = const EdgeInsets.all(14),
       background = const Color.fromRGBO(255, 255, 255, 0.08),
       borderColor = const Color.fromRGBO(255, 255, 255, 0.15),
       cornerRadius = 16,
       fontSize = 16,
       textColor = const Color(0xFFFFFFFF);

  /// "Ohne Konto erkunden", `screen-auth.jsx:393-404`.
  const SplashGhostButton.tertiary({
    required this.label,
    required this.onPressed,
    super.key,
  }) : padding = const EdgeInsets.all(12),
       background = const Color.fromRGBO(255, 255, 255, 0.12),
       borderColor = const Color.fromRGBO(255, 255, 255, 0.28),
       cornerRadius = 14,
       fontSize = 15,
       textColor = const Color.fromRGBO(255, 255, 255, 0.92);

  /// Rahmenstärke, `border: 1.5px solid …` in beiden Fällen.
  static const double borderWidth = 1.5;

  /// `backdropFilter: 'blur(8px)'` in beiden Fällen.
  static const double backdropBlurSigma = 8;

  /// Die Beschriftung.
  final String label;

  /// Was beim Tippen passiert.
  final VoidCallback onPressed;

  /// Innenabstand.
  final EdgeInsets padding;

  /// Füllfarbe.
  final Color background;

  /// Rahmenfarbe.
  final Color borderColor;

  /// Eckenradius.
  final double cornerRadius;

  /// Schriftgröße.
  final double fontSize;

  /// Schriftfarbe.
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.all(Radius.circular(cornerRadius));
    return SplashPressable(
      onPressed: onPressed,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: backdropBlurSigma,
            sigmaY: backdropBlurSigma,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: background,
              borderRadius: radius,
              border: Border.fromBorderSide(
                BorderSide(color: borderColor, width: borderWidth),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: FactTypography.heading.copyWith(
                fontSize: fontSize,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
