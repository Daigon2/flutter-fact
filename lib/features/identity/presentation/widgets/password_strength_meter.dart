import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:flutter/widgets.dart';

/// Die Stärkeanzeige unter dem Passwortfeld,
/// `02_Frontend/app/screen-auth.jsx:106-121` (`AuthPwStrength`).
///
/// ## Sie blockiert nichts
///
/// Weder die Farbe noch der Text noch der Wert von [passwordStrengthScore]
/// beeinflussen, ob abgeschickt werden darf. "Zu schwach" verhindert keine
/// Registrierung; ob das Passwort reicht, entscheidet der Server
/// (`onboarding.errPassword`). Das ist die Quelle, und es ist auch die
/// vernünftigere Aufteilung: eine zweite Regel im Client hätte dieselbe Zahl
/// zweimal, und eine davon wäre irgendwann falsch.
///
/// ## Die Farbtabelle hat fünf Einträge bei vier Balken
///
/// Und der erste ist damit **unerreichbar**: gefüllt werden `score` Balken mit
/// `segs[score]`, bei `score == 0` also keiner. Rot (`#E8380D`) erscheint in
/// dieser Anzeige nie. Nachgebaut wie in der Quelle, samt der überzähligen
/// Farbe: sie zu entfernen hieße, die Zuordnung `score -> Farbe` um eins zu
/// verschieben, und dann zeigte Score 1 die Farbe von Score 2. Ein Test hält
/// beides fest.
///
/// Die Balken zeigen alle **dieselbe** Farbe, nämlich die des aktuellen Scores.
/// Es ist keine Ampel von links nach rechts.
class PasswordStrengthMeter extends StatelessWidget {
  /// [score] kommt aus [passwordStrengthScore].
  const PasswordStrengthMeter({required this.score, super.key});

  /// Zahl der Balken, `[0,1,2,3].map(...)`.
  static const int segmentCount = 4;

  /// `height: 4` je Balken.
  static const double segmentHeight = 4;

  /// `borderRadius: 2`.
  static const double cornerRadius = 2;

  /// `gap: 4` zwischen den Balken.
  static const double gap = 4;

  /// `marginBottom: 4` unter der Balkenreihe.
  static const double barsBottomSpacing = 4;

  /// `marginTop: -4` am ganzen Block.
  ///
  /// Ein negativer Außenabstand zieht das Element und alles darunter nach oben.
  /// In Flutter gibt es keinen negativen Innenabstand, deshalb beides getrennt:
  /// gezeichnet wird um diesen Betrag verschoben ([Transform.translate]), und
  /// der Platzbedarf nach unten ist um denselben Betrag kleiner
  /// ([blockBottomSpacing]). Zusammen ergibt das denselben Fluss wie in CSS.
  static const double topShift = -4;

  /// `marginBottom: 12` am ganzen Block, verrechnet mit [topShift].
  static const double blockBottomSpacing = 12 + topShift;

  /// `fontSize: 9` der Beschriftung.
  static const double labelFontSize = 9;

  /// Die fünf Beschriftungen, **hartcodiert deutsch** wie in der Quelle.
  ///
  /// Es gibt dafür keinen i18n-Schlüssel, und dieser Schritt legt keinen an. Auf
  /// Englisch steht hier deshalb ebenfalls "Zu schwach" bis "Stark", genau wie
  /// in der PWA. Einer der belegten i18n-Löcher der Vorlage, kein Versehen beim
  /// Portieren.
  static const List<String> labels = <String>[
    'Zu schwach',
    'Schwach',
    'Okay',
    'Gut',
    'Stark',
  ];

  /// Ab welchem Score die Beschriftung grün wird und der Zusatz erscheint.
  static const int bonusScore = 3;

  /// Der Zusatz ab [bonusScore], ebenfalls hartcodiert (`' · +5 XP Bonus'`).
  ///
  /// **Der Bonus existiert nur als Text.** Es gibt keine Stelle, die dafür XP
  /// vergibt; die Registrierung schickt den Score nicht mit, und `progression`
  /// erfährt nichts davon. Übernommen, weil es sichtbarer Teil des Bildschirms
  /// ist.
  static const String bonusSuffix = ' · +5 XP Bonus';

  /// Farbe der Beschriftung ab [bonusScore] und letzter Eintrag der Balkenfarben.
  static const Color strongColor = Color(0xFF16A34A);

  /// Der Score von 0 bis 4.
  final int score;

  /// Die Balkenfarben, `[t.red, '#F59E0B', t.gold, '#84CC16', '#16A34A']`.
  ///
  /// Gemischt aus Tokens und Literalen, und genau so steht es in der Quelle:
  /// der erste Wert ist `--red`, der dritte `--gold`, die anderen drei sind
  /// inline geschriebene Farben. Deshalb hängen zwei von fünf am Theme und drei
  /// nicht.
  static List<Color> segmentColors(FactColors colors) => <Color>[
    colors.red,
    const Color(0xFFF59E0B),
    colors.gold,
    const Color(0xFF84CC16),
    strongColor,
  ];

  @override
  Widget build(BuildContext context) {
    assert(
      score >= 0 && score < labels.length,
      'Score $score liegt außerhalb von 0 bis ${labels.length - 1}. '
      'passwordStrengthScore begrenzt darauf.',
    );
    final colors = context.factColors;
    final filled = segmentColors(colors)[score];
    return Padding(
      padding: const EdgeInsets.only(bottom: blockBottomSpacing),
      child: Transform.translate(
        offset: const Offset(0, topShift),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                for (var i = 0; i < segmentCount; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // `i < score ? segs[score] : t.card2`.
                        color: i < score ? filled : colors.surface3,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(cornerRadius),
                        ),
                      ),
                      child: const SizedBox(height: segmentHeight),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: barsBottomSpacing),
            Text(
              strengthLabel(score).toUpperCase(),
              style: FactTypography.mono.copyWith(
                fontSize: labelFontSize,
                color: score >= bonusScore ? strongColor : colors.ink3,
                letterSpacing: 0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Die Beschriftung zu [score], mit dem Bonus-Zusatz ab [bonusScore].
  static String strengthLabel(int score) =>
      '${labels[score]}${score >= bonusScore ? bonusSuffix : ''}';
}

/// Der Score von 0 bis 4, `screen-auth.jsx:583`.
///
/// Vier Kriterien, jedes einen Punkt: mindestens acht Zeichen, ein Großbuchstabe
/// `A-Z`, eine Ziffer, ein Zeichen außerhalb von `A-Za-z0-9`. Das
/// `Math.min(4, Math.max(0, ...))` der Quelle ist bei vier Kriterien
/// wirkungslos und steht hier trotzdem als Zusicherung.
///
/// Was die Kriterien **nicht** prüfen: Kleinbuchstaben und Umlaute. `ÄÖÜ` sind
/// keine `[A-Z]`, sie zählen als Sonderzeichen. `ßßßßßßßß` bekommt damit zwei
/// Punkte (Länge plus Sonderzeichen) und heißt "Okay". Das ist das Verhalten der
/// Quelle, und es ist harmlos, solange die Anzeige nichts blockiert.
int passwordStrengthScore(String password) {
  final points =
      (password.length >= 8 ? 1 : 0) +
      (_uppercase.hasMatch(password) ? 1 : 0) +
      (_digit.hasMatch(password) ? 1 : 0) +
      (_special.hasMatch(password) ? 1 : 0);
  return points.clamp(0, PasswordStrengthMeter.segmentCount);
}

final RegExp _uppercase = RegExp('[A-Z]');
final RegExp _digit = RegExp('[0-9]');
final RegExp _special = RegExp('[^A-Za-z0-9]');
