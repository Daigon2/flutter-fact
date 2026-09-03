/// Die Kopfkarte des Reiseführers, `02_Frontend/app/screen-wallet.jsx:806-902`.
///
/// Ein oranger Verlauf mit der Zahl der gesammelten Geschichten, zwei
/// Merkmal-Chips und, sobald es eine Rangliste gibt, einer Rang-Pille.
library;

import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/collection/presentation/library_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Kopfkarte über dem Regal.
class LibraryHeaderCard extends ConsumerWidget {
  /// Erzeugt die Kopfkarte.
  const LibraryHeaderCard({
    required this.collectedCount,
    required this.cityCount,
    this.trophiesEarned = 0,
    this.rank,
    this.onRankTap,
    super.key,
  });

  /// Die Kennung der Karte, für Tests.
  static const Key cardKey = Key('library-header-card');

  /// Die Kennung der Rang-Pille, für Tests.
  static const Key rankKey = Key('library-header-rank');

  /// Die Kennung des Städte-Chips, für Tests.
  static const Key cityChipKey = Key('library-header-chip-cities');

  /// Die Kennung des Trophäen-Chips, für Tests.
  static const Key trophyChipKey = Key('library-header-chip-trophies');

  /// Wie viele Fakten insgesamt gesammelt sind.
  ///
  /// Kommt aus `collectedFactCountProvider`, und dort steht, warum die Quelle
  /// hier das Doppelte anzeigt (E-74).
  final int collectedCount;

  /// Wie viele Städte einen Band haben.
  final int cityCount;

  /// Wie viele Trophäen verdient sind.
  ///
  /// Vorgabe `0`. `progression` hat keine Datenschicht für `user_trophies`,
  /// und nach E-49 ist der Server die einzige Wahrheit über den
  /// Freischaltstand. Null verdiente Trophäen sind für einen neuen Nutzer der
  /// **richtige** Wert, kein Platzhalter. Dieselbe Bauform wie `TrophyList`
  /// aus Schritt 49.
  final int trophiesEarned;

  /// Der eigene Rang, oder `null`, solange es keine Rangliste gibt.
  ///
  /// Die Quelle zeigt die Pille nur bei `{myRank && …}`
  /// (`screen-wallet.jsx:851`), das Weglassen ist also ihr eigenes Verhalten
  /// und keine Auslassung. Die Rangliste ist Schritt 48.
  final int? rank;

  /// Was das Antippen der Rang-Pille auslöst.
  ///
  /// In der Quelle `onNav('profil')` (`:852`). `null`, solange das Profil
  /// keinen Einstieg hat.
  final VoidCallback? onRankTap;

  /// Der Außenabstand, `4px 18px 18px` (`screen-wallet.jsx:807`).
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 4, 18, 18);

  /// Der Abstand über der Chip-Zeile (`screen-wallet.jsx:865`).
  static const double chipRowSpacing = 14;

  /// Der Abstand zwischen zwei Chips (`screen-wallet.jsx:865`).
  static const double chipGap = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final FactColors colors = context.factColors;

    return Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(libraryHeaderRadius)),
          boxShadow: <BoxShadow>[libraryHeaderShadow],
        ),
        child: ClipRRect(
          // `overflow: 'hidden'` (`screen-wallet.jsx:808`): die beiden
          // Deko-Kreise ragen über den Rand und werden an der runden Ecke
          // abgeschnitten. Ohne den Schnitt stünden sie als Kugeln daneben.
          borderRadius: const BorderRadius.all(
            Radius.circular(libraryHeaderRadius),
          ),
          child: Container(
            key: cardKey,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                // `135deg` in CSS zeigt von links oben nach rechts unten.
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: libraryHeaderStops,
                colors: libraryHeaderColors,
              ),
            ),
            child: Stack(
              children: <Widget>[
                const Positioned(
                  right: -30,
                  top: -38,
                  child: _DecoCircle(size: 130, color: Color(0x0FFFFFFF)),
                ),
                const Positioned(
                  right: 28,
                  bottom: -18,
                  child: _DecoCircle(size: 56, color: Color(0x0DFFFFFF)),
                ),
                Padding(
                  padding: libraryHeaderPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _topRow(strings),
                      const SizedBox(height: chipRowSpacing),
                      _chips(strings, colors),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topRow(AppStrings strings) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.text('wallet.libraryKicker').toUpperCase(),
              style: FactTypography.mono.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 9,
                letterSpacing: 2,
                color: libraryHeaderKickerColor,
              ),
            ),
            const SizedBox(height: 6),
            _title(strings),
            const SizedBox(height: 6),
            _rankHint(strings),
          ],
        ),
      ),
      if (rank != null) ...<Widget>[const SizedBox(width: 10), _rankPill()],
    ],
  );

  /// Die große Zeile, `screen-wallet.jsx:837-846`.
  ///
  /// Zwei Zeilen mit einem festen Umbruch (`<br/>`), und die Zahl vorn in
  /// Gold. Der Umbruch steht in der Quelle und ist deshalb kein Ergebnis der
  /// Textbreite.
  Widget _title(AppStrings strings) => Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(
          text: '$collectedCount',
          style: const TextStyle(color: Color(0xFFFFE066)),
        ),
        TextSpan(text: ' ${strings.text('wallet.statStories')}\n'),
        TextSpan(text: strings.text('wallet.fromYourCities')),
      ],
    ),
    style: TextStyle(
      fontFamily: FactFont.display,
      fontWeight: FontWeight.w900,
      fontSize: 28,
      height: 1.05,
      letterSpacing: FactTypography.displayTracking(28),
      color: const Color(0xFFFFFFFF),
    ),
  );

  /// Die Zeile „Sammler-Rang bald verfügbar ↗", `screen-wallet.jsx:847-850`.
  ///
  /// ## Ein Pfeil, der wandert, und zwei Leerzeichen
  ///
  /// Die Quelle schreibt `t('wallet.rankSoon', lang).replace('↗', '')` und
  /// setzt danach ein goldenes `↗` an das Ende. Der Schlüssel lautet
  /// `Sammler-Rang ↗ bald verfügbar`, das Zeichen steht dort also **in der
  /// Mitte**. Nach dem Ersetzen bleibt `Sammler-Rang  bald verfügbar` mit
  /// **zwei** Leerzeichen stehen, und der Pfeil sitzt am Ende. Englisch
  /// dasselbe: `Collector rank ↗ coming soon`.
  ///
  /// Die Absicht ist klar erkennbar: der Pfeil soll golden und hinten sein.
  /// Umgesetzt ist deshalb genau das, und das doppelte Leerzeichen fällt
  /// zusammen mit dem Pfeil weg. Registriert als Teil von E-76.
  Widget _rankHint(AppStrings strings) {
    final String withoutArrow = strings
        .text('wallet.rankSoon')
        .replaceAll(RegExp(r'\s*↗\s*'), ' ')
        .trim();
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: withoutArrow),
          const TextSpan(
            text: ' ↗',
            style: TextStyle(
              color: Color(0xFFF5C518),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      style: FactTypography.bodyText.copyWith(
        fontSize: 12.5,
        color: libraryHeaderSubColor,
      ),
    );
  }

  Widget _rankPill() => GestureDetector(
    key: rankKey,
    onTap: onRankTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: libraryChipColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x47FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '#$rank',
            style: FactTypography.heading.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(width: 6),
          const Text('🏆', style: TextStyle(fontSize: 14)),
        ],
      ),
    ),
  );

  Widget _chips(AppStrings strings, FactColors colors) => Wrap(
    spacing: chipGap,
    runSpacing: chipGap,
    children: <Widget>[
      _Chip(
        key: cityChipKey,
        glyph: '🏙',
        value: '$cityCount',
        label: strings.text('wallet.cities'),
      ),
      _Chip(
        key: trophyChipKey,
        glyph: '🏆',
        value: '$trophiesEarned',
        label: strings.text('profil.trophies'),
      ),
    ],
  );
}

/// Einer der beiden Deko-Kreise, `screen-wallet.jsx:820-828`.
class _DecoCircle extends StatelessWidget {
  const _DecoCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// Ein Merkmal-Chip in der Kopfkarte, `screen-wallet.jsx:866-877`.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.glyph,
    required this.value,
    required this.label,
    super.key,
  });

  final String glyph;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    // `padding: '5px 12px 5px 10px'`, links schmaler wegen des Zeichens.
    padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
    decoration: BoxDecoration(
      color: libraryChipColor,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: libraryChipBorderColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(glyph, style: const TextStyle(fontSize: 14, height: 1)),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: const TextStyle(color: Color(0xFFFFE066)),
              ),
              TextSpan(text: ' $label'),
            ],
          ),
          style: FactTypography.heading.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.3,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ],
    ),
  );
}
