import 'package:fact_app/app/localization/app_language.dart';

/// Handgepflegte Oberflächentexte, die die PWA **sichtbar anzeigt, ohne sie
/// als i18n-Schlüssel zu führen**.
///
/// ## Warum es diese Datei gibt
///
/// `CLAUDE.md` verlangt, dass jede Beschriftung über `AppStrings` kommt.
/// `tool/generate_i18n.dart` erzeugt die Tabellen dafür aus der PWA und
/// überschreibt `lib/app/localization/generated/` bei jedem Lauf. Ein von Hand
/// eingetragener Schlüssel wäre dort beim nächsten Lauf weg und würde
/// `--check` rot machen. Es gibt aber Texte, die die PWA dem Nutzer zeigt und
/// trotzdem nicht als Schlüssel führt. Für genau die ist diese Datei der
/// dritte Weg. Sie liegt **außerhalb** von `generated/`, damit der Generator
/// sie nie anfasst. Entscheidung E-39 in `REBUILD_STATUS.md`.
///
/// ## Die Gegenprüfung, die sie wieder abbaut
///
/// Ein Ergänzungs-Eintrag ist eine Notlösung, keine zweite Textquelle.
/// `tool/generate_i18n.dart` prüft deshalb in **beiden** Betriebsarten, dass
/// jeder Schlüssel von hier in der PWA wirklich fehlt. Bekommt die PWA ihn,
/// endet der Generator mit Exit-Code 1 und nennt den Schlüssel, der jetzt aus
/// der Quelle kommt und hier zu löschen ist. `AppStrings` zieht den erzeugten
/// Wert dem Ergänzungs-Wert ohnehin vor, der Umstieg wirkt also sofort und
/// nicht erst beim Aufräumen.
///
/// ## Was hier nicht hineingehört
///
/// Kein erfundener Nutzertext. Ein Schlüssel, den die PWA benutzt, aber
/// niemand je formuliert hat, braucht eine Textentscheidung und keinen
/// Eintrag. Der bekannte Fall ist `audio.dialog.volumeHint` (E-28): die PWA
/// zeigt dem Nutzer wörtlich `🔊 audio.dialog.volumeHint`. Die technische
/// Sperre dafür ist mit dieser Datei weg, der Wortlaut fehlt weiterhin.
///
/// Kein Schlüssel, der in der PWA existiert. Der gehört in die erzeugten
/// Tabellen, und der Generator setzt das durch.
///
/// Die Sprachen sind die aus [AppLanguage]. Kommt eine dazu, meldet der Test
/// in `test/app/localization/app_strings_supplement_test.dart` jede Lücke.
const Map<AppLanguage, Map<String, String>> supplementTextsByLanguage =
    <AppLanguage, Map<String, String>>{
      AppLanguage.de: <String, String>{
        // Schrittanzeige des Tutorials, `screen-tour.jsx:483`. Die Quelle baut
        // sie als hartcodierten Ternär
        // (`lang === 'en' ? `STEP ${step + 1} OF ${STEPS.length}` : ...`) und
        // hat dafür keinen Schlüssel. Wortlaut und Großschreibung wie dort.
        //
        // ## Zum Namen `tour.stepCounter`
        //
        // Der Präfix `tour.` trägt in den erzeugten Tabellen zwei verschiedene
        // Bildschirme: `tour.skip`, `tour.tapHint` und `tour.step1` bis
        // `tour.step9` gehören zum Tutorial, ab `tour.planTitle` gehört alles
        // dem Tour-Planer. Der Stamm `step` ist innerhalb von `tour.` aber
        // eindeutig dem Tutorial zugeordnet; der Planer zählt in `stops`
        // (`tour.stopsSuffix`). Damit sitzt der Schlüssel sichtbar bei
        // `tour.step1` bis `tour.step9` und nicht beim Planer.
        //
        // Nicht `tour.stepOf` genannt, obwohl die Quelle „STEP x OF y" sagt:
        // `challenge.stepOf` existiert bereits und trägt dort nur das
        // Bindewort („von" / „of"). Derselbe Name für einen ganzen Satz wäre
        // im selben Wörterbuch irreführend. `stepCounter` folgt dem
        // camelCase-Schema der Quelle (`tapHint`, `stopsSuffix`, `customTime`).
        'tour.stepCounter': 'SCHRITT {step} VON {total}',
      },
      AppLanguage.en: <String, String>{
        'tour.stepCounter': 'STEP {step} OF {total}',
      },
    };

/// Die Ergänzung für [language], leer wenn es für sie keine gibt.
Map<String, String> supplementTextsFor(AppLanguage language) =>
    supplementTextsByLanguage[language] ?? const <String, String>{};
