import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/material.dart';

/// Die Beschriftung über einem Eingabefeld,
/// `02_Frontend/app/screen-auth.jsx:58-76` (`AuthLabel`).
///
/// ## Der Hinweis rechts fehlt hier, und das ist Absicht
///
/// Die Quelle kennt einen zweiten Inhalt in dieser Zeile: einen roten Hinweis,
/// entweder als Knopf (mit `hintOnClick`) oder als reiner Text (ohne). Benutzt
/// wird er an **genau einer** Stelle im ganzen Projekt, nämlich für "Vergessen?"
/// am Passwortfeld der Anmeldung (`screen-auth.jsx:511`). Weil dieser Schritt
/// den Passwort-Reset nicht baut (Begründung in `LoginPage`), gäbe es für den
/// Hinweis keinen Aufrufer.
///
/// Deshalb steht er hier nicht. Ein Parameter, den niemand setzt, ist kein
/// Vorbau, sondern ungetesteter Code, der beim ersten echten Aufrufer trotzdem
/// noch einmal angefasst wird. Wenn der Reset kommt, kommt er mit.
class AuthLabel extends StatelessWidget {
  /// Erzeugt die Beschriftung.
  const AuthLabel({required this.text, super.key});

  /// `fontSize: 9`.
  static const double fontSize = 9;

  /// `marginBottom: 6`.
  static const double bottomSpacing = 6;

  /// Die Beschriftung. Wird großgeschrieben gezeigt, `textTransform:
  /// uppercase` steht am Element und nicht in der Übersetzung.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: FactTypography.mono.copyWith(
        fontSize: fontSize,
        color: context.factColors.ink3,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Ein Eingabefeld mit Beschriftung, Symbol und optionalem Anhang,
/// `02_Frontend/app/screen-auth.jsx:78-104` (`AuthField`).
///
/// Geteilter Baustein für Anmeldung und Registrierung.
///
/// ## Kein Absenden mit der Eingabetaste
///
/// Die Quelle hat **kein** `<form>`, die Felder sind einzelne `<input>`. Ein
/// Druck auf die Eingabetaste löst dort also nichts aus, und hier deshalb auch
/// nicht: kein `onSubmitted`, kein `onFieldSubmitted`. Das ist eine bewusst
/// übernommene Einschränkung, keine Lücke. Wer sie aufhebt, ändert Verhalten und
/// braucht dafür eine Entscheidung.
class AuthField extends StatefulWidget {
  /// Erzeugt das Feld.
  const AuthField({
    required this.label,
    required this.placeholder,
    required this.controller,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.trailing,
    super.key,
  });

  /// `marginBottom: 12` am Wrapper.
  static const double bottomSpacing = 12;

  /// `padding: '13px 14px'` der Eingabebox.
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 13,
  );

  /// `borderRadius: 14`.
  static const double cornerRadius = 14;

  /// `border: 1.5px solid`.
  static const double borderWidth = 1.5;

  /// `gap: 10` zwischen Symbol, Eingabe und Anhang.
  static const double gap = 10;

  /// `fontSize: 15` der Eingabe.
  static const double inputFontSize = 15;

  /// `fontSize: 16` des Symbols.
  static const double iconFontSize = 16;

  /// `opacity: 0.75` des Symbols.
  static const double iconOpacity = 0.75;

  /// Dauer von `transition: all 0.15s`.
  static const Duration focusDuration = Duration(milliseconds: 150);

  /// `boxShadow: '0 0 0 4px rgba(232,56,13,0.12)'` im fokussierten Zustand.
  ///
  /// Literal und kein Token: die Quelle schreibt die Farbe inline hin, sie kommt
  /// nicht aus `useAuthTokens`. Dass `FactColors.light.redSoft` denselben Wert
  /// trägt, ist Zufall des hellen Themes und im dunklen nicht mehr wahr.
  static const Color focusRingColor = Color.fromRGBO(232, 56, 13, 0.12);

  /// Breite des Fokusrings.
  static const double focusRingWidth = 4;

  /// Beschriftung über dem Feld.
  final String label;

  /// Platzhalter in der leeren Eingabe.
  final String placeholder;

  /// Der Text der Eingabe. Gehört dem Aufrufer, nicht diesem Widget.
  final TextEditingController controller;

  /// Das Symbol links, in der Quelle ein Emoji-Zeichen.
  final String icon;

  /// Ob die Eingabe verdeckt wird.
  final bool obscureText;

  /// Tastaturart, etwa [TextInputType.emailAddress].
  final TextInputType? keyboardType;

  /// Werte für `autoComplete` der Quelle, also die Autofill-Zuordnung.
  final Iterable<String>? autofillHints;

  /// Optionaler Anhang rechts in der Box, etwa der Sichtbarkeitsschalter.
  final Widget? trailing;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  /// Der Fokuszustand steuert Rahmenfarbe und Ring. Ein eigener Knoten, damit
  /// das Feld ihn beobachten kann, ohne dass der Aufrufer einen liefern muss.
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus == _focused) {
      return;
    }
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.factColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AuthField.bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AuthLabel(text: widget.label),
          const SizedBox(height: AuthLabel.bottomSpacing),
          AnimatedContainer(
            duration: AuthField.focusDuration,
            // CSS setzt als Zeitfunktion einer `transition` standardmäßig
            // `ease`, und `Curves.ease` ist genau `cubic-bezier(0.25,0.1,0.25,1)`.
            curve: Curves.ease,
            padding: AuthField.contentPadding,
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: const BorderRadius.all(
                Radius.circular(AuthField.cornerRadius),
              ),
              border: Border.fromBorderSide(
                BorderSide(
                  color: _focused ? colors.red : colors.border2,
                  width: AuthField.borderWidth,
                ),
              ),
              // Ein `box-shadow` mit Streuung 0 und Weite 4 ist ein Ring um
              // die Box. In Flutter: derselbe Schatten mit `spreadRadius`.
              boxShadow: _focused
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: AuthField.focusRingColor,
                        spreadRadius: AuthField.focusRingWidth,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(
              children: <Widget>[
                Opacity(
                  opacity: AuthField.iconOpacity,
                  child: Text(
                    widget.icon,
                    style: const TextStyle(fontSize: AuthField.iconFontSize),
                  ),
                ),
                const SizedBox(width: AuthField.gap),
                Expanded(child: _input(colors)),
                if (widget.trailing case final Widget trailing) ...<Widget>[
                  const SizedBox(width: AuthField.gap),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(FactColors colors) {
    final style = FactTypography.bodyText.copyWith(
      fontSize: AuthField.inputFontSize,
      color: colors.ink,
    );
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      style: style,
      cursorColor: colors.red,
      // `InputDecoration.collapsed` nimmt Material seinen Rahmen, seine Füllung
      // und die 48 Pixel Mindesthöhe. Rahmen und Füllung zeichnet die Box
      // darüber, genau wie in der Quelle.
      decoration: InputDecoration.collapsed(
        hintText: widget.placeholder,
        // Die Quelle setzt keine Platzhalterfarbe und verlässt sich auf die
        // Browservorgabe. `ink3` ist der Token für "kaum sichtbarer Text" und
        // damit die nächstliegende Entsprechung.
        hintStyle: style.copyWith(color: colors.ink3),
      ),
    );
  }
}
