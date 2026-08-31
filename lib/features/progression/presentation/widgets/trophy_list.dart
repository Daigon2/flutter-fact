import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/localization_providers.dart';
import 'package:fact_app/app/theme/fact_colors.dart';
import 'package:fact_app/app/theme/fact_typography.dart';
import 'package:fact_app/core/widgets/css_grayscale_filter.dart';
import 'package:fact_app/features/progression/application/trophy_catalog.dart';
import 'package:fact_app/features/progression/domain/entities/trophy.dart';
import 'package:fact_app/features/progression/domain/value_objects/trophy_tier.dart';
import 'package:fact_app/features/progression/presentation/trophy_tier_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Trophäenliste, `02_Frontend/app/screen-profil.jsx:438-468`.
///
/// ## Dieses Widget hat keinen Einstieg, und das ist Absicht
///
/// Es gibt keine Route und keinen Aufrufer in `lib/`. Gezeigt wird die Liste
/// in der Quelle auf dem Profil-Bildschirm, der `features/profile` gehört;
/// welches Feature den Einstieg baut und wie der Freischaltstand aus
/// `progression` dorthin gelangt, ist eine Cross-Feature-Frage, die dieser
/// Schritt ausdrücklich nicht löst. Dieselbe Bauform wie die Fakt-Akte
/// (Schritt 21) und das Rätsel-Sheet (Schritt 27).
///
/// `test/features/progression/presentation/widgets/trophy_list_test.dart`
/// bewacht das mit einer Textsuche über `lib/`, und dort steht auch, was
/// diese Suche **nicht** kann; dieselbe Grenze wie bei
/// `puzzle_sheet_test.dart`.
///
/// ## Was hier bewusst fehlt
///
/// Nur die Liste selbst, nicht der Rest des Profil-Bildschirms: keine
/// Überschrift „Trophäen" (`:440`, ein reiner Anzeigetext ohne i18n-Schlüssel,
/// der zum Rahmen des Profil-Bildschirms gehört), keine Streak-Kachel, keine
/// Level-Leiste, kein Leaderboard. Diese drei anderen Teile von Schritt 49
/// sind gesperrt: der Stimmen-Picker hängt an E-15, das Sitzungsende im
/// Entdecken-Modus an E-19.
///
/// ## Der Freischaltstand ist ein Parameter, keine Datenschicht
///
/// `progression` hat heute keinen Zugriff auf `user_trophies` in Supabase,
/// und dieser Block baut keinen: kein Repository, kein Provider, der etwas
/// lädt. [unlockedKeys] kommt deshalb als expliziter Parameter herein, mit
/// der leeren Menge als Standard. Eine leere Menge zeigt alle 36 Trophäen
/// gesperrt, und das ist für einen neuen Nutzer der **richtige** Zustand,
/// kein Platzhalter, der auf eine spätere Datenanbindung wartet.
///
/// ## Sprache statt i18n-Schlüssel
///
/// Titel und Beschreibung stehen zweisprachig direkt in den Daten
/// (`label_de`/`label_en`, `desc_de`/`desc_en`), genau wie bei den
/// Themenrouten. Es gibt deshalb keinen `AppStrings`-Text für eine Trophäe;
/// gelesen wird nur die aktive Sprache aus [appLanguageProvider], um zwischen
/// den beiden Feldern zu wählen.
class TrophyList extends ConsumerWidget {
  /// Erzeugt die Trophäenliste.
  ///
  /// [unlockedKeys] sind die Schlüssel (`Trophy.key`) der freigeschalteten
  /// Trophäen. Standard ist die leere Menge.
  const TrophyList({this.unlockedKeys = const <String>{}, super.key});

  /// Die freigeschalteten Trophäen-Schlüssel. Siehe den Kopf dieser Datei.
  final Set<String> unlockedKeys;

  /// Die ganze scrollbare Liste, für Layout-Tests.
  static const Key listKey = Key('trophy-list');

  /// Eine Trophäenkarte, `:446`.
  static Key cardKey(String trophyKey) => Key('trophy-card-$trophyKey');

  /// Der Symbolkreis einer Karte, `:455-461`.
  static Key iconKey(String trophyKey) => Key('trophy-icon-$trophyKey');

  /// Der Titel einer Karte, `:462`.
  static Key nameKey(String trophyKey) => Key('trophy-name-$trophyKey');

  /// Die Beschreibung einer Karte, `:463`.
  static Key subKey(String trophyKey) => Key('trophy-sub-$trophyKey');

  /// Die Stufenbeschriftung, nur bei offenen Trophäen, `:464`.
  static Key tierLabelKey(String trophyKey) => Key('trophy-tier-$trophyKey');

  /// `padding: '0 16px'` plus `paddingBottom: 4` an der Liste, `:442`.
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(16, 0, 16, 4);

  /// `gap: 10` zwischen den Karten, `:442`.
  static const double cardGap = 10;

  /// `minWidth: 90` je Karte, `:447`.
  static const double cardMinWidth = 90;

  /// `borderRadius: 16` je Karte, `:449`.
  static const double cardRadius = 16;

  /// `padding: '12px 10px'` je Karte, `:449`.
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 12,
  );

  /// `opacity: 0.4` einer gesperrten Karte, `:450`.
  static const double lockedOpacity = 0.4;

  /// `filter: 'grayscale(0.6)'` einer gesperrten Karte, `:451`.
  static const double lockedGrayscaleAmount = 0.6;

  /// `height: 2` am farbigen Balken oben, nur offen, `:454`.
  static const double topBarHeight = 2;

  /// `width/height: 44` am Symbolkreis, `:456`.
  static const double iconSize = 44;

  /// `borderRadius: 13` am Symbolkreis, `:456`.
  static const double iconRadius = 13;

  /// `margin: '0 auto 8px'`: der Randabstand nach dem Symbolkreis, `:456`.
  static const double iconBottomSpacing = 8;

  /// `border: '1.5px solid …'` am Symbolkreis, `:458`.
  static const double iconBorderWidth = 1.5;

  /// `fontSize: 24` am Symbol selbst, `:460`.
  static const double iconGlyphFontSize = 24;

  /// `marginTop: 2` an der Beschreibung, `:463`.
  static const double subTopSpacing = 2;

  /// `marginTop: 4` an der Stufenbeschriftung, `:464`.
  static const double tierLabelTopSpacing = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final FactColors colors = context.factColors;
    final List<Trophy> trophies = trophiesInDisplayOrder(
      unlockedKeys: unlockedKeys,
    );

    return SingleChildScrollView(
      key: listKey,
      scrollDirection: Axis.horizontal,
      padding: listPadding,
      child: IntrinsicHeight(
        // `display: 'flex'` ohne `alignItems` an der Liste, `:442`: CSS'
        // Standard dafür ist `stretch`. Eine gesperrte Karte hat eine
        // Textzeile weniger (keine Stufenbeschriftung, `:464`) und würde ohne
        // dieses Paar aus `IntrinsicHeight` und `stretch` niedriger sein als
        // ihre offenen Nachbarn, statt bis zur gemeinsamen Zeile zu reichen.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < trophies.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: cardGap),
              _TrophyCard(
                trophy: trophies[i],
                locked: !unlockedKeys.contains(trophies[i].key),
                language: language,
                colors: colors,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Eine einzelne Trophäenkarte, `screen-profil.jsx:446-465`.
class _TrophyCard extends StatelessWidget {
  const _TrophyCard({
    required this.trophy,
    required this.locked,
    required this.language,
    required this.colors,
  });

  final Trophy trophy;
  final bool locked;
  final AppLanguage language;
  final FactColors colors;

  @override
  Widget build(BuildContext context) {
    final TrophyTier tier = trophy.tier;
    final Color tierColor = trophyTierColors[tier]!;
    final Color borderColor = locked
        ? colors.border
        : tierColor.withAlpha(0x44);
    final Color iconBackground = locked
        ? colors.surface3
        : tierColor.withAlpha(0x22);
    final Color iconBorderColor = locked
        ? colors.border
        : tierColor.withAlpha(0x55);
    final String name = language == AppLanguage.en
        ? trophy.labelEn
        : trophy.labelDe;
    final String sub = language == AppLanguage.en
        ? trophy.descEn
        : trophy.descDe;

    Widget card = Container(
      key: TrophyList.cardKey(trophy.key),
      constraints: const BoxConstraints(minWidth: TrophyList.cardMinWidth),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: const BorderRadius.all(
          Radius.circular(TrophyList.cardRadius),
        ),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(
          Radius.circular(TrophyList.cardRadius),
        ),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: TrophyList.cardPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    key: TrophyList.iconKey(trophy.key),
                    width: TrophyList.iconSize,
                    height: TrophyList.iconSize,
                    margin: const EdgeInsets.only(
                      bottom: TrophyList.iconBottomSpacing,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(TrophyList.iconRadius),
                      ),
                      border: Border.all(
                        color: iconBorderColor,
                        width: TrophyList.iconBorderWidth,
                      ),
                      // `boxShadow: 'none'` gesperrt, sonst
                      // `0 3px 0 ${tc}44`, `:460`: kein Weichzeichner, ein
                      // harter Versatz-Schatten.
                      boxShadow: locked
                          ? null
                          : <BoxShadow>[
                              BoxShadow(
                                color: tierColor.withAlpha(0x44),
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    // Kein `FactTypography`: das Zeichen ist ein Symbol, die
                    // Größe ist alles, was es hat, wie das Typsymbol im
                    // Rätsel-Sheet.
                    child: Text(
                      trophy.glyph,
                      style: const TextStyle(
                        fontSize: TrophyList.iconGlyphFontSize,
                      ),
                    ),
                  ),
                  Text(
                    name,
                    key: TrophyList.nameKey(trophy.key),
                    textAlign: TextAlign.center,
                    style: FactTypography.heading.copyWith(
                      fontSize: 12,
                      color: colors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: TrophyList.subTopSpacing),
                  Text(
                    sub,
                    key: TrophyList.subKey(trophy.key),
                    textAlign: TextAlign.center,
                    style: FactTypography.bodyText.copyWith(
                      fontSize: 10,
                      color: colors.ink3,
                    ),
                  ),
                  if (!locked) ...<Widget>[
                    const SizedBox(height: TrophyList.tierLabelTopSpacing),
                    Text(
                      // `textTransform: 'uppercase'`, `:464`. Die Stufe
                      // selbst ist Englisch in der Quelle (`gold`, `silver`,
                      // `bronze`), kein i18n-Schlüssel.
                      tier.name.toUpperCase(),
                      key: TrophyList.tierLabelKey(trophy.key),
                      style: FactTypography.mono.copyWith(
                        fontSize: 8,
                        color: tierColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!locked)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: TrophyList.topBarHeight,
                child: ColoredBox(color: tierColor),
              ),
          ],
        ),
      ),
    );

    if (locked) {
      // `opacity: 0.4` und `filter: 'grayscale(0.6)'`, `:450-451`, beide nur
      // gesperrt. Die Reihenfolge (erst Grau, dann Deckkraft) entspricht der
      // Quelle: CSS wendet `filter` vor `opacity` auf denselben Layer an,
      // beide multiplizieren aber nur mit dem Ergebnis darunter, die
      // Reihenfolge der beiden ändert das sichtbare Bild hier nicht.
      card = Opacity(
        opacity: TrophyList.lockedOpacity,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(
            cssGrayscaleColorMatrix(TrophyList.lockedGrayscaleAmount),
          ),
          child: card,
        ),
      );
    }
    return card;
  }
}
