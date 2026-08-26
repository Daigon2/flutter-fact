// GENERIERT von tool/generate_i18n.dart. Nicht von Hand bearbeiten.
//
// Quelle, nur lesend:
//   02_Frontend/app/translations.jsx  (window.I18n.strings)
//   02_Frontend/app/audio-strings.jsx (audioDe, audioEn)
//   02_Frontend/app/i18n-config.jsx   (aktive Sprachen, Fallback)
//
// Erneut erzeugen: dart run tool/generate_i18n.dart
import 'package:fact_app/app/localization/generated/app_strings_de.g.dart';
import 'package:fact_app/app/localization/generated/app_strings_en.g.dart';

/// Sprachen, die die PWA ausliefert (`I18N.active`).
const List<String> generatedLanguageCodes = <String>['de', 'en'];

/// Startsprache vor der ersten Wahl (`I18N.default`).
const String generatedDefaultLanguageCode = 'de';

/// Sprache, die einspringt, wenn ein Schlüssel fehlt
/// (`I18N.fallback`).
const String generatedFallbackLanguageCode = 'de';

/// Texttabellen nach Sprachkürzel.
const Map<String, Map<String, String>> generatedTextsByLanguage =
    <String, Map<String, String>>{'de': appTextsDe, 'en': appTextsEn};

/// Listentabellen nach Sprachkürzel.
const Map<String, Map<String, List<String>>> generatedTextListsByLanguage =
    <String, Map<String, List<String>>>{
      'de': appTextListsDe,
      'en': appTextListsEn,
    };
