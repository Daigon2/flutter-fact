import 'package:fact_app/app/localization/app_language.dart';
import 'package:fact_app/app/localization/app_strings_supplement.dart';
import 'package:fact_app/app/localization/generated/app_strings_index.g.dart';
import 'package:flutter/foundation.dart';

/// Nachschlagen der Oberflächentexte einer Sprache.
///
/// Die Schlüssel sind exakt die der PWA, also `splash.createAccountCta` und
/// `audio.direction.nw`. Deshalb gibt es hier bewusst keine erzeugten Getter
/// und kein `gen_l10n`: beim Portieren eines Screens soll der Schlüssel im
/// Dart-Code so lesen wie in `02_Frontend/app/`, sonst geht die Zuordnung zur
/// Verhaltensquelle verloren.
///
/// Neben den erzeugten Tabellen gibt es eine zweite, handgepflegte Quelle:
/// `app_strings_supplement.dart` trägt die wenigen Texte, die die PWA
/// sichtbar anzeigt, ohne sie als Schlüssel zu führen. Sie ist nachrangig,
/// siehe [AppStrings.debugResolve].
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
    required this._texts,
    required this._supplement,
    required this._fallbackTexts,
    required this._fallbackSupplement,
    required this._lists,
    required this._fallbackLists,
  });

  /// Texte für [language], mit der Fallback-Sprache im Rücken.
  factory AppStrings.of(AppLanguage language) {
    final fallback = AppLanguage.fallback;
    return AppStrings._(
      language: language,
      texts: _textsFor(language),
      supplement: supplementTextsFor(language),
      fallbackTexts: _textsFor(fallback),
      fallbackSupplement: supplementTextsFor(fallback),
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
  final Map<String, String> _supplement;
  final Map<String, String> _fallbackTexts;
  final Map<String, String> _fallbackSupplement;
  final Map<String, List<String>> _lists;
  final Map<String, List<String>> _fallbackLists;

  /// Die Suchreihenfolge als reine Funktion, damit sie prüfbar ist.
  ///
  /// Sie steht hier und nicht inline in [text], weil sie sich an echten Daten
  /// nicht nachweisen ließe: die Ergänzung trägt per Konstruktion nur
  /// Schlüssel, die in **keiner** erzeugten Tabelle stehen, der Generator
  /// erzwingt das. Ein Überlappungsfall kommt in Produktion also nie vor, und
  /// genau deshalb muss er hier vorgeführt werden können.
  ///
  /// ## Warum diese Reihenfolge
  ///
  /// 1. `texts`: erzeugter Text der gewählten Sprache.
  /// 2. `supplement`: Ergänzung der gewählten Sprache.
  /// 3. `fallbackTexts`: erzeugter Text der Fallback-Sprache.
  /// 4. `fallbackSupplement`: Ergänzung der Fallback-Sprache.
  ///
  /// Der erzeugte Wert schlägt den Ergänzungs-Wert derselben Sprache, weil die
  /// PWA die Textquelle ist. Bekommt sie einen Schlüssel nachträglich, soll er
  /// **sofort** von dort kommen, auch in dem Zeitfenster, in dem der
  /// Ergänzungs-Eintrag noch dasteht. Andersherum würde eine lokale Kopie die
  /// Quelle stumm überstimmen, und niemand würde es merken.
  ///
  /// Die Ergänzung der gewählten Sprache steht vor der Fallback-Sprache, weil
  /// die für den Nutzer sichtbare Regel „erst meine Sprache, dann der
  /// Rückfall" lautet und nicht „erst erzeugt, dann handgepflegt". Ein Konflikt
  /// zwischen 2 und 3 kann ohnehin nicht entstehen, siehe oben.
  @visibleForTesting
  static String? debugResolve(
    String key, {
    required Map<String, String> texts,
    required Map<String, String> supplement,
    required Map<String, String> fallbackTexts,
    required Map<String, String> fallbackSupplement,
  }) =>
      texts[key] ??
      supplement[key] ??
      fallbackTexts[key] ??
      fallbackSupplement[key];

  /// Text zu [key], mit den Platzhaltern aus [params] gefüllt.
  ///
  /// Die Suchreihenfolge entspricht `window.t` aus `translations.jsx`:
  /// gewählte Sprache, dann Fallback-Sprache, dann der Schlüssel selbst. Dazu
  /// kommt je Sprache die handgepflegte Ergänzung, siehe [debugResolve] für
  /// die vollständige Reihenfolge und ihre Begründung.
  ///
  /// Ein unbekannter Schlüssel darf in Produktion keinen Absturz auslösen, im
  /// Test aber nicht durchrutschen. Deshalb `assert` plus Rückgabe des
  /// Schlüssels: im Debug- und Testlauf scheitert der Aufruf laut, im
  /// Release-Build erscheint der Schlüssel als Text. Ein Ergänzungs-Schlüssel
  /// löst dabei nichts aus, er wird in Schritt 2 oder 4 gefunden.
  ///
  /// [params] nimmt fertige Zeichenketten. Zahlen und Datumsangaben werden
  /// sprachabhängig formatiert und gehören damit zum Aufrufer, nicht in das
  /// Nachschlagen.
  String text(
    String key, {
    Map<String, String> params = const <String, String>{},
  }) {
    final raw = debugResolve(
      key,
      texts: _texts,
      supplement: _supplement,
      fallbackTexts: _fallbackTexts,
      fallbackSupplement: _fallbackSupplement,
    );
    if (raw == null) {
      assert(
        false,
        'Unbekannter i18n-Schlüssel "$key" (Sprache ${language.code}). '
        'Steht der Schlüssel in 02_Frontend/app/translations.jsx? Dann '
        'tool/generate_i18n.dart erneut laufen lassen. Zeigt die PWA den Text '
        'ohne Schlüssel an? Dann gehört er nach '
        'app_strings_supplement.dart.',
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
  /// Text dafür gibt. Die Ergänzung zählt mit: die Frage lautet „liefert
  /// [text] etwas, ohne die Assertion auszulösen", und darauf muss die Antwort
  /// dieselbe sein wie in [text].
  bool hasText(String key) =>
      _texts.containsKey(key) ||
      _supplement.containsKey(key) ||
      _fallbackTexts.containsKey(key) ||
      _fallbackSupplement.containsKey(key);

  /// Ob [key] eine Liste liefert.
  bool hasTextList(String key) =>
      _lists.containsKey(key) || _fallbackLists.containsKey(key);

  /// Alle **erzeugten** Textschlüssel der gewählten Sprache.
  ///
  /// Ohne die Ergänzung, und das mit Absicht: das hier ist die Fläche, die
  /// `app_strings_parity_test.dart` gegen die PWA festnagelt. Nähme sie die
  /// handgepflegten Schlüssel auf, würde jeder Ergänzungs-Eintrag die
  /// Paritätszahlen verschieben und der Test hätte seine Aussage verloren. Wer
  /// die Ergänzung braucht, liest `supplementTextsByLanguage`.
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
