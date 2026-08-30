import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Der Standardknopf der PWA, CSS-Klasse `.btn` aus
/// `02_Frontend/app/styles.css:135-145`.
///
/// `.btn` arbeitet mit den CSS-Variablen `--red`, `--red-dk` und `--red-glow`,
/// also mit [FactColors.red], [FactColors.redDark] und [FactColors.redGlow].
/// Auf dem Startbildschirm, für den der Knopf entstanden ist, war er damit die
/// einzige Stelle mit Tokens statt Literalen.
///
/// ## Der Umzug nach `core/widgets` ist eingetreten, nicht vorweggenommen
///
/// Diese Datei lag bis Schritt 33 unter `identity/presentation/widgets/`, mit
/// dem Vermerk, dass `docs/architecture/project-structure.md` einen Umzug erst
/// **nach belegter Wiederverwendung** vorsieht. Der Beleg ist der Startknopf
/// des Schnitzeljagd-Assistenten (`02_Frontend/app/screen-challenge.jsx:1979`,
/// `className="btn"`): ein vierter Aufrufer, und der erste außerhalb von
/// `identity`.
///
/// Der Umzug war damit nicht optional, und das ist gemessen und nicht
/// hergeleitet. Eine Wegwerf-Probe unter
/// `lib/features/challenges/presentation/`, die
/// `identity/presentation/widgets/auth_field.dart` importiert, lässt
/// `dart run tool/check_architecture.dart` mit **Exit-Code 1** abbrechen:
///
/// > Regel 8: presentation von "identity" darf nur dieses Feature selbst
/// > importieren, außerhalb davon nur die App-Komposition unter lib/app/
///
/// Es ist also **Regel 8** und nicht Regel 10, und die Maschine fängt es. Der
/// Wortlaut der Regel steht in `dependency-rules.md:54`: „Nobody outside a
/// feature may import that feature's `presentation` directory." Die zweite
/// Bedingung des Dokuments ist ebenfalls erfüllt: der Knopf trägt keine
/// fachliche Bedeutung, nur die Optik von `.btn`.
///
/// ## Warum er nicht mehr `FactButton` heißt
///
/// Regel 11 verbietet unterhalb von `core/` jeden Geschäftsbegriff im Pfad und
/// prüft das an den Wortbestandteilen des Dateinamens. `fact_button.dart` fiel
/// damit über den Begriff „fact", obwohl der Knopf nach der **App** benannt
/// war und nicht nach der Entität; der Prüfer sieht diesen Unterschied nicht
/// und soll ihn auch nicht sehen müssen. Statt die Wache für einen Fehlalarm
/// aufzuweichen, hat der Knopf einen Namen bekommen, der sagt, was er ist. Die
/// Prüfung sieht nur Pfade, der Klassenname ist trotzdem mitgewandert: zwei
/// Namen für dieselbe Sache wären der schlechtere Zustand.
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
class PrimaryButton extends StatefulWidget {
  /// Erzeugt den Knopf.
  const PrimaryButton({
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
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
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
          duration: PrimaryButton.pressDuration,
          // CSS setzt als Zeitfunktion einer `transition` standardmäßig `ease`,
          // und `Curves.ease` ist genau `cubic-bezier(0.25, 0.1, 0.25, 1)`.
          curve: Curves.ease,
          builder: (context, t, _) => Transform.translate(
            offset: Offset(0, PrimaryButton.pressDepth * t),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.red,
                borderRadius: const BorderRadius.all(
                  Radius.circular(PrimaryButton.cornerRadius),
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
