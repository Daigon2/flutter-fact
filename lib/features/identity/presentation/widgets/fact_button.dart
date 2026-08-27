import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Der Standardknopf der PWA, CSS-Klasse `.btn` aus
/// `02_Frontend/app/styles.css:135-145`.
///
/// Einziger Ort auf diesem Bildschirm, der Theme-Tokens statt Literalen nutzt:
/// `.btn` arbeitet mit den CSS-Variablen `--red`, `--red-dk` und `--red-glow`,
/// also mit [FactColors.red], [FactColors.redDark] und [FactColors.redGlow].
/// Alles andere auf dem Startbildschirm zeichnet die Quelle mit literalen
/// Farben und themenunabhängig.
///
/// Liegt noch bei `identity` und nicht in `core/widgets`: laut
/// `docs/architecture/project-structure.md` zieht wiederverwendbare Oberfläche
/// erst nach belegter Wiederverwendung um. `.btn` wird in der PWA app-weit
/// benutzt, der zweite Aufrufer kommt also bald, und dann gehört diese Datei
/// nach `core/widgets`.
///
/// Die Maße von `.btn` selbst (`padding: 14px 22px`, `font-size: 16`) sind hier
/// überschreibbar, weil der Startbildschirm sie überschreibt
/// (`screen-auth.jsx:377`).
///
/// ## Gesperrt heißt hier: [onPressed] ist `null`
///
/// `.btn` selbst kennt keinen gesperrten Zustand; die Quelle setzt `disabled`
/// am Element und die Deckkraft **am Aufrufer** (`screen-auth.jsx:530`:
/// `opacity: loading ? 0.6 : 1`). Deshalb sperrt dieses Widget nur die
/// Bedienung samt Drück-Animation und Knopf-Semantik, und die Deckkraft bleibt
/// Sache des Aufrufers. Ein festverdrahteter Wert hier wäre eine Zahl aus einem
/// Bildschirm in einem Baustein, den mehrere Bildschirme benutzen.
class FactButton extends StatefulWidget {
  /// Erzeugt den Knopf.
  const FactButton({
    required this.label,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    this.fontSize = 16,
    this.letterSpacing,
    super.key,
  });

  /// Eckenradius, `border-radius: 16px`.
  static const double cornerRadius = 16;

  /// Wie weit der Knopf beim Drücken einsinkt, `:active { translateY(4px) }`.
  static const double pressDepth = 4;

  /// Dauer von `transition: transform 0.08s, box-shadow 0.08s`.
  static const Duration pressDuration = Duration(milliseconds: 80);

  /// Die Beschriftung.
  final String label;

  /// Was beim Tippen passiert, oder `null` für einen gesperrten Knopf.
  final VoidCallback? onPressed;

  /// Innenabstand, Standard ist der von `.btn`.
  final EdgeInsets padding;

  /// Schriftgröße, Standard ist die von `.btn`.
  final double fontSize;

  /// Laufweite in logischen Pixeln, falls der Aufrufer eine setzt.
  final double? letterSpacing;

  @override
  State<FactButton> createState() => _FactButtonState();
}

class _FactButtonState extends State<FactButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    // `box-shadow: 0 5px 0 var(--red-dk), 0 8px 20px var(--red-glow)` und im
    // gedrückten Zustand `0 1px 0 var(--red-dk), 0 2px 8px var(--red-glow)`.
    // Reihenfolge umgekehrt zur Quelle: CSS zeichnet den ersten Schatten vorne,
    // Flutter den letzten.
    final rest = <BoxShadow>[
      BoxShadow(
        color: colors.redGlow,
        offset: const Offset(0, 8),
        blurRadius: 20,
      ),
      BoxShadow(color: colors.redDark, offset: const Offset(0, 5)),
    ];
    final pressed = <BoxShadow>[
      BoxShadow(
        color: colors.redGlow,
        offset: const Offset(0, 2),
        blurRadius: 8,
      ),
      BoxShadow(color: colors.redDark, offset: const Offset(0, 1)),
    ];

    final onPressed = widget.onPressed;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Gesperrt auch ohne Drück-Animation: ein `onTap: null` allein würde
        // `onTapDown` weiter zustellen, der Knopf sänke also ein und täte
        // nichts. Das sieht wie ein Defekt aus.
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: onPressed,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _pressed ? 1 : 0),
          duration: FactButton.pressDuration,
          // CSS setzt als Zeitfunktion einer `transition` standardmäßig `ease`,
          // und `Curves.ease` ist genau `cubic-bezier(0.25, 0.1, 0.25, 1)`.
          curve: Curves.ease,
          builder: (context, t, _) => Transform.translate(
            offset: Offset(0, FactButton.pressDepth * t),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.red,
                borderRadius: const BorderRadius.all(
                  Radius.circular(FactButton.cornerRadius),
                ),
                boxShadow: BoxShadow.lerpList(rest, pressed, t),
              ),
              child: Padding(
                padding: widget.padding,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: FactTypography.emphasis.copyWith(
                    fontSize: widget.fontSize,
                    color: const Color(0xFFFFFFFF),
                    letterSpacing: widget.letterSpacing,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
