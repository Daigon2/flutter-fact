import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/generated/app_strings_index.g.dart';

/// Nachschlagen der Oberflächentexte einer Sprache.
///
/// Die Schlüssel sind exakt die der PWA, also `splash.createAccountCta` und
/// `audio.direction.nw`. Deshalb gibt es hier bewusst keine erzeugten Getter
/// und kein `gen_l10n`: beim Portieren eines Screens soll der Schlüssel im
/// Dart-Code so lesen wie in `02_Frontend/app/`, sonst geht die Zuordnung zur
/// Verhaltensquelle verloren.
///
/// Was hier ausdrücklich **nicht** hingehört: Vergleichen, Normalisieren oder
/// Zuordnen von Nutzereingaben gegen Texte. `dependency-rules.md` Regel 15
/// verbietet Geschäftsregeln auf Lokalisierungs-Strings.
///
/// Die PWA verletzt das an einer belegten Stelle: `puzzle-sheet.jsx:425` baut
/// die acht Antwortknöpfe des Kompass-Rätsels aus `puzzle.compass.N` bis
/// `puzzle.compass.NW` und vergleicht in Zeile 450 den angezeigten Text gegen
/// `puzzle.expected` aus den Fakt-Daten, das deutsch ist. Auf Englisch ist das
/// Rätsel damit unlösbar. Dieser Fehler wird nicht nachgebaut, also entsteht
/// hier auch kein Vergleichswerkzeug. Die Auswertung gehört zu
/// `features/puzzles` und arbeitet mit einem sprachfreien Wert, nicht mit dem
/// Anzeigetext.
class AppStrings {
  const AppStrings._({
    required this.language,
    required Map<String, String> texts,
    required Map<String, String> fallbackTexts,
    required Map<String, List<String>> lists,
    required Map<String, List<String>> fallbackLists,
  }) : _texts = texts,
       _fallbackTexts = fallbackTexts,
       _lists = lists,
       _fallbackLists = fallbackLists;

  /// Texte für [language], mit der Fallback-Sprache im Rücken.
  factory AppStrings.of(AppLanguage language) {
    final fallback = AppLanguage.fallback;
    return AppStrings._(
      language: language,
      texts: _textsFor(language),
      fallbackTexts: _textsFor(fallback),
      lists: _listsFor(language),
      fallbackLists: _listsFor(fallback),
    );
  }

  /// Die PWA interpoliert mit `text.replace('{name}', wert)`, siehe
  /// `screen-auth.jsx:451` und `audio-player.jsx:344`. Genau diese Form wird
  /// unterstützt, eine zweite gibt es nicht.
  static final RegExp _placeholder = RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}');

  /// Die Sprache, deren Texte diese Instanz liefert.
  final AppLanguage language;

  final Map<String, String> _texts;
  final Map<String, String> _fallbackTexts;
  final Map<String, List<String>> _lists;
  final Map<String, List<String>> _fallbackLists;

  /// Text zu [key], mit den Platzhaltern aus [params] gefüllt.
  ///
  /// Die Suchreihenfolge entspricht `window.t` aus `translations.jsx`:
  /// gewählte Sprache, dann Fallback-Sprache, dann der Schlüssel selbst.
  ///
  /// Ein unbekannter Schlüssel darf in Produktion keinen Absturz auslösen, im
  /// Test aber nicht durchrutschen. Deshalb `assert` plus Rückgabe des
  /// Schlüssels: im Debug- und Testlauf scheitert der Aufruf laut, im
  /// Release-Build erscheint der Schlüssel als Text.
  ///
  /// [params] nimmt fertige Zeichenketten. Zahlen und Datumsangaben werden
  /// sprachabhängig formatiert und gehören damit zum Aufrufer, nicht in das
  /// Nachschlagen.
  String text(
    String key, {
    Map<String, String> params = const <String, String>{},
  }) {
    final raw = _texts[key] ?? _fallbackTexts[key];
    if (raw == null) {
      assert(
        false,
        'Unbekannter i18n-Schlüssel "$key" (Sprache ${language.code}). '
        'Steht der Schlüssel in 02_Frontend/app/translations.jsx? Dann '
        'tool/generate_i18n.dart erneut laufen lassen.',
      );
      return key;
    }
    return _interpolate(key, raw, params);
  }

  /// Listenwert zu [key], etwa `creator.steps` oder `profil.levelTitles`.
  ///
  /// Die PWA hinterlegt für diese wenigen Schlüssel ein Array. Die
  /// zurückgegebene Liste ist konstant und damit nicht veränderbar.
  List<String> textList(String key) {
    final raw = _lists[key] ?? _fallbackLists[key];
    if (raw == null) {
      assert(
        false,
        'Unbekannter i18n-Listen-Schlüssel "$key" (Sprache '
        '${language.code}). Ist es in der PWA ein Text statt einer Liste? '
        'Dann text() verwenden.',
      );
      return const <String>[];
    }
    return raw;
  }

  /// Ob [key] in der gewählten oder der Fallback-Sprache existiert.
  ///
  /// Für Tests und für Oberflächen, die einen Abschnitt nur zeigen, wenn es
  /// Text dafür gibt.
  bool hasText(String key) =>
      _texts.containsKey(key) || _fallbackTexts.containsKey(key);

  /// Ob [key] eine Liste liefert.
  bool hasTextList(String key) =>
      _lists.containsKey(key) || _fallbackLists.containsKey(key);

  /// Alle Textschlüssel der gewählten Sprache.
  Iterable<String> get textKeys => _texts.keys;

  /// Alle Listenschlüssel der gewählten Sprache.
  Iterable<String> get textListKeys => _lists.keys;

  @override
  bool operator ==(Object other) =>
      other is AppStrings && other.language == language;

  @override
  int get hashCode => language.hashCode;

  static Map<String, String> _textsFor(AppLanguage language) {
    final table = generatedTextsByLanguage[language.code];
    assert(
      table != null,
      'Keine Texttabelle für "${language.code}". '
      'tool/generate_i18n.dart erneut laufen lassen.',
    );
    return table ?? const <String, String>{};
  }

  static Map<String, List<String>> _listsFor(AppLanguage language) {
    final table = generatedTextListsByLanguage[language.code];
    assert(
      table != null,
      'Keine Listentabelle für "${language.code}". '
      'tool/generate_i18n.dart erneut laufen lassen.',
    );
    return table ?? const <String, List<String>>{};
  }

  String _interpolate(String key, String raw, Map<String, String> params) {
    var result = raw;
    for (final param in params.entries) {
      result = result.replaceAll('{${param.key}}', param.value);
    }
    assert(
      !_placeholder.hasMatch(result),
      'i18n-Schlüssel "$key" hat unaufgelöste Platzhalter: '
      '${_placeholder.allMatches(result).map((m) => m.group(0)).join(', ')}. '
      'Übergeben wurde: ${params.keys.isEmpty ? 'nichts' : params.keys.join(', ')}.',
    );
    return result;
  }
}
