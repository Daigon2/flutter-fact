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
    // Der Lautstärke-Hinweis im Audio-Guide-Dialog, `screen-auth.jsx:251`.
    //
    // **Der erste Eintrag dieser Map, der einen Text trägt, den die Quelle
    // nicht hat.** Alle anderen schreiben ab, was die PWA anzeigt, ohne es
    // als Schlüssel zu führen. Hier zeigt die PWA gar keinen Text, sondern
    // wörtlich `🔊 audio.dialog.volumeHint`, weil `window.t` bei einem
    // fehlenden Schlüssel den Schlüsselnamen zurückgibt. Das ist E-28, und es
    // ist ein Defekt der Quelle und keine Vorlage.
    //
    // Der Wortlaut ist am 02.09.2026 vom Eigentümer freigegeben. Er sagt, was
    // der Kommentar an der Fundstelle als Absicht nennt
    // (`// A2 (Daniel-Feedback): expliziter Lautstaerke-Hinweis vor
    // Aktivierung`) und was der Dialog braucht: er schaltet den Modus für
    // blinde und sehbehinderte Nutzer ein, ab dem alles gesprochen wird.
    //
    // **Englisch ist hier echtes Englisch und nicht derselbe deutsche Satz.**
    // Das unterscheidet diesen Eintrag von den Blöcken `challenge.huntPill.*`
    // und Verwandten, die den deutschen Wert doppelt tragen. Der Grund steht
    // in `CLAUDE.md` unter „The PWA is a reference, not a gold standard":
    // hartcodiertes Deutsch ist ein Defekt und keine Parität, und wo die
    // Quelle überhaupt keinen Text hat, gibt es auch nichts nachzuahmen.
    'audio.dialog.volumeHint':
        'Stell vorher die Lautstärke deines Geräts ein. Ab der Aktivierung '
        'wird alles gesprochen.',
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
    // In der Quelle auch im englischen Modus deutsch: das `STEPS`-Array
    // existiert nur einmal und wird nicht pro Sprache gebaut.
    //
    // **Der Neubau übersetzt es trotzdem**, seit dem 02.09.2026. Bis dahin
    // stand hier derselbe deutsche Wert in beiden Karten, mit genau dieser
    // Beobachtung als Begründung. Der Eigentümer hat das aufgehoben:
    // englischsprachige Nutzer sehen Englisch, und ein hartcodierter
    // deutscher Text in der Quelle ist ein Defekt und keine Parität. Siehe
    // `CLAUDE.md`, „The PWA is a reference, not a gold standard".
    //
    // Der Nachbar `tour.step1.meta` bleibt in beiden Karten gleich, und das
    // ist kein Versäumnis: „— GOETHE" ist eine Namensnennung.
    'tour.step9.meta': 'PUSH AUS DER HOSENTASCHE',

    // Die Aktennummer im Kopfbereich der Fakt-Akte,
    // `screen-fact.jsx:367`: `Akte #{fact.nr || fact.id}`. Der Text steht
    // dort wörtlich im JSX und nicht in `translations.jsx`, also kein
    // `t()`-Aufruf und kein Schlüssel.
    //
    // Die Quelle hat nur diese eine Fassung und zeigt sie auch im
    // englischen Modus deutsch. **Der Neubau nicht mehr, seit dem
    // 02.09.2026:** die englische Karte trägt „File #{nr}". Bis dahin stand
    // hier derselbe deutsche Wert mit dem Hinweis, das sei „exakte Parität
    // und keine vergessene Übersetzung". Genau diese Lesart hat der
    // Eigentümer aufgehoben, ein hartcodierter deutscher Text der Quelle ist
    // ein Defekt und keine Vorlage.
    //
    // **Der englische Wortlaut war offen und ist es nicht mehr.** Er kostete
    // genau das, was hier vorhergesagt war: eine einzige Zeichenkette, weder
    // der Schlüsselname noch die Aufrufstelle in `fact_page.dart` haben sich
    // geändert. Bekommt die PWA
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

    // Die Entfernungszeile der Mini-Vorschau **ohne Ortung**,
    // `screen-map.jsx:3856-3858`:
    // `lang === 'en' ? '🔒 Location unknown — too far' : '🔒 Standort
    // unbekannt — zu weit weg'`. Ein Ternär im JSX, kein `t()`-Aufruf, also
    // kein Schlüssel in der PWA.
    //
    // **Beide Sprachen stehen wörtlich in der Quelle**, wie bei
    // `fact.sourceMissing` und anders als bei `fact.fileNumber`. Hier ist
    // also nichts erfunden und nichts entschieden, nur abgeschrieben.
    //
    // **Ausdrücklich nicht der E-28-Fall.** Dort zeigt die PWA dem Nutzer den
    // nackten Schlüsselnamen, weil der Schlüssel fehlt; hier zeigt sie
    // fertigen Text und führt ihn bloß nicht als Schlüssel. Der Unterschied
    // entscheidet, ob ein Eintrag hierher darf, siehe den Kopf dieser Datei.
    //
    // Das Schlosszeichen gehört zum Text und nicht zum Widget, weil es in
    // der Quelle in derselben Zeichenkette steht wie das Wort. Der
    // Gedankenstrich bleibt, wie bei `puzzle.photoCaption`: die Schreibregel
    // gegen Gedankenstriche gilt für selbst formulierten Text, nicht für eine
    // Abschrift.
    'map.teaser.locationUnknown': '🔒 Standort unbekannt — zu weit weg',

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
    // ein nackter Textknoten `Aufgabe`, ohne Ternär und ohne `t()`. Die
    // Quelle zeigt ihn deshalb auch im englischen Modus deutsch.
    //
    // **Der Neubau übersetzt, seit dem 02.09.2026** („Task"), derselbe Fall
    // wie `fact.fileNumber` und `tour.step9.meta` und aus demselben Grund.
    // Das Widget schreibt die Beschriftung groß, auf Englisch steht dort also
    // `TASK`.
    'puzzle.taskLabel': 'Aufgabe',

    // Die Leiste unter dem historischen Foto, `puzzle-sheet.jsx:176`,
    // ebenfalls ein nackter Textknoten. In der Quelle in beiden Sprachen
    // deutsch, im Neubau seit dem 02.09.2026 übersetzt. Der Gedankenstrich
    // der Quelle wird dabei nicht mitgenommen, die englische Fassung setzt
    // einen Doppelpunkt.
    //
    // **Der Gedankenstrich bleibt.** Er steht so in der
    // Verhaltensquelle; die Schreibregel gegen Gedankenstriche gilt für
    // Text, den wir selbst formulieren, nicht für eine Abschrift.
    'puzzle.photoCaption': 'Damals — was hat sich verändert?',

    // ── Schnitzeljagd-Assistent, `screen-challenge.jsx` ────────────────
    //
    // Zwölf sichtbare Texte des Assistenten, keiner mit Schlüssel in der
    // PWA. Sie stehen dort als Ternär `lang === 'de' ? … : …` oder als
    // literaler Vorgabewert im JSX. **Beide Sprachen stehen jeweils in
    // der Quelle**, außer bei `challenge.bubbleTitle`, das nur einmal
    // existiert.
    //
    // Zum Präfix: `challenge.` trägt in den erzeugten Tabellen bereits
    // die Schlüssel dieses Bildschirms. Die elf Namen mit
    // `challenge.setup.` sitzen damit bei ihren Nachbarn und sind
    // zugleich als „gehört zum Assistenten" erkennbar.

    // Der Titel der Marken-Blase, `:964` als Vorgabewert
    // (`title = 'Challenge'`) und `:1660` beim Aufruf noch einmal
    // wörtlich gesetzt. Kein `t()`-Aufruf.
    //
    // **Nicht `tab.challenge` benutzen**, obwohl dort dasselbe Wort
    // steht: das ist die Beschriftung des Reiters in `chrome.jsx`. Wer
    // den Reiter umbenennt, würde sonst die Überschrift des Bildschirms
    // mit umbenennen, ohne es zu merken.
    'challenge.bubbleTitle': 'Challenge',

    // Die drei Beschreibungen der Schwierigkeitskarten, `:1851-1853`,
    // `:1858-1860` und `:1865-1867`.
    //
    // **Nicht zu verwechseln mit `challenge.easyDesc`,
    // `challenge.mediumDesc` und `challenge.hardDesc`**, die es in den
    // erzeugten Tabellen gibt. Die tragen kürzere Sätze („Ideal für
    // erste Erkundung.") und gehören zur Tabelle `SNJD_DIFF`
    // (`:153-169`), also zum alten Demo-Pfad. Der Assistent zeigt die
    // langen Fassungen, und beide Varianten stehen gleichzeitig in der
    // Quelle. Wer hier die kurzen Schlüssel einsetzt, zeigt einen
    // anderen Text, als die PWA zeigt.
    'challenge.setup.easyDesc':
        'Pfeil und Distanz weisen dir den Weg. Ideal für die erste '
        'Erkundung.',
    'challenge.setup.mediumDesc':
        'Nur Distanz, kein Pfeil. Für neugierige Stadtkenner.',
    'challenge.setup.hardDesc':
        'Nur das Rätsel, keine Navi. Pro Station kannst du Hinweise '
        'kaufen. Nur für echte Locals.',

    // Die Überschrift über den drei Dauer-Karten, `:1896`.
    'challenge.setup.durationLabel': 'Dauer',

    // Die Beschriftung einer Dauer-Karte, `:1900-1902`: dort steht
    // `label: '30 min'` je Karte wörtlich, in beiden Sprachen gleich.
    // Hier eine Vorlage statt dreier Zeichenketten, damit die Zahl aus
    // `HuntDuration.minutes` kommt und nicht zweimal im Code steht.
    'challenge.setup.durationCard': '{minutes} min',

    // Die Zeile unter der Zahl, `:1912`:
    // `{d.stops} {lang === 'de' ? 'Stationen' : 'stops'}`.
    //
    // Nicht `tour.stopsSuffix`: das trägt „Stopps" und „stops", also im
    // Deutschen ein anderes Wort. Der Tour-Planer zählt Stopps, die
    // Schnitzeljagd Stationen.
    'challenge.setup.stopsSuffix': 'Stationen',

    // Der Kopf des Themen-Filters, `:1545`.
    'challenge.setup.topicsLabel': 'Themen (optional)',

    // Der Knopf, der die Auswahl leert, `:1551`. Er heißt „Alle", weil
    // danach wieder alle Themen gelten, nicht weil er alle auswählt.
    'challenge.setup.topicsClear': 'Alle',

    // Die Zeile unter dem Themen-Gitter, `:1574-1576`. Die Quelle
    // unterscheidet Einzahl und Mehrzahl mit `selected.length > 1`,
    // deshalb zwei Schlüssel statt eines mit Platzhalter-Grammatik.
    // Der Gedankenstrich steht so in der Quelle.
    'challenge.setup.topicsHintOne':
        '{count} Thema ausgewählt — weniger Fakten verfügbar',
    'challenge.setup.topicsHintMany':
        '{count} Themen ausgewählt — weniger Fakten verfügbar',

    // Der Startknopf des Solo-Pfads, `:1986`.
    //
    // Nicht `challenge.cta.start`: das trägt „Schnitzeljagd starten →",
    // also einen anderen Text mit Pfeil, und gehört zum alten
    // Setup-Bildschirm.
    'challenge.setup.startCta': 'Starten',

    // ── Startpunkt-Picker, `screen-challenge.jsx:2979-3102` ────────────
    //
    // E-46: **der deutsche Teil ist Abschrift, der englische ist
    // hergeleitet.** Die Quelle schreibt jeden dieser Texte hartcodiert
    // ins JSX, ohne `t()` und ohne englische Fassung; der Picker ist im
    // englischen Modus also vollständig deutsch. Die deutschen Werte
    // stehen deshalb wortgleich hier, einschließlich Zeichen und
    // Gedankenstrich.
    //
    // **Die englischen Fassungen unten warten auf Janeks Bestätigung.**
    // Sie sind hergeleitet und nicht freigegeben, wie bei E-28. Bis dahin
    // ist der Bildschirm in beiden Sprachen vollständig und der erfundene
    // Anteil als solcher markiert. Die einzige Ausnahme ist
    // `challenge.hotspot.noFacts`: dafür stehen **beide** Sprachen in der
    // Quelle (`:4348-4350`), der Wert ist also Abschrift.
    //
    // Zum Präfix `challenge.hotspot.`: der Picker heißt in der Quelle
    // `HotspotPickView` und wird über `view === 'hotspot'` eingeblendet
    // (`:4441`). Die Schlüssel sitzen damit sichtbar bei
    // `challenge.setup.*` und sind trotzdem vom Assistenten getrennt.
    // **Nachtrag vom 02.09.2026: diese Begründung ist aufgehoben.** Der
    // Eigentümer hat E-61 grundsätzlich entschieden: englischsprachige Nutzer
    // sehen Englisch, und hartcodiertes Deutsch in der Quelle ist ein Defekt
    // und keine Parität. Die englischen Werte stehen deshalb übersetzt da.
    // Was noch in beiden Karten gleich ist, steht auf der Ausnahmeliste im
    // Test und ist dort je einzeln begründet.

    // Die erste Zeile der Auswahl, `:3025`. Sie erscheint nur, wenn eine
    // Nutzerposition vorliegt.
    'challenge.hotspot.here': 'Hier wo ich bin',

    // Die drei **gezählten** Dichten, `:3005-3007`.
    //
    // Nicht mit den drei gelesenen darunter verwechseln: „Hohe
    // Faktendichte" steht zweimal in der Quelle, einmal mit `✓` und
    // einmal mit `💎`. Gleiche Worte, anderes Zeichen, und beide werden
    // gezeigt. Wer hier zusammenlegt, ändert sichtbares Verhalten.
    'challenge.hotspot.densityLocalHigh': 'Hohe Faktendichte ✓',
    'challenge.hotspot.densityLocalMedium': 'Mittlere Dichte 🟡',
    // Der Gedankenstrich steht so in der Quelle; die Schreibregel gegen
    // Gedankenstriche gilt für selbst formulierten Text, nicht für eine
    // Abschrift. Dieselbe Begründung wie bei `puzzle.photoCaption`.
    'challenge.hotspot.densityLocalLow':
        'Wenig Fakten ⚠ — empfohlen sind dichte Gebiete',

    // Die vier **gelesenen** Dichten, `:3015-3018`. Der letzte ist der
    // Rückfall der Quelle für jeden Wert, den sie nicht kennt.
    'challenge.hotspot.densityVeryHigh': 'Sehr hohe Faktendichte 💎',
    'challenge.hotspot.densityHigh': 'Hohe Faktendichte 💎',
    'challenge.hotspot.densityMedium': 'Mittlere Faktendichte ✨',
    'challenge.hotspot.density': 'Faktendichte',

    // Der Zusatz hinter der Dichte, `:3034`:
    // `` · ~${walkMin(h.dist)} Min Fußweg``. Das Trennzeichen ` · ` steht
    // in der Quelle **außerhalb** dieses Textes und deshalb auch hier im
    // Widget: ein Trennzeichen am Anfang eines Sprachwerts überlebt die
    // erste Übersetzung nicht.
    'challenge.hotspot.walkMinutes': '~{minutes} Min Fußweg',

    // Die Kickerzeile, `:3055`. Die Quelle schreibt „Schritt 3 von 3"
    // wörtlich hin; die Großschreibung kommt aus
    // `textTransform: 'uppercase'` am Element (`:3054`) und steht deshalb
    // nicht im Wert, sondern im Widget.
    //
    // Nicht `tour.stepCounter` benutzen: das gehört dem Tutorial, trägt
    // die Großschreibung im Wert und würde beim nächsten Umbau des
    // Tutorials still diesen Bildschirm ändern.
    'challenge.hotspot.stepCounter': 'Schritt {step} von {total}',

    // Überschrift und Unterzeile, `:3057` und `:3059`.
    'challenge.hotspot.title': 'Wo startest du?',
    'challenge.hotspot.subtitle':
        'Wir setzen die ersten Rätsel in der Nähe deines Startpunkts.',

    // Der Startknopf, `:3093`. Der Pfeil steht im Text, wie in der
    // Quelle.
    'challenge.hotspot.startCta': 'Hunt starten →',

    // Der Zustand ohne jede Auswahl, `:3046`. Er tritt nur ein, wenn es
    // **weder** eine Nutzerposition **noch** einen Hotspot der Stadt
    // gibt.
    'challenge.hotspot.empty':
        'Für diese Stadt sind noch keine Hotspots vorhanden.',

    // Der Hinweis, wenn der Generator nichts liefert, `:4348-4350`.
    // **Beide Sprachen stehen in der Quelle**, hier ist nichts erfunden.
    'challenge.hotspot.noFacts':
        'Für diese Stadt sind noch keine klassifizierten Fakten verfügbar.',

    // ── Jagd-Pille, `HuntPill` in `screen-map.jsx:1011-1135` ───────────
    //
    // Sechs sichtbare Texte der laufenden Solo-Jagd, keiner mit Schlüssel in
    // der PWA. **Alle sechs stehen nur auf Deutsch da, und das ist Absicht,
    // nicht ein vergessenes Englisch:** die Quelle zeigt diese Pille auch im
    // englischen Modus deutsch, sie hat für keinen der sechs Texte einen
    // zweiten Wortlaut. Übernommen ist deshalb genau das, was `fact.fileNumber`,
    // `tour.step9.meta`, `puzzle.taskLabel` und `puzzle.photoCaption` schon
    // vormachen: derselbe deutsche Wert steht in beiden Sprachkarten, damit
    // `AppStrings` in beiden Sprachen dasselbe Ergebnis liefert wie die Quelle,
    // ohne dass irgendwo eine erfundene englische Fassung stünde.
    //
    // Zum Präfix: nicht `challenge.pill.`, obwohl das dem Muster von
    // `challenge.setup.` und `challenge.hotspot.` am nächsten läge. Die
    // erzeugten Tabellen führen bereits `challenge.pills.*` (Mehrzahl, die vier
    // Marketing-Kacheln des Startbildschirms, `screen-onboarding.jsx`), und ein
    // fast gleich geschriebenes zweites Präfix wäre eine Falle für den nächsten
    // Blick in die Tabelle. `challenge.huntPill.` trägt denselben Namen wie die
    // Quellfunktion `HuntPill` und ist von `challenge.pills.` unverwechselbar.
    //
    // Zu den Emoji: wo die Quelle ein Zeichen als **eigenständiges Präfix**
    // vor einen Text setzt (💡 vor „Tipps", 🔒 vor „Tipp freischalten…", ▲ vor
    // „Schließen"), steht es hier **nicht** im Wert. Dasselbe Muster wie beim
    // `icon`-Feld von `AuthField` (`signup_page.dart:352`) und wie es der
    // Kopfkommentar dieser Datei für `audio.dialog.volumeHint` (E-28) vorführt:
    // ein Icon ist Bildschmuck des Widgets, kein Bestandteil des Lesetexts.
    // 🪙 dagegen steht **im** Wert von `hintLocked`, weil es mitten im Satz
    // sitzt und zur Aussage „vom Fakt-Lohn" gehört, nicht davor.
    // **Nachtrag vom 02.09.2026: diese Begründung ist aufgehoben.** Der
    // Eigentümer hat E-61 grundsätzlich entschieden: englischsprachige Nutzer
    // sehen Englisch, und hartcodiertes Deutsch in der Quelle ist ein Defekt
    // und keine Parität. Die englischen Werte stehen deshalb übersetzt da.
    // Was noch in beiden Karten gleich ist, steht auf der Ausnahmeliste im
    // Test und ist dort je einzeln begründet.

    // Die Stationszeile, `:1086`: `Station {activeHunt.currentStopIdx + 1} /
    // {activeHunt.stops.length}`. Nicht `challenge.hotspot.stepCounter`
    // („Schritt {step} von {total}"), das ist ein anderer Wortlaut für einen
    // anderen Bildschirm, und nicht `puzzle.stationCounter` („Station
    // {station}"), dem hier das zweite Zahlenfeld fehlt.
    'challenge.huntPill.stationCounter': 'Station {station} / {total}',

    // Die Beschriftung des Tipp-Knopfs, `:1103`. Das 💡 steht davor und wird
    // vom Widget gezeichnet, siehe oben.
    'challenge.huntPill.hintsLabel': 'Tipps',

    // Der gesperrte Hinweis, `:1121`: `🔒 Tipp freischalten (−{HINT_COSTS[idx]}
    // 🪙 vom Fakt-Lohn)`. Nachgeprüft, welches Zeichen wo steht: `−` ist U+2212
    // (Minuszeichen, keine Ziffernsatz-Auszeichnung und kein Gedankenstrich),
    // 🔒 ist das abtrennbare Präfix (siehe oben, außerhalb des Werts), 🪙 sitzt
    // mitten im Satz und bleibt deshalb hier stehen.
    'challenge.huntPill.hintLocked':
        'Tipp freischalten (−{cost} 🪙 vom Fakt-Lohn)',

    // Der Einklapp-Text, `:1130`: `▲ Schließen`. Das ▲ ist derselbe Fall wie
    // 💡 und 🔒 oben.
    'challenge.huntPill.close': 'Schließen',

    // Der Rückfalltext ohne Hinweis aus der Datenbank, `:1036` und `:1040`
    // wortgleich: `stop.nextHint || 'Schau dich in der Umgebung aufmerksam
    // um.'`. Kein Emoji, keine Interpunktion außerhalb des Punkts am Ende.
    'challenge.huntPill.hintFallback':
        'Schau dich in der Umgebung aufmerksam um.',

    // Der Platzhalter für einen fehlenden Stationstitel, `:1089`:
    // `stop.factTitle || stop.title || '—'`. Das Zeichen ist U+2014
    // (Gedankenstrich); er steht hier als **Abschrift** eines Platzhalters der
    // Quelle und nicht als selbst gesetzte Pause in eigener Prosa, dieselbe
    // Ausnahme wie bei `puzzle.photoCaption` weiter oben.
    'challenge.huntPill.missingTitle': '—',

    // ── Pause- und Ergebnisbildschirm der Jagd, `screen-challenge.jsx:2797-
    // 2980` ───────────────────────────────────────────────────────────────
    //
    // Zweiundzwanzig sichtbare Texte, keiner mit Schlüssel in der PWA, aus
    // `HuntPauseScreen` (`:2797-2895`), `HuntStatTile` (`:2896-2909`),
    // `HuntStopRow` (`:2911-2950`) und `HuntResultScreen` (`:2952-2980`).
    // **E-61 wie bei der Jagd-Pille**: die Quelle zeigt jeden dieser Texte
    // auch im englischen Modus deutsch, für keinen gibt es eine zweite
    // Fassung. Deshalb steht in beiden Sprachkarten derselbe deutsche Wert.
    //
    // Zum Präfix: `challenge.huntPause.` für den Pausebildschirm,
    // `challenge.huntResult.` für den Ergebnisbildschirm, nach demselben
    // Muster wie `challenge.huntPill.` weiter oben: eigene Namen für die
    // jeweilige Quellfunktion, nicht `challenge.pause.` oder
    // `challenge.result.`, die zu leicht mit anderen Bildschirmen
    // verwechselt würden.
    // **Nachtrag vom 02.09.2026: diese Begründung ist aufgehoben.** Der
    // Eigentümer hat E-61 grundsätzlich entschieden: englischsprachige Nutzer
    // sehen Englisch, und hartcodiertes Deutsch in der Quelle ist ein Defekt
    // und keine Parität. Die englischen Werte stehen deshalb übersetzt da.
    // Was noch in beiden Karten gleich ist, steht auf der Ausnahmeliste im
    // Test und ist dort je einzeln begründet.

    // Die drei Kachel-Beschriftungen, `:2832-2834`.
    'challenge.huntPause.stopsLabel': 'Stops',
    'challenge.huntPause.pointsLabel': 'Punkte',
    'challenge.huntPause.timeLabel': 'Zeit',

    // Der Platzhalter der Zeit-Kachel. **Kein `DateTime.now()`, kein
    // `Timer`**: E-19 verbietet dem Client, eine Dauer zu rechnen, an der
    // eine Belohnung hängt, siehe den Kopfkommentar von `hunt_run.dart` und
    // von `hunt_pause_view.dart`. Dasselbe Zeichen wie
    // `challenge.huntPill.missingTitle` (U+2014), hier aber ein eigener
    // Schlüssel: er steht für eine fehlende Zeit und nicht für einen
    // fehlenden Titel, und ein Test soll das benennen können.
    'challenge.huntPause.timePlaceholder': '—',

    // Der Abschnittstitel über der Stationsliste, `:2838`.
    'challenge.huntPause.stationsHeading': 'Stationen',

    // Die beiden Knöpfe unten, `:2849-2863`.
    'challenge.huntPause.backToMap': 'Zurück zur Karte',
    'challenge.huntPause.abort': 'Hunt abbrechen',

    // Die Rückfrage, `:2877-2889`.
    'challenge.huntPause.abortConfirmMessage':
        'Punkte gehen verloren. Wirklich abbrechen?',
    'challenge.huntPause.abortConfirmYes': 'Ja, abbrechen',
    'challenge.huntPause.abortConfirmNo': 'Doch weiterspielen',

    // Die drei Ersatztexte einer Station ohne enthüllten Titel,
    // `:2930-2933`. Der Kommentar der Quelle nennt den Grund, `:2925-2926`:
    // ein Titel vorab würde verraten, wohin die Jagd führt. Eins-basiert wie
    // in der Quelle (`idx + 1`).
    'challenge.huntPause.stopSkipped': 'Station {station} · übersprungen',
    'challenge.huntPause.stopCurrent': 'Station {station} · aktuell',
    'challenge.huntPause.stopPending': 'Station {station}',

    // Die drei Schwierigkeitsstufen, Entscheidung 3 von Schritt 39:
    // `hunt.difficulty` steht in der Quelle als roher Datenwert da (`:2828`),
    // und `puzzle_difficulty.dart` verlangt ausdrücklich, dass eine Anzeige
    // über `AppStrings` läuft und nicht über `PuzzleDifficulty.code`. Die
    // Werte sind deshalb hier hinterlegt und sichtbar identisch mit der
    // Quelle; wer künftig englische Wörter will, ändert zwei Zeilen in
    // dieser Datei und keine im Code.
    'challenge.huntPause.difficulty.leicht': 'leicht',
    'challenge.huntPause.difficulty.mittel': 'mittel',
    'challenge.huntPause.difficulty.schwer': 'schwer',

    // ── Ergebnisbildschirm, `HuntResultScreen`, `:2952-2977` ──────────────
    'challenge.huntResult.title': 'Hunt beendet!',
    'challenge.huntResult.pointsLabel': 'Punkte erspielt',
    'challenge.huntResult.solvedCount': '{solved} von {total} Stationen gelöst',

    // Die Zeitzeile, `:2967`. Derselbe Platzhaltergrund wie bei
    // `challenge.huntPause.timePlaceholder`, siehe dort und E-19; eigener
    // Schlüssel, weil dieser Bildschirm eine eigene Ergänzungs-Familie
    // trägt.
    'challenge.huntResult.timeLine': 'Zeit: {time}',
    'challenge.huntResult.timePlaceholder': '—',

    'challenge.huntResult.close': 'Fertig',
  },
  AppLanguage.en: <String, String>{
    // Siehe den deutschen Eintrag: dieser Schlüssel trägt als einziger einen
    // echt übersetzten Wert und nicht denselben deutschen Satz, weil die
    // Quelle hier keinen Text hat, den man nachahmen könnte.
    'audio.dialog.volumeHint':
        'Turn up your device volume first. From here on, everything is spoken.',
    'tour.stepCounter': 'STEP {step} OF {total}',
    'tour.step1.meta': '— GOETHE',
    'tour.step9.meta': 'A PUSH FROM YOUR POCKET',
    // Bewusst derselbe deutsche Wert wie in der DE-Karte, siehe dort.
    // **Nachtrag vom 02.09.2026: diese Begründung ist aufgehoben.** Der
    // Eigentümer hat E-61 grundsätzlich entschieden: englischsprachige Nutzer
    // sehen Englisch, und hartcodiertes Deutsch in der Quelle ist ein Defekt
    // und keine Parität. Die englischen Werte stehen deshalb übersetzt da.
    // Was noch in beiden Karten gleich ist, steht auf der Ausnahmeliste im
    // Test und ist dort je einzeln begründet.
    'fact.fileNumber': 'File #{nr}',
    'fact.sourceMissing': 'Source missing',
    // Wörtlich aus der Quelle, `screen-map.jsx:3857`. Siehe die DE-Karte.
    'map.teaser.locationUnknown': '🔒 Location unknown — too far',
    // Derselbe deutsche Wert wie in der DE-Karte: der Ternär in
    // `puzzle-sheet.jsx:150` schreibt in beiden Zweigen „Station".
    'puzzle.stationCounter': 'Station {station}',
    // Der einzige der vier, den die Quelle wirklich übersetzt, `:165`.
    'puzzle.riddleCounter': 'Riddle {number}',
    // Nackter Textknoten, `:194`, auch auf Englisch deutsch.
    'puzzle.taskLabel': 'Task',
    // Nackter Textknoten, `:176`, auch auf Englisch deutsch.
    'puzzle.photoCaption': 'Back then: what has changed?',

    // ── Schnitzeljagd-Assistent ────────────────────────────────────────
    // Begründungen stehen in der DE-Karte. Bis auf den Titel der Blase
    // hat die Quelle für jeden dieser Texte eine eigene englische
    // Fassung, sie sind also übersetzt und nicht kopiert.
    'challenge.bubbleTitle': 'Challenge',
    'challenge.setup.easyDesc':
        'Arrow and distance guide you. Perfect for a first exploration.',
    'challenge.setup.mediumDesc':
        'Distance only, no arrow. For the curious city-savvy.',
    'challenge.setup.hardDesc':
        'Riddles only, no navigation. Buy hints per stop if stuck. Only '
        'for true locals.',
    'challenge.setup.durationLabel': 'Duration',
    'challenge.setup.durationCard': '{minutes} min',
    'challenge.setup.stopsSuffix': 'stops',
    'challenge.setup.topicsLabel': 'Topics (optional)',
    'challenge.setup.topicsClear': 'All',
    'challenge.setup.topicsHintOne':
        'Filtering by {count} topic — fewer facts available',
    'challenge.setup.topicsHintMany':
        'Filtering by {count} topics — fewer facts available',
    'challenge.setup.startCta': 'Start',

    // ── Startpunkt-Picker ──────────────────────────────────────────────
    //
    // **E-46 ist am 02.09.2026 geschlossen, diese Werte sind entschieden.**
    // Janek hat kurze Oberflächentexte ausdrücklich delegiert; vierzehn
    // hergeleitete Beschriftungen sind genau das. Der Vermerk, sie warteten
    // auf Bestätigung, ist damit weg.
    // Die Quelle hat für diesen Bildschirm keine englische Fassung, sie
    // zeigt ihn auch im englischen Modus deutsch. Diese Werte sind
    // hergeleitet, nicht abgeschrieben, und dürfen ersetzt werden, ohne
    // dass sich ein Schlüsselname oder eine Aufrufstelle ändert.
    // Begründungen zu Schlüsselnamen und Zeichen stehen in der DE-Karte.
    // Die drei Werte dieses Blocks, die am weitesten vom Original
    // abweichen, für die Freigabe einzeln markiert: hier ist nichts
    // übersetzt, sondern frei formuliert, weil die Quelle für diesen
    // Bildschirm gar keine englische Fassung hat.
    'challenge.hotspot.here': 'Right where I am', // am freiesten formuliert
    'challenge.hotspot.densityLocalHigh': 'High fact density ✓',
    'challenge.hotspot.densityLocalMedium': 'Medium density 🟡',
    // Am freiesten formuliert. Ohne Gedankenstrich, anders als die
    // deutsche Zeile: die deutsche ist Abschrift aus der Quelle
    // (`screen-challenge.jsx:3007`) und behält ihren, diese hier ist eigene
    // Formulierung und folgt deshalb der Schreibregel des Projekts.
    'challenge.hotspot.densityLocalLow': 'Few facts ⚠: dense areas work better',
    'challenge.hotspot.densityVeryHigh': 'Very high fact density 💎',
    'challenge.hotspot.densityHigh': 'High fact density 💎',
    'challenge.hotspot.densityMedium': 'Medium fact density ✨',
    'challenge.hotspot.density': 'Fact density',
    'challenge.hotspot.walkMinutes': '~{minutes} min walk',
    'challenge.hotspot.stepCounter': 'Step {step} of {total}',
    'challenge.hotspot.title': 'Where do you start?',
    'challenge.hotspot.subtitle':
        'We place the first riddles near your starting point.',
    'challenge.hotspot.startCta': 'Start hunt →', // am freiesten formuliert
    'challenge.hotspot.empty': 'No hotspots available for this city yet.',
    // Der einzige Wert dieses Blocks, den die Quelle selbst auf Englisch
    // hat, `:4349`. Abschrift, keine Herleitung.
    'challenge.hotspot.noFacts':
        'No classified facts available for this city yet.',

    // ── Jagd-Pille ───────────────────────────────────────────────────────
    // Bewusst derselbe deutsche Wert wie in der DE-Karte, siehe dort: die
    // Quelle hat für diese Pille keinen englischen Wortlaut und zeigt sie auch
    // im englischen Modus deutsch.
    // **Nachtrag vom 02.09.2026: diese Begründung ist aufgehoben.** Der
    // Eigentümer hat E-61 grundsätzlich entschieden: englischsprachige Nutzer
    // sehen Englisch, und hartcodiertes Deutsch in der Quelle ist ein Defekt
    // und keine Parität. Die englischen Werte stehen deshalb übersetzt da.
    // Was noch in beiden Karten gleich ist, steht auf der Ausnahmeliste im
    // Test und ist dort je einzeln begründet.
    'challenge.huntPill.stationCounter': 'Station {station} / {total}',
    'challenge.huntPill.hintsLabel': 'Hints',
    'challenge.huntPill.hintLocked':
        'Unlock hint (−{cost} 🪙 off the fact reward)',
    'challenge.huntPill.close': 'Close',
    'challenge.huntPill.hintFallback': 'Take a careful look around you.',
    'challenge.huntPill.missingTitle': '—',

    // ── Pause- und Ergebnisbildschirm der Jagd ────────────────────────────
    // Bewusst derselbe deutsche Wert wie in der DE-Karte, siehe dort: die
    // Quelle hat für diese beiden Bildschirme keinen englischen Wortlaut und
    // zeigt sie auch im englischen Modus deutsch (E-61).
    // **Nachtrag vom 02.09.2026: diese Begründung ist aufgehoben.** Der
    // Eigentümer hat E-61 grundsätzlich entschieden: englischsprachige Nutzer
    // sehen Englisch, und hartcodiertes Deutsch in der Quelle ist ein Defekt
    // und keine Parität. Die englischen Werte stehen deshalb übersetzt da.
    // Was noch in beiden Karten gleich ist, steht auf der Ausnahmeliste im
    // Test und ist dort je einzeln begründet.
    'challenge.huntPause.stopsLabel': 'Stops',
    'challenge.huntPause.pointsLabel': 'Points',
    'challenge.huntPause.timeLabel': 'Time',
    'challenge.huntPause.timePlaceholder': '—',
    'challenge.huntPause.stationsHeading': 'Stations',
    'challenge.huntPause.backToMap': 'Back to the map',
    'challenge.huntPause.abort': 'Abandon hunt',
    'challenge.huntPause.abortConfirmMessage':
        'You will lose your points. Abandon the hunt?',
    'challenge.huntPause.abortConfirmYes': 'Yes, abandon',
    'challenge.huntPause.abortConfirmNo': 'Keep playing',
    'challenge.huntPause.stopSkipped': 'Station {station} · skipped',
    'challenge.huntPause.stopCurrent': 'Station {station} · current',
    'challenge.huntPause.stopPending': 'Station {station}',
    'challenge.huntPause.difficulty.leicht': 'easy',
    'challenge.huntPause.difficulty.mittel': 'medium',
    'challenge.huntPause.difficulty.schwer': 'hard',
    'challenge.huntResult.title': 'Hunt complete!',
    'challenge.huntResult.pointsLabel': 'Points earned',
    'challenge.huntResult.solvedCount': '{solved} of {total} stations solved',
    'challenge.huntResult.timeLine': 'Time: {time}',
    'challenge.huntResult.timePlaceholder': '—',
    'challenge.huntResult.close': 'Done',
  },
};

/// Die Ergänzung für [language], leer wenn es für sie keine gibt.
Map<String, String> supplementTextsFor(AppLanguage language) =>
    supplementTextsByLanguage[language] ?? const <String, String>{};
