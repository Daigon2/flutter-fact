import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/identity/presentation/notifiers/username_check_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Das Username-Feld der Registrierung,
/// `02_Frontend/app/screen-auth.jsx:668-721`.
///
/// ## Warum es **nicht** `AuthField` benutzt
///
/// Weil die Quelle es auch nicht tut. Das Feld sieht anders aus und verhält sich
/// anders: eigenes Label (Nunito 12/700 statt Mono 9), Eckenradius 10 statt 14,
/// kein Symbol links, kein Fokusring, dafür ein Statusabzeichen rechts und ein
/// Hinweis darunter. `AuthField` um sechs Schalter zu erweitern, damit es beides
/// kann, hätte den geteilten Baustein für die zwei Felder verschlechtert, die ihn
/// wirklich teilen.
///
/// ## Die Abzeichen sind teils Glyphen, teils Übersetzungen
///
/// Und das ist der Zustand der Quelle, kein Versehen:
///
/// | Zustand | Rahmen | Abzeichen |
/// |---|---|---|
/// | `idle` | `brd2` | **keines** |
/// | `checking` | `brd2` | `username.checking`, also wörtlich `...` |
/// | `ok` | `#00C2A8` | die Glyphe `✓` |
/// | `taken` | `#E8380D` | `username.taken` |
/// | `invalid` | `#E8380D` | die Glyphe `✗` |
///
/// **`username.available` und `username.invalid` existieren als i18n-Schlüssel
/// und werden hier absichtlich nicht benutzt**, weil die Quelle sie nicht
/// benutzt: `screen-auth.jsx:714-715` schreibt für diese beiden Zustände die
/// Zeichen `✓` und `✗` direkt hin. Das ist keine Portierlücke. Wer die Schlüssel
/// einsetzt, ändert das Bild des Feldes, und "Nur Buchstaben, Ziffern und _
/// (max. 20)" passt an dieser Stelle auch nicht: das Abzeichen liegt im Feld
/// über der Eingabe und hat dort keine 40 Zeichen Platz.
class UsernameField extends StatelessWidget {
  /// [status] kommt aus `usernameCheckProvider`.
  const UsernameField({
    required this.controller,
    required this.status,
    required this.onChanged,
    required this.label,
    required this.placeholder,
    required this.hint,
    required this.checkingBadge,
    required this.takenBadge,
    super.key,
  });

  /// `marginBottom: 14` am Wrapper.
  static const double bottomSpacing = 14;

  /// `padding: '12px 44px 12px 14px'` der Eingabe.
  ///
  /// Rechts bleibt Platz für das Abzeichen, auch wenn keines da ist. Die Quelle
  /// setzt den Wert fest und nicht abhängig vom Zustand, sonst hüpfte der Text
  /// beim Tippen.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(14, 12, 44, 12);

  /// `borderRadius: 10`. **Nicht** die 14 der übrigen Felder.
  static const double cornerRadius = 10;

  /// `border: 1.5px solid`.
  static const double borderWidth = 1.5;

  /// `fontSize: 15` der Eingabe.
  static const double inputFontSize = 15;

  /// `fontSize: 12` des Labels.
  static const double labelFontSize = 12;

  /// `marginBottom: 4` unter dem Label.
  static const double labelBottomSpacing = 4;

  /// `fontSize: 11` des Hinweises.
  static const double hintFontSize = 11;

  /// `marginTop: 4` über dem Hinweis.
  static const double hintTopSpacing = 4;

  /// `fontSize: 13` des Abzeichens.
  static const double badgeFontSize = 13;

  /// `right: 12` des Abzeichens.
  static const double badgeInset = 12;

  /// `maxLength: 20` der Eingabe.
  static const int maxLength = 20;

  /// Dauer von `transition: border-color 0.2s`.
  static const Duration borderDuration = Duration(milliseconds: 200);

  /// Rahmen und Abzeichen bei [UsernameStatus.ok], `#00C2A8`.
  ///
  /// Ein Literal wie in der Quelle. Dieses Grün kommt in `FactColors` nicht vor,
  /// es ist die einzige Verwendung im ganzen Bildschirm.
  static const Color okColor = Color(0xFF00C2A8);

  /// Rahmen und Abzeichen bei [UsernameStatus.taken] und
  /// [UsernameStatus.invalid], `#E8380D`.
  ///
  /// Wertgleich mit `FactColors.red`, hier aber als Literal: die Quelle schreibt
  /// den Hexwert hin, statt `tok.red` zu benutzen.
  static const Color errorColor = Color(0xFFE8380D);

  /// Abzeichen bei [UsernameStatus.checking], `#A09070`.
  static const Color checkingColor = Color(0xFFA09070);

  /// Die Glyphe für [UsernameStatus.ok], in der Quelle hartcodiert.
  static const String okGlyph = '✓';

  /// Die Glyphe für [UsernameStatus.invalid], in der Quelle hartcodiert.
  static const String invalidGlyph = '✗';

  /// Der Text des Feldes. Gehört dem Aufrufer.
  final TextEditingController controller;

  /// Der geprüfte Zustand.
  final UsernameStatus status;

  /// Jede Änderung, roh und ungetrimmt wie in der Quelle.
  final ValueChanged<String> onChanged;

  /// `username.label`.
  final String label;

  /// `username.placeholder`.
  final String placeholder;

  /// `username.hint`.
  final String hint;

  /// `username.checking`.
  final String checkingBadge;

  /// `username.taken`.
  final String takenBadge;

  /// Die Rahmenfarbe zu [status].
  ///
  /// Statisch und getrennt, damit ein Test sie ohne Widget-Baum prüfen kann.
  static Color borderColorFor(UsernameStatus status, FactColors colors) {
    return switch (status) {
      UsernameStatus.taken || UsernameStatus.invalid => errorColor,
      UsernameStatus.ok => okColor,
      UsernameStatus.idle || UsernameStatus.checking => colors.border2,
    };
  }

  /// Die Abzeichenfarbe zu [status].
  static Color badgeColorFor(UsernameStatus status) {
    return switch (status) {
      UsernameStatus.ok => okColor,
      UsernameStatus.taken || UsernameStatus.invalid => errorColor,
      // Auch für `idle`, wo es kein Abzeichen gibt: die Quelle rechnet die Farbe
      // vor der Sichtbarkeitsprüfung aus.
      UsernameStatus.idle || UsernameStatus.checking => checkingColor,
    };
  }

  /// Der Text des Abzeichens, oder `null` bei [UsernameStatus.idle].
  String? badgeTextFor(UsernameStatus status) {
    return switch (status) {
      UsernameStatus.idle => null,
      UsernameStatus.checking => checkingBadge,
      UsernameStatus.taken => takenBadge,
      UsernameStatus.invalid => invalidGlyph,
      UsernameStatus.ok => okGlyph,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    final inputStyle = FactTypography.bodyText.copyWith(
      fontSize: inputFontSize,
      color: colors.ink,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            // Kein `toUpperCase`: dieses Label hat, anders als `AuthLabel`,
            // kein `text-transform`. Es zeigt "Username", nicht "USERNAME".
            label,
            style: FactTypography.heading.copyWith(
              fontSize: labelFontSize,
              // Gewicht 700 statt der 800 von `.h`: die Quelle setzt es
              // ausdrücklich am Element. Nunito Bold ist geladen.
              fontWeight: FontWeight.w700,
              color: colors.ink3,
            ),
          ),
          const SizedBox(height: labelBottomSpacing),
          Stack(
            children: <Widget>[
              AnimatedContainer(
                duration: borderDuration,
                curve: Curves.ease,
                padding: contentPadding,
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(cornerRadius),
                  ),
                  border: Border.fromBorderSide(
                    BorderSide(
                      color: borderColorFor(status, colors),
                      width: borderWidth,
                    ),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: inputStyle,
                  cursorColor: colors.red,
                  // `autoCapitalize="none"` und `autoCorrect="off"`.
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  // `maxLength` als Formatierer und nicht als
                  // `TextField.maxLength`: letzteres zeichnet einen Zähler unter
                  // das Feld, den die Quelle nicht hat. Die Begrenzung selbst
                  // ist dieselbe.
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
                  decoration: InputDecoration.collapsed(
                    hintText: placeholder,
                    hintStyle: inputStyle.copyWith(color: colors.ink3),
                  ),
                ),
              ),
              if (badgeTextFor(status) case final String badge)
                _badge(badge, colors),
            ],
          ),
          const SizedBox(height: hintTopSpacing),
          Text(
            hint,
            style: FactTypography.bodyText.copyWith(
              fontSize: hintFontSize,
              color: colors.ink3,
            ),
          ),
        ],
      ),
    );
  }

  /// Das Abzeichen liegt **über** der Eingabe, wie in der Quelle
  /// (`position: absolute`), und beeinflusst deren Maße nicht.
  ///
  /// `left` steht mit dabei, obwohl die Quelle es nicht setzt: ohne eine linke
  /// Kante könnte ein langer Text wie "Bereits vergeben" bei großer
  /// Systemschrift über den linken Rand hinauswachsen und würde vom [Stack]
  /// **am Anfang** abgeschnitten. Rechts ausgerichtet und mit Auslassungspunkten
  /// bleibt der Anfang lesbar. Bei Systemschriftgröße 1.0 ist das Ergebnis
  /// identisch zur Quelle.
  Widget _badge(String badge, FactColors colors) {
    return Positioned(
      left: contentPadding.left,
      right: badgeInset,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            badge,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FactTypography.bodyText.copyWith(
              fontSize: badgeFontSize,
              color: badgeColorFor(status),
            ),
          ),
        ),
      ),
    );
  }
}
