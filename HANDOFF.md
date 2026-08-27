# Übergabe

**Diese Datei zuerst lesen.** Sie sagt, wo der Neubau steht, was zuletzt
passiert ist und was als Nächstes kommt. Sie ist bewusst kurz und wird bei
jedem abgeschlossenen Schritt aktualisiert.

Für Details nicht hier suchen, sondern:

| Frage | Dokument |
|---|---|
| Fortschritt aller 50 Schritte, offene Entscheidungen, Datenvertrags-Fallen | `REBUILD_STATUS.md` |
| Warum die Architektur so ist | `docs/architecture/`, `docs/decisions/adr/` |
| Welche Regeln beim Programmieren gelten | `docs/engineering/`, `.claude/rules/` |
| Wie die App sich verhalten muss | die PWA im Lese-Repo, siehe `CLAUDE.md` |

---

## Stand

**Zuletzt aktualisiert:** 27.08.2026

**Phase 0 abgeschlossen. Phase 1 läuft, Schritte 7 bis 10 von 50 fertig. Die App
ist erstmals auf einem Gerät gelaufen.**

Steht: Projektgerüst, Pakete, Design-Tokens, i18n, Fakt-Datenmodell mit
Supabase-Zugang, App-Shell mit typisierten Routen und Tab-Leiste, das
Architektur-Prüfskript mit eigener Testsuite, der Startbildschirm mit zentraler
Router-Weiche für Erstlauf und Sitzung, der Audio-Aktivierungsdialog und die
Anmeldung samt Supabase-Anbindung.

**Kennzahlen:** 614 Tests grün, alle vier Gates auf Exit-Code 0, und
`flutter build apk --debug` läuft.

**Wo die Arbeit liegt:** die Schritte 7 bis 10 lagen bis zum 27.08.2026 nur auf
`claude/fact-flutter-splash-screen-a2bfc9` und waren **nie nach `main` gemerged**.
Wer von `main` aus anfängt, bekommt Schritt 6. Der Merge steht weiterhin aus.

**Neu und projektweit nützlich:** `test/support/app_fonts.dart` lädt die echten
Schriften in Widget-Tests. Ohne das zeichnet `flutter test` jede Glyphe als
Quadrat der Schriftgröße, und **jede Layout-Zusicherung misst ein Layout, das
es auf keinem Gerät gibt**. Zum Größenvergleich: „FACT" in Nunito Black 64
belegt 166 Pixel, mit der Ersatzschrift 256. Aufruf nur aus `setUpAll`, im
Rumpf von `testWidgets` hängt er. Dazu `lib/core/async/detached_work.dart` mit
`reportDetached`, weil `docs/engineering/flutter.md:151` für abgekoppelte
Arbeit nicht nur einen Helfer, sondern auch eine Fehlermeldung verlangt.

**Stand der optischen Prüfung:** Startbildschirm, Anmeldung und Registrierung
sind am Emulator gesehen (Pixel 8, 411 logische Pixel, Systemschriftgröße 1.0).
Ungeprüft bleiben iOS, echte Hardware, andere Bildschirmbreiten und große
Systemschrift. Alle Aussagen zu 360 und 320 Pixeln und zu Skalierung 2.0 sind
strukturell.

**Der Build-Blocker ist seit dem 27.08.2026 gelöst**, siehe „Android-Build:
gelöst" unter „Rechner einrichten". Es war nie ein Netzwerkproblem: Java legt
für `Selector.open()` einen Unix-Domain-Socket im Temp-Verzeichnis an, und
AF_UNIX ist auf diesem Rechner unter `AppData` nicht verbindbar. Die Umgehung
ist eine Umgebungsvariable, siehe dort. Der erste Gerätebuild ist am selben Tag
gelaufen.

---

## Als Nächstes

1. **Den Gerätelauf wiederholen.** E-38 ist umgesetzt, damit ist jede
   Beschriftung ohne eigene Laufweite schmaler geworden. Kein Test meldet
   Überlauf oder Umbruch, aber die optische Prüfung von Splash, Anmeldung und
   Registrierung ist formal wieder offen.
2. **Schritt 11, Tutorial-Overlay.** Entsteht unter `lib/app/onboarding/`
   (E-26), die Anker-Registry unter `lib/core/anchors/` (E-27, am 27.08.2026
   entschieden). Neun Schritte, zwei davon Vollbild. **Vier sind heute voll
   baubar, fünf degradieren** paritätstreu, weil ihre Anker auf dem
   Kartenbildschirm liegen und der noch ein Platzhalter ist. Die frühere Zahl
   6/3 war falsch, siehe Korrektur 13 in `REBUILD_STATUS.md`. Ein fehlender
   Anker darf weder abstürzen noch den Schritt überspringen: die Quelle setzt
   das Rechteck auf `null` und zeichnet den Schritt ohne Pfeil und Ring weiter.
3. **Unabhängige Review der Schritte 9, 10 und 11.** Schritt 9 und 10 sind
   committet und **nicht** geprüft. Die Reviews haben in dieser Sitzung jedes Mal
   echte Fehler gefunden, insgesamt zehn Mutationen, die die Suite überlebten.
4. **Entschieden am 27.08.2026:** die vier Deep-Link-Pfade bleiben `/map`,
   `/collection`, `/challenges`, `/profile`, also die Domänennamen statt der
   PWA-Bezeichner. Splash, Login und Signup sind **eigene Routen** `/splash`,
   `/login`, `/signup` mit zentraler Redirect-Weiche. Damit ist E-25 in
   `REBUILD_STATUS.md` geschlossen und der Vertrag um drei Pfade gewachsen.

Vor Phase 2 (Karte) ist eine Entscheidung fällig: **wie Discovery, Tours,
Challenges und Collection eine Karte teilen**, ohne dass ein Feature die
Presentation eines anderen importiert. Der Vorschlag steht in
`lib/features/README.md` unter „Was bewusst kein Feature ist".

---

## Protokoll

Neueste zuerst. Ein Eintrag je abgeschlossenem Schritt oder größerem Block.

### 27.08.2026, E-38: Materials Laufweite raus

Der Eingriff sitzt woanders, als jeder erwartet, der sich `FactTheme` ansieht.
Materials `letterSpacing` steht **nicht** in dem `textTheme`, das `_textTheme`
zusammenbaut, sondern in `ThemeData.typography`, und das `Theme`-Widget mischt
es erst beim Lokalisieren ein, als **Basis** unter dem eigenen Stil
(`theme_data.dart:1762`, `localTextGeometry.merge(baseTheme.textTheme)`). Ein
`letterSpacing: null` in `_textTheme` hätte deshalb genau den Wert
durchgelassen, den es entfernen soll. An einer Wegwerf-Probe gemessen: dort
stand schon vorher `null`, und auch `fontSize` war `null`. Der Eingriff läuft
jetzt über `typography` und erledigt `textTheme` und `primaryTextTheme` in einem.

Zweitens: alle 15 hartcodierten Laufweiten der Identity-Bildschirme sind gegen
`screen-auth.jsx` belegt und **keine einzige wurde geändert**. Verdächtig waren
0.1, 0.15 und 0.25, weil das genau die Material-2021-Werte sind. Sie stehen
trotzdem so in der Quelle, der Gleichklang ist Zufall. Wer hier pauschal
aufgeräumt hätte, hätte die Parität zerstört.

Drittens ist nur ein einziges festgenageltes Maß gefallen, und zwar aus dem
umgekehrten Grund als vermutet: bei 411 Pixeln gibt der Kopfhörer-Knopf jetzt
nicht mehr nach, weil die Zeile aufgeht. Die Regel gilt weiter, sie ist bei 411
nur nicht mehr beobachtbar. Deshalb auf 390 verlegt, das Rahmenmaß der Quelle,
mit unveränderten exakten Zusicherungen statt einer aufgeweichten Toleranz.
E-36 bleibt offen: der Fehlbetrag bei 360 schrumpft von rund 19,5 auf rund
14,7, er verschwindet nicht.

### 27.08.2026, erster Gerätelauf

Der Build-Blocker fiel, und danach lief die App zum ersten Mal. Vier Funde, die
keine Testsuite hätte finden können, und drei davon haben eine Annahme
widerlegt.

**Der Paketkonflikt war nicht die `minSdk`.** Seit Phase 0 stand in
`REBUILD_STATUS.md` die Vermutung, `maplibre_gl` könnte eine höhere `minSdk`
verlangen. Es setzt bei 21 an, völlig unkritisch. Der echte Konflikt liegt
zwischen AGP 9.0.1, das das Flutter-Template selbst wählt, und der Art, wie zwei
Pakete auf Flutters Kotlin-Umstellung reagieren. `maplibre_gl 0.27.0` braucht
`android.builtInKotlin=true`, `app_links` braucht `false`, und `app_links` ist
nicht einmal direkt eingebunden. Beide sind laut `flutter pub outdated` aktuell.
Gelöst durch Festnageln auf `^0.26.1`, Begründung in `pubspec.yaml`.

**Das Format-Gate war ab dem ersten Build kaputt.** `dart format .` stürzt in
`build/` an Pfaden jenseits der Windows-Längengrenze ab und meldet Exit-Code 1,
ohne dass am Code etwas falsch ist. Bis zu diesem Tag fiel das nicht auf, weil
`build/` nie existierte. Das Gate zielt jetzt auf `lib test tool`.

**Die Sprachzeile brach um, und mein Verdacht war falsch.** Sichtbar stand
„Deutsch" als „Deutsc / h". Ich hatte die Deckelung des Kopfhörer-Knopfes auf
115 Pixel verdächtigt; die band bei Skalierung 1.0 nie. Die Ursache ist `Row`
mit `Expanded`, das die Breite verteilt, bevor es die Kinder nach ihrem Bedarf
fragt. Gemessen: eine Karte braucht 127,1 Pixel min-content, verfügbar waren
118. Der Defekt trat damit auch bei 390 auf, dem Rahmenmaß der Quelle.

**Und der Fund mit der größten Reichweite ist einer am Testnetz:** die Tests
prüfen auf **Überlauf**, und ein Zeilenumbruch ist keiner. Flutter meldet
nichts, es bricht einfach um. Es gab Tests für genau diese Zeile, und sie waren
blind. Jetzt ist die Einzeiligkeit zugesichert. Dasselbe Muster beim nativen
Startbildschirm: eine Mutationsprobe hat belegt, dass XML für `flutter test`
vollständig unsichtbar ist, die Farbe auf Weiß zu setzen überlebte alle vier
Gates. Dafür gibt es jetzt Dateiprüfungen.

Nebenbefunde, jeder eine Zeile wert. Der wirksame native Startbildschirm ist
`drawable-v21/`, nicht `drawable/`, und `NormalTheme` wiegt schwerer als
`LaunchTheme`, weil `FlutterActivity` in `onCreate` darauf umstellt. Der
Emulator hatte 2 GB und schoss die App per `lowmemorykiller` ab, jetzt 4 GB.
Und zweimal habe ich mir selbst falsche Ergebnisse gebaut, indem ich Auswertung
und Ausgabe in eine `&&`-Kette gemischt habe: einmal kam ein Exit-Code 0 von
`tail`, während der Build mit 1 abbrach, einmal lief ein Build gar nicht, weil
ein vorgeschaltetes `grep` die Kette abbrach. Die Warnung in „Befehle" gilt
nicht nur für die Gates.

### 27.08.2026, Schritt 9: Anmeldung mit Auth-Unterbau

Vertrag in `identity/domain/repositories/`, Supabase-Anbindung in `data/`,
Sitzungszustand und Bildschirm in `presentation/`. 463 Tests.

Der Kern war keine Zeichenaufgabe, sondern eine Verdrahtungsfrage:
**`presentation` darf `data` nicht importieren**, ein Anmeldeformular braucht
aber Supabase. Der Weg, der alle neun Prüfungen erfüllt: ein Provider, der auf
den **Domänenvertrag** typisiert ist, mit einem untätigen Standard, und die
Implementierung kommt per Override aus `bootstrap.dart`. Der Standard fällt zur
sicheren Seite aus, er kann keinen angemeldeten Nutzer erfinden, und
`flutter test` läuft weiter ohne `--dart-define`.

Überraschend war viererlei. Erstens hätte die naheliegende Lösung an Regel 7
gescheitert: das Prüfskript meldet in `presentation` jeden Konstruktoraufruf
einer Klasse, deren Name auf `Repository`, `DataSource` oder `Client` endet. Ein
`const UnavailableAuthRepository()` im Provider wäre ein Verstoß. Die drei
bestehenden Store-Provider überleben die Prüfung nur, weil ihre Klassen auf
`Store` enden. Gelöst über einen kleingeschriebenen `const`-Wert im Vertrag,
vorher mit zwei Wegwerf-Proben belegt.

Zweitens ist `Override` aus `flutter_riverpod 3.4.2` **nicht exportiert**, eine
Funktion `List<Override> productionOverrides()` ist nicht schreibbar. Die
benannte, testbare Funktion gibt deshalb die `ProviderScope` selbst zurück.

Drittens der teuerste Testfehler dieser Sitzung: eine Mutation von
`AuthSession.==` auf Identität **überlebte** die Suite. Ursache ist Darts
`const`-Kanonisierung. Zwei gleich geschriebene `const AuthSession.signedIn(...)`
sind dasselbe Objekt, der Gleichheitstest prüfte also nichts, und mit ihm der
Test gegen das Erneuerungs-Gewitter im Router. Echte Sitzungen entstehen zur
Laufzeit und sind nicht konstant. Nach der Korrektur fällt die Mutation an fünf
Stellen.

Viertens ist der Passwort-Reset **nicht angeboten**, und der Grund ist neu:
`supabase_flutter` fährt standardmäßig PKCE, und `resetPasswordForEmail` legt
den Code-Verifier auf dem Gerät ab. Der Link ginge an die Site-URL, also in die
PWA, die den Verifier nicht hat. Eine Mail zu schicken, deren Link niemand
einlösen kann, ist schlechter als kein Angebot. Zurücksetzen läuft bis auf
Weiteres über die PWA.

Nebenbefund: `FactButton` kann **nicht** nach `core/widgets` umziehen, wie sein
eigener Kommentar vorschlägt. Regel 11 zerlegt den Pfad und meldet, dass `core`
das Konzept `fact` nicht besitzen darf. Nachgewiesen, nicht vermutet.

### 27.08.2026, Schritt 8: Audio-Aktivierungsdialog

Der 🎧-Knopf des Startbildschirms öffnet ihn, „Aktivieren" setzt eine
Präferenz, „Abbrechen" schließt nur. 384 Tests.

**Wichtig zur Erwartung:** der Dialog setzt eine Präferenz, die **nichts
bewirkt**. Es gibt keine Wiedergabe und keine Sprachausgabe, die sie liest.
Nicht gebaut, jeweils dokumentiert statt implementiert: die
iOS-DeviceMotion-Berechtigung, die gesprochene Hilfe (`announceHelp`, gehört zu
Schritt 25 und der offenen Entscheidung E-15) und `fact_audio_help_shown`, das
ohne die Hilfe keinen Konsumenten hat.

Überraschend war viererlei. Erstens verlangte die Aufgabe eine echte
Architekturentscheidung statt Zeichnen: der Bildschirm gehört `identity`, die
Audio-Präferenz laut `lib/features/README.md:22` aber `settings`, und Regel 8
der Dependency-Rules verbietet den direkten Import. Der Ausweg steht in Regel
10, „an app-level composition adapter": `SplashRoute.build` setzt die Aktion
ein, `identity` erfährt nichts von `settings`.

Zweitens rendern die beiden Dialog-Knöpfe in der PWA in der
**Browser-Standardschrift**. Ein `<button>` erbt `font-family` nicht, und
`styles.css` holt das nur für `.tab-pill button` nach, während jeder andere
Knopf der App Nunito ausdrücklich setzt. Hier ist Nunito 14 gewählt, also die
Absicht statt des sichtbaren Zustands. Nebenwirkung, die dazugehört: Arial
kennt kein Gewicht 900, in der PWA sehen beide Knöpfe gleich fett aus, im
Nachbau nicht.

Drittens, und das ist der Fund mit der größten Reichweite: **`flutter test`
lädt keine Schriften.** Jede Glyphe ist ein Quadrat der Schriftgröße, „FACT"
belegt dort 256 statt 166 Pixel. Alle Layout-Zusicherungen der Schritte 7 und 8
haben damit ein Layout geprüft, das es nicht gibt, und die Knopfzeile des
Dialogs lief schon bei Skalierung 1.0 um. Behoben mit
`test/support/app_fonts.dart`. Aufruf nur aus `setUpAll`: im Rumpf von
`testWidgets` hängt `FontLoader`, weil dort eine `FakeAsync`-Zone läuft, in der
echte Datei-Ein-/Ausgabe nie fortschreitet.

Viertens fielen mit echten Schriften zwei **echte** Überläufe auf, beide in
Schritt 7 und beide bei doppelter Systemschrift, also innerhalb von Androids
Maximum: die Wortmarke um 65 Pixel und die Sprachzeile um 3,8 Pixel. Die
Wortmarke skaliert jetzt bewusst nicht mit (CSS-`px` folgt der
Betriebssystem-Textgröße nicht, und eine feste Kachel neben einem mitwachsenden
Schriftzug wäre ein halb skaliertes Logo), der Kopfhörer-Knopf ist auf 115
Pixel gedeckelt. Ein `LayoutBuilder` wäre dort der naheliegende Weg und ist
unmöglich: die Inhaltsspalte liegt in einem `IntrinsicHeight`, und der bricht
mit `LayoutBuilder does not support returning intrinsic dimensions`.

### 27.08.2026, Schritt 7: Startbildschirm und Router-Weiche

`/splash` außerhalb der Shell, dazu `route_guards.dart` mit der Weiche als
reiner Funktion und `FirstLaunchStore` nach dem Muster des Sprach-Speichers.
Login und Signup existieren als Platzhalter, damit die drei Ausgänge ein Ziel
haben. 348 Tests.

Überraschend war fünferlei. Erstens ist der Splash **kein Ladebildschirm**: der
zeitgesteuerte Boot-Splash der PWA wurde am 06.06.2026 in Commit `83be52f`
absichtlich entfernt, das Skript in `index.html:222-245` beginnt mit
`if (!splash) return` und ist toter Code. Die Zahlen 1200 ms und 15000 ms, die
in den Vorlagen stehen, gehören zu diesem toten Pfad. Was „SplashScreen" heißt,
ist ein interaktiver Bildschirm mit drei gleichrangigen Ausgängen, darunter ein
Gastmodus, der in beiden Vorlagen fehlt.

Zweitens ist `slideUp` **zweimal** definiert, in `styles.css:251` mit
`translateY(100%)` und in `index.html:25` mit 24 Pixeln plus Deckkraft. Der
Inline-Block steht nach dem Stylesheet, bei gleichnamigen `@keyframes` gewinnt
die letzte Definition. Wer nur das Stylesheet liest, baut das Falsche.

Drittens ist `onboarding.quote` ein **toter Schlüssel**: er existiert, wird in
der PWA nirgends benutzt und weicht im Text ab (»…« statt „…", plus
„(vermutlich)"). Für das sichtbare Goethe-Zitat gibt es also keinen Schlüssel,
und Invariante 4 („kein Text hartcodieren") hat hier keine Quelle.

Viertens, und das ist die teuerste Falle: eine eigene `MediaQuery` um `FactApp`
in einem Widget-Test **verdeckt die echte**. `pumpWidget` steckt das Widget in
ein `View`, und erst dieses legt `MediaQuery.fromView` an. Die eigene sitzt
darunter, `size` und `padding` fallen auf Null, und jede Layout-Zusicherung ist
lautlos wertlos. Der richtige Weg ist
`tester.platformDispatcher.accessibilityFeaturesTestValue`. Gemessen, nicht
vermutet: 141 statt 0 als `view.padding.top`.

Fünftens hat die Safe Area andersherum gelegen als angenommen.
`index.html:101-107` setzt `env(safe-area-inset-*)` als `padding` an den
**`body`**, die PWA rückt also den ganzen Bildschirm samt Verlauf und Pins ein.
Eine `SafeArea` nur um die Inhaltsspalte hätte die Wortmarke richtig und die
fünf Pins um die Notch-Höhe zu hoch gesetzt. Die unabhängige Review hat das
gefunden, nachdem die erste Vorgabe das Gegenteil verlangte.

Nebenbefund zur Arbeitsweise: die Review hat drei Mutationen gefunden, die die
Suite überlebten, darunter „der Knopf Anmelden öffnet die Registrierung". Die
Tests sahen vollständig aus und waren es nicht. Mutationsproben sind der
einzige Weg, das zu merken.

### 26.08.2026, Schritt 6: App-Shell, Phase 0 abgeschlossen

Vier Tabs, aus `chrome.jsx:55-60` belegt statt geraten. `StatefulShellRoute`
für unabhängige Stapel, typisierte Routen über `go_router_builder`, also
erstmals Codegen.

Überraschend war dreierlei. Erstens rechnet der alte Port den Bodenabstand der
Leiste als Summe aus 14 und der Safe Area, die Quelle nimmt das Maximum, und
er setzt die Unschärfe auf 18 statt der 24 aus `chrome.jsx:78`. Beides nicht
übernommen. Zweitens zählt `Container` die Rahmenstärke zum Innenabstand,
`DecoratedBox` nicht, was den ersten Höhentest bei 76 statt 78 scheitern ließ.
Drittens schließt `analysis_options.yaml` alle `*.g.dart` aus: der Analyzer
ist für die erzeugte Routendatei blind, ein Fehler dort fällt erst beim
Kompilieren auf. Gemessen mit einer absichtlich fehlerhaften Probedatei, nicht
vermutet.

### 26.08.2026, Nachbesserungen am Fundament

Nunito 600 fehlte, wird von der PWA aber für die Tab-Leiste genutzt. Google
Fonts liefert keine statische Instanz mehr, deshalb mit `fontTools` bei
`wght=600` aus der variablen Schrift herausgeschnitten.
`always_use_package_imports` aktiviert, damit relative
Cross-Feature-Importe nicht entstehen können.

### 26.08.2026, Schritt 5: Fakt-Datenmodell und Supabase

Fehler-Isolation durch Konstruktion: kein `as`-Cast auf Rohwerte, jeder
Datensatz einzeln abgebildet, Ausfälle in einem zählbaren Bericht. Das
Rätsel-Mapping übernimmt 21 Felder statt der vier, an denen der alte Port
gescheitert ist. Vier Spalten gefunden, die im eingecheckten Schema fehlen,
aber existieren.

### 26.08.2026, Schritt 4: i18n

716 Schlüssel je Sprache, aus der PWA generiert. Die Zahl 763 in Parity-Spec
und REBUILD_PLAN ist falsch, das ist der Bestand des alten Flutter-Ports.

### 26.08.2026, Schritt 3: Design-Tokens

31 Farb-Tokens aus `styles.css`, per Test festgenagelt. Drei Alias-Paare
getrennt, die `.theme-light` nur halbseitig überschreibt.

### 26.08.2026, Architektur-Prüfskript

`tool/check_architecture.dart` mit den neun Prüfungen aus den Quality-Gates,
53 Black-Box-Tests. Ersatz für `riverpod_lint`, das mit diesem
Abhängigkeitsstand nicht auflösbar ist.

### 26.08.2026, Schritte 1 und 2: Gerüst und Pakete

`flutter create` mit den Store-Kennungen des alten Ports, damit der Neubau im
Store dieselbe App bleibt. Feature-Struktur nach der Domain-Map.

### 26.08.2026, Architektur-Gegenüberstellung

Parity-Spec gegen die fünf ADRs geprüft. Ergebnis: 21 offene Entscheidungen,
Stand in `REBUILD_STATUS.md`.

---

## Rechner einrichten

Alles hier ist **maschinenabhängig** und steht absichtlich nicht im Code.

### Flutter-SDK

Auf dem bisherigen Rechner liegt es unter `C:\flutter-fresh\bin\` und ist
**nicht** auf dem PATH. `C:\flutter` ist dort kaputt. Auf einem anderen
Rechner gilt das nicht: nimm deinen eigenen Pfad und ersetze ihn in allen
Befehlen unten.

Geprüft mit **Flutter 3.44.1 / Dart 3.12.1**.

Bevorzuge `dart analyze` gegenüber `flutter analyze`, weil das Flutter-Werkzeug
auf diesem System gelegentlich hängt.

### Pfad zur PWA

Der i18n-Generator liest die Quelltexte aus der PWA. Der Standardpfad im
Skript zeigt auf ein OneDrive-Verzeichnis des ursprünglichen Rechners. Auf
einem anderen Rechner brauchst du:

```
dart run tool/generate_i18n.dart --source <pfad-zu>/02_Frontend/app
```

oder die Umgebungsvariable `FACT_PWA_APP_DIR`. Ohne einen davon bricht das
Skript mit Exit-Code 2 und einer Anleitung ab.

**Ohne PWA-Zugang kann man trotzdem arbeiten.** Die erzeugten Sprachdateien
sind versioniert, der Generator ist nur nötig, wenn sich die PWA-Texte
ändern.

### Supabase

URL und publizierbarer Schlüssel kommen über `--dart-define`, es steht kein
Wert im Repository:

```
flutter run --dart-define=SUPABASE_URL=https://<projekt>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_<rest>
```

Gilt genauso für `flutter build apk`, `flutter build ipa` und `flutter test`.
Alternativ `--dart-define-from-file=env.json`, diese Datei gehört **nicht** ins
Repository.

### Android-Build: gelöst am 27.08.2026

**Ursache: `Selector.open()` scheitert, weil Java dafür einen Unix-Domain-Socket
im Temp-Verzeichnis anlegt, und AF_UNIX auf diesem Rechner unter `AppData`
nicht verbindbar ist.**

Die Fehlermeldung war die ganze Zeit irreführend. Sie lautet „Unable to
establish loopback connection", und alle Verdächtigen, die man daraufhin prüft,
liegen im Netzwerk-Stack. Der scheiternde Vorgang ist aber **kein
Netzwerkaufruf**, sondern ein Verbindungsaufbau auf eine **Datei**.

Der Weg dorthin, aus den JDK-Quellen (`lib/src.zip` von Temurin):

```
WEPollSelectorImpl.java:79   new PipeImpl(sp, /* AF_UNIX */ true, /*buffering*/ false)
PipeImpl.java:127            createListener(preferUnixDomain)
PipeImpl.java:132            SocketChannel.open(sa)      // sa ist eine UnixDomainSocketAddress
```

`Pipe.open()` ruft denselben Konstruktor mit `false` und geht über TCP, deshalb
**gelingt `Pipe.open()` und scheitert `Selector.open()`**. Wer die beiden
verwechselt, schließt aus einem erfolgreichen `Pipe.open()`, Java sei in Ordnung,
und sucht danach an der falschen Stelle. Genau das ist hier zwei Tage passiert.

Der Pfad der Socket-Datei kommt aus `jdk.net.unixdomain.tmpdir` und zeigt
standardmäßig auf `java.io.tmpdir`, unter Windows also nach
`%LOCALAPPDATA%\Temp`. Gemessen:

| Verzeichnis für die Socket-Datei | AF_UNIX `connect` |
|---|---|
| `C:\Users\<user>\AppData\Local\Temp` (Standard) | **Fehler** |
| `C:\Users\<user>\AppData\Local\<beliebig>` | **Fehler** |
| `C:\Users\<user>\AppData\<beliebig>` | **Fehler** |
| `C:\Users\<user>\<beliebig>` | OK |
| `C:\Users\Public\<beliebig>` | OK |
| `C:\Windows\Temp` | OK |
| `C:\gtmp` | OK |

**Alles unter `AppData` scheitert, alles andere funktioniert.** `bind` gelingt
jeweils, die Socket-Datei entsteht, nur `connect` darauf nicht. Nicht die
Ursache: Pfadlänge (61 Bytes am Wurzelpfad gehen, 54 unter `AppData` nicht), der
8.3-Kurzname `JANEKP~1`, das Leerzeichen im Profilnamen, Reparse-Punkte, der
Ordnerschutz von Defender.

**Warum es früher funktionierte:** vermutlich hat sich die Bedingung unter
`AppData` geändert, nicht Java und nicht Gradle. Der eigentliche Systemdefekt
ist damit nicht behoben, nur umgangen.

#### Die Umgehung

Eine Benutzer-Umgebungsvariable, keine Administratorrechte nötig:

```
[Environment]::SetEnvironmentVariable('JAVA_TOOL_OPTIONS', '-Djdk.net.unixdomain.tmpdir=C:\gtmp', 'User')
```

Wirkt in jedem **neu gestarteten** Programm, also auch in Android Studio.
Bestehende Terminals neu öffnen. Jede JVM gibt danach die Zeile
`Picked up JAVA_TOOL_OPTIONS: ...` auf der Fehlerausgabe aus, das ist normal.

Belegt am leeren Testprojekt unter `C:\gtmp\gt`:

```
ohne die Variable : EXIT=1  java.io.IOException: Unable to establish loopback connection
mit der Variable  : EXIT=0  BUILD SUCCESSFUL in 5s
```

Das Verzeichnis `C:\gtmp` muss existieren. Jeder Pfad außerhalb von `AppData`
geht.

#### Die Prüfschleife: eine Sekunde statt eines Builds

Als `SelectorProbe.java` ablegen, mit `java SelectorProbe.java` starten
(Quelldatei-Modus, kein `javac` nötig). Liegt unter `C:\gtmp\SelectorProbe.java`.

```java
import java.nio.channels.Pipe;
import java.nio.channels.Selector;

public class SelectorProbe {
  public static void main(String[] a) {
    try { Pipe p = Pipe.open(); p.source().close(); p.sink().close();
      System.out.println("Pipe.open() OK");
    } catch (Throwable t) { System.out.println("Pipe.open() FEHLER: " + t); }
    try { Selector s = Selector.open(); s.close();
      System.out.println("Selector.open() OK");
    } catch (Throwable t) { System.out.println("Selector.open() FEHLER: " + t.getCause()); }
  }
}
```

Gesund: beide Zeilen `OK`. Defekt: `Pipe.open() OK`, dann
`Selector.open() FEHLER: java.net.SocketException: Invalid argument: connect`.

#### Was vorher ausgeschlossen wurde, und die Lehre daraus

Diese Liste ist Geschichte, nicht Arbeitsvorrat. Sie steht hier, weil sie zeigt,
wie teuer eine irreführende Fehlermeldung wird: **vierzehn Vermutungen, jede
einzeln gemessen, alle im Netzwerk-Stack, alle richtig ausgeschlossen und alle
am falschen Objekt.**

Temp-Pfad mit Leerzeichen · Sandbox der Werkzeugumgebung · Loopback generell
(Python verbindet 127.0.0.1 fehlerfrei) · `Pipe.open()` (gelingt, siehe oben) ·
reservierte und ausgeschlossene Portbereiche · Speichermangel ·
IPv6-Auflösung von `localhost` · hängender Gradle-Daemon · beschädigte
Daemon-Registry · Neustart · TotalAV vollständig deinstalliert ·
Selektor-Implementierung (auch der alte `WindowsSelectorProvider`) · das JDK
(JBR 17, 21, 25 **und** Temurin 21) · `--no-daemon` · alle fünf
JVM-Umgebungsvariablen · Winsock-Katalog (kein einziger Layered Service
Provider) · Netzwerk-Filtertreiber (nur Microsoft) · Defender Network
Protection · `hosts`-Datei · Reihenfolge im Prozess · **Winsock- und IP-Reset
samt Neustart**.

Eine Fehlspur ist erwähnenswert, weil sie überzeugend aussah: im WFP-Dump steht
ein Filter von **Rivet Networks** (Killer Networking) auf
`FWPM_LAYER_ALE_CONNECT_REDIRECT_V4`, ohne Bedingungen, mit Aktion
`FWP_ACTION_CALLOUT_TERMINATING`, und die Software ist längst deinstalliert. Das
passte perfekt zur Fehlermeldung und war trotzdem falsch. Widerlegt hat es ein
einfacher Gegencheck: ein Filter ohne Bedingungen würde **jede** Verbindung
treffen, und das Netz funktioniert. Drei Löschversuche über die WFP-Schnittstelle
scheiterten ohnehin an `ERROR_NOT_SUPPORTED`, es wurde also nichts verändert.

Die Lehre: **den Aufrufweg lesen, bevor man der Fehlermeldung glaubt.** Die
vollständige Stapelspur (`--stacktrace`) und dreißig Zeilen JDK-Quelle haben
gelöst, was vierzehn Systemmessungen nicht gelöst haben.


### Nicht aus einem OneDrive-Pfad bauen

Der AOT-Compiler bricht an Nicht-ASCII-Verzeichnisnamen. Dieses Repository
liegt deshalb unter `C:\dev\flutter-fact`. Wenn du es woanders klonst, nimm
einen kurzen ASCII-Pfad.

---

## Befehle

### Die vier Gates

Müssen alle vier auf Exit-Code 0 stehen, bevor etwas committet wird:

```
dart format --output=none --set-exit-if-changed lib test tool
dart analyze
dart run tool/check_architecture.dart
flutter test
```

**Warum `lib test tool` und nicht `.`:** ab dem ersten Gerätebuild existiert
`build/`, und darin liegen Gradle-Zwischenprodukte mit Pfaden jenseits der
Windows-Längengrenze. `dart format .` stürzt dort mit
`PathNotFoundException: Directory listing failed` ab und liefert Exit-Code 1,
ohne dass am Quellcode etwas falsch ist. Vor dem 27.08.2026 fiel das nicht auf,
weil `build/` nie existierte. `build/` und `.dart_tool/` stehen in
`.gitignore`, das Gate soll sie also ohnehin nicht ansehen.

**Hänge kein `| tail` an einen dieser Befehle, wenn du den Exit-Code
auswertest.** Die Pipe maskiert ihn, und genau dadurch wurde hier schon ein
rotes Gate stillschweigend durchgewinkt.

Es gibt **keinen CI-Workflow**. Diese vier Befehle laufen nur, wenn jemand sie
startet.

### Generierten Code neu erzeugen

```
dart run build_runner build
dart run tool/generate_i18n.dart
```

`--delete-conflicting-outputs` gibt es in `build_runner` 2.15.1 nicht mehr, das
Flag wird nur mit einer Warnung ignoriert.

Erzeugte Dateien **sind versioniert**, `*.g.dart` steht nicht in
`.gitignore`. Grund: ADR-004 verlangt generierte typisierte Routen, und ohne
CI, die vorher `build_runner` ausführt, ließe sich ein frischer Klon nicht
kompilieren. Das ist eine bewusste Entscheidung, nachzulesen im Kommentar in
`.gitignore`.

### Drift der Sprachdateien prüfen

```
dart run tool/generate_i18n.dart --check
```

---

## Was man wissen muss, bevor man Code anfasst

Die vier Punkte, die am häufigsten falsch gemacht werden.

**1. Der REBUILD_PLAN im Lese-Repo gibt die Reihenfolge vor, nicht die
Architektur.** Sein Grundprinzip 4 nennt `provider` und ein globales
`AppState`. Das widerspricht ADR-003 und ADR-005 und gilt hier nicht. Drei
weitere nachgewiesene Sachfehler des Plans stehen in `REBUILD_STATUS.md`.

**2. Die Domäne darf fast nichts importieren.** Erlaubt sind nur
`dart:`-Importe und Dateien der eigenen Feature-Domäne. Kein Flutter, kein
Riverpod, kein Supabase, kein Routing, auch **kein `core`**. Das prüft
`tool/check_architecture.dart` maschinell über eine Erlaubnisliste, die derzeit
leer ist.

**3. Navigation nur über typisierte Routen.** Route-Strings gibt es
ausschließlich in `lib/app/routing/`. Zum Schließen `context.pop()`, nicht
`Navigator.pop(context)`. Der Prüfer meldet jeden `Navigator.`-Aufruf außerhalb
des Routing-Verzeichnisses.

**4. Kein Text hartcodieren.** Alle Beschriftungen kommen über `AppStrings`
aus den generierten Sprachdateien. Werte für Farben, Größen und Abstände
kommen aus der PWA, nicht aus dem alten Flutter-Port, der an mehreren Stellen
weggedriftet ist.

---

## Arbeitsweise mit Claude

Bewährt hat sich, was nicht im Code steht und deshalb hier festgehalten wird.

**Spezialisten arbeiten, die Hauptsitzung orchestriert.** Die Agenten aus
`.claude/agents/` erledigen die Umsetzung, die Hauptsitzung schreibt die
Aufträge, entscheidet und führt widersprüchliche Ergebnisse zusammen. Das
Auftragsformat steht in `docs/ai/context-routing.md` unter „Context packet",
das Antwortformat in `docs/ai/agent-output.md`.

Was einen guten Auftrag ausmacht, gemessen an dem, was heute Fehler gefunden
hat: nicht „schau mal drüber", sondern benannte Prüfpunkte. Nicht „teste es",
sondern „lege eine Probe an, die den Verstoß enthält, führe die Prüfung aus,
lösche die Probe und berichte, was du so verifiziert hast". Der Unterschied
war heute mehrfach der zwischen einem grünen Lauf und einem gefundenen Fehler.

**Nach jedem Block eine unabhängige Review.** `code-reviewer` hat im ersten
Änderungssatz fünf blockierende Fehler in etwa 700 Zeilen gefunden, darunter
neun Erkennungslücken im Prüfskript, jede einzeln nachgewiesen. Der Wert liegt
im frischen Kontext: der Prüfer weiß nicht, was sich der Autor gedacht hat.

**Vor den großen Brocken der `architecture-guardian`,** nicht danach. Bei der
Rätsel-Engine und beim Map-Host entscheidet die Struktur, was danach zwei- bis
dreitausend Zeilen kostet.

**Jeden Schritt ansagen,** in der Form „Schritt N von 50: Titel". Der Stand
gehört zusätzlich hierher, siehe unten, weil eine Sitzung endet und diese
Datei bleibt.

**Nie behaupten, was nicht gelaufen ist.** Und beim Prüfen von Exit-Codes kein
`| tail` anhängen, siehe „Befehle". Diese eine Pipe hat hier schon zweimal ein
rotes Gate als grün ausgegeben.

## Diese Datei pflegen

Wer einen Schritt abschließt, aktualisiert hier:

1. **Stand:** Datum, Schrittnummer, Testzahl
2. **Als Nächstes:** was jetzt dran ist
3. **Protokoll:** einen neuen Eintrag oben, zwei bis vier Sätze. Was
   entstanden ist, und vor allem was dabei **überraschend** war. Die
   Überraschungen sind der Teil, den niemand aus dem Code zurücklesen kann.

Details gehören nicht hierher, sondern in `REBUILD_STATUS.md`. Diese Datei
soll in fünf Minuten lesbar bleiben, sonst liest sie niemand, und dann ist sie
schlimmer als keine.
