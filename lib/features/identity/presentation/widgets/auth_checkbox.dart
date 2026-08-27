import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ein Kästchen mit Beschriftung,
/// `02_Frontend/app/screen-auth.jsx:133-148` (`AuthCheckbox`).
///
/// Der ganze Bereich ist antippbar, nicht nur das Kästchen: die Quelle setzt
/// `onClick` auf den umschließenden `<div>`.
///
/// Geteilter Baustein für Anmeldung und Registrierung (dort für die
/// Einwilligung).
class AuthCheckbox extends StatelessWidget {
  /// Erzeugt das Kästchen.
  const AuthCheckbox({
    required this.checked,
    required this.label,
    required this.onChanged,
    this.labelSpans,
    super.key,
  });

  /// Kantenlänge des Kästchens, `width/height: 20`.
  static const double boxSize = 20;

  /// `borderRadius: 6`.
  static const double cornerRadius = 6;

  /// `border: 1.5px solid` im nicht gesetzten Zustand.
  static const double borderWidth = 1.5;

  /// `gap: 10` zwischen Kästchen und Beschriftung.
  static const double gap = 10;

  /// Kantenlänge des Häkchens, `width/height: 12`.
  static const double checkSize = 12;

  /// `fontSize: 12` der Beschriftung.
  static const double labelFontSize = 12;

  /// `lineHeight: 1.45` der Beschriftung.
  static const double labelLineHeight = 1.45;

  /// Ob das Kästchen gesetzt ist.
  final bool checked;

  /// Die Beschriftung rechts.
  ///
  /// Auch dann gesetzt, wenn [labelSpans] gezeichnet wird: dann ist es die
  /// Fassung für Screenreader.
  final String label;

  /// Eine ausgezeichnete Beschriftung, wenn [label] nicht genügt.
  ///
  /// Genau ein Aufrufer: die Einwilligung der Registrierung setzt
  /// "Nutzungsbedingungen" und "Datenschutzerklärung" rot und fett
  /// (`screen-auth.jsx:782-784`).
  ///
  /// **Die beiden roten Teile sind in der Quelle keine Links.** Ein Tap darauf
  /// trifft den `onClick` des umschließenden `<div>` und kippt nur das Kästchen.
  /// Es gibt im PWA-Ordner eine `privacy.html`, die von hier **nicht** verlinkt
  /// ist. Deshalb nimmt dieser Parameter `InlineSpan` ohne Erkenner: ein
  /// `TapGestureRecognizer` bräuchte eine Lebensdauer-Verwaltung und würde
  /// Verhalten hinzufügen, das die Quelle nicht hat.
  final List<InlineSpan>? labelSpans;

  /// Wird beim Tippen aufgerufen. Die Quelle übergibt keinen neuen Wert, der
  /// Aufrufer kippt ihn selbst; hier genauso, damit der Zustand beim Besitzer
  /// bleibt.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    return Semantics(
      checked: checked,
      // Kein `button: true`: für einen Screenreader ist das ein Kontrollkästchen
      // und keine Aktion. Die Quelle sagt beides nicht, sie benutzt ein `<div>`
      // mit `onClick`; damit ist der Zustand dort gar nicht ansagbar.
      container: true,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        // Ohne das ist die Lücke zwischen Kästchen und Text nicht antippbar.
        behavior: HitTestBehavior.opaque,
        onTap: onChanged,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // `marginTop: 1` am Kästchen, damit es zur ersten Textzeile passt.
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _box(colors),
            ),
            const SizedBox(width: gap),
            Expanded(child: _label(colors)),
          ],
        ),
      ),
    );
  }

  Widget _label(FactColors colors) {
    final style = FactTypography.bodyText.copyWith(
      fontSize: labelFontSize,
      color: colors.ink2,
      height: labelLineHeight,
    );
    if (labelSpans case final List<InlineSpan> spans) {
      return Text.rich(TextSpan(children: spans), style: style);
    }
    return Text(label, style: style);
  }

  Widget _box(FactColors colors) {
    return Container(
      width: boxSize,
      height: boxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? colors.red : null,
        borderRadius: const BorderRadius.all(Radius.circular(cornerRadius)),
        border: Border.fromBorderSide(
          BorderSide(
            color: checked ? colors.red : colors.border2,
            width: borderWidth,
          ),
        ),
        // `boxShadow: '0 2px 0 #A82508'`, also `--red-dk`.
        boxShadow: checked
            ? <BoxShadow>[
                BoxShadow(color: colors.redDark, offset: const Offset(0, 2)),
              ]
            : const <BoxShadow>[],
      ),
      // Pfaddaten unverändert aus der Quelle, siehe die Begründung in
      // `app/shell/shell_tab_icon.dart`.
      child: checked
          ? SvgPicture.string(
              '<svg width="12" height="12" viewBox="0 0 12 12" fill="none">'
              '<path d="M2.5 6.5l2.5 2.5L9.5 3.5" stroke="#fff" '
              'stroke-width="2" stroke-linecap="round" '
              'stroke-linejoin="round"/></svg>',
              width: checkSize,
              height: checkSize,
            )
          : null,
    );
  }
}
