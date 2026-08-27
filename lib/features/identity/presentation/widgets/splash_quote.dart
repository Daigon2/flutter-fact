import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Das Goethe-Zitat des Startbildschirms, `screen-auth.jsx:305-312`.
///
/// ## Warum der Text hier hartcodiert steht
///
/// Weil die Quelle ihn hartcodiert. Es gibt für diesen Text **keinen**
/// i18n-Schlüssel. Die naheliegenden Kandidaten `onboarding.quote` und
/// `onboarding.quoteAuthor` existieren in `translations.jsx`, sind in der ganzen
/// PWA aber nirgends benutzt (nachgeprüft) und weichen im Wortlaut ab: sie
/// stehen in Guillemets und der Verfasser heißt dort "Goethe (vermutlich)".
///
/// Wer diesen Bildschirm später "reparieren" will, indem er auf die Schlüssel
/// umstellt, ändert damit den angezeigten Text. Deshalb steht das hier und nicht
/// nur im Commit.
///
/// ## Zwei Eigenheiten der Quelle, absichtlich übernommen
///
/// Das öffnende Anführungszeichen ist das deutsche `„` (U+201E), das schließende
/// ein gerades ASCII-`"`. Typografisch wäre `“` richtig; die Quelle hat es
/// nicht, und dieser Bildschirm folgt der Quelle.
///
/// ## Eine Eigenheit, die nicht umsetzbar ist
///
/// `textWrap: 'balance'` verteilt den Umbruch in CSS gleichmäßig über die
/// Zeilen. Flutter hat dafür kein Gegenstück. Der Umbruch fällt damit bei
/// schmalen Bildschirmen möglicherweise anders als in der PWA. Nachbauen würde
/// eigene Zeilenmessung bedeuten und wäre für zwei Zeilen Zitat nicht
/// verhältnismäßig.
class SplashQuote extends StatelessWidget {
  /// Erzeugt das Zitat.
  const SplashQuote({super.key});

  /// Der Satz bis zum hervorgehobenen Wort.
  static const String opening = '„Man sieht nur, was man ';

  /// Das hervorgehobene Wort samt Punkt.
  static const String emphasis = 'weiß.';

  /// Das schließende Anführungszeichen der Quelle.
  static const String closing = '"';

  /// Die Verfasserzeile, `— Goethe`.
  static const String attribution = '— Goethe';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(text: opening),
              // `color: '#FFB088', fontWeight: 700, fontStyle: 'normal'`: das
              // eine Wort ist bewusst gerade gesetzt, nicht kursiv.
              TextSpan(
                text: emphasis,
                style: FactTypography.bodyText.copyWith(
                  fontSize: 17,
                  height: 1.4,
                  color: const Color(0xFFFFB088),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: closing),
            ],
          ),
          textAlign: TextAlign.center,
          style: FactTypography.bodyText.copyWith(
            fontSize: 17,
            height: 1.4,
            fontStyle: FontStyle.italic,
            color: const Color.fromRGBO(255, 255, 255, 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          attribution,
          textAlign: TextAlign.center,
          style: FactTypography.mono.copyWith(
            fontSize: 9,
            color: const Color.fromRGBO(255, 255, 255, 0.35),
          ),
        ),
      ],
    );
  }
}
