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

**Phase 0 abgeschlossen. Phase 1 läuft, Schritte 7 bis 9 von 50 fertig.**

Steht: Projektgerüst, Pakete, Design-Tokens, i18n, Fakt-Datenmodell mit
Supabase-Zugang, App-Shell mit typisierten Routen und Tab-Leiste, das
Architektur-Prüfskript mit eigener Testsuite, der Startbildschirm mit zentraler
Router-Weiche für Erstlauf und Sitzung, der Audio-Aktivierungsdialog und die
Anmeldung samt Supabase-Anbindung.

**Kennzahlen:** 463 Tests grün, alle vier Gates auf Exit-Code 0.

**Neu und projektweit nützlich:** `test/support/app_fonts.dart` lädt die echten
Schriften in Widget-Tests. Ohne das zeichnet `flutter test` jede Glyphe als
Quadrat der Schriftgröße, und **jede Layout-Zusicherung misst ein Layout, das
es auf keinem Gerät gibt**. Zum Größenvergleich: „FACT" in Nunito Black 64
belegt 166 Pixel, mit der Ersatzschrift 256. Aufruf nur aus `setUpAll`, im
Rumpf von `testWidgets` hängt er. Dazu `lib/core/async/detached_work.dart` mit
`reportDetached`, weil `docs/engineering/flutter.md:151` für abgekoppelte
Arbeit nicht nur einen Helfer, sondern auch eine Fehlermeldung verlangt.

**Wichtig:** Die App ist noch **nie gestartet**. Kein Android-Build, kein
iOS-Build, kein Emulatorlauf. Grüne Tests sagen nichts darüber, ob der erste
Gerätebuild durchläuft.

---

## Als Nächstes

1. **Android-Build zum Laufen bringen.** Blockiert durch einen
   Loopback-Fehler von Gradle, siehe „Rechner einrichten". Der erste Punkt
   dort braucht Administratorrechte. Solange das offen ist, kann niemand
   prüfen, ob `maplibre_gl` eine höhere `minSdk` verlangt, ob die vier
   SVG-Icons und Nunito bei 10px rendern und wie die Tab-Leiste mit echter
   Safe Area sitzt.
2. **Phase 1 abschließen** (Schritte 10 und 11): Registrierung und
   Tutorial-Overlay. Die geteilten Formular-Bausteine stehen in
   `lib/features/identity/presentation/widgets/`, die Registrierung soll sie
   benutzen statt sie zu verdoppeln.
3. **Entschieden am 27.08.2026:** die vier Deep-Link-Pfade bleiben `/map`,
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

### Android-Build scheitert derzeit: „Unable to establish loopback connection"

**Der erste Gerätebuild ist auf diesem Rechner nicht möglich.** Gradle bricht
nach etwa fünf Sekunden ab:

```
java.io.IOException: Unable to establish loopback connection
Caused by: java.net.SocketException: Invalid argument: connect
	at sun.nio.ch.PipeImpl$Initializer$LoopbackConnector.run
```

Der Emulator selbst läuft (`Pixel_8`, Android 17, API 37). Der Fehler entsteht
im Gradle-Launcher, wenn er sich mit seinem Daemon-Prozess verbindet:
`DefaultDaemonConnector.connectToDaemon` → `SocketConnection.<init>` →
`PipeImpl`.

**Achtung, die Notiz im alten REBUILD_PLAN nennt die falsche Ursache.** Dort
steht, `-Djava.io.tmpdir=C:/gtmp` plus `JAVA_TOOL_OPTIONS` löse das. Das ist
geprüft und hilft nicht.

Ausgeschlossen, jeweils einzeln getestet:

| Vermutung | Ergebnis |
|---|---|
| Temp-Pfad mit Leerzeichen | `-Djava.io.tmpdir=C:/gtmp` gesetzt, Variable wird übernommen, Fehler bleibt |
| Sandbox der Werkzeugumgebung | Build auch ohne Sandbox identisch fehlgeschlagen |
| Loopback generell blockiert | Python bindet und verbindet 127.0.0.1 fehlerfrei |
| Java kann keine NIO-Pipe | minimales `Pipe.open()`-Programm läuft mit demselben JDK durch |
| reservierte Portbereiche | nur 5357 und 50000–50059 belegt, unkritisch |
| Speichermangel | `-Xmx8G` auf 2G reduziert, Fehler bleibt. Frei waren 4,8 von 31,5 GB |
| IPv6-Auflösung von localhost | `preferIPv4Stack` in `JAVA_TOOL_OPTIONS`, `GRADLE_OPTS` und `org.gradle.jvmargs`, Fehler bleibt |
| hängender Gradle-Daemon | `gradlew --stop` meldete, dass keiner läuft |
| Daemon-Registry beschädigt | `~/.gradle/daemon/` beiseitegelegt, Fehler blieb, wieder zurückgelegt |
| Neustart des Rechners | Fehler unverändert |
| **TotalAV** | **vollständig deinstalliert und neu gestartet, Fehler unverändert. Damit ausgeschlossen.** Windows Defender ist danach von selbst angesprungen, Echtzeitschutz und Manipulationsschutz aktiv, keine Schutzlücke |

**Es ist kein Projektproblem.** Ein leeres Gradle-Testprojekt unter
`C:\gtmp\gt` scheitert identisch. Gradle kann auf diesem Rechner generell
nicht starten, unabhängig von Flutter, diesem Repository und dem langen
Worktree-Pfad.

**Und es lief hier früher.** `~/.gradle/daemon/` enthält Verzeichnisse für die
Versionen 8.2.1, 9.0.0 und 9.1.0. Am 26.08.2026 um 20:46 hat TotalAV seine
Datei `knap.data` aktualisiert, also am selben Tag, an dem der Fehler auftrat.

### Eingegrenzt am 27.08.2026: es ist `Selector.open()`

Die vollständige Stapelspur (`gradle help --no-daemon --stacktrace`) zeigt einen
anderen Aufrufweg als bisher angenommen:

```
sun.nio.ch.PipeImpl$Initializer.run
sun.nio.ch.PipeImpl.<init>
sun.nio.ch.WEPollSelectorImpl.<init>
sun.nio.ch.WEPollSelectorProvider.openSelector
java.nio.channels.Selector.open
org.gradle.internal.remote.internal.inet.SocketConnection$SocketInputStream.<init>
```

**Es scheitert nicht `Pipe.open()`, sondern `Selector.open()`.** Der frühere
Schluss „Java kann es, Gradle nicht" verglich zwei verschiedene Codepfade:
`Pipe.open()` erzeugt `PipeImpl(sp, buffering: true)`, der Selektor erzeugt
`PipeImpl(sp, buffering: false)`. Ersteres gelingt, Letzteres nicht.

Damit gibt es einen **Minimalfall von 20 Zeilen, der in einer Sekunde
antwortet.** Das ist die Prüfschleife für jeden Behebungsversuch, kein
Gerätebuild nötig. Als `SelectorProbe.java` ablegen und mit
`java SelectorProbe.java` starten (Quelldatei-Modus, kein `javac` nötig):

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

Erwartet auf einem gesunden Rechner: beide Zeilen `OK`. Auf diesem Rechner:
`Pipe.open() OK`, dann
`Selector.open() FEHLER: java.net.SocketException: Invalid argument: connect`.

**Warum das schwerer wiegt als ein Build-Problem:** `Selector.open()` ist eine
Grundfunktion von Java NIO. Kein Java-Werkzeug, das Selektoren benutzt, kann auf
diesem Rechner laufen. Gradle ist nur der erste, der es merkt.

### Am 27.08.2026 zusätzlich ausgeschlossen

| Vermutung | Ergebnis |
|---|---|
| Selektor-Implementierung | Auch der alte `sun.nio.ch.WindowsSelectorProvider`, erzwungen per Systemeigenschaft, scheitert identisch. Nicht wepoll-spezifisch. |
| Das JDK | **Endgültig ausgeschlossen.** JBR 21.0.10, JBR 17.0.14, PyCharms JBR 25.0.2 und **Temurin 21.0.12**, also ein ungepatchtes OpenJDK, scheitern alle identisch. Der Temurin-Build liefert zusätzlich echte Zeilennummern: geworfen wird in `PipeImpl.java:103`, nachdem `LoopbackConnector` intern die `SocketException` gefangen hat; Aufrufer ist `WEPollSelectorImpl.java:79` über `PipeImpl.java:197`. |
| Gradle-Daemon | `--no-daemon` scheitert identisch, es ist nicht der Handshake mit dem Daemon. |
| Sandbox der Werkzeugumgebung | Mit abgeschalteter Sandbox identisch gescheitert. |
| JVM-Umgebungsvariablen | `JAVA_TOOL_OPTIONS`, `_JAVA_OPTIONS`, `JDK_JAVA_OPTIONS`, `GRADLE_OPTS`, `JAVA_OPTS` sind alle leer, in Prozess, Benutzer und System. Keine globale `~/.gradle/gradle.properties`. Die frühere Fehlersuche hat nichts hinterlassen. |
| Winsock-Katalog | `netsh winsock show catalog` zeigt ausschließlich Basisdienstanbieter, **keinen einzigen Layered Service Provider**. Der klassische Auslöser für `WSAEINVAL` ist damit unwahrscheinlicher als gedacht. |
| Netzwerk-Filtertreiber | `Get-NetAdapterBinding` zeigt ausschließlich Microsoft-Komponenten. Kein Rest von TotalAV, keine VPN- oder Proxy-Filter. |
| Defender Network Protection | `EnableNetworkProtection = 0`, also aus. Echtzeitschutz an, das ist Dateiprüfung. |
| Portbereiche | Dynamischer TCP-Bereich ab 49152 mit 16384 Ports, ausgeschlossen sind genau 61 (5357 und 50000–50059). Keine Erschöpfung. |
| `hosts`-Datei | Keine Einträge für `localhost`, `127.0.0.1` oder `::1`. |
| Reihenfolge im Prozess | `Selector.open()` scheitert auch als **allererste** Netzoperation, dreimal hintereinander. Nicht die Folge eines vorher geschlossenen Sockets. |
| Gradle 8.x im Cache | `gradle-8.12-all` ist ein **abgebrochener Download** (0-Byte-`.zip.part`). Ein Herunterziehen auf 8.x braucht also doch einen Download. |

**Verbleibender Verdacht, in dieser Reihenfolge zu prüfen:**

0. **Neustart.** Der billigste Schritt. Behebt halb angewandte Treiber-Updates
   und setzt TotalAVs Kernel-Treiber neu auf. Ein Windows-Update war zum
   Zeitpunkt des Fehlers zur Installation vormerkt.

1. **Winsock-Katalog zurücksetzen.** Der klassische Auslöser für
   `WSAEINVAL` bei `connect` ist ein beschädigter Winsock-Katalog, etwa durch
   Reste einer Sicherheitssoftware. Braucht eine Eingabeaufforderung als
   Administrator und einen Neustart:

   ```
   netsh winsock reset
   netsh int ip reset
   ```

2. **Ein Vanilla-JDK: geprüft und erledigt.** Temurin 21.0.12 ist am
   27.08.2026 installiert (`C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot`)
   und scheitert identisch. Das JDK ist damit keine Variable mehr, und
   `flutter config --jdk-dir` löst nichts.

   Bleibt also der Netzwerk-Stack von Windows aus Punkt 1. Wenn Winsock- und
   IP-Reset samt Neustart nichts bringen, ist die nächste Stufe `sfc /scannow`
   und danach eine reparierende Windows-Installation: dann ist eine
   Systemkomponente beschädigt, und das ist kein Projektproblem mehr.

   **Nach jedem Versuch die Probe von oben, nicht einen Build.** Eine Sekunde
   statt Minuten, und sie sagt genau dasselbe.

   Netzwerkseitig ist nichts auffällig: nur WLAN aktiv, Hamachi nicht present,
   Default-Route und Loopback-Route normal, reservierte Portbereiche
   unkritisch.
3. **Gradle 9.1.0.** Vom Flutter-Template gesetzt und sehr neu. Testweise auf
   eine 8.x-Version in `android/gradle/wrapper/gradle-wrapper.properties`
   herunterziehen.

Bis das gelöst ist, sind alle Aussagen über die App **strukturell**: Tests,
Analyse und Grenzprüfung. Nichts ist optisch am Gerät verifiziert.

### Nicht aus einem OneDrive-Pfad bauen

Der AOT-Compiler bricht an Nicht-ASCII-Verzeichnisnamen. Dieses Repository
liegt deshalb unter `C:\dev\flutter-fact`. Wenn du es woanders klonst, nimm
einen kurzen ASCII-Pfad.

---

## Befehle

### Die vier Gates

Müssen alle vier auf Exit-Code 0 stehen, bevor etwas committet wird:

```
dart format --output=none --set-exit-if-changed .
dart analyze
dart run tool/check_architecture.dart
flutter test
```

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
