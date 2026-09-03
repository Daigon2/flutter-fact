/// Die Trophäenzeile des Reiseführers, `02_Frontend/app/screen-wallet.jsx:1032-1075`.
///
/// ## Zwei Defekte der Quelle stecken in dieser einen Zeile
///
/// **Erstens die Beschriftung.** Die Quelle holt sie mit
/// `t('trophy.' + tr.key, lang)` (`:1050`). Am 03.09.2026 nachgezählt: in
/// `translations.jsx` gibt es genau elf `trophy.*`-Schlüssel, und vier davon
/// sind Oberflächentexte (`trophy.collection`, `.count`, `.unlock`,
/// `.viewAll`). Übrig bleiben sechs Trophäennamen, die zu einem Eintrag in
/// `WalletTrophies` passen; ein siebter, `trophy.firstEver`, passt zu keinem.
/// Es gibt **36** Trophäen. Auf dem Bildschirm stehen damit **30** rohe
/// Schlüssel: `meister_hist`, `münchen_first`, `weltenbummler` und so weiter.
///
/// Dieselbe Fehlerklasse wie E-28 und E-63, und diesmal liegt die Antwort
/// unmittelbar daneben: die Namen stehen **zweisprachig in den Daten**
/// (`label_de`, `label_en`), und `screen-profil.jsx:210` liest sie genau so.
/// Zwei Bildschirme, dieselben 36 Definitionen, einer davon funktioniert.
/// Registriert als E-73. Hier gelesen wird die Datenquelle.
///
/// **Zweitens das dunkle Theme.** Die gesperrte Karte trägt `background:
/// '#fff'` (`:1057`), hart hingeschrieben und ohne Token, die verdiente einen
/// cremefarbenen Verlauf. Die Beschriftung nimmt `tok.ink`, und das ist im
/// dunklen Theme `#F5F0E8`. Auf einer weißen Karte steht damit weißer Text:
/// im dunklen Theme sind **alle 36 Beschriftungen unlesbar**. Registriert als
/// E-77.
///
/// Behoben, und es kostet keine Gestaltungsentscheidung: der Kartengrund ist
/// in beiden Themes hell, also folgt die Schriftfarbe der **Karte** und nicht
/// dem App-Theme. Genommen wird deshalb `FactColors.light.ink`, dieselbe
/// Farbe, die die Quelle im hellen Theme zeigt.
///
/// ## Der Freischaltstand ist ein Parameter
///
/// Wie bei `TrophyList` aus Schritt 49 und aus demselben Grund: `progression`
/// hat keine Datenschicht für `user_trophies`, und nach E-49 ist der Server
/// die einzige Wahrheit. 36 gesperrte Trophäen sind für einen neuen Nutzer
/// richtig.
///
/// ## Die Reihenfolge ist die der Quelle, und das Etikett passt nicht dazu
///
/// Diese Zeile zeigt die Trophäen in **Definitionsreihenfolge**
/// (`trophies.map`, `:1049`), während die Überschrift `wallet.trophiesLabel`
/// „Zuletzt erreicht" lautet. Der Profil-Bildschirm sortiert Verdiente nach
/// vorn (`screen-profil.jsx:216`), diese Zeile nicht. Übernommen ist die
/// Reihenfolge, weil sie Verhalten ist; das Etikett bleibt daneben stehen und
/// ist als Teil von E-76 vermerkt. Deshalb liest diese Zeile
/// [trophyCatalog] direkt und **nicht** `trophiesInDisplayOrder`, das für den
/// Profil-Bildschirm gebaut wurde.
library;

import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/features/collection/presentation/library_look.dart';
import 'package:fact_app/features/progression/application/trophy_catalog.dart';
import 'package:fact_app/features/progression/domain/entities/trophy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die waagerecht scrollende Trophäenzeile.
class LibraryTrophyRow extends ConsumerWidget {
  /// Erzeugt die Zeile.
  const LibraryTrophyRow({this.unlockedKeys = const <String>{}, super.key});

  /// Die Kennung der Zeile, für Tests.
  static const Key rowKey = Key('library-trophy-row');

  /// Die Kennung einer Karte, für Tests.
  static Key cardKey(String trophyKey) => Key('library-trophy-$trophyKey');

  /// Welche Trophäen verdient sind.
  final Set<String> unlockedKeys;

  /// Der Außenabstand, `6px 0 8px` (`screen-wallet.jsx:1033`).
  static const EdgeInsets padding = EdgeInsets.only(top: 6, bottom: 8);

  /// Der Abstand der Überschriftzeile, `4px 22px 10px`
  /// (`screen-wallet.jsx:1034`).
  static const EdgeInsets labelPadding = EdgeInsets.fromLTRB(22, 4, 22, 10);

  /// Der Innenabstand der Kartenzeile, `4px 18px 12px`
  /// (`screen-wallet.jsx:1046`).
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(18, 4, 18, 12);

  /// Der Abstand zwischen zwei Karten (`screen-wallet.jsx:1045`).
  static const double cardGap = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final AppLanguage language = ref.watch(appLanguageProvider);
    final FactColors colors = context.factColors;
    final int earned = trophyCatalog
        .where((Trophy trophy) => unlockedKeys.contains(trophy.key))
        .length;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: labelPadding,
            child: Row(
              children: <Widget>[
                Text(
                  strings.text('wallet.trophiesLabel').toUpperCase(),
                  style: FactTypography.mono.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                    letterSpacing: 2,
                    color: colors.ink3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: colors.border)),
                const SizedBox(width: 8),
                Text(
                  '$earned / ${trophyCatalog.length}',
                  style: FactTypography.heading.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: colors.ink3,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            key: rowKey,
            scrollDirection: Axis.horizontal,
            padding: listPadding,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < trophyCatalog.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: cardGap),
                  _TrophyCard(
                    trophy: trophyCatalog[i],
                    earned: unlockedKeys.contains(trophyCatalog[i].key),
                    language: language,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Trophäenkarte, `screen-wallet.jsx:1051-1072`.
class _TrophyCard extends StatelessWidget {
  const _TrophyCard({
    required this.trophy,
    required this.earned,
    required this.language,
  });

  final Trophy trophy;
  final bool earned;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    // **Die hellen Tokens, auch im dunklen Theme.** Siehe den Kopf dieser
    // Datei, E-77: der Kartengrund ist in beiden Themes hell, also gehört die
    // Schrift dazu und nicht zum App-Theme.
    const FactColors card = FactColors.light;
    final String label = language == AppLanguage.en
        ? trophy.labelEn
        : trophy.labelDe;

    return Container(
      key: LibraryTrophyRow.cardKey(trophy.key),
      width: libraryTrophyCardSize,
      height: libraryTrophyCardSize,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: earned ? null : libraryTrophyLockedColor,
        gradient: earned
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: libraryTrophyEarnedColors,
              )
            : null,
        borderRadius: BorderRadius.circular(libraryTrophyCardRadius),
        border: Border.all(
          color: earned ? libraryTrophyEarnedBorderColor : card.border,
        ),
        boxShadow: <BoxShadow>[
          earned ? libraryTrophyEarnedShadow : libraryTrophyLockedShadow,
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Opacity(
            opacity: earned ? 1 : libraryTrophyLockedGlyphOpacity,
            child: Text(
              trophy.glyph,
              style: TextStyle(
                fontSize: 22,
                height: 1,
                // `drop-shadow(0 1px 1px rgba(180,140,20,0.4))`, `:1068`, und
                // an der gesperrten Karte `filter: 'none'`. Deshalb die
                // Bedingung: ein Goldschatten unter einem auf 42 Prozent
                // abgeblendeten Zeichen sähe nach einem Zeichenfehler aus.
                shadows: earned
                    ? const <Shadow>[
                        Shadow(
                          color: Color(0x66B48C14),
                          offset: Offset(0, 1),
                          blurRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FactFont.display,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                height: 1.1,
                letterSpacing: 0.2,
                color: card.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
