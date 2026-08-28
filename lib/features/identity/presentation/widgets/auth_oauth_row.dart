import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';

/// Die beiden Fremdanmeldungen, `02_Frontend/app/screen-auth.jsx:534-543`.
///
/// **Beide Knöpfe sind abgeschaltet**, in der Quelle genauso (`disabled`,
/// `cursor: 'not-allowed'`, `opacity: 0.45`). Es gibt hinter ihnen keine
/// Implementierung, und dieser Schritt baut keine: OAuth wäre eine
/// Auth-Änderung mit eigenen Deep-Link-Verträgen.
///
/// Der Hinweis `auth.comingSoon` steht in der Quelle als `title`, also als
/// Tooltip, der beim Zeigen mit der Maus erscheint. Auf einem Touchgerät zeigt
/// ihn niemand an. Er wandert deshalb in die Semantik, wo ein Screenreader ihn
/// vorliest, statt als Langdruck-Tooltip erfunden zu werden: das wäre neue
/// Bedienung, die die Quelle nicht hat.
///
/// Geteilter Baustein für Anmeldung und Registrierung.
class AuthOAuthRow extends StatelessWidget {
  /// [appleLabel] ist `auth.appleSoon`, [googleLabel] ist `auth.googleSoon`,
  /// [comingSoonHint] ist `auth.comingSoon`.
  const AuthOAuthRow({
    required this.appleLabel,
    required this.googleLabel,
    required this.comingSoonHint,
    super.key,
  });

  /// `gap: 10`.
  static const double gap = 10;

  /// `padding: '12px'`.
  static const EdgeInsets padding = EdgeInsets.all(12);

  /// `borderRadius: 14`.
  static const double cornerRadius = 14;

  /// `fontSize: 14`.
  static const double fontSize = 14;

  /// `opacity: 0.45`.
  static const double disabledOpacity = 0.45;

  /// `boxShadow: '0 2px 0 rgba(0,0,0,0.15)'`.
  static const Color shadowColor = Color.fromRGBO(0, 0, 0, 0.15);

  /// Beschriftung des Apple-Knopfes.
  final String appleLabel;

  /// Beschriftung des Google-Knopfes.
  final String googleLabel;

  /// Was ein Screenreader zusätzlich ansagt.
  final String comingSoonHint;

  @override
  Widget build(BuildContext context) {
    // `background: tok.isLight ? '#000' : '#fff'` und die Textfarbe umgekehrt.
    // Die App läuft hell (`app.dart`), also schwarze Fläche mit weißem Text.
    // Abgefragt wird trotzdem die Helligkeit des Themes und nicht die
    // Startannahme, damit ein späterer Theme-Schalter das hier nicht bricht.
    final isLight = Theme.of(context).brightness == Brightness.light;
    return IntrinsicHeight(
      child: Row(
        // `display: flex` steht in CSS auf `align-items: stretch`, die Knöpfe
        // sind dort also immer gleich hoch. Flutters Standard ist `center`, und
        // damit steht bei großer Systemschrift ein einzeiliger Knopf mittig
        // neben einem zweizeiligen. Gemessen bei 390 und Skalierung 2.0:
        // "Mit Apple" 64 Pixel hoch, "Mit Google" 104. Bei Skalierung 1.0
        // ändert das hier nichts, dort sind beide 44.
        //
        // Die vier Zahlen sind vom 28.08.2026 und damit von vor der
        // Zeilenhöhen-Korrektur im Theme. Heute misst der Test bei Skalierung
        // 2.0 100 statt 104 und bei 1.0 43 statt 44; die Aussage bleibt
        // dieselbe. Herleitung in `auth_oauth_row_test.dart`.
        //
        // `IntrinsicHeight` ist dabei **nicht** optional. Beide Bildschirme
        // stellen diese Zeile in ein `SingleChildScrollView`, die Höhe ist dort
        // also unbeschränkt. `CrossAxisAlignment.stretch` gibt seinen Kindern
        // `BoxConstraints.tightFor(height: constraints.maxHeight)`, und das
        // wäre `Infinity`. Gemessen, nicht befürchtet: ohne diesen Rahmen wirft
        // jeder Aufbau der Anmeldung
        // `BoxConstraints forces an infinite height`.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _button(
              label: appleLabel,
              background: isLight
                  ? const Color(0xFF000000)
                  : const Color(0xFFFFFFFF),
              foreground: isLight
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF000000),
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: _button(
              label: googleLabel,
              // Google ist in beiden Themes weiß auf `#1A1208`, also dem
              // `ink`-Wert des hellen Themes, hier als Literal wie in der
              // Quelle.
              background: const Color(0xFFFFFFFF),
              foreground: const Color(0xFF1A1208),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Semantics(
      button: true,
      enabled: false,
      tooltip: comingSoonHint,
      container: true,
      // CSS-`opacity` gilt für das ganze Element, also Fläche, Text und
      // Schatten. Deshalb außen und nicht als Alphawert an den Farben.
      child: Opacity(
        opacity: disabledOpacity,
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(Radius.circular(cornerRadius)),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: shadowColor, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: FactTypography.heading.copyWith(
              fontSize: fontSize,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
