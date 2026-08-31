import 'package:fact_app/features/progression/domain/value_objects/trophy_tier.dart';

/// Eine Trophäendefinition der Domäne `progression`.
///
/// Entspricht einem Eintrag aus `wallet-colors.jsx: window.WalletTrophies`
/// (36 Stück), gelesen über
/// `progression/application/generated/wallet_trophies.g.dart`. Diese Domäne
/// kennt die generierte Datei nicht: Regel „Domain -> Application" gibt es in
/// `dependency-rules.md` nicht, die Übersetzung steht deshalb in
/// `progression/application/trophy_catalog.dart`.
///
/// ## Was hier bewusst fehlt
///
/// Kein Freischalt-Zeitpunkt und kein Freischalt-Status: ob eine Trophäe
/// offen ist, ist kein Datenfeld der Definition, sondern eine Laufzeitfrage
/// gegen die Menge freigeschalteter Schlüssel. Diese Menge kommt erst in
/// `progression/presentation/widgets/trophy_list.dart` als Parameter dazu, mit
/// der leeren Menge als Standard, weil `progression` heute keine Datenschicht
/// hat: der Freischaltstand läge in `user_trophies` bei Supabase.
final class Trophy {
  /// Erzeugt eine Trophäendefinition.
  const Trophy({
    required this.key,
    required this.category,
    required this.threshold,
    required this.glyph,
    required this.labelDe,
    required this.labelEn,
    required this.descDe,
    required this.descEn,
  });

  /// Eindeutiger Schlüssel, etwa `chronist`. Identifiziert die Trophäe
  /// zusammen mit `i18n.trophy.*` in der Quelle; hier steht kein i18n-
  /// Schlüssel, weil die Texte selbst schon zweisprachig in den Daten stehen.
  final String key;

  /// Die rohe Kategorie, etwa `hist`, `mile`, `city`, `secret`. Roh und kein
  /// Enum: siehe [trophyTierOf].
  final String category;

  /// Die Sammelschwelle, `null` wo `wallet-colors.jsx` das Feld nicht
  /// schreibt. Siehe [trophyTierOf] für den Ersatzwert bei der Stufe.
  final int? threshold;

  /// Das Symbol im Trophäenkreis, `glyph` in der Quelle.
  final String glyph;

  /// Deutscher Titel, `label_de`.
  final String labelDe;

  /// Englischer Titel, `label_en`.
  final String labelEn;

  /// Deutsche Beschreibung, `desc_de`.
  final String descDe;

  /// Englische Beschreibung, `desc_en`.
  final String descEn;

  /// Die abgeleitete Stufe, siehe [trophyTierOf].
  TrophyTier get tier =>
      trophyTierOf(category: category, key: key, threshold: threshold);

  @override
  bool operator ==(Object other) =>
      other is Trophy &&
      other.key == key &&
      other.category == category &&
      other.threshold == threshold &&
      other.glyph == glyph &&
      other.labelDe == labelDe &&
      other.labelEn == labelEn &&
      other.descDe == descDe &&
      other.descEn == descEn;

  @override
  int get hashCode => Object.hash(
    key,
    category,
    threshold,
    glyph,
    labelDe,
    labelEn,
    descDe,
    descEn,
  );

  @override
  String toString() => 'Trophy($key, $category)';
}
