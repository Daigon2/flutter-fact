import 'package:fact_app/app/localization/generated/app_strings_index.g.dart';

/// Die Sprachen, die die App ausliefert.
///
/// Entspricht `I18N.active` aus `02_Frontend/app/i18n-config.jsx`. Kommt eine
/// Sprache dazu, wird sie zuerst dort aktiviert, dann läuft
/// `tool/generate_i18n.dart` erneut, dann kommt hier ein Wert dazu. Der
/// Paritätstest in `test/app/localization/` schlägt an, solange beides
/// auseinanderläuft.
///
/// Der Code steht als eigenes Feld und nicht als `name`, weil regionale
/// Kürzel wie `pt-BR` keine gültigen Dart-Bezeichner sind.
enum AppLanguage {
  de('de'),
  en('en');

  const AppLanguage(this.code);

  /// Kürzel der Sprache, gleichzeitig Schlüssel der erzeugten Tabellen.
  final String code;

  /// Startsprache vor der ersten Wahl des Nutzers (`I18N.default`).
  static AppLanguage get initial => _byCode(generatedDefaultLanguageCode);

  /// Sprache, die einspringt, wenn ein Schlüssel fehlt (`I18N.fallback`).
  static AppLanguage get fallback => _byCode(generatedFallbackLanguageCode);

  /// Sprache zu einem Kürzel oder `null`, wenn die App sie nicht ausliefert.
  ///
  /// Bewusst nullbar: ein Kürzel aus Gerätesprache oder gespeicherter
  /// Präferenz kann etwas enthalten, das die App nicht kennt.
  static AppLanguage? fromCode(String code) {
    for (final language in values) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }

  static AppLanguage _byCode(String code) {
    final match = fromCode(code);
    assert(
      match != null,
      'Die PWA-Konfiguration nennt die Sprache "$code", das Enum AppLanguage '
      'kennt sie nicht. tool/generate_i18n.dart lief, das Enum wurde nicht '
      'nachgezogen.',
    );
    // Deutsch ist Startinhalt und Fallback der PWA. Es einer unbekannten
    // Konfiguration vorzuziehen ist besser, als beim Start zu scheitern.
    return match ?? AppLanguage.de;
  }

  /// Kürzel für Badges in der Oberfläche, entspricht `I18N.short`, etwa `DE`.
  String get isoLabel => code.toUpperCase();
}
