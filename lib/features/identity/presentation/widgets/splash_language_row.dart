import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/identity/presentation/widgets/flag_mark.dart';
import 'package:fact_app/features/identity/presentation/widgets/splash_pressable.dart';
import 'package:flutter/widgets.dart';

/// Sprachauswahl und Audio-Knopf des Startbildschirms,
/// `screen-auth.jsx:331-372`.
///
/// ## Die Sprachtexte sind absichtlich nicht übersetzt
///
/// `screen-auth.jsx:334` sagt es wörtlich: "Subs intentionally not translated —
/// each language shows in its own tongue". Eine Karte zeigt ihre eigene Sprache,
/// unabhängig davon, welche gerade aktiv ist. Deshalb stehen `Deutsch`,
/// `Weiter auf Deutsch`, `English` und `Continue in English` hier als Literale.
/// Der Schlüssel `lang.continue` ist **nicht** dasselbe und ersetzt sie nicht.
class SplashLanguageRow extends StatelessWidget {
  /// Erzeugt die Zeile.
  const SplashLanguageRow({
    required this.strings,
    required this.activeLanguage,
    required this.onLanguageSelected,
    required this.onAudioGuidePressed,
    super.key,
  });

  /// Eckenradius von Karten und Audio-Knopf, `borderRadius: 16`.
  static const double cornerRadius = 16;

  /// Breite der Flaggen, `<Flag size={30}/>`.
  static const double flagSize = 30;

  /// Höchstbreite des Audio-Knopfes, siehe [_audioGuideButton].
  ///
  /// Ein Drittel der Zeilenbreite bei den 390 Pixeln, auf die die Quelle gebaut
  /// ist (`chrome.jsx:135`): 390 minus die 44 Pixel Innenabstand der
  /// Inhaltsspalte sind 346, davon ein Drittel 115.
  static const double audioButtonMaxWidth = 115;

  /// Innenabstand aller drei Felder, `padding: '11px 14px'`.
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 11,
  );

  /// Texte der aktiven Sprache, für den Audio-Knopf.
  final AppStrings strings;

  /// Welche Karte hervorgehoben ist.
  final AppLanguage activeLanguage;

  /// Wird beim Tippen auf eine Sprachkarte gerufen.
  final ValueChanged<AppLanguage> onLanguageSelected;

  /// Wird beim Tippen auf den Kopfhörer-Knopf gerufen.
  final VoidCallback onAudioGuidePressed;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      // Die drei Felder sind in CSS gleich hoch, weil Flex-Kinder gestreckt
      // werden. Der Audio-Knopf ist das höchste und gibt damit das Maß vor.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: _languageCard(
              language: AppLanguage.de,
              kind: FlagKind.de,
              label: 'Deutsch',
              subtitle: 'Weiter auf Deutsch',
            ),
          ),
          Expanded(
            child: _languageCard(
              language: AppLanguage.en,
              kind: FlagKind.gb,
              label: 'English',
              subtitle: 'Continue in English',
            ),
          ),
          _audioGuideButton(),
        ],
      ),
    );
  }

  Widget _languageCard({
    required AppLanguage language,
    required FlagKind kind,
    required String label,
    required String subtitle,
  }) {
    final selected = language == activeLanguage;
    return SplashPressable(
      onPressed: () => onLanguageSelected(language),
      // Der Auswahlzustand ist in der Quelle nur farbig. Siehe
      // [SplashPressable.selected].
      selected: selected,
      child: Container(
        padding: fieldPadding,
        decoration: BoxDecoration(
          color: selected
              ? const Color.fromRGBO(232, 56, 13, 0.18)
              : const Color.fromRGBO(255, 255, 255, 0.06),
          borderRadius: const BorderRadius.all(Radius.circular(cornerRadius)),
          border: Border.fromBorderSide(
            BorderSide(
              color: selected
                  ? const Color.fromRGBO(232, 56, 13, 0.55)
                  : const Color.fromRGBO(255, 255, 255, 0.12),
              width: 1.5,
            ),
          ),
          // `boxShadow: '0 0 0 3px rgba(232,56,13,0.12)'`: kein Versatz, keine
          // Unschärfe, nur Ausbreitung. Das ist ein Ring, kein Schatten.
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color.fromRGBO(232, 56, 13, 0.12),
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 10,
          children: <Widget>[
            FlagMark(kind: kind, size: flagSize),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: FactTypography.heading.copyWith(
                      fontSize: 14,
                      height: 1,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 11,
                      color: const Color.fromRGBO(255, 255, 255, 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Der Kopfhörer-Knopf, gedeckelt auf [audioButtonMaxWidth].
  ///
  /// ## Warum die Deckelung nötig ist
  ///
  /// Er ist das einzige der drei Felder ohne `Expanded`, weil die Quelle ihn
  /// aus seinem Inhalt heraus bemisst (`screen-auth.jsx:356-370`, kein `flex`).
  /// Wächst seine Beschriftung mit der Systemschriftgröße, nimmt er den beiden
  /// Sprachkarten Platz weg, bis dort die 30 Pixel der Flagge plus 10 Pixel
  /// Abstand nicht mehr hineinpassen. Gemessen mit echten Schriften: bei 360
  /// Pixeln Breite und Skalierung 2.0 lief die innere Zeile der Karte um 3,8
  /// Pixel über.
  ///
  /// Ein Drittel, weil die drei Felder in CSS gleichrangige Flex-Kinder sind:
  /// mehr als seinen gleichen Anteil darf das eine Feld, das nicht schrumpfen
  /// kann, nicht beanspruchen. Bei Skalierung 1.0 **bindet die Deckelung
  /// nicht**, der Knopf ist dort mit etwa 88 Pixeln schmaler als die 115; das
  /// Aussehen des Normalfalls ändert sich also nicht. Per Test zugesichert.
  ///
  /// **Warum eine Konstante und nicht ein Drittel der gemessenen Zeile:** ein
  /// `LayoutBuilder` an dieser Stelle ist nicht möglich. Der Startbildschirm
  /// legt seine Inhaltsspalte in ein `IntrinsicHeight`
  /// (`splash_page.dart:273`), und `LayoutBuilder` kann keine intrinsischen
  /// Maße liefern: "LayoutBuilder does not support returning intrinsic
  /// dimensions." Ausprobiert, der ganze Bildschirm bricht damit zusammen.
  ///
  /// Die PWA braucht das alles nicht, weil sie den Fall nicht kennt: ihre 11
  /// und 14 Pixel sind CSS-`px` und folgen der Textgrößen-Einstellung des
  /// Betriebssystems nicht, und was trotzdem zu breit wird, schneidet
  /// `#root { overflow: hidden }` ab. In Flutter ist derselbe Zustand ein
  /// Fehler, deshalb bricht die Beschriftung hier stattdessen um.
  Widget _audioGuideButton() {
    final label = strings.text('audio.splash.button');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: audioButtonMaxWidth),
      child: SplashPressable(
        onPressed: onAudioGuidePressed,
        // `aria-label` der Quelle ist derselbe Schlüssel wie die Beschriftung.
        semanticLabel: label,
        child: Container(
          padding: fieldPadding,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, 0.06),
            borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
            border: Border.fromBorderSide(
              BorderSide(
                color: Color.fromRGBO(255, 255, 255, 0.12),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: <Widget>[
              // `fontSize: 28`, ohne feste Zeilenhöhe: die Quelle setzt keine,
              // und eine gekappte Zeile schneidet dem Emoji die Oberkante ab.
              const Text('🎧', style: TextStyle(fontSize: 28)),
              Text(
                label,
                // Mittig, damit eine durch die Deckelung umgebrochene
                // Beschriftung unter dem Emoji sitzt statt links wegzulaufen.
                // Bei einer Zeile ist das nicht zu sehen.
                textAlign: TextAlign.center,
                style: FactTypography.bodyText.copyWith(
                  fontSize: 11,
                  color: const Color.fromRGBO(255, 255, 255, 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
