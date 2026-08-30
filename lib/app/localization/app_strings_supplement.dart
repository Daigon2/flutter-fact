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
const Map<AppLanguage, Map<String, String>>
supplementTextsByLanguage = <AppLanguage, Map<String, String>>{
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

    // Die goldene Zeile der beiden Hero-Schritte, `screen-tour.jsx:141`
    // und `:168`. Wie die Schrittanzeige kein `t()`-Aufruf, sondern ein
    // wörtlicher Wert im `STEPS`-Array, und deshalb ohne Schlüssel in der
    // PWA. Freigegeben am 28.08.2026, wortwörtlich übernommen, nichts
    // erfunden.
    'tour.step1.meta': '— GOETHE',
    // Auch im englischen Modus deutsch: das `STEPS`-Array existiert nur
    // einmal und wird nicht pro Sprache gebaut. Deshalb derselbe Wert in
    // beiden Sprachkarten, keine Übersetzung.
    'tour.step9.meta': 'PUSH AUS DER HOSENTASCHE',

    // Die Aktennummer im Kopfbereich der Fakt-Akte,
    // `screen-fact.jsx:367`: `Akte #{fact.nr || fact.id}`. Der Text steht
    // dort wörtlich im JSX und nicht in `translations.jsx`, also kein
    // `t()`-Aufruf und kein Schlüssel.
    //
    // Derselbe Wert in beiden Sprachkarten, genau wie `tour.step9.meta`
    // eine Zeile darüber: die Quelle hat nur diese eine Fassung und zeigt
    // sie auch im englischen Modus deutsch. Das ist exakte Parität und
    // keine vergessene Übersetzung.
    //
    // **Der englische Wortlaut ist offen.** Kommt er, wird hier eine
    // einzige Zeichenkette ausgetauscht; weder der Schlüsselname noch die
    // Aufrufstelle in `fact_page.dart` ändern sich dabei. Bekommt die PWA
    // den Schlüssel selbst, meldet `tool/generate_i18n.dart` es und beide
    // Einträge fallen ersatzlos weg.
    //
    // Der Platzhalter heißt `{nr}` wie die Spalte `facts.nr`, aus der der
    // Wert im Regelfall kommt. Ist sie leer, setzt die Aufrufstelle die
    // Kennung ein, wie `|| fact.id` in der Quelle.
    'fact.fileNumber': 'Akte #{nr}',

    // Die Platzhalterzeile der Quellenliste, `screen-fact.jsx:474`:
    // `{ name: lang === 'en' ? 'Source missing' : 'Quelle fehlt', … }`.
    // **Hier stehen beide Sprachen wörtlich in der Quelle**, anders als
    // bei `fact.fileNumber`; übernommen ist genau dieser Wortlaut.
    'fact.sourceMissing': 'Quelle fehlt',

    // ── Rätsel-Sheet, `puzzle-sheet.jsx` ───────────────────────────────
    //
    // Vier sichtbare Texte, keiner davon mit Schlüssel in der PWA. Alle
    // vier stehen wörtlich im JSX, drei als Ternär oder Template-String
    // und einer als nackter Textknoten. Zum Präfix: `puzzle.` trägt in
    // den erzeugten Tabellen bereits das ganze Sheet, von
    // `puzzle.type.detektiv` über `puzzle.compass.N` bis
    // `puzzle.seeResults`. Die vier Namen unten sitzen also in
    // demselben Wörterbuch wie ihre Nachbarn und nicht in einem
    // eigenen.

    // Die Stationszeile in der Marken-Blase, `puzzle-sheet.jsx:150`:
    // `(lang === 'de' ? 'Station ' : 'Station ') + (stopIdx + 1)`.
    //
    // **Der Ternär hat in beiden Zweigen dasselbe Wort.** Das sieht nach
    // einem vergessenen englischen Wortlaut aus, ist aber das, was die
    // Quelle zeigt, und wird deshalb wortgleich übernommen, wie
    // `fact.fileNumber` es vormacht. Kommt eine englische Fassung, wird
    // hier eine Zeichenkette getauscht, sonst nichts.
    //
    // `stationCounter` und nicht `station`: der Wert ist eine Zeile mit
    // laufender Nummer, dasselbe Muster wie `tour.stepCounter` weiter
    // oben. Die Großschreibung der Quelle steckt nicht im Text, sondern
    // in `textTransform: 'uppercase'` am Element, deshalb steht hier
    // gemischt geschriebener Text.
    'puzzle.stationCounter': 'Station {station}',

    // Die Überschrift über der Aufgabe, `puzzle-sheet.jsx:165`:
    // ``lang === 'en' ? `Riddle ${stopIdx + 1}` : `Rätsel ${stopIdx + 1}` ``.
    // Anders als die Stationszeile sind die Sprachen hier wirklich
    // verschieden, beide Wortlaute stehen in der Quelle.
    'puzzle.riddleCounter': 'Rätsel {number}',

    // Die Beschriftung in der Aufgaben-Karte, `puzzle-sheet.jsx:194`:
    // ein nackter Textknoten `Aufgabe`, ohne Ternär und ohne `t()`. Wird
    // deshalb auch im englischen Modus deutsch gezeigt, derselbe Fall wie
    // `fact.fileNumber` und `tour.step9.meta`.
    'puzzle.taskLabel': 'Aufgabe',

    // Die Leiste unter dem historischen Foto, `puzzle-sheet.jsx:176`,
    // ebenfalls ein nackter Textknoten und ebenfalls in beiden Sprachen
    // deutsch.
    //
    // **Der Gedankenstrich bleibt.** Er steht so in der
    // Verhaltensquelle; die Schreibregel gegen Gedankenstriche gilt für
    // Text, den wir selbst formulieren, nicht für eine Abschrift.
    'puzzle.photoCaption': 'Damals — was hat sich verändert?',
  },
  AppLanguage.en: <String, String>{
    'tour.stepCounter': 'STEP {step} OF {total}',
    'tour.step1.meta': '— GOETHE',
    'tour.step9.meta': 'PUSH AUS DER HOSENTASCHE',
    // Bewusst derselbe deutsche Wert wie in der DE-Karte, siehe dort.
    'fact.fileNumber': 'Akte #{nr}',
    'fact.sourceMissing': 'Source missing',
    // Derselbe deutsche Wert wie in der DE-Karte: der Ternär in
    // `puzzle-sheet.jsx:150` schreibt in beiden Zweigen „Station".
    'puzzle.stationCounter': 'Station {station}',
    // Der einzige der vier, den die Quelle wirklich übersetzt, `:165`.
    'puzzle.riddleCounter': 'Riddle {number}',
    // Nackter Textknoten, `:194`, auch auf Englisch deutsch.
    'puzzle.taskLabel': 'Aufgabe',
    // Nackter Textknoten, `:176`, auch auf Englisch deutsch.
    'puzzle.photoCaption': 'Damals — was hat sich verändert?',
  },
};

/// Die Ergänzung für [language], leer wenn es für sie keine gibt.
Map<String, String> supplementTextsFor(AppLanguage language) =>
    supplementTextsByLanguage[language] ?? const <String, String>{};
